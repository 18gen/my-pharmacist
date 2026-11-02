# Medication Reference Data Sources for a Canadian Pill-Identification Prototype (as of Oct 2026)

Scope note: about 25 tool calls, mostly against primary sources (health-products.canada.ca, open.canada.ca, infoway-inforoute.ca, nlm.nih.gov, dailymed.nlm.nih.gov, GitHub). A few pages failed to load: drugs.com terms (HTTP 403), the data.gov C3PI page (404), and the Pfizer Canada monograph page (404). I could not extract text from the monograph PDF locally because no PDF tool is installed. Claims that rest only on my background knowledge are marked "[unverified]".

## Q1. Health Canada Drug Product Database (DPD): API, fields, appearance data, monographs, licence

### Takeaway
The DPD is the authoritative, free Canadian source for drug identity: DIN, brand, ingredient and strength, dosage form, company, status, schedule and ATC. It is under the Open Government Licence – Canada, available as a JSON/XML REST API plus monthly bulk extracts. It has no structured colour, shape or imprint fields and no images. Appearance appears only as free text inside the product monograph PDF linked from each DPD product page.

### Cited Findings
- Base URI is `https://health-products.canada.ca/api/drug/`. Output is JSON (default) or XML via `type=`, and `lang=en|fr` is supported. — [DPD API documentation](https://health-products.canada.ca/api/documentation/dpd-documentation-en.html)
- Endpoints and key fields — [DPD API documentation](https://health-products.canada.ca/api/documentation/dpd-documentation-en.html):
  - `drugproduct`: params `id`, `din`, `brandname`, `status`. Returns `drug_identification_number`, `brand_name`, `class_name`, `descriptor`, `number_of_ais`, `ai_group_no`, `company_name`, `last_update_date`, `drug_code`.
  - `activeingredient`: `ingredient_name`, `strength`, `strength_unit`, `dosage_value`, `dosage_unit`.
  - `form`: `pharmaceutical_form_name` (for example, Tablet or Capsule).
  - `route`, `schedule`, `status` (with `history_date`, `original_market_date`), `therapeuticclass` (ATC), `company`.
  - `packaging`: `package_type`, `package_size`, `upc`, `product_information`.
  - `pharmaceuticalstd`, `veterinaryspecies`.
  - `drug_code` is the internal join key across endpoints.
- No endpoint documents colour, shape, imprint, size or images. The only free-text field is `descriptor`, described only as "Additional details or descriptions for a product, if applicable." — [DPD API documentation](https://health-products.canada.ca/api/documentation/dpd-documentation-en.html)
- The open.canada.ca listing "Drug Product Database – All Files" has licence **Open Government Licence – Canada**, **monthly** update frequency, and ZIP extracts (full set, by-status subsets, reference files for ingredient, company, form, packaging, schedule, status, route, therapeutic class). The listing was last modified 2025-05-28. — [open.canada.ca DPD dataset](https://open.canada.ca/data/en/dataset/bf55e42a-63cb-4556-bfd8-44f26e5a36fe)
- Example DPD web product page (GLEEVEC, DIN 02253283). It shows status (Marketed), company, dosage form, route, schedule, ATC L01EA01, AIG number, and active ingredient (imatinib 400 MG). It also has a "Product Monograph" PDF link dated 2026-01-15 at `https://pdf.hres.ca/dpd_pm/00083190.PDF`. The page itself has no colour, shape or imprint. The PDF file ID is not derived from the DIN. — [DPD product page](https://health-products.canada.ca/dpd-bdpp/info?lang=eng&code=73825)
- I downloaded that monograph directly (no login, 70-page PDF, fetch succeeded) but could not text-extract it locally. — direct fetch of [pdf.hres.ca/dpd_pm/00083190.PDF](https://pdf.hres.ca/dpd_pm/00083190.PDF)
- Product monographs are written by the drug sponsor following Health Canada guidelines and include a "Dosage Forms, Strengths, Composition and Packaging" section. Manufacturer pages reproduce it (for example, the Pfizer Canada Nurtec ODT page titled "6 Dosage Forms, Strengths, Composition And Packaging"). — [search result: Pfizer Medical Information Canada](https://pfizermedicalinformation.ca/nurtec/6-Dosage-Forms) (page returned 404 on direct fetch; title only)

### Inferences
- A DPD monograph link is reachable from the DPD web page but not from the documented API fields. To get monograph URLs at scale you would scrape the DPD HTML pages, which is legal under OGL for the data, but monograph PDF copyright sits with the sponsor (see Gaps).
- In the current Health Canada monograph template, the "Dosage Forms, Strengths, Composition and Packaging" section usually describes tablet colour, shape, scoring and debossing in prose. Example: "yellow, round, biconvex film-coated tablet debossed 'X' on one side". [unverified for the specific Gleevec PDF; based on background knowledge of the template]. Parsing it requires PDF text extraction plus NLP or manual transcription. It is not structured data.
- Because DPD is at DIN level, and a DIN is specific to one manufacturer's product, DIN plus monograph is the closest Canadian analogue to a US NDC-level SPL appearance record.

### Gaps
- I did not confirm the exact appearance wording inside a specific Canadian monograph, because local PDF extraction failed.
- Copyright and licence terms for the monograph PDFs themselves (sponsor-authored, hosted on pdf.hres.ca) were not found. OGL covers the DPD data listing, and it is unclear whether it extends to the PDFs.
- I did not separately verify the Drug and Health Product Register (DHPR) or whether it exposes monographs differently.

## Q2. Other Canadian sources: CCDD, provincial formularies, commercial databases

### Takeaway
CCDD (Canada Health Infoway) is a free-with-login drug terminology covering MP, NTP and TM concept levels mapped to DINs. It contains no appearance data. Canadian pill images and imprints exist only in commercial products: Vigilance Santé's Drug Photo Database/RxPhotos and CPhA's CPS Full Access (formerly RxTx) Pill Identifier. Neither publishes an open or academic data licence.

### Cited Findings
- The CCDD is "the drug terminology for use in digital health solutions such as electronic prescribing". It has French descriptions since the December 2019 release. Downloads require an Infoway account login through the Terminology Gateway, with users reconfirming acceptance of the Terms of Use and License Agreements annually. Infoway tools are free with an active account. — [Infoway CCDD page](https://sl.infoway-inforoute.ca/en/standards/canadian/ccdd)
- CCDD is also listed on the Open Government Portal, pointing to the Terminology Gateway (free login), and is labelled non-proprietary. — [open.canada.ca CCDD](https://open.canada.ca/data/en/dataset/3e0a7b9e-a5e9-4131-bde4-ac685a1f1a38)
- Health Canada also notes CCDD in its February 2025 Health Product InfoWatch. — [Health Product InfoWatch Feb 2025](https://www.canada.ca/en/health-canada/services/drugs-health-products/medeffect-canada/health-product-infowatch/february-2025.html) (title seen in search only; content not fetched)
- Vigilance Santé markets a "Drug Photo Database", described as "The most complete Canadian drug photo bank for quick and easy visual identification", plus RxPhotos and RxPhotosID software. — [vigilance.ca](https://www.vigilance.ca/)
- The Vigilance Drug Photo Database includes photos of medications and their packaging (bottles, boxes, blister packs) and "photos of previous appearances", plus product descriptions. It is updated monthly, can be integrated with "any application or software", and is aimed at developers of tools for health professionals. No photo count, licence terms, academic access or pricing is published. — [Vigilance Drug Photo Database](https://www.vigilance.ca/drug-database-photo)
- Vigilance distributes AHFS classification licences in Canada with DIN mappings. — [Vigilance news](https://www.vigilance.ca/news-and-update/vigilance-sante-becomes-official-distributor-of-ahfs)
- CPS Full Access (formerly RxTx) from the Canadian Pharmacists Association has a Pill Identifier tool ("visual confirmation of the product in hand"). It is a subscription product available through institutional or library subscriptions. — [RRC Polytech Library](https://library.rrc.ca/RxTx/drugID); [Regina Public Library](https://reginalibrary.ca/digitalservices/CPS-Full-Access)
- FDB MedKnowledge Canada exists ("most widely used drug database within healthcare IT applications" in Canada, per FDB's 2019 release). FDB drug images are documented for the US product (NDC-level, with multiple active images per NDC where the manufacturer verified them). I found no confirmation that the Canadian product includes images or imprints. — [FDB Canada release (BioSpace)](https://www.biospace.com/fdb-releases-expanded-canadian-french-drug-knowledge); [FDB Drug Images (RedSail help)](https://hub.redsailtechnologies.com/documents/RS/NRX/NRx%20Help%20Center/Whats_New/NRx_Enhancements_Overview/First_Databank_Drug_Images.htm)
- A third-party site, canadian-pill-identifier.com, says it updates monthly from Health Canada changes and describes imprint, colour, shape and score. Its provenance and licence are unknown. — [canadian-pill-identifier.com](https://canadian-pill-identifier.com/)

### Inferences
- An institutional CPS Full Access subscription (UWaterloo library may have one) allows manual lookup of Canadian pill appearances for building mock data by hand. Bulk extraction would likely breach subscription terms.
- Vigilance is the most plausible route to a licensed Canadian pill photo set. An academic request by email would be needed.

### Gaps
- I did not find the CCDD licence text itself (it sits behind login), whether the CCDD Technical Specification includes any appearance attributes (likely not), or its release cadence.
- I did not research the Ontario Drug Benefit formulary. From background knowledge, it is DIN/price/benefit data without appearance, but this is unverified.
- I did not verify whether UWaterloo libraries subscribe to CPS, or Vigilance's academic pricing.
- Medi-Span and Multum Canadian coverage was not verified.

## Q3. US sources: Pillbox, RxImage, C3PI, RxNorm, DailyMed SPL, openFDA

### Takeaway
NLM retired Pillbox on 28/29 January 2021 and the RxImage API on 31 December 2021. Their final data and images survive as static downloads on NLM Data Discovery, for research, development and education only, explicitly "not for pill identification". DailyMed SPL remains the live US source of structured appearance attributes (SPLCOLOR, SPLSHAPE, SPLSIZE, SPLIMPRINT, SPLSCORE), keyed to NDC.

### Cited Findings
- Pillbox retirement: NLM announced the program "will be retired" on **January 29, 2021**. Retirement covered the websites, dataset production, image library and APIs. The final data and images remain as static files for research, development and education, will not be updated, and "should not be used for pill identification". NLM states MedlinePlus and DailyMed do not provide pill identification. — [NLM Technical Bulletin, Pillbox discontinue](https://www.nlm.nih.gov/pubs/techbull/ja20/ja20_pillbox_discontinue.html)
- Data.gov catalogue title: "Pillbox (retired January 28, 2021)", a one-day discrepancy with the bulletin. It offers CSV, JSON, XML and RDF downloads (for example, `https://datadiscovery.nlm.nih.gov/api/views/crzr-uvwg/rows.csv?accessType=DOWNLOAD`). The image library is a zip on the NLM FTP server. — [data.gov Pillbox (retired)](https://catalog.data.gov/dataset/pillbox-retired-january-28-2021)
- The RxImage API "will cease operation on December 31, 2021". All RxImage data are downloadable from NLM Data Discovery. The link was updated in an editor's note dated July 12, 2024: `https://datadiscovery.nlm.nih.gov/Drugs-and-Chemicals/Pillbox-retired-January-28-2021-/crzr-uvwg/about_data/`. — [NLM Technical Bulletin, RxImage API](https://www.nlm.nih.gov/pubs/techbull/so21/so21_rximage_api.html)
- C3PI (Computational Photography Project for Pill Identification) was sunset in 2018 with no new images. Downloads include a reference image set (~6.8 GB zip), a training set of ~133,000 consumer-grade images, and a 493 MB sample zip. Images and metadata are "for research and development purposes only". — [data.gov C3PI](https://catalog.data.gov/dataset/computational-photography-project-for-pill-identification-c3pi-82201) (via search snippet; direct fetch returned 404 on Oct 30 2026); [InfoDocket 2013 on RxImage launch with ~1,800 images](https://www.infodocket.com/2013/07/23/reference-nlm-releases-1800-hi-quality-images-of-pills-now-available-via-api/)
- DailyMed web services v2 `/spls` supports filters: setid, drug_name (with name_type), labeler, manufacturer, application_number, ndc, rxcui, unii_code, drug_class_code, boxed_warning, dea_schedule_code, doctype, marketing_category_code, published_date. Output is XML/JSON, with page size capped at 100. Lookup endpoints: `/applicationnumbers`, `/drugclasses`, `/drugnames`, `/ndcs`, `/rxcuis`, `/uniis`. There is no appearance filter. — [DailyMed v2 /spls docs](https://dailymed.nlm.nih.gov/dailymed/webservices-help/v2/spls_api.cfm)
- SPL product characteristics: SPLCOLOR (predominant colour(s), "not an FDA specification for actual colors"), SPLIMPRINT (embossed, debossed, engraved or printed alphanumerics, including logos readable as characters), and SPLSHAPE (2-D outline, NCI codes such as ROUND C48348, OVAL C48345, CAPSULE C48336). — [HL7 MedicationObservationType value set](https://terminology.hl7.org/ValueSet-v3-MedicationObservationType.html); [FDA Data Standards Manual – SPL Color](https://www.fda.gov/drugs/data-standards-manual-monographs/data-standards-manual-monographs-spl-color)
- The NLM UMLS MTHSPL source includes SPL attribute statistics, so SPL attributes are also redistributed in UMLS. — [UMLS MTHSPL stats](https://www.nlm.nih.gov/research/umls/sourcereleasedocs/current/MTHSPL/stats.html)

### Inferences
- [unverified, background knowledge] Appearance attributes live inside each SPL XML (`<characteristic>` elements per product). Retrieving them means downloading the SPL (`/spls/{setid}.xml`) or bulk SPL zips and parsing. DailyMed also offers `/spls/{setid}/media` for label images, sometimes including tablet photos. DailyMed content is generally public-domain US government/FDA-submitted labelling.
- [unverified, background knowledge] RxNorm/RxNav APIs provide normalized clinical drug concepts (RxCUI, ingredient, strength, dose form) and NDC mappings, with no images since RxImage retirement. openFDA `/drug/label` and `/drug/ndc` provide label text and NDC metadata (CC0-style public data) but no structured imprint fields. Neither was verified this session.
- All US sources are US-market (NDC). They cover Canadian DIN products only where the same physical product is sold in both markets.

### Gaps
- I did not fetch the DailyMed `/spls/{setid}/media` docs, the DailyMed licensing/copyright page, RxNav API docs, or openFDA docs.
- I did not confirm the current live availability of the C3PI download links (the data.gov page returned 404 on fetch).

## Q4. Commercial pill identifiers (Drugs.com, Medscape, WebMD, FDB, Medi-Span, Multum)

### Takeaway
None offer free or academic bulk access that I could verify. Drugs.com's terms page blocked automated fetch (403). FDB image data is a commercial licence, and its documented image product is US/NDC-based. Treat these as manual reference only, not as data sources.

### Cited Findings
- Drugs.com Pill Identifier searches by imprint, shape and colour, and is "updated daily" per its app listing. The terms are at drugs.com/support/terms.html, which returned HTTP 403 to my fetch, so the scraping clauses are unverified. — [Drugs.com app listing](https://apps.apple.com/au/app/id599471042?l=en-au); [drugs.com terms (blocked)](https://www.drugs.com/support/terms.html)
- A third-party 2026 tutorial notes Drugs.com uses "multi-layered bot defenses" and advises reviewing its ToS. This is a secondary source. — [blog](https://frog03-20494.wykr.es/blog/scrape-drugs-com-medication-2026)
- FDB drug images are high-resolution photographs of Rx and OTC products. A single NDC may have multiple active images when the manufacturer verified both are still in market. This is distributed through licensed pharmacy software. — [RedSail FDB Drug Images](https://hub.redsailtechnologies.com/documents/RS/NRX/NRx%20Help%20Center/Whats_New/NRx_Enhancements_Overview/First_Databank_Drug_Images.htm); [MedPak FDB licence](https://medpak.com/first-databank-license)

### Inferences
- [Assumption] Drugs.com, Medscape and WebMD pill identifiers are largely US-market and built from licensed data (Drugs.com historically from Multum/Cerner). They likely prohibit automated harvesting.
- Academic licences from FDB, Medi-Span (Wolters Kluwer) or Multum would require direct negotiation and are overkill for a mock-data prototype.

### Gaps
- No verified ToS text for Drugs.com, Medscape or WebMD. No verified academic licensing terms for FDB, Medi-Span or Multum.

## Q5. Canada–US appearance overlap

### Takeaway
I found no quantitative evidence on how often Canadian and US pills look the same. Overlap should be assumed partial and checked per product.

### Cited Findings
- Apotex has separate US product pages (US NDCs) for molecules it also sells in Canada. This shows the same company operates in both markets, but not that the tablets are identical. — [Apotex US product example](https://apotex.com/products/us/detail.asp?m=69162)

### Inferences
- [Assumption] Many brand products made in global plants share the same tablet and imprint across Canada and the US (for example, imprints like "NVR" for Novartis). Canadian generics (Apotex, Teva Canada, Sandoz Canada, Pharmascience, Auro, etc.) often have Canada-specific imprints. US Pillbox/C3PI/SPL appearance data cannot be trusted for a Canadian DIN without checking against the Canadian monograph.

### Gaps
- No study or dataset quantifying Canada–US imprint overlap was found.

## Q6. Manufacturer variation and how databases represent multiple appearances

### Takeaway
Appearance is a property of the specific marketed product (Canadian DIN, US NDC/SPL), not of the clinical drug (ingredient plus strength). Commercial databases explicitly track multiple and historical appearances.

### Cited Findings
- FDB allows multiple active images per NDC when the manufacturer confirms both are on market. — [RedSail FDB Drug Images](https://hub.redsailtechnologies.com/documents/RS/NRX/NRx%20Help%20Center/Whats_New/NRx_Enhancements_Overview/First_Databank_Drug_Images.htm)
- Vigilance's photo database includes "photos of previous appearances". — [Vigilance Drug Photo Database](https://www.vigilance.ca/drug-database-photo)
- DPD assigns DINs per company product (each record carries `company_name`). For example, GLEEVEC DIN 02253283 is Novartis-specific. — [DPD API docs](https://health-products.canada.ca/api/documentation/dpd-documentation-en.html); [DPD product page](https://health-products.canada.ca/dpd-bdpp/info?lang=eng&code=73825)
- ePillID notes 4,902 pill types and 9,804 appearance classes (two sides each), so each side is treated as a separate appearance class. — [ePillID repo](https://github.com/usuyama/ePillID-benchmark)

### Inferences
- In the "My Pharmacist" model, registering the **dispensed DIN** (not just the drug and strength) is required to know the expected appearance. If only ingredient plus strength is known (CCDD NTP level), the app must accept a set of candidate appearances, one per marketed generic DIN. Interchangeable-generic substitution at the pharmacy can change appearance between refills.
- The data model should be: Medication (ingredient, strength) → 1..n Products (DIN, manufacturer) → 1..n Appearances (colour, shape, size, imprint front/back, score, valid-from/to, reference images).

### Gaps
- No quantitative statistic on how often generic substitution changes appearance was found this session.

## Q7. Benchmark and fine-tuning datasets (licensing)

### Takeaway
The usable public pill image datasets (C3PI/Pillbox and the derived ePillID) are US-only and restricted to research. They are fine for an academic prototype but contain no Canadian-specific products.

### Cited Findings
- C3PI: ~133k consumer-grade training images plus a reference set. "Research and development purposes only". Sunset in 2018. — [data.gov C3PI](https://catalog.data.gov/dataset/computational-photography-project-for-pill-identification-c3pi-82201)
- ePillID: ~13k images, 9,804 appearance classes / 4,902 pill types, mostly one reference image per class. Built from the NIH NLM Pill Image Recognition Challenge and Pillbox. Code is under MIT; data and software are "released for research purposes only". — [ePillID-benchmark GitHub](https://github.com/usuyama/ePillID-benchmark); [arXiv 2005.14288](https://arxiv.org/abs/2005.14288v1)
- Roboflow mirrors of ePillID are labelled CC BY 4.0, but these are third-party re-hosts and may not reflect the original terms. — [Roboflow ePillID](https://universe.roboflow.com/pills-l7v0j/epillid-full-library)

### Inferences
- Prefer the original NLM/ePillID sources and cite them, and treat Roboflow's CC BY label as unreliable.

### Gaps
- I found nothing on a "CURE" pill dataset. Its licence and availability are unverified.
- None of these datasets show multiple pills in a palm, so the in-hand four-pill scenario needs self-collected images.

## Q8. Recommendation for the academic prototype (mock data)

### Takeaway
Use the Health Canada DPD (OGL-Canada, free API) for medication identity and metadata. Hand-transcribe appearance from DPD-linked product monographs for the handful of mock medications. Use US C3PI/ePillID only for research-only model benchmarking. Self-collect in-hand reference photos of the actual pills used in demos.

### Cited Findings
- DPD offers an OGL-Canada licence, monthly extracts and a JSON API with DIN, brand, ingredient, strength, form and company. — [open.canada.ca DPD](https://open.canada.ca/data/en/dataset/bf55e42a-63cb-4556-bfd8-44f26e5a36fe); [DPD API docs](https://health-products.canada.ca/api/documentation/dpd-documentation-en.html)
- Monograph PDFs are linked from DPD pages and downloadable without login. — [DPD product page](https://health-products.canada.ca/dpd-bdpp/info?lang=eng&code=73825)
- NLM says retired Pillbox data "should not be used for pill identification" (in production). It is for research and education only. — [NLM bulletin](https://www.nlm.nih.gov/pubs/techbull/ja20/ja20_pillbox_discontinue.html)

### Inferences (recommendation)
- **Metadata:** DPD API (`drugproduct?din=…`, `activeingredient?id=…`, `form?id=…`) to seed mock patient medications with real DINs. Optionally use CCDD (free Infoway login) for e-prescribing-style concept codes, mirroring "registered from prescription".
- **Appearance attributes:** For ~5–20 mock DINs, manually transcribe colour, shape, imprint, score and size from each monograph's "Dosage Forms, Strengths, Composition and Packaging" section into a local JSON schema modelled on SPL characteristics (SPLCOLOR, SPLSHAPE, SPLSIZE, SPLIMPRINT, SPLSCORE). Store DIN-level, with multiple appearances allowed.
- **Reference images:** Self-collect photos of the demo pills, ideally placebo or vitamin lookalikes or the team's own legitimately held OTC products, front and back plus in-hand. Optionally use C3PI/ePillID images (research-only) for offline benchmarking of the imprint/colour pipeline. Avoid Drugs.com or CPS scraping. If Canadian commercial photos are wanted, request an academic arrangement from Vigilance Santé or use the UWaterloo library CPS subscription for manual verification only.
- **Must be self-collected:** in-hand, multi-pill, Canadian-lighting/phone-camera images; any Canadian-generic reference photos; and ground-truth labels linking photos to DINs.

### Gaps
- Licence status of monograph PDF text for redistribution within an app is unverified. For a non-distributed academic prototype this is low risk, but it should be confirmed with Health Canada or the sponsor if the app is published.
