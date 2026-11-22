import { assert } from "chai";
import request from "supertest";
import app from "../app.js";

describe("X-Powered-By and the root redirect", () => {
  afterEach(() => {
    delete CONFIG.POWERED_BY;
    delete CONFIG.HOME_URL;
  });

  it("sends the configured X-Powered-By", async () => {
    CONFIG.POWERED_BY = "Astra Team";
    const res = await request(app).get("/");
    assert.strictEqual(res.headers["x-powered-by"], "Astra Team");
  });

  it("redirects / to the configured home URL", async () => {
    CONFIG.HOME_URL = "https://astrateam.net";
    const res = await request(app).get("/");
    assert.strictEqual(res.status, 302);
    assert.strictEqual(res.headers.location, "https://astrateam.net");
  });

  it("keeps the upstream values when neither key is set", async () => {
    const res = await request(app).get("/");
    assert.strictEqual(res.headers["x-powered-by"], "Iframely");
    assert.strictEqual(res.headers.location, "http://iframely.com");
  });
});
