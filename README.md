# My Pharmacist

An iPhone app that double-checks pills before they are taken. The person photographs
the pills in their hand; the app finds each pill, recognizes which of their own
medications it is, and says pill by pill: **take now**, **don't take now**, or
**unknown**.

It is a double-check, not medical advice: it compares pills with the list and times the
person entered.

## How it works

| Step | Where it runs | What happens |
|---|---|---|
| 1. Find and cut out | On the phone | Each pill in the photo is found and cut out as its own picture. |
| 2. Recognize | Server, then OpenAI | Each picture is compared with the person's medications and their photos. |
| 3. Decide | On the phone | The schedule decides take now / don't take now. The recognizer never does. |

[docs/pill-recognition.md](docs/pill-recognition.md) explains the three steps in detail,
in English and Japanese, and how to put a model of your own in step 2.

## Layout

| Folder | What is in it |
|---|---|
| `MyPharmacist/App` | The root view and the routes. |
| `MyPharmacist/Features` | The screens: Home, Scan, Medications, About. |
| `MyPharmacist/Core` | Rules with no UI: models, schedule, picture quality, the geometry that finds pills. |
| `MyPharmacist/PillVision` | Vision, cut-outs, and the `PillRecognizer` that names each pill. |
| `MyPharmacist/Camera` | The camera session and preview. |
| `MyPharmacist/Data` | The medication list, the scan record and photo files, all on the device. |
| `MyPharmacist/DesignSystem` | Colours and shared controls. |
| `MyPharmacistTests` | Unit tests (Swift Testing). |
| `server/pill-check` | The Cloudflare Worker between the app and OpenAI. It holds the OpenAI key. |
| `design/demo-pills` | Printable pills at actual size, for demos. |
| `AppStore` | Everything written for the App Store submission. |

## Run it

1. Open `MyPharmacist.xcodeproj` in Xcode and run the `MyPharmacist` scheme.
2. To check pills, the app needs the server:
   1. Deploy it as [server/pill-check/README.md](server/pill-check/README.md) describes.
   2. Copy `Secrets.example.plist` to `MyPharmacist/Resources/Secrets.plist` and fill in
      the server's address and app token. Git ignores that file.
3. The camera and Vision's subject lifting need a real iPhone. In the Simulator, Debug
   builds take launch arguments instead, listed in
   `MyPharmacist/Features/Scan/DemoScan.swift` (`-demoScan`, `-demoFind -noCloud`, …).

## Test

```sh
# The app
xcodebuild test -project MyPharmacist.xcodeproj -scheme MyPharmacist \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'

# The server
cd server/pill-check && npm install && npm test && npx tsc --noEmit
```

## Privacy

The medication list and pill photos stay on the phone. Only after the person allows it,
pictures of the pills being checked, and the medications' names and pill photos, are sent
to the server and on to OpenAI to be recognized. The server keeps nothing. Nothing is
saved to the photo library.
