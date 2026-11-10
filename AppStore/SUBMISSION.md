# My Pharmacist: App Store submission pack

Everything App Store Connect asks for, in the order it asks. Each box can be pasted as
is. The character limits are Apple's; every text here fits them.

---

## 0. Before App Store Connect

1. **Apple Developer Program** ($99 a year, at developer.apple.com/programs). The project
   already uses team `F4X59UTGAL`; check that this is the paid membership and not a free
   personal team.
2. **Deploy the pill check server** (`server/pill-check/README.md`):
   1. In `wrangler.jsonc`, set `SUPPORT_EMAIL` to the email that answers support.
   2. `npx wrangler secret put OPENAI_API_KEY`, then `npx wrangler secret put APP_TOKEN`
      (any long random string, e.g. from `openssl rand -hex 32`).
   3. `npx wrangler deploy`. Note the address it prints, e.g.
      `https://my-pharmacist-pill-check.<you>.workers.dev`.
   4. Open `<address>/privacy` and `<address>/support` in a browser and check that both
      show your email.
3. **Set a budget limit on OpenAI** (platform.openai.com → Settings → Limits), e.g.
   $20 a month. The token in the app can be extracted, and the limit caps what abuse
   could cost.
4. **Fill in `MyPharmacist/Resources/Secrets.plist`** (copy `Secrets.example.plist`):
   - `PILL_CHECK_URL`: the address from step 2.3.
   - `PILL_CHECK_TOKEN`: the same `APP_TOKEN` value.

   Without this file, every scan says "Couldn't check".
5. **Test on your iPhone** (Debug, from Xcode):
   1. Add one of your own pills with the camera.
   2. Scan it.
   3. Turn the light on.
   4. Deny camera access, then use Open Settings.
   5. Leave the app and come back while aiming.
   6. Use Load sample list.

---

## 1. Create the app record

App Store Connect → Apps → **+** → New App.

