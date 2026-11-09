# Crop post-processing for in-hand pill photos: classical segmentation, splitting, mask refinement, crop geometry, rejection and evaluation on iOS (as of Nov 2026)

Scope: the algorithmic layer between "some detector produced masks or boxes" and "exactly one good crop per pill is sent to OpenAI". It also covers classical CV as a detector or fallback. Apple API availability was read from Apple's documentation JSON endpoints (`developer.apple.com/tutorials/data/documentation/...json`) on 2026-11-09. GitHub release data was read from the GitHub API the same day.

**Current app baseline.** These are local sources, not web sources:
- `MyPharmacist/PillVision/PillFinder.swift` reads `observation.instanceMask` (low resolution) and keeps instances with `minimumArea = 0.0004` and `maximumArea = 0.12` of the image.
- `MyPharmacist/PillVision/OpenAIPillIdentifier.swift` does `surroundingCrop(of:in:padding: 0.25)`, adding 25% of `max(w,h)` on each side, and `jpeg(maxSide: 384)`.

**Capture geometry used for the worked numbers below** (my arithmetic, not a source). The assumptions are a 12 MP 4:3 still (4032×3024) held in portrait, and a 7 cm pill spread filling 80% of the 3024 px width:
- Scale is 0.8 × 3024 / 70 ≈ **34.6 px/mm**. The frame covers about 87 × 117 mm (about 10,200 mm²).
- A 6 mm round tablet is about **207 px** across. A 9 mm tablet is about **311 px**.
- As a fraction of the image, a 6 mm round tablet is ≈ 28 mm² ≈ **0.28%**, a 9×4.5 mm oval ≈ 32 mm² ≈ **0.31%**, and a 9 mm round tablet ≈ 64 mm² ≈ **0.62%**.
- Two touching 9 mm round tablets are ≈ **1.25%**. An adult fingernail of about 10×12 mm is ≈ 94 mm² ≈ **0.9%**.
- The current 0.04%–12% window therefore admits merged pairs and fingernails. Its upper bound corresponds to about 1,200 mm², roughly a 35×35 mm patch of skin.
- For any other capture size, scale px/mm by `0.8 × imageWidth / 70`.

## 1. Segmenting pills from skin or a table without a trained model

### Takeaway
No published evaluation of classical pill segmentation on palms was found, even after searching pill-segmentation papers, VAIPE, MEDISEG, the NIH/NLM challenge, and pill-counting code. The closest evidence is a classical superpixel method on 5,000 NLM consumer photos. It produced acceptable masks for 82.1% of pills, and it failed mainly when the pill colour resembled the background. That is exactly the beige or pink pill on matching skin case.

Fixed skin-colour rules embed skin-tone assumptions, and their absolute-intensity thresholds penalise dark skin and dim light. The most defensible zero-training approach is a per-photo adaptive model:
- learn this person's skin or table colour from the image itself,
- treat pills as colour outliers inside the hand or table region,
- measure pill-to-background contrast and abstain when it is too low.

GrabCut seeded from a detector box is the strongest classical refiner, but on iOS it needs OpenCV.

