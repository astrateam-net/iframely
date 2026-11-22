const env = process.env;

const set = (name) => env[name] !== undefined && env[name] !== "";

const string = (name) => (set(name) ? env[name] : undefined);

const number = (name) => {
  if (!set(name)) {
    return undefined;
  }
  const value = Number(env[name]);
  if (!Number.isFinite(value) || value < 0) {
    throw new Error(`${name} must be a non-negative number, got "${env[name]}"`);
  }
  return value;
};

const list = (name) =>
  set(name)
    ? env[name]
        .split(",")
        .map((item) => item.trim())
        .filter(Boolean)
    : undefined;

const defined = (object) => Object.fromEntries(Object.entries(object).filter(([, value]) => value !== undefined));

const scaled = (value, factor) => (value === undefined ? undefined : value * factor);

const providers = defined({
  locale: string("IFRAMELY_LOCALE"),
  google: set("IFRAMELY_GOOGLE_MAPS_KEY") ? { maps_key: env.IFRAMELY_GOOGLE_MAPS_KEY } : undefined,
  youtube: set("IFRAMELY_YOUTUBE_API_KEY") ? { api_key: env.IFRAMELY_YOUTUBE_API_KEY } : undefined,
});

export default defined({
  baseAppUrl: string("IFRAMELY_BASE_URL"),
  allowedOrigins: list("IFRAMELY_ALLOWED_ORIGINS"),

  POWERED_BY: string("IFRAMELY_POWERED_BY") ?? "Astra Team",
  HOME_URL: string("IFRAMELY_HOME_URL") ?? "https://astrateam.net",

  CLUSTER_WORKERS_COUNT: number("IFRAMELY_WORKERS_COUNT") ?? 2,
  CLUSTER_WORKER_RESTART_ON_MEMORY_USED: scaled(number("IFRAMELY_WORKER_MAX_MEMORY_MB"), 1024 * 1024),
  CLUSTER_WORKER_RESTART_ON_PERIOD: scaled(number("IFRAMELY_WORKER_RESTART_PERIOD_SEC"), 1000),

  // Empty disables the hourly fetch; the allowlist then comes only from files in whitelist/.
  WHITELIST_URL: env.IFRAMELY_WHITELIST_URL,

  CACHE_ENGINE: string("IFRAMELY_CACHE_ENGINE"),
  CACHE_TTL: number("IFRAMELY_CACHE_TTL"),
  REDIS_OPTIONS: set("IFRAMELY_REDIS_URL") ? { url: env.IFRAMELY_REDIS_URL } : undefined,
  MEMCACHED_OPTIONS: set("IFRAMELY_MEMCACHED_LOCATIONS")
    ? { locations: list("IFRAMELY_MEMCACHED_LOCATIONS") }
    : undefined,

  // config.js merges this key shallowly, so its own defaults are repeated here.
  providerOptions:
    Object.keys(providers).length > 0 ? { readability: {}, "twitter.status": {}, ...providers } : undefined,
});
