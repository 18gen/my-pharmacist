# Pill check server

The small server between the My Pharmacist app and OpenAI. It holds the OpenAI API key,
so the key is never inside the app, and it owns the prompt and the answer's schema, so
it can't be used as a general OpenAI proxy. It runs on Cloudflare Workers (the free plan
is enough).

| Path | What |
|---|---|
| `POST /check` | Checks pill pictures against the person's medications. Needs the `X-App-Token` header. |
| `GET /privacy` | The privacy policy (the App Store's Privacy Policy URL). |
| `GET /support` | The support page (the App Store's Support URL). |

It never logs request bodies and keeps nothing. Each network address may make 20 checks
a minute.

## Deploy (once)

1. Create a free Cloudflare account at <https://dash.cloudflare.com/sign-up>.
2. In this folder:
   ```sh
   npm install
   npx wrangler login
   ```
3. Set your support email in `wrangler.jsonc` (`SUPPORT_EMAIL`). It is shown on the
   privacy and support pages.
4. Set the two secrets. For the app token, make up a long random string
   (for example `openssl rand -hex 32`) and keep it: the app needs it too.
   ```sh
   npx wrangler secret put OPENAI_API_KEY
   npx wrangler secret put APP_TOKEN
   ```
5. Deploy:
   ```sh
   npm run deploy
   ```
   Wrangler prints the address, like `https://my-pharmacist-pill-check.<you>.workers.dev`.
6. In the app, put that address and the app token in `MyPharmacist/Resources/Secrets.plist`
   (`PILL_CHECK_URL`, `PILL_CHECK_TOKEN`); see `Secrets.example.plist`.
7. In the OpenAI dashboard, set a monthly budget limit for the project the key belongs to.

## Develop

```sh
npm test          # the request checks, the OpenAI request and reply parsing
npm run typecheck
cp .dev.vars.example .dev.vars   # then fill it in
npm run dev       # runs it on http://localhost:8787
```
