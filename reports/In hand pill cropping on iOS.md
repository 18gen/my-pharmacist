# Lift, check and enlarge every pill crop

The best way to crop each pill for My Pharmacist on iOS 17 is a four-part pipeline, and the order matters. **First, fix capture**: the app very likely gets 1920×1080 stills today, about 12 px/mm on the pill. **Second, keep Apple's zero-training subject lifting** (`VNGenerateForegroundInstanceMaskRequest`) as the detector. **Third, wrap it in a validation layer that has to explain every blob.** That layer adds a hand-pose palm region, a per-photo skin-difference cross-check, a size-independent merge test (two touching pills have solidity ≈ 0.88, one pill ≈ 0.97–1.0) and a tiled second pass when the hand swallows the pills. Anything it cannot explain becomes an abstention, not a crop. **Fourth, send square, neighbour-dimmed, long-axis-horizontal context crops**, resampled to 384–512 px with an explicit `detail` setting, plus one small numbered overview. The patient then confirms "we found N pills". Train a single-class RF-DETR Seg-Small detector (Apache-2.0, native Core ML export) only if a one-afternoon on-device test shows subject lifting failing on palms. Use SAM 3 in the cloud as a validator, never as ground truth. Cropping is the safety-critical step, more than identification. OpenAI's three-way verdict (due now, registered but not scheduled, not registered) can only be as complete as the set of crops. A pill that is never cropped, or two pills fused into one crop, becomes a silent false "all good" that no model downstream can catch. Nobody has published a benchmark of pills on palms. Every threshold below is a starting point to tune on the team's own labelled photos, and the plan is built so that the first experiment produces those numbers.

## Today's stills are probably 1080 px wide, so the thresholds in the notes need rescaling

The notes disagree on the starting point, and the disagreement changes almost every pixel threshold. The post-processing research assumed a 12 MP 4:3 still, about 34.6 px/mm. The capture research read `CameraSession.swift` against Apple's documentation and found that the session uses `sessionPreset = .high` and a bare `AVCapturePhotoSettings()`. Nothing sets `maxPhotoDimensions`. Apple documents that this property "defaults to the smallest dimensions returned by `supportedMaxPhotoDimensions`" ([Apple](https://developer.apple.com/documentation/avfoundation/avcapturephotosettings/maxphotodimensions.md)). Apple also says "only the photo preset supports 24 and 48 megapixel photos" ([WWDC26 304](https://developer.apple.com/videos/play/wwdc2026/304/)). With `.high` selecting a 1080p video format, the most likely still is **1920×1080, or 1080 px across the portrait frame**. Both premises are documented. The conclusion is not verified on a device. One log line of `photo.resolvedSettings.photoDimensions` in the capture delegate, which Apple describes as "the size, in pixels, of the photo image... that the capture delivers" ([Apple](https://developer.apple.com/documentation/avfoundation/avcaptureresolvedphotosettings/photodimensions.md)), settles it. That log line is the first task in the plan. Until it runs, this report treats 1080 px as the working assumption and gives the 12 MP figures alongside.

`startingZoom` frames a 70 mm spread at 80% of a 16:9 portrait width, so the frame is about **87.5 mm wide** whatever the resolution. Two kinds of threshold then behave differently. **Area fractions depend only on the frame's aspect ratio**, which sets the frame's area in mm². **Pixel thresholds depend on resolution.** A 16:9 portrait frame is about 87.5 × 156 mm (≈ 13,600 mm²). The 4:3 frame the post-processing notes assumed is 87.5 × 117 mm (≈ 10,200 mm²). So every fraction they quote shrinks by about 25% for today's capture. The pixel figures shrink to about 36% (12.3 ÷ 34.6).

