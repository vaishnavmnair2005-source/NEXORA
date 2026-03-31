/**
 * Nexora MediTwin — MQTT Display Client
 * ======================================
 * Paste this <script> block at the bottom of doctor.html and
 * patient_dashboard.html (before the closing </body> tag).
 *
 * Depends on:
 *   <script src="https://cdnjs.cloudflare.com/ajax/libs/mqtt/5.3.4/mqtt.min.js"></script>
 *   Add that line in the <head> of each HTML file.
 *
 * What it does:
 *   • Connects to the MQTT broker over WebSocket
 *   • Subscribes to the 4 Nexora topics for this patient
 *   • Updates vital display elements WITHOUT flickering:
 *       — shown numbers only change when the new value differs by ≥ threshold
 *       — a smooth CSS transition handles the visual update
 *   • Shows real-time spike alerts as toast notifications
 *   • Renders the 30-minute report in a dedicated modal / section
 *
 * Element IDs expected in the HTML (use existing IDs if they differ):
 *   vital-hr, vital-spo2, vital-temp, vital-ecghr, vital-rmssd, vital-sdnn
 *   vital-status      (NORMAL / WARNING / CRITICAL badge)
 *   vital-signal      (green dot or wifi icon that pulses on each update)
 *   alert-container   (div where toast alerts are appended)
 *   report-container  (div where the 30-min report card is rendered)
 *   session-progress  (optional <progress> or width bar showing 0-30 min)
 */

