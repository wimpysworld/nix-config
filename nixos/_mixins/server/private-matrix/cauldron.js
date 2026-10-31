(() => {
  const HISTORY_LIMIT = 14;
  const REFRESH_INTERVAL_SEC = 15;
  const history = {
    versions: [],
    daemon: [],
    login: [],
    wkClient: [],
    wkSupport: [],
    lockdown: [],
  };

  let countdown = REFRESH_INTERVAL_SEC;
  let isProbing = false;

  const el = (id) => document.querySelector("#" + id);

  function setBadge(node, state, text) {
    if (!node) return;
    let roleClass = "badge-info";
    if (state === "ok") roleClass = "badge-success";
    else if (state === "warn") roleClass = "badge-warning";
    else if (state === "err") roleClass = "badge-error";
    node.className = "badge " + roleClass;
    node.textContent = text;
  }

  function renderSparkline(containerId, samples) {
    const container = el(containerId);
    if (!container) return;
    const max = Math.max(...samples, 25);
    container.replaceChildren();
    for (const ms of samples) {
      const bar = document.createElement("span");
      bar.className = "sparkline-bar";
      const pct = Math.max(14, Math.min(100, Math.round((ms / max) * 100)));
      bar.style.height = pct + "%";
      bar.title = ms.toFixed(1) + " ms";
      container.append(bar);
    }
  }

  function pushSample(key, sparkId, rttId, ms) {
    const arr = history[key];
    arr.push(ms);
    if (arr.length > HISTORY_LIMIT) arr.shift();
    const rttNode = el(rttId);
    if (rttNode) rttNode.textContent = ms.toFixed(1) + "\u00A0ms";
    renderSparkline(sparkId, arr);
  }

  async function timedFetch(url) {
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 10000);
    const t0 = performance.now();
    try {
      const response = await fetch(url, {
        method: "GET",
        headers: { Accept: "application/json" },
        cache: "no-store",
        signal: controller.signal,
      });
      const rtt = performance.now() - t0;
      let data = null;
      try {
        data = await response.json();
      } catch (err) {
        if (controller.signal.aborted) throw err;
        data = null;
      }
      return { response, data, rtt };
    } finally {
      clearTimeout(timer);
    }
  }

  async function probeVersions() {
    try {
      const { response, data, rtt } = await timedFetch("/_matrix/client/versions");
      pushSample("versions", "spark-versions", "rtt-versions", rtt);
      if (!response.ok || !data) {
        setBadge(el("status-versions"), "err", "HTTP " + response.status);
        return { ok: false, rtt };
      }
      const serverInfo = data["net.zemos.msc4383.server"] || {};
      const serverName = serverInfo.name || "Tuwunel";
      const serverVer = serverInfo.version || "-";
      const compiler = serverInfo.compiler || "rustc";
      const versions = Array.isArray(data.versions) ? data.versions : [];
      const highestSpec = versions.length ? versions.at(-1) : "-";
      const features =
        data.unstable_features && typeof data.unstable_features === "object"
          ? Object.entries(data.unstable_features)
          : [];
      const enabledFeatures = features.filter(([, enabled]) => Boolean(enabled));

      el("val-server-name").textContent = serverName;
      el("val-server-ver").textContent = serverVer;
      el("val-compiler").textContent = compiler;
      el("val-max-spec").textContent = highestSpec;
      el("val-spec-count").textContent = versions.length + " versions";
      el("val-msc-count").textContent =
        enabledFeatures.length + " enabled / " + features.length + " total";
      el("summary-msc-total").textContent =
        versions.length + " specs - " + enabledFeatures.length + " MSCs";

      const specContainer = el("spec-version-tags");
      if (specContainer && versions.length) {
        specContainer.replaceChildren();
        for (const v of versions) {
          const b = document.createElement("span");
          b.className = "badge badge-outline badge-primary badge-sm";
          b.textContent = v;
          specContainer.append(b);
        }
      }

      const mscContainer = el("msc-feature-tags");
      if (mscContainer && enabledFeatures.length) {
        mscContainer.replaceChildren();
        for (const [feature] of enabledFeatures) {
          const b = document.createElement("span");
          b.className = "badge badge-outline badge-info badge-sm";
          b.textContent = feature;
          mscContainer.append(b);
        }
      }

      setBadge(el("status-versions"), "ok", highestSpec + " OK");
      return { ok: true, rtt };
    } catch {
      setBadge(el("status-versions"), "err", "UNREACHABLE");
      return { ok: false, rtt: null };
    }
  }

  async function probeDaemon() {
    try {
      const { response, data, rtt } = await timedFetch("/_tuwunel/server_version");
      pushSample("daemon", "spark-daemon", "rtt-daemon", rtt);
      const srv = (data && data.server) || data;
      if (!response.ok || !srv || (!srv.name && !srv.version)) {
        setBadge(el("status-daemon"), "err", "HTTP " + response.status);
        return { ok: false, rtt };
      }
      el("val-daemon-name").textContent = srv.name || "Tuwunel";
      el("val-daemon-version").textContent = srv.version || "-";
      setBadge(el("status-daemon"), "ok", srv.version || "ACTIVE");
      return { ok: true, rtt };
    } catch {
      setBadge(el("status-daemon"), "err", "UNREACHABLE");
      return { ok: false, rtt: null };
    }
  }

  async function probeLogin() {
    try {
      const { response, data, rtt } = await timedFetch("/_matrix/client/v3/login");
      pushSample("login", "spark-login", "rtt-login", rtt);
      if (!response.ok || !data || !Array.isArray(data.flows)) {
        setBadge(el("status-login"), "err", "HTTP " + response.status);
        return { ok: false, rtt };
      }
      const flows = data.flows.map((f) => f.type).filter(Boolean);
      el("val-login-count").textContent = flows.length + " active";
      const container = el("val-login-flows");
      if (container) {
        container.replaceChildren();
        for (const flow of flows) {
          const span = document.createElement("span");
          span.className = "badge badge-outline badge-accent badge-sm";
          span.textContent = flow;
          container.append(span);
        }
      }
      setBadge(el("status-login"), "ok", flows.length + " FLOWS");
      return { ok: true, rtt };
    } catch {
      setBadge(el("status-login"), "err", "UNREACHABLE");
      return { ok: false, rtt: null };
    }
  }

  async function probeWellKnownClient() {
    try {
      const { response, data, rtt } = await timedFetch("/.well-known/matrix/client");
      pushSample("wkClient", "spark-wk-client", "rtt-wk-client", rtt);
      const baseUrl = data && data["m.homeserver"] && data["m.homeserver"].base_url;
      if (!response.ok || !baseUrl) {
        setBadge(el("status-wk-client"), "err", "HTTP " + response.status);
        return { ok: false, rtt };
      }
      el("val-wk-homeserver").textContent = baseUrl;
      el("val-wk-state").textContent = "Verified (HTTP 200)";
      setBadge(el("status-wk-client"), "ok", "DISCOVERABLE");
      return { ok: true, rtt };
    } catch {
      setBadge(el("status-wk-client"), "err", "UNREACHABLE");
      return { ok: false, rtt: null };
    }
  }

  async function probeWellKnownSupport() {
    try {
      const { response, data, rtt } = await timedFetch("/.well-known/matrix/support");
      pushSample("wkSupport", "spark-wk-support", "rtt-wk-support", rtt);
      if (!response.ok || !data) {
        setBadge(el("status-wk-support"), "err", "HTTP " + response.status);
        return { ok: false, rtt };
      }
      const contact =
        Array.isArray(data.contacts) && data.contacts[0] ? data.contacts[0] : {};
      if (contact.matrix_id) el("val-support-mxid").textContent = contact.matrix_id;
      if (contact.email_address) {
        const mailLink = document.createElement("a");
        mailLink.href = "mailto:" + contact.email_address;
        mailLink.textContent = contact.email_address;
        const emailCell = el("val-support-email");
        if (emailCell) emailCell.replaceChildren(mailLink);
      }
      if (contact.role) el("val-support-role").textContent = contact.role;
      if (data.support_page) {
        const link = document.createElement("a");
        link.href = data.support_page;
        link.rel = "noopener noreferrer";
        link.textContent = data.support_page.replace(/^https?:\/\//, "");
        const cell = el("val-support-page");
        cell.replaceChildren(link);
      }
      setBadge(el("status-wk-support"), "ok", "MSC1929 OK");
      return { ok: true, rtt };
    } catch {
      setBadge(el("status-wk-support"), "err", "UNREACHABLE");
      return { ok: false, rtt: null };
    }
  }

  async function probeLockdown() {
    const tableBadge = el("table-lockdown-badge");
    setBadge(tableBadge, "warn", "PROBING...");
    try {
      const { response, rtt } = await timedFetch("/_matrix/federation/v1/version");
      pushSample("lockdown", "spark-lockdown", "rtt-lockdown", rtt);
      el("val-lockdown-http").textContent = "HTTP " + response.status;
      if (response.status === 403) {
        el("val-lockdown-verdict").textContent = "VERIFIED LOCKDOWN (403)";
        setBadge(el("status-lockdown"), "ok", "VERIFIED LOCKDOWN");
        setBadge(tableBadge, "ok", "VERIFIED LOCKDOWN (403)");
        return { ok: true, rtt };
      }
      el("val-lockdown-verdict").textContent = "Unexpected HTTP " + response.status;
      setBadge(el("status-lockdown"), "warn", "HTTP " + response.status);
      setBadge(tableBadge, "err", "EXPOSED (HTTP " + response.status + ")");
      return { ok: false, rtt };
    } catch {
      setBadge(el("status-lockdown"), "err", "UNREACHABLE");
      setBadge(tableBadge, "err", "UNVERIFIED (UNREACHABLE)");
      return { ok: false, rtt: null };
    }
  }

  async function runAllProbes() {
    if (isProbing) return;
    isProbing = true;
    const btn = el("probe-now-btn");
    if (btn) btn.disabled = true;

    const results = await Promise.all([
      probeVersions(),
      probeDaemon(),
      probeLogin(),
      probeWellKnownClient(),
      probeWellKnownSupport(),
      probeLockdown(),
    ]);

    const passed = results.filter((r) => r.ok).length;
    const validRtts = results.map((r) => r.rtt).filter((v) => typeof v === "number");
    const avgRtt = validRtts.length
      ? (validRtts.reduce((a, b) => a + b, 0) / validRtts.length).toFixed(1) + "\u00A0ms"
      : "-";

    el("avg-rtt-val").textContent = avgRtt;
    el("last-checked-val").textContent = new Intl.DateTimeFormat("en-GB", {
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
    }).format(new Date());

    const summaryBadge = el("probe-summary-badge");
    if (summaryBadge) {
      summaryBadge.textContent = passed + " / " + results.length + " passing";
      let summaryRole = "badge-error";
      if (passed === results.length) summaryRole = "badge-success";
      else if (passed > 0) summaryRole = "badge-warning";
      summaryBadge.className = "badge badge-outline tabular " + summaryRole;
    }

    const overallBadge = el("overall-badge");
    const overallText = el("overall-status-text");
    if (overallBadge && overallText) {
      if (passed === results.length) {
        overallBadge.className = "badge badge-lg badge-success";
        overallText.textContent = "ONLINE - 6/6 VERIFIED";
      } else if (passed > 0) {
        overallBadge.className = "badge badge-lg badge-warning";
        overallText.textContent = "DEGRADED - " + passed + "/6 PASSING";
      } else {
        overallBadge.className = "badge badge-lg badge-error";
        overallText.textContent = "OFFLINE - PROBES FAILED";
      }
    }

    countdown = REFRESH_INTERVAL_SEC;
    if (el("countdown-val")) el("countdown-val").textContent = String(countdown);
    if (btn) btn.disabled = false;
    isProbing = false;
  }

  document.addEventListener("DOMContentLoaded", () => {
    const btn = el("probe-now-btn");
    const toggle = el("auto-refresh-toggle");

    if (btn) {
      btn.addEventListener("click", () => {
        runAllProbes();
      });
    }

    runAllProbes();

    setInterval(() => {
      if (!toggle || !toggle.checked || isProbing) return;
      countdown -= 1;
      if (countdown <= 0) {
        runAllProbes();
      } else if (el("countdown-val")) {
        el("countdown-val").textContent = String(countdown);
      }
    }, 1000);
  });
})();