### Cited Findings
- **Superpixel/RAG pill segmentation on NLM consumer photos** (SciTePress 2017):
  - Steps: Gaussian σ=2, then SLIC superpixels (compactness 12, 10 iterations), then a region-adjacency graph with mean-colour edge weights, cut at threshold 29. The threshold was tuned on 30 images.
  - Post-processing: a histogram background-bin removal, red/blue plane thresholds 105/83 OR-ed together, opening with a circular element to remove blobs of radius < 9 px, flood fill, convex hull, then box crop.
  - Results on 5,000 NLM Pill Image Recognition Challenge 2016 consumer images: 2,243 accurate masks, 1,862 masks that included some shadow, and 17.9% false segmentations. Counting shadowed masks as acceptable gives 82.1%.
  - The primary limitation was pills that "merged completely into the background", i.e. background-like pill colour.
  - Runtime was ~684 s per image in Python 2.7.
  — [SciTePress 2017](https://www.scitepress.org/Papers/2017/61358/pdf/index.html)
- **NLM challenge consumer images** were "taken with a variety of digital cameras, under various lighting conditions, and at camera angles not necessarily perpendicular", with 5,000 consumer images of 1,000 pills. The notice does not describe backgrounds or hand-held capture. — [Federal Register 2016-00777 (search summary)](https://www.govinfo.gov/content/pkg/FR-2016-01-19/html/2016-00777.htm)
- **L\*a\*b\* + K-means++ segmentation** reported a 1.9% segmentation error on NLM Pillbox reference images. Those images show a single pill on a plain background, i.e. controlled conditions. — [SciTePress 2013 (search summary)](https://www.scitepress.org/PublishedPapers/2013/43036/43036.pdf)
- **MEDISEG** (arXiv 2603.10825, Mar 2026, CC BY 4.0, submitted to *Scientific Data*):
  - 8,262 images of 32 pill types, taken on an iPhone 12 Pro Max with lighting intensity and angle varied.
  - Pills sit in a 4×7 dosette box, with 1–6 pills per slot image in the 3-Pills subset and up to 11–13 in the 32-Pills subset (the text and table disagree). It includes "overlapping tablets and partial obstructions".
  - Annotation was manual in COCO Annotator, checked by the initial annotator plus a secondary reviewer.
  - Baselines (validation, box metrics): YOLOv9 mAP@50 0.995 on 3-Pills and 0.801 on 32-Pills. No mask AP is reported.
  - Hands and palms are not mentioned.
  — [arXiv HTML](https://arxiv.org/html/2603.10825)
- **VAIPE** (2023) was built because earlier pill datasets were captured under controlled conditions. It has about 9,400 smartphone images in varied settings, with about 5–10 pills each, labelled from prescriptions. Its licence and download were not found. — [arXiv 2303.09782 (search summary)](https://arxiv.org/pdf/2303.09782)
- **The NLM pill dataset does not provide localisation or segmentation masks.** One waste-medication paper built synthetic training composites instead (DeepLabv3+). — [arXiv 2007.13903 (search summary)](https://arxiv.org/pdf/2007.13903)
- **Explicit RGB skin rule** (Peer, Kovac, Solina 2003, as quoted by Choraś 2008): skin if `R > 95 and G > 40 and B > 20 and max{R,G,B} − min{R,G,B} > 15 and |R − G| > 15 and R > G and R > B`. — [Choraś 2008, SciTePress](https://www.scitepress.org/Papers/2008/19390/19390.pdf)
- **YCbCr skin map** with Cr ∈ [133, 173] and Cb ∈ [77, 127]. Choraś reports these ranges as "most suitable for all the input images that we have tested" and "very robust against different types of skin color" (no per-tone numbers). — [Choraś 2008](https://www.scitepress.org/Papers/2008/19390/19390.pdf)
  - A patent gives the same 77–127 / 133–173 ranges and cites Phung, Bouzerdoum & Chai (PAMI 2005). — [US 8199165](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/8199165)
  - Chai & Ngan's 1999 face paper gives a narrower illustrative range (Cr 136–156, Cb 110–123). — [Chai & Ngan TCSVT 1999 (search summary)](https://webarchive.lib.cuhk.edu.hk/20210328154327mp_/http:/www.ee.cuhk.edu.hk/~knngan/TCSVT_v9_n4_p551-564.pdf)
- **Colour space choice does not change separability** given the optimum detector for that space: "the separability of the skin and no skin classes is independent of the color space chosen". The same paper names unknown ambient light, camera differences and person-to-person variation as the difficulties. — [Albiol, Torres, Delp 2001](https://gtav.upc.edu/en/publications/papers/2001/optimum-color-spaces-for-skin-detection)
- **Skin chroma barely differs between light and dark skin.** In 1,204 PPB* face images, "the chrominance values do not appear different for individuals with light or dark skin type … Practically all the variation in skin type is captured by the Y channel alone."
  - This was under "favorable lighting conditions".
  - Their rule is printed as `90 ≤ Cr ≤ 115 and 140 ≤ Cb ≤ 195`, which looks like a different Cb/Cr naming or offset than the common 133–173 / 77–127 box.
  — [Muthukumar et al. 2018, arXiv 1812.00099](https://arxiv.org/pdf/1812.00099)
- **Accuracy disparities on darker skin.** One paper states there is "a substantial disparity in the accuracy of classifying darker skin colors" and proposes a darker-skin RGB/HSL threshold. — [Springer MTAP 2021 (search summary)](https://link.springer.com/article/10.1007/s11042-021-10955-4)
- **Per-tone thresholds** in a lesion-segmentation context: choosing decision thresholds per Fitzpatrick group raised binary IoU by up to +31% for Fitzpatrick VI. — [Stothers et al. 2025, arXiv 2510.06655 (search summary)](https://arxiv.org/abs/2510.06655)
- **Colour cues dominate prior skin detection.** "Previous skin-detection methods have used color cues almost exclusively". The authors use augmentation to learn colour-invariant skin features and report gains for most Fitzpatrick tones (ECU dataset). — [Xu, Sarkar, Abbott 2022, arXiv 2204.09882](https://arxiv.org/abs/2204.09882)
- **GrabCut (OpenCV):**
  - It models foreground and background with GMMs and runs an iterative min-cut. It is initialised from a rect (`GC_INIT_WITH_RECT`) or a mask (`GC_INIT_WITH_MASK`) with labels `GC_BGD=0, GC_FGD=1, GC_PR_BGD=2, GC_PR_FGD=3`.
  - The `bgdModel`/`fgdModel` buffers are 1×65 float64 arrays.
  - The tutorial uses `iterCount = 5` for both the rect pass and the mask-refinement pass.
  — [OpenCV GrabCut tutorial](https://github.com/opencv/opencv/blob/4.x/doc/py_tutorials/py_imgproc/py_grabcut/py_grabcut.markdown)
- **Otsu inside a pill-counting pipeline.** The OpenCV tutorial binarises with `THRESH_BINARY_INV + THRESH_OTSU` on grayscale. — [OpenCV watershed tutorial](https://github.com/opencv/opencv/blob/4.x/doc/py_tutorials/py_imgproc/py_watershed/py_watershed.markdown)
- **Background colour matters even for deep pill-ID models.** A smartphone pill-ID study found accuracy depended on background, flash and exposure, and was better on white than black backgrounds. — [JMIR Med Inform 2021, PMC8367115 (search summary)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC8367115/)
- **On-device primitives (all usable at an iOS 17 target):**
  - `CIFilter.convertRGBtoLab()` (iOS 16) — [Apple](https://developer.apple.com/documentation/coreimage/cifilter-swift.class/convertrgbtolab())
  - `CIFilter.colorThresholdOtsu()` (iOS 14). It is applied per R, G, B component — [Apple](https://developer.apple.com/documentation/coreimage/cifilter-swift.class/colorthresholdotsu())
  - `CIFilter.kMeans()` (iOS 14). It returns a count×1 image of cluster centres, with weight in alpha — [Apple](https://developer.apple.com/documentation/coreimage/cifilter-swift.class/kmeans())
  - `CIFilter.cannyEdgeDetector()` and `CIFilter.sobelGradients()` (both iOS 17) — [Canny](https://developer.apple.com/documentation/coreimage/cifilter-swift.class/cannyedgedetector()), [Sobel](https://developer.apple.com/documentation/coreimage/cifilter-swift.class/sobelgradients())

### Inferences
- **Recommended zero-training segmenter on skin: an adaptive per-photo outlier model.**
  1. Get a hand or region-of-interest mask. Options are the subject-lifting hand instance, hand-pose palm polygon, or the union of subject-lifting instances, dilated.
  2. Sample "background" pixels from that region, excluding current pill candidates. An alternative is to take the dominant `CIKMeans` cluster (k = 3–4) inside the ROI as skin.
  3. Fit a 2-D Gaussian in chroma (a\*, b\* from `convertRGBtoLab`, or Cb/Cr), plus a loose 1-D model of L\*.
  4. Mark pixels with Mahalanobis distance above about 3–4σ (start at 3.5) or |ΔL\*| above about 3σ as "non-skin".
  5. Close and open with a radius of about 0.05 × expected pill diameter (≈10 px at 34.6 px/mm). Fill holes so specular highlights and imprints don't punch holes.
  6. Keep components inside the hand mask.

  This needs no skin-tone constants. Chroma being nearly tone-invariant (Muthukumar et al.) is the reason to put most of the weight on a\*/b\* or Cb/Cr and treat L\* loosely: L\* is where skin tones differ, and where shadows and creases appear.
- **Don't use the Kovac RGB rule or the fixed 133–173 / 77–127 box as the primary classifier.**
  - `R > 95` is an absolute brightness gate. Darker skin under indoor light, or any underexposed photo, can fall below it. That would make the whole palm "non-skin" and every crease a candidate.
  - The fixed YCbCr box was tuned on unspecified test sets.
  - Use these rules at most as a sanity prior, e.g. "is the ROI mostly skin-coloured at all?".
- **Contrast gate (key safety and fairness control).** For each candidate, compute the CIEDE/ΔE (or plain Euclidean Lab distance) between the pill's median colour (eroded mask) and the surrounding ring's median colour.
  - If ΔE falls below about 10–15 (start at 12, tune on data), or the mean gradient magnitude along the contour (`CISobelGradients`) is low, the boundary is not trustworthy. Return "can't confirm — try a plain light surface or paper" rather than guessing.
  - This turns the known failure (beige or pink pill on matching skin) into an explicit abstention.
  - Report the abstention rate per skin-tone group (Section 7). Otherwise the system may "fairly" abstain far more often for some users, which is still a fairness problem.
- **Tables.** On a plain table or a sheet of paper, the dominant k-means cluster (or the Otsu threshold on L\* and on chroma magnitude) is the background, and pills are the remaining blobs. This is the condition where the classical literature works. Offering "put the pills on a sheet of white paper" as a fallback is the cheapest robustness gain. That is consistent with the JMIR finding that a white background is best.
- **Background modelling from pre-capture frames is not viable for palms.** The pills are present in every frame, so there is no clean plate, and the hand moves, so frame differencing produces motion edges. Use preview frames for stability and count consistency (Section 5), not for background subtraction. The exception is an optional "show me your empty palm first" step, which costs UX and isn't recommended.
- **Edge methods (`CICannyEdgeDetector`, `VNDetectContoursRequest`)** respond to palm creases, finger boundaries, imprints, score lines and glare. They are better as a boundary-quality score and refinement cue than as a primary segmenter on skin.
- **GrabCut** works well per detection box when it is initialised from a mask:
  - Mark the eroded detector mask as `GC_FGD`.
  - Mark the area outside the dilated mask but inside the padded box as `GC_BGD`.
  - Mark the band in between as `PR_*`.
  - Run 3–5 iterations on a ~400×400 crop.

  It fails like any colour model when pill ≈ skin, so the contrast gate still applies.

### Gaps
- No published per-skin-tone evaluation of pill-on-skin segmentation (classical or learned) was found. No published evaluation of the Kovac or YCbCr rules broken down by Fitzpatrick or Monk group was found either.
- I did not find VAIPE's background composition or licence, or whether any public dataset contains pills on palms.
- I did not measure GrabCut runtime on an iPhone.

## 2. Splitting merged or touching pills

### Takeaway
Use marker-controlled watershed on the distance transform, but seed it with h-maxima or a per-blob relative threshold rather than a single global fraction of the image-wide maximum. Only attempt a split on blobs that shape tests flag as "probably ≥2 pills". Then re-validate each part as a single pill and abstain if any part fails. Concave-point or ellipse-fitting methods are a good second opinion. A useful fact for touching pills is geometric: two touching congruent convex ellipses (any aspect ratio, side-by-side or end-to-end) have a silhouette solidity of about 0.88, while a single tablet or capsule is about 0.97–1.0. That makes solidity a size-independent merge detector that works even when the handful mixes pill sizes.

### Cited Findings
- **OpenCV watershed tutorial pipeline:**
  1. Otsu threshold (inverted binary).
  2. Opening with a 3×3 kernel, 2 iterations.
  3. Sure background = dilation with 3 iterations.
  4. `distanceTransform(opening, DIST_L2, 5)`.
  5. Sure foreground = DT > **0.7 × DT.max()**.
  6. Unknown = sure_bg − sure_fg.
  7. `connectedComponents(sure_fg)`, then markers + 1, then unknown = 0.
  8. `watershed(img, markers)`; boundaries are −1.
  — [OpenCV tutorial](https://github.com/opencv/opencv/blob/4.x/doc/py_tutorials/py_imgproc/py_watershed/py_watershed.markdown)
- **scikit-image example:**
  - `distance = ndi.distance_transform_edt(image)`
  - `peak_local_max(distance, footprint=np.ones((3,3)), labels=image)`
  - markers by `ndi.label`
  - `watershed(-distance, markers, mask=image)`
  — [scikit-image example](https://scikit-image.org/docs/stable/auto_examples/segmentation/plot_watershed.html)
  - API notes: `compactness` gives "more regularly-shaped watershed basins" (compact watershed). `watershed_line=True` adds 1-px label-0 separators. Users are "encouraged to pass markers explicitly". — [scikit-image API](https://scikit-image.org/docs/stable/api/skimage.segmentation.html)
- **Over-segmentation and h-minima.** Every regional minimum, "even if tiny and insignificant", forms its own catchment basin. Eddins suppresses shallow minima with `imhmin` (example height 20) before watershed, or uses `imextendedmin` + `imimposemin` so minima appear only at the desired markers. MathWorks' `watershed` reference recommends removing shallow minima with `imhmin`. — [Eddins, MathWorks technical article](https://es.mathworks.com/company/technical-articles/the-watershed-transform-strategies-for-image-segmentation.html); [MathWorks watershed doc](https://www.mathworks.com/help/images/ref/watershed.html); [Steve on Image Processing](https://blogs.mathworks.com/steve/?p=917)
- **Open-source pill counter (count-drug):**
  - Otsu, then opening with 2 iterations, then EDT, with markers = DT > **0.4 × max**.
  - Watershed with `watershed_line=True`; lines are dilated 2×2 and removed.
  - Unit area = mean of regions within **1.15×** the smallest region.
  - Each region's count = round(area / unit) if within **0.3** of an integer; otherwise a "Warning" asks the user to reposition the pills.
  — [kien-ly/count-drug](https://github.com/kien-ly/count-drug)
- **Practitioner reports** say distance transform + watershed "does not work well, specially for adjacent tablets". I could not open the thread (HTTP 403), so this is unverified. — [OpenCV Q&A "Counting tablets" (search summary)](https://answers.opencv.org/question/210687/counting-tablets/)
- **Concave points + ellipse fitting.** Find concave points on the contour, split the contour into segments there, and fit an ellipse per segment or group of segments. — [Bai, Sun, Zhou, "Splitting touching cells based on concave points and ellipse fitting" (search summary)](https://www.datalearner.com/academic/journal-papers/0031-3203/volumes-and-issues/355/paper-detail/99875)
  - A follow-up adds an improved watershed for blobs whose concave points are unclear. — [Song et al. 2014, Frontiers of Computer Science](https://journal.hep.com.cn/fcs/EN/10.1007/s11704-013-3130-2)
- **Zafari et al.** do concave-point contour evidence extraction, group segments by branch and bound, then estimate contours by Gaussian-process regression. They claim this outperforms 3–4 prior methods on nanoparticle images (no numbers in the abstract). — [arXiv 1906.01049](https://arxiv.org/abs/1906.01049); [Zafari dissertation, LUT 2018](https://lutpub.lut.fi/handle/10024/158779)
- **Chord-based concavity detection** "assume[s] that only one concave point exists for each convexity defect", which "may not always hold in clusters containing more than two objects". — [Miró-Nicolau et al. (search summary)](https://ar5iv.labs.arxiv.org/html/2008.00997)
- **OpenCV contour tools:**
  - `convexityDefects` returns `[start, end, farthest point, approximate distance]` and requires `convexHull(..., returnPoints=False)`. — [OpenCV tutorial](https://github.com/opencv/opencv/blob/4.x/doc/py_tutorials/py_imgproc/py_contours/py_contours_more_functions/py_contours_more_functions.markdown)
  - Solidity = contour area / convex hull area. Extent = area / bounding-rect area. Equivalent diameter = √(4A/π). `fitEllipse` gives centre, axes and angle. — [OpenCV contour properties](https://github.com/opencv/opencv/blob/4.x/doc/py_tutorials/py_imgproc/py_contours/py_contour_properties/py_contour_properties.markdown)
- **Fast radial symmetry transform** reportedly gave 100% pill counting accuracy "even though the pills are overlapped and of different sizes" (2008 IEEE paper; small controlled set). — [Mahidol repository (search summary)](https://repository.li.mahidol.ac.th/entities/publication/de522b3e-fb5f-45f9-abbe-4c8330da0439/full)

### Inferences
- **Solidity of two touching pills is ≈ 0.88 for any equal pair of ellipses** (my derivation). Two tangent circles of radius r have union 2πr² and hull 4r² + πr², so solidity = 2π/(4+π) ≈ 0.880. Solidity is affine-invariant, so the same value holds for two congruent parallel ellipses touching side-by-side or end-to-end. Three in a row or a triangle cluster comes out lower.
  - Real single-pill masks score about 0.95–0.99. This needs measuring: mask noise, imprint notches and low-res staircase edges reduce it.
  - Heart, triangle or other concave-silhouette tablets would trip the test. Use the registered meds' known shapes to whitelist them.
- **Detecting "this blob is probably ≥2 pills".** Starting thresholds, to tune on labelled data:

  | Cue | Single pill (expected) | Flag as merged if |
  |---|---|---|
  | Solidity (area / hull area) | 0.95–1.0 | < **0.93** |
  | Deepest convexity defect depth / equivalent radius | ≈ 0 | > **0.15** (2 defects that deep, roughly opposite, strongly suggests a pair) |
  | Area / reference single-pill area | 0.7–1.4 | > **1.6** (only meaningful when pills are the same med or expected sizes are known) |
  | Ellipse-fit residual (mean point-to-ellipse distance / minor semi-axis) | < ~0.05 | > **0.10** |
  | Aspect ratio of fitted ellipse | ≤ ~3 (capsules) | > 3.5, or larger than the registered meds' maximum + 25% |
  | Number of h-maxima of the DT (h below) | 1 | ≥ 2 |

  Use the reference single-pill area only when it can be trusted. Take the median area of blobs that pass solidity ≥ 0.95 and the ellipse test. Better still, use the expected physical sizes of the patient's registered medications converted to pixels. Mixed 6 mm and 9 mm pills differ by more than 2× in area, which makes a plain "area vs median" test unreliable.
- **Seeding (avoid OpenCV's global 0.7 × max).** A global fraction of the image-wide DT maximum erases seeds of smaller pills when large and small pills are mixed: a 6 mm pill's DT peak is about 2/3 of a 9 mm pill's. Instead:
  - **Option A (preferred):** compute h-maxima of the DT within each flagged blob, with h ≈ **0.2 × expected minor semi-axis in px**. At 34.6 px/mm and a 4.5–6 mm minor axis that is about 15–20 px; on a 4× downsampled mask it is about 4–5 px.
  - **Option B:** threshold the DT at **0.5–0.6 × that blob's own maximum**. count-drug's 0.4 is more permissive and OpenCV's 0.7 more conservative.
  - Under either option, discard seeds whose DT value is < 0.5 × expected minor semi-axis. Such seeds are necks, crease bridges or glare holes.
  - The DT of a capsule (stadium) has a flat ridge. Treat a plateau as one regional maximum: h-maxima does this automatically, while "peak_local_max" with a 3×3 footprint can return several peaks along the ridge. Merge seeds closer than about 0.8 × expected minor axis.
- **Watershed on what surface?** On −DT for shape-driven splits, which is the right choice for same-coloured pills. Gradient magnitude (Sobel of L\*) is better when pills of different colours touch. A blend is −DT normalised + λ·gradient with λ ≈ 0.3.
- **Validate every split.** Accept a split only if every part has:
  - solidity ≥ 0.93,
  - area within the expected single-pill range,
  - an ellipse residual within threshold,
  - a cut line no longer than about 1.2 × the expected minor axis. Longer cuts mean the watershed cut through a pill.

  If any part fails, abstain ("pills are touching — spread them apart") instead of emitting crops. A UX prompt to spread the pills is a cheap and very effective "algorithm" for a patient app. count-drug's design (refuse to count non-integer area ratios and warn) is the same idea.
- **Concave-point or ellipse decomposition as a cross-check.**
  1. Take the polygon (`VNContour.polygonApproximation(epsilon:)` with ε ≈ 0.01 × perimeter, or `approxPolyDP`).
  2. Find convexity defects deeper than 0.15 × equivalent radius.
  3. Pair the defects with the shortest connecting chord.
  4. Fit an ellipse per resulting segment.

  If watershed and concave-point splitting disagree on the number of pills, abstain.
- **Three or more touching pills in a cluster** are where all classical methods get fragile (Miró-Nicolau's critique). Treat clusters with more than 2 estimated pills as "ask to spread out" in v1.

### Gaps
- I found no published accuracy figures for watershed versus concave-point splitting on tablets specifically. The Zafari and Miró-Nicolau numbers are for nanoparticles and cells and were not extracted.
- The OpenCV Q&A claim about adjacent tablets could not be opened (403).
- Single-pill solidity and ellipse-residual distributions for real low-res subject-lifting masks need to be measured. I found no source.

## 3. Mask refinement and resolution

### Takeaway
Treat the subject-lifting or model mask as a localisation prior, not a boundary. Best practice is to:
1. Upsample with an edge-aware filter guided by the full-resolution photo (`CIEdgePreserveUpsample`, `MPSImageGuidedFilter`, or Vision's own `generateScaledMaskForImage`).
2. Re-threshold, or GrabCut, inside each padded box using colour statistics seeded from the prior.
3. Compute boxes, orientation and size from the refined full-resolution mask.

Disagreement between the upsampled prior and the refined mask is itself a useful low-confidence signal.

### Cited Findings
- `VNInstanceMaskObservation.generateMask(forInstances:)` "Creates a low-resolution mask". `generateScaledMaskForImage(forInstances:from:)` "Creates a high-resolution mask where everything becomes transparent black, except for the instances you specify". `generateMaskedImage(ofInstances:from:croppedToInstancesExtent:)` returns a `CVPixelBuffer`. All are iOS 17. — [Apple: generateMask](https://developer.apple.com/documentation/vision/vninstancemaskobservation/generatemask(forinstances:)); [generateScaledMaskForImage](https://developer.apple.com/documentation/vision/vninstancemaskobservation/generatescaledmaskforimage(forinstances:from:)); [generateMaskedImage](https://developer.apple.com/documentation/vision/vninstancemaskobservation/generatemaskedimage(ofinstances:from:croppedtoinstancesextent:))
- Third-party references describe the raw `instanceMask` as UInt8 labels (0 = background) at the analysis resolution, not upscaled. — [Axiom Vision reference (third-party)](https://lobehub.com/skills/charleswiltgen-axiom-axiom-vision-ref)
- **`CIFilter.edgePreserveUpsample()`** (iOS 13) "upsamples a small input image to be the size of the scale image using the luminance of the input image to preserve detail". Its properties are `smallImage`, `spatialSigma` ("influence of the input image's spatial information") and `lumaSigma` ("influence of the input image's luma information"). — [Apple](https://developer.apple.com/documentation/coreimage/cifilter-swift.class/edgepreserveupsample()); [spatialSigma](https://developer.apple.com/documentation/coreimage/ciedgepreserveupsample/spatialsigma); [lumaSigma](https://developer.apple.com/documentation/coreimage/ciedgepreserveupsample/lumasigma)
- **`MPSImageGuidedFilter`** (iOS 11.3) is "A filter that performs edge-aware filtering". Its API is `init(device:kernelDiameter:)`, `epsilon`, `encodeRegression(commandBuffer:source:guidance:weights:destinationCoefficientsA:destinationCoefficientsB:)` and `encodeReconstruction(commandBuffer:guidance:coefficientsA:coefficientsB:destination:)`, plus `reconstructScale/Offset`. — [Apple](https://developer.apple.com/documentation/metalperformanceshaders/mpsimageguidedfilter)
- **Standard boundary-refinement baselines** in the literature are bilinear upsampling, GrabCut, dense CRF, the bilateral solver, joint bilateral upsampling (JBU) and the guided filter. — [DeepStrip CVPR 2020 supplementary (search summary)](https://openaccess.thecvf.com/content_CVPR_2020/supplemental/Zhou_Deepstrip_High-Resolution_Boundary_CVPR_2020_supplemental.pdf)
- **A shipped mobile pipeline** (Google synthetic depth of field) upsampled a low-res network mask with edge-aware filtering. It used the fast bilateral solver at half resolution, a Gaussian blur to remove speckle, then JBU. — [Wadhwa et al. 2018, arXiv 1806.04171 (search summary)](https://arxiv.org/pdf/1806.04171)
- **Guided filter as post-processing** can give poor high-res results when the network was trained on low-res targets; Wu et al. make it a trainable layer. — [Wu et al. CVPR 2018](https://openaccess.thecvf.com/content_cvpr_2018/papers/Wu_Fast_End-to-End_Trainable_CVPR_2018_paper.pdf)
- **`VNDetectContoursRequest.maximumImageDimension`** defaults to **512**. Vision downscales to it and "never scales the image up", with supported values from 64 upward. So for precise outlines, run it on the per-pill crop or raise the limit. — [Apple](https://developer.apple.com/documentation/vision/vndetectcontoursrequest/maximumimagedimension)
- **`cv.minAreaRect`** returns (centre, (w,h), angle), with `boxPoints` for corners. `fitEllipse` returns the rotated rect in which the ellipse is inscribed. Moments give the centroid as (M10/M00, M01/M00). — [OpenCV contour features](https://github.com/opencv/opencv/blob/4.x/doc/py_tutorials/py_imgproc/py_contours/py_contour_features/py_contour_features.markdown)

### Inferences
- **Recommended refinement per instance:**
  1. Take the instance bounding box from the low-res labels, scale it to full resolution, and pad it by 30%.
  2. Upsample that instance's mask into the box using `generateScaledMaskForImage` or `CIEdgePreserveUpsample`, with the full-res crop as the guide. `lumaSigma` and `spatialSigma` should be swept on data; defaults were not verified.
  3. Build a trimap. Eroded mask (radius ≈ 0.1 × expected minor axis) = sure pill. Outside the mask dilated by the same radius = sure background. The band between = unknown.
  4. Fit pill and background colour models in Lab from the sure regions: 1–2 Gaussians each, or `CIKMeans` k = 2–3 inside the box. Classify the unknown band, which is GrabCut-lite without the graph cut. Use full GrabCut (OpenCV) if available.
  5. Clean up with an open and a close (radius ≈ 3–5 px at full res), fill holes so glare and imprint holes vanish, and keep the component with the largest overlap with the prior.
  6. Compute the **refinement IoU** between the refined mask and the upsampled prior. If IoU < ~0.75, or the refined mask leaks to the box edge, flag the instance as uncertain.
- **Precise geometry from the refined mask:**
  - Axis-aligned box = min/max of mask pixels.
  - Orientation from second-order central moments: θ = ½·atan2(2μ11, μ20 − μ02).
  - Rotated box by projecting hull points onto the principal axes (PCA box), or rotating calipers for the true minimum-area rectangle.
  - Major and minor axis lengths in px, converted to mm via the scale estimate, then compared with the registered meds.
  - Avoid computing these on the low-res mask. At, for example, 1/8 scale a 207 px pill is about 26 px, and a 1-px boundary error is about 4% of the diameter and about 8% of the area.
- **Find out the actual low-res mask size on device.** Log `CVPixelBufferGetWidth/Height(observation.instanceMask)` in the existing `PillFinder.swift` code. Pill diameter in mask pixels then tells how much the refinement matters. If pills are under about 15 mask px across, small pills may vanish or merge before any post-processing can help. In that case run subject lifting a second time on a palm-ROI crop.
- **When the detector gives boxes only** (e.g. a Create ML detector): run the trimap or GrabCut step with the box as the rectangle prior (`GC_INIT_WITH_RECT`), or run subject lifting on the box crop.

### Gaps
- I did not verify default values or ranges for `spatialSigma` and `lumaSigma`.
- Apple does not document how `generateScaledMaskForImage` upsamples (soft or hard edges, edge-aware or not), or the instance-mask resolution.
- I did not find an evaluation of `CIEdgePreserveUpsample` for segmentation masks.

## 4. Crop geometry for an identification model (OpenAI vision)

### Takeaway
Keep the current approach of real background, moderate context and a single crop per pill, but harden it:
- Make crops square around the pill's own centre, with about 20–25% context per side.
- Neutralise neighbouring pills that fall inside the padding.
- Rotate elongated pills so the long axis is horizontal.
- Never upscale. Ensure the pill itself is at least about 200 px across in the source.
- Refuse pills that touch the frame edge.

Evidence that context padding helps comes from general detection (R-CNN: +3–5 mAP from 16 px of context), not from pills. OpenAI documents that rotated text can be misread and that it does not upscale small images.

### Cited Findings
- **R-CNN context padding.** Each proposal is dilated so that, after warping, there are **p = 16 px of context** around the box (227 px input). "warping with context padding (p = 16 pixels) outperformed the alternatives by a large margin (3-5 mAP points)". When the source rectangle extends beyond the image, "the missing data is replaced with the image mean". — [Girshick et al., arXiv 1311.2524, Appendix A](https://arxiv.org/abs/1311.2524)
- **OpenAI image input (Nov 2026 docs):**
  - Detail options are `low`, `high`, `original` and `auto`.
  - "All resizing keeps aspect ratio and doesn't enlarge small images".
  - Patch-based token cost = ceil(w/32) × ceil(h/32) × a model multiplier, e.g. 1.2 for gpt-5.x and 1.62 for gpt-4.1-mini.
  - `low` means within 512×512 px for gpt-5.5/5.6/6-astra. For gpt-5.4 and gpt-5.2/4.1-mini, low means a max side of 2048 px with a 6,144-patch budget.
  - Documented limitations: "May misread rotated or upside-down text and images", "Object counts are approximate", weak precise spatial localisation, and small text should be enlarged, using `original` detail where available.
  — [OpenAI images & vision guide](https://developers.openai.com/api/docs/guides/images-vision)
- **Current app** pads by 25% of max(w,h) per side (crop side ≈ 1.5 × pill long side) and caps the JPEG at 384 px on the longest side. — local: `MyPharmacist/PillVision/OpenAIPillIdentifier.swift`
- **Background in prior pill-recognition work.** Pill pipelines typically localise and segment the pill before feature extraction: coarse gradient localisation, then a sliding-window crop scored by HOG+SVM, keeping the largest connected region. — [US 10713540 (search summary)](https://image-ppubs.uspto.gov/dirsearch-public/print/downloadPdf/10713540)
- **Background affects smartphone pill-ID accuracy** (white better than black). — [PMC8367115 (search summary)](https://www.ncbi.nlm.nih.gov/pmc/articles/PMC8367115/)

### Inferences
- **Recommended crop recipe (starting point):**
  1. **Centre** on the refined-mask centroid, not the box centre.
  2. **Rotate** if the fitted aspect ratio is ≥ 1.25. Rotate by −θ so the long axis is horizontal (bilinear resampling of the full-res photo via `CIImage.transformed`/`CIAffineTransform`). Do not rotate round tablets, whose orientation is undefined. The 180° ambiguity remains for imprints, so either send as-is and let the model cope, or (cost permitting) add "the pill may be upside down" to the prompt. OpenAI's "may misread rotated text" note is the reason to at least remove the arbitrary 0–360° rotation of oblong pills.
  3. **Square side** = max(major axis) × **1.4–1.5**, i.e. about 20–25% context per side. This matches the current setting. Context lets the model see the pill's edge profile, bevel and thickness shading, and lets it judge colour against skin.
  4. **Neighbour suppression.** Pixels inside the crop that belong to *other* instances (dilated by 5 px) are replaced with a neutral mid-grey (sRGB ≈ 128) or heavily blurred. This prevents a "which pill?" ambiguity when pills touch. The pill's own surrounding skin or table stays real.
  5. **Optional full masking** of everything outside the pill (dilated by about 3% of its diameter) to neutral grey. This removes skin-colour cues and fingernail distractions, but mask errors then cut into the pill. Prefer real background unless an A/B test on labelled data shows masking helps. No pill-specific evidence was found either way.
  6. **Frame edges.** If the refined mask comes within about 1% of image width of any frame edge, mark the pill "partly out of frame". Don't crop it; ask to recentre. If only the padding falls outside the frame, fill with neutral grey, as R-CNN filled with the image mean, so the pill stays centred.
  7. **Resolution.** At the stated geometry a 6 mm pill is about 207 px, so a 1.5× crop is about 310 px and is sent at native resolution under the 384 cap. A 9 mm pill (≈ 467 px crop) is downscaled to 384. Recommendations:
     - Require **pill ≥ ~150 px across in the source** (≈ 4.3 mm at nominal distance). Below that, ask the user to move closer.
     - Consider **512 px** max side if imprint reading matters: 16×16 = 256 patches ≈ 308 tokens at multiplier 1.2, versus 144 patches ≈ 173 tokens at 384.
     - Never upscale, since OpenAI won't add detail.
     - Use JPEG quality ≥ 0.85 to protect imprints.
  8. **One crop per pill per request, with an index.** Send the crops plus their numbers. Don't ask the model to count; OpenAI says counts are approximate.
- **Optional context image.** A downscaled whole-palm image with numbered outlines can help the model resolve ambiguity, e.g. "pill 3 is the same as pill 1". Only use it for consistency checks, never to find pills.

### Gaps
- I found no published study of padding amount, masking versus real background, or rotation normalisation for pill identification by a general vision-language model. Pill-specific numbers must come from an A/B test on the app's own labelled set.

## 5. Rejecting non-pills and catching failures

### Takeaway
Build the layer as "detect, then explain every blob". Each candidate must pass physical-size, shape, colour and contrast tests; every rejection should be explicable; and the final count must agree across:
1. several preview frames,
2. the still photo,
3. the expected dose count for this time slot,
4. the user's confirmation on a numbered overlay.

Any disagreement leads to "can't confirm — retake". Nothing in the literature quantifies these checks for pills in palms, so thresholds below are starting points to tune.

### Cited Findings
- **Specular highlights (endoscopy)** are detected by converting to HSV and taking "absolutely bright" pixels via thresholds on high value and low saturation. A relatively-bright set is added using per-region 75th-percentile + IQR value thresholds, and the union forms the mask. — [Oh et al., EURASIP JIVP 2010 (search summary)](https://link.springer.com/article/10.1155/2010/814319)
  - Colour-space methods are cheaper than machine learning. A grayscale threshold of about 200 helps separate highlights. — [Yu et al., Frontiers in Physics 2021 (search summary)](https://www.frontiersin.org/articles/10.3389/fphy.2020.616930/full)
- **count-drug** flags non-integer area ratios (deviation ≥ 0.3), and a zero total, as warnings that prompt the user to reposition. — [kien-ly/count-drug](https://github.com/kien-ly/count-drug)
- **Vision geometry helpers (iOS 14):**
  - `VNGeometryUtils` provides `boundingCircle(for:)`, `calculateArea(_:for:orientedArea:)` and `calculatePerimeter(_:for:)`.
  - `VNContour.polygonApproximation(epsilon:)` "Simplifies the contour to a polygon using a Ramer-Douglas-Peucker algorithm".

  These are enough for circularity 4πA/P² and for the bounding-circle fill ratio. — [Apple VNGeometryUtils](https://developer.apple.com/documentation/vision/vngeometryutils); [polygonApproximation](https://developer.apple.com/documentation/vision/vncontour/polygonapproximation(epsilon:)); [calculateArea](https://developer.apple.com/documentation/vision/vngeometryutils/calculatearea(_:for:orientedarea:))
- **Region statistics in Core Image (iOS 14).** `CIAreaAverage` returns a 1×1 average colour over an extent. `CIAreaMinMax` returns 2×1 min/max. `CIAreaHistogram` returns a 1-px-high histogram with `count` bins. — [areaAverage](https://developer.apple.com/documentation/coreimage/cifilter-swift.class/areaaverage()); [areaMinMax](https://developer.apple.com/documentation/coreimage/cifilter-swift.class/areaminmax()); [areaHistogram](https://developer.apple.com/documentation/coreimage/cifilter-swift.class/areahistogram())
- **Hand pose** (`VNDetectHumanHandPoseRequest`, iOS 14) gives joint keypoints, not a mask. This is from the earlier note, not re-verified here. — [Apple](https://developer.apple.com/documentation/vision/vndetecthumanhandposerequest.md)

### Inferences
- **Per-candidate tests** (thresholds are starting values; px values at 34.6 px/mm should scale with the measured scale):

  | Test | Reject or flag if | Catches |
  |---|---|---|
  | Physical size (major and minor axis in mm via px/mm) | outside [0.7 × smallest, 1.3 × largest] registered-med dimension; with no med info, outside 4–22 mm major / 3–10 mm minor | creases (thin), glare dots (tiny), fingertip pads, nails, merges |
  | Thickness | max DT < 0.3 × expected minor semi-axis | creases, finger gaps, thin shadows |
  | Solidity | < 0.93 | merges, crescents (nail edges), crease fragments |
  | Ellipse-fit residual / circularity | residual > 0.10 × minor semi-axis; circularity < 0.6 (non-round) | irregular skin folds, ring segments |
  | Colour uniformity (eroded mask, Lab) | a\*/b\* std > ~6–8 for "solid" registered meds (allow two-tone capsules if registered) | skin folds, mixed regions, half-pill + skin leaks |
  | Pill vs surround contrast | ΔE(median inside, median ring) < ~12 | pill ≈ skin; boundary untrustworthy, so abstain |
  | Specular-only blob | > 50% of pixels have V > 0.92 and S < 0.12 (HSV), or all RGB > ~240 | glare on skin, metal rings, wet skin |
  | Touches hand-mask border or finger region | centroid within ~1 pill diameter of a fingertip joint, or blob lies on the hand silhouette boundary | fingernails, finger gaps |
  | Near frame edge | mask within 1% of width of the edge | partial pills |

- **Fingernails** show on the palm side mainly when fingers curl. They are pinkish-white, convex and pill-sized, the worst false positive. Defences:
  - Hand-pose fingertip joints (`thumbTip`, `indexTip`, etc.): reject candidates overlapping a disc of radius about 8 mm around each tip joint.
  - Require the candidate to be surrounded by skin on at least ~70% of its boundary ring. A nail sits at the hand boundary, with background on one side.
  - Instruct "open, flat palm".
- **Metal rings** are elongated and metallic, show specular stripes, and often sit at the finger base. They are rejected by the specular, aspect-ratio and hand-pose finger-base tests.
- **Palm creases and folds** are long and thin with low thickness. They are rejected by thickness and aspect ratio. Shadows next to pills are dark, low-chroma crescents and are rejected by solidity. In refinement, exclude pixels whose L\* is much lower than the skin model while chroma matches skin.
- **Count-consistency chain:**
  1. **Preview stability.** Run the same pipeline, or a cheaper version (subject lifting on downscaled frames, every 3rd frame), over about 0.5–1 s before auto-capture. Require the same count on ≥ 3 consecutive analysed frames, and boxes matching frame-to-frame with IoU > 0.5 after compensating global motion by the median box shift.
  2. **Still versus preview.** The still's count must equal the stable preview count.
  3. **Expected count.** The app knows the scheduled dose for the "Now" slot. If the detected count ≠ expected, show "I see 3 pills, you should have 4" rather than identifying. Never tune the detector to *find* N; use N only as a check, to avoid confirmation-biased segmentation.
  4. **User confirmation.** Show numbered outlines on the still: "Is each pill outlined exactly once? [Yes] [Retake]". This catches misses and merges, but not substitutions. Patients may tap Yes reflexively (automation bias, an inference with no source found), so make it a quick, specific question and keep checks 1–3 automatic.
- **Abstain on any of these:**
  - a test failure that can't be explained,
  - a split that fails validation,
  - the contrast gate,
  - count disagreement,
  - refinement IoU < 0.75,
  - a pill at the frame edge.

  Log the reason code (not the photo) for telemetry.

### Gaps
- No source quantifies fingernail, ring or crease false-positive rates for subject lifting or classical segmentation on palms.
- I found no source on automation bias in patient confirmation of pill-count overlays.
- Hand-pose joint accuracy for a palm holding pills was not checked.

## 6. iOS implementation options and costs

### Takeaway
At an iOS 17 target, almost everything except watershed, GrabCut, connected-component labelling and contour analysis exists natively:
- **Core Image:** colour conversion, thresholds, morphology, Canny/Sobel (iOS 17), k-means and region statistics.
- **vImage:** morphology, histograms and flood fill (iOS 16).
- **MPS:** an exact Euclidean distance transform since iOS 11.3, and a guided filter.

This corrects the earlier note: a distance transform *is* available, through Metal Performance Shaders. Core Image's own distance filters require iOS 26.

Watershed and connected components are easy to write in pure Swift for mask sizes this small. OpenCV via `yeatse/opencv-spm` (Apache-2.0, OpenCV 5.1.0 published 2026-11-07, with an `OpenCV-Core` tier) gives watershed, grabCut, findContours, fitEllipse, minAreaRect and convexityDefects in one dependency. The binary download is large (125–225 MB zipped xcframework), and the real app-size impact must be measured.

### Cited Findings
- **Metal Performance Shaders (availability):**
  - `MPSImageEuclideanDistanceTransform`: iOS 11.3. Its `searchLimitRadius` (iOS 14) defaults to `greatestFiniteMagnitude` (exact EDT); typical values are 32, 64, 96 and 128. — [Apple](https://developer.apple.com/documentation/metalperformanceshaders/mpsimageeuclideandistancetransform); [searchLimitRadius](https://developer.apple.com/documentation/metalperformanceshaders/mpsimageeuclideandistancetransform/searchlimitradius)
  - `MPSImageThresholdBinary` (iOS 9), `MPSImageDilate`/`MPSImageErode` (iOS 9), `MPSImageAreaMax` (iOS 9), `MPSImageHistogram` (iOS 9), `MPSImageFindKeypoints` (iOS 11), `MPSImageGuidedFilter` (iOS 11.3), `MPSImageCanny` (iOS 14). — [Apple MPS docs](https://developer.apple.com/documentation/metalperformanceshaders/mpsimagethresholdbinary) (each symbol page under `/documentation/metalperformanceshaders/`)
- **Core Image (convenience-constructor availability):**
  - iOS 13: `edgePreserveUpsample()`, `morphologyMinimum()`, `maximumComponent()`. Apple's prose for `morphologyMinimum` oddly describes it as a "blur"; the `radius` property is "The radius of the circular morphological structuring element". `CIMorphologyRectangleMinimum.width` is "rounded to the nearest odd integer".
  - iOS 14: `colorThreshold()`, `colorThresholdOtsu()`, `areaHistogram()`, `areaMinMax()`, `areaAverage()`, `kMeans()`, `colorAbsoluteDifference()`.
  - iOS 16: `convertRGBtoLab()`.
  - iOS 17: `cannyEdgeDetector()` (properties include `gaussianSigma`, `perceptual`, `thresholdHigh`/`thresholdLow`, `hysteresisPasses`) and `sobelGradients()`.
  - **iOS 18:** `areaBoundsRed()`.
  - **iOS 26:** `distanceGradientFromRedMask()` and `signedDistanceGradientFromRedMask()`.
  — [Apple CIFilter docs](https://developer.apple.com/documentation/coreimage/cifilter-swift.class/cannyedgedetector()) (e.g. `/distancegradientfromredmask()`, `/areaboundsred()`, `/morphologyminimum()`, `/colorthresholdotsu()`); [radius](https://developer.apple.com/documentation/coreimage/cimorphologyminimum/radius); [rectangle width](https://developer.apple.com/documentation/coreimage/cimorphologyrectangleminimum/width)
- **Accelerate/vImage:**
  - Morphology: `vImageDilate_*`, `vImageErode_*` (arbitrary kernel), and `vImageMax_*`/`vImageMin_*` (rectangular), each in Planar8, PlanarF, ARGB8888 and ARGBFFFF. — [Apple Morphology](https://developer.apple.com/documentation/accelerate/morphology)
  - `vImageHistogramCalculation_Planar8` and `_ARGB8888` (iOS 5). — [Apple](https://developer.apple.com/documentation/accelerate/vimagehistogramcalculation_planar8(_:_:_:))
  - `vImageEndsInContrastStretch_ARGB8888`. — [Apple](https://developer.apple.com/documentation/accelerate/vimageendsincontraststretch_argb8888(_:_:_:_:_:))
  - **`vImageFloodFill_Planar8` (iOS 16)**: "Applies a flood-fill operation to an 8-bit planar image". — [Apple](https://developer.apple.com/documentation/accelerate/vimagefloodfill_planar8(_:_:_:_:_:_:_:))
  - `vImage.PixelBuffer` Swift API (iOS 16). — [Apple](https://developer.apple.com/documentation/accelerate/vimage/pixelbuffer)
- **Vision:**
  - `VNDetectContoursRequest` and `VNContour` (iOS 14). The default `maximumImageDimension` is 512.
  - `VNGeometryUtils` (iOS 14).
  — [Apple](https://developer.apple.com/documentation/vision/vndetectcontoursrequest)
- **OpenCV via Swift Package Manager (`yeatse/opencv-spm`):**
  - Licence Apache-2.0; add `https://github.com/yeatse/opencv-spm.git` and `import opencv2`.
  - Product tiers (pick one): `OpenCV` (all modules incl. `dnn`), `OpenCV-NoDNN`, and `OpenCV-Core` (core, imgproc, imgcodecs, geometry). `dnn` is "by far the largest".
  - `highgui` and `stitching` have no ObjC/Swift bindings.
  - The README shows Swift usage (`Mat(uiImage:)`, `toUIImage()`).
  — [GitHub README](https://github.com/yeatse/opencv-spm)
  - Releases (GitHub API, 2026-11-09):
    - **5.1.0 (2026-11-07):** `opencv2-core.xcframework.zip` 125.4 MB, `-nodnn` 164.1 MB, `-full` 225.2 MB.
    - 5.0.0 (2026-06-08): 225.5 MB.
    - 4.13.0 (2026-01-02): 200.4 MB.
    - 4.12.0 (2025-07-23): 196.1 MB.
    — [releases](https://github.com/yeatse/opencv-spm/releases)
  - Swift Package Index build logs list a minimum iOS of 12.0 for the 5.0.0 manifest. — [SPI build log (search summary)](https://swiftpackageindex.com/builds/877D5262-58F3-4971-8D83-DEEA488DFA87)
  - Upstream OpenCV iOS framework zips: 5.1.0 (2026-11-06) 44.3 MB; 4.14.0 (2026-07-19) 75.2 MB. — [opencv/opencv releases](https://github.com/opencv/opencv/releases)
  - Alternative package `r0ml/OpenCV` (4.9.x) requires switching C++/Objective-C interop to C++/Objective-C++. — [Swift Package Registry (search summary)](https://swiftpackageregistry.com/r0ml/OpenCV)
- **OpenCV function set** used here (all in imgproc): `threshold` (Otsu), `morphologyEx`, `distanceTransform`, `connectedComponents`, `watershed`, `grabCut`, `findContours`, `convexHull`, `convexityDefects`, `fitEllipse`, `minAreaRect`, `approxPolyDP`, `moments`. — [OpenCV tutorials](https://github.com/opencv/opencv/tree/4.x/doc/py_tutorials/py_imgproc)

### Inferences
- **Native-only implementation map (no third-party code):**

  | Step | API |
  |---|---|
  | Colour conversion | `CIFilter.convertRGBtoLab()` (iOS 16). Alternatively, request `kCVPixelFormatType_420YpCbCr8BiPlanarFullRange` and read the CbCr plane directly (free chroma at half resolution). |
  | ROI statistics / skin model seed | `CIKMeans` k=3 on the ROI; `CIAreaAverage` / `CIAreaHistogram`; or a vImage histogram + Swift Otsu (about 20 lines on a 256-bin histogram) |
  | Thresholding | `CIColorThreshold` / `CIColorThresholdOtsu` (per channel; feed a single-channel distance image), a `CIColorKernel` for Mahalanobis distance, or `MPSImageThresholdBinary` |
  | Morphology | `CIMorphologyMinimum`/`Maximum` (circular radius), or `vImageErode/Dilate_Planar8` with a disc kernel; `vImageMin/Max_Planar8` for fast rectangles |
  | Connected components | Pure Swift two-pass union-find on a UInt8 mask (≤ a few ms at 1–2 MP), or repeated `vImageFloodFill_Planar8`, which is limited to 255 labels per pass |
  | Distance transform | `MPSImageEuclideanDistanceTransform` (GPU, exact), or pure-Swift linear-time EDT (Felzenszwalb–Huttenlocher style; a well-known algorithm, not sourced here) on the low-res mask |
  | h-maxima / seeds | Pure Swift: morphological reconstruction by dilation of (DT − h) under DT, using a queue-based algorithm on the per-blob crop |
  | Watershed | Pure Swift marker-controlled priority-flood (Meyer) on the per-blob crop (~150 lines; blobs are < 100k px) |
  | Contours / shape | `VNDetectContoursRequest` on the binary per-pill crop with `maximumImageDimension` raised; `polygonApproximation(epsilon:)`; `VNGeometryUtils.calculateArea/Perimeter/boundingCircle`; convex hull (Andrew's monotone chain) and ellipse fit (moments, or Fitzgibbon direct least squares) in pure Swift |
  | Edge-aware upsampling | `generateScaledMaskForImage`; `CIEdgePreserveUpsample`; `MPSImageGuidedFilter` |
  | Edges / boundary quality | `CISobelGradients` / `CICannyEdgeDetector` (iOS 17), `MPSImageCanny` |
  | Rotation and crop | `CIImage.transformed(by:)` + `cropped(to:)`, rendered once with a shared `CIContext` |

- **When to add OpenCV.** Add it if GrabCut is wanted, or if development speed matters more than binary size. The `OpenCV-Core` tier should include imgproc's watershed, grabCut, distanceTransform and contour functions. Verify that 5.x hasn't moved `fitEllipse`/`minAreaRect` to the `geometry` module, which the Core tier lists anyway.
  - The 125 MB zip is a multi-slice static xcframework (device + simulator, likely with debug info). The App Store download impact after linking and dead-stripping will be far smaller but unknown: measure an archive with and without the dependency via Xcode's App Thinning Size Report.
  - Apache-2.0 requires keeping the licence and NOTICE in the app's acknowledgements.
- **Concurrency and memory (Swift 6).**
  - Run the pipeline on a dedicated actor or serial queue.
  - Reuse one `CIContext` and one `MTLDevice`/`MTLCommandQueue`.
  - Do per-blob work on crops, never full-frame float buffers.
  - Keep everything in memory (no `CIImage` writes, no temp files) to honour "photos never saved".
  - Release `CVPixelBuffer`s promptly.
  - Mark Metal and Core Image wrappers `@unchecked Sendable` only behind an actor.
- **Expected cost.** Per photo with ≤ 10 pills: a full-res colour conversion, plus per-pill work on about 400×400 crops: k-means, refinement, DT and watershed on flagged blobs only. Tens of milliseconds on a modern iPhone is plausible, but this is not measured. Subject lifting itself dominates.

### Gaps
- No measured iPhone latency was found for any of these steps (EDT, CIKMeans, the Swift watershed), or for OpenCV on iOS.
- No published app-size impact was found for opencv-spm tiers.
- I did not verify whether OpenCV 5.x moved contour or geometry functions out of imgproc.

## 7. Evaluating the crop pipeline

### Takeaway
Evaluate at three levels:
1. **Instance level:** per-pill recall and precision, merge rate, split rate, and mask or box IoU.
2. **Photo level:** exactly-N rate, abstention rate, and, the safety metric, the **silent-failure rate**, meaning a photo where crops were emitted but any pill was missed, merged, split or hallucinated.
3. **Crop level:** pill fully inside the crop, and neighbour intrusion.

Stratify all of it by skin tone, pill colour, surface, lighting and touching configuration. Use the rule of three to size the test set. Zero silent failures in 300 photos bounds the rate below about 1% (95%), and zero in 100 photos below about 3%. Label with CVAT or Label Studio self-hosted with SAM assistance, to keep palm photos off third-party clouds.

### Cited Findings
- **Split and merge as dedicated metrics.** Metrics Reloaded notes that cell-nucleus segmentation assesses "splitting a reference object by two separate predictions" with a dedicated split error, and the converse with a merge error. — [Metrics Reloaded, arXiv 2206.01653 (search summary)](https://arxiv.org/pdf/2206.01653)
- **Example operational definitions:**
  - One study counted a cell as correct if mask overlap with ground truth exceeded 85%, and reported the percentage of merged cells (false-negative contours) and split cells (false-positive contours). — [arXiv 2407.15817 (search summary)](https://arxiv.org/pdf/2407.15817)
  - A 2026 preprint argues that existing metrics can rank models unreliably under split, merge and boundary errors, and proposes Maximum Matching Accuracy (globally optimal one-to-one matching). — [arXiv 2606.10107 (search summary)](https://arxiv.org/abs/2606.10107)
- **Rule of three.** If an event never occurs in n trials, the 95% upper confidence limit on its rate is ≈ 3/n. The numerator is 4.61 for 99% (from −ln 0.01). — [Wikipedia, Rule of three (statistics)](https://en.wikipedia.org/wiki/Rule_of_three_(statistics)); original: [Hanley & Lippman-Hand, JAMA 1983](https://jamanetwork.com/journals/jama/article-abstract/389714)
- **Labelling tools:**
  - **CVAT:** SAM 2 interactive masks via the AI Tools/Interactor, with positive and negative points. The SAM 2 *tracker* is limited to paid on-prem plans. — [CVAT blog](https://www.cvat.ai/resources/blog/video-annotation-sam-2)
  - **Label Studio:** an official SAM / SAM 2 ML backend, self-hosted. — [Label Studio](https://labelstud.io/integrations/machine-learning/segment-anything-model)
  - **Roboflow:** "Smart Polygon" with SAM, one-click in the browser (cloud). — [Roboflow docs](https://docs.roboflow.com/annotate/ai-labeling/enhanced-smart-polygon-with-sam)
  - Vendor speed claims (10–100×) are promotional and unverified. — [Roboflow comparison](https://roboflow.com/compare-labeling-tools/label-studio-vs-roboflow-anntate)
- **MEDISEG's labelling QA** used manual COCO Annotator polygons, multiple annotators under written guidelines, and every image checked by the original annotator plus a second reviewer. It used a 70/20/10 split. — [arXiv HTML 2603.10825](https://arxiv.org/html/2603.10825)

### Inferences
- **Matching and metric definitions** (implement in a small Python or Swift script):
  - Match predicted to ground-truth instances one-to-one by Hungarian assignment on mask IoU, with a match if IoU ≥ 0.5. Also record box IoU, since crops come from boxes.
  - **Per-pill recall** = matched GT / all GT. **Precision** = matched predictions / all predictions emitted (not abstained).
  - **Merge** = one prediction covering ≥ 50% of the area of ≥ 2 GT pills. **Split** = one GT pill with ≥ 2 predictions each covering ≥ 20% of it.
  - **False positive by type**: nail, crease, glare, ring, shadow, other. This tells which rejection test to tune.
  - **Exactly-N rate** = photos where the prediction count equals the GT count *and* all are matched.
  - **Abstention rate** = photos where the pipeline said "retake".
  - **Silent-failure rate** = photos *not* abstained with any miss, merge, split or false positive. This is the primary safety metric; abstentions are a usability cost, not a safety failure.
  - **Crop quality:** fraction of GT pill area inside the crop (target ≥ 0.99), area of other pills inside the crop after neighbour suppression (target 0), and pill major axis in crop pixels.
  - Report the abstention-versus-silent-failure trade-off curve as thresholds vary, and pick the operating point by a silent-failure target (e.g. ≤ 1%).
- **Test set design.** Photos have to be collected through a separate consented capture path, such as a debug-only build or a standalone camera app with written consent. The production app never saves photos.
  - Stratify across:
    - **Skin tone:** at least 6 groups on a Fitzpatrick or Monk-style scale, recruiting deliberately.
    - **Pill colour:** white, beige, yellow, pink/peach, orange, two-tone capsule.
    - **Surface:** open palm, cupped palm, white paper, light table, dark or wood table.
    - **Lighting:** daylight, warm indoor, dim, overhead glare.
    - **Configuration:** all separated; 1 touching pair; a cluster of 3; a pill on a crease; a pill near the frame edge; nails visible; a ring worn.
    - **Count:** 1–10.
  - **Size.** For the claim "silent failures < 1% (95%)", need ≥ 300 non-abstained photos with zero silent failures overall. Per skin-tone group, ~50 photos only bounds failures at < 6% (3/50). Fairness claims per group therefore need about 100–300 photos per group, or a stated wider bound.
  - **Practical v1.** 150–300 photos, about 600–1,200 pill instances, from 10–20 volunteers. Hold out by *person*, not by photo, to avoid leakage. Add hard negatives: empty palms, palms with only rings or nails.
- **Labelling workflow.**
  1. Self-host CVAT or Label Studio with SAM (on a laptop is fine). Click each pill with SAM, fix the polygon, and add "touching" and "partially out of frame" attributes.
  2. Have a second person review every image, following MEDISEG.
  3. Export COCO.
  4. Store the evaluation set encrypted, with a deletion date.

  Palm photos carry biometric palmprint detail, which is a reason to avoid uploading them to a cloud labelling service.
- **Run the evaluation offline on macOS.** Use the same Swift pipeline (Vision, Core Image and MPS all run on macOS 14+) over the labelled set, so that the shipped code, not a Python re-implementation, is what gets measured.

### Gaps
- No published benchmark exists for pills on palms, so there is no external baseline to compare against.
- I found no standard definition of "exactly-N rate" for pill counting; the definitions above are proposed, not taken from a source.
- The labelling tools' speed claims are vendor-reported.
