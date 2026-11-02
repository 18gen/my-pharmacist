# Uncertainty Handling, Open-Set Rejection and Evaluation for In-Hand Pill Verification (as of Oct 2026)

Scope note: the task is closed-set *verification*. Each patient has a few registered medications (K ≈ 2–8). For every pill found in the palm, the system answers {registered med k | not one of mine | uncertain}, and then compares the set against what is due. The costliest error is a **false confirmation**: a wrong or unknown pill shown as "OK".

Sourcing convention: findings marked [search-verified] were confirmed in this session via search results or abstracts. Findings marked [primary, from prior knowledge] are well-known primary papers that I cite by canonical arXiv/DOI link but did not re-open in this session. The report writer should treat their exact numbers cautiously; their qualitative claims are standard in the field.

---

## Q1. Which open-set / OOD rejection techniques suit a tiny closed set with very little data?

### Takeaway
With a handful of classes and a few reference photos each, the simplest reliable option is **embedding distance to the nearest reference plus a margin (ratio) test, with thresholds set on a held-out calibration split that includes look-alike and distractor pills**. Max-softmax, energy and OpenMax need a trained classifier and enough data to fit it. Conformal prediction is a good *wrapper* for picking thresholds, but its guarantees are loose at small n.

### Cited Findings
- **A strong closed-set model is the main driver of open-set rejection.** Vaze et al. (ICLR 2022 oral) found that a classifier's ability to make the "none-of-the-above" call is highly correlated with its closed-set accuracy. Simply improving the closed-set accuracy of the max-softmax baseline reached state of the art on several OSR benchmarks. On their Semantic Shift Benchmark, the strong baseline and specialised OSR methods differed negligibly. — [Vaze et al., arXiv 2110.06207](https://arxiv.org/abs/2110.06207) [search-verified]
- **Max softmax probability (MSP)** is the standard OOD/misclassification baseline: thresholding the top softmax score. — [Hendrycks & Gimpel, ICLR 2017, arXiv 1610.02136](https://arxiv.org/abs/1610.02136) [primary, from prior knowledge]
- **Energy score** (logsumexp of logits) is a drop-in replacement for MSP that the authors report gives lower false-positive rates on OOD benchmarks than softmax confidence. — [Liu et al., NeurIPS 2020, arXiv 2010.03759](https://arxiv.org/abs/2010.03759) [primary, from prior knowledge]
- **OpenMax** adds an "unknown" class by fitting Weibull models to distances between activation vectors and per-class mean activations. It needs enough correct training examples per class to fit the tail distribution. — [Bendale & Boult, CVPR 2016, arXiv 1511.06233](https://arxiv.org/abs/1511.06233) [primary, from prior knowledge]
- **Non-parametric k-NN distance in embedding space** is an effective OOD score that makes no distributional assumptions. Its natural form is "distance from the test embedding to its k-th nearest training embedding, above a threshold means OOD". — [Sun et al., ICML 2022, arXiv 2204.06507](https://arxiv.org/abs/2204.06507) [primary, from prior knowledge]
- **Nearest-neighbour ratio test:** accept a match only if the nearest-neighbour distance is clearly smaller than the second-nearest (from a *different* class). Lowe introduced this for SIFT keypoint matching to reject ambiguous matches. — [Lowe, IJCV 2004](https://www.cs.ubc.ca/~lowe/papers/ijcv04.pdf) [primary, from prior knowledge]
- **Apple Vision feature prints:** `VNGenerateImageFeaturePrintRequest` returns a `VNFeaturePrintObservation`, and `computeDistance(_:to:)` returns a float where lower means more similar and identical images give 0.0. Community analysis suggests it is a Euclidean distance. Apple documents no upper bound or probabilistic meaning, so any "% similar" mapping must be calibrated by the developer. — [fritz.ai tutorial](https://fritz.ai/compute-image-similarity-using-computer-vision-in-ios/); [MWM/Medium analysis](https://medium.com/@MWM.io/apples-vision-framework-exploring-advanced-image-similarity-techniques-f7bb7d008763); [Apple Dev Forums thread on distance range](https://developer.apple.com/forums/thread/721760); [zenn.dev walkthrough](https://zenn.dev/shu223/articles/vision_image-feature-print) [search-verified; community sources, not Apple docs]
- **Selective classification:** given any confidence function, you can pick a threshold that guarantees a target risk (error rate among accepted predictions) with high probability, trading away coverage. The risk–coverage curve is the standard way to report this trade-off. — [Geifman & El-Yaniv, NeurIPS 2017, arXiv 1705.08500](https://arxiv.org/abs/1705.08500) [primary, from prior knowledge]
- **Conformal prediction** produces set-valued outputs with marginal coverage ≥ 1−α that holds for **any** calibration size n, but only *on average over calibration draws*. Coverage for one fixed calibration set is itself random. The tutorial suggests n ≈ 1000 is "sufficient for most purposes" for tight conditional coverage and gives a closed-form way to compute the n needed for a given tail probability δ. — [Angelopoulos & Bates, "A Gentle Introduction to Conformal Prediction", arXiv 2107.07511](https://arxiv.org/abs/2107.07511) [search-verified]
- **Adaptive prediction sets (APS/RAPS)** for image classifiers: conformal sets whose size grows with difficulty. A set with more than one med, or an empty set, maps naturally onto "uncertain". — [Angelopoulos et al., ICLR 2021, arXiv 2009.14193](https://arxiv.org/abs/2009.14193) [primary, from prior knowledge]
- **Pill-domain evidence on the reference-to-consumer gap:** in ePillID, most appearance classes have **only one reference image**. The best baseline (multi-head metric learning with bilinear features) "performed remarkably well", but error analysis showed it "still fail[s] to distinguish particularly confusing classes". — [Usuyama et al., CVPRW 2020, arXiv 2005.14288](https://arxiv.org/abs/2005.14288) [search-verified]
- Consumer photos and reference photos of the same pill "may look very different" because of real-world noise. — [JMIR Med Inform 2021 smartphone pill study](https://medinform.jmir.org/2021/7/e26000) [search-verified]
- I found **no published work on open-set rejection of unregistered pills** on CURE or ePillID (search for "open-set pill" returned only closed-set and few-shot work). — [Ling et al., CVPR 2020 "Few-Shot Pill Recognition"](https://openaccess.thecvf.com/content_CVPR_2020/papers/Ling_Few-Shot_Pill_Recognition_CVPR_2020_paper.pdf) [search-verified, absence noted]

### Inferences
- **Recommended rule for a student team (implementable in days):** for each detected pill crop, compute the embedding distance to every reference image of every registered med. Let d1 be the best distance (class c1) and d2 the best distance to any *other* class. **Confirm c1 only if** (a) d1 < τ_abs, **and** (b) d1/d2 < τ_ratio, **and** (c) for multi-view or burst capture, c1 wins in ≥ m of the frames. Otherwise output "uncertain" (if d1 is near the boundary) or "not one of mine" (if d1 ≫ τ_abs). Rule (a) handles unregistered distractors (the open-set case). Rule (b) handles look-alikes among the patient's own meds.
- **Set the thresholds by target false-accept rate, not accuracy.** On a calibration split, choose τ_abs as the largest value at which zero (or ≤ target) wrong or distractor pills pass. This is a selective-classification / conformal-style threshold. Report the abstention it costs.
- **Conformal prediction is worth using mainly as a principled threshold picker.** With about 100–300 calibration crops, the guarantee holds only in expectation and individual runs vary a lot. Framing it as "set size == 1 → confirm, otherwise → uncertain" is clean and easy to explain in a report.
- MSP, energy and OpenMax only become relevant if the team trains a classifier head. For per-patient sets that change, which is typical of this app, a retrieval/embedding design avoids retraining whenever a patient adds a med.
- Imprint text is the most discriminative cue for look-alikes. Generic global embeddings (such as Vision feature prints) are likely weak at it. This is an assumption, consistent with ePillID's error analysis and the GPT-4 imprint-misread errors in Q2.

### Gaps
- No pill-specific benchmark of distance or ratio thresholds for rejecting unregistered pills was found.
- How discriminative Apple feature prints are for fine-grained pills is undocumented. Teams must measure it.

---

## Q2. How should confidence be calibrated, and is LLM-verbalised confidence reliable?

### Takeaway
Temperature scaling is simple and effective *in-distribution* but can break under mild shift (new lighting, a new phone). LLMs' and VLMs' self-reported confidence is systematically overconfident and should **never** gate a confirmation on its own. Use consistency across repeated queries, or agreement with an independent recognizer, and calibrate empirically on your own data.

### Cited Findings
- **Modern deep nets are miscalibrated (overconfident).** A single scalar temperature fitted on a validation set ("temperature scaling") is a simple, effective fix in-distribution. — [Guo et al., ICML 2017, arXiv 1706.04599](https://arxiv.org/abs/1706.04599) [primary, from prior knowledge]
- **Under dataset shift, post-hoc calibration fails.** Ovadia et al. found that temperature scaling improves i.i.d. calibration but "can fail under even a mild shift", and that accuracy drops under shift while confidence does not. Deep ensembles were the most robust method, and about 5 members sufficed. — [Ovadia et al., NeurIPS 2019, arXiv 1906.02530](https://arxiv.org/abs/1906.02530); [Google Research blog](https://research.google/blog/can-you-trust-your-models-uncertainty/) [search-verified]
- **Text LLMs' verbalised confidence is highly overconfident.** Stated values mostly fall in the 80–100% range, usually in multiples of 5. Prompting strategies help but with diminishing returns for GPT-4. **Consistency-based methods** (sample several answers and measure agreement) beat verbalised confidence in most cases, and hybrids work best. — [Xiong et al., ICLR 2024, arXiv 2306.13063](https://arxiv.org/abs/2306.13063) [search-verified]
- **Vision-language models' verbalised confidence is notably miscalibrated** across tasks and settings, measured by ECE. Vision-centric reasoning models (o3 named) were better calibrated. The authors propose a two-stage "Visual Confidence-Aware Prompting". — [Xuan et al., "Seeing is Believing, but How Much?", EMNLP 2025](https://aclanthology.org/anthology-files/pdf/emnlp/2025.emnlp-main.74.pdf) [search-verified, abstract level]
- **Most current VLMs give high verbalised confidence on incorrect object-level answers.** A semantic-perturbation fine-tuning method (CSP) reduced calibration error. — [Zhao et al., arXiv 2504.14848](https://arxiv.org/abs/2504.14848) [search-verified, abstract level]
- Larger LMs can be reasonably calibrated *on token probabilities* for multiple-choice formats, and can be trained to predict P(True). This concerns internal probabilities, not free-text verbalised numbers. — [Kadavath et al., arXiv 2207.05221](https://arxiv.org/abs/2207.05221) [primary, from prior knowledge]
- **Pill-specific LLM evidence (small studies):** ChatGPT-4 identified 22/25 (88%) iPhone photos of nephrology drugs. Errors came from **misreading imprints** (e.g., "NF 06" read as "NF 05"). — [Renal Failure 2024, PMC11391868](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC11391868/) [search-verified]. A conference poster reported 23/25 lithium preparations identified and stressed the need for human oversight. — [CRRT 2024 poster](https://crrtonline.com/conference/posters_2024/76_Sheikh_Lithium.pdf) [search-verified; non-peer-reviewed poster]

### Inferences
- If OpenAI is used, do **not** prompt for "confidence 0–100" and threshold it. Instead: (1) constrain the output to a closed list (the patient's K meds + "none" + "unsure") via structured output. (2) Query N≈3–5 times, or with augmented crops, and require unanimity. (3) Require agreement with the on-device embedding match. (4) Measure the false-accept rate of the whole rule on the team's test set.
- A one-in-25 imprint misread (as in the GPT-4 study) is exactly the look-alike/strength failure that matters here. Different strengths of the same drug often differ only in imprint or colour, so test sets must include them.
- If a classifier is trained, temperature scaling is cheap enough to always apply. Still, re-check calibration on the "shifted" condition subsets (glare, low light, a different phone), because Ovadia et al. show it may not transfer.

### Gaps
- No study found that measures VLM verbalised-confidence calibration specifically for pill or medication images.
- The exact ECE numbers from the EMNLP 2025 VLM paper were not extracted.

---

## Q3. Does ensembling or two-model agreement reduce errors, and when is agreement misleading?

### Takeaway
Ensembles of independently trained models reliably improve accuracy and uncertainty, including under shift. But agreement only helps to the extent that the models' errors are **independent**. LLMs (and likely similar foundation models) share many errors, so "two models agree" can give false comfort, especially on hard look-alikes.

### Cited Findings
- Deep ensembles (independently initialised networks, averaged) give better predictive uncertainty than single models and are simple to implement. — [Lakshminarayanan et al., NeurIPS 2017, arXiv 1612.01474](https://arxiv.org/abs/1612.01474) [primary, from prior knowledge]
- Deep ensembles were the most robust uncertainty method under dataset shift, with about 5 members sufficient. Even so, ensemble calibration still degraded as shift increased. — [Ovadia et al., arXiv 1906.02530](https://arxiv.org/abs/1906.02530) [search-verified]
- **LLM errors are strongly correlated.** On one leaderboard dataset, when two models are both wrong they agree on the *same wrong answer* about 60% of the time. Larger, more accurate models have highly correlated errors **even across different architectures and providers**. — [Kim, Garg, Peng & Garg, ICML 2025, arXiv 2506.07962](https://arxiv.org/abs/2506.07962) [search-verified]
- A 2026 preprint argues that crowd and consensus strategies fail as a truth signal for LLMs because errors are strongly correlated. — [“Consensus is Not Verification”, arXiv 2603.06612](https://arxiv.org/html/2603.06612) [search-verified; preprint, venue unconfirmed]

### Inferences
- **The best agreement is between recognizers that rely on different cues**, e.g., (a) a global appearance embedding (shape/colour) and (b) imprint OCR or a cloud VLM reading the imprint. Two embedding models trained on similar web data are likely to share failure modes on look-alikes.
- **Use agreement as an AND gate for confirmation**, never as an OR gate. Any disagreement leads to "uncertain". This can only reduce false confirmations, at a measurable cost in abstention. Report both numbers.
- **Measure correlation directly on your test set:** report P(model B wrong | model A wrong) and the fraction of A-errors on which B gives the same wrong label. If that conditional is high, agreement buys little safety.

### Gaps
- No pill-domain study of error correlation between embedding matchers and VLMs was found.

---

## Q4. How many reference images per class are needed for few-shot verification?

### Takeaway
There is no pill-specific evidence-based number. Public benchmarks operate at 1 reference image per side (ePillID), and few-shot accuracy at 1-shot is modest. A practical, *assumption-based* target is **≥5–10 reference shots per pill per side, captured under varied lighting, backgrounds and orientations, and in hand**. Validate empirically by plotting accuracy and false-accept rate against the number of references.

### Cited Findings
- ePillID: for most appearance classes **only one reference image exists**. The dataset has 13k images and about 8–9.8k appearance classes (two sides per pill type). Versions disagree on the exact count: 8184 in the CVPRW paper vs 9804 on the dataset page. — [Usuyama et al., CVPRW 2020](https://openaccess.thecvf.com/content_CVPRW_2020/html/w54/Usuyama_ePillID_Dataset_A_Low-Shot_Fine-Grained_Benchmark_for_Pill_Identification_CVPRW_2020_paper.html) [search-verified]
- CURE was built specifically to have more instances per pill and more varied imaging conditions, framing pill recognition as few-shot. — [Ling et al., CVPR 2020](https://openaccess.thecvf.com/content_CVPR_2020/papers/Ling_Few-Shot_Pill_Recognition_CVPR_2020_paper.pdf) [search-verified]
- A 2025 self-supervised method reported **60.78% accuracy on CURE in a 1-shot 5-way setting**, a task size similar to this app's per-patient K. — [BRACIS 2025, "Self-Supervised Few-Shot Pill Image Recognition"](https://sol.sbc.org.br/index.php/bracis/article/view/40905) [search-verified, abstract level]
- Metric learning with textual cues from drug leaflets improved CURE Top-1 accuracy by 1.6% over the prior best. — [IET Image Processing, Dec 2024](https://doaj.org/article/6583b0dd1ee54c4491d3638c83dd3394) [search-verified]
- NLM Pill Image Recognition Challenge (2016): training data was 2000 reference images + 5000 consumer images from 1000 pills (about 5 consumer shots per pill). The challenge was judged by mean average precision on consumer→reference retrieval. — [NLM Tech Bulletin 2016](https://nlm.nih.gov/pubs/techbull/ma16/brief/ma16_pill_challenge.html); [NLM initial report](https://lhncbc.nlm.nih.gov/LHC-publications/pubs/ThenationallibraryofmedicinepillimagerecognitionchallengeAninitialreport.html) [search-verified]
- Smartphone conditions matter strongly. Across 12 real-world conditions, the best top-1 accuracy was 51.1% (white background, flash on, EV +2.0) and top-5 was 78.4%. Background colour, flash and exposure all significantly affected accuracy. — [JMIR Med Inform 2021;9(7):e26000](https://medinform.jmir.org/2021/7/e26000) [search-verified]
- Prototypical networks: averaging the embeddings of the k support shots into a class prototype is the standard few-shot metric-learning baseline. Accuracy rises with k (1-shot → 5-shot) on standard benchmarks. — [Snell et al., NeurIPS 2017, arXiv 1703.05175](https://arxiv.org/abs/1703.05175) [primary, from prior knowledge]

### Inferences
- 1-shot accuracy around 60% (5-way, CURE) means **single-reference enrolment is unsafe** for confirmation. Enrol several shots per side and keep *all* of them (nearest-of-many usually tolerates varied conditions better than one averaged prototype). This is an assumption to test.
- Enrolment protocol: for each med, capture both faces, 3 lighting conditions (daylight, indoor warm, flash), on the palm and on a neutral surface, plus slight rotations. That gives about 10–12 shots per side and takes the patient or pharmacist a few minutes.
- **Experiment to include in the report:** an ablation of k ∈ {1, 3, 5, 10} references per side, plotting false-accept rate at a fixed abstention rate. This answers the question empirically for the team's own data.

### Gaps
- No primary study gives a validated minimum number of reference images for pill *verification* at a target false-accept rate.

---

## Q5. Evaluation design: metrics, test-set construction, sample sizes, confidence intervals and leakage

### Takeaway
Treat this as a **safety-weighted selective-classification evaluation**. The headline metric is the **false confirmation rate**, with an exact (Clopper–Pearson) upper confidence bound. It is reported alongside the abstention rate and the risk–coverage curve, and broken down by stratified hard cases (look-alikes, other strengths, unregistered distractors, bad conditions). Split by **physical pill and capture session**, not by photo, to avoid leakage. A zero-error result on N trials only supports "≤3/N at 95% confidence".

### Cited Findings
- **Rule of three:** if 0 events are observed in N independent trials, the 95% upper confidence limit on the event rate is about 3/N (from −ln 0.05 ≈ 2.996). Example: 0/50 gives ≤6%, and 0/1000 gives ≤0.3%. It is most accurate for N > 30. — [Hanley & Lippman-Hand, JAMA 1983;249(13):1743–5](https://jamanetwork.com/journals/jama/article-abstract/389714); [Wikipedia summary](https://en.wikipedia.org/wiki/Rule_of_three_(statistics)); [Arch Dis Child note](https://adc.bmj.com/content/archdischild/90/6/642.2.full.pdf) [search-verified, secondary for the original]
- For binomial proportions with small n or rates near 0, the Wald interval performs poorly. Wilson or exact (Clopper–Pearson) intervals are recommended. — [Brown, Cai & DasGupta, Statistical Science 2001](https://projecteuclid.org/journals/statistical-science/volume-16/issue-2/Interval-Estimation-for-a-Binomial-Proportion/10.1214/ss/1009213286.full) [primary, from prior knowledge]
- **Risk–coverage curve / selective risk:** the standard way to report selective classifiers is error among accepted predictions versus the fraction accepted. — [Geifman & El-Yaniv, arXiv 1705.08500](https://arxiv.org/abs/1705.08500) [primary, from prior knowledge]
- **Consumer-to-reference evaluation paradigm in pills:** NLM's challenge ranked reference images for each consumer query and scored by MAP. It reported top-5 retrieval figures, and a later paper cites the winner at 83.3% top-5. — [NLM report](https://lhncbc.nlm.nih.gov/LHC-publications/pubs/ThenationallibraryofmedicinepillimagerecognitionchallengeAninitialreport.html); [PMC6550183](https://pmc.ncbi.nlm.nih.gov/articles/PMC6550183) [search-verified]
- **Condition-stratified testing in pill apps:** the JMIR 2021 study crossed background colour × flash × exposure (12 conditions) and showed large accuracy swings, which is a template for factorial condition testing. — [JMIR Med Inform 2021](https://medinform.jmir.org/2021/7/e26000) [search-verified]
- **Multi-pill scenes:** existing public datasets are limited. CURE often has one pill per image with incomplete instance labels, and CURE and NIH Pillbox are described as the only public pill datasets found by one 2026 preprint. — [MEDISEG preprint, arXiv 2603.10825](https://arxiv.org/pdf/2603.10825); [multi-pill GNN paper, arXiv 2303.09782](https://arxiv.org/pdf/2303.09782) [search-verified]

### Inferences: a concrete evaluation protocol for the team
**Metrics** (per-pill unless noted):
1. **False Confirmation Rate (FCR)** = (# pills shown green/"OK" whose true identity ≠ the claimed med, *including* unregistered distractors) / (# pills shown green). Also report it per *opportunity*: FCR_distractor = P(confirmed | pill is unregistered), FCR_lookalike = P(confirmed as k | pill is a look-alike or other strength of k). Report each with a Clopper–Pearson 95% upper bound.
2. **Abstention rate** (uncertain + "not mine" on pills that *were* registered and correct) — the usability cost.
3. **Correct-confirmation rate / coverage** on registered pills.
4. **Risk–coverage curve** sweeping the threshold. Mark the operating point.
5. **Scan-level exact-match accuracy**: the whole palm (≈4 pills) is judged correctly, i.e. every pill labelled right *and* the due/not-due comparison correct. Also report a **scan-level false-OK rate**: the scan was "all good" but at least one pill was wrong. This is what the patient experiences.
6. **Counting / detection accuracy**: predicted count = true count. Also report missed pills (a missed wrong pill is a hidden false confirmation) and duplicate detections. Report detection recall separately from identification.
7. **Red-highlight sensitivity**: P(red | pill should not be taken). This is the complement of the safety metric at the UI level.

**Test-set strata** (each pill instance labelled with its stratum):
- A. Registered pills, nominal conditions.
- B. **Different strengths / same drug** of a registered med (e.g., 5 mg vs 10 mg).
- C. **Look-alikes**: different drugs with similar colour and shape (white round tablets are the obvious hard case).
- D. **Unregistered distractors**: common OTC pills (acetaminophen, ibuprofen, vitamins), supplements, candy (mints, Tic Tacs).
- E. **Conditions** in a factorial grid: lighting (daylight / warm indoor / dim / flash), glare (glossy coating, specular), motion blur, imprint-side up vs down, partial occlusion between pills, palm vs table, skin tone and palm texture diversity, at least 2 iPhone models.
- F. **Scene composition**: 1–6 pills, touching or overlapping pills, two identical pills, a scan with zero pills.

**Sample sizes (honest framing):**
- With N trials of a given stratum and 0 false confirmations, claim only FCR ≤ 3/N (95%). To show ≤5%, you need about 60 clean distractor/look-alike trials. To show ≤1%, about 300. To show ≤0.1%, about 3000, which is beyond a student project. State this explicitly.
- Trials are **not independent** if many photos come from the same pill and session. Count independent *physical-pill × session* units for the CI, or report the CI per unit and note the clustering.

**Leakage controls:**
- References (enrolment gallery) and test queries must come from **different capture sessions**, ideally different days, lighting and photographer. Where possible, use **different physical pill instances** of the same product.
- Never tune thresholds on the test set. Use 3 splits: enrolment gallery / calibration (threshold-setting) / held-out test. Lock thresholds before the final test run and report the date and commit.
- If a cloud LLM is evaluated, log the model version and date. Do not include test photos in few-shot prompts.
- For distractors, keep some **distractor products completely unseen** during calibration ("novel distractors"). Otherwise the threshold is tuned to the specific distractors.

### Gaps
- I found no standard published metric definitions specifically for "palm multi-pill verification". The metrics above are proposed by analogy to biometric verification (false accept / false reject) and selective classification.

---

## Q6. How is medication-safety tech evaluated, and how do prototype benchmarks differ from clinical validation?

### Takeaway
Real medication-safety technology such as barcode medication administration (BCMA) is judged on **clinical outcomes in deployment**: observed administration errors and potential adverse drug events, measured by direct observation before and after. SaMD regulatory frameworks separate **analytical validation** (does the software produce the right technical output) from **clinical validation** (does it achieve the clinical purpose). A student benchmark is, at most, early analytical validation and should say so. No source gives a numeric accuracy threshold for pill recognition, and none should be invented.

### Cited Findings
- **BCMA evidence (Poon et al., NEJM 2010):** a before-and-after quasi-experimental study at one Boston academic hospital directly observed 14,041 medication administrations. Non-timing administration errors fell from 11.5% to 6.8% (41.4% relative reduction), and potential ADEs fell from 3.1% to 1.6% (50.8% relative reduction). Transcription errors were eliminated, and timing errors fell 27.3%. Limitations: a single site, pre-existing CPOE, potential (not actual) ADEs, and major workflow changes were needed. — [AHRQ PSNet summary](https://psnet.ahrq.gov/issue/effect-bar-code-technology-safety-medication-administration); [The Hospitalist](https://www.the-hospitalist.org/hospitalist/article/124206/literature-research-you-need-know); NEJM doi:10.1056/NEJMsa0907115 [search-verified via secondary summaries]
- **IMDRF SaMD Clinical Evaluation (N41, 2017; adopted as FDA guidance):** three pillars. (1) **Valid clinical association**. (2) **Analytical validation**: the ability to "accurately, reliably and precisely generate the intended technical output from the input data". (3) **Clinical validation**: the ability to "yield a clinically meaningful output" in the target healthcare situation. Both validations are stated as necessary for any SaMD. — [IMDRF N41 PDF](https://www.imdrf.org/docs/imdrf/final/technical/imdrf-tech-170921-samd-n41-clinical-evaluation_1.pdf); [FDA copy](https://fda.gov/media/100714/download) [search-verified]. One commentary claims FDA later withdrew its specific SaMD clinical evaluation guidance. **Unverified**, so check FDA's site before citing. — [meddeviceguide.com](https://meddeviceguide.com/blog/samd-clinical-evaluation-generating-clinical-evidence-software-medical-device-guide)
- **Reporting guidelines (for framing only):** STARD 2015 for diagnostic accuracy studies — [Bossuyt et al., BMJ 2015;351:h5527](https://www.bmj.com/content/351/bmj.h5527); TRIPOD+AI 2024 for prediction models using AI — [Collins et al., BMJ 2024;385:e078378](https://www.bmj.com/content/385/bmj-2023-078378); CONSORT-AI / SPIRIT-AI for trials of AI interventions — [Liu et al., Nat Med 2020](https://www.nature.com/articles/s41591-020-1034-x) [primary, from prior knowledge; not re-opened in this session]
- Commercial pill-ID apps often report developer claims (e.g., "over 95%" for the AIGIA Pharmacist app) without peer-reviewed validation. — [BioSpectrum Asia](https://www.biospectrumasia.com/article/pdf/13464) [search-verified; news, developer claim]

### Inferences
- The write-up can say the prototype benchmark addresses an *early form of analytical validation* (technical correctness on a small, self-collected, non-representative set). **Clinical validation** would require real patients, real medication regimens, real-world use, and outcomes such as observed wrong-pill-taken events, as in Poon's direct-observation design. That is out of scope.
- Borrow STARD-style reporting hygiene even for a prototype: describe how images were collected, the reference standard (the label source, e.g., pill bottle and imprint lookup in a drug database), any exclusions, flow of all scans including failures, and CIs on every metric.
- BCMA's lesson is that safety gains depended on workflow (hard stops, scanning compliance). For this app, the **UI policy on "uncertain"** (e.g., "check the bottle or ask your pharmacist" rather than a soft green) is part of the safety system and should be evaluated, at least through a small usability check.

### Gaps
- No published accuracy or false-accept thresholds for consumer pill-identification software were found, and none should be stated.
- Health Canada-specific SaMD guidance was not retrieved this session. Health Canada is an IMDRF member, so N41 framing is a reasonable proxy (an assumption).
- The BCMA wrong-drug subcategory figures were not verified.
