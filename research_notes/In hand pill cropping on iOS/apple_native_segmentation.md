# Apple-native, zero-training segmentation and cropping of several small pills on a palm or table (iOS, as of Nov 2026)

Scope: Vision, VisionKit and Core Image only, on device, with an iOS 17.0 deployment target. Every availability claim below was checked against Apple's documentation JSON/Markdown endpoints (developer.apple.com/tutorials/data/documentation/…json and …/documentation/….md), fetched 2026-11-09. Statements about how the APIs behave on pills on skin are inferences unless a source says so: **I found no published test, from Apple or anyone else, of subject lifting on several small objects held in a hand.** The app's current code is `MyPharmacist/PillVision/PillFinder.swift`. It runs `VNGenerateForegroundInstanceMaskRequest` once, measures instances from the low-resolution `instanceMask`, keeps those covering 0.04%–12% of the image, and cuts each one out with `generateMaskedImage(ofInstances:from:croppedToInstancesExtent: true)`. The OpenAI step then uses a *context* crop around each box (`OpenAIPillIdentifier.surroundingCrop(of:in:)`), not the transparent cut-out.

## Q1. What subject lifting (`VNGenerateForegroundInstanceMaskRequest`, VisionKit subjects) treats as a "subject", and its known behaviour (hands, small or many objects, touching objects, resolution, determinism)

