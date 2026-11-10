// The pill check itself: what the app may send, what is asked of OpenAI, and what goes
// back. Pure functions, so they can be tested without the network.

/** A medication the pills are compared with: its id, a line about it, and photos. */
export interface Candidate {
  id: string;
  description: string;
  /** JPEG or PNG images, base64. */
  photos: string[];
}

/** What the app sends: each pill's picture and all of them together, numbered. */
export interface CheckRequest {
  pills: string[];
  overview: string | null;
  candidates: Candidate[];
}

/** The model's answer for one pill. */
export interface PillAnswer {
  pill: number;
  shows_one_whole_pill: boolean;
  imprint: string;
  medication_id: string;
  confidence: "high" | "medium" | "low";
}

/** What goes back to the app. */
export interface CheckReply {
  pills: PillAnswer[];
  unnumbered_pill_like_objects: number;
}

export const limits = {
  pills: 12,
  candidates: 20,
  photosPerCandidate: 4,
  /** Base64 characters per image: about 600 KB. */
  imageLength: 800_000,
  /** Base64 characters in one request: about 8 MB. */
  totalLength: 11_000_000,
  idLength: 100,
  descriptionLength: 300,
} as const;

export class RequestError extends Error {}

const base64 = /^[A-Za-z0-9+/]+={0,2}$/;

