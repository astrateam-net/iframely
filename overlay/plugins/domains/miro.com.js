const KEPT_PARAMS = ["embedMode", "moveToViewport", "embedId"];

export default {
  re: /^https?:\/\/(?:www\.)?miro\.com\/app\/(?:board|live-embed|embed)\/([A-Za-z0-9_\-=%]+)\/?(?:\?([^#]*))?/i,

  // No mixins: the live-embed page is robots noindex and has no oEmbed, so nothing is fetched.
  // Iframely's loader reads parameter names from `function (...)` source; an arrow is ignored.
  // biome-ignore lint/complexity/useArrowFunction: see above
  getLink: function (urlMatch) {
    const given = new URLSearchParams(urlMatch[2] || "");
    const params = new URLSearchParams({ embedMode: "view_only_without_ui" });
    for (const name of KEPT_PARAMS) {
      if (given.has(name)) {
        params.set(name, given.get(name));
      }
    }
    return {
      href: `https://miro.com/app/live-embed/${decodeURIComponent(urlMatch[1])}/?${params}`,
      type: CONFIG.T.text_html,
      rel: [CONFIG.R.app, CONFIG.R.iframely, "fullscreen", "clipboard-read", "clipboard-write", "storage-access"],
      "aspect-ratio": 16 / 9,
    };
  },

  // biome-ignore lint/complexity/useArrowFunction: see getLink
  getMeta: function () {
    return { site: "Miro" };
  },
};