| Field | Value |
|---|---|
| Platforms | iOS |
| Name | `My Pharmacist – Pill Check` (see note) |
| Primary language | English (Canada), or English (U.S.) |
| Bundle ID | `com.genichihashi.MyPharmacist` (register it first under Certificates, IDs & Profiles → Identifiers if it isn't listed) |
| SKU | `mypharmacist-ios-1` |
| User access | Full access |

> **About the name.** "Pharmacist" can read as if a professional is giving advice, which
> reviewers look at closely under guideline 1.4.1, and some jurisdictions protect the title.
> If the name is rejected, use one of these instead:
> - `PillCheck – Dose Double-Check`
> - `Pill Scan: Right Pill, Right Time`
>
> The name on the home screen ("My Pharmacist", `CFBundleDisplayName`) may differ from the
> store name, but it shouldn't contradict it.

---

## 2. App Information

| Field | Value |
|---|---|
| Subtitle (30) | `Check pills before you take` |
| Category, primary | Medical |
| Category, secondary | Health & Fitness |
| Content rights | "No, it does not contain, show, or access third-party content." |
| Age rating | See §6 |
| License agreement | Apple's standard EULA |

**Regulated medical device** (shown for apps in the Medical category, for the EU, UK and
US). Answer this honestly. If no regulator has cleared the app, don't claim it is a
cleared device. Check with your course supervisor before the public release (see §10).

---

## 3. Pricing and Availability

- **Price:** Free.
- **Availability:** choose countries on purpose. Starting with Canada only keeps the
  regulatory exposure small.
- **EU Digital Services Act trader status:** if you sell nothing and are an individual,
  you can declare "not a trader", and the app will then not be offered in the EU. If you
  declare "trader", your address and phone number become public on the listing.

---

## 4. App Privacy

### Privacy Policy URL
`https://my-pharmacist-pill-check.<you>.workers.dev/privacy`

### Data collection: "Yes, we collect data from this app"

Choose **two** data types. Answer the same for each:

| Data type | Used for | Linked to the user? | Used for tracking? |
|---|---|---|---|
| **Photos or Videos** (the pill pictures sent for checking) | App Functionality | **No** | **No** |
| **Health** (the medication names and pill photos sent with them) | App Functionality | **No** | **No** |

Why disclose at all? Our server keeps nothing, but OpenAI may keep requests for up to 30
days to detect abuse. That is longer than "processed in real time", so Apple counts it as
collected. These answers match `PrivacyInfo.xcprivacy`.

Nothing else is collected: no accounts, no analytics, no ads, no location, no contacts.

---

## 5. Version page (1.0)

### Promotional text (170)
```
Take the right pills at the right time. Photograph the pills in your hand and see which ones to take now, and which to put back.
```

### Description (4000)
```
My Pharmacist double-checks your pills before you take them.

Put the pills you're about to take in your hand and point the camera at them. The app finds each pill, recognizes which of your medications it is, and tells you, pill by pill:

• Take now: it's one of your medications and it's due.
• Don't take now: it's too early, already taken, or too late for this dose.
• Unknown: it isn't one of the medications on your list.

Built for people who take many medications, like during cancer treatment, and for the people who help them.

SIMPLE BY DESIGN
• No shutter button. Hold the pills steady and the photo is taken for you.
• Large text, high contrast and clear words. Works with VoiceOver and larger text sizes.
• Before checking, the app shows every pill it found and asks whether that's all of them, so none is missed.
• It never guesses. If a pill or the photo isn't clear, it says so and asks for another photo.

YOUR MEDICATIONS
• Add each medication with a photo of its pill, its strength, what it's for and when you take it, or mark it "when needed".
• Today's doses on the home screen: morning, noon, evening, bedtime.
• A pill counts for a dose from an hour before its time to two hours after. Later than that, the app tells you to ask your pharmacist.
• Try it first with the sample list.

PRIVACY
• Your medication list and pill photos stay on your phone. There's no account.
• When you check pills, and only after you allow it, pictures of those pills and of your medications' pills are sent to be recognized. Our server keeps nothing. OpenAI may keep them for up to 30 days to detect abuse, and doesn't use them to train its models.
• Nothing is saved to your photo library.

IMPORTANT
My Pharmacist is a double-check, not medical advice. It doesn't replace your pharmacist, doctor or the label on your medication. Always follow their instructions, and ask your pharmacist if you're unsure.
```

### Keywords (100, commas, no spaces)
```
pill,medication,medicine,scan,dose,identifier,oncology,chemo,tablet,schedule,caregiver,check
```
(92 characters. Words already in the name are left out, because Apple indexes the name anyway.)

### URLs
| Field | Value |
|---|---|
| Support URL | `https://my-pharmacist-pill-check.<you>.workers.dev/support` |
| Marketing URL | Leave empty (optional) |

### Version and copyright
- **Version:** 1.0 (build 1). Each new upload needs a higher build number (Xcode → target
  → General → Build).
- **Copyright:** `2026 Gen Ichihashi`

### Screenshots, iPhone 6.9" (1320 × 2868), 3 to 10 of them
Take them in the **iPhone 16 Pro Max** or **17 Pro Max** Simulator, from a Debug build:
Product → Scheme → Edit Scheme → Run → Arguments, add one flag, run, then press ⌘S in the
Simulator. Order them like this:

| # | Launch flag | What it shows | Caption idea |
|---|---|---|---|
| 1 | `-demoScan` | Results: take now / don't take now | "See which pills to take now" |
| 2 | `-demoFind -noCloud` (stop at the question) | Every pill circled, "Is that all of them?" | "Never miss a pill" |
| 3 | *(none, sample list loaded)* | Home with today's doses | "Today's doses at a glance" |
| 4 | `-demoMedications` | My Medications | "Your own medications, your own pills" |
| 5 | `-demoNewMedication` | Adding a medication | "Add a pill with one photo" |
| 6 | `-demoAbout` | About & privacy | "Your list stays on your phone" |

The screenshots must show the app as it really works. Don't add claims like
"100% accurate".

App Store Connect scales the 6.9" set down for smaller iPhones. iPad screenshots aren't
needed, because the app is iPhone-only.

### Build
Upload it from Xcode:
1. Pick **Any iOS Device (arm64)** as the destination, then Product → **Archive**.
2. In the Organizer, **Distribute App** → App Store Connect → Upload.
3. When the build appears (10–30 minutes later), choose it here.

Export compliance is already answered: `ITSAppUsesNonExemptEncryption = NO`, since the app
uses HTTPS only.

---

## 6. Age rating questionnaire

Answer **None / No** to everything except:

| Question | Answer |
|---|---|
| Medical or treatment information | **Yes** (Infrequent/Mild if levels are offered) |
| Unrestricted web access | No (the privacy and help links open fixed pages) |
| User-generated content / messaging | No |
| Age assurance, parental controls | No |

Apple works out the rating from these answers.

---

## 7. App Review Information

| Field | Value |
|---|---|
| Sign-in required | **No** (there are no accounts) |
| Contact | Your name, phone and email |
| Attachment | `design/demo-pills/sample-list-pills-letter.pdf` |

### Notes (paste)
```
My Pharmacist is a patient-facing double-check: the person photographs the pills in their hand, and the app says which of THEIR OWN registered medications each pill is and whether it is due now. It does not diagnose, dose or recommend treatment, and every result screen says "A double-check, not medical advice. Ask your pharmacist if unsure."

HOW TO TRY IT (no account needed)
1. Tap the pills button (top right) > "Load sample list" > confirm. This loads four sample medications with photos of their pills and sample times.
2. Print the attached PDF (letter size, colour) and cut out the pills, or show it on a screen. Its pictures match the sample list.
3. Back on the home screen, tap the camera button. The first time, the app explains what is sent and asks for permission ("Allow and continue"). Then hold the printed pills in your hand under the camera; the photo is taken automatically once the picture is steady.
4. The app circles every pill it found and asks "Is that all of them?". Tap Yes to see, pill by pill: Take now / Don't take now / Unknown.
You can also add your own medication: My Medications > "Add a medication", and photograph any tablet.

DATA AND THIRD-PARTY AI (5.1.1, 5.1.2)
- The medication list and pill photos stay on the device; there is no account, analytics or tracking.
- Only after explicit consent (asked before the first scan, and revocable in My Medications > About & privacy), crops of the pills in the photo, plus the user's medication names and reference pill photos, are sent to our server, which forwards them to OpenAI for recognition and keeps nothing. OpenAI does not train on API data and may keep it for up to 30 days to detect abuse. This is disclosed in the consent sheet, the About page and the privacy policy.
- Nothing is saved to the photo library.

The recognition server is live. Results take a few seconds and need an internet connection; without one the app says "Couldn't check. Try again" and never shows a result it didn't check.
```

---

## 8. Submit

1. Optional but recommended: TestFlight → Internal Testing → add yourself → install it
   on your phone through the TestFlight app and do one real scan. This proves the
   Release build has `Secrets.plist`.
2. On the 1.0 page: **Add for Review** → **Submit to App Review**.
3. Choose **manual release**, so you decide when it goes live after approval.
4. Review usually takes 1–3 days. If it's rejected, reply in App Review's Resolution
   Center; most medical-app questions get answered by pointing to the disclaimer, the
   consent sheet and the notes above.

---

## 9. Likely questions from App Review, and answers

| They may ask | Answer |
|---|---|
| "Does the app give medical advice?" (1.4.1) | No. It compares pills with the user's own list and schedule, as they entered them. It says "not medical advice" on every result and on the About page, and refers the user to their pharmacist for anything late or unknown. |
| "Is AI data sharing disclosed and consented?" (5.1.2(i)) | Yes. A sheet before the first scan names what is sent, to whom (our server, then OpenAI) and what is kept. Nothing is sent without "Allow". It can be switched off in About & privacy. |
| "The app looks like a demo." (2.2 / 4.2) | The list starts empty. Users add their own medications with their own pill photos; the sample list is only for trying the app. |
| "Where does the privacy policy say X?" | `/privacy` on the server, also linked in the app (About & privacy, and the consent sheet). |

---

## 10. Risks to keep in mind

- **Regulation:** software that tells a patient whether to take a medication can be a
  regulated medical device:
  - Health Canada: SaMD.
  - US: FDA "device software functions".
  - EU: MDR.

  Before a public release, ask your course or university whether this prototype should
  stay in TestFlight, as a closed beta of up to 10,000 testers that needs only a short
  beta review. That is the lower-risk way to put it in people's hands.
- **Accuracy:** recognition can be wrong. The app asks before every check whether all
  pills were found, never shows a check that didn't happen, and treats anything uncertain
  as "Unknown". Still, keep the wording "double-check" everywhere.
- **Cost:** keep the OpenAI budget limit on. The server also limits each address to 20
  checks a minute.
