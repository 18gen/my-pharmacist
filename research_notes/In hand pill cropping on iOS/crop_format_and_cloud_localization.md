# Pill crops for a cloud VLM: capture resolution, crop format and packaging, and cloud localization or counting as a fallback (as of 2026-11-09)

Scope and method:
- Research date is 2026-11-09.
- Vendor docs were read as raw Markdown this session from developers.openai.com, ai.google.dev, platform.claude.com and developer.apple.com (`.md` variants). Exact numbers below are copied from those files, not from summaries.
- Papers and third-party pages were read through search summaries or fetch-and-summarize. They are marked as such where it matters.
- App facts come from the working tree:
  - `MyPharmacist/Camera/CameraSession.swift`
  - `MyPharmacist/PillVision/OpenAIPillIdentifier.swift`
  - `MyPharmacist/PillVision/PillPhotoAnalyzer.swift`
- This file does not repeat the earlier notes in `research_notes/In hand pill recognition architecture/` (cloud_multimodal_apis.md, camera_quality_assessment.md). It goes deeper on resolution, crop format, packaging and cloud localization.
- Pixel arithmetic is my own. The assumptions are stated where it appears.

## 1. Capture: which AVFoundation settings maximise real pixels on each pill, and how many pixels does a 6–9 mm pill get today?

### Takeaway
The app very likely gets **1920×1080 stills** today (1080 px across the portrait frame), not 12 MP. A default `AVCapturePhotoSettings()` asks for the *smallest* entry in the active format's `supportedMaxPhotoDimensions`, and preset `.high` selects a video format. That gives about 12 px/mm, so a 7 mm pill is about 86 px and an imprint character about 18 px.

Setting `maxPhotoDimensions` alone helps little at the app's ~1.5–2× digital zoom, because a binned 12 MP readout cropped by 2× has only about 13–14 real px/mm. The real gain needs a full-resolution (48 MP Quad-sensor) readout: about 26–35 px/mm, so a 7 mm pill is about 180–240 px and a character about 38–51 px. That requires:
- session preset `.photo`, with output and settings `maxPhotoDimensions` = 8064×6048 on 48 MP devices; or
- zoom snapped to a `secondaryNativeResolutionZoomFactors` value (2×), where the sensor switches to full-resolution sampling without upscaling.

Verify on device by logging `resolvedSettings.photoDimensions` and `activeFormat.supportedMaxPhotoDimensions`.

### Cited Findings
**What the app does now** (local code):
- `session.sessionPreset = .high`; single `.builtInWideAngleCamera`.
- `let settings = AVCapturePhotoSettings()` with nothing else set. No `maxPhotoDimensions` on the output or the settings, no quality prioritization.
- `videoZoomFactor = startingZoom(for:)`, capped at `min(maxAvailableVideoZoomFactor, 3)`. It is computed from `minimumFocusDistance` and a 70 mm spread at 80% of a 16:9 portrait width (`tan(hfov/2)·9/16`).
- The still is rotated upright with `CIImage.oriented(.right)` → `CIContext.createCGImage`.
- Source: `MyPharmacist/Camera/CameraSession.swift` (lines ~81, 119–131, 148, 168, 93–96).