| Quantity (frame ≈ 87.5 mm wide) | Today, likely: 1080×1920, 16:9 | 12 MP 4:3 (post-processing notes' assumption) |
|---|---|---|
| Output px/mm | **12.3** | 34.6 |
| 6 mm / 9 mm round tablet, diameter | ~74 / ~111 px | ~207 / ~311 px |
| 6 mm round, share of frame | 0.21% | 0.28% |
| 9×4.5 mm oval | 0.23% | 0.31% |
| 9 mm round | 0.47% | 0.62% |
| Two touching 9 mm rounds | 0.93% | 1.25% |
| Fingernail (~10×12 mm) | 0.69% | 0.92% |
| Current `minimumArea` 0.04% | ≈ 5.4 mm² (a ~2.6 mm disc), ~830 px | ≈ 4.1 mm², ~4,900 px |
| Current `maximumArea` 12% | ≈ 1,630 mm² (~40×40 mm of skin) | ≈ 1,225 mm² (~35×35 mm) |
| 1.5 mm imprint character | ~18 px | ~52 output px, but only ~20 real px (see below) |
| Today's crop (25% pad, `jpeg(maxSide: 384)` never upscales) | **~110–170 px sent** | ~310–470 px, capped at 384 |

Under both assumptions, today's 0.04%–12% window admits fused pairs, triples and fingernails. At today's capture it also admits a 40 mm patch of skin. The window does no harm on its own, but it is not a validator. The pixel-denominated rules in the notes need restating in millimetres and converting at runtime with `px/mm = imageWidth ÷ 87.5`. Without that, they silently break when capture changes:

- The morphology radius (≈ 0.05 × pill diameter) is ~10 px at 34.6 px/mm but **~4 px today**.
- The watershed h-maxima height (≈ 0.2 × minor semi-axis) is 15–20 px at 34.6 px/mm but **~6–7 px today**.
- The rule "require the pill ≥ ~150 px across in the source" would reject **every normal pill today**, since a 9 mm tablet is ~111 px.

The 12 MP column is also less of an upgrade than it looks. The 34.6 figure counts *output* pixels. At the app's ~1.5–1.9× digital zoom, a binned 12 MP readout carries only **~13.6–17.3 real px/mm**, about 10% more detail than the 1080p still. Apple warns that zoom works "by cropping around the center... the device must scale the cropped image up to the output size, resulting in a loss of image quality" ([Apple](https://developer.apple.com/documentation/avfoundation/avcapturedevice/videozoomfactor.md)). The real gain needs a full-resolution 48 MP readout, about **27–35 real px/mm**: a 7 mm pill gets ~190–240 px and an imprint character ~40–51 px. That means `.photo` plus the largest `supportedMaxPhotoDimensions`, or zoom snapped to a `secondaryNativeResolutionZoomFactors` value. Apple says those factors let devices "switch their pixel sampling mode dynamically to produce high-fidelity images without upscaling" ([Apple](https://developer.apple.com/documentation/avfoundation/avcapturedevice/format/secondarynativeresolutionzoomfactors.md)). A practitioner team doubled its still resolution simply by moving from a video preset to `.photo` ([Brickit Engineering](https://medium.com/brickit-engineering/how-we-doubled-the-photo-resolution-from-flutter-camera-on-ios-e17004cd0b74)). 48 MP Quad sensors start with iPhone 14 Pro ([WWDC26 304](https://developer.apple.com/videos/play/wwdc2026/304/)). On iPhone 13 and 14 non-Pro, ~14–17 real px/mm is the ceiling. So the gate should be a **hard floor of ≥ 16 real px per imprint character** (about 11 px/mm), not a fixed pill width.

Why imprints set the bar: in the only controlled GPT-4 pill study, every error was an imprint-digit misread ([PMC11391868](https://pmc.ncbi.nlm.nih.gov/articles/PMC11391868/)). Classical OCR "will produce very poor OCR return" at an 8–12 px x-height and prefers 20–40 px ([iDigBio](https://www.idigbio.org/node/106)). Early VLMs' accuracy "sharply decreases when the height is smaller than 7 pixels" ([LLaVAR](https://arxiv.org/pdf/2306.17107)). Debossed, same-colour imprints have far less contrast than ink, so today's ~18 px characters are borderline. Memory is the cost of 48 MP. A decoded 48 MP bitmap is ~195 MB, and `upright()` makes a second full-size copy through `CIContext.createCGImage`. The safe pattern is to keep the HEIC/JPEG bytes and run Vision on a ~2048 px thumbnail from `CGImageSourceCreateThumbnailAtIndex`. Each pill is then cropped from the full-resolution decode, and only the small crop is rotated.

Resolution matters less to the segmenter than to OpenAI. Apple's subject-lifting network resamples every image to **512×512** ([Apple ML Research](https://machinelearning.apple.com/research/salient-object-segmentation)). A pill's size *inside the network* therefore depends only on framing and aspect ratio, never on megapixels. If 512 spans the frame width, a 6–9 mm pill is ~35–53 network px. If the 16:9 frame is letterboxed on its long side, it is only ~20–30 px. On 4:3 `.photo` frames it is ~26–39 px. Apple does not document whether the input is letterboxed or squashed. Moving to `.photo` therefore also gives pills about 30% more network pixels under letterboxing, and tiling (below) gives 2–3× more under either scheme.

## Subject lifting is a usable detector only when wrapped in failure detection

Apple's own documentation explains why `PillFinder` cannot be trusted alone. The model is class-agnostic. Apple says "the man and his dog together are the focal point of the image, making them one combined subject" ([WWDC23 10176](https://developer.apple.com/videos/play/wwdc2023/10176/)). It also says that when "the framework can't separate overlapping objects... a subject may consist of two or more objects" ([Apple](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/subject)). A confidence gate can suppress output entirely ([Apple ML Research](https://machinelearning.apple.com/research/salient-object-segmentation)). Three palm failures follow, all plausible by design and none measured by anyone:

- **Absorbed pills.** The hand and its pills come back as one instance, which the 12% cap then discards along with the pills.
- **Merged pills.** Touching pills come back as one subject.
- **No result at all.** When skin fills the frame, the request may return nothing.

The current code makes the third failure invisible. `PillPhotoAnalyzer.findPills` returns `(try? PillFinder.find(in:)) ?? []`, and `find` returns `[]` when `results` is nil. A Simulator inference failure ([Forums 764948](https://developer.apple.com/forums/thread/764948)), an empty observation and a genuinely empty palm all look like "0 pills". These need distinct outcomes: `.unsupported`, `.noSubject` and `.noPills`. The model has had no new revision since iOS 17: `GenerateForegroundInstanceMaskRequest.Revision` still lists only `.revision1` ([Apple](https://developer.apple.com/documentation/vision/generateforegroundinstancemaskrequest/revision-swift.enum)), so its behaviour will not improve on its own.

### Workarounds that change what the model sees as background

Cropping to the hand alone does little, because the app's framing is already a palm close-up. What helps is making skin the dominant background. The plan uses four mechanisms, all built from iOS 14–17 APIs.

**Hand pose.** `VNDetectHumanHandPoseRequest` with `maximumHandCount = 1` ([Apple](https://developer.apple.com/documentation/vision/vndetecthumanhandposerequest/maximumhandcount)) gives a palm polygon from the wrist, thumb CMC/MP and four MCP joints, dilated by ~15%. The polygon decides palm mode or table mode, rejects instances outside the palm, and gives skin pixels to sample. Fingertip joints define ~8 mm exclusion discs against fingernails, the worst false positive.

**Conditional tiled pass.** Run the request on 2×2 or 3×3 tiles of the palm box with ~30% overlap, each tile at least 2.5× the expected pill length. Use explicit `CGImage.cropping(to:)` with a new handler for each tile. Do not use `regionOfInterest`: it has a lower-left origin, and Apple does not document whether the masks it produces are in ROI space or full-image space ([Apple](https://developer.apple.com/documentation/vision/vnimagebasedrequest/regionofinterest)). De-duplicate tile results by IoU > 0.3 or centre distance. Trigger the tiled pass only when the full-frame pass returns an instance over ~12% that overlaps the palm, or disagrees with the cross-check.

**Per-photo skin-difference cross-check.** This is an independent second detector:

1. Sample this person's skin, or this table, inside the ROI with `CIKMeans`.
2. Fit a chroma Gaussian in Lab using `convertRGBtoLab` (iOS 16).
3. Mark pixels more than ~3.5σ from it.
4. Clean up with an open and a close, then connected components.

Weight chroma heavily and lightness loosely. In 1,204 face images, "the chrominance values do not appear different for individuals with light or dark skin type … Practically all the variation in skin type is captured by the Y channel alone" ([Muthukumar et al.](https://arxiv.org/pdf/1812.00099)). This avoids fixed rules such as the RGB test `R > 95` ([Choraś 2008](https://www.scitepress.org/Papers/2008/19390/19390.pdf)), whose absolute brightness gate penalises dark skin and dim light.

**Contrast gate.** If the median ΔE between a pill and the ring of skin around it is below ~12, the boundary is untrustworthy, and the app says "put the pills on a sheet of white paper". The closest published classical method got acceptable masks for 82.1% of pills on NLM consumer photos. It failed mainly where pills "merged completely into the background" ([SciTePress 2017](https://www.scitepress.org/Papers/2017/61358/pdf/index.html)). That is exactly the beige-pill-on-matching-skin case, and the gate turns it into an explicit abstention. White backgrounds also gave the best smartphone pill-ID accuracy in a controlled study ([PMC8367115](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC8367115/)). That supports making paper the recommended mode and the palm the convenience mode. Report the abstention rate per skin tone, because abstaining more often for some users is still a fairness failure.

### Merge detection and splitting

**Solidity** (area ÷ convex-hull area) is the strongest merge cue because it does not depend on size. Two tangent circles give 2π/(4+π) ≈ 0.880. Solidity is affine-invariant, so any equal pair of ellipses touching side by side or end to end gives the same value. Single tablets should score 0.95–0.99 once mask noise is counted. Flag a blob when any of these holds:

- solidity < 0.93;
- the deepest convexity defect exceeds 0.15 × the equivalent radius;
- the ellipse-fit residual exceeds 0.10 × the minor semi-axis;
- the area is more than 1.6× a trusted single-pill area, preferably the registered medications' known sizes rather than the median, since 6 mm and 9 mm pills differ by more than 2× in area.

The shape tests run on the refined full-resolution mask, not on the low-resolution `instanceMask`. Heart- or triangle-shaped registered meds go on a whitelist, because their own outlines fail the convexity tests.

**Splitting** uses marker-controlled watershed on the distance transform, seeded by per-blob h-maxima (h ≈ 0.2 × the expected minor semi-axis in px, so ~6–7 px today). Do not use OpenCV's global `0.7 × DT.max()` ([OpenCV tutorial](https://github.com/opencv/opencv/blob/4.x/doc/py_tutorials/py_imgproc/py_watershed/py_watershed.markdown)): a global fraction erases the seeds of smaller pills when sizes are mixed. Suppressing shallow minima is the standard defence against over-segmentation ([MathWorks](https://www.mathworks.com/help/images/ref/watershed.html)). Accept a split only if every part passes the single-pill tests and the cut is no longer than ~1.2 × the minor axis. Otherwise say "spread the pills apart". The open-source counter count-drug takes the same refuse-and-warn stance on non-integer area ratios ([count-drug](https://github.com/kien-ly/count-drug)). Clusters of three or more go straight to "spread them out" in v1.

On iOS 27 devices, `GenerateIterativeSegmentationRequest` can split flagged merges and segment user-tapped misses. It takes a seed point or box, with at most 13 include/exclude points (11 with a box), and needs a model download through `DownloadableAssetsRequest` ([Apple](https://developer.apple.com/documentation/vision/generateiterativesegmentationrequest); [WWDC26 237](https://developer.apple.com/videos/play/wwdc2026/237/)). Gate it with `#available` and fall back to the iOS 17 path.

### Refinement and rejection

Each instance's mask is a location prior, not a boundary. Upsample it inside a 30%-padded box with `generateScaledMaskForImage` or `CIEdgePreserveUpsample`. Build a trimap and classify the uncertain band with Lab colour models. If the refined mask and the prior overlap at IoU < 0.75, flag the instance. Geometry comes from the refined mask: centroid, principal axis from second-order moments, and major and minor axes in mm.

Other rejections:

| Candidate | Rejection rule |
|---|---|
| Creases | thin: maximum distance-transform value < 0.3 × expected minor semi-axis |
| Glare | more than half the blob's pixels at V > 0.92 and S < 0.12 |
| Rings | specular and elongated |
| Partial pills | mask within 1% of the frame edge: ask to recentre |
| Out-of-range sizes | outside 0.7× the smallest to 1.3× the largest registered medication dimension |

Almost all of this is native at iOS 17. Core Image covers Lab conversion, k-means, Otsu, morphology, Sobel and Canny (iOS 17). `MPSImageEuclideanDistanceTransform` (iOS 11.3) gives an exact distance transform ([Apple](https://developer.apple.com/documentation/metalperformanceshaders/mpsimageeuclideandistancetransform)). That corrects earlier notes, since Core Image's own distance filters need iOS 26. Connected components, h-maxima, watershed, convex hull and ellipse fitting are small pure-Swift functions on per-blob crops. OpenCV through `yeatse/opencv-spm` (Apache-2.0; the 5.1.0 Core tier zip is 125 MB) is worth adding only for GrabCut ([releases](https://github.com/yeatse/opencv-spm/releases)). Measure its effect with an App Thinning Size Report before committing.

## A trained detector earns its place only if the palm test fails

If palms defeat subject lifting even with tiling, **RF-DETR is the one licence-clean, maintained option with masks and native Core ML export**:

- **Licence:** detection Nano–Large and every segmentation size are Apache-2.0. Atto, Femto, Pico, XL and 2XL detection fall under PML ([rf-detr](https://github.com/roboflow/rf-detr)).
- **Export:** `model.export(format="coreml", coreml_precision="float16")` targets iOS 15. The export is labelled "experimental". Only fp16 reaches the Neural Engine. The input is a normalised float tensor rather than an image unless it is wrapped ([coreml.md](https://raw.githubusercontent.com/roboflow/rf-detr/develop/docs/exports/coreml.md)).
- **Speed:** measured only on Macs (Nano fp16 ≈ 18–25 ms on M3 Pro/M4 Max ANE). Community iPhone reports are ~10–15 fps on the GPU in fp32.
- **Why it suits touching pills:** it is a set predictor with no NMS, so it cannot suppress one of two overlapping true pills.

The alternatives fall short:

- **Create ML Object Detection** gives boxes only, but it is the zero-conversion baseline. Apple says transfer learning "does well with as few as 80 training examples per class" ([Tech Talk 10155](https://developer.apple.com/kr/videos/play/tech-talks/10155/?time=764)).
- **Ultralytics YOLO and YOLOE** are AGPL-3.0, which Ultralytics extends to trained weights ([Ultralytics](https://www.ultralytics.com/license)).
- **DEIMv2 and EdgeSAM** are non-commercial ([DEIMv2](https://raw.githubusercontent.com/Intellindust-AI-Lab/DEIMv2/main/LICENSE.md); [EdgeSAM](https://raw.githubusercontent.com/chongzhou96/EdgeSAM/master/LICENSE)).
- **On-device open-vocabulary "pill" detection** is not ready on iOS 17 with a commercial-safe licence. EfficientSAM3's Core ML export is "coming soon" ([EfficientSAM3](https://huggingface.co/Simon7108528/EfficientSAM3)).

For input, take a centre-square crop of the still at 576–640 px (a multiple of 32 for detection or 24 for segmentation). That lifts a 7 mm pill from ~38 to ~51 px compared with letterboxing. Do not tile at this stage. SAHI-style gains come from tiny aerial objects ([arXiv 2202.06934](https://arxiv.org/abs/2202.06934)), and tile seams manufacture exactly the duplicates and merges this pipeline must avoid.

Data is the binding constraint, because **no public pills-in-palm segmentation set exists with a clean licence**:

- **ePillID** is single-pill 224 px crops, "for research purposes only" ([ePillID](https://github.com/usuyama/ePillID-benchmark)).
- **VAIPE** has in-hand multi-pill boxes, but its licence is "Unknown" ([PLOS ONE](https://journals.plos.org/plosone/article?id=10.1371%2Fjournal.pone.0291865)).
- **MEDISEG** is CC BY 4.0 with polygon masks and touching pills, but in dosette boxes ([arXiv 2603.10825](https://arxiv.org/html/2603.10825)).

The precedent for filling the gap is synthetic. Microsoft Research trained a pill localiser **only** on 100,000 copy-paste composites of NIH reference pills: 1–5 pills, 360° rotation, 20–50 px, 0–20 px shadows. That localiser supported 94% top-5 identification on real photos ([npj Digit Med 2019](https://europepmc.org/article/PMC/PMC6550183)). Separately, synthetic data plus only 10% real data beat all-real training across domains ([Cut, Paste and Learn](https://arxiv.org/abs/1708.01642)).

A realistic recipe for this app:

1. Generate 5k–20k composites of ePillID cut-outs, the team's paper demo pills and a few OTC tablets on 50–150 self-shot empty palms and tables.
2. Make 20–30% of images contain touching pairs.
3. Add unlabelled hard negatives: nails, rings, coins.
4. Fine-tune on 150–300 hand-labelled real photos.
5. Test on a frozen 100-photo set.

Label with self-hosted CVAT or Label Studio with SAM assistance, because palm photos carry palmprint detail. ePillID-derived weights stay research-only until legal review.

## Crops should be square, dimmed around the pill, enlarged, and paired with an overview

The packaging evidence favours one image per pill:

- Training-free cropping "significantly improve[s]" MLLM accuracy on detail-sensitive tasks ([Zhang et al., ICLR 2025](https://arxiv.org/pdf/2502.17422)).
- Closed models "generally perform worse on composite images than when directly inputting multiple individual images" ([RealBench](https://arxiv.org/pdf/2509.17421)), so contact sheets are out.
- Set-of-Mark numbering lets GPT-4V ground references to marked regions ([SoM](https://arxiv.org/abs/2310.11441)). That justifies **one small numbered overview**: the pills' union box plus 10% margin, ≤ 1024 px, skin dimmed, numerals drawn outside each pill, at roughly 600–900 tokens.

The overview turns counting into a local question: "report any pill-like object with no number." That is safer than a scalar count. In CountQA the best model got only 60.3% exact counts for 1–5 objects ([CountQA](https://arxiv.org/html/2508.06585v2)), and OpenAI says "the model may give approximate counts" ([OpenAI](https://developers.openai.com/api/docs/guides/images-vision)). A cloud count may add uncertainty. It must never raise confidence.

Within each crop:

1. **Centre** on the refined-mask centroid.
2. **Size** the square side at 1.4–1.5× the major axis. The current `surroundingCrop` follows the box's aspect ratio and shifts the pill off-centre at the frame edge.
3. **Rotate** pills with aspect ≥ 1.25 so the long axis is horizontal, because OpenAI's models "may misinterpret rotated or upside-down text". Leave round tablets alone, and tell the model imprints may be upside down.
4. **Suppress neighbours.** Dim or blur pixels outside the pill's dilated mask, so a touching neighbour cannot be the pill the model describes. Fine-grained visual prompting found "blur reverse mask" the best visual prompt, though in CLIP-style models ([FGVP](https://arxiv.org/abs/2306.04356v2)). Do not cut the pill hard onto grey: mask errors would then clip edges and imprints. Context padding itself has general support: 16 px of context gave R-CNN 3–5 mAP ([Girshick et al.](https://arxiv.org/abs/1311.2524)).

On size, `jpeg(maxSide: 384)` scales by `min(1, …)`, so today's ~110–170 px crops go out small. That is below the 200 px point where Anthropic warns models "might hallucinate" ([Claude Vision](https://platform.claude.com/docs/en/build-with-claude/vision)). OpenAI explicitly advises "Enlarge text within the image" for small text. Resampling each crop up to 384 (or 512 with 48 MP sources) adds no information, but it lifts each character above one 32 px patch.

Token cost on patch models is ceil(w/32)·ceil(h/32)·1.2: ~173 tokens at 384 and ~308 at 512 ([OpenAI](https://developers.openai.com/api/docs/guides/images-vision)). On `gpt-6.1-sol` ($2 / $10 per 1M) that is about $0.0003 extra per crop at 512 ([Pricing](https://developers.openai.com/api/docs/pricing)). A whole scan is about $0.015–0.03, and reasoning output dominates the bill.

Two settings need changing. Replace `"detail": "auto"` with `"high"`, or `"original"` where supported, because `auto` means `original` on GPT-6/5.6 but `high` on GPT-5.4: switching `OPENAI_MODEL` silently changes behaviour. Add `"store": false`, which `requestBody` omits. Without it, the Responses API keeps application state for 30 days by default ([OpenAI Your data](https://developers.openai.com/api/docs/guides/your-data)).

The three-way verdict should stay split as it is now. OpenAI chooses only from a closed enum, the candidate IDs plus `"none"`. Swift code then turns an ID into "due now" or "registered but not scheduled" against the dose schedule. "None" means not registered. A missing or merged crop is surfaced before any of that, as "can't confirm".

### Cloud fallbacks validate, they do not decide

When the device is unsure, or N ≥ 7, call **SAM 3** with the prompt "pill" on the cropped overview. It "detects, segments, and tracks" every matching instance with a presence head ([arXiv 2511.16719](https://arxiv.org/abs/2511.16719)). On fal it costs $0.005 per request, but `max_masks` **defaults to 3** and must be raised to ~16 or a six-pill photo is silently truncated ([fal](https://fal.ai/models/fal-ai/sam-3/image-rle/llms.txt)). Send `X-Fal-Store-IO: 0` so fal does not keep request I/O.

Match SAM 3 instances to on-device boxes at IoU > 0.5. An unmatched high-score instance triggers a retake with a specific hint. **Gemini** is the only general LLM with documented detection and segmentation (`box_2d` normalised to 0–1000, plus PNG masks), with thinking set to minimal ([Gemini](https://ai.google.dev/gemini-api/docs/image-understanding)). Its zero-shot detection is modest: 13.3 mAP50:95 for Gemini 2.5 Pro on RF100-VL ([arXiv 2505.20612](https://arxiv.org/html/2505.20612v3)). Gemini also logs Generate Content calls by default for projects created on or after 26 Oct 2026 ([Gemini logs](https://ai.google.dev/gemini-api/docs/logs-policy)). OpenAI still says its models struggle with "precise spatial localization", so it identifies crops and never places boxes.

## A five-phase plan mapped onto the existing files

Each phase ends with on-device validation, as the project guidelines require. Vision does not run in the Simulator, so the harness has to run on a device. Test photos come from a DEBUG-only, in-memory path with consenting volunteers, never the photo library.

| Phase | Change | Files | Exit check |
|---|---|---|---|
| **0. Measure (½ day)** | Log `resolvedSettings.photoDimensions`, `activeFormat.supportedMaxPhotoDimensions`, the zoom factor, the `instanceMask` width and height, per-instance area, fill ratio and solidity, and timing. Split `findPills` outcomes into `.unsupported` / `.noSubject` / `.found([FoundPill])` instead of `try? … ?? []`. Run variants V1 (current), V2 (+ hand-pose filter), V3/V4 (2×2/3×3 tiles), V5 (person-mask subtraction) and V6 (skin blobs alone) on ~40 labelled photos: 3 skin tones, palm and table, 2–10 pills, touching pairs, real tablets and paper. | `Camera/CameraSession.swift`, `PillVision/PillPhotoAnalyzer.swift`, `PillVision/PillFinder.swift`, DEBUG harness | Real still size known. Per-variant recall, merge rate, phantom rate and **flag recall** (share of misses and merges that were flagged) |
| **1. Capture** | `sessionPreset = .photo`. Set `photoOutput.maxPhotoDimensions` to the largest supported entry before `commitConfiguration()`, mirror it per shot, use `.balanced` prioritisation and `setPreparedPhotoSettingsArray`. Change `9/16` to `3/4` in `startingZoom`, and snap to a secondary native zoom factor near 2×. Keep the encoded bytes, run Vision on a 2048 px thumbnail, and crop full-resolution regions lazily. Fall back to 12 MP on high ISO or low-memory devices. | `Camera/CameraSession.swift` | ≥ 16 real px per imprint character; no memory spike; 4:3 preview framing correct |
| **2. Validation layer** | Move thresholds to mm with a runtime px/mm. Keep a loose prefilter (≈ 5–400 mm²), flag 400–1,630 mm² as a "cluster", and treat larger instances as "possible absorbed pills", which triggers tiles. Add the palm polygon, skin-difference blobs, the contrast gate, solidity, defect and ellipse tests, the reject table and reconciliation (instance ↔ blob). Every candidate carries a reason code. Extend `InstanceBoxes` to return centroid, pixel count and moments in the same pass, and add pure-Swift components, hull, ellipse, h-maxima and watershed beside it with unit tests. | `PillVision/PillFinder.swift`, `Core/Identification/InstanceBoxes.swift`, new `PillVision/PillValidator.swift` | Flag recall ≈ 100% on the Phase 0 set; abstention rate reported per skin tone |
| **3. Crops and request** | Square crops centred on the centroid, rotation, neighbour dimming and edge padding; upscale to 384–512; numbered overview as image 0; `detail` explicit; `store: false`; schema fields `unnumbered_pill_like_objects` and `pills_overlapping_or_touching`. Drop the per-instance `generateMaskedImage` cut-out, except where the feature-print fallback needs it. | `PillVision/OpenAIPillIdentifier.swift`, `PillPhotoAnalyzer.swift` | A/B on 30–50 photos: plain padded crop vs dimmed crop, rotated vs not, with vs without overview; real `usage.input_tokens` checked |
| **4. Confirmation and fallbacks** | Show numbered outlines: "We found N pills — is each outlined once?" A tap adds a crop sized to the median pill. Check the count against the due-now dose and preview-frame stability. SAM 3 validator when unsure. Iterative segmentation splits on iOS 27. Train RF-DETR Seg-Small plus a Create ML baseline only if Phase 0–2 fails on palms. | `Features/Scan/ScanFlow.swift`, scan views, optional Core ML model | Silent-failure rate on a frozen set: 0 in 300 non-abstained photos bounds it below ~1% at 95% |

The decision rule after Phase 0 is mechanical:

- If tiles plus flags catch essentially every miss and merge on palms with few phantoms, ship the Apple-native pipeline with confirmation.
- If palms fail but tables pass, make paper or table the default and the palm best-effort.
- If both fail, the one-to-two-week RF-DETR plan begins.

The headline metric throughout is the **silent-failure rate**: photos where crops were emitted but a pill was missed, merged, split or invented. Abstentions are a usability cost, not a safety failure. By the rule of three, zero failures in 100 photos only bounds the rate below about 3% ([Hanley & Lippman-Hand](https://jamanetwork.com/journals/jama/article-abstract/389714)). Per-skin-tone claims need roughly 100–300 photos per group.

## Conclusion

The research changes the question from "which segmenter?" to "which failures can the pipeline see?" No Apple API, trained model or cloud service promises one crop per pill on a palm, and Apple says outright that its segmenter may merge objects. So the design target is not perfect segmentation but perfect *flagging*: every instance is reconciled against an independent signal, and every unexplained case becomes "spread the pills" or "use paper". This also makes the first experiment cheap and decisive. It does not ask whether subject lifting works. It asks whether the validation layer catches it when it fails. That can be answered in an afternoon with no training.

The resolution reconciliation adds a second, less obvious lesson. The binding limit on imprint legibility is probably the camera configuration, not the AI, and the commonly assumed fix (asking for 12 MP) would barely help at the app's zoom. Thresholds written in pixels quietly encode an assumption about capture. Writing them in millimetres, with the scale measured at runtime, is what keeps the validation layer correct as capture improves from 1080p to 48 MP and across iPhones whose sensors differ by a factor of two.
