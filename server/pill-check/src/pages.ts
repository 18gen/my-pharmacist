// The public pages App Store Connect links to: the privacy policy and support.

function escape(value: string): string {
  return value.replace(/[&<>"']/g, (character) => `&#${character.charCodeAt(0)};`);
}

function page(title: string, body: string): Response {
  const html = `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escape(title)} – My Pharmacist</title>
<style>
  body { font: 18px/1.55 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; color: #111; background: #fff;
         max-width: 680px; margin: 0 auto; padding: 24px 16px 48px; }
  h1 { font-size: 30px; margin: 8px 0 4px; }
  h2 { font-size: 21px; margin-top: 28px; }
  p, li { color: #333; }
  .muted { color: #666; font-size: 15px; }
  a { color: #0066d9; }
</style>
</head>
<body>
${body}
</body>
</html>`;
  return new Response(html, { headers: { "content-type": "text/html; charset=utf-8", "cache-control": "public, max-age=3600" } });
}

export function privacyPage(supportEmail: string): Response {
  const email = escape(supportEmail);
  return page(
    "Privacy Policy",
    `<h1>Privacy Policy</h1>
<p class="muted">My Pharmacist · Effective 1 December 2026</p>

<p>My Pharmacist helps you double-check the pills in your hand against your own list of medications before you take them. This policy explains what the app keeps, what it sends, and why.</p>

<h2>What stays on your phone</h2>
<p>Your medication list (names, strengths, what each is for, when you take it), the photos you take of each pill, and the times you scanned your doses are stored only on your phone, in the app's own storage. They are not put in your photo library, and we don't receive them unless you check pills as described below. Deleting a medication deletes its photos; deleting the app deletes everything.</p>

<h2>What is sent when you check pills</h2>
<p>Only after you allow it in the app, each time you check pills the app sends, over an encrypted connection:</p>
<ul>
  <li>pictures of the pills found in the photo you just took, each cut out on its own, and one picture of them together;</li>
  <li>for each medication on your list: its name, strength, what it's for, a short description of how it looks, and the photos of its pill.</li>
</ul>
<p>The full photo from the camera is not sent. Nothing that identifies you (such as your name, email or contacts) is sent, and the app has no accounts.</p>
<p>These go to our server (run on Cloudflare Workers), which passes them to OpenAI to recognize which of your medications each pill is, and sends the answer back to your phone. Our server does not store them. Cloudflare keeps standard technical logs of requests (such as the time and network address) to run and protect the service, not their contents.</p>
<p>OpenAI processes them under its API terms: it does not use them to train its models, and it may keep them for up to 30 days to detect abuse before deleting them. We ask OpenAI not to store them as application state (the API's <code>store: false</code> setting).</p>

<h2>What we don't do</h2>
<p>No advertising, no tracking, no analytics, and we never sell or share your information for any other purpose. Anyone we share data with for checking pills (Cloudflare and OpenAI, as above) protects it at least as this policy does.</p>

<h2>Your choices</h2>
<ul>
  <li>Turn off sending pictures in the app: My Medications › About &amp; privacy. Pills can't be checked while it's off.</li>
  <li>Delete a medication and its photos, or delete the app to remove everything from your phone.</li>
  <li>To ask about or delete anything else, email <a href="mailto:${email}">${email}</a>.</li>
</ul>

<h2>Children</h2>
<p>The app is not directed to children under 13 and we don't knowingly collect their information.</p>

<h2>Not medical advice</h2>
<p>My Pharmacist is a double-check, not medical advice, and it can be wrong. Always follow your pharmacist's or doctor's instructions, and ask them if you are unsure about a pill.</p>

<h2>Changes and contact</h2>
<p>If this policy changes, the new version will be posted here with a new date. Questions: <a href="mailto:${email}">${email}</a>.</p>`
  );
}

export function supportPage(supportEmail: string): Response {
  const email = escape(supportEmail);
  return page(
    "Support",
    `<h1>My Pharmacist Support</h1>
<p>My Pharmacist checks the pills in your hand against your own medication list before you take them, and tells you which to take now.</p>

<h2>Getting started</h2>
<ol>
  <li>Open My Medications and add each medication: two photos of its pill (front and back, on a plain surface), its name, and when you take it.</li>
  <li>When it's time, tap Scan Pills, hold the pills in an open hand or put them on a table, and keep the phone still.</li>
  <li>Check that every pill is circled, then read the result: OK to take, don't take now, or unknown.</li>
</ol>

<h2>Tips</h2>
<ul>
  <li>Spread the pills apart so they don't touch, and keep them in the middle of the picture.</li>
  <li>Use good light; tap Light at the bottom of the camera if it's dark.</li>
  <li>If a pill shows as unknown, check its photos in My Medications, and ask your pharmacist.</li>
</ul>

<h2>Important</h2>
<p>My Pharmacist is a double-check, not medical advice, and it can be wrong. Always follow your pharmacist's or doctor's instructions.</p>

<h2>Contact</h2>
<p>Email <a href="mailto:${email}">${email}</a>. See also the <a href="/privacy">privacy policy</a>.</p>`
  );
}