**Apple API facts** (fetched `.md` docs, Nov 2026):
- `AVCapturePhotoSettings.maxPhotoDimensions`:
  - "This property defaults to the smallest dimensions returned by `supportedMaxPhotoDimensions`."
  - It must match an entry in the active format's `supportedMaxPhotoDimensions`, and must be ≤ the photo output's `maxPhotoDimensions`.
  - [Apple: AVCapturePhotoSettings.maxPhotoDimensions](https://developer.apple.com/documentation/avfoundation/avcapturephotosettings/maxphotodimensions.md)
- `AVCapturePhotoOutput.maxPhotoDimensions` (iOS 16+):
  - "Set a value for this property to request images up to the specified dimensions. Images that a photo output returns may be smaller... but are never larger."
  - It must match a `supportedMaxPhotoDimensions` entry.
  - "Changing this property may trigger a lengthy reconfiguration of the capture pipeline, so set this value before calling `startRunning()`."
  - [Apple: AVCapturePhotoOutput.maxPhotoDimensions](https://developer.apple.com/documentation/avfoundation/avcapturephotooutput/maxphotodimensions.md)
- `AVCaptureDevice.Format.supportedMaxPhotoDimensions` (`[CMVideoDimensions]`) is "the maximum photo dimension this format supports". — [Apple](https://developer.apple.com/documentation/avfoundation/avcapturedevice/format/supportedmaxphotodimensions.md)
- **Deprecated predecessors:**
  - `AVCapturePhotoSettings.isHighResolutionPhotoEnabled` is available on iOS 10.0–16.0 only (deprecated). Its doc says that when false (the default), the output "delivers images with the dimensions specified by the `formatDescription` of the source device's active capture format". Some formats allow stills larger than their video resolution. [Apple](https://developer.apple.com/documentation/avfoundation/avcapturephotosettings/ishighresolutionphotoenabled.md)
  - `AVCaptureDevice.Format.highResolutionStillImageDimensions` is iOS 8.0–16.0 (deprecated). [Apple](https://developer.apple.com/documentation/avfoundation/avcapturedevice/format/highresolutionstillimagedimensions.md)
  - The output-side `isHighResolutionCaptureEnabled` must be set before `startRunning()`, or toggling it causes a "lengthy reconfiguration". [Apple](https://developer.apple.com/documentation/avfoundation/avcapturephotooutput/ishighresolutioncaptureenabled.md)
- **Video stabilization** on any output can make photos "around 10% smaller than the maximum still image dimensions". — [Apple: isHighResolutionPhotoEnabled](https://developer.apple.com/documentation/avfoundation/avcapturephotosettings/ishighresolutionphotoenabled.md)
- **Actual size per shot:** `AVCaptureResolvedPhotoSettings.photoDimensions` is "the size, in pixels, of the photo image... that the capture delivers", available in early delegate callbacks. — [Apple](https://developer.apple.com/documentation/avfoundation/avcaptureresolvedphotosettings/photodimensions.md)
- **Presets:**
  - `.high` is "A preset suitable for capturing high-quality output... This is the default preset." [Apple](https://developer.apple.com/documentation/avfoundation/avcapturesession/preset/high.md)
  - `.photo` is "suitable for capturing high-resolution photo quality output". [Apple](https://developer.apple.com/documentation/avfoundation/avcapturesession/preset/photo.md)
- **WWDC26 session 304, "Implement high resolution photo capture"** (via fetch-and-summarize of the session page):
  - "only the photo preset supports 24 and 48 megapixel photos. Other presets do not support it."
  - Apple's sample sets `sessionPreset = .photo`, picks the largest `activeFormat.supportedMaxPhotoDimensions`, and assigns it to `photoOutput.maxPhotoDimensions` before commit.
  - It sets per-shot `settings.maxPhotoDimensions` and `photoQualityPrioritization`.
  - "Setting maxPhotoDimensions is a request, not a guarantee... The actual dimensions come back to your delegate inside AVCaptureResolvedSettings."
  - 48 MP Quad sensors exist "starting with iPhone 14 Pro and iPhone 14 Pro Max". 24 MP exists starting with iPhone 15.
  - 48 MP is a single sensor frame and allows `.balanced` or `.quality`. 18 and 24 MP are multi-frame fused and need `.quality`. 12 MP allows all three levels.
  - Use `setPreparedPhotoSettingsArray` to pre-allocate. Processing "can take several seconds"; check `photoProcessingTimeRange`.
  - [WWDC26 304](https://developer.apple.com/videos/play/wwdc2026/304/)
- **`maxPhotoQualityPrioritization`** defaults to `.balanced` on an `AVCaptureSession`. Changing it while running "causes the session to be rebuilt". — [Apple](https://developer.apple.com/documentation/avfoundation/avcapturephotooutput/maxphotoqualityprioritization.md)
- **`videoZoomFactor`:**
  - "The device achieves a zoom effect by cropping around the center of the image captured by the sensor... At higher zoom factors, the device must scale the cropped image up to the output size, resulting in a loss of image quality."
  - `videoZoomFactorUpscaleThreshold` gives the factor at which upscaling starts.
  - [Apple: videoZoomFactor](https://developer.apple.com/documentation/avfoundation/avcapturedevice/videozoomfactor.md); [Apple: videoZoomFactorUpscaleThreshold](https://developer.apple.com/documentation/avfoundation/avcapturedevice/format/videozoomfactorupscalethreshold.md)
- **`secondaryNativeResolutionZoomFactors`** (iOS 16+): "Devices that provide secondary native resolution zoom factors can switch their pixel sampling mode dynamically to produce high-fidelity images without upscaling at a fixed zoom factor beyond 1.0." — [Apple](https://developer.apple.com/documentation/avfoundation/avcapturedevice/format/secondarynativeresolutionzoomfactors.md)
- **Practitioner evidence (Brickit, Oct 2023):**
  - The 3840×2160 preset produced 16:9 stills of 3840×2160 (6.2 MP after a 4:3 crop).
  - Switching to `AVCaptureSessionPresetPhoto` gave 4032×3024: "twice bigger", with 6 months in production.
  - [Brickit Engineering, Medium](https://medium.com/brickit-engineering/how-we-doubled-the-photo-resolution-from-flutter-camera-on-ios-e17004cd0b74)
- **Forum reports**, from a search summary and not opened. Treat them as unverified pitfalls:
  - Setting both output and settings to 8064×6048 still returned 12 MP for one developer.
  - 24 MP (5712×4284) was only delivered with auto-deferred photo delivery enabled.
  - [Apple Forums 748321](https://developer.apple.com/forums/thread/748321); [Apple Forums 771705](https://developer.apple.com/forums/thread/771705)
- **Auto-deferred delivery:** `isAutoDeferredPhotoDeliveryEnabled` (iOS 17+) also requires "a lengthy reconfiguration" if changed while running. — [Apple](https://developer.apple.com/documentation/avfoundation/avcapturephotooutput/isautodeferredphotodeliveryenabled.md)

### Inferences
- **What the app probably gets today.** `.high` selects a 1080p video format on current iPhones, and default settings request the smallest supported photo size. So the still is most likely 1920×1080, which upright is 1080 px wide. Both premises are documented; the exact list values per device are not.
  - Confirm with one log line in the delegate: `photo.resolvedSettings.photoDimensions`.
  - Also log `device.activeFormat.supportedMaxPhotoDimensions` at configure time.
- **Pixel budget (my arithmetic).** Assumptions:
  - The preview's portrait width covers 70 mm / 0.8 = **87.5 mm** of scene. The app's zoom logic targets this, and the user moves until the pills fill the frame.
  - Real sensor pixels across that width = sensor short side ÷ zoom.
  - The 24 mm-equivalent main camera has about 73.7° HFOV, so the app's fill distance at 1× is about 104 mm. With a minimum focus of about 150–200 mm, `startingZoom` lands at about **1.45–1.95×**. The minimum-focus values are typical, not sourced, so compute them on device.
  - Imprint characters are about **1.5 mm** tall. I measured this from the project's own reference photo `dexamethasone-4-1.png` ("54 892"): digit height is about 22% of tablet diameter. The tablet's diameter was not verified (about 7 mm is assumed), so 1.5 mm is approximate.

  | Capture path | Zoom 1.5× (real px/mm) | Zoom 1.9× | Zoom 3× | 7 mm pill at 1.9× | 1.5 mm char at 1.9× | 7 mm crop incl. 25% pad at 1.9× |
  |---|---|---|---|---|---|---|
  | Today, likely: `.high` + default settings, 1080 px wide output | 12.3 (output-limited) | 12.3 | 8.6 | ~86 px | ~18 px | ~129 px |
  | `.high` + largest 12 MP 16:9 `maxPhotoDimensions` (binned readout) | 17.3 | 13.6 | 8.6 | ~95 px | ~20 px | ~143 px |
  | `.photo` 12 MP 4:3 (binned) | 17.3 | 13.6 | 8.6 | ~95 px | ~20 px | ~143 px |
  | `.photo` 48 MP (full readout), or 2× native-resolution crop | 34.6 | 27.3 | 17.3 | ~190 px | ~40 px | ~286 px |

  - Digital zoom from a binned readout adds output pixels, not detail. At about 1.9×, a 12 MP still has only about 10% more real detail than the 1080p still. Setting `maxPhotoDimensions` to 12 MP and stopping there will disappoint.
  - The doubling comes from the full-resolution 48 MP readout. The main wide camera has it on iPhone 14 Pro and later Pro models and on iPhone 15 and later (WWDC26 says 24 MP fusion begins at iPhone 15). iPhone 13 and 14 non-Pro wide cameras are 12 MP; for them, `.photo` 12 MP and minimal zoom are the ceiling.
- **Recommended capture configuration (iOS 17 floor), in order of payoff:**
  1. `session.sessionPreset = .photo`. The preview becomes 4:3, so change the `9/16` in `startingZoom` to `3/4`, or the pills fill only about 60% of the width.
  2. Before `commitConfiguration()`:
     - Pick the largest entry of `device.activeFormat.supportedMaxPhotoDimensions` and set `photoOutput.maxPhotoDimensions`.
     - Set `photoOutput.maxPhotoQualityPrioritization = .quality`.
     - Optionally pick 12 MP instead of 48 MP on low-memory devices.
  3. Per shot, use `AVCapturePhotoSettings()` with:
     - `maxPhotoDimensions = photoOutput.maxPhotoDimensions`
     - `photoQualityPrioritization = .balanced`, which is allowed for 48 MP; `.quality` adds latency.
     Call `setPreparedPhotoSettingsArray` once after start so the first auto-capture doesn't stall.
  4. Optionally snap the zoom to a value in `activeFormat.secondaryNativeResolutionZoomFactors` (typically 2.0 on 48 MP devices). Do this when `startingZoom` computes about 1.6–2.4×, so the video preview and a 12 MP still both use full-resolution sampling without upscaling. This needs checking on hardware, because Apple's doc does not say whether photo capture honours the same mode.
  5. Leave video stabilization off on the video data output. Stabilization shrinks stills by about 10%.
- **Memory (Swift memory-safety concern).**
  - A decoded 48 MP RGBA bitmap is about 195 MB, and 12 MP is about 49 MB.
  - The current `upright()` makes a second full-size copy through `CIContext.createCGImage`, so 48 MP would transiently need about 400 MB and risks a jetsam kill on 6 GB phones.
  - Safer pattern:
    - Keep `photo.fileDataRepresentation()` (HEIC/JPEG bytes, a few MB).
    - Make a downscaled upright overview with `CGImageSourceCreateThumbnailAtIndex(... kCGImageSourceThumbnailMaxPixelSize: 2048, kCGImageSourceCreateThumbnailWithTransform: true)`.
    - Map each pill box back to sensor orientation, and crop each pill from the full-resolution decode before rotating only that small crop.
    - Release the full bitmap promptly; none of this persists to disk.
- **Low light trade-off.** A 48 MP single frame is noisier than 12 MP binned or fused. When the quality gate sees high ISO, fall back to 12 MP with `.quality` (Deep Fusion-style multi-frame), or ask for more light. Noise destroys debossed imprints faster than it destroys printed ones.

### Gaps
- No Apple page lists `supportedMaxPhotoDimensions` per device and format, or states the default photo output `maxPhotoDimensions` when the `.high` preset is used. The "1920×1080 today" conclusion is inferred from two documented defaults and must be verified with `resolvedSettings.photoDimensions`.
- I didn't verify whether a still captured at `videoZoomFactor` = a secondary native factor (2×) uses the full-resolution crop, or what `videoZoomFactorUpscaleThreshold` is on 1080p formats.
- Minimum focus distance and exact `videoFieldOfView` per iPhone weren't sourced, so the 1.45–1.95× zoom range is an estimate.
- Imprint character height in mm comes from one reference image. I found no pharmaceutical tooling standard for minimum deboss character height.

## 2. How many pixels must a pill or an imprint character have to be legible (OCR and VLM evidence)?

### Takeaway
Classical OCR wants about **20–40 px x-height**, and degrades badly at 8–12 px. Early VLMs collapsed below about **7 px** text height. A vendor rule of thumb is a **16 px** minimum. Debossed same-colour imprints have far lower contrast than printed text, so target **≥ 30–40 real px per character** (about ≥ 25 px/mm). That means a 6–9 mm pill spans about 150–230 real px, plus a 25% margin.

Today's likely ~18 px characters are borderline. The 48 MP path (~38–51 px) is comfortable. Claude's docs separately warn about images under 200 px, and today's ~130 px crops fall below that.

### Cited Findings
- **Tesseract OCR** (via iDigBio digitization guidance, secondary): "an x-height of 20 pixels or better is preferred"; the ideal is "between 20-40 pixels"; "8–12 pixel range will produce very poor OCR return". — [iDigBio Resolution Requirements](https://www.idigbio.org/node/106); [iDigBio OCR Tips](https://idigbio.org/wiki/index.php/Special:MobileDiff/1634)
- **LLaVAR (2023)**, from a search summary of the paper: "The accuracy sharply decreases when the height is smaller than 7 pixels". Earlier, lower-resolution model variants did better on 3 px text, and higher-resolution ones did better above 7 px. — [LLaVAR arXiv 2306.17107](https://arxiv.org/pdf/2306.17107)
- **VISTA-Bench (2026)**: small 9 pt rendered text enlarged the image-vs-text "modality gap" to 7.7 points, against 3.1 overall, for current open VLMs. — [arXiv 2602.04802](https://arxiv.org/pdf/2602.04802) (search summary)
- **Zebra's on-device TextOCR** documentation suggests a minimum text height of 16 px. This is a vendor rule of thumb, not a study. — [Zebra TextOCR docs](https://techdocs.zebra.com/ai-datacapture/latest/textocr/) (search summary)
- **Vendor guidance on small text:**
  - OpenAI: "**Small text**: Enlarge text within the image to improve readability. When available, using `"detail": "original"` can also help performance." — [OpenAI Images & vision](https://developers.openai.com/api/docs/guides/images-vision)
  - Anthropic: Claude "might hallucinate or make mistakes when interpreting low-quality, rotated, or very small images under 200 pixels". And: "Avoid cropping out key visual context solely to enlarge the text." — [Claude Vision](https://platform.claude.com/docs/en/build-with-claude/vision)
- **Apple Vision:** `VNRecognizeTextRequest.minimumTextHeight` defaults to 1/32 of image height. — cited in the earlier notes, [Apple](https://developer.apple.com/documentation/vision/vnrecognizetextrequest/minimumtextheight.md)
- **Why it matters:** in the only controlled GPT-4 pill study, every error was an imprint-digit misread ("2089"→"2003", "660"→"550"), even with 12 MP iPhone photos taken at 6 inches. — [Sheikh et al., Renal Failure 2024, PMC11391868](https://pmc.ncbi.nlm.nih.gov/articles/PMC11391868/)

### Inferences
- **Working thresholds.** These are untuned starting points to validate on the project's own pills.
  - **Hard floor:** ≥ 16 real px per imprint character. Below that, don't trust any imprint the model reports; force "imprint unreadable" and retake or move closer.
  - **Target:** ≥ 30–40 real px per character, so a 7 mm round pill spans about ≥ 180–250 real px.
  - Use **real** pixels (sensor pixels after zoom) in the gate, not output pixels. Upscaled pixels don't count.
- The quality gate can predict this before capture. Take the pill-box width in the analysis frame, scale it to still pixels, and divide by the zoom-upscale factor. Gate "move closer" or "hold still" on it.
- Debossed imprints are legible through shading, not ink. Glare, flat frontal light and JPEG artefacts all erase them first. Keep crops at JPEG quality ≥ 0.85 (the app uses 0.85) or PNG; never re-encode twice.

### Gaps
- I found no study measuring VLM imprint legibility (debossed or printed) against pixel height for GPT-6.x, Gemini 3.x/4 or Claude 4.x/5.x. The thresholds above are extrapolated from OCR and 2023-era VLM text studies. A 20-minute in-house test would settle it: one photo set, crops resampled to 8/12/16/24/32/48 px character heights, and per-size accuracy of the reported `imprint`.

## 3. OpenAI image input (Nov 2026): detail levels, tokenization, cost, and is 384 px too small or wasteful?

### Takeaway
On current patch-based models, a pill crop costs about **ceil(w/32)·ceil(h/32)·1.2 tokens**:
- 384×384 ≈ 173 tokens
- 512×512 ≈ 308 tokens
- today's probable ~130 px crop ≈ 30 tokens

Crops of 512 px or less are not resized at any detail level, so `detail` barely matters for them. Image tokens are a rounding error next to reasoning output on `gpt-6.1-sol`.

384 px is **not wasteful, and in fact is not binding**. The `jpeg(maxSide:)` helper never upscales, so today's crops are probably about 130 px. The fix is more source pixels (section 1), plus resampling each crop *up* to a 384–512 px long side so characters span at least one or two 32 px patches. Set `detail` explicitly (`"high"`, or `"original"` where supported) rather than `"auto"`, whose meaning differs by model family.

### Cited Findings
**Detail levels and sizing** — [OpenAI Images & vision](https://developers.openai.com/api/docs/guides/images-vision):
- "Supported values depend on the model: `low`, `high`, `original`, or `auto`. If you omit the parameter, it defaults to `auto`."
- Guidance:
  - `low` is "coarse... `low` does not always use fewer tokens than `high`".
  - `high` is "standard high-fidelity... when precise original-image coordinates are not required".
  - `original` is for "large, dense, spatially sensitive, or computer-use images".
  - "For tasks that require fine visual detail or precise coordinates, such as optical character recognition (OCR), small-object detection, or computer use, use `"detail": "original"` when supported."
- **Sizing table:**
  - `gpt-6-astra`: `low` fits 512×512; `high` uses a 2,500-patch budget and a 65,535 px max dimension; `original` preserves dimensions; **`auto` = `original`**.
  - `gpt-5.6-sol/terra/luna`: `low` fits 512×512; `high` fits 2048×2048 and 2,500 patches; **`auto` = `original`**.
  - `gpt-5.5`: `original` allows up to 10,000 patches and 6000 px; `auto` = `original`.
  - `gpt-5.4` family: `low` uses 2048 px and a 6,144-patch budget, so it "can use more tokens than `high`"; **`auto` = `high`**.
  - `gpt-5.2` / `gpt-4.1-mini` don't support `original`.
  - `gpt-5.1` / `gpt-4.1` / `gpt-4o` / `gpt-4o-mini` are tile-based.
  - "All resizing preserves aspect ratio without enlarging smaller images."
- **Patch math:** `patch_count = ceil(width/32)×ceil(height/32)`, then a resize to the patch budget if one applies, then × the model multiplier. The multiplier is **1.2** for `gpt-6-astra`, `gpt-5.6-*`, `gpt-5.5`, `gpt-5.4*` and `gpt-5.2`; `gpt-4.1-mini` is 1.62. Worked example: 1024×1024 on `gpt-6-astra`/high = 1,229 tokens.
- **Limits:** up to 1,500 images and 512 MB per request; any image needing more than 30,000 patches after resizing is **rejected**, not resized.
- **Limitations kept in the Nov 2026 guide:**
  - "Rotation: The model may misinterpret rotated or upside-down text and images."
  - "Spatial reasoning: The model struggles with tasks requiring precise spatial localization."
  - "Counting: The model may give approximate counts for objects in images."
  - "Medical images: ... not suitable for interpreting specialized medical images."

**Models and prices** (read from raw pricing and model pages):
- `gpt-6.1-sol`:
  - "Near-Astra performance for complex work at a lower cost". Image input supported; 1,050,000 context; 922,000 max input; Apr 30 2026 cutoff.
  - `reasoning.effort` supports `low` (lowest), `medium` (default), `high`, `xhigh` and `max`. There is **no `none`**.
  - Standard $2.00 in / $10.00 out per 1M tokens; cached input $0.10 (5%); cache writes $2.50 (1.25×).
  - Batch and Flex are 50% off; Fast mode is 2×; Ultrafast is 6×; regional processing adds 10%. Prompts over 272K input are priced at 2× input and 1.5× output.
  - [GPT-6.1 Sol model page](https://developers.openai.com/api/docs/models/gpt-6.1-sol); [Pricing](https://developers.openai.com/api/docs/pricing)
- `gpt-6.1-terra`:
  - "A fast, efficient model for visual reasoning, precise computer use, and clear, natural writing."
  - The GPT-6 guide says to use it "to match product photos to catalog entries" (close to this app's task).
  - Effort supports **`none`**, `low`, `medium` (default), `high`, `xhigh` and `max`.
  - $1.00 / $5.00, cached $0.05.
  - [GPT-6 guide](https://developers.openai.com/api/docs/guides/latest-model); [Pricing](https://developers.openai.com/api/docs/pricing)
- Other GPT-6 prices: `gpt-6-astra` $10 / $50 (cached $1); `gpt-6-luna` $0.10 / $0.50; `gpt-6-sol` $2 / $10 (cached $0.20). — [Pricing](https://developers.openai.com/api/docs/pricing)
- **Prompt caching (GPT-5.6+)** — [OpenAI Prompt caching](https://developers.openai.com/api/docs/guides/prompt-caching):
  - What's cached: "OpenAI caches the model's full rendered context including ... images".
  - Minimum cacheable prefix is 1,024 tokens.
  - Writes cost 1.25× for the default 30-minute TTL and 2.5× for `prompt_cache_options.ttl: "12h"`. Reads cost 0.05× on GPT-6.1 Sol and Terra.
  - Up to four cache writes per request; the whole prefix must match.
- **App code** (`OpenAIPillIdentifier.swift`):
  - Every image is sent with `"detail": "auto"`.
  - Pill crops use `surroundingCrop(padding: 0.25)`, which pads 25% of the box's longer side on every side, so the crop is about 1.5× the pill.
  - Then `jpeg(maxSide: 384)` scales by `min(1, 384/maxSide)`, so it never enlarges, and encodes at quality 0.85.
  - Reference photos go through `jpeg(maxSide: 256)`.

### Inferences
- **`gpt-6.1-sol` sizing is not in OpenAI's table.** The vision guide's sizing and multiplier tables list `gpt-6-astra` and `gpt-5.6-*` but not `gpt-6.1-sol` or `gpt-6.1-terra`. Assume the GPT-6 behaviour (32 px patches, ×1.2, `auto` = `original`), and confirm with `usage.input_tokens` from one call that sends a single 384×384 image (expect about 173 plus text tokens).
- **Token table** (OpenAI ×1.2 patches / Claude 28 px patches):

  | Crop side | OpenAI tokens | Claude tokens |
  |---|---|---|
  | 130 | 30 | 25 |
  | 256 | 77 | 100 |
  | 384 | 173 | 196 |
  | 512 | 308 | 361 |

  - An overview image of 768×1024 is about 922 OpenAI tokens.
  - A full 1536×2048 at `original` is about 3,687 tokens; at `high` on astra it is capped near 3,000.
- **Per-scan cost on `gpt-6.1-sol`** for the recommended packaging (my arithmetic, Standard tier). Inputs: 6 crops at 384 (1,038 tokens), one 768×1024 numbered overview (922), 8 reference photos at 256 (616) and about 700 text tokens.
  - Input ≈ 3.3K tokens ≈ **$0.0066**.
  - Output: about 300 JSON tokens plus reasoning. At `low` effort, probably 0.5–2K reasoning tokens (unmeasured), which is **$0.008–0.023**.
  - Total ≈ $0.015–0.03 per scan. Image tokens are about a quarter of the cost, and reasoning dominates.
  - The instructions plus reference photos form a stable per-patient prefix of 1,024 tokens or more. Putting it first makes repeat scans read it at $0.10/M.
  - `gpt-6.1-terra` with `reasoning.effort: "none"` would be roughly 5–10× cheaper and faster. Worth an A/B on imprint accuracy.
- **Is 384 right?**
  - With 48 MP capture, a 7–9 mm pill crop is about 290–370 real px, so 384 is right-sized and costs about 173 tokens.
  - With today's ~130 px crops, enlarge to 384 with high-quality (Lanczos/`.high`) interpolation. Upscaling adds no information, but OpenAI explicitly advises enlarging small text, and it lifts each character from about half a patch to more than one patch. Claude also flags images under 200 px as unreliable.
  - Going to 512 costs about 135 more tokens per crop (≈ $0.0003 on Sol) and is only worth it if the source has more than 384 real px.
- **Set `detail` explicitly.** Use `"high"`, or `"original"` on families that support it, rather than `"auto"`. `"auto"` means `original` on GPT-6/5.6 but `high` on GPT-5.4, so the semantics change silently if `OPENAI_MODEL` is switched. For images of 512 px or less, `low`, `high` and `original` give the same size on GPT-6/5.6. On GPT-5.4, `low` can cost *more*.
- **Reference photos.** At 256 px (77 tokens) they are fine. If the reference photos are imprint-bearing cut-outs, consider 384 so their imprint is as legible as the crop's. A mismatch in apparent sharpness may bias matching.

### Gaps
- `gpt-6.1-sol` and `gpt-6.1-terra` image sizing and multipliers are undocumented in the vision guide, as noted above.
- I found no OpenAI statement on whether `original` vs `high` changes accuracy for small images (both keep them unresized) or whether upscaling small crops helps current GPT-6 models. An A/B test is needed.
- Reasoning-token usage per scan at `low` effort was not measured.

## 4. Packaging: separate crops vs numbered marks on the full image vs a contact sheet vs crops plus the full image; masked cut-out vs real background; canonical rotation

### Takeaway
Keep **one image per pill** (separate `input_image` items, each labelled "Pill N:" in text). Evidence favours separate high-resolution crops over a downscaled full image for small details, and favours separate images over composites for proprietary models.

Add **one small numbered overview** (Set-of-Mark style: the on-device boxes drawn with large numbers on a downscaled, tightly cropped image) as context and as the hook for a "did we miss a pill?" check.

Within each crop, keep the real pixels around the pill but **suppress neighbours**: dim or blur outside the pill mask, or draw a thin outline. Don't hard-cut it onto gray. Rotate elongated pills so the long axis is horizontal; leave round pills alone.

### Cited Findings
- **Cropping helps small details:**
  - The ICLR 2025 paper "MLLMs Know Where to Look" finds MLLMs "know where to look" even when they answer wrong. Training-free visual cropping (ViCrop) "significantly improve[s]" accuracy on detail-sensitive benchmarks including TextVQA. — [Zhang et al., arXiv 2502.17422](https://arxiv.org/pdf/2502.17422)
  - Its predecessor reports cropping improved BLIP-2-T5 by 32.23% on TextVQA. — [arXiv 2310.16033](https://arxiv.org/pdf/2310.16033) (search summaries)
- **Set-of-Mark:** overlaying alphanumeric marks, masks or boxes on segmented regions lets GPT-4V ground references. "GPT-4V with SoM in zero-shot setting outperforms the state-of-the-art fully-finetuned" referring-expression model on RefCOCOg. — [Yang et al., arXiv 2310.11441](https://arxiv.org/abs/2310.11441)
- **Composites and collages:**
  - GPT-4V collage prompting: accuracy decreases as grid size grows, a 2×2 grid cuts cost to about 1/4, and accuracy "varies significantly with the order of images within the collage". — [CollagePrompt, arXiv 2403.11468](https://arxiv.org/pdf/2403.11468v1.pdf) (search summary)
  - RealBench (2025): "closed-source models... generally perform worse on composite images than when directly inputting multiple individual images", while some open multi-image models do the opposite. — [arXiv 2509.17421](https://arxiv.org/pdf/2509.17421) (search summary)
- **Masking vs context:** Fine-Grained Visual Prompting (NeurIPS 2023) compared crop, box, circle, coloured mask, grayscale and blur prompts. "Blur Reverse Mask" (blur everything outside the target's mask) was best, improving zero-shot referring comprehension by about 3.0–4.6% on average over prior visual prompts, and up to 12.5% on RefCOCO+ testA. These are CLIP-style models, not GPT. — [FGVP, arXiv 2306.04356](https://arxiv.org/abs/2306.04356v2); [Papers with Code summary](https://cs.paperswithcode.com/paper/fine-grained-visual-prompting)
- **Context guidance:** Anthropic advises "Avoid cropping out key visual context solely to enlarge the text", and for fine targets to "crop the region of interest and send the crop". — [Claude Vision](https://platform.claude.com/docs/en/build-with-claude/vision); [Claude Coordinates](https://platform.claude.com/docs/en/build-with-claude/vision-coordinates)
- **Rotation:**
  - OpenAI: models "may misinterpret rotated or upside-down text". [OpenAI](https://developers.openai.com/api/docs/guides/images-vision)
  - Gemini: "Verify that images are correctly rotated." [Gemini image understanding](https://ai.google.dev/gemini-api/docs/image-understanding)
  - OCR-Rotation-Bench: without rotation correction, Tesseract fell from about 49% to about 24% and docTR from about 65% to about 16%. Classical OCR, not VLMs. [ORB on alphaXiv](https://alphaxiv.org/benchmarks/krutrim-ai/ocr-rotation-bench); [arXiv 2511.04161](https://arxiv.org/html/2511.04161v2)
  - A 2025 paper reports MLLM extraction accuracy degrading beyond several tens of degrees of in-plane rotation, recovering near 180°. [arXiv 2511.17607](https://web3.arxiv.org/pdf/2511.17607) (secondary description; unverified)
- **Gemini input order:** "When using a single image with text, place the text prompt *before* the image." — [Gemini image understanding](https://ai.google.dev/gemini-api/docs/image-understanding)

### Inferences
- **Option comparison for this app:**

  | Packaging | Pixels on imprint | Pill↔answer binding | Context (count, colour reference) | Privacy | Verdict |
  |---|---|---|---|---|---|
  | (a) separate crops (current) | Best: full native resolution per pill | Strong: "Pill N:" text precedes each image | None | Minimal (pill plus a little palm) | **Keep as primary** |
  | (b) one full image with SoM numbers | A 4032 px still downscaled to about 1600 px loses about 60% of linear resolution; a pill becomes about 70–100 px and a character about 15–20 px | Good with marks | Full | Sends hand and background | Use only as a *small overview*, not for imprint reading |
  | (c) contact sheet of numbered crops | Same pixels as (a) if not shrunk, but grid-position confusion and order effects | Weaker (label must be read off the image) | None | Minimal | Avoid; saves a few tokens per image at most |
  | (d) crops + overview | (a) plus context | Strong | Good | Moderate; mitigate by cropping the overview to the pills' union box and greying out skin | **Recommended** |
- **Overview spec (starting point):**
  - Crop the still to the union of the on-device pill boxes plus about 10% margin, and downscale to a long side of about 768–1024 px.
  - Draw each pill's box with a high-contrast outline and a large numeral (about 6% of image height) placed *outside* the pill, so the numeral never covers the imprint. Use the same numbering as the crops.
  - Send at `detail: "high"`, about 600–900 tokens.
  - Prompt: "Image 0 is an overview with the numbered pills that were cut out. Report any pill-like object that has no number."
- **Neighbour suppression inside crops.** With 25% padding, crops of touching or nearby pills contain parts of other pills. The model can then describe the wrong one, which is a plausible silent failure. Two options:
  - (i) Multiply pixels outside the dilated pill mask by about 0.5 brightness, or Gaussian-blur them (FGVP-style). This keeps the true edge and imprint even if the mask is a little tight, which is the reason the current code pads.
  - (ii) Add a thin coloured contour around the target and say "the outlined pill" in the prompt.

  Prefer (i): blur or dim keeps shape cues, while a hard gray cut-out amplifies any mask error (a clipped imprint or edge changes shape and imprint). If the reference photos are gray-background cut-outs, a dimmed but real background is still closer to them than raw palm skin.
- **Rotation:**
  - For capsule, oval or oblong pills, rotate each crop so the long axis (from the mask's principal axis or minimum-area rectangle) is horizontal. Imprints on elongated tablets usually run along the long axis (domain knowledge, unsourced). This reduces arbitrary angles to 0° or 180°.
  - For round tablets there is no axis to use. Leave them, or try the 4 cardinal rotations only on retry.
  - Tell the model: "the imprint may be upside down; read it in any orientation".
  - Do the rotation on the small crop, after cropping from the full-resolution image (memory).
- **Number of images.** 10 pills + 10 crops + 1 overview + 8–16 references is about 30 images, well under OpenAI's 1,500 per request. Claude applies a stricter per-image size limit above 20 images per request (≤ 3,000 px per side), which crops satisfy. — [Claude Vision](https://platform.claude.com/docs/en/build-with-claude/vision)

### Gaps
- I found no study comparing these packagings for pill or small-object identification with GPT-6.x or Gemini 3.x/4. The CollagePrompt and RealBench results come from GPT-4V-era or open models.
- I found no VLM-specific evidence for blur/dim-outside-mask vs plain crop vs gray cut-out. FGVP's evidence is for CLIP-style models.
- Imprint-direction conventions on elongated tablets were not sourced.
- Recommended in-house A/B on 30–50 real palm photos: (a) vs (d); padded crop vs dimmed-outside-mask vs gray cut-out; rotated vs unrotated. Measure per-pill top-1, false-confident rate and imprint exact-match.

## 5. Cloud localization alternatives: can a cloud model reliably detect or segment the pills when on-device cropping is unsure?

### Takeaway
- **OpenAI** still documents no box format and keeps "struggles with tasks requiring precise spatial localization" in its Nov 2026 guide. Don't use it as a detector.
- **Gemini** is the only general LLM API with documented, trained detection (`box_2d` normalized 0–1000) and segmentation (box plus a base64 PNG probability mask). It is good enough as a *fallback proposal generator* validated on the device, but zero-shot detection benchmarks are modest.
- **SAM 3** (text prompt "pill") is the strongest candidate for a *dedicated* fallback detector or independent counter. It returns instance masks, scores and boxes for every match, is cheap ($0.005 per image on fal) and is fast (sub-second GPU inference).
- **Claude** returns approximate pixel boxes and is not a better detector than Gemini.
- **Moondream Cloud** has detect, point and count skills, but its status is uncertain (a reported shutdown on 2026-11-13).
- **Florence-2** was not researched this session.

### Cited Findings
**OpenAI**
- The Nov 2026 vision guide lists the spatial-reasoning and counting limitations, and recommends `"detail": "original"` for "small-object detection" and coordinate tasks, mapping returned coordinates back yourself. It defines no box schema. — [OpenAI Images & vision](https://developers.openai.com/api/docs/guides/images-vision)
- GPT-6.1 Terra is pitched for "precise computer use" (screen pointing), not natural-image detection. — [OpenAI Models](https://developers.openai.com/api/docs/models)
- I found no published GPT-6.x grounding benchmark. Earlier notes cite GPT-5 at 79.3% Acc@0.5 on RefCOCO, but only via a multi-step verify-candidates workflow. — [arXiv 2509.09958](https://arxiv.org/html/2509.09958v3)

**Google Gemini** — [Gemini image understanding](https://ai.google.dev/gemini-api/docs/image-understanding); [Media resolution](https://ai.google.dev/gemini-api/docs/media-resolution); [Pricing](https://ai.google.dev/gemini-api/docs/pricing)
- "Gemini models offer **enhanced accuracy** for specific use cases like object detection and segmentation, through additional training."
- **Detection:** boxes are `[ymin, xmin, ymax, xmax]` normalized to 0–1000. "You need to descale these coordinates based on your original image size." JSON-schema output works.
- **Segmentation** ("Starting with Gemini 2.5"): each item has `box_2d`, `label`, and "the segmentation mask inside the bounding box, as base64 encoded png that is a probability map with values between 0 and 255". "For better results, disable thinking by setting the thinking level to 'minimal'."
- **Media resolution (Gemini 3 and 4):** per-image *maximum* tokens are `unspecified` (default) 1,120, `low` 280, `medium` 560, `high` 1,120, and `ultra_high` 2,240 (per item only). These can be set per content item: "Higher resolutions improve the model's ability to read fine text or identify small details."
- **Older token rule:** an image ≤ 384 px on both sides costs 258 tokens; larger images are tiled into 768×768 tiles of 258 tokens each.
- **Current models and prices** (per 1M tokens):
  - `gemini-4-argon`: $2 / $10 through 2026-11-30, then $4 / $20 from 2026-12-01.
  - `gemini-3.8-flash`: $0.75 / $3.75 through 2026-12-31, then $1.50 / $7.50 from 2027-01-01.
  - `gemini-3.5-flash-lite`: $0.30 input / $2.50 output, as read from the page.
- **RF100-VL** (Roboflow, May 2025): across 100 diverse detection datasets, zero-shot Gemini 2.5 Pro scored **13.3 mAP50:95** against 15.7 for GroundingDINO. "Newer Gemini models consistently improve". Specialist detectors fine-tuned on a few examples beat in-context VLMs by 3–4×. No small-object breakdown was found. — [arXiv 2505.20612](https://arxiv.org/html/2505.20612v3) (search summary)

**Meta SAM 3 and hosted APIs**
- **Paper:** "SAM 3: Segment Anything with Concepts" (submitted 2025-11-20, revised 2026-03-28).
  - A unified model that "detects, segments, and tracks objects in images and videos" from concept prompts (short noun phrases, image exemplars, or both).
  - Trained on a data engine with 4M unique concept labels including hard negatives.
  - A "presence head" decouples recognition from localization. It reports about 2× the accuracy of existing systems on promptable concept segmentation, and returns masks and identities for *all* matching instances.
  - [arXiv 2511.16719](https://arxiv.org/abs/2511.16719)
- **fal.ai `fal-ai/sam-3/image-rle`:**
  - **$0.005 per request.**
  - Inputs: `image_url`, `prompt` (text), point and box prompts, `return_multiple_masks`, `max_masks` (**default 3, range 1–32**), `include_scores`, `include_boxes` (normalized `[cx, cy, w, h]`), and `sync_mode` (returns media as a data URI).
  - Output is an RLE mask or masks, plus per-mask scores and boxes.
  - [fal SAM 3 llms.txt](https://fal.ai/models/fal-ai/sam-3/image-rle/llms.txt)
- **Other hosts:** WaveSpeedAI lists SAM 3 image at $0.005 per image. Reka lists SAM 3.1 at about 0.4 s per frame. — [WaveSpeed](https://www.wavespeed.ai/models/wavespeed-ai/sam3-image); [Reka](https://infer.reka.ai/models/sam-3-1) (listing pages, search summary)
- Replicate and Roboflow SAM 3 pricing was not found.

**Anthropic Claude** — [Claude Coordinates](https://platform.claude.com/docs/en/build-with-claude/vision-coordinates); [Claude Vision](https://platform.claude.com/docs/en/build-with-claude/vision)
- "Claude works best with absolute pixel coordinates... Claude does not work well when you ask for normalized coordinates (0–1000)."
- Coordinates are relative to the *resized* image:
  - Standard tier: 1,568 px / 1,568 tokens.
  - High-resolution tier (Claude 4.7 and later): 2,576 px / 4,784 tokens.
  - Images are padded to a multiple of 28.
  - `"oversized_image": "error"` makes the API reject an image instead of silently resizing it.
- Limitations: "Claude's coordinate and localization outputs are approximate"; "Small elements lose precision when an image is downscaled: for fine targets, crop the region of interest". Claude can give "approximate counts... especially with large numbers of small objects".
- **Price example:** Opus 5.5 is $4 per 1M input tokens, so a 1000×1000 image costs about $5.18 per 1,000 images.

**Moondream**
- The official pricing page lists Moondream 3.1 (9B-A2B) at $0.30 / 1M input and $1.00 / 1M output (Batch: $0.15 / $0.50), with $5/month free credits. It shows no shutdown notice. — [moondream.ai/pricing](https://moondream.ai/pricing)
- A third-party post says Moondream Cloud "shuts off on November 13, 2026" after an acquisition by Prime Intellect, and that Cloudflare Workers AI serves query, caption, point and detect. **Unverified**: a single secondary source, contradicted by the silence on the official page. — [OrcaRouter blog](https://www.orcarouter.ai/blog/molmo2-4b-vs-moondream-3); [flaviocopes on Workers AI](https://flaviocopes.com/moondream-workers-ai.md)

### Inferences
- **Ranking for this app's fallback detector** (pills on palm or table, 2–10 instances, 6–9 mm, high contrast vs skin):
  1. **SAM 3 via fal, prompt "pill".**
     - Use `return_multiple_masks: true`, `max_masks: 16`, `include_scores: true`, `include_boxes: true`. The default `max_masks` of 3 would silently truncate a 6-pill photo, so set it explicitly.
     - It gives masks, which the app needs for neighbour-suppressed crops, plus scores for thresholding.
     - Cost is $0.005 per call. Latency is likely about 1–2 s end to end (sub-second GPU plus upload of an about 1–2 MB JPEG); this is not measured.
     - Try prompts "pill", "tablet" and "capsule". Test printed-paper demo pills too, since the app's demo uses printed pictures (`make_demo_pills.py`).
  2. **Gemini 3.8 Flash** with segmentation (`thinking_level: "minimal"`, `media_resolution` `high` per image, JSON schema). It is a single LLM call and can also label pills. It is a weaker detector than a dedicated segmenter, its masks are low-resolution PNGs inside the box, and 0–1000 quantization (about 4 px on a 4032 px image) is fine for 150–250 px pills.
  3. **Claude**: pixel boxes are usable after the documented resize mapping, but are explicitly "approximate". Use it only if Claude is already the identification model.
  4. **OpenAI GPT-6.x**: not a detector. Keep it for identification only.
- **Use any cloud detector as a *proposal + validator*, never as ground truth:**
  - Match cloud instances to on-device boxes by IoU (> 0.5).
  - Unmatched cloud instances with a high score mean "possible missed pill". Prompt a retake, or crop the instance and add it to the identification request.
  - Unmatched on-device boxes mean "possible false positive".
  - When on-device detection is unsure (low confidence, touching pills, odd backgrounds), call SAM 3 *before* the identification request and use its masks to cut crops.
- **Florence-2** (MIT-licensed, 0.23B/0.77B) is from domain knowledge, not verified this session. Its size suggests it could even run on-device via Core ML, but hosted endpoints and pricing were not checked.

### Gaps
- No benchmark measures any cloud model (Gemini 3.x/4, SAM 3, Claude, GPT-6) on small pills in hands. RF100-VL has no small-object breakdown, and the SA-Co per-concept results for "pill" or "tablet" were not retrieved.
- Real end-to-end latency for fal SAM 3, and whether fal accepts data-URI `image_url` inputs (avoiding CDN upload), were not verified.
- No Gemini 3.x/4 detection or segmentation accuracy numbers beyond Google's "enhanced accuracy" claim were found.
- Whether Gemini bills small images at the full 1,120-token cap or fewer is unclear ("maximum number of tokens").
- I could not confirm Moondream Cloud's shutdown.
- Roboflow-hosted and Replicate-hosted SAM 3 pricing and retention were not found.

## 6. Counting as a safety cross-check, and the privacy cost of sending the full photo

### Takeaway
"Ask the VLM how many pills are in the full photo; retake on mismatch" is **not a sound safety gate on its own**. Frontier VLMs get small counts right only about 60–88% of the time, depending on the benchmark, and vendors document counting as approximate. That means frequent false retakes, and when the VLM and the device agree, the agreement doesn't prove the count is right.

A better design compares **instances, not scalars**:
- On-device boxes vs SAM 3 or Gemini masks, matched by IoU; or
- A numbered overview in which the VLM must flag any *unnumbered* pill.

Use a scalar count only as a soft signal that adds "uncertain".

For privacy, send crops plus a tightly cropped, skin-dimmed overview, never the raw full frame. Set `store: false`, which the app currently omits. Disable Gemini's project logging, which is on by default for new projects since 2026-10-26, and disable fal's I/O storage.

### Cited Findings
**Counting accuracy**
- **CountBenchQA** (counts 2–10, simple images) and **PixMo-Count**, from the Molmo paper's Table 1 (search summary of arXiv 2409.17146):

  | Model | CountBenchQA | PixMo-Count |
  |---|---|---|
  | GPT-4o-0513 | 87.9 | 59.6 |
  | Gemini 1.5 Pro | 85.8 | 64.3 |
  | Gemini 1.5 Flash | 81.6 | 61.1 |
  | GPT-4V | 69.9 | 45.0 |

  Molmo-72B leads counting with a "point-then-count" approach. — [Molmo/PixMo, arXiv 2409.17146](https://arxiv.org/pdf/2409.17146)
- **CountQA** (Aug 2025; 1,528 questions on cluttered real-world images; zero-shot, single-integer answers):
  - Best overall: Gemini 2.5 Pro at 42.93% exact match.
  - Others: o4-mini 34.42%, o3 34.16%, Gemini 2.5 Flash 32.59%, Claude 4 Sonnet 31.07%.
  - Gemini 2.5 Pro by count bin: **60.3% EM for 1–5 objects** and **44.0% for 6–10**.
  - The authors hypothesize that fixed-resolution processing makes small, dense objects "blur together or disappear".
  - [CountQA, arXiv 2508.06585](https://arxiv.org/html/2508.06585v2)
- **Vendor statements:**
  - OpenAI: "Counting: The model may give approximate counts for objects in images." [OpenAI](https://developers.openai.com/api/docs/guides/images-vision)
  - Anthropic: counts are approximate, "especially with large numbers of small objects". [Claude Vision](https://platform.claude.com/docs/en/build-with-claude/vision)
- **SAM 3** returns all matching instances for a noun-phrase prompt with a presence head that decouples recognition from localization. — [arXiv 2511.16719](https://arxiv.org/abs/2511.16719)

**Retention and privacy settings**
- **OpenAI** — [OpenAI Your data](https://developers.openai.com/api/docs/guides/your-data); [Prompt caching](https://developers.openai.com/api/docs/guides/prompt-caching)
  - `/v1/responses` has a "30 day Application State retention period by default, or when the `store` parameter is set to `true`".
  - Abuse-monitoring logs are kept up to 30 days on all endpoints.
  - ZDR and Modified Abuse Monitoring need OpenAI approval; MAM may still log "image and file inputs in rare cases".
  - A new "ZDR with Private Safety Processing" option stores safety records in customer-controlled storage with no human review.
  - A HIPAA BAA is available with "Private Retention with PSP".
  - Prompt caching may hold encrypted KV tensors on GPU for up to 24 h.
- **App code:** `OpenAIPillIdentifier.requestBody` sends `model`, `instructions`, `input` and `text`. There is **no `store` key**, so the default 30-day application-state retention applies today. — local file `MyPharmacist/PillVision/OpenAIPillIdentifier.swift`
- **Gemini Developer API:**
  - Paid tier: "Google does not use your prompts... to improve our products". Prompts are logged for a limited period for abuse monitoring. Self-serve ZDR is pointed to the Vertex/Gemini Enterprise Agent Platform. [Gemini ZDR](https://ai.google.dev/gemini-api/docs/zdr)
  - Separately, developer-visible logging: "Logging is on by default for Interactions API calls, and for Generate Content API calls in projects created on or after October 26, 2026". "Logs are retained for a default maximum period of 55 days", configurable to 7/14/28/55 days. Logs saved into datasets have no set retention. [Gemini Data logging](https://ai.google.dev/gemini-api/docs/logs-policy)
- **fal.ai**, from docs pages via search summary:
  - JSON inputs and outputs are stored 30 days by default for request history.
  - The `X-Fal-Store-IO: 0` header disables that.
  - Uploaded and generated media live on fal's CDN, with lifecycle set by `X-Fal-Object-Lifecycle-Preference`.
  - [fal media expiration](https://fal.ai/docs/documentation/model-apis/media-expiration.md); [fal payloads](https://fal.ai/docs/documentation/model-apis/inference/payloads.md); [fal FAQ](https://fal.ai/docs/documentation/model-apis/faq.md)

### Inferences
- **Why a scalar count gate is weak here.** Take about 80–90% exact-count accuracy for 2–10 pills on clean images (CountBench-style), dropping toward about 45–60% on cluttered real photos (CountQA). Then a mismatch-triggered retake fires on roughly 10–40% of *correct* scans, which is a usability failure for older patients. And a VLM and a detector can share failure modes: two touching pills read as one, or a pill hidden in a palm crease. So agreement is weak evidence. Counting performance on simple, separated objects is likely better than CountQA, but no pill-specific number exists.
- **Recommended cross-check design** (layered, cheapest first):
  1. **On-device consistency.** Detection count must be stable over the gate's stability window; this is already partly in place.
  2. **Numbered-overview check inside the same identification request** (no extra call). Ask for `unnumbered_pill_like_objects: integer` and `pills_overlapping_or_touching: [int]`. Treat any non-zero as "uncertain → retake with pills spread out". This turns counting into a local "is there an unmarked object" question, which Set-of-Mark-style marking supports better than global counting. It is a hypothesis, to validate.
  3. **Independent detector only when the device is unsure, or for N ≥ 7 pills.** Send SAM 3 ("pill"; `max_masks` 16; scores) on the cropped overview and match instances to on-device boxes by IoU.
     - Mismatch with a high-score unmatched instance (≥ ~0.5, starting point): retake, with a specific hint ("separate the pills", "move the pill at top-left into view").
     - Only a low-score mismatch: proceed but mark "uncertain".
  4. **Never** let a cloud count *raise* confidence. It can only add uncertainty.
- **Privacy: send less than the full frame.**
  - The overview needs the pills, not the hand. Crop to the pills' union box plus about 10% margin, downscale to ≤ 1024 px, and dim or desaturate pixels outside the on-device foreground mask. Palm skin texture, rings, faces in the background or a home setting are then mostly removed.
  - A high-resolution palm close-up could carry palm-crease or fingerprint detail, which is biometric-adjacent. That is an inference, unsourced.
  - Strip metadata: crops from `CGImage` have none. The current JPEG encoder writes no EXIF unless it is passed in.
- **Concrete settings:**
  - OpenAI: add `"store": false` to every Responses request.
  - Gemini: turn project logging off (or create the project before 2026-10-26, which isn't practical) and use the paid tier.
  - fal: send `X-Fal-Store-IO: 0`, use `sync_mode: true` so masks come back inline rather than as CDN URLs, and pass images as data URIs if supported (unverified).
  - Disclose in the app's privacy text that the provider may keep abuse-monitoring copies for up to 30 days (OpenAI) or a limited period (Google).

### Gaps
- I found no counting benchmark for 2–10 small, similar objects on skin or a hand, and no CountBench or CountQA numbers for GPT-6.x, Gemini 3.x/4 or Claude 5.x.
- The exact Gemini paid-tier abuse-log retention is not stated on the official pages fetched. A third-party tracker says 55 days, unconfirmed, and it is separate from the 55-day default of the developer-visible logs.
- fal's CDN media default lifetime and data-URI input support were not confirmed from a primary page in this session.
- Canadian PHIPA/PIPEDA implications of sending pill or hand images abroad were not researched here (see the earlier notes' gap).
