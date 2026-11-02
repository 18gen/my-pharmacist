# Real-time camera image-quality assessment and guided auto-capture for in-hand pill photos (iOS 17+, as of Oct 2026)

Scope note: Apple doc pages were fetched as `.md` this session (Oct 2026). Some well-known AVFoundation / Accelerate / Core Image symbols (`iso`, `exposureDuration`, `lensPosition`, `isAdjustingFocus`, `vImageHistogramCalculation_Planar8`, `CIAreaAverage`, `CIAreaHistogram`, EXIF `BrightnessValue` attachment) were **not** fetched individually because of the tool-call budget. They appear under Inferences, and someone should check them against the docs before writing code. **Every numeric threshold in these notes is an unvalidated starting point to tune on real captures**, unless a citation says otherwise.

## Lighting: which signals are cheapest and most reliable (low light, overexposure, uneven lighting)?

### Takeaway
Gate on the camera's own exposure state first, which costs almost nothing: KVO `exposureTargetOffset`, plus ISO and exposure duration read once per analysed frame. Then compute a 256-bin luma histogram on a downscaled Y plane, restricted to the pill or hand region, to separate "too dark", "clipped or too bright" and "uneven". AE metadata alone can't see uneven lighting or local clipping, because auto-exposure drives the mean back to its target.

