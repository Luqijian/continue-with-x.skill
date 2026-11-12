import { describe, expect, it } from "vitest";
import { slugify } from "../src/slugify.js";

describe("slugify", () => {
  it("lowercases and hyphenates", () => {
    expect(slugify("Hello World Again")).toBe("hello-world-again");
  });

  it("strips punctuation", () => {
    expect(slugify("Hello, World!")).toBe("hello-world");
  });
});