function isRecord(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

function image(value: unknown, what: string): string {
  if (typeof value !== "string" || value.length === 0 || value.length > limits.imageLength || !base64.test(value)) {
    throw new RequestError(`${what} must be a base64 image of at most ${limits.imageLength} characters`);
  }
  return value;
}

function text(value: unknown, what: string, maxLength: number): string {
  if (typeof value !== "string" || value.length > maxLength) {
    throw new RequestError(`${what} must be text of at most ${maxLength} characters`);
  }
  return value;
}

/** Checks what the app sent, and throws `RequestError` with the reason if it's wrong. */
export function parseCheckRequest(body: unknown): CheckRequest {
  if (!isRecord(body)) throw new RequestError("The request must be a JSON object");
  const { pills, overview, candidates } = body;
  if (!Array.isArray(pills) || pills.length === 0 || pills.length > limits.pills) {
    throw new RequestError(`pills must hold 1 to ${limits.pills} images`);
  }
  if (!Array.isArray(candidates) || candidates.length > limits.candidates) {
    throw new RequestError(`candidates must hold at most ${limits.candidates} medications`);
  }
  const parsed: CheckRequest = {
    pills: pills.map((pill, index) => image(pill, `pills[${index}]`)),
    overview: overview === null || overview === undefined ? null : image(overview, "overview"),
    candidates: candidates.map((candidate, index): Candidate => {
      if (!isRecord(candidate)) throw new RequestError(`candidates[${index}] must be an object`);
      const id = text(candidate.id, `candidates[${index}].id`, limits.idLength);
      if (id.length === 0 || id === "none") throw new RequestError(`candidates[${index}].id can't be empty or "none"`);
      const photos = candidate.photos;
      if (!Array.isArray(photos) || photos.length > limits.photosPerCandidate) {
        throw new RequestError(`candidates[${index}].photos must hold at most ${limits.photosPerCandidate} images`);
      }
      return {
        id,
        description: text(candidate.description, `candidates[${index}].description`, limits.descriptionLength),
        photos: photos.map((photo, photoIndex) => image(photo, `candidates[${index}].photos[${photoIndex}]`)),
      };
    }),
  };
  const ids = new Set(parsed.candidates.map((candidate) => candidate.id));
  if (ids.size !== parsed.candidates.length) throw new RequestError("Candidate ids must be different");
  const total =
    parsed.pills.reduce((sum, pill) => sum + pill.length, 0) +
    (parsed.overview?.length ?? 0) +
    parsed.candidates.reduce((sum, candidate) => sum + candidate.photos.reduce((s, photo) => s + photo.length, 0), 0);
  if (total > limits.totalLength) throw new RequestError("The request's images are too large together");
  return parsed;
}

export const instructions = [
  "You check pills for a medication safety app used by older people.",
  "Each numbered pill photo was cut from a phone photo of pills in a hand or on a surface; it may also be a printed picture of a pill.",
  "The pill to judge is in the middle at full brightness; everything around it is dimmed and is not part of it.",
  "Long pills have been turned to lie flat, so an imprint may be upside down. Small photos have been enlarged.",
  "Compare each pill with the candidate medications' reference photos, which show both sides.",
  "Match on shape, colour and the imprint (letters or numbers pressed into or printed on the pill).",
  "Give a candidate's ID only when the pill clearly is that medication.",
  'If the imprint you can read contradicts it, if no candidate fits, or if you are unsure, answer "none".',
  "Report the imprint you can read, or an empty string.",
  'Confidence is "high" only when shape, colour and any visible imprint all agree, "medium" when they agree but the imprint can\'t be read, otherwise "low".',
  "Set shows_one_whole_pill to false when the bright middle of a photo shows no pill, only part of a pill, or more than one pill.",
  "The last picture shows all the pills together, each in a box with its number beside it.",
  "Count in unnumbered_pill_like_objects the things in it that look like a pill or capsule but have no box and number; 0 if there are none or there is no such picture.",
].join(" ");

type Content = { type: "input_text"; text: string } | { type: "input_image"; image_url: string; detail: "high" };

function textPart(value: string): Content {
  return { type: "input_text", text: value };
}

function imagePart(data: string): Content {
  // PNG starts "iVBOR" in base64; everything else the app sends is JPEG.
  const type = data.startsWith("iVBOR") ? "image/png" : "image/jpeg";
  return { type: "input_image", image_url: `data:${type};base64,${data}`, detail: "high" };
}

/** The OpenAI Responses API request: the candidates with their photos, the pills, and a
 * strict schema whose medication_id can only be a candidate's id or "none". Nothing is
 * stored by OpenAI's application state (`store: false`). */
export function openAIRequest(request: CheckRequest, model: string): Record<string, unknown> {
  const content: Content[] = [textPart("Candidate medications, each with its reference photos:")];
  for (const candidate of request.candidates) {
    content.push(textPart(`Candidate ${candidate.id}: ${candidate.description}`));
    content.push(...candidate.photos.map(imagePart));
  }
  content.push(textPart(`Pills to identify (${request.pills.length}):`));
  request.pills.forEach((pill, index) => {
    content.push(textPart(`Pill ${index + 1}:`));
    content.push(imagePart(pill));
  });
  if (request.overview !== null) {
    content.push(textPart("All the pills together, numbered as above:"));
    content.push(imagePart(request.overview));
  }
  return {
    model,
    store: false,
    instructions,
    input: [{ role: "user", content }],
    text: {
      format: {
        type: "json_schema",
        name: "pill_identification",
        strict: true,
        schema: {
          type: "object",
          properties: {
            pills: {
              type: "array",
              items: {
                type: "object",
                properties: {
                  pill: { type: "integer" },
                  shows_one_whole_pill: { type: "boolean" },
                  imprint: { type: "string" },
                  medication_id: { type: "string", enum: [...request.candidates.map((candidate) => candidate.id), "none"] },
                  confidence: { type: "string", enum: ["high", "medium", "low"] },
                },
                required: ["pill", "shows_one_whole_pill", "imprint", "medication_id", "confidence"],
                additionalProperties: false,
              },
            },
            unnumbered_pill_like_objects: { type: "integer" },
          },
          required: ["pills", "unnumbered_pill_like_objects"],
          additionalProperties: false,
        },
      },
    },
  };
}

export class ReplyError extends Error {}

function isAnswer(value: unknown): value is PillAnswer {
  return (
    isRecord(value) &&
    typeof value.pill === "number" &&
    typeof value.shows_one_whole_pill === "boolean" &&
    typeof value.imprint === "string" &&
    typeof value.medication_id === "string" &&
    (value.confidence === "high" || value.confidence === "medium" || value.confidence === "low")
  );
}

/** The answer in an OpenAI Responses API reply: its first output text, as JSON in the
 * schema's shape. Throws `ReplyError` for a refusal or anything else. */
export function checkReply(openAIReply: unknown): CheckReply {
  if (!isRecord(openAIReply) || !Array.isArray(openAIReply.output)) throw new ReplyError("Unexpected reply");
  const parts = openAIReply.output
    .filter((item): item is Record<string, unknown> => isRecord(item) && item.type === "message")
    .flatMap((message) => (Array.isArray(message.content) ? message.content : []))
    .filter(isRecord);
  if (parts.some((part) => part.type === "refusal")) throw new ReplyError("The model refused");
  const output = parts.find((part) => part.type === "output_text");
  if (output === undefined || typeof output.text !== "string") throw new ReplyError("No output text");
  let answer: unknown;
  try {
    answer = JSON.parse(output.text);
  } catch {
    throw new ReplyError("The output isn't JSON");
  }
  if (
    !isRecord(answer) ||
    !Array.isArray(answer.pills) ||
    !answer.pills.every(isAnswer) ||
    typeof answer.unnumbered_pill_like_objects !== "number"
  ) {
    throw new ReplyError("The output isn't in the expected shape");
  }
  return { pills: answer.pills, unnumbered_pill_like_objects: answer.unnumbered_pill_like_objects };
}

/** Compares two strings in time that doesn't depend on where they differ. */
export function sameSecret(given: string, expected: string): boolean {
  const encoder = new TextEncoder();
  const a = encoder.encode(given);
  const b = encoder.encode(expected);
  let difference = a.length ^ b.length;
  for (let index = 0; index < Math.max(a.length, b.length); index += 1) {
    difference |= (a[index] ?? 0) ^ (b[index] ?? 0);
  }
  return difference === 0 && expected.length > 0;
}