### Cited Findings
- `AVCaptureDevice.exposureTargetOffset` is "the metered exposure level's offset from the target exposure value, in exposure value (EV) units". It is the difference between the metered exposure of the current scene and the target, it is key-value observable, and it has been available since iOS 8.0. — [Apple: exposureTargetOffset](https://developer.apple.com/documentation/avfoundation/avcapturedevice/exposuretargetoffset.md)
- Pill-recognition research on smartphones found that background colours, flash and exposure values in real-world conditions significantly affect recognition performance, and that pill colours are especially affected by lighting hue and fluorescent light. Accuracy was measured under 12 real-world conditions. The full text couldn't be retrieved (PMC returned a bot-check page), so only search-snippet-level detail is available. — [JMIR Med Inform 2021, 9(7):e26000](https://medinform.jmir.org/2021/7/e26000); [PMC8367115](https://pmc.ncbi.nlm.nih.gov/articles/PMC8367115)
- Open-source document scanners use brightness checks next to sharpness and glare checks on each frame (docuSnap), and treat low light as one input to a fused auto-capture score (scannerpro's AutoCaptureStateMachine, which includes "low-light tolerance"). — [docuSnap README](https://github.com/petermartis/docuSnap); [scannerpro AutoCaptureStateMachine](https://pub.dev/documentation/scannerpro/3.0.0/core_engine_auto_capture_state_machine/AutoCaptureStateMachine-class.html)

### Inferences
- **Recommended tiered approach:**
  1. **Metadata tier, near-free, every frame.** Read `device.iso`, `device.exposureDuration`, `device.activeFormat.maxISO` and `exposureTargetOffset`. Starting points:
     - **Low light:** ISO ≥ ~0.8 × `maxISO`, *or* exposure duration ≥ ~1/30 s with `exposureTargetOffset` < −1 EV for more than about 0.5 s. Hint: "Move to a brighter area". Long exposure at close range also predicts motion blur.
     - **Overexposed:** `exposureTargetOffset` > +1 EV persisting while ISO sits at minimum.
     - The EXIF `BrightnessValue` (APEX Bv) attached to each video `CMSampleBuffer` (via `CMCopyDictionaryOfAttachments` → `kCGImagePropertyExifDictionary`) is a second scene-brightness signal. It's widely used, but I didn't verify in this session that it's present on video data output buffers for every format. Starting point: Bv < ~0 means dim indoor light. Treat it as advisory.
  2. **Pixel tier, cheap.** Work on the Y plane of the `420YpCbCr8BiPlanarFullRange` buffer (no colour conversion). Downscale to about 320 px on the long side, or just sample every 4th pixel, and run `vImageHistogramCalculation_Planar8`. Compute:
     - Mean luma. Starting points: < 50/255 is dark, > 200/255 is bright.
     - Clipped fraction, pixels ≥ 250. Starting point: > 2–5 % in the ROI means overexposed or glare.
     - Crushed fraction, pixels ≤ 10.
     - Unevenness: split the ROI into a 3×3 or 4×4 grid of cell means. Flag when max/min cell mean is > ~2.5×, or the cell-mean coefficient of variation is > ~0.35. Hint: "Even out the lighting" or "Turn so light falls evenly". A hand casting a shadow on part of the palm is the typical failure.
  - `CIAreaAverage` and `CIAreaHistogram` work on the GPU, but they add Core Image context and render overhead. At 3 fps on a downscaled plane, vImage on the CPU is likely simpler and cheaper. This is an inference, and the cost should be measured in Instruments.
- **Measure in the ROI, not the full frame.** AE meters the whole scene, so a bright palm under a dark background can leave the pills fine while the frame mean looks dark, and the reverse can happen too. Set `exposurePointOfInterest` to the pill or hand centroid, or rely on AE and judge only the ROI histogram.

### Gaps
- No published study gives ISO, EV or Bv thresholds specifically for pill imprint legibility. The JMIR study's quantitative per-condition numbers couldn't be retrieved.
- I didn't verify whether `BrightnessValue` is reliably attached to `AVCaptureVideoDataOutput` buffers on all iPhone models.

## Blur: focus measures, motion sensors, focus state, and Apple quality APIs

### Takeaway
Combine three cheap signals:
- **Focus state.** `isAdjustingFocus == false`, with `lensPosition` stable.
- **Shake.** CoreMotion gyro rotation-rate magnitude below a threshold, or frame-to-frame stability.
- **Sharpness.** Variance of Laplacian or Tenengrad computed on the *pill ROI* at reduced resolution, compared relative to the recent maximum for the current scene rather than against an absolute constant.

Apple's ML quality APIs don't fit as per-frame gates:
- `VNDetectFaceCaptureQualityRequest` is face-only.
- `CalculateImageAestheticsScoresRequest` (iOS 18+) is an aesthetics/memorability score that only partly reflects blur and exposure.
- `DetectLensSmudgeRequest` (iOS 26+, A14+) is useful as an occasional "clean your lens" check on the captured still.

### Cited Findings
- **`VNDetectFaceCaptureQualityRequest`** (iOS 13+) produces a 0–1 `faceCaptureQuality` on a `VNFaceObservation`. Faces "closer to 1 are better lit, sharper, and more centrally positioned". It is face-specific and doesn't apply to pills. — [Apple: VNDetectFaceCaptureQualityRequest](https://developer.apple.com/documentation/vision/vndetectfacecapturequalityrequest.md)
- **`CalculateImageAestheticsScoresRequest`** is iOS 18.0+, a Swift-only struct in the new Vision API, and returns an `ImageAestheticsScoresObservation`. It can run on a `CVPixelBuffer` or `CMSampleBuffer` via `perform(on:)`, which is `async throws`. — [Apple: CalculateImageAestheticsScoresRequest](https://developer.apple.com/documentation/vision/calculateimageaestheticsscoresrequest.md)
  - `overallScore` is "a score which incorporates aesthetic score, failure score, and utility labels". `isUtility` marks "images that are not necessarily of poor image quality, but may not have memorable or exciting content". — [Apple: ImageAestheticsScoresObservation](https://developer.apple.com/documentation/vision/imageaestheticsscoresobservation.md)
  - In WWDC24, Apple said multiple factors "such as blur and exposure" are analysed, that the score "ranges from -1 to 1 indicating how well taken the image is", and that utility images are things "like screenshots or photos of receipts". A low-score example is an image that "doesn't have a clear focus". — [WWDC24 "Discover Swift enhancements in the Vision framework" (10163)](https://developer.apple.com/videos/play/wwdc2024/10163/)
- **`DetectLensSmudgeRequest`** is iOS 26.0+ and needs an A14 Bionic or later (or M1). It returns a `SmudgeObservation.confidence` from 0–1, where 1.0 means a high probability the lens is smudged. Apple's sample uses a threshold of `0.9`. Apple warns that "naturally-blurred objects, long exposure, and motion blur" can be classified as smudge, and says to use it "on a fixed capture where the device is stable". — [Apple: DetectLensSmudgeRequest](https://developer.apple.com/documentation/vision/detectlenssmudgerequest.md)
  - The iOS 26 Camera app itself shows a lens-cleaning hint. — [Kodeco Vision iOS 18/26 module](https://www.kodeco.com/ios/paths/apple-ai-models/49307523-vision-framework/04-unveiling-new-vision-framework-features-in-ios-18-ios-26/05); [Sir Apfelot (German)](https://www.sir-apfelot.de/reinigungshinweis-ios-26-warnt-bei-verschmutzter-iphone-kamera-65971/)
- **Focus-measure literature.** Pertuz, Puig & García, "Analysis of focus measure operators for shape-from-focus", *Pattern Recognition* 2013 (doi 10.1016/j.patcog.2012.11.011). It groups operators into gradient-based (e.g., Tenengrad, first derivatives), Laplacian-based (second derivative, e.g., variance of Laplacian) and wavelet-based families, and publishes MATLAB code. I couldn't retrieve its exact rankings. — [Pertuz project page](https://sites.google.com/view/cvia/focus-measure); [paper record](https://portal.mardi4nfdi.de/wiki/Publication:1951256)
- **Practitioner use.** Document-scanner libraries use Laplacian variance as the blur score, and one offers Tenengrad as an option, claiming it is "more robust than Laplacian". — [scannerpro ScannerOptions](https://pub.dev/documentation/scannerpro/3.0.0/core_models_scanner_options/ScannerOptions-class.html); [docuSnap](https://github.com/petermartis/docuSnap)
- **Frame-difference stability.** An Android/CameraX write-up uses RMS frame difference with a threshold of 5.0 and a debounce of 3 consecutive stable frames. It warns that a threshold set too low means the user can never capture, and too high still lets blurry scans through. — [DEV: frame stability detection with CameraX](https://dev.to/a_bitabovebytes_bd82186/stop-taking-blurry-scans-how-i-built-frame-stability-detection-for-android-with-camerax-2jh5)
- **Blur hides imprints.** The MobileDeepPill patent notes that "a blurry or out-of-focus image can hide unique characteristics such as a proprietary imprint". — [US patent 10713540 / US20180260665](https://patents.justia.com/patent/20180260665)

### Inferences
- **Recommended blur gate, all three conditions required:**
  1. **Focus settled.** KVO or poll `device.isAdjustingFocus == false`, and `lensPosition` changes by less than ~0.01 across the last 3 analysed frames. Starting point. The existing near-focus `autoFocusRangeRestriction = .near` helps.
  2. **Device steady.** Use `CMMotionManager` gyro at 30–60 Hz on its own `OperationQueue`, or `CMDeviceMotion.rotationRate` without gravity. Start with |ω| < ~0.15 rad/s averaged over the last 300 ms. Rough physics behind it: at 1/30 s exposure, 0.15 rad/s is about 0.005 rad of rotation, which is several pixels at full-resolution focal lengths. Tighten the threshold when exposure duration is long.
     - Optionally add frame-to-frame stability of the pill bounding boxes, with IoU > ~0.9 between consecutive analysed frames. This mirrors Dynamsoft's quad IoU stabilizer and also catches the hand moving while the phone is still. — [Dynamsoft QuadStabilizer tutorial](https://www.dynamsoft.com/codepool/android-document-scanner.html)
     - Hint: "Hold steady".
  3. **Sharp enough.** Compute variance of Laplacian on the ROI's Y plane, cropped to the union of pill boxes plus a margin and downscaled to about 256–384 px on the long side. Use `vImageConvolve_Planar8` with a 3×3 Laplacian kernel, then mean and variance via vDSP. Tenengrad is the alternative: Sobel `vImageConvolve` passes, then the sum of squared gradients.
     - Absolute VoL values depend on scene texture, resolution and noise. A plain white pill on a palm has little texture. So use **relative** gating: accept when the current score is ≥ ~70 % of the running max over the last ~2 s in the same framing, *and* above an absolute floor tuned on your own data. As a rough reference, about 100 is a commonly quoted VoL floor for 8-bit, roughly 500 px images in OpenCV tutorials, but it's untuned and unverified for this domain.
     - High ISO noise inflates VoL. Apply a light Gaussian blur first, or prefer Tenengrad with a noise threshold.
     - Hint: "Hold steady" when gyro is high; "Move a little farther" or "Tap to focus" when focus is settled but the score is low. The second case usually means the subject is closer than the minimum focus distance.
- Close-focus limit: when VoL stays low with `isAdjustingFocus == false` and `lensPosition` near its minimum-distance end, the pill is probably inside the minimum focus distance. That calls for "Move farther away" (and rely on zoom), not "Move closer". The existing computed starting zoom already supports this.
- **Aesthetics score is not a good per-frame gate.**
  - It's iOS 18+ while the app's floor is iOS 17, so it would need `#available`.
  - It blends aesthetic and memorability judgements. A pill-in-palm photo will probably be classed as "utility".
  - It's a full neural request, far more expensive than a Laplacian on 300 px.
  - Possible use: a one-off sanity check on the captured still. For example, reject if `overallScore` is very low (< ~−0.5, starting point), ignoring `isUtility`.
- **Lens smudge check:** run `DetectLensSmudgeRequest` (iOS 26, A14+) on the *captured still* only, and only after the device was stable. If confidence > 0.9 (Apple's sample value) across 2+ captures, suggest "Wipe the camera lens".

### Gaps
- Apple hasn't published per-factor sub-scores for the aesthetics request (blur and exposure aren't exposed separately), and gives no latency figures.
- No head-to-head data on VoL vs Tenengrad for low-texture small objects. Pertuz rankings weren't retrieved.
- VisionKit's `DataScannerViewController` and `VNDocumentCameraViewController` don't expose their internal frame-quality or auto-capture heuristics publicly. I found no Apple doc describing them, so they can't serve as quality-assessment components. This came from search; I didn't fetch their doc pages this session.

## Glare: detecting specular highlights on pills

### Takeaway
Within each pill's mask or box, compute the fraction of near-saturated, low-saturation pixels: Y ≥ ~245, and in chroma terms close to neutral. Also check whether those pixels form a compact blob. Reject or hint "Tilt to reduce glare" when the fraction is above a few percent of pill area, or when a blob overlaps the imprint region. It is cheap pixel analysis on the ROI only.

### Cited Findings
- Document-scanner libraries detect glare as a "hot-pixel fraction" and fuse it into the auto-capture score. — [scannerpro AutoCaptureStateMachine](https://pub.dev/documentation/scannerpro/3.0.0/core_engine_auto_capture_state_machine/AutoCaptureStateMachine-class.html)
- docuSnap runs a glare check per frame next to sharpness, brightness and size. — [docuSnap](https://github.com/petermartis/docuSnap)
- Flash use is one of the conditions that significantly affected smartphone pill recognition. — [JMIR Med Inform 2021 e26000](https://medinform.jmir.org/2021/7/e26000)

### Inferences
- **Algorithm, per pill box, from the downscaled Y plane plus the CbCr plane:**
  - **Specular mask:** Y ≥ 245 **and** |Cb−128| + |Cr−128| < ~20. Specular highlights are desaturated, while bright white pills are also desaturated but usually not clipped at 245+ when AE is on the pill.
  - **glareFraction** = mask pixels / pill pixels. Starting points: ≤ 2 % is OK, 2–8 % gets a "Tilt to reduce glare" hint, > 8 % blocks capture.
  - Also compute the largest connected blob, or simply the bounding box of the mask pixels. A single compact blob over the pill centre (where imprints usually sit) is worse than scattered points.
- **Coated or glossy tablets and gel caps** will always show some specular highlight. Gate on the clipped core, not on merely bright pixels, or the check will never pass. Locking exposure slightly negative also helps: set `exposureTargetBias` to about −0.3 to −0.7 EV, a starting point. It shrinks clipping on glossy pills at the cost of some noise.
- **Torch** (see the auto-capture section): turning on the torch at close range almost always creates a centred specular reflection on glossy pills. Treat glare as the main cost of the torch.

### Gaps
- I found no pill-specific glare-detection study or published thresholds.

## Framing, size, overlap, and minimum pill/imprint pixel size

### Takeaway
Derive all framing checks from the pill detector's boxes or masks, which are already computed for recognition, so they add essentially no cost:
- **Edge contact:** a box within a few pixels of the frame edge means "partly outside".
- **Pairwise IoU/IoA or mask contact:** means "touching" or "overlapping".
- **Size:** box short side as a fraction of frame, and pixels in the *full-resolution still*.

The only Apple text-size guidance is `VNRecognizeTextRequest.minimumTextHeight`, default 1/32 of image height. Imprint characters well above that relative size are safest.

### Cited Findings
- `VNRecognizeTextRequest.minimumTextHeight` is "the minimum height, relative to the image height, of the text to recognize". The default is "1/32, or 0.03125". Increasing it "reduces memory consumption and expedites recognition with the tradeoff of ignoring text smaller than the minimum height". Available since iOS 13. — [Apple: minimumTextHeight](https://developer.apple.com/documentation/vision/vnrecognizetextrequest/minimumtextheight.md)
- Document-scanner auto-capture uses a "document coverage ratio" (object area vs frame) as a gate. — [scannerpro AutoCaptureStateMachine](https://pub.dev/documentation/scannerpro/3.0.0/core_engine_auto_capture_state_machine/AutoCaptureStateMachine-class.html)
- docuSnap includes a size check. — [docuSnap](https://github.com/petermartis/docuSnap)
- MobileDeepPill localizes the pill first to remove background before recognition. — [US20180260665](https://patents.justia.com/patent/20180260665)

### Inferences
- **Edge contact:** with boxes in normalized coordinates, flag when any edge is within ~2 % of the frame border, a starting point. Hint: "Move the pills to the centre" or "Move back slightly". Use the *preview crop as displayed* (`AVCaptureVideoPreviewLayer.layerRectConverted(fromMetadataOutputRect:)` / `videoGravity`), so the hint matches what the user sees.
- **Touching or overlapping:**
  - With boxes only: flag a pair when IoU > ~0.05, or when the gap between boxes is < ~5 % of the smaller box's side. A starting point, since boxes of round pills touch before the pills do.
  - With instance masks: dilate each mask by 2–3 px and test intersection.
  - Hint: "Separate the pills".
- **Size and "move closer":** imprints are typically about 1–3 mm characters on 6–12 mm tablets (domain knowledge, not sourced here).
  - For Vision OCR via the `.accurate` path, the pixel height of the characters matters more than the relative height. Practical starting point: imprint characters ≥ ~20–30 px tall in the image fed to OCR or the classifier, and the pill's short side ≥ ~150–200 px in the full-resolution still. Both are untuned.
  - Given a 12 MP still (4032 px wide) and a 1080p analysis frame, the analysis frame shows about 1/3.7 of the still's pixels per dimension. So the still-space size equals the preview-box size × (still width / analysis width).
  - Gate "Move closer" when the largest pill's short side is < ~8–10 % of the frame's short side. Gate "Too close / move back" when the pill exceeds ~50 % or focus fails.
  - If OCR runs on a *cropped* pill region, set `minimumTextHeight` relative to the crop height (e.g., 0.1–0.2) for speed. The 1/32 default is relative to the whole image.
- **Count stability:** require the number of detected pills to stay constant over the stability window, so a pill isn't half-entering the frame at capture time.

### Gaps
- No published minimum imprint-character pixel height for pill OCR or recognition was found. Apple publishes only the relative `minimumTextHeight`.
- No sourced data on typical imprint character dimensions in mm.

## Continuous vs capture-only analysis, resolution, throttling, thermal and battery

### Takeaway
- Run only cheap checks continuously, at the current ~3 Hz or adaptively 2–5 Hz: metadata, gyro, ROI histogram, ROI Laplacian, and box geometry from the detector.
- Reserve expensive work for the captured still: full recognition, OCR, and optional aesthetics or smudge checks.
- Downscale before any pixel math, and drop frames with `alwaysDiscardsLateVideoFrames`.
- Respond to both `ProcessInfo.thermalState` and `AVCaptureDevice.systemPressureState` by lowering analysis rate and capture frame rate.

### Cited Findings
- Camera performance "is subject to several external factors, such as power usage and device temperature". At excessive pressure "the capture system automatically shuts down, causing a session interruption". Under lesser pressure the system "may automatically reduce capture quality". Apple says to KVO `systemPressureState` and reduce impact, "for example, by reducing the capture frame rate". It exposes `level` and `factors`, and has been available since iOS 11.1. — [Apple: AVCaptureDevice.SystemPressureState](https://developer.apple.com/documentation/avfoundation/avcapturedevice/systempressurestate-swift.class.md)
- `ProcessInfo.ThermalState` cases (iOS 11+), plus testing guidance via Xcode's "Test under adverse device conditions":
  - `nominal`: "within normal limits"
  - `fair`: "slightly elevated"
  - `serious`: "high"
  - `critical`: "significantly impacting the performance of the system and the device needs to cool down"
  — [Apple: ProcessInfo.ThermalState](https://developer.apple.com/documentation/foundation/processinfo/thermalstate-swift.enum.md)
- Apple's lens-smudge note implies an ML check should run on stable fixed captures, not on every frame. — [Apple: DetectLensSmudgeRequest](https://developer.apple.com/documentation/vision/detectlenssmudgerequest.md)

### Inferences
- **Policy (starting point):**

  | Thermal state / pressure | Analysis rate | Session frame rate | Other |
  |---|---|---|---|
  | `nominal` / `fair` | 3–5 Hz | 30 fps | Normal |
  | `serious` | 1–2 Hz | 15–20 fps via `activeVideoMin/MaxFrameDuration` | Disable torch; skip any ML quality requests |
  | `critical` / pressure `shutdown` | — | — | Stop the preview analysis and show "Phone is too warm" |

  Use `serious` from either signal. Observe `ProcessInfo.thermalStateDidChangeNotification`.
- **Run the cheap pixel checks only after the detector reports pills.** With no pills, show "Show the pills in your palm" and skip blur and glare work.
- **Resolution:** analyse an ROI downscaled to ≤ 384 px. At that size, histogram + 3×3 convolution + variance is roughly 150k pixel-ops per check, which is trivially cheap on the CPU at 3 Hz. Estimate only, measure with Instruments.
  - Keep the session preset and video format at 1080p or lower for the video output, and use `AVCapturePhotoOutput` for the full-resolution still.
- **Avoid copies:** lock the pixel buffer base address and use the Y plane directly as a `vImage_Buffer`. Don't create a `CGImage` or `UIImage` per frame.
- **Swift 6 concurrency:** the data-output delegate runs on the serial video queue. Keep the quality state machine confined to that queue, or use an actor fed with value-type results. Publish only small `Sendable` hint enums to the MainActor.
- **Battery:** the camera pipeline and torch dominate power draw. Analysis at 3 Hz on downscaled ROIs is minor. Stop the session promptly after capture, and auto-stop after ~60 s with no pills (starting point).

### Gaps
- No Apple-published power or latency figures for vImage vs Core Image vs Vision quality requests on current iPhones.

## Auto-capture architecture: stability window, photo settings, focus lock, torch policy

### Takeaway
Use a small state machine: `searching → adjusting (hints) → steady (N consecutive good frames, ~0.6–1 s) → capturing → validating`.
- On entering capture, lock focus and exposure at the current values.
- Fire `AVCapturePhotoOutput.capturePhoto` with `photoQualityPrioritization = .balanced`. Use `.quality` only when the scene is steady and well lit, because multi-frame fusion takes longer and is more motion-sensitive.
- Re-run the quality checks on the still and retry automatically if it fails.
- Default the torch to **off**, and offer it as a user toggle or a low-light suggestion, because of glare on glossy pills.

### Cited Findings
- `photoQualityPrioritization` (iOS 13+): techniques "which include reducing noise, preserving detail in low light, and freezing motion — can take significant processing time before the system returns a photo". The default is `.balanced`. `.speed` prioritises delivery and `.quality` prioritises "the best quality at the expense of speed". — [Apple: AVCapturePhotoSettings.photoQualityPrioritization](https://developer.apple.com/documentation/avfoundation/avcapturephotosettings/photoqualityprioritization.md); [Apple: QualityPrioritization](https://developer.apple.com/documentation/avfoundation/avcapturephotooutput/qualityprioritization.md)
- Scanner patterns:
  - **N consecutive good frames:** scannerpro has a configurable "number of consecutive stable high-quality frames required for auto capture", plus a countdown timer. — [scannerpro ScannerOptions](https://pub.dev/documentation/scannerpro/3.0.0/core_models_scanner_options/ScannerOptions-class.html)
  - docuSnap requires 10 consecutive passing frames, keeps a rolling buffer of full-resolution frames, and picks the sharpest at capture time (sharpness weighted 40 %, edge confidence 30 %). — [docuSnap](https://github.com/petermartis/docuSnap)
  - Debounce of 3 stable frames. — [DEV CameraX post](https://dev.to/a_bitabovebytes_bd82186/stop-taking-blurry-scans-how-i-built-frame-stability-detection-for-android-with-camerax-2jh5)
  - Quad IoU and area-delta stabilizer. — [Dynamsoft](https://www.dynamsoft.com/codepool/android-document-scanner.html)
- Flash presence significantly affected pill recognition performance in a smartphone study. — [JMIR Med Inform 2021 e26000](https://medinform.jmir.org/2021/7/e26000)

### Inferences
- **Stability window:** at 3 Hz, N = 3 consecutive good frames is about 1 s. At 5 Hz, use N = 4–5. Both are starting points. Also require the good state to be continuous: any failing frame resets the count. Add hysteresis so hints don't flicker, for example a condition must fail for 2 frames before its hint appears.
- **Capture sequence:**
  1. On reaching steady, lock focus and exposure: `lockForConfiguration`, `focusMode = .locked`, and optionally `exposureMode = .locked` or a custom exposure. This stops AF hunting between the last analysed frame and the still.
  2. Build `AVCapturePhotoSettings` with:
     - `flashMode = .off` by default.
     - `photoQualityPrioritization = .balanced`. Must be ≤ `photoOutput.maxPhotoQualityPrioritization`, which is set at configuration time.
     - `maxPhotoDimensions` set to the largest supported (iOS 16+ API, replaces the deprecated `isHighResolutionPhotoEnabled`). Not fetched this session, so verify.
  3. `capturePhoto(with:delegate:)`. Give haptic plus audio or VoiceOver feedback: "Photo taken".
  4. Re-run blur, glare and size checks on a downscaled copy of the still. Optionally run the smudge check on iOS 26.
  5. Unlock focus and exposure back to continuous modes. On failure, return to adjusting with the specific hint, capped at about 3 auto retries before offering a manual shutter.
- Optionally enable responsive or zero-shutter-lag capture (iOS 17 `isResponsiveCaptureEnabled` / `isZeroShutterLagEnabled` on `AVCapturePhotoOutput`). These would shrink the gap between the good frame and the still, but they weren't fetched this session, so verify availability and their interaction with `photoQualityPrioritization`.
- **Torch policy:**
  - Default off. When low light persists for more than ~2 s, show "Move to a brighter area", with a secondary "Turn on light" button.
  - If the user enables it, use a low `setTorchModeOn(level:)` (~0.3–0.5, starting point) to limit specular hotspots. The glare check then becomes the main gate, with the hint "Tilt your hand slightly".
  - Use flash for the still only if the torch is already on. Pre-flash metering on glossy close-ups tends to produce centred glare.
  - Turn the torch off when thermal state reaches `serious`.
- **Manual override:** always keep a manual shutter button, both for accessibility and for when the auto-capture thresholds are too strict.

### Gaps
- No public engineering detail from Apple VisionKit, or from commercial ID SDKs (Microblink, Onfido, Jumio), on their exact auto-capture thresholds. The sources found are open-source libraries and tutorials of mixed quality.
- I didn't fetch `isResponsiveCaptureEnabled`, `isZeroShutterLagEnabled` or `maxPhotoDimensions` docs this session.

## Accessibility: spoken guidance without overwhelming VoiceOver users; haptics

### Takeaway
Speak only *changes* in the single highest-priority hint, rate-limited to about one announcement every 2–3 s, and send them as VoiceOver announcements with a priority attribute (iOS 17+). Use a distinct haptic for "steady, capturing" and success. Don't speak continuously, and make sure hints never interrupt the "Photo taken" confirmation.

### Cited Findings
- `NSAttributedString.Key.accessibilitySpeechAnnouncementPriority` is available from iOS 17.0. It sets announcement priority on an attributed announcement string. The doc page has no further discussion text; values are `UIAccessibilityPriority` `.high` / `.default` / `.low`, per the UIKit headers, which I didn't fetch. — [Apple: accessibilitySpeechAnnouncementPriority](https://developer.apple.com/documentation/foundation/nsattributedstring/key/accessibilityspeechannouncementpriority.md)

### Inferences
- **Hint priority order (single active hint):**
  1. Too warm
  2. No pills visible
  3. Too dark / too bright
  4. Partly outside the frame
  5. Too far / too close
  6. Separate the pills
  7. Glare
  8. Hold steady

  Fix the big, slow conditions first.
- **Delivery:**
  - When VoiceOver is running (`UIAccessibility.isVoiceOverRunning`), post `AccessibilityNotification.Announcement(attributedString).post()` (SwiftUI, iOS 17) or `UIAccessibility.post(notification: .announcement, ...)`. Set `.low` priority for advisory hints, so they queue and can be dropped, and `.high` for "Photo taken".
  - When VoiceOver is off, optionally use `AVSpeechSynthesizer` behind an in-app "spoken hints" toggle, and set the audio session so it doesn't duck other audio unexpectedly. I didn't verify the SwiftUI `AccessibilityNotification.Announcement` doc URL; the fetch returned 404 at the guessed path.
- **Visual:** a persistent hint banner plus a frame-guide colour state, and check marks for each condition. Don't rely on colour alone.
- **Haptics:**
  - `UIImpactFeedbackGenerator(.light)` or SwiftUI `.sensoryFeedback(.impact, trigger:)` (iOS 17) when the state goes from adjusting to steady.
  - `.success` on capture, `.warning` on a failed post-capture check.
  - Optionally a slow "geiger" pulse that speeds up as conditions improve. Keep it off by default.

### Gaps
- No Apple HIG text specifically on guided-camera announcements was retrieved. The rate limits above are inferences.

## Hand-held vs flat-surface photography for small objects / pills

### Takeaway
Evidence is thin. Pill-recognition studies show that real-world consumer photos, taken with varied cameras, angles and lighting, are much harder than lab reference images, and that flash, exposure and background all matter. No retrieved study directly compares in-palm with on-a-table capture.

### Cited Findings
- **NLM Pill Image Recognition Challenge (2016):** consumer images came from various digital cameras, at different angles and under various lighting conditions, "akin to photos of prescription pills that the general public might take". These were matched against lab RxIMAGE references and scored by MAP. — [CCC blog: NIH Pill Image Recognition Challenge](https://cccblog.org/2016/02/15/nih-pill-image-recognition-challenge/); [Federal Register notice](https://www.govinfo.gov/content/pkg/FR-2016-01-19/pdf/2016-00801.pdf)
- **MobileDeepPill (MobiSys 2017)** targets "unconstrained" pill images. It localizes pills to remove background and uses colour, grayscale and gradient-magnitude CNN streams for robustness to real-world noise. — [MobileDeepPill DOI 10.1145/3081333.3081336](https://www.doi.org/10.1145/3081333.3081336); [patent US20180260665](https://patents.justia.com/patent/20180260665)
- **JMIR 2021:** even with professionally photographed reference images, drug-recognition accuracy in real-world conditions "was not very high". Background colour, flash and exposure value significantly affected performance. — [JMIR Med Inform 2021 e26000](https://medinform.jmir.org/2021/7/e26000)

### Inferences
- **What a palm adds:**
  - Two-body motion: phone shake plus hand tremor. So frame or box stability is needed in addition to the gyro.
  - A variable, skin-toned, textured background, which helps AF and segmentation contrast for white pills but shifts white balance.
  - Shadows from the phone at close range.
- **What a flat surface adds:** only one moving body, and a constant background.
- **Implications:**
  - Require box-IoU stability, not just gyro.
  - Consider a lock on white balance or a grey-world correction, since pill colour is sensitive to lighting.
  - Offer "Place pills on a plain surface" as a fallback hint after repeated failures.

### Gaps
- No quantitative study comparing hand-held/in-palm vs flat-surface pill photo quality or recognition accuracy was found. The JMIR full text, with its 12 condition results, couldn't be retrieved because of a PMC bot-check.
