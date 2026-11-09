# Trainable and promptable on-device models for detecting and segmenting individual pills on iPhone (as of 9 Nov 2026)

Scope: a single-class "pill" detector or instance segmenter that runs on iPhone (iOS 17.0 target, Core ML) and finds 2–10 tablets (6–9 mm) on a palm or a table, so that each pill can be cropped and sent to OpenAI. The notes cover candidate models, promptable and open-vocabulary models, datasets, synthetic copy-paste data, Core ML integration, and a recommended plan. They build on `research_notes/In hand pill recognition architecture/on_device_detection.md` (sections 3, 4 and 7) and only repeat its facts where a newer or more precise source exists.

Primary sources checked on 2026-11-09:
- GitHub API licence fields for 30 repos
- PyPI release metadata
- RF-DETR's Core ML export docs and exporter source, branch `develop`
- the ePillID data zip itself (downloaded and inspected)
- the npj Digital Medicine 2019 full text (Europe PMC)
- Apple documentation `.md` endpoints
- arXiv abstracts

---

## 1. Permissively licensed single-class detectors and instance segmenters that export to Core ML

### Takeaway
RF-DETR is the only actively maintained detector that combines all four of the following:
- permissive licence for code and weights: Apache-2.0 for detection Nano/Small/Medium/Large and for every segmentation size
- native Core ML export: `format="coreml"`, rfdetr 1.12.0 released 2026-11-06
- instance masks
- strong fine-tuning results on small datasets

Its Core ML path is officially labelled "experimental". Apple's measurements are on Mac only (about 18–25 ms for Nano fp16 on the Apple Neural Engine (ANE) of an M3 Pro or M4 Max). Community iPhone reports range from about 10 to 15 fps, and those runs were on the GPU in fp32.

The other options fall short in different ways:
- **Create ML Object Detection:** the zero-licence-risk, zero-conversion baseline, but it outputs boxes only.
- **D-FINE and DEIM (v1):** Apache-2.0, but detection only and no documented Core ML path.
- **DEIMv2 and YOLO-NAS weights:** non-commercial.
- **YOLOv9 (original repo) and YOLO-World:** GPL-3.0.
- **Ultralytics YOLO and YOLOE:** AGPL-3.0, which Ultralytics says extends to the weights.

### Cited Findings

