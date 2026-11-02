# Cloud Multimodal APIs for Multi-Pill Identification (OpenAI focus, with Gemini/Claude comparison)

Research date: 2026-10-30. All pricing figures were read from official pricing pages on 2026-10-30. The pages were read through a fetch-and-summarize tool, so before committing to a budget, recheck the exact numbers by eye on the live pages. Model names such as `gpt-6-*` and `gemini-4-argon` are reported exactly as the official pages list them today.

## 1. Which OpenAI models accept images, what they cost, how images are tokenized, cost per scan, and scans per $80

### Takeaway
Every current OpenAI model accepts image input. The current lineup is GPT-6 Astra, GPT-6.1 Sol, GPT-6.1 Terra and GPT-6 Luna. One scan is one high-detail palm photo plus a JSON answer, which comes to about 4–5K input tokens and under 1K output tokens. That costs roughly $0.007 per scan on `gpt-6.1-terra` and $0.014 on `gpt-6.1-sol`, so $80 buys thousands of scans on any model except the flagship. The budget becomes a real limit only with `gpt-6-astra` (about 900–1,200 scans) or when reasoning tokens grow large.

### Cited Findings
**Models and image support**
- Recommended models on the models page are `gpt-6-astra` (flagship, $10 in / $50 out per 1M tokens), `gpt-6.1-sol` ($2 / $10, "balance intelligence and cost"), `gpt-6.1-terra` ($1 / $5) and `gpt-6-luna` ($0.10 / $0.50, "most efficient model for focused, high-volume tasks"). All four have a 1.05M-token context and 128K max output. — [OpenAI Models](https://developers.openai.com/api/docs/models)
- "All latest OpenAI models support text and image input, text output, multilingual capabilities, and vision." The page describes GPT-6.1 Terra as "A fast, efficient model for visual reasoning, precise computer use, and clear, natural writing." — [OpenAI Models](https://developers.openai.com/api/docs/models)
- The vision guide marks `gpt-5-mini`, `gpt-5-nano`, `gpt-4.1-nano` and `o4-mini` as deprecated. — [OpenAI Images & Vision guide](https://developers.openai.com/api/docs/guides/images-vision)

**Standard prices, USD per 1M tokens (input / cached input / output), read 2026-10-30, short context of 272K tokens or less** — [OpenAI Pricing](https://developers.openai.com/api/docs/pricing)

| Model | Input | Cached input | Output |
|---|---|---|---|
| gpt-6-astra | 10.00 | 1.00 | 50.00 |
| gpt-6.1-sol | 2.00 | 0.10 | 10.00 |
| gpt-6.1-terra | 1.00 | 0.05 | 5.00 |
| gpt-6-luna | 0.10 | 0.01 | 0.50 |
| gpt-5.6-sol / terra / luna | 4.00 / 2.00 / 0.20 | — | 20.00 / 12.00 / 1.20 |
| gpt-5.4 / 5.4-mini / 5.4-nano | 2.50 / 0.75 / 0.20 | — | 15.00 / 4.50 / 1.25 |
| gpt-4.1 / 4.1-mini | 2.00 / 0.40 | 0.50 / 0.10 | 8.00 / 1.60 |
| gpt-4o / 4o-mini | 2.50 / 0.15 | 1.25 / 0.075 | 10.00 / 0.60 |

- Batch prices are 50% of Standard; for example `gpt-6.1-terra` is $0.50 / $2.50 and `gpt-6.1-sol` is $1 / $5. Flex prices match Batch for the models Flex covers. Priority processing was renamed "Fast mode" on 2026-07-30 and costs 2× Standard; for example `gpt-6.1-terra` Fast is $2 / $10. The page says GPT-5.6 Sol's promotional pricing runs "at least through November 21, 2026". — [OpenAI Pricing](https://developers.openai.com/api/docs/pricing)
- Data-residency (regional processing) endpoints add a 10% uplift. — [OpenAI Pricing](https://developers.openai.com/api/docs/pricing)

**Image tokenization** — [OpenAI Images & Vision guide](https://developers.openai.com/api/docs/guides/images-vision)
- Detail levels are `low`, `high`, `original` and `auto`. The default is `auto`.
- Patch-based models use 32 px patches: `patch_count = ceil(w/32) × ceil(h/32)`, and tokens = patches × a model multiplier.
  - `gpt-6-astra`: `low` fits the image in 512×512. `high` allows up to 2,500 patches. `original` and `auto` keep the original dimensions. The multiplier is 1.2.
  - `gpt-5.6-*`: `low` fits 512×512. `high` fits 2048×2048 and 2,500 patches. The multiplier is 1.2.
  - `gpt-5.4` family: `high` allows up to 2,500 patches and a 2048 px maximum dimension. `original` allows up to 10,000 patches and 6000 px. `auto` equals `high`. The multiplier is 1.2.
  - Other multipliers: `gpt-4.1-mini` 1.62, `gpt-5-nano` 1.5, `o4-mini` 1.72.
  - Official worked example: a 2048×2048 image on `gpt-6-astra` at `high` is resized to 1600×1600, which is 2,500 patches and ceil(2500×1.2) = 3,000 tokens.
- Tile-based models count base tokens plus tile tokens. `gpt-4o` and `gpt-4.1` use 85 + 170 per 512 px tile, and `gpt-5.1` uses 70 + 140. `gpt-4o-mini` uses 2,833 + 5,667, so images on 4o-mini are not cheap despite its low per-token price. `high` first fits the image in 2048×2048, then shrinks the shortest side to 768 px. `low` costs only the base tokens.
- Limits: PNG, JPEG, WEBP or non-animated GIF; up to 512 MB of payload and 1,500 images per request; up to 30,000 patches per image, and images over that limit are rejected rather than resized.

**Worked cost per scan.** These are my calculations from the figures above. Assumptions: the 12 MP photo (4032×3024) is downscaled on the device to 1536×2048 JPEG; the text prompt plus medication list is about 800 tokens; the JSON output is about 600 tokens for 4 pills; reasoning effort is minimal.
- Full photo at `high` on a 1.2× patch model: capped at about 2,500 patches, so about 3,000 tokens (same as the official example). At `low` (384×512): 192 patches, so about 231 tokens. Low detail is probably too coarse to read imprints.
- A 384×384 pill crop is 144 patches, so about 173 tokens. Four crops plus four reference images is about 1,380 tokens.
- Scenario A (1 high-detail photo, about 3.8K input tokens and 0.6K output tokens):
  - `gpt-6.1-terra`: about $0.0068 per scan, so about 11,700 scans for $80.
  - `gpt-6.1-sol`: about $0.0136, so about 5,900 scans.
  - `gpt-6-astra`: about $0.068, so about 1,170 scans.
  - `gpt-6-luna`: about $0.0007, so more than 100,000 scans.
- Scenario B (photo plus 4 crops plus 4 reference images, about 5.2K input and 0.8K output):
  - Terra: about $0.0092, so about 8,700 scans.
  - Sol: about $0.018, so about 4,300 scans.
  - Astra: about $0.092, so about 870 scans.
- `gpt-4o` (tile-based): 1536×2048 becomes 768×1024, which is 4 tiles and 765 tokens. Scenario A then costs about $0.0099, so about 8,000 scans. `gpt-4.1` costs about $0.0079, so about 10,000 scans.
- Reference images that repeat across requests can use the cached-input rate, which is 10–20× cheaper on GPT-6.x, but only if they sit in an identical prompt prefix. — [OpenAI Pricing](https://developers.openai.com/api/docs/pricing) (the caching mechanics were not fetched)

### Inferences
- Reasoning tokens are billed as output. With high reasoning effort, an extra 2–5K reasoning tokens would add $0.02–0.05 per scan on Sol. Even then, $80 still covers more than 1,000 scans on Sol or Terra. Development iteration, not production use, will probably consume most of the budget.
- Set a hard monthly spend limit on the project, because a leaked key or a retry loop is the realistic way to exhaust $80.

### Gaps
- The vision guide's tokenization table, as extracted, does not list `gpt-6.1-sol`, `gpt-6.1-terra` or `gpt-6-luna`. The estimates above assume they behave like the other GPT-6 and GPT-5.6 patch models (1.2× multiplier, 2,500-patch `high` cap). Before trusting these estimates, measure real token use by reading `usage.input_tokens` from one test call.
- Prompt-caching rules for images (minimum prefix length, whether image blocks are cacheable) were not verified.

## 2. Latency, Batch, and cheaper options

### Takeaway
Use Standard for interactive scans. Batch and Flex cost half as much, but they are asynchronous or slower, so they suit offline evaluation runs, for example re-scoring a test image set. They do not suit a live scan. `gpt-6.1-terra` and `gpt-6-luna` are the low-cost options; the old "mini/nano" names are deprecated or legacy.

### Cited Findings
- The Batch and Flex tiers are priced at about 50% of Standard. "Fast mode" (formerly Priority) costs 2× Standard. — [OpenAI Pricing](https://developers.openai.com/api/docs/pricing)
- The Batches endpoint is not eligible for Zero Data Retention, and batch data is kept "until deleted". — [OpenAI Your Data](https://developers.openai.com/api/docs/guides/your-data)
- Background Responses requests with `store` false are deleted after about a 10-minute polling window. — [OpenAI Your Data](https://developers.openai.com/api/docs/guides/your-data)
- Claude's vision guide advises resizing before upload "to minimize latency", and notes that lossy compression reduces request size and therefore latency. — [Anthropic Vision](https://platform.claude.com/docs/en/build-with-claude/vision)

### Inferences
- Downscale and JPEG-compress the image on the device (about 1536–2048 px long edge, quality about 0.8), with no EXIF. This cuts upload time over cellular and also removes location metadata.

### Gaps
- No official end-to-end latency figures were found for GPT-6.x image requests. I also found no official Batch turnaround SLA during this session; Batch has historically had a 24-hour completion window, but that is unverified here. The team should benchmark p50 and p95 latency with 10–20 real calls per candidate model. I could not verify a typical seconds-per-request figure.

## 3. Can the models return bounding boxes for multiple small objects? OpenAI vs Gemini vs Claude

### Takeaway
OpenAI documents no bounding-box output format. Its vision guide says the model "struggles with tasks requiring precise spatial localization" and gives only approximate counts. Gemini officially documents detection (`box_2d`, normalized 0–1000) and segmentation masks. Claude documents coordinate and bounding-box workflows in absolute pixels of the resized image. For drawing red highlights reliably, do localization on the device (Vision/Core ML, saliency or contour detection) or with Gemini, and use the LLM to identify each crop.

### Cited Findings
- OpenAI, limitations: "The model struggles with tasks requiring precise spatial localization, such as identifying chess positions." "The model may give approximate counts for objects in images." It "may misinterpret rotated or upside-down text and images." For small text, enlarge it or use `detail: "original"`. The page gives no box format. For coordinate tasks it advises: "resize images to fit those limits before sending them and map returned coordinates back to the original image" (and points to the Computer Use guide). — [OpenAI Images & Vision guide](https://developers.openai.com/api/docs/guides/images-vision)
- Gemini returns detection results as `[ymin, xmin, ymax, xmax]` normalized to 0–1000. Segmentation returns `box_2d`, `label` and `mask`, where the mask is a polygon of [x,y] coordinates normalized to 0–1000. Google recommends setting thinking to "minimal" for better segmentation, and says "the latest model versions are specifically trained to improve accuracy" for these tasks. The JSON schema response format works with detection. — [Gemini Image Understanding](https://ai.google.dev/gemini-api/docs/image-understanding)
- Claude "returns absolute pixel coordinates relative to the image it processes after resizing". A dedicated guide covers pre-resizing and rescaling, and `"oversized_image": "error"` makes the API reject an image rather than silently resize it, which keeps coordinates exact. — [Anthropic Vision](https://platform.claude.com/docs/en/build-with-claude/vision); [Claude Coordinates guide](https://platform.claude.com/docs/en/build-with-claude/vision-coordinates)
- Claude limitation: it "might hallucinate or make mistakes when interpreting low-quality, rotated, or very small images under 200 pixels." — [Anthropic Vision](https://platform.claude.com/docs/en/build-with-claude/vision)
- Third-party evidence:
  - GPT-5 inside a multi-step "verification-first" workflow (draw candidate boxes, ask true/false) reached Acc@0.5 of 79.3% on RefCOCO, 74.2% on RefCOCO+ and 72.4% on RefCOCOg. This is not direct box regression. — [arXiv 2509.09958](https://arxiv.org/html/2509.09958v3)
  - Earlier work reported that GPT-4V "can not generate precise coordinates". — [LLM-Optic, arXiv 2405.17104](https://arxiv.org/pdf/2405.17104)
  - GPT-4o was strong at judging whether a given box was acceptable, which is not the same as predicting one. — [Wonderful Team, arXiv 2407.19094](https://arxiv.org/pdf/2407.19094)
  - An unverified leaderboard lists GPT-5.4-mini at 67.0% Acc@0.5 on RefCOCO; its methodology is unclear. — [interfaze.ai RefCOCO](https://interfaze.ai/leaderboards/refcoco)

### Inferences
- Four pills in a palm are large, high-contrast objects, which is much easier than RefCOCO. Even so, a box off by 20–30% IoU puts the red highlight on the wrong pill, which is a safety-relevant UI error.
- Recommended split: detect pills on the device (Apple Vision, e.g. `VNGenerateForegroundInstanceMaskRequest` or a small Core ML detector), crop each one, and send the crops with stable IDs ("pill_1…pill_4"). Then the LLM never has to output coordinates. It only labels IDs, and the app already knows where each ID is. The team should verify the Vision API names against Apple docs.
- A cheap alternative for the prototype is to ask an OpenAI model for normalized boxes and validate them on the device, rejecting the result if the box count does not match the on-device detection. Treat this as a fallback, not the primary method.

### Gaps
- I found no official OpenAI grounding benchmark for GPT-6.x, GPT-5.x or GPT-4.1. I found no head-to-head published evaluation of Gemini, GPT and Claude box accuracy on small handheld objects.

## 4. Structured Outputs with images and a per-pill schema

### Takeaway
Strict JSON-schema Structured Outputs work in the Responses API (`text.format`) and Chat Completions (`response_format`) for GPT-4o and later. They constrain the output, not the input, so image inputs do not prevent their use. The page I fetched did not explicitly state "works with images", but Gemini's docs show schema-constrained JSON for image detection. Design the schema so that every field is required and nullable, uncertainty is an explicit enum, and refusals are handled.

### Cited Findings
- Structured Outputs are "available in our latest large language models, starting with GPT-4o". In the Responses API, use `text: { format: { type: "json_schema", strict: true, schema: … } }`. In Chat Completions, use `response_format` with `json_schema`. — [OpenAI Structured Outputs](https://developers.openai.com/api/docs/guides/structured-outputs)
- Schema rules:
  - Every field must be in `required`; emulate optional fields with `["string","null"]`.
  - `additionalProperties: false` is mandatory.
  - The root must be an object and cannot be `anyOf`.
  - Limits: at most 5,000 properties, nesting depth 10, 1,000 enum values, and 120,000 characters of names and enums.
  - `allOf`, `not`, `if/then/else` and `dependent*` are unsupported. `minLength`, `maxLength`, `pattern`, `format`, `minimum`, `maximum`, `minItems` and `maxItems` are supported only on fine-tuned models. On base models, a confidence value of 0–1 therefore cannot be enforced by the schema and must be checked in client code.
  — [OpenAI Structured Outputs](https://developers.openai.com/api/docs/guides/structured-outputs)
- A safety refusal comes back as a `refusal` content item that may not follow the schema. Incomplete responses (e.g. `max_output_tokens` reached) must be checked through the response status. — [OpenAI Structured Outputs](https://developers.openai.com/api/docs/guides/structured-outputs)
- Gemini detection and segmentation accept a JSON schema with `application/json`. — [Gemini Image Understanding](https://ai.google.dev/gemini-api/docs/image-understanding)

### Inferences
Suggested schema shape, with all keys required. Put `matched_medication_id` in an enum built per request from the patient's registered IDs plus `"none"` and `"unknown"`, so the model cannot invent a drug:
```json
{ "pills": [ { "pill_ref": "pill_1",
    "color": "white", "shape": "round|oval|capsule|oblong|other",
    "imprint_text": "string|null", "imprint_legible": true,
    "matched_medication_id": "<enum of patient med IDs> | none | unknown",
    "confidence": 0.0, "uncertain": true,
    "reason": "short string" } ],
  "pill_count_seen": 4, "image_quality_issue": "none|blur|glare|occlusion|too_far" }
```
- Ask for `imprint_text: null` when it is unreadable, rather than a guess. This targets the misread-imprint failure mode described in section 7.
- Do not trust model-reported `confidence` on its own. Derive `uncertain` in the app as well, for example from `imprint_legible == false`, an imprint that does not match the registered medication's imprint, or a count mismatch.

### Gaps
- I did not find an explicit statement in the fetched portion of the OpenAI Structured Outputs page that it works with image inputs. Compatibility is expected but should be confirmed with one test call.

## 5. Data handling: training, retention, ZDR, image storage, HIPAA; Canadian privacy

### Takeaway
By default, OpenAI does not use API data for training. It keeps abuse-monitoring logs for up to 30 days, and Responses API objects are stored for 30 days unless `store: false` is set. Zero Data Retention (ZDR) and Modified Abuse Monitoring require OpenAI approval through sales, so they are unrealistic for a student project. HIPAA BAAs exist but are irrelevant here. With mock data only and `store: false`, the prototype's exposure is low.

### Cited Findings
- API data is "not used to train or improve OpenAI models" unless the customer opts in. — [OpenAI Your Data](https://developers.openai.com/api/docs/guides/your-data)
- Abuse-monitoring logs are kept for up to 30 days by default, or longer if the law requires it or to prevent harm. — [OpenAI Your Data](https://developers.openai.com/api/docs/guides/your-data)
- ZDR and Modified Abuse Monitoring are "subject to prior approval by OpenAI", with eligibility handled by sales. ZDR forces `store=false`. ZDR-eligible endpoints include Chat Completions and Responses; Files, Batches, Assistants, vector stores and others are not eligible. — [OpenAI Your Data](https://developers.openai.com/api/docs/guides/your-data)
- Images: all images and files are scanned for CSAM on submission. Flagged images are kept for manual review even under ZDR or MAM. MAM may still log image and file inputs "in rare cases". — [OpenAI Your Data](https://developers.openai.com/api/docs/guides/your-data)
- Responses API data is kept for at least 30 days by default, or when `store` is true. Chat Completions keeps no application state, apart from audio outputs for 1 hour. — [OpenAI Your Data](https://developers.openai.com/api/docs/guides/your-data)
- HIPAA: a BAA is available with an executed Business Associate and Healthcare Addendum. BAA-eligible endpoints can process PHI once the org is provisioned with "Private Retention with PSP". Web search is not HIPAA-eligible. — [OpenAI Your Data](https://developers.openai.com/api/docs/guides/your-data)
- Gemini: on the paid tier, data is not used to improve products. On the free tier, it is used for most models. — [Gemini Pricing](https://ai.google.dev/gemini-api/docs/pricing)
- Data residency (regional processing) is available at a 10% price uplift. — [OpenAI Pricing](https://developers.openai.com/api/docs/pricing)

### Inferences
- Concrete settings:
  - Send `store: false` on every Responses call, or use Chat Completions, which keeps no state.
  - Send images inline as base64, not through the Files API, because files persist until deleted.
  - Never use Batch for real photos.
  - Strip EXIF metadata, and hold the image only in memory or a temporary directory that is deleted after the response.
- Even with `store: false`, OpenAI may keep the image in abuse logs for up to 30 days. "Photos are not persisted" is true only on the app side. The team's privacy statement should say so.
- Canada, at a high level (not verified in this session): PIPEDA governs commercial collection of personal information. Ontario's PHIPA governs personal health information held by health information custodians such as pharmacists, and generally expects safeguards and accountability for cross-border transfers. A pill photo linked to a patient's medication list would likely count as personal health information. With mock data and no real patients, these laws likely do not bind the prototype. Any real deployment would need a privacy impact assessment, consent, and possibly Canadian data residency.

### Gaps
- I did not fetch PIPEDA, PHIPA or Office of the Privacy Commissioner guidance in this session, so the Canada points above are unsourced background and need verification.
- I did not verify whether OpenAI offers a Canadian data-residency region.
- I did not find how long CSAM-flagged images are kept.

## 6. Secure iOS integration: API keys, proxy pattern, Swift clients

### Takeaway
Do not embed the OpenAI key in the app. OpenAI's guidance is to keep keys out of client-side code and route requests through your own backend. For this project that means a small serverless proxy (e.g. Cloudflare Worker, Vercel or Firebase Function) that holds the key, enforces a per-device rate limit, sets `store: false`, and forwards the request. I found no ephemeral-key mechanism for non-Realtime endpoints. Plain `URLSession` against your proxy is simplest. MacPaw/OpenAI is the main community Swift SDK.

### Cited Findings
- OpenAI's help center says never to deploy keys in client-side environments such as browsers or mobile apps, and to route requests through a backend. It recommends expiring keys, rotation, organization-level maximum key lifetimes, monthly spend limits with hard enforcement (alerts alone do not stop traffic), IP allowlisting, and workload identity federation for short-lived tokens. — [OpenAI Help: Best practices for API key safety](https://help.openai.com/en/articles/5112595-best-practices-for-api-key-safety) (content came from a search summary; the page was not fetched directly)
- MacPaw/OpenAI is a community Swift package. It supports Chat Completions, the Responses API (`client.responses.createResponse(query:)`) and structured outputs (`text: .jsonSchema(...)`). Release 0.4.9 was built with Swift 6.1 on 2026-04-30. — [Swift Package Index build](https://swiftpackageindex.com/builds/58CEA7C1-844D-4E3C-8319-E58218CB048C); [GitHub MacPaw/OpenAI](https://github.com/MacPaw/OpenAI)
- The OpenAI Structured Outputs page lists official helpers for Python and JavaScript, plus Go, Java, C# and Ruby examples. Swift is not mentioned, so there is no official Swift SDK there. — [OpenAI Structured Outputs](https://developers.openai.com/api/docs/guides/structured-outputs)

### Inferences
- With a proxy in place, the iOS app does not need an OpenAI SDK at all. It can POST JPEG data plus the patient's medication IDs to `/scan` and decode a `Codable` result. That keeps the Swift 6 strict-concurrency surface small, which matters because the repo just moved to the Swift 6 language mode, and it lets the team switch providers (OpenAI or Gemini) on the server without shipping a new app.
- Basic proxy protection for a class demo: a shared app token or Firebase App Check / Apple App Attest, a per-device daily cap, the request body size capped at about 2 MB, and a hard spend limit on the OpenAI project.

### Gaps
- I found no ephemeral or client-scoped tokens for the Responses or Chat endpoints. Ephemeral client secrets are documented for the Realtime API, but I did not re-verify that in this session.
- I did not verify the current MacPaw release number in October 2026 or its Swift 6 strict-concurrency status.

## 7. Published evidence on general multimodal LLMs identifying pills

### Takeaway
Direct evidence is thin. The best study, on ChatGPT-4 with 25 nephrology pills photographed under ideal conditions, reached 88% accuracy. Every error was a misread imprint digit that produced a different but plausible drug or dose, which is exactly the dangerous failure mode. I found no peer-reviewed 2025–2026 head-to-head of GPT-4o/5/6, Gemini and Claude on pill imprint identification. Specialized pipelines (detector, then OCR, then database lookup) remain the accuracy benchmark in the literature.

### Cited Findings
- Sheikh et al., *Renal Failure* 2024 (published online 2024-09-11):
  - Setup: ChatGPT-4 variants, including a "GPT-4.Ø" tested in August 2024, with browsing. 25 oral nephrology medications, photographed front and back on an iPhone 13 Pro Max at 4032×3024, well lit, on a grey background, from 6 inches.
  - Result: 22/25 (88%) correct, counting name, dose and imprint, on every version and date.
  - All three errors were imprint misreads: "TEVA 2089"→"2003" (wrong strength), "NF 06"→"NF 05", and "660"→"550" (wrong drug, naproxen/diclofenac 550 mg instead of spironolactone).
  - Supplying the correct imprint fixed all three.
  - Image degradation was not tested, and confidence or calibration was not reported. The paper also has an internal inconsistency in one error's reported output.
  — [PMC11391868](https://pmc.ncbi.nlm.nih.gov/articles/PMC11391868/)
- The same paper cites an earlier study (Benedict et al.) with 26% accuracy as a comparison point. — [PMC11391868 via search summary](https://doi.org/10.1080/0886022X.2024.2402075)
- *Scientific Reports* 2024, "Assessing the ability of GPT-4o to visually recognize medications and provide patient education": GPT-4o was tested on medication images, including blurred ones, and handled the written medication information well. Its generated instruction images scored poorly (16.7%). I could not fetch the full text because of a Nature login redirect, so the accuracy numbers are not verified. — [Nature Sci Rep s41598-024-78577-y](https://www.nature.com/articles/s41598-024-78577-y)
- A 2026 *Frontiers in AI* hybrid pipeline (YOLO detection, MobileNet attribute classifier, EasyOCR imprint reading, metadata retrieval) handles multi-pill detection with no LLM comparison. A related review covers 91 studies. Imprint-recognition systems such as GO-PILL report Top-1/5/10 of 46.63% / 68.80% / 76.52% on NLM images, which shows that imprint reading is hard even for specialized systems. — [Frontiers frai.2026.1890296](https://www.frontiersin.org/journals/artificial-intelligence/articles/10.3389/frai.2026.1890296/xml) (from a search summary; figures not cross-checked in the full text)
- Dedicated pill-recognition models report about 91–97% on NIH-style datasets, and the paper notes that GPT-4 needs clear, well-oriented images. — [IJACSA 2024 Vol 15 No 7](https://thesai.org/Downloads/Volume15No7/Paper_68-A_Computer_Vision_Based_Pill_Recognition_Application.pdf) (from a search summary)

### Inferences
- The project's problem is easier than open-world pill ID: a closed set of about 4 registered medications, matched against known color, shape and imprint. Accuracy will likely be well above open-set figures. Still, the 88% study shows that a misread digit can map to a plausible wrong drug, so the app must verify the model's imprint reading against the registered imprint in code and flag any mismatch as uncertain.
- Palm photos (skin background, hand shadows, pills at different angles, both sides not visible) are harder than the study's controlled setup. Expect lower imprint legibility. A "flip pills / retake" prompt is a reasonable UX fallback.

### Gaps
- I found no 2025–2026 peer-reviewed study comparing GPT-4o/5/6, Gemini and Claude on pill identification, and no study measuring imprint hallucination rates or overconfidence and calibration. This is a genuine gap and a possible contribution for the CS497 report.

## 8. Do reference images in the prompt (few-shot visual matching) help?

### Takeaway
Evidence is indirect but mostly positive. GPT-4V's accuracy on pathology classification rose with more in-context example images. Other work finds that vision-language models often fail at tasks defined only by demonstrations. I found no pill-specific evidence. Treat reference images as a hypothesis to test with an A/B run, and pair them with the structured text attributes (color, shape, imprint) of each registered medication.

### Cited Findings
- On histopathology, GPT-4V with ten-shot in-context learning matched or beat retrained specialist classifiers. One class improved from 67% at three shots to 80% at ten. — [Ferber et al., arXiv 2403.07407](https://arxiv.org/pdf/2403.07407)
- State-of-the-art vision-language models "often fail" at n-way few-shot visual recognition and instance recognition defined only by demonstrations, partly because they lack in-context-learning instruction tuning. — [Doveh et al., arXiv 2403.12736](https://arxiv.org/pdf/2403.12736v1)
- Microsoft's GPT-4V report lists few-shot visual in-context learning as a supported test-time technique. — [Yang et al., arXiv 2309.17421](https://arxiv.org/pdf/2309.17421)
- In the pill study, giving the model the correct imprint text fixed every error, which suggests that text-attribute grounding is powerful. — [PMC11391868](https://pmc.ncbi.nlm.nih.gov/articles/PMC11391868/)

### Inferences
- Reference images are cheap: about 173 tokens each at 384×384 on GPT-6.x, under $0.001 for four on Terra. They are also cacheable if placed in a fixed prompt prefix. The cost argument therefore favours including them. Label each reference with its medication ID and its imprint text.
- Evaluation plan: about 30 palm photos covering the mock medications. Compare (a) text attributes only, (b) attributes plus reference images, and (c) on-device crops versus the full photo. Measure per-pill top-1 accuracy, the false-confident rate (wrong and not flagged uncertain), and token usage. At about $0.01 per call, the whole grid costs a few dollars.

### Gaps
- I found no study of reference-image prompting for pill or medication identification, and no study of how it affects calibration.

## Appendix: Comparable API pricing snapshot (read 2026-10-30)
- **Gemini**, USD per 1M tokens — [Gemini Pricing](https://ai.google.dev/gemini-api/docs/pricing):

| Model | Input | Output | Notes |
|---|---|---|---|
| `gemini-4-argon` | $2 | $10 | Rises to $4 / $20 on 2026-12-01 |
| `gemini-3.8-flash` | $0.75 | $3.75 | Rises to $1.50 / $7.50 on 2027-01-01 |
| `gemini-3-flash-preview` | $0.50 | $3.00 | |
| `gemini-2.5-flash` | $0.30 | $2.50 | |
| `gemini-3.1-flash-lite` | $0.25 | $1.50 | |
| `gemini-2.5-flash-lite` | $0.10 | $0.40 | |

  - Batch is about 50% of these prices.
  - Image tokens: an image of 384 px or less on both sides costs 258 tokens. Larger images are split into 768×768 tiles at 258 tokens each, using a crop unit of about min(w,h)/1.5. — [Gemini Image Understanding](https://ai.google.dev/gemini-api/docs/image-understanding)
  - My estimate: 1536×2048 gives a crop unit of 1024 and 2×2 tiles, about 1,032 tokens. A Scenario A scan on 3.8 Flash would cost about $0.004–0.005.
  - The inline request limit is 20 MB, up to 3,600 images per request, and HEIC is accepted. — [Gemini Image Understanding](https://ai.google.dev/gemini-api/docs/image-understanding)
- **Claude**:
  - Image tokens = ⌈w/28⌉×⌈h/28⌉. The standard tier caps at a 1,568 px long edge and 1,568 tokens. Claude 4.7 and later models are on a high-resolution tier capped at 2,576 px and 4,784 tokens.
  - Up to 600 images per request, at most 8000×8000 px, 10 MB per image. Above 20 images per request, keep each side at 3,000 px or less.
  - The docs' example prices are Haiku 4.5 at $1 per 1M input tokens and Opus 5.5 at $4 per 1M input. A 1000×1000 image costs about $5.18 per 1,000 images on Opus 5.5.
  - My estimate: a 1536×2048 image on the high-resolution tier is about 4,070 tokens.
  - Claude output prices were not verified in this session; see [claude.com/pricing](https://claude.com/pricing).
  — [Anthropic Vision](https://platform.claude.com/docs/en/build-with-claude/vision)
