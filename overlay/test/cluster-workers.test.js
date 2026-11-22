import { spawn } from "node:child_process";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { assert } from "chai";

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), "..");
const STARTED = /Cluster: worker \d+ started\./g;

// Boots cluster.js with config.local.js and counts the workers it forks.
function countWorkers(vars, settleMs = 3000) {
  return new Promise((done, fail) => {
    const child = spawn(process.execPath, ["cluster.js"], {
      cwd: ROOT,
      env: { ...process.env, NODE_ENV: "local", PORT: "18961", IFRAMELY_WHITELIST_URL: "", ...vars },
      stdio: ["ignore", "pipe", "pipe"],
    });
    let output = "";
    let timer;
    const collect = (chunk) => {
      output += chunk;
      clearTimeout(timer);
      timer = setTimeout(() => child.kill("SIGTERM"), settleMs);
    };
    child.stdout.on("data", collect);
    child.stderr.on("data", collect);
    child.on("error", fail);
    child.on("exit", () => {
      clearTimeout(timer);
      done({ count: (output.match(STARTED) || []).length, output });
    });
  });
}

describe("cluster worker count", function () {
  this.timeout(60000);

  it("forks IFRAMELY_WORKERS_COUNT workers", async () => {
    const { count, output } = await countWorkers({ IFRAMELY_WORKERS_COUNT: "3" });
    assert.strictEqual(count, 3, output);
  });

  it("forks two workers when the variable is unset", async () => {
    const { count, output } = await countWorkers({ IFRAMELY_WORKERS_COUNT: "" });
    assert.strictEqual(count, 2, output);
  });
});
