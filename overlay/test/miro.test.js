import { assert } from "chai";
import request from "supertest";
import app from "../app.js";

async function embed(url) {
  const res = await request(app).get("/iframely").query({ url, group: "true" });
  assert.strictEqual(res.status, 200, JSON.stringify(res.body));
  return res.body;
}

describe("Miro boards", () => {
  it("embeds the live-embed URL from Miro's Embed tab", async () => {
    const body = await embed(
      "https://miro.com/app/live-embed/uXjVELUtCaE=/?embedMode=view_only_without_ui&moveToViewport=4964%2C-806%2C5653%2C3514&embedId=740645711547",
    );
    assert.match(
      body.html,
      /src="https:\/\/miro\.com\/app\/live-embed\/uXjVELUtCaE=\/\?embedMode=view_only_without_ui&amp;moveToViewport=4964%2C-806%2C5653%2C3514&amp;embedId=740645711547"/,
    );
    assert.match(body.html, /allow="fullscreen; clipboard-read; clipboard-write; storage-access"/);
  });

  it("embeds a board URL and keeps its viewport", async () => {
    const body = await embed("https://miro.com/app/board/uXjVELUtCaE=/?moveToViewport=4964,-806,5653,3514");
    assert.include(
      body.html,
      "https://miro.com/app/live-embed/uXjVELUtCaE=/?embedMode=view_only_without_ui&amp;moveToViewport=4964%2C-806%2C5653%2C3514",
    );
  });

  it("decodes a percent-encoded board id", async () => {
    const body = await embed("https://miro.com/app/board/uXjVELUtCaE%3D/");
    assert.include(body.html, "https://miro.com/app/live-embed/uXjVELUtCaE=/?embedMode=view_only_without_ui");
  });
});