### Takeaway
Apple describes subject lifting as a class-agnostic "salient foreground" segmenter. A small internal network sees the image resampled to **512×512**, a confidence gate can suppress output entirely, and the low-resolution matte is upsampled to the photo with guided filtering. Apple's own docs say that objects the model can't separate **may be returned as one subject**, and that several objects that together form the focal point (Apple's example is a man and his dog) are deliberately **combined into one subject**. Apple documents nothing about hands, minimum object size or maximum instance count, so "hand absorbs pills" and "touching pills merge" are both plausible, by design. They must be measured on device.

### Cited Findings
**What a subject is**
- WWDC23 10176 defines it as follows: "A subject is the foreground object, or objects, of a photo. This is not always a person or a pet. It can be anything from a building, a plate of food, or some pairs of shoes." — [WWDC23 10176](https://developer.apple.com/videos/play/wwdc2023/10176/)
- The same session warns: "subjects are not always an individual object. In this example, the man and his dog together are the focal point of the image, making them one combined subject." — [WWDC23 10176](https://developer.apple.com/videos/play/wwdc2023/10176/)
- VisionKit's `ImageAnalysisInteraction.Subject` page (iOS 17.0+) says: "A single image can have multiple subjects. For example, in an image of three different coffee mugs, the framework may classify all three mugs as separate subjects. **In cases where the framework can't separate overlapping objects in a photo as individual subjects, a subject may consist of two or more objects.**" This is Apple's only official statement on merging. — [Apple docs: ImageAnalysisInteraction.Subject](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/subject)
- The request is "class agnostic. Any foreground object, regardless of its semantic class, can be potentially segmented." Instance 0 is the background, foreground instances are numbered from 1, and "Beyond being contiguously labeled, the ordering of these IDs is not guaranteed." — [WWDC23 10176](https://developer.apple.com/videos/play/wwdc2023/10176/)

**The model behind it (Apple ML Research, "Fast Class-Agnostic Salient Object Segmentation", the model used for subject lifting in Photos)**
- **Input and encoder:** the network takes an RGB image "resampled to 512×512" and uses an EfficientNet v2 variant as its encoder.
- **Output:** "a single channel alpha matte (also 512×512)", upsampled to the source resolution (the example is a 3024×4032 12 MP photo) with a content-aware method based on Guided Image Filtering.
- **Confidence gate:** a separate branch outputs a scalar confidence that the image has a salient subject, and results are shown only when it is "sufficiently high".
- **Speed and hardware:** typical network time on an iPhone 14 is "under 10 milliseconds" on the Neural Engine. Older devices use the GPU through Metal Performance Shaders, and the upsampling and matting run as Metal kernels.
- **Training and fairness:** training mixes real data with 2D/3D synthetic data and pastes foregrounds onto random backgrounds. The team "regularly checks results for fairness across factors such as gender and skin tone".
- **Limits:** the task is "inherently ill-posed" and can give "surprising results at times".
- **Not covered:** the article says nothing about how instances are formed, a maximum instance count, small objects, touching objects, hands or determinism.
— [Apple Machine Learning Research](https://machinelearning.apple.com/research/salient-object-segmentation)

**Mask outputs**
- `instanceMask: CVPixelBuffer` on `VNInstanceMaskObservation` (iOS 17.0+): "A pixel can only correspond to one instance. A 0 represents the background, and all other values represent the indices of the instances." — [Apple docs: instanceMask](https://developer.apple.com/documentation/vision/vninstancemaskobservation/instancemask)
- WWDC23 calls `instanceMask` "a single channel UInt8 buffer". `generateMask(forInstances:)` is documented as "a low-resolution mask". `generateScaledMaskForImage(forInstances:from:)` and `generateMaskedImage(ofInstances:from:croppedToInstancesExtent:)` are "high-resolution", and the scaled mask is "a single channel floating point pixel buffer containing the soft segmentation mask." With the crop flag false, "the output image resolution matches the input image"; with it true, "you get a tight crop for the selected instances." — [WWDC23 10176](https://developer.apple.com/videos/play/wwdc2023/10176/); [Apple docs: VNInstanceMaskObservation](https://developer.apple.com/documentation/vision/vninstancemaskobservation)
- Apple documents no pixel dimensions for `instanceMask`. Community code reads them at runtime with `CVPixelBufferGetWidth`/`GetHeight`. — [axiom-vision-ref (community skill)](https://lobehub.com/skills/charleswiltgen-axiom-axiom-vision-ref); [Apple docs: instanceMask](https://developer.apple.com/documentation/vision/vninstancemaskobservation/instancemask)

**VisionKit vs Vision**
- VisionKit "happens out-of-process, which has performance benefits but means the image size is limited". Vision "isn't as limited in image resolution as VisionKit." — [WWDC23 10176](https://developer.apple.com/videos/play/wwdc2023/10176/)
- `ImageAnalysisInteraction.subjects` (iOS 17.0+) is `@MainActor … Set<ImageAnalysisInteraction.Subject> { get async }`.
- `Subject.bounds` is given "in relation to the interaction view's bounds" and "will always return CGRect.zero if the interaction isn't added to the view".
- `image(for:)` is `@MainActor … async throws -> UIImage` and throws `imageUnavailable` if a subject fails.
- `ImageAnalyzer` (iOS 16.0+) has the analysis types `.text`, `.machineReadableCode` and `.visualLookUp`. Subjects become active when `preferredInteractionTypes` includes `.automatic` or `.imageSubject`.
— [Apple docs: subjects](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/subjects); [Subject.bounds](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/subject/bounds); [image(for:)](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/image(for:)); [ImageAnalyzer](https://developer.apple.com/documentation/visionkit/imageanalyzer); [AnalysisTypes](https://developer.apple.com/documentation/visionkit/imageanalyzer/analysistypes); [Subject](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/subject)

**No model updates since iOS 17**
- The request still has only `VNGenerateForegroundInstanceMaskRequestRevision1` on iOS 17. In the iOS 18+/27 Swift API, `GenerateForegroundInstanceMaskRequest.Revision` lists only `.revision1`. No newer subject-lifting model revision has been published through iOS 27. — [Apple docs: VNGenerateForegroundInstanceMaskRequest](https://developer.apple.com/documentation/vision/vngenerateforegroundinstancemaskrequest); [Apple docs: Revision](https://developer.apple.com/documentation/vision/generateforegroundinstancemaskrequest/revision-swift.enum)

**Weak anecdotal evidence (iOS 16 Photos, before instances existed, not the Vision API)**
- A user who lifted a photo of himself holding a pistol said it "did a 85% job".
- Another said "it will pull multiple subjects if they are all similar focus level".
- An iPhone 13 Pro user said "Most of the time it misses things it should get, and includes things it should not … the legs and antennae were crisp, but totally missed."
— [MacRumors forum, Oct 2022](https://forums.macrumors.com/threads/ios-16s-lift-subjects-from-background-feature-is-pretty-epic.2363951/)

**Person instance masks (the closest documented limits)**
- `VNGeneratePersonInstanceMaskRequest` "outputs up to four individual person masks, each with a confidence score". "When scenes contain many people, returned observations may miss people or combine them." Apple suggests counting faces to decide whether to fall back. No equivalent statement exists for the foreground request. — [WWDC23 111241](https://developer.apple.com/videos/play/wwdc2023/111241/)

### Inferences
**Pill size at the model's input resolution**
- The capture framing puts about 7 cm of pills across 80% of the frame width, so an upright 3024×4032 photo spans about 8.75 cm, or about 345 px/cm.
- A 6–9 mm tablet is then about 207–310 px wide at full resolution, and about 0.2–0.6% of the image area.
- If the model's 512-px input spans the frame width, a pill is about **35–53 px** wide for the network. That is not tiny for a 512×512 segmenter.
- So for this capture design, plain small-object recall is probably *not* the main risk. The main risks are semantic:
  - (a) the palm and fingers are a coherent salient object, so the "man and his dog" behaviour could fold the pills into the hand instance;
  - (b) touching pills are the "overlapping objects" case that Apple says may become one subject;
  - (c) with skin filling nearly the whole frame, the confidence gate may decide there is no single subject and return **no observation**, which the current code turns silently into "0 pills".
- It is not documented whether the 512×512 resampling preserves aspect ratio (letterbox) or squashes the 4:3 photo. Squashing would shrink pills on one axis to about 0.75×.

**Area filter**
- The current 0.04%–12% filter is about right for pills (0.2–0.6%), and a hand instance (≫12%) is correctly rejected. But **rejecting the hand instance also rejects any pills fused into it**. When a large instance exists, treat that as a "possible absorbed pills" signal rather than discarding it silently.

**Paper demo pills**
- Printed paper cut-outs have no thickness, shadow or specular highlights, so they may look less like separate 3D objects than real tablets do. Expect different results for paper and real tablets, and test both.

**Determinism**
- The network is a fixed feed-forward model, so identical input should give identical output. However, a different capture of the same scene will vary, and instance IDs are unordered by contract. Sort instances geometrically (the code already uses reading order) and never key on IDs.

**VisionKit**
- VisionKit is a poor fit for a headless pipeline. It needs a view-hosted `ImageAnalysisInteraction` on the main actor, gives bounds in view coordinates, has an out-of-process size limit and returns `UIImage` cut-outs only. Use Vision.

### Gaps
- I found no Apple or third-party measurement of: `instanceMask` dimensions; maximum instance count; minimum object size; how a hand holding small objects is split; or how touching small objects behave. The only directly relevant statements are the two Apple quotes above about "combined" and "two or more objects" subjects.
- It is undocumented whether the Vision API uses exactly the network described in the ML Research article. The article describes the Photos feature, and the Vision request is presented as the same capability, but the article does not say so.
- The confidence gate's behaviour in the Vision API (empty `results` vs. a low-confidence observation) is undocumented.

## Q2. Workarounds that make subject lifting separate pills from a hand: two-pass, tiling, regionOfInterest, person-mask subtraction, hand-pose palm ROI, contours and saliency cross-checks

### Takeaway
No workaround is documented or validated by anyone for this case, so all of them are hypotheses to test. The most promising iOS 17-compatible combination: build a hand-pose palm polygon, run subject lifting on the full image and on overlapping tiles of the palm (so skin dominates each tile and is more likely to be treated as background), and cross-check against an independent "non-skin blob" detector built with Core Image plus `VNDetectContoursRequest`. `regionOfInterest` exists on the request, but its effect on instance masks is undocumented, so explicit cropping is safer. Person segmentation is person-centric. Whether it fires on a hand alone is unknown, which makes it a cheap test but an unreliable foundation.

### Cited Findings
**(c) regionOfInterest**
- `VNImageBasedRequest.regionOfInterest` (iOS 11.0+): "The rectangle is normalized to the dimensions of the processed image. Its origin is specified relative to the image's lower-left corner. The default value is { { 0, 0 }, { 1, 1 } }." The request "will fail to perform if you set this property to a rectangle outside the normalized coordinate space." — [Apple docs: regionOfInterest](https://developer.apple.com/documentation/vision/vnimagebasedrequest/regionofinterest)
- `VNGenerateForegroundInstanceMaskRequest` and `VNGeneratePersonInstanceMaskRequest` both inherit from `VNImageBasedRequest`, so the property is available on iOS 17. — [Apple docs: VNGenerateForegroundInstanceMaskRequest](https://developer.apple.com/documentation/vision/vngenerateforegroundinstancemaskrequest); [VNGeneratePersonInstanceMaskRequest](https://developer.apple.com/documentation/vision/vngeneratepersoninstancemaskrequest)
- On iOS 18+, `GenerateForegroundInstanceMaskRequest` conforms to `ImageProcessingRequest`, "A type for image-analysis requests that focus on a specific part of an image", which has a `regionOfInterest` property. — [Apple docs: ImageProcessingRequest](https://developer.apple.com/documentation/vision/imageprocessingrequest)
- No Apple page says whether the instance mask and the `generateMaskedImage`/`generateScaledMaskForImage` outputs are expressed in ROI space or full-image space when an ROI is set. — [Apple docs: VNInstanceMaskObservation](https://developer.apple.com/documentation/vision/vninstancemaskobservation)

**(d) Person segmentation and person instance masks**
- `VNGeneratePersonSegmentationRequest` (iOS 15.0+) produces "a matte image for a person", returned as a `VNPixelBufferObservation`. It has `qualityLevel` (`.accurate`, `.balanced`, `.fast`) and `outputPixelFormat`. — [Apple docs](https://developer.apple.com/documentation/vision/vngeneratepersonsegmentationrequest); [QualityLevel](https://developer.apple.com/documentation/vision/vngeneratepersonsegmentationrequest/qualitylevel-swift.enum)
- `VNGeneratePersonInstanceMaskRequest` (iOS 17.0+; Swift `GeneratePersonInstanceMaskRequest` on iOS 18.0+) returns `VNInstanceMaskObservation` for up to 4 people. Apple's crowd-handling advice relies on face detection. — [Apple docs](https://developer.apple.com/documentation/vision/vngeneratepersoninstancemaskrequest); [GeneratePersonInstanceMaskRequest](https://developer.apple.com/documentation/vision/generatepersoninstancemaskrequest); [WWDC23 111241](https://developer.apple.com/videos/play/wwdc2023/111241/)
- I found no source on whether either request segments an isolated hand with no body or face in frame. A community reference notes the person request returns a single mask for all people, and suggests combining a subject mask with hand pose to build an exclusion mask. That suggestion is unvalidated. — [axiom-vision (community skill)](https://agentskills.so/skills/charleswiltgen-axiom-axiom-vision)

**(e) Hand pose**
- `VNDetectHumanHandPoseRequest.maximumHandCount` (iOS 14.0+): "The request orders detected hands by relative size, with only the largest ones having key points determined. The default value is 2." — [Apple docs](https://developer.apple.com/documentation/vision/vndetecthumanhandposerequest/maximumhandcount)
- The Swift `DetectHumanHandPoseRequest` (iOS 18.0+) has `maximumHandCount`, `supportedJointNames` and `supportedJointsGroupNames`, and returns `HumanHandPoseObservation`. — [Apple docs](https://developer.apple.com/documentation/vision/detecthumanhandposerequest)

**(f) Contours and saliency**
- `VNContoursObservation` (iOS 14.0+) provides `contourCount`, `topLevelContours`, `normalizedPath` and `contour(at:)`. `VNContour` provides `normalizedPoints`, `aspectRatio`, `childContours` and `polygonApproximation(epsilon:)` (Ramer–Douglas–Peucker). — [Apple docs: VNContoursObservation](https://developer.apple.com/documentation/vision/vncontoursobservation); [VNContour](https://developer.apple.com/documentation/vision/vncontour); [polygonApproximation](https://developer.apple.com/documentation/vision/vncontour/polygonapproximation(epsilon:))
- `VNGeometryUtils` (iOS 14.0+) offers `boundingCircle(for:)`, `calculateArea(_:for:orientedArea:)` and `calculatePerimeter(_:for:)`. — [Apple docs: VNGeometryUtils](https://developer.apple.com/documentation/vision/vngeometryutils)
- `DetectContoursRequest` (iOS 18.0+) has `contrastAdjustment`, `contrastPivot`, `detectsDarkOnLight` and `maximumImageDimension`. — [Apple docs](https://developer.apple.com/documentation/vision/detectcontoursrequest)
- WWDC23: saliency maps "are at a fairly low resolution and as such, not suitable for segmentation". — [WWDC23 10176](https://developer.apple.com/videos/play/wwdc2023/10176/)
- `salientObjects` is "lazily" computed, and "The objects in this array don't follow any specific ordering". — [Apple docs: salientObjects](https://developer.apple.com/documentation/vision/vnsaliencyimageobservation/salientobjects)
- Per the earlier notes, the saliency heat map is 64×64 in real time and 68×68 deferred. — [Apple docs: VNSaliencyImageObservation](https://developer.apple.com/documentation/vision/vnsaliencyimageobservation)

### Inferences
**(a) Two-pass "lift, crop the hand, lift again"**
- This helps mainly when the hand is small in the frame. With the app's 3× zoom framing the photo is already a palm close-up, so cropping to the hand changes little.
- What *does* change the model's view is making skin the dominant, featureless "background". That points to tiling or to an even tighter crop, not a hand crop.
- Keep pass 2 only as a fallback when pass 1 returns one big instance (>12%) overlapping the palm and fewer pill-sized instances than the cross-check detector finds.

**(b) Tiling**
- Split the palm bounding box (from hand pose, or the whole frame) into a 2×2 or 3×3 grid of tiles with about 30% overlap. Each tile side should be at least 2.5× the expected pill length, so every pill fits whole in at least one tile.
- Run the request on each tile (a separate `VNImageRequestHandler(cgImage: tile)`).
- Map instances back to photo coordinates, discard instances touching a tile edge unless no other tile contains them whole, and de-duplicate by IoU > 0.3 or by centre distance under half the median pill size.
- Benefits:
  - the 512-px network sees each pill 2–3× larger;
  - each tile is mostly palm skin, so pills become the salient subjects;
  - touching pills get more pixels to be split on.
- Cost: 4–9 extra inferences at under 10 ms of network time each, plus upsampling. That is acceptable for a one-shot capture.
- Risks: a tile containing only skin and creases may return phantom "subjects" (creases, fingertips). The area, shape and colour filters plus the cross-check below must reject them.

**(c) regionOfInterest vs. explicit crop**
- Use `CGImage.cropping(to:)` plus a new handler instead of `regionOfInterest`. The coordinate space of the outputs is then unambiguous, `generateMaskedImage` works on the crop's handler, and you control resolution.
- If you try `regionOfInterest`, remember it is normalized with a **lower-left origin**, and verify on device whether `instanceMask` covers the ROI or the full frame.

**(d) Person-mask subtraction**
- The idea: pills = (all foreground instances ∪ non-skin pixels) − person mask, restricted to the palm.
- This works only if the person request fires on a hand alone and labels held pills as "not person". Both are unknown and cheap to test: run `VNGeneratePersonSegmentationRequest(qualityLevel: .accurate)` on 10 palm photos and look at the mask.
- If it works, it is the most elegant hand remover. If it returns empty or patchy masks for hands without a body, drop it.
- `VNGeneratePersonInstanceMaskRequest` is less likely to help: it is designed and documented around whole people and faces.

**(e) Hand-pose palm polygon (most robust ROI)**
- Build the polygon from `.wrist`, `.thumbCMC`, `.thumbMP`, `.indexMCP`, `.middleMCP`, `.ringMCP`, `.littleMCP` (`VNHumanHandPoseObservation.JointName`). Dilate it by about 15% and use it to:
  - crop or tile;
  - reject subject-lifting instances whose centre is outside it (fingertips, sleeve, background clutter);
  - sample skin colour from pixels inside the polygon that are not covered by candidate pills.
- Set `maximumHandCount = 1`.
- Fall back to the whole frame when no hand is detected (table mode). Pills lying on the palm might degrade the joint estimates; test this.

**(f) Independent cross-check detector (needed for safety, iOS 14+)**
1. Downscale the photo to about 1024 px long side.
2. Compute per-pixel colour distance from the sampled skin colour in a chroma space (e.g. YCbCr, or Lab a*/b*, plus a lightness term so white pills stand out) with a small `CIColorKernel`/Metal kernel or vImage.
3. Threshold, using Otsu over the palm region.
4. Clean up with morphology: an open, then a close.
5. Run `VNDetectContoursRequest` on the binary image, or a CPU connected-components pass.
6. Keep contours of pill-like area. Compute circularity `4πA/P²` with `VNGeometryUtils.calculateArea`/`calculatePerimeter`, and convexity from `polygonApproximation`. Two touching pills show as one blob with low convexity or circularity and about 2× the median area.

This detector is weak where pill colour matches skin (beige or pink tablets on matching skin, white pills on very light skin under warm light). It is a *cross-check*, not the primary detector.

**Saliency**
- `VNGenerateObjectnessBasedSaliencyImageRequest` boxes from a 68×68 map would cover a pill with only about 5–7 cells, so touching pills merge. They are useful at most as a coarse "pill cluster" box, or as a sanity check that something non-skin is in the palm.

### Gaps
- I found no evidence that anyone has tried tiling or two-pass subject lifting on small objects. Recall and phantom-subject rates are unknown.
- Person segmentation on isolated hands is unverified in any source found.
- The effect of `regionOfInterest` on instance-mask outputs is undocumented.
- Exact iOS availability of Core Image `CIColorThresholdOtsu`/`CIColorThreshold` could not be confirmed from Apple's JSON in this session (the pages returned no availability data). The earlier notes cite iOS 14+ without a source.

## Q3. iOS 18 Swift-native Vision API and new capabilities from WWDC24, WWDC25 and WWDC26 (iOS 18, 26, 27): what runs on iOS 17 and what needs `#available`

### Takeaway
On iOS 17 you have the `VN*` classes only. iOS 18 adds Swift-native `Sendable` structs with async `perform` and a convenient `instanceAtPoint(_:)`, but no new capability for this problem. iOS 26 (WWDC25) added document and lens-smudge requests, not segmentation. **iOS 27 (WWDC26) adds the first genuinely new tool for this problem: `GenerateIterativeSegmentationRequest`**, promptable segmentation seeded by a point, box or scribble, with include/exclude refinement points (at most 13 points, or 11 with a box). It needs a model download through `DownloadableAssetsRequest`. It can split touching pills *if* you can supply one seed per pill. Foundation Models gained image input on iOS 27, but nothing documents it returning object locations.

### Cited Findings
**iOS 18 Swift-native API**
- `GenerateForegroundInstanceMaskRequest` (a struct) is available on iOS 18.0+, macOS 15+, visionOS 2+ and watchOS 27+. It returns `InstanceMaskObservation`, has `perform(on:orientation:)` overloads for URL, Data, CGImage, CVPixelBuffer, CMSampleBuffer and CIImage, and offers only `Revision.revision1`. — [Apple docs](https://developer.apple.com/documentation/vision/generateforegroundinstancemaskrequest); [Revision](https://developer.apple.com/documentation/vision/generateforegroundinstancemaskrequest/revision-swift.enum)
- `InstanceMaskObservation` (iOS 18.0+) is a struct conforming to `Sendable`, `Codable`, `Hashable` and `VisionObservation`. Its members are:
  - `allInstances`
  - `allInstancesMask`, a `PixelBufferObservation`
  - `generateMask(for:)`
  - `generateMaskedImage(for:imageFrom:croppedToInstancesExtent: Bool = false)`
  - `generateScaledMask(for:scaledToImageFrom:)`
  - `instanceAtPoint(_ point: NormalizedPoint) -> IndexSet`

  In `generateMaskedImage` the `instances` parameter is "An indexed set of selected instances, where 0 is the background", and `croppedToInstancesExtent` "Crops the image to the smallest rectangle containing all instances." — [Apple docs: InstanceMaskObservation](https://developer.apple.com/documentation/vision/instancemaskobservation); [generateMaskedImage](https://developer.apple.com/documentation/vision/instancemaskobservation/generatemaskedimage(for:imagefrom:croppedtoinstancesextent:)); [generateScaledMask](https://developer.apple.com/documentation/vision/instancemaskobservation/generatescaledmask(for:scaledtoimagefrom:)); [instanceAtPoint](https://developer.apple.com/documentation/vision/instancemaskobservation/instanceatpoint(_:))
- `ImageRequestHandler` (a final class, iOS 18.0+) has `perform(_:)` and `performAll(_:)`. — [Apple docs](https://developer.apple.com/documentation/vision/imagerequesthandler)
- Swift equivalents of the other requests are also iOS 18.0+: `DetectContoursRequest`, `DetectHumanHandPoseRequest` and `GeneratePersonInstanceMaskRequest`. This resolves a gap in the earlier notes. — [DetectContoursRequest](https://developer.apple.com/documentation/vision/detectcontoursrequest); [DetectHumanHandPoseRequest](https://developer.apple.com/documentation/vision/detecthumanhandposerequest); [GeneratePersonInstanceMaskRequest](https://developer.apple.com/documentation/vision/generatepersoninstancemaskrequest)
- A forum poster said the Swift API's `GenerateForegroundInstanceMaskRequest` "lacks a `setComputeDevice` method". On iOS 17, `VNRequest.setComputeDevice(_:for:)` exists. — [Apple Developer Forums 761095](https://developer.apple.com/forums/thread/761095); [Apple docs: setComputeDevice](https://developer.apple.com/documentation/vision/vnrequest/setcomputedevice(_:for:))

**WWDC25 (iOS 26)**
- WWDC25 added `RecognizeDocumentsRequest` and `DetectLensSmudgeRequest`; no new general segmenter (from the earlier notes). — [WWDC25 session 272](https://developer.apple.com/videos/play/wwdc2025/272/)

**WWDC26 (iOS 27): session 237, "What's new in image understanding"**
- Chapters: tap-to-segment, image inputs for Foundation Models, image-based tool calling, and Vision on watchOS. — [WWDC26 237](https://developer.apple.com/videos/play/wwdc2026/237/)
- **Tap-to-segment.** Quotes from the session:
  - "To segment an object, you'll use GenerateIterativeSegmentationRequest."
  - Prompts can be a point, a bounding box "around all of the objects I want to segment", a lasso or a scribble.
  - "I can refine the mask by adding or subtracting more points … I can choose a point on the cup to exclude from my mask."
  - "The mask is a PixelBuffer that shows which pixels belong to the segmented object."
  - "Vision uses a normalized coordinates system with the coordinate origin in the lower left hand corner."
  - Lasso line width "should be at least 1% of the total image width."
  - "before you perform a segmentation request for the first time on a device, you'll have to download the model … downloadAssets … assetStatus".

  The session's sample code reads `GenerateIterativeSegmentationRequest(seed: point)`, then `handler.perform(request)`, then `observation?.pixelBuffer`, then `request.addIncludedPoint(newPoint)`. — [WWDC26 237](https://developer.apple.com/videos/play/wwdc2026/237/)
- **`GenerateIterativeSegmentationRequest`, API reference:**
  - A `final class`, **iOS/iPadOS/Mac Catalyst/macOS/tvOS/visionOS 27.0+**, conforming to `Sendable`, `ImageProcessingRequest` and `DownloadableAssetsRequest`.
  - Initializers: `init(seedBox: NormalizedRect, _:)`, `init(seedPoint: NormalizedPoint, _:)` and `init(seedScribbleBuffer: CVReadOnlyPixelBuffer, _:)`.
  - `addIncludedPoint(_:)` and `addExcludedPoint(_:)` throw when the total exceeds the limit. The limit is "a maximum of 13 points when seeded with a point or scribble, or 11 points when seeded with a box."
  - `qualityLevel` takes `.fast` ("low-resolution mask, but runs very quickly"), `.balanced` (default, "medium-resolution") or `.accurate` ("high-resolution mask").
  - `Result = PixelBufferObservation?`, which "can be nil if there is nothing to segment".

  Note that the docs' initializer label is `seedPoint:`, while the session code shows `seed:`. Trust the docs. — [Apple docs](https://developer.apple.com/documentation/vision/generateiterativesegmentationrequest); [QualityLevel](https://developer.apple.com/documentation/vision/generateiterativesegmentationrequest/qualitylevel-swift.enum); [Result](https://developer.apple.com/documentation/vision/generateiterativesegmentationrequest/result)
- **`DownloadableAssetsRequest`** (iOS 27.0+): "Inspect assetStatus to determine whether the required assets are ready, and call downloadAssets() to initiate the download when they are not." It also has `downloadAssets(progress:)`. — [Apple docs](https://developer.apple.com/documentation/vision/downloadableassetsrequest)
- **Sample code:** "Segmenting objects using taps, scribbles or rectangles" says it "needs to run on a physical device." — [Apple sample](https://developer.apple.com/documentation/vision/segmenting-objects-using-taps-scribbles-or-rectangles)
- A third-party SDK diff lists `GenerateSelectedObjectSegmentationRequest` (with `includePoint`/`excludePoint`) as **deprecated** in the 27 SDK. That implies an earlier, possibly iOS 26-era promptable request. I could not open its Apple page to confirm, so treat this as unverified. — [miniswift.run Vision 27 diff](https://miniswift.run/whats-new/vision/)
- **Foundation Models image input (iOS 27).** `Attachment<Content>` (iOS 27.0+) lets you "include media such as images alongside text in your prompts". It has `init(_:orientation:)` for CGImage, `init(imageURL:orientation:)` and `label(_:)`. WWDC26 says "Models tend to do well with descriptive tasks" and that Vision is "fine tuned for specific tasks … And Vision is fast." Vision ships `BarcodeReaderTool` and `OCRTool` for model tool calling. Nothing describes the model returning bounding boxes. — [Apple docs: Attachment](https://developer.apple.com/documentation/foundationmodels/attachment); [WWDC26 237](https://developer.apple.com/videos/play/wwdc2026/237/)
- A .NET MAUI docs issue states that on OS 26 and earlier, Foundation Models image requests throw `NotSupportedException`, and that image support requires the Xcode 27 SDK. This is a secondary source. — [dotnet/docs-maui #3565](https://github.com/dotnet/docs-maui/issues/3565)

### Inferences
**Availability matrix for this app (deployment target 17.0)**

| Capability | Minimum iOS | Notes |
|---|---|---|
| `VNGenerateForegroundInstanceMaskRequest`, `VNGeneratePersonInstanceMaskRequest` | 17 | |
| `VNGeneratePersonSegmentationRequest` | 15 | |
| `VNDetectHumanHandPoseRequest`, `VNDetectContoursRequest`, `VNGeometryUtils` | 14 | |
| Objectness saliency | 13 | |
| Swift-native request structs and `instanceAtPoint` | 18 | Nice to have only. Keeping one `VN*` code path avoids duplicating logic. |
| `GenerateIterativeSegmentationRequest`, Foundation Models image input | 27 | Gate with `if #available(iOS 27, *)`. Handle "assets not downloaded" and "device not eligible" by falling back to the iOS 17 path. |

**How to use iterative segmentation for pills (iOS 27)**
- It is a **mask refiner, not a detector**. Seeds have to come from somewhere: subject-lifting instance centroids, cross-check blob peaks, or **user taps**.
- For a suspected merge (one blob, two pills):
  1. Find two seed points (two distance-transform peaks, or two taps).
  2. Run `init(seedPoint: p1)` + `addExcludedPoint(p2)`, then run it again with the roles swapped.
- For a missed pill, seed with a box of the median pill size around the tap or blob.
- Each request is limited to 13 or 11 points, which is plenty for one pill.

**Foundation Models**
- It could serve, at most, as an on-device cross-check of the *count* ("How many separate tablets are in this image?"). Its accuracy for counting small objects is undocumented, so it cannot be a safety gate on its own. Device eligibility (Apple Intelligence hardware) also limits it.

### Gaps
- I did not fetch the WWDC24 "Discover Swift enhancements in the Vision framework" transcript. The iOS 18 facts above come from the API reference.
- `assetStatus` enum cases, model download size, offline behaviour and the iterative request's latency and mask resolution per quality level are not documented on the pages fetched.
- I found no evidence of how iterative segmentation performs on tiny objects or on objects against skin.
- Foundation Models' device and region eligibility for image input on iOS 27 was not verified in this session.
- I found no open-vocabulary object detection API in Vision or VisionKit through iOS 27. A third-party SDK diff lists no such request, but that page was only partially read. — [miniswift.run](https://miniswift.run/whats-new/vision/)

## Q4. Implementation details: coordinates, per-instance boxes, crops with context, Swift 6 concurrency, memory, latency and the Simulator

### Takeaway
Measure everything from the low-resolution `UInt8` `instanceMask`: one pass gives each label's bounding box, area and centroid. Map to full-resolution pixels with separate x and y scale factors read at runtime. Crop *context* boxes directly from the upright `CGImage` (cheap, no extra Vision work). Call `generateMaskedImage(…, croppedToInstancesExtent: true)` only when a transparent cut-out is really needed. Keep `VN*` objects inside one isolation domain (they are not `Sendable`), never request uncropped full-resolution masks per instance (each is about 50 MB at 12 MP), and treat "Vision unavailable" (the Simulator) and "no observation" as errors distinct from "0 pills".

### Cited Findings
- **Simulator.** A developer got "Could not create inference context" running the request in the Simulator, even with CPU forced. A reply says the request doesn't run on CPU, so it won't work in the Simulator, and that `usesCPUOnly` was deprecated in iOS 17. — [Apple Developer Forums 764948](https://developer.apple.com/forums/thread/764948)
- **Threading.** Subject lifting is "a resource intensive task and best deferred to a background thread so as not to block the UI." — [WWDC23 10176](https://developer.apple.com/videos/play/wwdc2023/10176/)
- **Sendable.** `VNInstanceMaskObservation` conforms to `NSSecureCoding`, `NSCopying`, `Hashable` and so on, but **not** `Sendable`. `VNImageRequestHandler` likewise lists no `Sendable` conformance. The iOS 18 `InstanceMaskObservation` struct *is* `Sendable`. — [Apple docs: VNInstanceMaskObservation](https://developer.apple.com/documentation/vision/vninstancemaskobservation); [VNImageRequestHandler](https://developer.apple.com/documentation/vision/vnimagerequesthandler); [InstanceMaskObservation](https://developer.apple.com/documentation/vision/instancemaskobservation)
- **Coordinate origins.** Vision normalized rects and points use a lower-left origin (`regionOfInterest` docs; WWDC26 for `NormalizedPoint`). — [regionOfInterest](https://developer.apple.com/documentation/vision/vnimagebasedrequest/regionofinterest); [WWDC26 237](https://developer.apple.com/videos/play/wwdc2026/237/)
- **Orientation.** `VNImageRequestHandler` has `init(cgImage:orientation:options:)`, plus pixel-buffer and sample-buffer variants that take an orientation. — [Apple docs: VNImageRequestHandler](https://developer.apple.com/documentation/vision/vnimagerequesthandler)
- **HDR.** "Vision, much like VisionKit, produces SDR outputs. Performing the masking in CoreImage, however, preserves the high dynamic range of the input." Use `CIBlendWithMask` with the scaled mask. — [WWDC23 10176](https://developer.apple.com/videos/play/wwdc2023/10176/)
- **Latency.** The only published figure is "under 10 milliseconds" for the network on an iPhone 14 Neural Engine. Upsampling and matting run as GPU Metal kernels in addition to that. — [Apple ML Research](https://machinelearning.apple.com/research/salient-object-segmentation)

### Inferences
**Mask layout and box mapping**
- `CVPixelBuffer` rows are stored top-down, so row 0 of `instanceMask` should be the top of the upright image. The app's `FoundPill.box` already assumes a top-left origin. Verify once on device by lifting a single object placed in the top-left corner.
- When building any Vision `regionOfInterest` or `NormalizedPoint` (iOS 27 seeds), flip y: `yVision = 1 - yTopLeft`.
- Keep passing an already-upright `CGImage` with orientation `.up`. If you ever pass the `AVCapturePhoto` pixel buffer directly, pass its `CGImagePropertyOrientation`, and verify that the mask comes back in the oriented frame.
- Read `CVPixelBufferGetWidth`/`GetHeight` for the mask and use `sx = photoW / maskW` and `sy = photoH / maskH` separately. Don't assume the mask is square or has the photo's aspect ratio.
- Pad by one mask pixel before scaling: a single low-resolution mask pixel spans about 6–8 full-resolution pixels.

**Swift sketch (iOS 17): boxes, centroids and context crops from one pass**
```swift
nonisolated struct InstanceStats: Sendable { var minX, minY, maxX, maxY: Int; var count: Int; var sumX: Int; var sumY: Int }

/// Runs synchronously inside the analyzer actor; no VN* object escapes this function.
nonisolated func liftInstances(_ photo: CGImage) throws -> (maskSize: CGSize, stats: [UInt8: InstanceStats])? {
    let request = VNGenerateForegroundInstanceMaskRequest()
    let handler = VNImageRequestHandler(cgImage: photo, orientation: .up)
    try handler.perform([request])                     // throws in the Simulator: surface as "unsupported", not "0 pills"
    guard let obs = request.results?.first else { return nil }   // nil = model found no salient subject -> "retake" path
    let mask = obs.instanceMask
    CVPixelBufferLockBaseAddress(mask, .readOnly); defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }
    let w = CVPixelBufferGetWidth(mask), h = CVPixelBufferGetHeight(mask), rb = CVPixelBufferGetBytesPerRow(mask)
    guard let base = CVPixelBufferGetBaseAddress(mask)?.assumingMemoryBound(to: UInt8.self) else { return nil }
    var stats: [UInt8: InstanceStats] = [:]
    for y in 0..<h { let row = base + y * rb
        for x in 0..<w { let l = row[x]; guard l != 0 else { continue }
            var s = stats[l] ?? InstanceStats(minX: x, minY: y, maxX: x, maxY: y, count: 0, sumX: 0, sumY: 0)
            s.minX = min(s.minX, x); s.maxX = max(s.maxX, x); s.minY = min(s.minY, y); s.maxY = max(s.maxY, y)
            s.count += 1; s.sumX += x; s.sumY += y; stats[l] = s } }
    return (CGSize(width: w, height: h), stats)
}

/// Full-res pixel rect (top-left origin) with a context margin, clamped to the photo.
func contextRect(_ s: InstanceStats, maskSize: CGSize, photo: CGImage, margin: CGFloat = 0.6) -> CGRect {
    let sx = CGFloat(photo.width) / maskSize.width, sy = CGFloat(photo.height) / maskSize.height
    var r = CGRect(x: CGFloat(s.minX - 1) * sx, y: CGFloat(s.minY - 1) * sy,
                   width: CGFloat(s.maxX - s.minX + 3) * sx, height: CGFloat(s.maxY - s.minY + 3) * sy)
    let side = max(r.width, r.height) * (1 + margin)          // square, centred: stable framing for the cloud model
    r = CGRect(x: r.midX - side / 2, y: r.midY - side / 2, width: side, height: side)
    return r.intersection(CGRect(x: 0, y: 0, width: photo.width, height: photo.height)).integral
}
// crop = photo.cropping(to: contextRect(...))   // shares the backing store; no Vision call, no 50 MB buffer
```
- **Per-instance shape metrics from the same pass**, all useful for merge detection:
  - fill ratio = `count / bboxArea` (about 0.785 for a round or elliptical pill seen face-on; lower for an L-shaped merge);
  - ratio of area to the median pill area;
  - bbox aspect ratio.

  For a finer convexity check, render one instance's mask (`generateMask(forInstances:)`, low resolution) and run `VNDetectContoursRequest` on it. Then compare `VNGeometryUtils.calculateArea` with the area of a convex-hull or RDP polygon.
- **Transparent cut-out (optional).** `generateMaskedImage(ofInstances: [i], from: handler, croppedToInstancesExtent: true)` must use the *same* `handler` that performed the request, so call it inside the same function.
- **Memory.**
  - A 12 MP BGRA image is about 48 MB. An uncropped `generateMaskedImage` or `generateScaledMaskForImage` result is also full-size (the scaled mask is floating point, so about 48 MB more if it is 32-bit).
  - Doing that per pill for 10 pills would spike past 500 MB. Use cropped outputs, or crop the photo first and run masks on the crop.
  - Release buffers promptly: no arrays of `CVPixelBuffer`; convert to a small `CGImage` and drop the buffer.
- **Concurrency.**
  - Keep `PillFinder` as `nonisolated` synchronous code called from the `PillPhotoAnalyzer` actor, as it is today. Return only `Sendable` values (`CGRect`, `CGImage`, plain structs).
  - Running several tiles: perform them sequentially in the actor, or in a `withThrowingTaskGroup` where each child builds its own request and handler. Never share a `VNImageRequestHandler` across tasks.
  - On iOS 18+ the Swift structs are `Sendable` and `async`, but adopting them is optional.
- **Latency budget (inference, to be measured).**
  - Per inference: network about 10 ms on A15-class or newer devices, plus guided upsampling and buffer handling (likely tens of ms at 12 MP), plus handler image conversion.
  - A 1 + 9-tile pass with hand pose and a Core Image cross-check is plausibly under 1 s on A15–A19.
  - Measure with `ContinuousClock` on an iPhone 13/14 (A15) and a current device. Downscale the photo to about 2048 px long side before Vision runs, since the network only sees 512 px anyway, and crop context boxes from the full-resolution original.
- **Privacy.** All of this runs on in-memory `CGImage`/`CVPixelBuffer` objects. Nothing touches the photo library or disk, provided debug overlays and test-harness captures are not written out in release builds.

### Gaps
- `instanceMask` dimensions, the scaled mask's pixel format (Float32 vs Float16) and the actual end-to-end latency at 12 MP are undocumented. Log them on device.
- I found no statement on whether `VNImageRequestHandler` may safely be used from several threads, so assume not.

## Q5. Bottom line: is an Apple-native-only pipeline realistic for pills on a palm across skin tones, which recipe is best, and which on-device experiment would settle it fastest?

### Takeaway
An Apple-native, zero-training pipeline is **realistic for pills on a plain table and plausible but unproven on a palm**. Apple itself documents that subjects can be "combined" or contain "two or more objects", so no Apple-native recipe can *guarantee* one crop per pill. Safety therefore has to come from **failure detection plus user confirmation**, not from the segmenter. The best iOS 17 recipe is:
- hand-pose palm ROI;
- subject lifting on the full image, plus overlapping palm tiles when needed;
- shape-based merge flags;
- an independent skin-difference blob cross-check;
- a mandatory "We found N pills: tap any we missed" confirmation.

On iOS 27, add `GenerateIterativeSegmentationRequest` to split flagged merges and to segment user-tapped misses. A one-afternoon on-device A/B test on about 40 labelled photos decides it.

### Cited Findings
- Apple acknowledges that overlapping objects can come back as one subject. — [Apple docs: ImageAnalysisInteraction.Subject](https://developer.apple.com/documentation/visionkit/imageanalysisinteraction/subject)
- Apple combines co-salient objects into one subject by design ("the man and his dog … one combined subject"). — [WWDC23 10176](https://developer.apple.com/videos/play/wwdc2023/10176/)
- The model works at 512×512, has a subject-confidence gate, and Apple checks fairness "across factors such as gender and skin tone". That check is not reported for small objects on skin. — [Apple ML Research](https://machinelearning.apple.com/research/salient-object-segmentation)
- Promptable refinement with include and exclude points exists only on iOS 27+, after an asset download. — [Apple docs: GenerateIterativeSegmentationRequest](https://developer.apple.com/documentation/vision/generateiterativesegmentationrequest); [DownloadableAssetsRequest](https://developer.apple.com/documentation/vision/downloadableassetsrequest)
- The earlier smartphone pill-ID study found accuracy depended heavily on capture conditions (best with a white background). — [JMIR Med Inform 2021, via earlier notes](https://preprints.jmir.org/preprint/26000/submitted)

### Inferences
**Recommended pipeline (iOS 17 baseline; additions on iOS 27)**
1. **Capture design.** This is the cheapest gain.
   - Prompt "spread the pills so they don't touch" and show live feedback.
   - Make **table or plain paper** the recommended mode and the palm the convenience mode.
   - The quality gate already handles light, glare and motion.
2. **Hand pose** (`VNDetectHumanHandPoseRequest`, `maximumHandCount = 1`):
   - Hand found → palm mode: build the palm polygon and sample the skin colour.
   - No hand → table mode: sample the background colour from the image border.
3. **Pass A:** `VNGenerateForegroundInstanceMaskRequest` on the image, downscaled to about 2048 px. Collect each instance's stats (Q4 sketch).
   - A nil result is a failure, not "0 pills".
   - A large instance (>12%) overlapping the palm is the signal "the hand may have absorbed pills".
4. **Pass B, conditional:** run on overlapping 2×2 or 3×3 tiles of the palm bounding box when Pass A has a large palm instance, or when its pill count disagrees with step 5. Merge with IoU and centre-distance de-duplication.
5. **Cross-check detector:** colour distance from skin or background, then Otsu threshold, then morphology open/close, then `VNDetectContoursRequest` or connected components, inside the palm polygon. Output: blob count, boxes, area and convexity.
6. **Reconcile and flag:**
   - each accepted pill instance ↔ one blob (centre inside);
   - a blob with no instance → *possible missed pill* (add as a candidate with a context crop and mark it low confidence);
   - an instance or blob with area >1.7× the median, fill ratio <0.65 or low convexity → *possible merged pills*;
   - total disagreement → ask for a retake.
   - Record why each crop exists (lifted, tile, blob, tap).
7. **iOS 27, when assets are ready:**
   - For each *possible merge*, seed `GenerateIterativeSegmentationRequest(seedPoint:)` at each lobe or peak and add the other lobes with `addExcludedPoint`. This gives one mask per pill.
   - For each *possible miss* or user tap, seed with `init(seedBox:)` sized to the median pill.
   - Call `downloadAssets()` early (onboarding) and check `assetStatus` before relying on it.
8. **Human confirmation (all iOS versions).**
   - Show numbered boxes over the photo: "We found 4 pills. Is that every pill?"
   - Tapping an unboxed pill adds a context crop centred on the tap (sized by the median pill box, or a default about 10% of the frame width).
   - Tapping a box that holds two pills splits it: iterative segmentation on iOS 27, otherwise two context crops centred on the taps.

   This is the only step that makes "missed or merged = detectable" hold regardless of segmentation quality.
9. **Crops for the cloud model:** square context crops from the full-resolution upright `CGImage` (the existing `surroundingCrop`). The transparent cut-out is optional and only for display or the feature-print fallback.

**Realism across skin tones**
- Subject lifting is not colour-thresholding, so it should degrade more gracefully across skin tones than a skin model does. Apple says it checks skin-tone fairness, though not for this task.
- The colour cross-check is weakest for pills whose colour matches the skin, which is exactly where a second, independent signal is most needed. The human confirmation step covers that residual risk.
- Expect palm-mode recall to vary with the pills' contrast against the skin. Measure recall and merge rate per (skin tone × pill colour) cell rather than in aggregate.

**Fastest decisive experiment: about one afternoon on a physical iPhone, no training**
- **Data.** About 40 photos taken with the app's own capture path. Cover:
  - 3 skin tones (light, medium, dark, from volunteers);
  - palm and table;
  - 2, 4, 6 and 10 pills;
  - spread vs. 1–2 touching pairs;
  - real tablets vs. paper cut-outs;
  - white, beige and coloured pills.

  Label the ground-truth count and the touching pairs. Use developer test photos in a test bundle or a DEBUG-only in-memory harness. Never patient photos, never the photo library.
- **Harness.** A DEBUG screen, or an XCTest run on device (Vision fails in the Simulator), that runs these variants on each photo:
  - **V1:** current single pass;
  - **V2:** single pass + hand-pose ROI filter;
  - **V3:** 2×2 tiles;
  - **V4:** 3×3 tiles;
  - **V5:** person-segmentation subtraction;
  - **V6:** skin-difference blobs alone;
  - **V7** (iOS 27 device): V3 + iterative split of flagged merges.

  Log for each run: `instanceMask` width and height; instance count and area; per-instance fill ratio; time per step; and a colour overlay of the instances.
- **Metrics.**
  - pill recall (pills with exactly one crop);
  - merge rate (crops containing ≥2 pills);
  - phantom rate;
  - **flag recall**: the share of misses and merges that the reconcile step flagged. This is the number that matters for safety.
- **Decision rule.**
  - If V3/V4 + flags reach about 100% *flag recall* with few phantoms on palms → ship Apple-native with human confirmation.
  - If palms fail broadly but tables succeed → make table mode the default and palm best-effort.
  - If both fail → the custom-trained detector route (Create ML or RF-DETR, covered in the earlier notes) or a cloud detector (another researcher's topic) is needed.
- **First thing to do (minutes):** print the `instanceMask` size and the instance areas for 5 palm photos with V1. That alone shows which failure mode is real: hand absorbs pills, empty result, or merges only.

### Gaps
- There is no empirical data from any source for subject lifting, tiling, person segmentation or iterative segmentation on pills on skin. The recipe's thresholds (1.7× area, fill ratio 0.65, 30% tile overlap, IoU 0.3) are engineering starting points, not sourced values.
- Iterative segmentation's quality on 6–9 mm objects and its latency are unknown until tested on an iOS 27 device.
