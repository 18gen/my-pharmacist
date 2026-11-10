import { describe, expect, it } from "vitest";
import { checkReply, limits, openAIRequest, parseCheckRequest, ReplyError, RequestError, sameSecret } from "../src/check";

const jpeg = "/9j/4AAQSkZJRgABAQ==";
const png = "iVBORw0KGgoAAAANSUhEUg==";

function request(overrides: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    pills: [jpeg, jpeg],
    overview: jpeg,
    candidates: [
      { id: "capecitabine-500", description: "Capecitabine 500 mg", photos: [png, png] },
      { id: "ondansetron-8", description: "Ondansetron 8 mg", photos: [png] },
    ],
    ...overrides,
  };
}

describe("parseCheckRequest", () => {
  it("accepts a well-formed request", () => {
    const parsed = parseCheckRequest(request());
    expect(parsed.pills).toHaveLength(2);
    expect(parsed.overview).toBe(jpeg);
    expect(parsed.candidates.map((candidate) => candidate.id)).toEqual(["capecitabine-500", "ondansetron-8"]);
  });

  it("allows no overview and no candidates", () => {
    expect(parseCheckRequest(request({ overview: null, candidates: [] })).overview).toBeNull();
  });

  it.each([
    ["no pills", { pills: [] }],
    ["too many pills", { pills: Array(limits.pills + 1).fill(jpeg) }],
    ["a pill that isn't base64", { pills: ["not base64!"] }],
    ["a huge image", { pills: ["A".repeat(limits.imageLength + 4)] }],
    ["too many candidates", { candidates: Array(limits.candidates + 1).fill({ id: "x", description: "", photos: [] }) }],
    ["a candidate called none", { candidates: [{ id: "none", description: "", photos: [] }] }],
    ["the same id twice", { candidates: [{ id: "a", description: "", photos: [] }, { id: "a", description: "", photos: [] }] }],
    ["too many photos", { candidates: [{ id: "a", description: "", photos: Array(limits.photosPerCandidate + 1).fill(png) }] }],
  ])("rejects %s", (_, overrides) => {
    expect(() => parseCheckRequest(request(overrides))).toThrow(RequestError);
  });

  it("rejects anything but an object", () => {
    expect(() => parseCheckRequest([])).toThrow(RequestError);
    expect(() => parseCheckRequest(null)).toThrow(RequestError);
  });
});

describe("openAIRequest", () => {
  const body = openAIRequest(parseCheckRequest(request()), "gpt-test") as {
    model: string;
    store: boolean;
    input: { content: { type: string; image_url?: string; detail?: string }[] }[];
    text: { format: { strict: boolean; schema: { properties: { pills: { items: { properties: { medication_id: { enum: string[] } } } } } } } };
  };

  it("keeps nothing and allows only the candidates or none", () => {
    expect(body.model).toBe("gpt-test");
    expect(body.store).toBe(false);
    expect(body.text.format.strict).toBe(true);
    expect(body.text.format.schema.properties.pills.items.properties.medication_id.enum).toEqual([
      "capecitabine-500",
      "ondansetron-8",
      "none",
    ]);
  });

  it("sends every picture at high detail, with its type", () => {
    const images = (body.input[0]?.content ?? []).filter((part) => part.type === "input_image");
    // Three reference photos, two pills and the overview.
    expect(images).toHaveLength(6);
    expect(images.every((part) => part.detail === "high")).toBe(true);
    expect(images[0]?.image_url?.startsWith("data:image/png;base64,")).toBe(true);
    expect(images[3]?.image_url?.startsWith("data:image/jpeg;base64,")).toBe(true);
  });
});

describe("checkReply", () => {
  function reply(text: string, extra: Record<string, unknown>[] = []): unknown {
    return { output: [{ type: "reasoning" }, { type: "message", content: [...extra, { type: "output_text", text }] }] };
  }

  it("reads the answer", () => {
    const answer = {
      pills: [{ pill: 1, shows_one_whole_pill: true, imprint: "XELODA", medication_id: "capecitabine-500", confidence: "high" }],
      unnumbered_pill_like_objects: 0,
    };
    expect(checkReply(reply(JSON.stringify(answer)))).toEqual(answer);
  });

  it("rejects a refusal, text that isn't JSON, or the wrong shape", () => {
    expect(() => checkReply(reply("{}", [{ type: "refusal", refusal: "no" }]))).toThrow(ReplyError);
    expect(() => checkReply(reply("not json"))).toThrow(ReplyError);
    expect(() => checkReply(reply(JSON.stringify({ pills: [{ pill: 1 }], unnumbered_pill_like_objects: 0 })))).toThrow(ReplyError);
    expect(() => checkReply({})).toThrow(ReplyError);
  });
});

describe("sameSecret", () => {
  it("matches only the same, non-empty secret", () => {
    expect(sameSecret("abc", "abc")).toBe(true);
    expect(sameSecret("abd", "abc")).toBe(false);
    expect(sameSecret("ab", "abc")).toBe(false);
    expect(sameSecret("", "")).toBe(false);
  });
});