(function () {
  "use strict";

  /* ── 1. CONFIGURATION ─────────────────────────────────────────────────── */

  const BROKER_WS  = "ws://localhost:9001";  // Mosquitto WebSocket port
  // For HiveMQ cloud:  "wss://YOUR-ID.s1.eu.hivemq.cloud:8884/mqtt"
  const PATIENT_ID = "P001";
  const MQT_USER   = "";       // leave blank for unauthenticated local broker
  const MQT_PASS   = "";

  const T_LIVE    = `nexora/${PATIENT_ID}/live`;
  const T_VITALS  = `nexora/${PATIENT_ID}/vitals`;
  const T_ALERTS  = `nexora/${PATIENT_ID}/alerts`;
  const T_REPORT  = `nexora/${PATIENT_ID}/report`;
  const T_STATUS  = `nexora/${PATIENT_ID}/status`;

  /* ── 2. HOW MUCH A VALUE MUST CHANGE BEFORE THE DISPLAY UPDATES ───────── */
  /*    This is what gives the smartwatch / professional feel.               */
  const UPDATE_THRESHOLDS = {
    "vital-hr":    2,    // bpm  — ignore ±1 bpm noise
    "vital-spo2":  1,    // %
    "vital-temp":  0.1,  // °C
    "vital-ecghr": 2,    // bpm
    "vital-rmssd": 3,    // ms
    "vital-sdnn":  3,    // ms
  };

  /* ── 3. CONNECT ──────────────────────────────────────────────────────────*/

  const opts = {
    clientId: `nexora-web-${Math.random().toString(16).substr(2, 8)}`,
    clean:    true,
    reconnectPeriod: 3000,
  };
  if (MQT_USER) { opts.username = MQT_USER; opts.password = MQT_PASS; }

  const client = mqtt.connect(BROKER_WS, opts);

  client.on("connect", () => {
    console.log("[MQTT] Connected to broker");
    client.subscribe([T_LIVE, T_VITALS, T_ALERTS, T_REPORT, T_STATUS]);
    _setSignal("connected");
  });

  client.on("error",      (err) => { console.error("[MQTT]", err); });
  client.on("offline",    ()    => { _setSignal("offline"); });
  client.on("reconnect",  ()    => { _setSignal("reconnecting"); });

  /* ── 4. INCOMING MESSAGES ────────────────────────────────────────────────*/

  /** Track displayed values to avoid unnecessary DOM updates */
  const _displayed = {};

  client.on("message", (topic, raw) => {
    let data;
    try { data = JSON.parse(raw.toString()); } catch { return; }

    const sub = topic.split("/")[2];   // live | vitals | alerts | report | status

    switch (sub) {
      case "live":
        // 1 Hz stream — feed sparklines only, no number update
        _feedSparkline(data);
        _pulse();  // tiny heartbeat on the signal dot
        break;

      case "vitals":
        // Stable 1-per-minute reading — THIS updates the big displayed numbers
        _updateStableVitals(data);
        _updateSessionProgress(data.minute);
        break;

      case "alerts":
        _showAlert(data);
        break;

      case "report":
        _renderReport(data);
        break;

      case "status":
        _setSignal(data.service === "online" ? "connected" : "offline");
        break;
    }
  });

  /* ── 5. STABLE VITAL UPDATE ──────────────────────────────────────────────*/

  function _updateStableVitals(d) {
    const map = {
      "vital-hr":    d.heart_rate,
      "vital-spo2":  d.spo2,
      "vital-temp":  d.temperature,
      "vital-ecghr": d.ecg_hr,
      "vital-rmssd": d.rmssd,
      "vital-sdnn":  d.sdnn,
    };

    Object.entries(map).forEach(([id, val]) => {
      if (!val || val <= 0) return;
      const prev = _displayed[id];
      const thr  = UPDATE_THRESHOLDS[id] || 1;
      if (prev !== undefined && Math.abs(val - prev) < thr) return; // no update
      _displayed[id] = val;

      const el = document.getElementById(id);
      if (!el) return;

      // Fade-in-place: tiny opacity dip then restore
      el.style.transition = "opacity 0.35s ease, transform 0.35s ease";
      el.style.opacity    = "0.5";
      el.style.transform  = "scale(0.95)";
      setTimeout(() => {
        el.textContent    = _fmt(id, val);
        el.style.opacity  = "1";
        el.style.transform = "scale(1)";
      }, 180);
    });

    // Status badge
    const statusEl = document.getElementById("vital-status");
    if (statusEl) {
      const cls = d.overall_status || "NORMAL";
      statusEl.textContent = cls;
      statusEl.className   = statusEl.className.replace(/badge-\w+/g, "");
      statusEl.classList.add(
        cls === "CRITICAL" ? "badge-danger" :
        cls === "WARNING"  ? "badge-warning" : "badge-success"
      );
    }

    // Fall indicator
    if (d.fall_detected) _showAlert({ type: "fall" });

    // HRV cards + trend chart (defined in each dashboard HTML)
    if (typeof updateHRVDisplay === "function") updateHRVDisplay(d);
  }

  /* ── 6. SPARKLINE FEED ───────────────────────────────────────────────────*/

  // Lightweight rolling 60-point sparklines using Canvas
  const _sparklines = {};
  const SPARK_LEN   = 60;  // points

  function _feedSparkline(d) {
    const feeds = {
      "spark-hr":   d.heart_rate,
      "spark-spo2": d.spo2,
    };
    Object.entries(feeds).forEach(([id, val]) => {
      if (!_sparklines[id]) {
        _sparklines[id] = new Array(SPARK_LEN).fill(null);
      }
      _sparklines[id].push(val);
      if (_sparklines[id].length > SPARK_LEN) _sparklines[id].shift();
      _drawSparkline(id, _sparklines[id]);
    });
  }

  function _drawSparkline(id, points) {
    const canvas = document.getElementById(id);
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    const W = canvas.width, H = canvas.height;
    ctx.clearRect(0, 0, W, H);

    const valid = points.filter(p => p != null && p > 0);
    if (valid.length < 2) return;

    const mn = Math.min(...valid) - 2;
    const mx = Math.max(...valid) + 2;
    const xStep = W / (SPARK_LEN - 1);
    const yScale = (mn === mx) ? 0 : H / (mx - mn);

    ctx.beginPath();
    ctx.strokeStyle = "#14b8a6";
    ctx.lineWidth   = 1.5;
    ctx.lineJoin    = "round";

    let started = false;
    points.forEach((p, i) => {
      if (p == null) { started = false; return; }
      const x = i * xStep;
      const y = H - (p - mn) * yScale;
      if (!started) { ctx.moveTo(x, y); started = true; }
      else ctx.lineTo(x, y);
    });
    ctx.stroke();
  }

  /* ── 7. ALERT TOASTS ─────────────────────────────────────────────────────*/

  function _showAlert(alert) {
    const container = document.getElementById("alert-container");
    if (!container) {
      // Fallback: native browser notification
      if (alert.type === "fall") {
        _notify("⚑ Fall detected!", "Immediate attention required.");
      } else if (alert.type === "spike") {
        _notify(
          `⚑ ${alert.metric.replace("_", " ")} alert`,
          `Value: ${alert.value} ${alert.unit || ""} (${alert.direction})`
        );
      }
      return;
    }

    const toast  = document.createElement("div");
    const isCrit = alert.type === "fall" || alert.direction === "HIGH";
    toast.className = `nexora-toast ${isCrit ? "nexora-toast-crit" : "nexora-toast-warn"}`;
    toast.innerHTML = `
      <span class="toast-icon">${alert.type === "fall" ? "⚑" : "▲"}</span>
      <div>
        <div class="toast-title">${_alertTitle(alert)}</div>
        <div class="toast-body">${_alertBody(alert)}</div>
      </div>
      <button onclick="this.parentElement.remove()" style="margin-left:auto;background:none;border:none;cursor:pointer;font-size:16px;opacity:0.6">×</button>
    `;
    container.prepend(toast);

    // Auto-dismiss after 30 s (falls never auto-dismiss)
    if (alert.type !== "fall") {
      setTimeout(() => toast.remove(), 30000);
    }

    // Browser notification as extra safety net
    _notify(_alertTitle(alert), _alertBody(alert));
  }

  function _alertTitle(a) {
    if (a.type === "fall") return "⚑ Fall Detected";
    return `⚑ ${(a.metric || "").replace(/_/g, " ")} ${a.direction || ""}`;
  }
  function _alertBody(a) {
    if (a.type === "fall") return "Patient may need immediate assistance.";
    return `Reading: ${a.value} ${a.unit || ""}  (safe range limit: ${a.limit})`;
  }

  /* ── 8. 30-MINUTE REPORT ─────────────────────────────────────────────────*/

  function _renderReport(r) {
    const container = document.getElementById("report-container");
    if (!container) {
      console.log("[Report] Received:", r);
      return;
    }

    const statusColor = {
      CRITICAL: "#ef4444",
      WARNING:  "#f59e0b",
      NORMAL:   "#10b981",
    }[r.overall_status] || "#64748b";

    const rows = (r.anomaly_minutes || []).map(m =>
      `<tr>
        <td style="padding:4px 8px">${m.minute}</td>
        <td>${m.classification}</td>
        <td>${m.heart_rate ?? "—"}</td>
        <td>${m.spo2 ?? "—"}</td>
        <td>${m.temperature ?? "—"}</td>
        <td>${m.anomaly_score?.toFixed(3) ?? "—"}</td>
      </tr>`
    ).join("");

    const spikes = (r.spike_events || []).map(s =>
      `<li>${s.ts_human || ""} — <b>${(s.metric || "").replace(/_/g, " ")}</b>:
       ${s.value} ${s.unit || ""} (${s.direction})</li>`
    ).join("");

    container.innerHTML = `
      <div style="border:2px solid ${statusColor};border-radius:14px;padding:20px;margin-top:16px">
        <div style="display:flex;align-items:center;gap:12px;margin-bottom:16px">
          <div style="width:12px;height:12px;border-radius:50%;background:${statusColor}"></div>
          <h3 style="margin:0;font-size:16px">30-Minute Report — ${r.overall_status}</h3>
          <span style="margin-left:auto;font-size:12px;color:#94a3b8">${r.generated_at || ""}</span>
        </div>

        <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(120px,1fr));gap:10px;margin-bottom:16px">
          ${_statCard("HR avg",  r.vitals_stats?.heart_rate?.avg, "bpm")}
          ${_statCard("SpO₂ avg",r.vitals_stats?.spo2?.avg, "%")}
          ${_statCard("Temp avg",r.vitals_stats?.temperature?.avg, "°C")}
          ${_statCard("RMSSD avg",r.vitals_stats?.rmssd?.avg, "ms")}
          ${_statCard("Anomaly mins", r.summary?.anomaly_minutes_count, "")}
          ${_statCard("Spike events", r.summary?.spike_count, "")}
          ${_statCard("Fall", r.summary?.fall_detected ? "YES" : "No", "")}
        </div>

        ${rows ? `
        <div style="overflow-x:auto;margin-bottom:16px">
          <table style="width:100%;border-collapse:collapse;font-size:12px">
            <thead><tr style="background:#f1f5f9">
              <th style="padding:4px 8px;text-align:left">Min</th>
              <th>Status</th><th>HR</th><th>SpO₂</th><th>Temp</th><th>Score</th>
            </tr></thead>
            <tbody>${rows}</tbody>
          </table>
        </div>` : ""}

        ${spikes ? `
        <div>
          <div style="font-size:13px;font-weight:600;margin-bottom:6px">Spike events during session:</div>
          <ul style="font-size:12px;margin:0;padding-left:18px;line-height:1.8">${spikes}</ul>
        </div>` : ""}
      </div>`;

    // Scroll report into view
    container.scrollIntoView({ behavior: "smooth", block: "start" });
  }

  function _statCard(label, val, unit) {
    return `<div style="background:#f8fafc;border:1px solid #e2e8f0;border-radius:10px;padding:10px;text-align:center">
      <div style="font-size:18px;font-weight:700;color:#0f172a">${val ?? "—"}${val != null ? unit : ""}</div>
      <div style="font-size:11px;color:#64748b;margin-top:2px">${label}</div>
    </div>`;
  }

  /* ── 9. SESSION PROGRESS BAR ─────────────────────────────────────────────*/

  function _updateSessionProgress(minute) {
    const el = document.getElementById("session-progress");
    if (!el) return;
    const pct = Math.min(100, Math.round((minute / 30) * 100));
    if (el.tagName === "PROGRESS") {
      el.value = pct;
    } else {
      // Assume it's a div acting as a bar fill
      el.style.width = pct + "%";
    }

    const label = document.getElementById("session-progress-label");
    if (label) label.textContent = `${minute}/30 min`;
  }

  /* ── 10. SIGNAL DOT / PULSE ──────────────────────────────────────────────*/

  function _pulse() {
    const el = document.getElementById("vital-signal");
    if (!el) return;
    el.classList.add("nexora-signal-pulse");
    setTimeout(() => el.classList.remove("nexora-signal-pulse"), 400);
  }

  function _setSignal(state) {
    const el = document.getElementById("vital-signal");
    if (!el) return;
    el.dataset.state = state;
  }

  /* ── 11. BROWSER NOTIFICATION ────────────────────────────────────────────*/

  function _notify(title, body) {
    if (!("Notification" in window)) return;
    if (Notification.permission === "granted") {
      new Notification(title, { body, icon: "/static/logo.png" });
    } else if (Notification.permission !== "denied") {
      Notification.requestPermission().then(perm => {
        if (perm === "granted") new Notification(title, { body });
      });
    }
  }

  /* ── 12. FORMAT HELPERS ──────────────────────────────────────────────────*/

  function _fmt(id, val) {
    const prec = {
      "vital-temp":  1,
      "vital-rmssd": 1,
      "vital-sdnn":  1,
    };
    return val.toFixed(prec[id] ?? 0);
  }

  /* ── 13. INJECT REQUIRED CSS IF NOT ALREADY IN THE PAGE ─────────────────*/

  if (!document.getElementById("nexora-mqtt-styles")) {
    const style = document.createElement("style");
    style.id = "nexora-mqtt-styles";
    style.textContent = `
      .nexora-toast {
        display: flex; align-items: flex-start; gap: 10px;
        padding: 12px 16px; border-radius: 12px; margin-bottom: 8px;
        font-size: 13px; animation: nexora-slide-in 0.3s ease;
        box-shadow: 0 4px 20px -4px rgba(0,0,0,0.15);
      }
      .nexora-toast-crit  { background:#fef2f2; border:1.5px solid #fca5a5; color:#7f1d1d; }
      .nexora-toast-warn  { background:#fffbeb; border:1.5px solid #fcd34d; color:#78350f; }
      .toast-title        { font-weight:700; margin-bottom:2px; }
      .toast-body         { color:inherit; opacity:0.8; }
      .toast-icon         { font-size:18px; margin-top:1px; }
      @keyframes nexora-slide-in {
        from { transform:translateY(-12px); opacity:0; }
        to   { transform:translateY(0);     opacity:1; }
      }
      @keyframes nexora-pulse-ring {
        0%   { box-shadow: 0 0 0 0 rgba(20,184,166,0.5); }
        100% { box-shadow: 0 0 0 8px rgba(20,184,166,0); }
      }
      .nexora-signal-pulse { animation: nexora-pulse-ring 0.4s ease-out; }
    `;
    document.head.appendChild(style);
  }

})();