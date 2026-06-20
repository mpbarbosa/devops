#!/usr/bin/env node
// Smoke test for https://copa2026.mpbarbosa.com
// Uses only Node.js built-in modules — no npm install required.
// Exit code 0 = all checks passed, 1 = one or more failures.
//
// Usage: node copa2026/smoke-test.js [--verbose]

import https from "https";
import tls from "tls";
import { URL } from "url";

const BASE = "https://copa2026.mpbarbosa.com";
const TIMEOUT_MS = 10_000;
const VERBOSE = process.argv.includes("--verbose");

// ── helpers ──────────────────────────────────────────────────────────────────

function get(url) {
  return new Promise((resolve, reject) => {
    const req = https.get(url, { timeout: TIMEOUT_MS }, (res) => {
      let body = "";
      res.on("data", (c) => (body += c));
      res.on("end", () =>
        resolve({ status: res.statusCode, headers: res.headers, body }),
      );
    });
    req.on("timeout", () => {
      req.destroy();
      reject(new Error(`Timeout after ${TIMEOUT_MS}ms`));
    });
    req.on("error", reject);
  });
}

function certDaysRemaining(host) {
  return new Promise((resolve, reject) => {
    const socket = tls.connect(
      { host, port: 443, servername: host, timeout: TIMEOUT_MS },
      () => {
        const cert = socket.getPeerCertificate();
        socket.destroy();
        const expiry = new Date(cert.valid_to);
        resolve(Math.floor((expiry - Date.now()) / 86_400_000));
      },
    );
    socket.on("timeout", () => {
      socket.destroy();
      reject(new Error("TLS connect timeout"));
    });
    socket.on("error", reject);
  });
}

// ── test runner ───────────────────────────────────────────────────────────────

let passed = 0;
let failed = 0;

function pass(name, detail = "") {
  passed++;
  console.log(`  ✓  ${name}${detail ? `  (${detail})` : ""}`);
}

function fail(name, reason) {
  failed++;
  console.error(`  ✗  ${name}`);
  console.error(`     └─ ${reason}`);
}

function verbose(label, value) {
  if (VERBOSE) console.log(`     ${label}: ${JSON.stringify(value)}`);
}

// ── checks ────────────────────────────────────────────────────────────────────

async function checkHealth() {
  console.log("\n[1] Health endpoint");
  const t0 = Date.now();
  const { status, body } = await get(`${BASE}/api/health`);
  const ms = Date.now() - t0;

  if (status !== 200) {
    fail("HTTP 200", `got ${status}`);
    return;
  }
  pass("HTTP 200", `${ms}ms`);

  let json;
  try {
    json = JSON.parse(body);
  } catch {
    fail("Valid JSON body", "could not parse");
    return;
  }
  pass("Valid JSON body");
  verbose("body", json);

  json.status === "ok"
    ? pass('status === "ok"')
    : fail('status === "ok"', `got "${json.status}"`);

  json.uptime > 0
    ? pass("uptime > 0", `${json.uptime}s`)
    : fail("uptime > 0", `got ${json.uptime}`);

  Array.isArray(json.load) && json.load.length >= 1
    ? pass("load array present", `1m=${json.load[0]}`)
    : fail("load array present", `got ${JSON.stringify(json.load)}`);

  const load1m = json.load?.[0] ?? 999;
  load1m < 4
    ? pass("1-min load < 4", `${load1m}`)
    : fail("1-min load < 4", `load is ${load1m} — server may be overloaded`);

  const freeMem = json.system?.freeMem ?? 0;
  const totalMem = json.system?.totalMem ?? 1;
  const freePct = Math.round((freeMem / totalMem) * 100);
  freeMem > 0
    ? pass("freeMem > 0", `${freePct}% free`)
    : fail("freeMem > 0", `got ${freeMem}`);

  const heapUsed = json.memory?.heapUsed ?? 0;
  heapUsed > 0
    ? pass("heapUsed > 0", `${Math.round(heapUsed / 1024 / 1024)}MiB`)
    : fail("heapUsed > 0", `got ${heapUsed}`);
}

async function checkMatchOverlays() {
  console.log("\n[2] /api/match-overlays");
  const t0 = Date.now();
  const { status, body } = await get(`${BASE}/api/match-overlays`);
  const ms = Date.now() - t0;

  if (status !== 200) {
    fail("HTTP 200", `got ${status}`);
    return;
  }
  pass("HTTP 200", `${ms}ms`);

  let json;
  try {
    json = JSON.parse(body);
  } catch {
    fail("Valid JSON body", "could not parse");
    return;
  }
  pass("Valid JSON body");
  verbose("keys", Object.keys(json));

  typeof json.refreshAfterMs === "number"
    ? pass("refreshAfterMs is a number", `${json.refreshAfterMs}ms`)
    : fail("refreshAfterMs is a number", `got ${typeof json.refreshAfterMs}`);

  json.overlays !== null && typeof json.overlays === "object"
    ? pass("overlays is an object", `${Object.keys(json.overlays).length} entries`)
    : fail("overlays is an object", `got ${typeof json.overlays}`);
}

