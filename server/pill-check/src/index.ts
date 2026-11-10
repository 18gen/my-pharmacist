// The server between the My Pharmacist app and OpenAI.
//   POST /check   checks pill pictures against the person's medications (needs X-App-Token)
//   GET  /privacy the privacy policy
//   GET  /support the support page

import { checkReply, openAIRequest, parseCheckRequest, ReplyError, RequestError, sameSecret } from "./check";
import { privacyPage, supportPage } from "./pages";

export interface Env {
  OPENAI_API_KEY: string;
  APP_TOKEN: string;
  OPENAI_MODEL: string;
  SUPPORT_EMAIL: string;
  CHECK_LIMITER: RateLimit;
}

/** How long OpenAI may take; the app waits a little longer. */
const openAITimeout = 25_000;

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), { status, headers: { "content-type": "application/json" } });
}

function failure(status: number, message: string): Response {
  return json({ error: message }, status);
}

async function check(request: Request, env: Env): Promise<Response> {
  if (!sameSecret(request.headers.get("X-App-Token") ?? "", env.APP_TOKEN)) {
    return failure(401, "Not allowed");
  }
  const address = request.headers.get("CF-Connecting-IP") ?? "unknown";
  const { success } = await env.CHECK_LIMITER.limit({ key: address });
  if (!success) return failure(429, "Too many checks; try again in a minute");

  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return failure(400, "The request isn't JSON");
  }
  let checkRequest;
  try {
    checkRequest = parseCheckRequest(body);
  } catch (error) {
    if (error instanceof RequestError) return failure(400, error.message);
    throw error;
  }

  let response: Response;
  try {
    response = await fetch("https://api.openai.com/v1/responses", {
      method: "POST",
      headers: { authorization: `Bearer ${env.OPENAI_API_KEY}`, "content-type": "application/json" },
      body: JSON.stringify(openAIRequest(checkRequest, env.OPENAI_MODEL)),
      signal: AbortSignal.timeout(openAITimeout),
    });
  } catch {
    return failure(504, "The pill checker didn't answer in time");
  }
  if (!response.ok) {
    // The status only: OpenAI's error text could echo parts of the request.
    console.error(`OpenAI returned ${response.status}`);
    return failure(502, "The pill checker had a problem");
  }
  try {
    return json(checkReply(await response.json()));
  } catch (error) {
    if (error instanceof ReplyError) {
      console.error(`OpenAI reply unusable: ${error.message}`);
      return failure(502, "The pill checker gave no usable answer");
    }
    throw error;
  }
}

export default {
  async fetch(request, env): Promise<Response> {
    const { pathname } = new URL(request.url);
    if (pathname === "/check") {
      if (request.method !== "POST") return failure(405, "Use POST");
      return check(request, env);
    }
    if (request.method !== "GET" && request.method !== "HEAD") return failure(405, "Use GET");
    if (pathname === "/privacy") return privacyPage(env.SUPPORT_EMAIL);
    if (pathname === "/support" || pathname === "/") return supportPage(env.SUPPORT_EMAIL);
    return failure(404, "Not found");
  },
} satisfies ExportedHandler<Env>;