**RF-DETR (Roboflow)**
- Licence:
  - The code is Apache-2.0 ([GitHub API](https://api.github.com/repos/roboflow/rf-detr)).
  - Detection Nano, Small, Medium and Large are Apache-2.0.
  - Detection Atto, Femto, Pico, XL and 2XL, and the NAS models, are under PML 1.0. PML 1.0 allows commercial use only when deployed on Roboflow; commercial self-hosting needs an Enterprise add-on.
  - All segmentation sizes, Seg-Nano through Seg-2XL, are Apache-2.0.
  - [roboflow/rf-detr README](https://github.com/roboflow/rf-detr); [RF-DETR llms-full doc](https://rfdetr.roboflow.com/llms-full.txt). The docs now agree that every segmentation size is Apache-2.0. That resolves the README/doc conflict noted in the earlier research.
- Detection sizes (COCO AP50:95 / params / default resolution / T4 TensorRT fp16 latency / RF100-VL AP50:95):

  | Size | COCO AP50:95 | Params | Resolution | T4 latency | RF100-VL AP50:95 |
  |---|---|---|---|---|---|
  | Nano | 48.4 | 30.5M | 384 | 2.3 ms | 57.7 |
  | Small | 53.0 | 32.1M | 512 | 3.5 ms | 60.2 |
  | Medium | 54.7 | 33.7M | 576 | 4.4 ms | 61.2 |
  | Large | 56.5 | 33.9M | 704 | 6.8 ms | 62.2 |

  — [roboflow/rf-detr README](https://github.com/roboflow/rf-detr)
- Segmentation sizes (COCO mask AP50:95 / params / resolution / T4 latency):

  | Size | COCO mask AP50:95 | Params | Resolution | T4 latency |
  |---|---|---|---|---|
  | Seg-Nano | 40.3 | 33.6M | 312 | 3.4 ms |
  | Seg-Small | 43.1 | 33.7M | 384 | 4.4 ms |
  | Seg-Medium | 45.3 | 35.7M | 432 | 5.9 ms |
  | Seg-Large | 47.1 | 36.2M | 504 | 8.8 ms |
  | Seg-XL | 48.8 | 38.1M | 624 | 13.5 ms |
  | Seg-2XL | 49.9 | 38.6M | 768 | 21.8 ms |

  — [roboflow/rf-detr README](https://github.com/roboflow/rf-detr)
- **Versions.** rfdetr 1.12.0 was released 2026-11-06 ("adds INT8 exports, and speeds up inference on CUDA and Apple Silicon"). 1.11.0 (2026-09-24) added Core AI (`.aimodel`, iOS/macOS 27+), OpenVINO and LiteRT exports. — [PyPI rfdetr](https://pypi.org/pypi/rfdetr/json); [rf-detr releases](https://api.github.com/repos/roboflow/rf-detr/releases)
- **Native Core ML export** (`docs/exports/coreml.md`):
  - Labelled "experimental and work-in-progress". Install with `pip install "rfdetr[coreml]"`, then call `model.export(format="coreml")`. This works for detection (`RFDETRMedium`) and segmentation (`RFDETRSegMedium`).
  - Output is an mlprogram `.mlpackage` with minimum target iOS 15 / macOS 12, so it fits an iOS 17 app.
  - The default is FP32. `coreml_precision="float16"` halves the size and is the only way to reach the ANE: "an fp32 bundle never touches it".
  - Outputs are positional: `dets, labels` for detection and `dets, labels, masks` for segmentation.
  - `dynamic_batch=True` is not supported.
  - [rf-detr docs/exports/coreml.md](https://raw.githubusercontent.com/roboflow/rf-detr/develop/docs/exports/coreml.md)
- **Measured Mac latency** (Nano at 384, M3 Pro, coremltools 9.0, p50):
  - fp16 `CPU_AND_NE`: 24.9 ms; fp16 `ALL`: 22.7 ms; fp32 `CPU_AND_GPU`: 26.1 ms.
  - On an M4 Max the ANE-optimised graph (`coreml_neural_engine=True`) runs Nano in 17.7 ms (`CPU_AND_NE`), Small in 30.2 ms (`ALL`) and Medium in 33.0 ms (`CPU_AND_GPU`).
  - For Seg-Nano on the M3 Pro, `ALL` (44.2 ms) was slower than `CPU_AND_NE` (38.8 ms) because work was split between the ANE and GPU.
  - First ANE compile takes about 5–10 s; later loads come from the system cache in under 0.1 s.
  - COCO mAP was identical (48.0) in fp32, fp16 on the ANE and fp16 on the GPU.
  - An iOS 16-target fp16 program lost about 3 AP on the ANE, so the exporter pins iOS 15.
  - 99.7% of estimated work runs on the ANE. Only 11–15 ops (`topk`, `resample`, `cast`) fall back to CPU.
  - Bundle sizes for Small: 114.7 MB (fp32) and 57.7 MB (fp16).
  - [rf-detr docs/exports/coreml.md](https://raw.githubusercontent.com/roboflow/rf-detr/develop/docs/exports/coreml.md); [exporter.py](https://raw.githubusercontent.com/roboflow/rf-detr/develop/src/rfdetr/export/_coreml/exporter.py)
- **Input format.** The exported package "expects ImageNet mean/std normalization". `ct.convert` is called without an `ImageType` input, so the input is a float tensor named `tensors` (1×3×H×W), not an image. — [exporter.py](https://raw.githubusercontent.com/roboflow/rf-detr/develop/src/rfdetr/export/_coreml/exporter.py); [coreml.md "Use Core ML directly"](https://raw.githubusercontent.com/roboflow/rf-detr/develop/docs/exports/coreml.md)
- **Community image adapter.** `landchenxuan/rf-detr-to-coreml` (Apache-2.0, pushed 2026-11-01, 14 stars):
  - adds an RGB `ImageType` input named `image` with ImageNet normalisation inside the graph
  - supports segmentation variants, e.g. `rfdetr-coreml --model seg-nano --precision fp16`
  - outputs remain raw boxes, logits and masks
  - [README](https://raw.githubusercontent.com/landchenxuan/rf-detr-to-coreml/main/README.md); [GitHub API](https://api.github.com/repos/landchenxuan/rf-detr-to-coreml)
- **Community iPhone reports** (Reddit, June 2026; unverified):
  - Fine-tuned RF-DETR Nano at 384, FP32, converted with that repo, ran at about 15 fps on iPhone 14 Pro, GPU only, no ANE.
  - The same post cites another report of about 10 fps at 512.
  - A Core AI build reached 33–39 fps but needs iOS 27.
  - [Reddit snapshot](https://reddit.sentinel-team.org/posts/1uc3qdf/snapshots/2026-06-26T22%3A16%3A49.53411Z)
- **Resolution and training settings:**
  - Detection Nano, Small, Medium and Large use patch size 16 with 2 windows. Segmentation sizes use patch 12 with 2 windows; Seg-Nano uses 1 window.
  - The backbone "requires input shape to be divisible by" patch_size × num_windows. That means multiples of 32 for detection and 24 for segmentation.
  - A custom `resolution` is supported, e.g. `RFDETRLarge(resolution=640)`.
  - `num_queries` is 100 for Seg-Nano and Seg-Small and 200 for Seg-Medium and Seg-Large.
  - [config.py](https://raw.githubusercontent.com/roboflow/rf-detr/develop/src/rfdetr/config.py); [dinov2.py](https://raw.githubusercontent.com/roboflow/rf-detr/develop/src/rfdetr/models/backbone/dinov2.py)
- **Fine-tuning:**
  - Accepts COCO JSON or YOLO format. Segmentation needs COCO polygons.
  - Default 50 epochs; "effective batch size 16 is a starting target".
  - Augmentation defaults to scale jitter plus horizontal flip. Optional Albumentations presets (e.g. `Rotate`, `Affine`) are applied with bounding-box and mask handling.
  - [llms-full](https://rfdetr.roboflow.com/llms-full.txt); [augmentations.md](https://raw.githubusercontent.com/roboflow/rf-detr/develop/docs/learn/train/augmentations.md)
- A Roboflow blog (2025-11-10) calls RF-DETR "Apache 2.0 licensed, so you can use it in commercial products for free". It gives no iPhone latency, only 4.52 ms on a T4. — [Roboflow blog](https://roboflow.com/blog/best-ios-object-detection-models)

**Create ML Object Detection (Apple)**
- `MLObjectDetector.ModelParameters.ModelAlgorithmType` has two cases:
  - `darknetYolo`: "trains a full neural network with your training data"
  - `transferLearning(FeatureExtractorType)`: "leverages the knowledge of a general purpose model built into the operating system"
  - No segmentation option exists. [Apple docs](https://developer.apple.com/documentation/createml/mlobjectdetector/modelparameters-swift.struct/modelalgorithmtype.md)
- Apple tech talk 10155:
  - The full network is YOLOv2-based and runs back to iOS 12.
  - Transfer learning uses the OS "Object Print" backbone and is about 5× smaller. It needs iOS 14 and "does well with as few as 80 training examples per class".
  - A 15×8 grid "preserves the original aspect ratio".
  - A forum thread reports grid sizes above 30×30 fall back to 30×30.
  - [Apple Tech Talk 10155](https://developer.apple.com/kr/videos/play/tech-talks/10155/?time=764); [Apple forums 746867](https://developer.apple.com/forums/thread/746867) (via search summary)
- I found no WWDC24/25/26 change to the Create ML 2D object-detection template. WWDC24's Create ML additions were data previews and visionOS object tracking. — [WWDC24 10183 notes](https://wwdcnotes.com/documentation/wwdc24-10183-whats-new-in-create-ml/)

**D-FINE and DEIM family (Intellindust / USTC)**
- **D-FINE:**
  - Code is Apache-2.0. Objects365-pretrained checkpoints "may be subject to the Objects365 dataset terms".
  - Sizes (COCO AP / params / T4 latency): N 42.8 / 4M / 2.12 ms; S 48.5 / 10M / 3.49 ms; M 52.3 / 19M / 5.62 ms.
  - Exports to ONNX and TensorRT only. No Core ML mention. Detection only; last dated model release 2024-11-07.
  - [Peterande/D-FINE](https://github.com/Peterande/D-FINE)
- **DEIM (CVPR 2025):** the LICENSE says "DEIM is licensed under the Apache License". Results: DEIM-D-FINE N 43.0 AP (4M), S 49.0 AP (10M). Exports to ONNX and TensorRT only. Detection only. — [DEIM LICENSE](https://raw.githubusercontent.com/Intellindust-AI-Lab/DEIM/main/LICENSE); [Intellindust-AI-Lab/DEIM](https://github.com/Intellindust-AI-Lab/DEIM)
- **DEIMv2 (2025-09-26)** is under the custom "DEIMv2 License":
  - "solely for Non-Commercial Purposes … No rights are granted for Commercial Use". This covers code and model weights.
  - Sizes (AP / params): Atto 23.8 / 0.5M; Pico 38.5 / 1.5M; N 43.0 / 3.6M; S 50.9 / 9.7M. S and above use DINOv3-distilled backbones.
  - Export: ONNX, TensorRT and OpenVINO; no Core ML.
  - [DEIMv2 LICENSE.md](https://raw.githubusercontent.com/Intellindust-AI-Lab/DEIMv2/main/LICENSE.md); [DEIMv2 README](https://github.com/Intellindust-AI-Lab/DEIMv2)

**Other detectors, licences per the GitHub API (2026-11-09)**
- RT-DETR / RT-DETRv2 (`lyuwenyu/RT-DETR`): Apache-2.0, pushed 2026-10.
- YOLOX (`Megvii-BaseDetection/YOLOX`): Apache-2.0, last push 2025-06.
- YOLOv9 (`WongKinYiu/yolov9`): **GPL-3.0**.
- `MultimediaTechLab/YOLO` (reimplementation of YOLOv9/v7): MIT.
- YOLO-World (`AILab-CVC`): **GPL-3.0**.
- YOLOE (`THU-MIG`): **AGPL-3.0**.
- `ultralytics/ultralytics`: **AGPL-3.0** (8.4.208, 2026-11-08).
- detectron2 and mmdetection (Mask R-CNN family): Apache-2.0. mmdetection's last push was 2024-08.
- [GitHub API](https://api.github.com/repos/roboflow/rf-detr) (one query per repo); [PyPI ultralytics](https://pypi.org/pypi/ultralytics/json)
- **YOLO-NAS weights** (Deci): "you may not use the Software for any commercial use, including in connection with any models used in a production environment". The weights may not be modified or redistributed. The `super-gradients` code itself is Apache-2.0, last release 3.7.1 (2024-04). — [LICENSE.YOLONAS.md](https://raw.githubusercontent.com/Deci-AI/super-gradients/master/LICENSE.YOLONAS.md); [PyPI super-gradients](https://pypi.org/pypi/super-gradients/json)
- **Ultralytics:** YOLO26n INT8 at 640 on iPhone 17 Pro takes 3.7 ms for detection and 4.9 ms for segmentation. Ultralytics says AGPL covers "the models produced by that training code". — [Ultralytics Core ML docs](https://docs.ultralytics.com/integrations/coreml/); [Ultralytics license](https://www.ultralytics.com/license) (from earlier research, unchanged)

**Apple's own sample models**
- Apple's gallery has no pill or generic instance segmenter. It has:
  - YOLOv3 (80 COCO classes; Tiny Int8 is 8.9 MB)
  - DeepLabV3 (2.3–8.6 MB)
  - DETR ResNet-50 semantic segmentation (F16, 86 MB): 34.32 ms on iPhone 16 Pro, 39 ms on iPhone 15 Pro Max, 51 ms on iPhone 13 Pro Max
  - [Apple Core ML models](https://developer.apple.com/machine-learning/models/)

### Inferences
- **Best fit for "private now, maybe commercial later": RF-DETR.** Use Seg-Small or Seg-Medium if outlines are wanted, or detection Small or Medium if boxes are enough. The only licence-clean alternative with a turnkey iOS path is Create ML, which is boxes only and based on a 2016-era YOLOv2 or an opaque OS backbone, with no published small-object metrics.
- **Why a DETR-style set predictor suits touching pills.** It emits one query per object and needs no NMS: decoding is sigmoid on the logits, then threshold or top-k over the 100–300 queries. NMS-based detectors can suppress one of two strongly overlapping true boxes. For touching or slightly overlapping pills this is a real safety advantage, and it also removes the "embed NMS or not" conversion question.
- **Size and latency cost.** RF-DETR's parameter count is dominated by its DINOv2 backbone: about 30–36M parameters, so roughly 55–70 MB in fp16 by analogy with Small's 57.7 MB. YOLO26n has a few million. Expect roughly 20–60 ms per still on recent iPhones. This is extrapolated from 17–25 ms on M3 Pro/M4 Max ANE, the community's 66 ms (15 fps) fp32 GPU result on iPhone 14 Pro, and Apple's own DETR-R50 at 34 ms on iPhone 16 Pro. That is fine for one auto-captured still and acceptable even for throttled live gating. It is unverified on iPhone.
- **D-FINE / DEIM v1** are licence-clean and small (4–10M parameters), but nobody documents a Core ML conversion. Both use deformable-attention-style sampling, the same `resample` op that RF-DETR had to work around. Budget several days of conversion debugging, so they are not a 1–2 week option.
- **YOLOX** is Apache-2.0 and NMS-based. It is old (2021) and has no maintained Core ML path, and its value over RF-DETR is unclear.
- **Ultralytics YOLO26-seg** is technically the easiest and fastest. It is legitimate for the class project only if the team accepts AGPL obligations: publish the source, and Ultralytics also reads AGPL to cover the weights. Keep it as a fallback benchmark, not the shipping path.

### Gaps
- There are no official RF-DETR iPhone latencies, ANE placement data or memory figures on an iPhone. Only Mac numbers and anecdotal community reports exist.
- I did not verify whether `coreml_neural_engine=True` exports exist for segmentation models. The docs table lists only detection Nano, Small and Medium.
- I found no Create ML Object Detection small-object accuracy data, no input-size documentation for `darknetYolo`, and no 2025–2026 template changes.
- I found no Core ML conversion reports for D-FINE, DEIM, RT-DETR or YOLOX.

---

## 2. Promptable and open-vocabulary segmentation for "pill" with zero or little training

### Takeaway
None of the open-vocabulary models is a practical on-device "pill" detector on iOS 17 as of Nov 2026:
- **SAM 3 / 3.1:** 848M parameters, gated weights, custom SAM licence, no mobile build.
- **EfficientSAM3:** Apache-2.0, but Core ML export is "coming soon".
- **YOLOE:** AGPL. **YOLO-World:** GPL.
- **OWLv2 and Grounding DINO:** no Core ML ports found.
- **Florence-2:** the Core ML port is captioning, OCR and VQA only, CPU-only, and uses about 1.2 GB of RAM.

Promptable SAM-family models do have working Core ML ports: Apple's SAM 2.1 tiny (Apache-2.0), MobileSAM (Apache-2.0, 19 MB), and EdgeSAM (fast but **non-commercial**). They need a box or point prompt from somewhere.

Best uses:
- **Offline:** auto-label training photos with these models.
- **On-device, optionally:** refine detector boxes into masks.

### Cited Findings
- **SAM 3** (facebookresearch, arXiv 2511.16719, 2025):
  - 848M parameters; detector plus tracker.
  - Accepts text noun-phrase prompts as well as points, boxes, masks and exemplars.
  - Checkpoints are gated on Hugging Face.
  - SAM 3.1 ("Object Multiplex") was released 2026-03-27.
  - No mobile or edge version is mentioned.
  - [facebookresearch/sam3](https://github.com/facebookresearch/sam3)
- **SAM License:**
  - Grants a "non-exclusive, worldwide, non-transferable and royalty-free limited license" to use, modify and distribute.
  - Includes prohibited-use (military, weapons), trade-control and indemnification clauses.
  - Does not explicitly bar commercial use.
  - GitHub's licence field is `NOASSERTION`.
  - [SAM 3 LICENSE](https://raw.githubusercontent.com/facebookresearch/sam3/main/LICENSE); [GitHub API](https://api.github.com/repos/facebookresearch/sam3)
- **EfficientSAM3** (arXiv 2511.15833):
  - Repo is Apache-2.0.
  - Students (image backbones): RepViT 4.7–22.4M, TinyViT 5.1–20.6M, EfficientViT 0.68–15M parameters.
  - Text encoders distilled into MobileCLIP-S0 (42.6M) or S1 (63.6M).
  - SAM3-LiteText (2026-02-18) scores 53.6–54.0 avg F1 on SA-Co/Gold, against 54.1 for SAM 3.
  - "Core ML and ONNX export: Coming soon". An iOS app is listed only as a wanted contribution.
  - [EfficientSAM3 HF](https://huggingface.co/Simon7108528/EfficientSAM3); [alphaXiv 2511.15833](https://www.alphaxiv.org/abs/2511.15833.md)
- **Apple `coreml-sam2.1-tiny`:**
  - Apache-2.0, float16, made for the SAM2 Studio demo app (Apache-2.0, macOS).
  - The image encoder package is about 67.2 MB.
  - No latency is published.
  - [HF apple/coreml-sam2.1-tiny](https://huggingface.co/apple/coreml-sam2.1-tiny); [encoder file listing (search summary)](https://huggingface.co/apple/coreml-sam2.1-tiny/tree/main/SAM2_1TinyImageEncoderFLOAT16.mlpackage); [sam2 repo licence Apache-2.0](https://api.github.com/repos/facebookresearch/sam2)
- **MobileSAM Core ML** (community, `mlboydaisuke`):
  - 19 MB download, iOS 17.0 minimum, about 300 MB peak RAM, Apache-2.0.
  - Point prompts; Swift library SamKit.
  - [HF MobileSAM-CoreML](https://huggingface.co/mlboydaisuke/MobileSAM-CoreML)
  - Speed: 4.9 FPS on iPhone 14 per EdgeSAM's comparison table. — [EdgeSAM](https://github.com/chongzhou96/EdgeSAM)
- **EdgeSAM:**
  - 38.7 FPS on iPhone 14; 9.6M parameters; COCO mask mAP 42.2 against MobileSAM's 39.4.
  - Ships Core ML encoder and decoder packages; supports box and point prompts.
  - **Licence: NTU S-Lab License 1.0.** Use is allowed only for "non-commercial purpose"; commercial use requires contacting the authors.
  - [EdgeSAM README](https://github.com/chongzhou96/EdgeSAM); [EdgeSAM LICENSE](https://raw.githubusercontent.com/chongzhou96/EdgeSAM/master/LICENSE)
- **EfficientSAM** (`yformer`): Apache-2.0, last push 2024-12. I found no Core ML package or iOS app. — [GitHub API](https://api.github.com/repos/yformer/EfficientSAM); search summary
- **YOLOE** (THU-MIG, ICCV 2025):
  - Text, visual and prompt-free prompts; outputs segmentation masks.
  - 11-S has 10M parameters and 27.5 LVIS AP.
  - Export via ONNX and Core ML. The README says it "can become YOLOs after re-parameterization with zero inference … overhead".
  - **Licence AGPL-3.0.**
  - [THU-MIG/yoloe](https://github.com/THU-MIG/yoloe)
- **YOLO-World** (AILab-CVC) is GPL-3.0. — [GitHub API](https://api.github.com/repos/AILab-CVC/YOLO-World)
- **Grounding DINO** (`IDEA-Research`) is Apache-2.0; last push 2024-08. **OWLv2** lives in `google-research/scenic` (Apache-2.0). Searches found no Core ML or iPhone ports of either. — [GitHub API](https://api.github.com/repos/IDEA-Research/GroundingDINO); search summary
- **Florence-2 Core ML** (community port):
  - 229 MB in three packages; iOS 17.0; MIT.
  - All packages are set to `cpuOnly`; peak RAM about 1.2 GB.
  - The card covers captioning, OCR and VQA. It does not document the detection or grounding tasks.
  - [HF Florence-2-base-CoreML](https://huggingface.co/mlboydaisuke/Florence-2-base-CoreML)

### Inferences
- **Zero-shot "pill" on device is not ready on iOS 17 with a commercial-safe licence.** The closest candidate is EfficientSAM3 with a MobileCLIP text encoder, once a Core ML export exists. Even then, an encoder of about 5–20M parameters plus a text encoder of 42–64M parameters would be heavier than RF-DETR. Its accuracy on 6–9 mm tablets on skin is untested.
- **Detector box → SAM mask is sensible but optional.**
  - Pills are small, convex and high-contrast at the box scale. A box prompt per pill helps SAM split touching pills. Without a prompt, SAM-style "segment everything" tends to merge or over-split.
  - It adds a second model (about 20–70 MB), an encoder pass, and Swift prompt plumbing.
  - Cheaper routes to a mask:
    1. RF-DETR-Seg, which gives masks directly.
    2. Apple's `VNGenerateForegroundInstanceMaskRequest` run on each padded box crop. A pill then dominates the crop, so subject lifting is far more likely to isolate it. No extra model or licence is needed.
- **SAM 3, Grounding DINO and OWLv2 are most valuable offline.** Use them to pre-label palm photos with the prompt "pill" or "tablet" and box/mask outputs, then correct by hand. X-AnyLabeling and Roboflow both integrate SAM-family models. This shortens the 1–2 week plan.
- **Avoid EdgeSAM** if commercialisation is likely (S-Lab non-commercial licence). MobileSAM (Apache-2.0) or Apple's SAM 2.1 tiny (Apache-2.0) are the licence-clean promptable choices.

### Gaps
- I found no measured iPhone latency for Apple's SAM 2.1 tiny Core ML encoder, MobileSAM Core ML or EfficientSAM.
- I found no small-object or pill-specific evaluation of any promptable or open-vocabulary model.
- I did not read the SAM 3 licence in full for app-store distribution specifics. Not legal advice.

---

## 3. Datasets: what exists, what annotations, what licences

### Takeaway
- **ePillID** is not a detection dataset. Every image is a 224×224 JPEG crop of one pill: reference crops on black, and consumer crops on grey or other backgrounds. It has no boxes or masks and is "for research purposes only".
- **NIH C3PI** (the source) is ODbL and "for research and development purposes only".
- The only public multi-pill sets with instance annotations are:
  - **VAIPE:** boxes, in-hand and out-of-hand, about 9.4k images; licence "Unknown" on Kaggle.
  - **MEDISEG:** COCO polygon masks, 8,262 images, dosette-box slots, **CC BY 4.0**, the cleanest licence.
  - **CURE:** partial masks, includes synthetic images.
- Roboflow Universe pill sets are mostly CC BY 4.0 but mostly table or tray photos. I found no public pills-in-palm segmentation set with a clean commercial licence.

### Cited Findings
- **ePillID contents.** I downloaded and inspected `ePillID_data.zip` (160.7 MB, release `ePillID_data_v1.0`, 2020-09-07):
  - 33,014 zip entries.
  - `classification_data/segmented_nih_pills_224/`: 25,996 JPEGs.
  - `classification_data/fcn_mix_weight/`: `dc_224` with 5,000 files and `dr_224` with 2,001.
  - `all_labels.csv` has 13,532 rows: 9,804 `is_ref=True` and 3,728 consumer. Columns: `pilltype_id`, `label_code_id`, `prod_code_id`, `is_ref`, `is_front`, `is_new`, `image_path`, `label`.
  - Sampled images are all 224×224 JPEG (no alpha) with one pill per image:
    - Reference images are tightly cropped on a near-black background.
    - Consumer images (`fcn_mix_weight`) are pill-centred crops with their original grey or other backgrounds.
  - [ePillID release](https://api.github.com/repos/usuyama/ePillID-benchmark/releases); local inspection
- **ePillID licence.** The code is MIT. The page says "dataset and software are released for research purposes only". Data comes from the NIH NLM Pill Image Recognition Challenge and Pillbox. — [usuyama/ePillID-benchmark](https://github.com/usuyama/ePillID-benchmark)
- **NIH NLM Pill Image Recognition Challenge:** "7000 pill images of 1000 pill types … 2000 reference images and 5000 consumer-quality ones". The challenge provides no localisation (bounding-box) data. — [Larios Delgado et al., npj Digit Med 2019 (PMC6550183)](https://europepmc.org/article/PMC/PMC6550183)
- **NIH C3PI:**
  - 133,000 consumer images plus about 4,000 reference images. The reference zip (`rximage.zip`) is 6.8 GB.
  - Licence ODbL. "Images and metadata are for research and development purposes only".
  - Sunset in 2018.
  - [data.gov C3PI](https://catalog.data.gov/dataset/computational-photography-project-for-pill-identification-c3pi)
- **VAIPE (PLOS ONE 2023):**
  - 9,426 images, 96 pill classes, about 5–10 pills per image, smartphone photos "in-hand or out-of-hand".
  - Bounding boxes, reviewed by 20 readers.
  - Baselines: Faster R-CNN R50-C4 mAP 62.6; YOLOv5n AP 37.9. These are 96-class results.
  - Public via Kaggle (`anhduy091100/vaipe-minimal-dataset`, 254 MB), where the licence is shown as **"Unknown"**.
  - [PLOS ONE 10.1371/journal.pone.0291865](https://journals.plos.org/plosone/article?id=10.1371%2Fjournal.pone.0291865); [Kaggle API metadata](https://www.kaggle.com/api/v1/datasets/view/anhduy091100/vaipe-minimal-dataset)
- **MEDISEG** (arXiv 2603.10825, 2026-03-11):
  - 8,262 images, 32 pill types, iPhone 12 Pro Max.
  - Pills in a 4×7 dosette box with varied lighting; images cropped to slots and padded or resized to 640×640; up to 13 pills per frame.
  - Manual COCO polygon masks plus boxes, second-reviewer checked. **CC BY 4.0** (Figshare DOI 10.25383/city.28574786.v1; code `williamcwi/MEDISEG`).
  - YOLOv9: 3-Pills mAP50 99.5%; 32-Pills mAP50 80.1%.
  - No in-hand capture is described.
  - [arXiv 2603.10825](https://arxiv.org/html/2603.10825); [GitHub API](https://api.github.com/repos/williamcwi/MEDISEG)
- **CURE:** 8,973 images with partial instance-segmentation labels, including synthetic images. — [MEDISEG Table 1](https://arxiv.org/html/2603.10825)
- **Roboflow Universe:**
  - The search found many pill projects (e.g. `mohamed-attia-e2mor/pill-detection-llp4r`, `yolopills`, `pills-sxdht` from Roboflow-100) and separate palm datasets.
  - It found **no project combining pills with a hand or palm**.
  - The earlier research recorded most pill projects as CC BY 4.0.
  - [Universe search results](https://universe.roboflow.com/mohamed-attia-e2mor/pill-detection-llp4r); [earlier notes §4](../In%20hand%20pill%20recognition%20architecture/on_device_detection.md)
- **Ultralytics "medical-pills" dataset:** AGPL-3.0. — [search summary of Ultralytics docs](https://docs.ultralytics.com/datasets/detect/medical-pills)
- **Hand backgrounds:**
  - **11k Hands:** 11,076 images at 1600×1200 of 190 subjects, palmar and dorsal. I found no authoritative licence; a Kaggle mirror says "FREE for reasonable academic fair use". — [search summary: Afifi 2019 / mirrors](https://arxiv.org/pdf/1711.04322)
  - **HaGRID:** "a variant of Creative Commons Attribution-ShareAlike 4.0" (see the repo's `license/en_us.pdf`). HaGRIDv2 has 1M images. — [ai-forever/hagrid](https://github.com/ai-forever/hagrid); [HaGRIDv2 arXiv 2412.01508](https://arxiv.org/pdf/2412.01508)

### Inferences
- **ePillID is the right pill appearance bank for the class project.** The demo pills are printouts of exactly these reference images. Cut-outs need alpha masks you make yourself:
  - Reference crops: threshold the near-black background, then erode 1–2 px and feather to hide JPEG halos.
  - Consumer crops: segment the pill with subject lifting or SAM.
- **Resolution is enough for the detector, not for identification.** The 224 px source resolution suffices for training a detector, since pasted pills end up roughly 30–60 px in the model input. It is too low to train imprint-level identification.
- **Licensing for a commercial version.** ePillID, C3PI and VAIPE all carry research-only or unknown terms. A commercial detector should be retrained on:
  - self-collected palm photos
  - CC BY 4.0 data (MEDISEG, Roboflow CC BY sets, with attribution)
  - self-photographed or licensed pill cut-outs

  Training only a class-agnostic "pill" detector on research-only images is still a derivative use. Treat it as research-only until legal review. Not legal advice.
- **VAIPE is the most domain-relevant public set** (multi-pill, in-hand, smartphone). For research it works as a validation or pre-training source after remapping all 96 classes to one "pill" class. Licence "Unknown" rules it out for commercial training.
- **MEDISEG** is the best permissively licensed source of real instance masks with touching or occluded pills. Its dosette-box backgrounds differ from palms, so use it as a pre-training or mix-in source.

### Gaps
- I could not confirm the licence of the full VAIPE dataset (only the Kaggle "minimal" edition) or of CURE.
- I did not count or inspect the 16,192 files in `segmented_nih_pills_224` that `all_labels.csv` does not reference.
- I did not verify the 11k Hands licence from the authors' own page.
- I did not inspect any Roboflow Universe dataset for in-hand images.

---

## 4. Synthetic copy-paste data from ePillID cut-outs: evidence, recipe, and how many real images

### Takeaway
There is direct precedent from the ePillID authors themselves. Microsoft Research trained a pill localiser **only** on 100,000 synthetic copy-paste images built from NIH reference pills. The recipe:
- 1–5 pills per image
- 360° rotation
- 20–50 px pill size
- 0–20 px drop shadow
- paper, desk, carpet and metal backgrounds
- brightness, contrast, blur and affine/perspective jitter

That localiser enabled 94% top-5 identification on real consumer photos. General detection literature shows:
- copy-paste gives solid gains (Simple Copy-Paste, CVPR 2021)
- synthetic data plus about 10% of the real data can beat all-real data in cross-domain settings (Cut, Paste and Learn, ICCV 2017)

Still keep a real, hand-annotated set: about 100 palm photos for testing and about 150–300 for fine-tuning.

### Cited Findings
- **Larios Delgado, Usuyama et al., npj Digital Medicine 2019** (Microsoft Research; CC BY 4.0 article):
  - "Since the NIH competition dataset does not provide the pill localization data … we generated synthetic images and trained FCN only with the synthetic images".
  - 100,000 synthetic images of 480×640.
  - Pill cut-outs made by removing the reference background of RGB (117±1, 117±1, 117±1).
  - Backgrounds: "papers, desks, carpets, and metal textures … different lighting sources".
  - Paste parameters: "1–5 pills per image, 360° rotation, 20–50 px pill size, 0–20 px drop shadow".
  - Runtime augmentations: contrast and brightness, Gaussian blur, affine and perspective.
  - The FCN outputs a 480×640 mask; boundary loss weight was doubled.
  - Segmentation was evaluated only indirectly, through classification accuracy: top-5 94% against the competition winner's 83.3%.
  - [Europe PMC full text PMC6550183](https://europepmc.org/article/PMC/PMC6550183); [Nature](https://www.nature.com/articles/s41746-019-0086-0)
- **Marami & Royaee (arXiv 2007.13903, 2020):**
  - 160,000 synthetic images: NLM reference pills pasted on background textures with random orientation, drop shadows, perspective and blur.
  - Model: DeepLabv3+.
  - Identification accuracy 0.912 (top-5 0.984) on about 1,000 loose pills.
  - The synthetic-data details come from a search-engine summary; I could not parse the PDF. The accuracy figures come from the arXiv abstract.
  - [arXiv 2007.13903](https://arxiv.org/abs/2007.13903)
- **Simple Copy-Paste (Ghiasi et al., CVPR 2021 oral):**
  - Random pasting "works well" with no context modelling.
  - COCO: 49.1 mask AP / 57.3 box AP, which is +0.6 / +1.5 over the previous state of the art.
  - LVIS rare categories: +3.6 mask AP over the 2020 challenge winner.
  - It combines with self-training.
  - [arXiv 2012.07177](https://arxiv.org/abs/2012.07177)
- **Cut, Paste and Learn (Dwibedi et al., ICCV 2017):**
  - "Ensuring only patch-level realism provides enough training signal".
  - Boundary "pixel artifacts" hurt unless handled; the paper uses blending or ignoring of boundaries.
  - Combined with real data: more than 21% relative improvement.
  - "Synthetic data plus only 10% real data outperforms models trained on all real data" (cross-domain).
  - [arXiv 1708.01642](https://arxiv.org/abs/1708.01642)
- **MEDISEG authors' caution:** synthetic data "often fails to capture real-world variations". — [arXiv 2603.10825](https://arxiv.org/html/2603.10825)
- **Apple's guidance:** Create ML transfer learning "does well with as few as 80 training examples per class". — [Apple Tech Talk 10155](https://developer.apple.com/kr/videos/play/tech-talks/10155/?time=764)

### Inferences
**Recipe tuned to this app.** Use Python with OpenCV and Albumentations. No special tool is needed, and RF-DETR's training loader already accepts COCO polygons.
1. **Pill bank.** Take the 9,804 ePillID reference crops. Alpha mask = threshold of the black background, plus erode and feather. Optionally add 100–300 cut-outs of the team's own printed paper pills and a few real OTC tablets (vitamins, mints), so the detector does not learn "pill = printed paper texture".
2. **Background bank.** Use 50–150 self-shot empty palms and tabletops: several people and skin tones, open, flat and cupped hands, indoor lights, both phone cameras at 1–3× zoom. HaGRID or 11k Hands crops may be added for the research version only (licences are unclear).
3. **Placement.**
   - 2–10 pills per image, 360° rotation, placed mostly inside the palm region (a hand mask from subject lifting or hand pose).
   - Scale the long side to about 5–10% of image width, matching "7 cm spread = 80% of frame".
   - Force 20–30% of images to contain touching pairs, with overlap of 0–15% of area.
   - Add a drop shadow with offset 0–20 px and blur, and a slight per-pill colour or illumination match to the background.
4. **Image-level augmentation.** Gaussian and motion blur, JPEG compression, brightness, contrast and white-balance shifts, specular highlight blobs, small perspective changes.
5. **Hard negatives.** Paste distractors with no labels: fingernails, rings, buttons, crumbs, coins, coloured paper scraps.
6. **Volume.** Generate 5k–20k images. The npj paper used 100k, but modern pretrained DETR backbones need far fewer; this is an inference, not a measured number.

**Real images still needed:**
- At least 100 annotated real test photos (never trained on), covering the full range of conditions, with about 400–600 pill instances.
- 150–300 annotated real training photos, mixed with synthetic data, for example 1 real to 3–5 synthetic per batch, or synthetic pre-training followed by real fine-tuning.

This follows the Cut-Paste-Learn finding that synthetic plus about 10% real beats all-real, Apple's "80 examples" for transfer learning, and the earlier estimate of 100–300 photos. Each photo holds 2–10 pills, so 200 photos give roughly 1,000 instances.

**Biggest sim-to-real risks:**
- pasted pills lack contact shadows and skin occlusion
- ePillID reference images are uniformly lit
- 224 px sources upscaled at large paste sizes look soft

Mitigations: keep paste sizes near the source scale, apply blur, and make sure the real fine-tuning set covers the failure cases.

### Gaps
- I found no published pill detector trained on synthetic copy-paste data and evaluated with detection metrics (recall/AP) on in-hand photos. The npj paper evaluated localisation only indirectly.
- I could not read the Simple Copy-Paste data-efficiency tables, which report results for fractions of COCO.
- I found no ready-made, maintained open-source "copy-paste dataset generator" to recommend with a verified licence. A small custom script is the realistic path.

---

## 5. Integration on iOS 17: conversion, Vision, resolution, tiling, mapping back

### Takeaway
- **Export.** Export RF-DETR in fp16 with `format="coreml"`; it targets iOS 15+. Either wrap it with an `ImageType` input (community adapter or a small PyTorch wrapper) so Vision can resize, or call `MLModel` directly with a normalised `MLMultiArray`.
- **Preprocessing.** Do your own crop rather than letterboxing. A centre square crop of the 3:4 still keeps all pills and raises pill pixel size by about 33% for free.
- **Resolution.** Choose about 512–640 input. RF-DETR defaults of 312–384 make 6–7 mm pills "small objects" (about 20 px).
- **Tiling.** Skip it. Pills are not tiny at 640, and tiling creates cut and duplicate pills, which is exactly the safety failure to avoid.
- **Output.** No NMS is needed for DETR. Map normalised boxes back to the full-resolution still and crop from there.

### Cited Findings
- **`VNCoreMLRequest` result types:**
  - a classifier gives `VNClassificationObservation`
  - an image output gives `VNPixelBufferObservation`
  - otherwise a "general predictor model" gives `VNCoreMLFeatureValueObservation`
  - "Vision forwards all confidence values … as-is and doesn't normalize them"
  - `imageCropAndScaleOption` controls scaling
  - [Apple VNCoreMLRequest](https://developer.apple.com/documentation/vision/vncoremlrequest.md)
- **`VNImageCropAndScaleOption` cases:**
  - `centerCrop`: scales the shorter side to fit, then centre-crops
  - `scaleFit`: scales the longer side to fit, preserving aspect ratio
  - `scaleFill`: resizes to fill, distorting aspect ratio
  - rotate-90 variants of fit and fill
  - [Apple VNImageCropAndScaleOption](https://developer.apple.com/documentation/vision/vnimagecropandscaleoption.md)
- **coremltools image inputs:**
  - Without `inputs=[ct.ImageType(...)]`, inputs are `MLMultiArray`.
  - `ImageType` applies `y = x*scale + bias`, with one global scale and per-channel bias. torchvision mean/std normalisation "can only be approximated" (scale = 1/(0.226·255)).
  - `ImageType` "suits on-device use with Vision, which can resize images automatically" and copies `CVPixelBuffer`s efficiently, whereas an `MLMultiArray` copy "can become a bottleneck".
  - ML programs need iOS 15+.
  - [coremltools image inputs](https://apple.github.io/coremltools/docs-guides/source/image-inputs.html)
- **Versions:** coremltools 9.0 (2025-11-10, BSD-3) is the latest PyPI release and is the version RF-DETR benchmarks against. SAHI 0.14.0 (2026-11-01) is MIT. — [PyPI coremltools](https://pypi.org/pypi/coremltools/json); [PyPI sahi](https://pypi.org/pypi/sahi/json); [GitHub API obss/sahi](https://api.github.com/repos/obss/sahi)
- **RF-DETR Core ML specifics:**
  - Outputs are positional (`dets, labels[, masks]`) and need Swift-side decoding.
  - fp16 plus the iOS 15 program is deliberate: iOS 16 lost about 3 AP on the ANE.
  - Choose `computeUnits = .cpuAndNeuralEngine` and measure against `.all`; Seg-Nano was faster on CPU+NE (38.8 ms) than ALL (44.2 ms) on Mac.
  - The first ANE load compiles for about 5–10 s, then is cached.
  - [rf-detr coreml.md](https://raw.githubusercontent.com/roboflow/rf-detr/develop/docs/exports/coreml.md)
- **Ultralytics alternative:** `nms=True` embeds NMS (detect and segment); `.cpuAndNeuralEngine` is recommended. — [Ultralytics Core ML docs](https://docs.ultralytics.com/integrations/coreml/)
- **SAHI (ICIP 2022):** sliced inference added +6.8, +5.1 and +5.3 AP for FCOS, VFNet and TOOD. With slicing-aided fine-tuning the totals were +12.7, +13.4 and +14.5 AP, on the aerial datasets VisDrone and xView, where objects are tiny. — [arXiv 2202.06934](https://arxiv.org/abs/2202.06934)

### Inferences
**Pixel budget.** Assume a portrait 4032×3024 still with the pills' 7 cm spread across 80% of the 3024 px width. The frame is then about 8.75 cm wide (about 345 px/cm), so a 7 mm tablet is about 240 px long in the full-resolution photo.

- Letterboxing (`scaleFit`) the whole 3:4 frame into a square N gives a pill length of about 0.06·N:

  | N | 7 mm pill |
  |---|---|
  | 640 | ~38 px |
  | 576 | ~35 px |
  | 512 | ~31 px |
  | 384 | ~23 px |
  | 312 | ~19 px |

  Short axes of oval tablets are about half that. COCO "small" is under 32×32 px.
- A centre square crop of 3024×3024 (`centerCrop`, or crop first in Core Image) loses no pills if the on-screen guide keeps them in the middle. It raises pill length to about 0.08·N: **~51 px at 640, ~41 px at 512, ~31 px at 384**.
- Recommendation: train and export at 576–640 for detection (multiple of 32) or 576–624 for segmentation (multiple of 24), and use the centre crop. That puts 6–9 mm pills in the "medium" range without tiling.

**Why not tile?**
- SAHI's gains are for tiny objects (aerial imagery).
- Here, 2×2 tiles would split pills at tile seams and need cross-tile merging. That is a source of both duplicates and merges, the two safety failures.
- If more pixels are needed, prefer one larger input (e.g. 768) or a two-stage approach: detect the palm or pill cluster, crop that region, then run the detector.

**Swift pipeline (iOS 17):**
1. Capture the full-resolution still.
2. `CGImage` → centre-square `CIImage` crop → (with an `ImageType` model) `VNCoreMLRequest`, setting `imageCropAndScaleOption = .scaleFill`, since the crop is already square. Run it on a background serial queue. Alternatively, render to a `CVPixelBuffer` and call `MLModel.prediction` directly.
3. Decode the outputs: sigmoid on the logits; keep queries above a recall-tuned threshold (e.g. 0.3); convert `dets` from normalised cx,cy,w,h to the crop's pixel coordinates; add the crop's origin to get full-resolution coordinates. Handle `CGImagePropertyOrientation` before cropping.
4. Crop each pill from the full-resolution still with 10–20% padding. Optionally apply the mask, or run subject lifting on the crop, to blank the background before sending to OpenAI.

**Safety guards cheap enough to add on device:**
- Compare the detected count with the expected pill count for that dose, and prompt a retake on mismatch.
- Flag merge suspects: any box whose area is more than about 1.7× the median pill box, or whose mask has two convexity-defect lobes.
- Flag pairs of boxes with IoU above about 0.3 and ask the user to spread the pills.
- Run the model on the live preview, throttled, and only auto-capture when the count is stable for N frames.

**Size budget.** About 55–70 MB fp16 for RF-DETR Small/Seg-Small, against about 7 MB for Create ML transfer learning and a few MB for YOLO26n. On-demand resources or post-install download are options if app size matters.

### Gaps
- There is no documented pixel scale of the app's actual capture format (12 MP vs 24/48 MP, crop region) in my sources. The calculations above assume 4032×3024.
- There is no published evidence on RF-DETR-Seg mask quality for 30–50 px objects.
- I did not verify whether Vision accepts RF-DETR's multi-output mlprogram with an `ImageType` input without issues on iOS 17 specifically. The community adapter claims `ImageType` support but publishes no iOS test.

---

## 6. Recommendation and a realistic 1–2 week plan

### Takeaway
Train **RF-DETR Seg-Small** (Apache-2.0, masks), or detection Small if masks prove unnecessary:
- input about 576–624, on a centre-square crop
- pre-train on 5k–20k synthetic ePillID-on-palm images
- fine-tune on about 150–300 hand-annotated real palm and table photos
- test on a frozen set of about 100 real photos
- export with `format="coreml"`, fp16, iOS 15 program, and run with `.cpuAndNeuralEngine`

Also train a **Create ML transfer-learning detector** on the same real boxes in one afternoon. It is the licence-free, conversion-free fallback and the baseline to beat.

Use SAM 3 or SAM 2 offline only, to speed up labelling. Keep Ultralytics YOLO26-seg as an AGPL-flagged benchmark, not a dependency.

For a commercial version, retrain on non-research-only data: self-shot photos, MEDISEG, CC BY Roboflow sets, and own pill cut-outs.

### Cited Findings
- RF-DETR detection Nano–Large and all Seg sizes are Apache-2.0. Native Core ML export exists (experimental) and fp16 COCO mAP equals PyTorch's. — [rf-detr README](https://github.com/roboflow/rf-detr); [coreml.md](https://raw.githubusercontent.com/roboflow/rf-detr/develop/docs/exports/coreml.md)
- Create ML transfer learning works with about 80 examples per class, needs iOS 14+, and is about 5× smaller than the full network. — [Apple Tech Talk 10155](https://developer.apple.com/kr/videos/play/tech-talks/10155/?time=764)
- A synthetic-only pill localiser trained from NIH references was good enough to support 94% top-5 identification. — [npj Digit Med 2019](https://europepmc.org/article/PMC/PMC6550183)
- Real multi-pill, closed-set detection reached mAP50 99.5% with 3 classes and 80.1% with 32 classes (YOLOv9, MEDISEG). — [arXiv 2603.10825](https://arxiv.org/html/2603.10825)
- Licence flags:
  - **AGPL:** Ultralytics, YOLOE ([Ultralytics license](https://www.ultralytics.com/license); [yoloe](https://github.com/THU-MIG/yoloe))
  - **GPL:** YOLOv9 original, YOLO-World ([GitHub API](https://api.github.com/repos/WongKinYiu/yolov9))
  - **Non-commercial:** DEIMv2 ([DEIMv2 LICENSE](https://raw.githubusercontent.com/Intellindust-AI-Lab/DEIMv2/main/LICENSE.md)), EdgeSAM ([EdgeSAM LICENSE](https://raw.githubusercontent.com/chongzhou96/EdgeSAM/master/LICENSE)), YOLO-NAS weights ([LICENSE.YOLONAS](https://raw.githubusercontent.com/Deci-AI/super-gradients/master/LICENSE.YOLONAS.md))
  - **PML:** RF-DETR Atto, Femto, Pico, XL and 2XL detection ([rf-detr README](https://github.com/roboflow/rf-detr))
  - **Research-only data:** ePillID, C3PI ([ePillID](https://github.com/usuyama/ePillID-benchmark); [C3PI](https://catalog.data.gov/dataset/computational-photography-project-for-pill-identification-c3pi))

### Inferences
**Expected accuracy (to be verified, not sourced).** For one "pill" class, in-domain, at about 40–50 px per pill, a fine-tuned modern detector should reach per-pill recall at IoU 0.5 in the high-0.9s on held-out palm photos. MEDISEG's 3-class 99.5% mAP50 suggests pill-vs-background is easy in-domain.

The hard residual cases are:
- touching same-colour pills (merges)
- beige pills on light skin
- palm-crease and fingernail false positives
- glare

Set acceptance criteria up front, for example on the 100-photo test set:
- per-pill recall ≥ 99%
- 0 merged crops
- at most 1 false positive per 20 photos

Treat any miss as a retake trigger via the expected-count check.

**Plan, week 1:**
- **Day 1 — baseline and eval set.**
  - Shoot about 100 test photos: ≥3 people and skin tones, palm and table, 2–10 pills including touching pairs, warm, cool and dim light, 1× and 3× zoom. Use paper demo pills plus a few real tablets.
  - Label boxes and polygons in Roboflow, CVAT or X-AnyLabeling with SAM-assisted clicks.
  - Measure the current `VNGenerateForegroundInstanceMaskRequest` cropper on this set (misses and merges). This is the number to beat.
- **Days 1–2 — real training set.** Shoot 150–300 more photos and 50–150 empty-palm and table backgrounds. Pre-label with SAM 3, or with SAM 2 using boxes from a quick first model, then correct by hand.
- **Days 2–3 — synthetic generator** (recipe in §4). Output COCO JSON with polygons; 5k–20k images, plus hard negatives.
- **Days 3–4 — training** on one CUDA GPU (Colab, a university GPU, or rented).
  - `RFDETRSegSmall(resolution=576)` or `RFDETRSmall(resolution=576)`.
  - Stage A: synthetic only, about 10–20 epochs.
  - Stage B: real plus synthetic mix, about 30–50 epochs.
  - Also: the Create ML transfer-learning baseline on the real boxes (Mac, about 1 hour).
  - Report per-pill recall, merges and false positives per photo at a recall-oriented threshold.
- **Days 5–6 — export and on-device run.**
  - `model.export(format="coreml", coreml_precision="float16")`, or the `rf-detr-to-coreml` adapter for an `ImageType` input.
  - Check parity on the Mac with `RFDETRInference` on the test set.
  - In Swift: centre-crop → model → decode → map to full resolution → padded crops → existing OpenAI call.
  - Measure latency and memory on the oldest supported iPhone, comparing `.cpuAndNeuralEngine` with `.all`.
- **Day 7 — safety layer.** Expected-count check, merge-suspect and overlap heuristics, retake UI.

**Plan, week 2 (hardening):**
- Error analysis on misses and merges; shoot 50–100 targeted real photos of the failure modes; retrain.
- Calibrate the threshold for recall.
- Optional: per-box subject lifting or SAM 2.1 tiny refinement for cleaner crops.
- Write a licence and data README covering CC BY attribution and the research-only status of ePillID-derived weights.

**Fallbacks if RF-DETR Core ML export blocks progress:**
1. Ship the Create ML box detector (licence-clean) plus per-box subject lifting for masks.
2. For the class demo only, YOLO26n-seg under AGPL, with the source made public as AGPL requires (per Ultralytics' terms).

### Gaps
- There is no public benchmark of any detector on in-palm pill photos, so the accuracy expectations above are reasoned, not measured.
- No measured iPhone latency or memory exists yet for RF-DETR Seg-Small Core ML. It must be measured on the team's devices in week 1.
- I did not confirm whether the University of Waterloo course or the university has rules on AGPL or research-only data in student projects.