async function checkTeamLineups() {
  console.log("\n[3] /api/team-lineups");
  const t0 = Date.now();
  const { status, body } = await get(`${BASE}/api/team-lineups`);
  const ms = Date.now() - t0;

  if (status !== 200) {
    fail("HTTP 200", `got ${status}`);
    return;
  }
  pass("HTTP 200", `${ms}ms`);

  let json;
  try {
    json = JSON.parse(body);
  } catch {
    fail("Valid JSON body", "could not parse");
    return;
  }
  pass("Valid JSON body");

  typeof json.refreshAfterMs === "number"
    ? pass("refreshAfterMs is a number", `${json.refreshAfterMs}ms`)
    : fail("refreshAfterMs is a number", `got ${typeof json.refreshAfterMs}`);

  json.lineups !== null && typeof json.lineups === "object"
    ? pass("lineups is an object", `${Object.keys(json.lineups).length} entries`)
    : fail("lineups is an object", `got ${typeof json.lineups}`);
}

async function checkRootPage() {
  console.log("\n[4] Root page");
  const t0 = Date.now();
  const { status, headers, body } = await get(`${BASE}/`);
  const ms = Date.now() - t0;

  if (status !== 200) {
    fail("HTTP 200", `got ${status}`);
    return;
  }
  pass("HTTP 200", `${ms}ms`);

  const ct = headers["content-type"] ?? "";
  ct.includes("text/html")
    ? pass("Content-Type: text/html")
    : fail("Content-Type: text/html", `got "${ct}"`);

  body.includes("<title>Agora na Copa 26</title>")
    ? pass('title: "Agora na Copa 26"')
    : fail('title: "Agora na Copa 26"', "not found in HTML");

  body.includes('lang="pt-BR"')
    ? pass('html lang="pt-BR"')
    : fail('html lang="pt-BR"', "not found");

  body.includes('id="root"')
    ? pass('React mount point <div id="root"> present')
    : fail('React mount point <div id="root"> present', "not found in HTML");

  // Verify the JS bundle URL is embedded and loadable
  const jsMatch = body.match(/src="(\/assets\/index-[^"]+\.js)"/);
  if (!jsMatch) {
    fail("JS bundle tag present", "no <script src=/assets/index-*.js> found");
    return;
  }
  const jsBundleUrl = `${BASE}${jsMatch[1]}`;
  pass("JS bundle tag present", jsMatch[1]);

  const t1 = Date.now();
  const bundle = await get(jsBundleUrl);
  const bundleMs = Date.now() - t1;
  bundle.status === 200
    ? pass("JS bundle loads", `${bundleMs}ms`)
    : fail("JS bundle loads", `HTTP ${bundle.status} on ${jsMatch[1]}`);

  // Check CSS bundle too
  const cssMatch = body.match(/href="(\/assets\/index-[^"]+\.css)"/);
  if (cssMatch) {
    const cssUrl = `${BASE}${cssMatch[1]}`;
    const css = await get(cssUrl);
    css.status === 200
      ? pass("CSS bundle loads", cssMatch[1].slice(0, 30) + "…")
      : fail("CSS bundle loads", `HTTP ${css.status}`);
  }
}

async function checkTLS() {
  console.log("\n[5] TLS certificate");
  const host = new URL(BASE).hostname;
  const days = await certDaysRemaining(host);
  days > 14
    ? pass("cert valid for > 14 days", `${days} days remaining`)
    : fail("cert valid for > 14 days", `only ${days} days left — renew soon`);
  days > 0
    ? pass("cert not expired")
    : fail("cert not expired", `expired ${Math.abs(days)} days ago`);
}

// ── main ──────────────────────────────────────────────────────────────────────

console.log(`Smoke test: ${BASE}`);
console.log(`${"─".repeat(50)}`);

try {
  await checkHealth();
  await checkMatchOverlays();
  await checkTeamLineups();
  await checkRootPage();
  await checkTLS();
} catch (err) {
  failed++;
  console.error(`\nUnexpected error: ${err.message}`);
}

console.log(`\n${"─".repeat(50)}`);
console.log(`Results: ${passed} passed, ${failed} failed`);

if (failed > 0) {
  process.exit(1);
}
