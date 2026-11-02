# On-device detection, segmentation and matching of several pills in a palm (iOS, as of Oct 2026)

Scope: building blocks available on iOS 17+ (Swift 6, SwiftUI, AVFoundation + Vision already in the app) for (1) finding each pill's box or outline in a palm photo, (2) cropping each pill, and (3) identifying it against a patient's few registered medications. All availability data comes from Apple's `.md` documentation endpoints, fetched 2026-10-30. Notes on how well each option works for pills on skin are marked as inferences unless a source says so.

## 1. Apple Vision built-ins: APIs, iOS versions, outputs, documented limits

### Takeaway
Vision ships no pill detector, but several building blocks are available from iOS 13 to 17: class-agnostic subject lifting with per-instance masks (iOS 17), objectness saliency boxes (iOS 13), contours (iOS 14), hand pose (iOS 14) and image feature prints (iOS 13; the better revision 2 needs iOS 17). The Swift-native versions (e.g. `GenerateForegroundInstanceMaskRequest`) need iOS 18. Apple documents no instance count or minimum object size for subject lifting, so whether it separates 4 small pills from the hand holding them must be tested.

### Cited Findings
- **VNGenerateForegroundInstanceMaskRequest** is available on iOS/iPadOS/Mac Catalyst 17.0+, macOS 14+ and visionOS 1+. Apple describes it as "A request that generates an instance mask of noticable objects to separate from the background." Its results are `[VNInstanceMaskObservation]`. — [Apple docs](https://developer.apple.com/documentation/vision/vngenerateforegroundinstancemaskrequest.md)
- **VNInstanceMaskObservation** (iOS 17+) exposes:
  - `allInstances: IndexSet`, which excludes the background
  - `instanceMask: CVPixelBuffer`
  - `generateMask(forInstances:)`, which returns a low-resolution mask
  - `generateMaskedImage(ofInstances:from:croppedToInstancesExtent:)`, which returns a high-resolution image with everything except the chosen instances made transparent black
  - `generateScaledMaskForImage(forInstances:from:)`
  — [Apple docs](https://developer.apple.com/documentation/vision/vninstancemaskobservation.md)
- WWDC23 "Lift subjects from images in your app" says:
  - The request is "class agnostic. Any foreground object, regardless of its semantic class, can be potentially segmented" (the example picks up a car as well as people).
  - "Each distinct segmented object is referred to as an instance … The zero index is reserved for the background, and then each foreground instance is labeled sequentially, starting at 1 … the ordering of these IDs is not guaranteed."
  - Setting the crop flag to true gives "a tight crop for the selected instances."
  - It is "a resource intensive task and best deferred to a background thread."
  - Vision runs it in-process and "isn't as limited in image resolution as VisionKit."
  - The session gives no maximum instance count and no minimum object size, and never mentions hands specifically.
  — [WWDC23 session 10176](https://developer.apple.com/videos/play/wwdc2023/10176/)
- **Swift-native API.** `GenerateForegroundInstanceMaskRequest` (a struct) is available on iOS 18.0+, macOS 15+ and visionOS 2+. Apple's page also lists watchOS 27, which implies the iOS 27 SDK generation is current as of Oct 2026. It offers async `perform(on:orientation:)` overloads for URL, Data, CGImage, CVPixelBuffer, CMSampleBuffer and CIImage, returns an `InstanceMaskObservation`, and conforms to `Sendable`. — [Apple docs](https://developer.apple.com/documentation/vision/generateforegroundinstancemaskrequest.md)
- **VNGenerateObjectnessBasedSaliencyImageRequest** (iOS 13+) "generates a heat map that identifies the parts of an image most likely to represent objects." — [Apple docs](https://developer.apple.com/documentation/vision/vngenerateobjectnessbasedsaliencyimagerequest.md)
- Its result, `VNSaliencyImageObservation`, contains a heat map that is "64 x 64 when fetched in real time, or 68 x 68 when requested in its deferred form." `salientObjects: [VNRectangleObservation]?` holds "objects describing the distinct areas of the saliency heat map." No maximum object count is documented. — [Apple docs](https://developer.apple.com/documentation/vision/vnsaliencyimageobservation.md)
- **VNDetectContoursRequest** (iOS 14+) takes the parameters `contrastAdjustment`, `contrastPivot`, `detectsDarkOnLight` and `maximumImageDimension`, and returns `VNContoursObservation`. — [Apple docs](https://developer.apple.com/documentation/vision/vndetectcontoursrequest.md)
- **VNDetectHumanHandPoseRequest** (iOS 14+) has a `maximumHandCount` setting and returns `VNHumanHandPoseObservation` joints by `JointName` / `JointsGroupName`. It has only revision 1. It returns joint keypoints, not a hand or palm mask. — [Apple docs](https://developer.apple.com/documentation/vision/vndetecthumanhandposerequest.md)
- **VNGenerateImageFeaturePrintRequest** (iOS 13+) returns `VNFeaturePrintObservation` and has an `imageCropAndScaleOption` setting. — [Apple docs](https://developer.apple.com/documentation/vision/vngenerateimagefeatureprintrequest.md)
- `VNFeaturePrintObservation` exposes `data`, `elementCount`, `elementType` and `computeDistance(_:to:)`, which "Computes the distance between two feature print observations." It conforms to `NSSecureCoding`, so reference prints can be archived. — [Apple docs](https://developer.apple.com/documentation/vision/vnfeatureprintobservation.md)
- **Feature print revision 2** (iOS 17+) "takes images with a size of 360x360 and produces a 768 feature vector" and "usually" gives better models than revision 1. — [Apple Create ML Components docs](https://developer.apple.com/documentation/createmlcomponents/imagefeatureprint/revision.md); [VNGenerateImageFeaturePrintRequestRevision2](https://developer.apple.com/documentation/vision/vngenerateimagefeatureprintrequestrevision2.md)
- `computeDistance` fails ("The revision of the observations do not match", error code 12) when the two prints come from different revisions, so pin one revision for both the reference and query prints. — [Apple Developer Forums 732876](https://developer.apple.com/forums/thread/732876)
- One unverified third-party article gives example distance thresholds of about 1.5 on iOS 17 and about 23 on iOS 16. — [Volcengine article](https://www.volcengine.com/article/1582955)
- WWDC25 added `RecognizeDocumentsRequest` and `DetectLensSmudgeRequest`. Neither is a new general object segmenter. `DetectLensSmudgeRequest` returns a 0–1 confidence and could serve as a capture-quality gate. — [WWDC25 session 272](https://developer.apple.com/videos/play/wwdc2025/272/); [WWDC Notes](https://wwdcnotes.com/documentation/wwdc25-272-read-documents-using-the-vision-framework/)

### Inferences
- **Subject lifting** is trained to lift the main foreground subjects. For a close-up of a palm, the likely outcome is that the hand and pills come back as one instance, or the hand as instance 1 with pills merged into it. Pills come out as separate instances only if the model treats them as distinct objects. This is a hypothesis, not documented behaviour, and needs to be tested on self-collected photos. A cheap experiment is to run it on 20 palm photos and count instances. A possible two-pass trick is to lift the hand+pills, then run subject lifting again on the cropped palm region, where pills are relatively larger.
- **Saliency's** 64×64 / 68×68 heat map is very coarse. In a frame where the palm fills most of the image, a pill about 1 cm across covers only a few heat-map cells. The salient boxes will probably merge touching pills, or return the whole palm. The heat map is better used as a coarse "where is the palm/pill cluster" prior than as a per-pill detector.
- **Contours** works on edges and contrast. It may outline white or coloured tablets well on darker or more saturated skin. It will also return palm creases, fingers and imprint edges, so filtering contours by size, convexity and ellipse fit would be needed. Same-coloured skin and pill (e.g. a beige tablet on light skin) is the weak case.
- **Hand pose** gives wrist and finger-joint points, from which a palm polygon (wrist plus MCP joints) can be approximated. That polygon serves as a region of interest to crop before detection, or to reject detections outside the palm. Detection may degrade when pills partially cover the palm or the hand is cupped.
- **Feature prints** are general-purpose image embeddings, not trained for fine-grained pill discrimination. They should tell a round white tablet from an oblong orange capsule. They are unlikely to reliably separate two round white tablets that differ only by imprint. Treat them as a first-pass filter over the patient's few registered medications (a small closed set, which helps a lot), not as an identifier.

### Gaps
- No Apple documentation states a maximum number of instances, a minimum object size, or how hands are treated by foreground instance masking.
- I could not confirm whether `computeDistance` output is normalized for revision 2, or what the typical distance ranges are.
- I did not find documented on-device latency for subject lifting or feature prints on specific iPhones.
- I did not fetch Swift-native equivalents of the other requests (`GenerateImageFeaturePrintRequest`, `DetectContoursRequest`, `DetectHumanHandPoseRequest`, `GenerateObjectnessBasedSaliencyImageRequest`). By analogy with `GenerateForegroundInstanceMaskRequest` they are expected to be iOS 18+, but that is unverified.

## 2. Traditional CV (Core Image / vImage / OpenCV) for segmenting pills from skin

### Takeaway
The classic pipeline is: threshold (background or colour) → binary mask → distance transform → marker-based watershed to split touching pills. It is well established for pills on a controlled, uniform background. Skin makes it fragile: the background has a variable colour similar to many pills, plus shadows, creases and glare. It works as a quick baseline, but not as the main detector.

### Cited Findings
- Matrox MIL's pill example binarizes the image, computes a distance transform (chamfer 3-4), runs a watershed and ANDs the result with the mask "to separate the touching pills." — [Matrox MIL example (VB)](https://aurorahelp.zebra.com/aurorail/MILPP2/HelpFilesPP2/extfile/zz_MIL_Examples_mimsegment.vb.212/zz_MIL_Examples_mimsegment.vb.212.htm); [C++ version](https://aurorahelp.zebra.com/aurorail/MILPP2/HelpFilesPP2/extfile/zz_MIL_Examples_mimsegment.cpp.211/zz_MIL_Examples_mimsegment.cpp.211.htm)
- OpenCV's watershed is marker-based. Markers are usually seeded from distance-transform peaks. — [Stack Overflow archive](https://kiwix.lema.org/stackoverflow.com_en_all_2023-11/questions/46763625/image-segmentation-with-watershed-thresholding)
- On a MATLAB forum thread about pill photos:
  - Shadows on the background and the light parts of oval pills make thresholding hard.
  - Responders suggest erosion or watershed to split pills, HSV thresholding, possibly a separate mask per pill colour, thresholding the background and inverting it, or simply "a better background, like all white."
  — [MathWorks Answers](https://www.mathworks.com/matlabcentral/answers/1592779-identify-objects-in-images)
- A pill-identification patent separates pills by edge density against a high-edge-density background such as a checkerboard. It notes that imprints and glare also appear as edges. — [USPTO 9111357](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/9111357)
- An unrelated smartphone pill-ID study found accuracy depended heavily on capture conditions. The best top-1 accuracy was 51.1%, with a white background, flash on and EV +2.0. — [JMIR Med Inform 2021 (via search summary)](https://preprints.jmir.org/preprint/26000/submitted)

### Inferences
- **Skin-to-background.** On iOS, skin can be modelled as the "background" class. The hand mask could come from subject lifting (Section 1) or a YCrCb/HSV skin range. Pills would then be the non-skin connected components inside the hand mask. Core Image filters (`CIColorCube`, `CIColorThreshold` on iOS 14+, morphology filters) and vImage (`vImageDilate`/`Erode`, histogram ops) can implement this without third-party code. Watershed and distance transform are not in Core Image, so they need OpenCV (Apache 2.0 since 4.5) or a hand-written implementation.
- **Failure modes.** The approach is expected to fail on:
  - beige, pink or brown pills on matching skin tones
  - translucent gelcaps
  - specular glare on coated tablets
  - pills resting in palm creases
  - a cupped hand that casts shadows
  It is also tuned per skin tone, which raises fairness concerns for a health app.
- **Pragmatic mitigation.** Ask the user to hold pills on a flat open palm under even light. Or allow a fallback of pills on a plain sheet of paper, where classical CV works much better.

### Gaps
- I found no published evaluation of classical pill segmentation specifically on skin or palms.
- I found no iOS-specific OpenCV pill example.

## 3. Training a custom detector or segmenter (Create ML, YOLO → Core ML, permissive alternatives, SAM family)

### Takeaway
A custom-trained detector or instance segmenter is the most reliable route to per-pill boxes or masks on skin. Ultralytics YOLO (v8, 11, and as of 2026 YOLO26) exports directly to Core ML, including segmentation, and reports single-digit-millisecond latency on the Neural Engine. However, it is AGPL-3.0, and Ultralytics says the AGPL also covers trained weights. Two options avoid that:
- Create ML Object Detection: Apple's tool, boxes only, low effort.
- RF-DETR (Apache 2.0 for Nano–Large, including segmentation variants). Its Core ML export is experimental.

### Cited Findings
- **Ultralytics Core ML export:**
  - `yolo export model=yolo26n.pt format=coreml imgsz=640`
  - `quantize=16|8|"w8a16"` replaces the deprecated `half` and `int8` flags
  - `nms=True` embeds NMS for detect, segment and pose (only with `dynamic=False`)
  - Detect and segment export is supported for YOLOv8, YOLO11 and YOLO26
  - Recommended setting is `computeUnits = .cpuAndNeuralEngine` in camera apps, to avoid GPU contention
  - Core ML inference and validation inside the Ultralytics tooling runs only on macOS
  - `format="coreai"` targets Apple's Core AI on iOS 27 / macOS 27
  — [Ultralytics Core ML docs](https://docs.ultralytics.com/integrations/coreml/)
- Ultralytics benchmark on iPhone 17 Pro, iOS 27.0.1, YOLO26n INT8 at 640, single-image burst latency:

  | Task | CPU + Neural Engine | CPU only |
  |---|---|---|
  | Detect | 3.7 ms | 8.8 ms |
  | Segment | 4.9 ms | 12.3 ms |

  Ultralytics notes that sustained camera use runs slower. — [Ultralytics Core ML docs](https://docs.ultralytics.com/integrations/coreml/)
- **Ultralytics licensing:**
  - AGPL-3.0 (free) requires open-sourcing the entire project under AGPL. It lists "academic research and university coursework" in the free tier.
  - Non-profit or government research qualifies only if fully disclosed.
  - Enterprise (paid) is required for closed-source or commercial products, apps on edge devices, and SaaS.
  - "All trained YOLO models fall under AGPL-3.0 by default". The licence "covers the training code and the models produced by that training code."
  — [Ultralytics license page](https://www.ultralytics.com/license)
- **RF-DETR** core models (Nano through Large) and all training and inference code are Apache 2.0. XLarge and 2XLarge need `rfdetr[plus]` under PML 1.0. The README marks Seg-N through Seg-2XL as Apache 2.0, while the llms-full doc implies the same tiering applies to segmentation. These conflict for the XL and 2XL segmentation weights. — [roboflow/rf-detr GitHub](https://github.com/roboflow/rf-detr); [RF-DETR docs](https://rfdetr.roboflow.com/latest/); [llms-full](https://rfdetr.roboflow.com/llms-full.txt)
- RF-DETR's official docs cover ONNX, TFLite and TensorRT export. A community Hugging Face repo reports a Core ML export of RF-DETR Medium and Large (detection, FP16) made with the upstream `format="coreml"` exporter, which it calls experimental. It used rfdetr 1.9.4 and coremltools 9.0. — [kortexa-ai/rf-detr-coreml](https://huggingface.co/kortexa-ai/rf-detr-coreml)
- **Create ML Object Detection** (2020 Apple tech talk):
  - Transfer learning "does well with as few as 80 training examples per class."
  - The full-network YOLOv2-based model shrank from about 65 MB to about 33 MB with 16-bit quantization. The transfer-learning model is about 7 MB because it uses the OS-shipped object print.
  - Transfer-learning models need iOS 14+.
  - These figures may be dated.
  — [Apple Tech Talk 10155](https://developer-rno.apple.com/videos/play/tech-talks/10155); [Evil Martians Create ML guide](https://evilmartians.com/chronicles/object-detection-with-create-ml-training-and-demo-app)
- **SAM family on iPhone:**
  - EdgeSAM: above 30 FPS on iPhone 14 with Core ML, measured in Xcode, with encoder and decoder reported separately. It claims to be about 14× faster than MobileSAM.
  - MobileSAM: 4.9 FPS on iPhone 14 in EdgeSAM's comparison table.
  - RepViT-SAM: claims about 10× faster than MobileSAM on iPhone 12 via coremltools.
  - One developer reported about 2 s CPU latency for MobileSAM on iOS and difficulty getting a GPU path to work.
  — [EdgeSAM (ecosyste.ms mirror)](https://awesome.ecosyste.ms/projects/github.com%2Fchongzhou96%2FEdgeSAM); [RepViT GitHub](https://github.com/thu-mig/RepViT); [PyTorch forum](https://discuss.pytorch.org/t/inference-on-ios-and-gpu/191235)

### Inferences
- **YOLO licence for this project.** For a university course prototype that is not distributed commercially, AGPL-3.0 is workable if the team is willing to publish the app source (e.g., a public GitHub repo) and the trained weights. If the repo must stay private, or the app may later be commercialized, Ultralytics' own page says an Enterprise licence is needed. In that case, prefer Create ML or RF-DETR (Apache 2.0). Confirm with the course or university; this is not legal advice.
- **Data effort.** Four pills per palm image gives four box annotations per image. Applying the "80 examples per class" guideline to a single class "pill" (identification happens later), about 100–300 self-collected palm photos across lighting, skin tones and pill types is a plausible starting point. Augment them, and optionally pre-train on public pill datasets (Section 4). A single "pill" class is far easier than one class per medication, and it keeps the detector independent of the patient's prescription list.
- **Boxes vs masks.** Boxes are enough to highlight a wrong pill in red and to crop it. Masks (YOLO-seg, RF-DETR-Seg) give nicer outlines and background-free crops, which may help embedding matching. A middle path is detect boxes, then run subject lifting on each box crop to get an outline. That reuses Apple's built-in for masks with no extra licence.
- **SAM-style models.** These are promptable, not detectors. They need box or point prompts, which a detector or saliency map must supply. That adds latency and conversion effort, with little gain over YOLO-seg for small, convex pills.
- **Other permissive detectors.** TF/MediaPipe SSD-MobileNet and EfficientDet-Lite (Apache 2.0) exist. Converting them to Core ML via coremltools is possible but less turnkey than Ultralytics or Create ML. Licences were not re-verified in this session.

### Gaps
- I found no current (2025–2026) Create ML Object Detection benchmarks for small objects, or official minimum data counts.
- I found no official RF-DETR Core ML documentation or iPhone latency figures.
- I did not find EfficientSAM iPhone latency figures.
- I did not verify licences for EfficientDet, MobileNet-SSD or D-FINE in this session.
- I did not confirm whether Ultralytics' claim that weights are covered by AGPL is legally settled. It is Ultralytics' stated position.

## 4. Existing pretrained pill detection models and datasets

### Takeaway
Roboflow Universe hosts many small pill detection datasets, mostly CC BY 4.0, with some marked Public Domain. They suit pre-training or augmenting a single-class "pill" detector, but most show pills on tables or trays, not in palms. ePillID (built on NIH data) is the main fine-grained identification benchmark; it is not a detection dataset.

### Cited Findings
- Roboflow Universe pill projects listed as CC BY 4.0 include NKUST "Pill Detection", "pill" (11-jypsp), "pill" (qms), "pill" (checkPill) and a pill-bottle project. A Hugging Face mirror of Mohamed Attia's "pill-detection-llp4r" says Public Domain, while the Universe model page shows CC BY 4.0 (a discrepancy). The live Universe page is authoritative. — [NKUST Pill Detection](https://universe.roboflow.com/nkust-gpqqx/pill-detection-fta5i); [qms pill](https://universe.roboflow.com/qms/pill-mf7nw/dataset/); [checkpill](https://universe.roboflow.com/checkpill/pill-i9x4j); [11-jypsp pill](https://universe.roboflow.com/11-jypsp/pill-kjfru); [medicaldoh pills](https://universe.roboflow.com/medicaldoh/pills-sxdht-ufchc-qz3bo); [HF mirror data.yaml](https://huggingface.co/cvtechniques/PillDetectionModel/blob/main/Dataset/data.yaml); [Attia pill-classification](https://universe.roboflow.com/mohamed-attia-e2mor/pill-classification/model/2/train/results)
- **ePillID** (Usuyama et al., CVPRW 2020):
  - It is a low-shot, fine-grained benchmark built from the NIH challenge dataset (consumer photos) and NIH Pillbox (reference images).
  - Most appearance classes have only one reference image.
  - The CVPRW version has about 13k images, 8,184 appearance classes and 4,092 pill types. The arXiv version cites 9,804 appearance classes and 4,902 pill types.
  - The best baseline was multi-head metric learning with bilinear features, which still failed on confusing classes.
  — [CVF open access](https://openaccess.thecvf.com/content_CVPRW_2020/html/w54/Usuyama_ePillID_Dataset_A_Low-Shot_Fine-Grained_Benchmark_for_Pill_Identification_CVPRW_2020_paper.html); [arXiv 2005.14288](https://arxiv.org/abs/2005.14288v1)
- The CURE dataset is used as a pill-ID benchmark. MIRA-Pill reports +7.29 percentage points on it for near-identical pills that differ only by imprint. — [search summary of MIRA-Pill / related works](https://www.mdpi.com/2227-7390/14/2/356)

### Inferences
- **Training mix.** Combine CC BY 4.0 Universe datasets (keep attribution in the README or credits) with self-collected palm photos. Remap all classes to a single "pill" class for detection.
- **ePillID** is useful mainly for testing a matching or embedding approach offline: it has one reference image per class, similar to "patient registers a few meds."

### Gaps
- I did not inspect image counts, annotation quality, or the presence of in-hand images in individual Universe datasets.
- I did not check for pretrained public pill detection weights that are licensed for reuse.
- I did not verify ePillID's licence or CURE's licence.

## 5. On-device embedding models for fine-grained pill retrieval

### Takeaway
Options in order of effort:
1. Vision feature print (built in, 768-D in revision 2, iOS 17+).
2. MobileCLIP / MobileCLIP2 image encoders (MIT code, Apple model terms, small, built for iPhone).
3. A DINOv2-small Core ML conversion.

Published evidence shows that generic embeddings struggle on fine-grained pill ID. ePillID baselines needed metric learning, and imprint-only differences remain hard. With a closed set of about 3–10 registered meds, colour, shape and size embeddings are likely enough to flag a pill that is clearly wrong, but not to confirm one that looks similar.

### Cited Findings
- Vision feature print revision 2 produces a 768-element vector from 360×360 input (iOS 17+). — [Apple Create ML Components docs](https://developer.apple.com/documentation/createmlcomponents/imagefeatureprint/revision.md)
- **MobileCLIP (v1, CVPR 2024)** comes in S0, S1, S2, B, B(LT), S3, L/14 and S4. **MobileCLIP2 (TMLR 2025)** comes in S0, S2, B, S3, L/14 and S4.
  - MobileCLIP2-S0 has an 11.4M-parameter image encoder, 1.5 ms image latency in the table (device not named), and 71.5% zero-shot ImageNet top-1.
  - MobileCLIP2-S4 has 321.6M image parameters, 19.6 ms image latency and 81.9% top-1.
  - The licence is MIT for code and the Apple ML Research Model Terms of Use for weights.
  - An iOS demo app (`ios_app`, released Nov 2024) does real-time zero-shot classification.
  - The repo README does not say whether Core ML packages are provided.
  — [apple/ml-mobileclip](https://github.com/apple/ml-mobileclip)
- ePillID's best baseline used metric learning with bilinear features and still erred on confusing classes. — [CVF open access](https://openaccess.thecvf.com/content_CVPRW_2020/html/w54/Usuyama_ePillID_Dataset_A_Low-Shot_Fine-Grained_Benchmark_for_Pill_Identification_CVPRW_2020_paper.html)
- Heo et al. (JMIR 2023) found that combining imprint reading with language-model correction gave 85.6% and 74.5% top-1 on unknown pills in two databases. It gave 78.0% top-1 on consumer images with one training image per pill. — [JMIR 2023](https://jmir.org/2023/1/e41043/PDF)

### Inferences
- **Prototype recipe:**
  1. Register each medication with 3–5 reference crops taken in-app, on the palm, under different lighting.
  2. At query time, embed each detected crop (prefer the masked crop, with background removed via subject lifting or a seg mask).
  3. Take the nearest neighbour among the registered meds, and flag the pill "wrong / unknown" if its distance exceeds a threshold calibrated on self-collected photos.
- Store feature prints with `NSSecureCoding` and pin the request revision.
- Combine the embedding distance with cheap handcrafted cues: mean Lab colour inside the mask, aspect ratio from the mask's ellipse fit, and relative size versus the other pills or the palm width.
- **MobileCLIP S0 or S2** is a likely upgrade over feature print, and offers optional text prompts ("white oval tablet") for zero-shot attributes. Conversion via coremltools is required unless a Core ML build is found. The model terms of use must be checked for academic use.
- **DINOv2-small** (about 21M parameters, ViT-S/14) is known for strong instance-level retrieval features. I did not verify its licence or a Core ML conversion in this session.

### Gaps
- I found no published evaluation of Apple feature print, MobileCLIP or DINOv2 on pill retrieval specifically.
- I did not verify MobileCLIP iPhone latency on recent devices, or which device the table refers to. The page names iPhone 12 Pro Max only in a different comparison.
- I did not verify the DINOv2 licence or Core ML ports.

## 6. On-device OCR of tiny imprints (VNRecognizeTextRequest)

### Takeaway
`VNRecognizeTextRequest` can be run on each pill crop. Its `minimumTextHeight` defaults to 1/32 of image height, so OCR on an upscaled tight crop is better than on the full frame. Research shows printed imprints are tractable, but debossed or embossed imprints (low contrast, curved) degrade conventional OCR significantly and need specialised models. Treat imprint OCR as an optional confirmation signal, not a primary one.

### Cited Findings
- `minimumTextHeight` is "relative to the image height … Increasing the size reduces memory consumption and expedites recognition with the tradeoff of ignoring text smaller than the minimum height. The default value is 1/32, or 0.03125." — [Apple docs](https://developer.apple.com/documentation/vision/vnrecognizetextrequest/minimumtextheight.md)
- GO-PILL (MDPI Mathematics, 2026) targets curved, embossed and irregular imprints. It reports that conventional OCR methods degrade significantly on these, and it uses TextSnake detection plus contrast enhancement for embossed and debossed text. — [MDPI 2227-7390/14/2/356](https://www.mdpi.com/2227-7390/14/2/356)
- A 2025 Springer paper used YOLOv5s detection with a Deep Text Spotter and character-level RNN for imprints, on smartphone photos, and reported 97.8% detection accuracy. That figure is for detection, not imprint-reading accuracy. — [Springer s44291-025-00122-6](https://link.springer.com/article/10.1007/s44291-025-00122-6)
- Heo et al.'s imprint and language-model pipeline: 85.6% / 74.5% top-1 on unknown pills. — [JMIR 2023](https://jmir.org/2023/1/e41043/PDF)

### Inferences
- **For printed (ink) imprints:**
  - Crop tightly to the pill.
  - Upscale so the imprint is well above 1/32 of the crop height, or lower `minimumTextHeight`.
  - Use `.accurate` recognition with `usesLanguageCorrection = false`.
  - Set `customWords` to the registered meds' imprint codes.
  - Fuzzy-match the results only against the patient's registered imprints. This is a small closed set, so matching is much easier than open lookup.
- **For debossed imprints:** expect frequent failure from a palm photo. Useful mitigations are a close-up second capture of one pill, torch or flash at a raking angle, and CLAHE-style contrast enhancement in Core Image before OCR.
- **Rotation.** Pills in a palm are at arbitrary angles. Vision handles some rotation, but trying 0/90/180/270° rotations of each crop may help.

### Gaps
- I found no published evaluation of Apple's VNRecognizeTextRequest on pill imprints.
- I found no data on the minimum imprint pixel height needed for reliable recognition.

## 7. Performance expectations (latency, Neural Engine)

### Takeaway
A custom nano-size YOLO detector or segmenter runs in about 4–5 ms per frame on the iPhone 17 Pro Neural Engine (INT8), so live per-frame detection is feasible. Subject lifting is documented as resource-intensive and should run on a still frame on a background thread. Embedding a few crops and OCR are fine per capture but not per frame. A sensible architecture is a live detector on video frames, plus capture-time embedding and OCR.

### Cited Findings
- YOLO26n INT8 at 640 on iPhone 17 Pro with CPU + Neural Engine: detect 3.7 ms, segment 4.9 ms, classify (224) 2.0 ms. Sustained camera use is slower than burst. Use `.cpuAndNeuralEngine`. — [Ultralytics Core ML docs](https://docs.ultralytics.com/integrations/coreml/)
- Subject lifting is "a resource intensive task and best deferred to a background thread." — [WWDC23 10176](https://developer.apple.com/videos/play/wwdc2023/10176/)
- EdgeSAM runs above 30 FPS on iPhone 14, and MobileSAM at 4.9 FPS on iPhone 14. — [EdgeSAM](https://awesome.ecosyste.ms/projects/github.com%2Fchongzhou96%2FEdgeSAM)
- MobileCLIP2-S0 image encoder: 1.5 ms in the repo table (device unspecified). — [apple/ml-mobileclip](https://github.com/apple/ml-mobileclip)
- The saliency heat map is 64×64 in real time and 68×68 deferred. — [Apple docs](https://developer.apple.com/documentation/vision/vnsaliencyimageobservation.md)

### Inferences
- **Suggested pipeline for the prototype:**
  - **Live preview:** run on `AVCaptureVideoDataOutput` frames, throttled. Use hand pose (optional ROI) and either a YOLO or Create ML "pill" detector, or the zero-training baseline: subject lifting on a still frame.
  - **On capture:** take a full-resolution still, then run detection, then crop (mask via seg or subject lifting), then embed each crop (feature print or MobileCLIP) against the registered references, plus colour and shape cues, plus optional OCR. Highlight mismatches in red. Escalate uncertain crops to a cloud model.
- **Swift 6 concurrency.** The Swift-native Vision requests (iOS 18+) are `Sendable` and async. With an iOS 17 deployment target, the `VN*` classes plus a dedicated serial queue are needed, or availability-gated code paths.

### Gaps
- I found no measured latency for VNGenerateForegroundInstanceMaskRequest, VNGenerateImageFeaturePrintRequest or VNRecognizeTextRequest on specific iPhones.
- I found no Create ML detector latency on current devices.
