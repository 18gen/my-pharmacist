# Image-based pill recognition from real-world smartphone photos: published evidence (as of Oct 2026)

Context: "My Pharmacist" (Waterloo CS497 iOS prototype). About 4 pills held in the palm, located and identified, then compared to a closed set of a few pharmacist-registered medications. Safety priority: never falsely confirm a wrong pill.

Throughout: **REF** means clean, studio-style reference images. **CONSUMER** means phone photos taken under uncontrolled conditions. Most of the headline numbers in the literature are retrieval over hundreds to thousands of classes. They are not closed-set verification over 3 to 10 classes.

## NIH/NLM Pill Image Recognition (PIR) Challenge, 2016

### Takeaway
The first public benchmark on consumer photos was hard. Each query showed one pill on a uniform background, and the winner reached only MAP 0.27 and about 43% top-5 against 1,000 unseen pill types. Embossed or debossed and white round or oval pills were the worst cases.

### Cited Findings
- **Task.** Rank NLM RxIMAGE reference images by similarity to consumer-quality query photos. This is a retrieval task. Each query was a single pill on a uniform background, photographed from any angle with consumer cameras. — [Yaniv et al., PIR Challenge results (PMC5973812)](https://pmc.ncbi.nlm.nih.gov/articles/PMC5973812/)
- **Data.** Training had 1,000 pills, 2,000 REF images (both sides) and 5,000 CONSUMER images. The segregated test set had 1,000 *different* pills, 2,000 REF and 5,000 CONSUMER images. A non-segregated test reused the same 1,000 training pills with 6,486 new consumer images. — [PMC5973812](https://pmc.ncbi.nlm.nih.gov/articles/PMC5973812/)
- **Metric.** MAP was the sole official criterion, with MRR also reported for the top 3. Prizes were $25k, $15k and $5k. Submissions ran 4 Apr to 31 May 2016 and winners were announced 1 Aug 2016. — [PMC5973812](https://pmc.ncbi.nlm.nih.gov/articles/PMC5973812/); [Federal Register notice](https://www.govinfo.gov/content/pkg/FR-2016-01-19/pdf/2016-00801.pdf); [NLM Technical Bulletin](https://nlm.nih.gov/pubs/techbull/ma16/brief/ma16_pill_challenge.html)
- **Winners, segregated-test MAP on CONSUMER queries.**
  - 1st, msumpf (Michigan State "Mobile Pill Finder"): MAP 0.27, from a CNN (Caffe) plus SIFT fused with weights 0.8 and 0.2.
  - 2nd, castelo (TensorFlow CNN): 0.09.
  - 3rd, nhatuntsev (hand-crafted weighted colour and shape distances): 0.08.
  - The correct reference was in the top 5 for 43%, 12% and 11% of the 5,000 queries, which appears to be in rank order.
  - For msumpf, the correct reference was in the top 10 for about 54% of queries and the top 40 for about 75%.
  - No top-1 was reported.
  - Source: [PMC5973812](https://pmc.ncbi.nlm.nih.gov/articles/PMC5973812/)
- **Overfitting.** msumpf scored MAP 0.41 on training pills and 0.27 on the unseen-pill test. — [PMC5973812](https://pmc.ncbi.nlm.nih.gov/articles/PMC5973812/)
- **Difficulty factors, top-5.** Printed capsules were about 74%, printed tablets about 66%, and embossed or debossed pills about 34%. White round and white oval pills made up 36.3% of the test set and scored MAP of only about 0.08 and 0.09. The authors cite free camera pose and lighting as problems and suggest including a reference object such as a coin. — [PMC5973812](https://pmc.ncbi.nlm.nih.gov/articles/PMC5973812/)
- **Conflicting figure.** A later paper (npj Digital Medicine, 2019) describes the winner's pipeline as follows. Reference images were localised with gradients and morphology. Consumer images used SVM-based pill detection. Identification used modified deep ranking. That paper quotes the winner's top-5 as **83.3%**. This conflicts with the 43% in the official results paper, and may be a different evaluation subset or definition. I did not verify it. — [npj Digit Med 2019 (PMC6550183)](https://pmc.ncbi.nlm.nih.gov/articles/PMC6550183) vs [PMC5973812](https://pmc.ncbi.nlm.nih.gov/articles/PMC5973812/)

### Inferences
- The challenge used open-set retrieval with no training images of the test pills. It is a much harder problem than a closed set of 3 to 10 known medications, so its low numbers are a floor, not an estimate for this app.
- The finding that embossed and white round pills are hard applies directly. Many common generics are small white round debossed tablets.

### Gaps
- I did not resolve the 43% vs 83.3% top-5 discrepancy.
- The official winner write-ups and the challenge site (pir.nlm.nih.gov/challenge) were not fetched.

## ePillID benchmark (Usuyama, Delgado, Hall, Lundin; CVPR Workshops 2020)

### Takeaway
ePillID is the largest public low-shot benchmark. With one REF image per class, multi-head metric learning reaches about 92% MAP@1 when both sides of the pill are photographed. With only one side it falls to about 76% MAP@1. Plain classifiers do far worse, at about 35 to 57% MAP@1. Look-alike pills that differ by one imprint character still fail.

### Cited Findings
- **Size.** About 13k images covering 9,804 appearance classes (two sides each for 4,902 pill types). Most classes have only one REF image, so the setting is low-shot and fine-grained. — [arXiv 2005.14288](https://arxiv.org/abs/2005.14288)
- **Images.** 3,728 CONSUMER images cover 1,920 appearance classes (960 pill types), and 9,804 REF images cover all 4,902 types. Consumer images are split 80/20 train/holdout with pill types mutually exclusive between the two. The training split is further split into 4 folds for cross-validation. Results are the mean ± std over folds. — [ar5iv full text](https://ar5iv.labs.arxiv.org/html/2005.14288)
- **Results on the holdout (CONSUMER queries vs REF gallery, %).**
  - Best plain classifier: ResNet152 B-CNN, with MAP 72.65 ± 1.69, MAP@1 56.75 ± 2.51 and GAP 44.75.
  - Best multi-head metric learning with both-sides input: ResNet152 + compact bilinear pooling (CBP), with MAP 95.76 ± 0.40, **MAP@1 92.01 ± 0.67**, GAP 81.20 and GAP@1 91.19.
  - ResNet50 CBP: MAP@1 91.01.
  - Smallest metric-learning model, ResNet18: MAP@1 84.38.
  - Single-side input, as an ablation: ResNet152 reached MAP@1 76.42 and MAP 85.25, and ResNet50 reached MAP@1 72.56.
  - Top-1 and top-5 were not reported as such. MAP@1 is the closest equivalent.
  - Source: [ar5iv 2005.14288](https://ar5iv.labs.arxiv.org/html/2005.14288)
- **Failures.** All four models failed on shiny materials under lighting variation, and on pill types that look nearly identical and differ by one imprint character. The authors also say off-the-shelf OCR is unlikely to work on pills because of low-contrast imprints, irregular layouts, and capsule or gel materials. — [ar5iv 2005.14288](https://ar5iv.labs.arxiv.org/html/2005.14288)
- **Availability and licence.** Code is on GitHub under MIT, and the data is under Releases. The README says the dataset and software are "released for research purposes only" and are derived from NIH NLM data, and it tells users to check the original source terms. There is no formal data licence. The repo had about 100 stars, 18 forks and 7 open issues when fetched in Oct 2026. — [GitHub usuyama/ePillID-benchmark](https://github.com/usuyama/ePillID-benchmark)

### Inferences
- Metric learning against a reference image (embedding plus nearest neighbour) is the approach with the best evidence in the one-reference-per-class setting. It suits a pharmacist-registered list, where each medication can be enrolled from one or a few reference photos.
- Capturing both faces of the pill is worth about 15 points of MAP@1. In a palm scan, only one face is visible per pill.

### Gaps
- No ePillID results are published for small closed candidate sets.
- I did not confirm whether the data release is still downloadable in 2026, only that the repo is up.

## Datasets: CURE, VAIPE, MEDISEG, NIH C3PI, Roboflow/Kaggle

### Takeaway
VAIPE is the only major public dataset that explicitly includes in-hand, multi-pill smartphone photos. MEDISEG (2026, CC BY 4.0) offers realistic multi-pill images with occlusion, in dosette boxes rather than hands. CURE is mostly single pills and includes synthetic images. C3PI/RxIMAGE is sunset, its terms say research only, and its catalogue licence field lists ODbL.

### Cited Findings
- **CURE** (Ling et al., CVPR 2020, "Few-Shot Pill Recognition").
  - 8,973 images, 196 classes, about 40 to 50 instances per class, compared with about 7 in the NIH data. The paper proposed W2-net for segmentation. — [CVPR 2020 paper](https://openaccess.thecvf.com/content_CVPR_2020/papers/Ling_Few-Shot_Pill_Recognition_CVPR_2020_paper.pdf); [mlanthology entry](https://mlanthology.org/cvpr/2020/ling2020cvpr-fewshot/)
  - The full PDF returned 403, so I could not fetch the paper's own accuracy numbers.
  - A later 2024 paper reports 89.65% accuracy on CURE in a 5-way 1-shot setting. That figure comes only from the search snippet. — [search result: XJTLU "Transfer Learning for Few-shot Pill Image Recognition"](https://scholar.xjtlu.edu.cn/en/publications/transfer-learning-for-few-shot-pill-image-recognition/)
  - The 2026 MEDISEG authors say CURE consists mainly of single isolated pills under controlled conditions, includes synthetic images, and has incomplete instance-segmentation labels. — [MEDISEG arXiv 2603.10825](https://arxiv.org/html/2603.10825)
- **VAIPE** (Vietnam, PLOS ONE 2023).
  - 9,426 images (also described as about 10k), 96 pill labels, about 5 to 10 pills per image.
  - Smartphone capture, more than 20 devices, more than 50 lighting conditions, more than 50 backgrounds, with pills **in hand and out of hand**.
  - Train/test split of 7,514 / 1,912 images, plus 1,527 prescriptions.
  - Public "vaipe-minimal-dataset" on Kaggle. No dataset-specific licence is stated, and the article itself is CC BY 4.0.
  - Source: [PMC10538799](https://pmc.ncbi.nlm.nih.gov/articles/PMC10538799/)
- **VAIPE contextual subset (PIKA).** 3,087 images, 76 classes, from 168 patients' prescriptions at 4 Vietnamese hospitals. Train: 2,058 images / 116 prescriptions. Test: 1,029 / 52. Five images per prescription, phone photos in unconstrained settings. — [PIKA, arXiv 2208.02432](https://ar5iv.labs.arxiv.org/html/2208.02432)
- **MEDISEG** (City St George's, University of London; arXiv March 2026).
  - 8,262 real images, 32 pill types. There is also a 3-Pills subset with deliberate look-alikes: two share a shape, and one shares a colour.
  - Up to 13 pills per frame, in 4×7 dosette boxes or trays, often overlapping or occluded. Every image has instance masks.
  - No in-hand images are mentioned.
  - CC BY 4.0, at [doi 10.25383/city.28574786.v1](https://doi.org/10.25383/city.28574786.v1).
  - Source: [arXiv 2603.10825](https://arxiv.org/html/2603.10825)
- **NIH C3PI / RxIMAGE.**
  - Contents: about 4,000 REF images under controlled light and about 133,000 consumer-grade images for training recognisers.
  - Status: the project was sunset in 2018 and no new images are being added.
  - Terms: metadata says "research and development purposes only", and the data.gov licence field points to ODbL. It is not a clear public-domain dedication.
  - Source: [data.gov C3PI record](https://catalog.data.gov/dataset/computational-photography-project-for-pill-identification-c3pi-82201)
- **Roboflow Universe.** Many small community "pill detection" datasets exist, several labelled CC BY 4.0, for example [Irwxn "pill"](https://universe.roboflow.com/irwxn/pill-ajpxz) and [Pill detection 2](https://universe.roboflow.com/pill-vpb4v/pill-detection-2-xixoe). I found none that clearly contains in-hand images. Quality and documentation vary.

### Inferences
- For a palm scan, VAIPE is the closest public training and evaluation source for both detection and the in-hand domain. Its pills are Vietnamese-market, so it serves detector pretraining, not identity labels for North American drugs.
- MEDISEG's CC BY 4.0 licence makes it the cleanest one for redistribution in a university project.

### Gaps
- I did not verify the VAIPE Kaggle licence.
- I found no public dataset dedicated to pills held in a palm.

## 2021–2026 methods: detection + classification, metric/few-shot, imprint-aware, prescription context, VLMs

### Takeaway
- **Detection.** Modern detectors (Faster R-CNN, YOLOv5/8/9) localise pills well.
- **Classification in the wild.** On VAIPE, detection plus classification mAP is about 58 to 70.
- **Prescription context.** Adding prescription context gives large gains: PGPNet adds about 9 to 12% mAP, and PIKA raises F1 from about 0.52 to 0.86.
- **Imprints.** Imprint-aware pipelines reach about 78% top-1 on consumer photos with one image per pill.
- **General VLMs.** A general VLM (ChatGPT-4) got 22 of 25 clean images right, and every miss was an imprint misreading or a look-alike or strength confusion.

### Cited Findings
- **PGPNet** (VAIPE, PLOS ONE 2023): Faster R-CNN plus prescription co-occurrence, relative-size and visual-semantic graphs.
  - VAIPE test mAP: Faster R-CNN R50-FPN 63.7 → 69.7, R50-C4 62.6 → 68.3, SwinV2-T 59.7 → 62.6, YOLOv5s 57.5 → 63.4, YOLOv5n 37.9 → 43.0.
  - Heavy-occlusion subset: 59.2 → 67.5.
  - Source: [PMC10538799](https://pmc.ncbi.nlm.nih.gov/articles/PMC10538799/)
- **PIKA** (2022): a prescription knowledge graph injected through attention. The classifier still scores all 76 classes, so the candidate set is **not** hard-restricted.
  - Macro F1: ResNet-18 0.516 → **0.857**, ResNet-50 0.521 → 0.810, VGG-16 0.501 → 0.549.
  - Ablation: removing the pseudo-classifier drops F1 from 0.810 to 0.699.
  - Source: [arXiv 2208.02432](https://ar5iv.labs.arxiv.org/html/2208.02432)
- **PIMA** (pill-prescription matching on VAIPEPP): reported accuracy improves from 19.09% to 46.95% over baselines. This is from a search snippet only and was not verified. — [search result, IEEE Access 2024 via DOAJ](https://doaj.org/article/4f61dc8b4b0147f69fc440115c0d35e3)
- **Heo et al., JMIR 2023:** separate shape, colour and imprint modules. Imprint text is detected, then corrected by a language model with a coordinate encoding. 24,404 images in total.
  - **Top-1 is 78% on CONSUMER images when trained with only one image per pill.**
  - Top-1 is 85.6% (Korea DB) and 74.5% (US DB) for pill types not seen in training.
  - Ablation: the language-model imprint correction "significantly improves" identification.
  - Source: [JMIR 2023;25:e41043 (DOAJ record)](https://doaj.org/article/8955d7ce362743b5ae1c39bc931b9269); [JMIR article](https://www.jmir.org/2023/1/e41043)
- **2025 Springer article:** YOLOv5s plus a Deep Text Spotter for imprints, trained on NLM data plus real-world images. It reports 97.8% detection accuracy. The metric definition was unclear, so it is not comparable to identification accuracy. — [Springer s44291-025-00122-6](https://link.springer.com/article/10.1007/s44291-025-00122-6)
- **Small closed-set YOLO studies.**
  - 20 pill types, 994 images: YOLOv5 mAP 94.83% and recall 95%. — [Mekatronika 2024](https://journal.ump.edu.my/index.php/mekatronika/article/view/11020)
  - MEDISEG baselines, YOLOv8/v9 mAP@50: **99.5% on 3 classes and 80.1% on 32 classes**. — [arXiv 2603.10825](https://arxiv.org/html/2603.10825)
- **Few-shot detection under domain shift** (Chu, Tarroni, Li; arXiv March 2026, submitted to EMBC 2026).
  - Classification of novel pills "saturates" even with 1 labelled example. Localisation and recall drop markedly with overlap and occlusion. Training on realistic multi-pill data improves robustness. — [arXiv 2603.10833](https://arxiv.org/abs/2603.10833)
  - Foreground classification accuracy on an overlap-only test, MEDISEG-trained vs CURE-trained: 0.406 vs 0.131 at 1-shot, 0.625 vs 0.372 at 5-shot, 0.740 vs 0.558 at 10-shot. — [arXiv 2603.10825](https://arxiv.org/html/2603.10825)
- **VLM: ChatGPT-4** (Renal Failure, Sept 2024).
  - Setup: 25 nephrology drugs, iPhone 13 Pro Max, about 15 cm away, grey background, 2 pills per image showing front and back, prompt "What is this medication?" with browsing enabled.
  - Result: 22 of 25 (88%) fully correct on name, dose and imprint.
  - Failures were imprint misreads (NF 06 → NF 05, TEVA 2089 → TEVA 2003, 660 → 550) and look-alike or wrong-strength answers. All three misses were fixed once the correct imprint was supplied.
  - Answers on the misses changed between rounds, which contradicts the paper's claim of consistency.
  - Source: [PMC11391868](https://pmc.ncbi.nlm.nih.gov/articles/PMC11391868/)

### Inferences
- The strongest evidence-backed architecture for this app has four parts:
  1. A class-agnostic pill detector or segmenter, pretrained on VAIPE or MEDISEG-like multi-pill data.
  2. A metric-learning embedding matched against the patient's enrolled reference images.
  3. Optional imprint reading as a confirming signal.
  4. Hard restriction to the prescription candidate set, plus an "unknown" rejection threshold.
- VLM evidence shows imprint misreading and strength confusion are the main failure modes. That fits a "never falsely confirm" policy: output only "matches enrolled medication X" when confidence is high, and otherwise output "cannot confirm".

### Gaps
- I found no published head-to-head of GPT-4o, Gemini or Claude on multi-pill or in-hand pill ID.
- Zeng et al.'s MobileDeepPill (2017) was not retrieved here, so its numbers are not cited.

## Factors affecting accuracy (imprint, background, lighting, classes, look-alikes, strength; hand vs flat surface)

### Takeaway
Background, flash and exposure can swing accuracy dramatically. In one 19-class study, the best top-1 was only 51.1%. The other main factors are:
- whether the imprint is printed or embossed (about 74% vs 34% top-5 in the NIH challenge);
- white round or oval pills;
- shiny materials;
- one-character imprint differences and strength variants.

No study directly quantified palm vs flat surface.

### Cited Findings
- **Cha et al., JMIR Med Inform 2021.**
  - 19 medications under 12 conditions: black or white background × flash on or off × 3 exposure values.
  - Best top-1 was **51.1%** (white background, flash on, EV +2.0). Best top-5 was 78.4% (white, flash, EV 0).
  - On black backgrounds, lower EV raised accuracy.
  - Accuracy generally rose as the colour difference from the reference images fell.
  - Source: [PMC8367115](https://pmc.ncbi.nlm.nih.gov/articles/PMC8367115/); [JMIR](https://medinform.jmir.org/2021/7/e26000)
- **NIH challenge.** Imprint type (printed capsule about 74%, printed tablet about 66%, embossed or debossed about 34% top-5) and white round or oval pills (MAP about 0.08 to 0.09) were the dominant failure groups. — [PMC5973812](https://pmc.ncbi.nlm.nih.gov/articles/PMC5973812/)
- **ePillID.** Shiny material under lighting variation and one-character imprint differences defeated all models. One-side vs two-side input changed MAP@1 from about 76% to about 92%. — [ar5iv 2005.14288](https://ar5iv.labs.arxiv.org/html/2005.14288)
- **Number of classes.** YOLO mAP@50 was 99.5% with 3 classes vs 80.1% with 32 classes on the same MEDISEG capture protocol. — [arXiv 2603.10825](https://arxiv.org/html/2603.10825)
- **Occlusion and overlap.** On VAIPE heavy occlusion, Faster R-CNN mAP fell to 59.2. In 2026 work, overlap and occlusion mainly hurt localisation and recall. — [PMC10538799](https://pmc.ncbi.nlm.nih.gov/articles/PMC10538799/); [arXiv 2603.10833](https://arxiv.org/abs/2603.10833)
- **Strength and look-alikes.** ChatGPT-4's errors included the same drug at a wrong strength and look-alike different drugs. — [PMC11391868](https://pmc.ncbi.nlm.nih.gov/articles/PMC11391868/)
- **In hand.** VAIPE includes in-hand and out-of-hand photos but reports no separate accuracy for each. — [PMC10538799](https://pmc.ncbi.nlm.nih.gov/articles/PMC10538799/)
- **Prior palm-based concept.** A University of Illinois (ADSC) project page describes placing a pill on the palm and photographing it, but gives no accuracy. — [Illinois ADSC page](https://publish.illinois.edu/immersivetelepresence/visual-recognition-of-medication/)

### Inferences
- A palm is a non-uniform, skin-coloured background with shadows. By analogy with Cha et al.'s background and colour-difference effects, a palm likely reduces accuracy compared with a plain contrasting tray. This has not been measured.
- Practical mitigations include a guided capture with a plain card or tray option, torch or flash control, and enrolling the reference images under similar conditions.

### Gaps
- I found no study that quantifies palm vs flat-surface accuracy.

## Effect of restricting to a small candidate set (patient's own 3–10 medications)

### Takeaway
The evidence is indirect but consistent: fewer classes and prescription context raise accuracy substantially. Examples are 99.5% mAP@50 at 3 classes vs 80.1% at 32, and F1 rising from about 0.52 to 0.86 with prescription context. No paper evaluates a hard-restricted 3 to 10 class verification task with a rejection option.

### Cited Findings
- **Class count.** MEDISEG, same protocol: 3 classes, including deliberate look-alikes, gave 99.5% mAP@50. 32 classes gave 80.1%. — [arXiv 2603.10825](https://arxiv.org/html/2603.10825)
- **Prescription co-occurrence context.** PIKA lifts F1 from about 0.52 to 0.86 with ResNet-18. PGPNet adds about 6 points of mAP (Faster R-CNN R50-FPN, 63.7 → 69.7). — [arXiv 2208.02432](https://ar5iv.labs.arxiv.org/html/2208.02432); [PMC10538799](https://pmc.ncbi.nlm.nih.gov/articles/PMC10538799/)
- **Few-shot classification.** It saturates at about 1 labelled example per novel class in a detection setting, while localisation stays the bottleneck. — [arXiv 2603.10833](https://arxiv.org/abs/2603.10833)
- **Small-set retrieval.** CURE 5-way 1-shot accuracy is reportedly 89.65%, from a snippet only. — [XJTLU record](https://scholar.xjtlu.edu.cn/en/publications/transfer-learning-for-few-shot-pill-image-recognition/)
- **Large-set baseline.** Even with about 960 holdout pill types, metric learning gets about 92% MAP@1 with both sides. — [ar5iv 2005.14288](https://ar5iv.labs.arxiv.org/html/2005.14288)

### Inferences
- With 3 to 10 enrolled medications, the real risk shifts. The main danger is no longer confusing similar classes within the set. It becomes:
  - a pill **not in the set** (wrong, old or other-household medication) being forced to its nearest enrolled class;
  - a look-alike pill of a different strength being matched.
- The design therefore needs open-set rejection (a distance threshold, margin to the second-best match, or an imprint check). Closed-set accuracy alone is not enough.

### Gaps
- I found no published measurement of false-accept rate for out-of-set pills against a small enrolled set.

## Real-world accuracy of smartphone pill-ID apps and pharmacist evaluations

### Takeaway
Rigorous evidence is thin. A 2021 systematic review found almost no accuracy studies. The small studies that exist show about 83 to 89% accuracy for clinicians using apps, and about 51% top-1 for a deep-learning recogniser under varied capture.

### Cited Findings
- **Systematic review (PLOS ONE 2021).** It covered 25 apps and 16 websites but only 2 database studies, and only one report on app accuracy (for falsified or substandard drugs). Most apps rely on imprint, colour and shape search, and few use photos. The authors call this a major evidence gap. — [PMC7861418](https://pmc.ncbi.nlm.nih.gov/articles/PMC7861418/)
- **Korean randomised study.** Residents and nurses, 10 per arm: an image-based identifier app gave 89% accuracy vs 83% for a conventional search app. — [KoreaMed Synapse](https://synapse.koreamed.org/articles/1122077)
- **Delgado et al., arXiv 2020.** A mobile-app pill ID for adherence and post-market surveillance; I did not fetch it. — [arXiv 2004.11479](https://arxiv.org/pdf/2004.11479)
- **Consumer Reports, 2014.** Of 7 apps, Drugs.com and Epocrates Pill ID were preferred, with advice to confirm with a pharmacist. This source is dated and paywalled. — [Consumer Reports](https://www.consumerreports.org/cro/news/2014/04/best-pill-identifier-apps/index.htm)
- **EAHP 2022 abstract.** A pharmacist-captured validation set of 200 images. Its results were not retrievable.

### Inferences
- There is no independent evidence that any commercial photo-based pill ID is reliable enough to confirm a pill without human check. A prototype should present results as "likely matches enrolled X, please confirm" rather than an authoritative confirmation.

### Gaps
- I found no 2024–2026 independent evaluation of commercial photo-based pill-ID apps (for example Drugs.com or Medscape image features).
- I did not retrieve full numbers for the Korean study or the EAHP abstract.
