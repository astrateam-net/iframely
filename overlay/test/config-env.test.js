import { assert } from "chai";

const NAMES = [
  "IFRAMELY_BASE_URL",
  "IFRAMELY_ALLOWED_ORIGINS",
  "IFRAMELY_POWERED_BY",
  "IFRAMELY_HOME_URL",
  "IFRAMELY_WORKERS_COUNT",
  "IFRAMELY_WORKER_MAX_MEMORY_MB",
  "IFRAMELY_WORKER_RESTART_PERIOD_SEC",
  "IFRAMELY_WHITELIST_URL",
  "IFRAMELY_CACHE_ENGINE",
  "IFRAMELY_CACHE_TTL",
  "IFRAMELY_REDIS_URL",
  "IFRAMELY_MEMCACHED_LOCATIONS",
  "IFRAMELY_LOCALE",
  "IFRAMELY_GOOGLE_MAPS_KEY",
  "IFRAMELY_YOUTUBE_API_KEY",
];

let generation = 0;

// Each call re-evaluates config.local.js against the given environment.
async function load(vars) {
  const saved = Object.fromEntries(NAMES.map((name) => [name, process.env[name]]));
  for (const name of NAMES) {
    delete process.env[name];
  }
  Object.assign(process.env, vars);
  try {
    generation += 1;
    return (await import(`../config.local.js?generation=${generation}`)).default;
  } finally {
    for (const name of NAMES) {
      if (saved[name] === undefined) {
        delete process.env[name];
      } else {
        process.env[name] = saved[name];
      }
    }
  }
}

describe("config.local.js", () => {
  it("sets only the branding and worker defaults when no variable is set", async () => {
    const config = await load({});
    assert.deepEqual(config, {
      POWERED_BY: "Astra Team",
      HOME_URL: "https://astrateam.net",
      CLUSTER_WORKERS_COUNT: 2,
    });
  });

  it("maps every variable to its config key", async () => {
    const config = await load({
      IFRAMELY_BASE_URL: "https://embed.example.com",
      IFRAMELY_ALLOWED_ORIGINS: "https://a.example.com, https://b.example.com",
      IFRAMELY_POWERED_BY: "Example",
      IFRAMELY_HOME_URL: "https://example.com",
      IFRAMELY_WORKERS_COUNT: "4",
      IFRAMELY_WORKER_MAX_MEMORY_MB: "300",
      IFRAMELY_WORKER_RESTART_PERIOD_SEC: "3600",
      IFRAMELY_CACHE_ENGINE: "redis",
      IFRAMELY_CACHE_TTL: "86400",
      IFRAMELY_REDIS_URL: "redis://cache:6379/1",
      IFRAMELY_LOCALE: "ru_RU",
      IFRAMELY_GOOGLE_MAPS_KEY: "maps-key",
      IFRAMELY_YOUTUBE_API_KEY: "youtube-key",
    });
    assert.deepEqual(config, {
      baseAppUrl: "https://embed.example.com",
      allowedOrigins: ["https://a.example.com", "https://b.example.com"],
      POWERED_BY: "Example",
      HOME_URL: "https://example.com",
      CLUSTER_WORKERS_COUNT: 4,
      CLUSTER_WORKER_RESTART_ON_MEMORY_USED: 300 * 1024 * 1024,
      CLUSTER_WORKER_RESTART_ON_PERIOD: 3600 * 1000,
      CACHE_ENGINE: "redis",
      CACHE_TTL: 86400,
      REDIS_OPTIONS: { url: "redis://cache:6379/1" },
      providerOptions: {
        readability: {},
        "twitter.status": {},
        locale: "ru_RU",
        google: { maps_key: "maps-key" },
        youtube: { api_key: "youtube-key" },
      },
    });
  });

  it("splits memcached locations", async () => {
    const config = await load({ IFRAMELY_MEMCACHED_LOCATIONS: "m1:11211,m2:11211" });
    assert.deepEqual(config.MEMCACHED_OPTIONS, { locations: ["m1:11211", "m2:11211"] });
  });

  it("keeps the upstream allowlist URL when the variable is unset", async () => {
    const config = await load({});
    assert.notProperty(config, "WHITELIST_URL");
  });

  it("disables the allowlist fetch when the variable is empty", async () => {
    const config = await load({ IFRAMELY_WHITELIST_URL: "" });
    assert.strictEqual(config.WHITELIST_URL, "");
  });

  it("falls back to the defaults for empty branding variables", async () => {
    const config = await load({ IFRAMELY_POWERED_BY: "", IFRAMELY_HOME_URL: "" });
    assert.strictEqual(config.POWERED_BY, "Astra Team");
    assert.strictEqual(config.HOME_URL, "https://astrateam.net");
  });

  it("refuses a worker count that is not a number", async () => {
    let error;
    try {
      await load({ IFRAMELY_WORKERS_COUNT: "many" });
    } catch (caught) {
      error = caught;
    }
    assert.match(error?.message, /IFRAMELY_WORKERS_COUNT must be a non-negative number/);
  });
});
