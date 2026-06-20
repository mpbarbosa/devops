// CloudWatch Synthetics runtime: syn-nodejs-puppeteer-9.x
// Checks https://copa2026.mpbarbosa.com/api/health — HTTP 200 + status:"ok"
const synthetics = require("Synthetics");
const log = require("SyntheticsLogger");
const https = require("https");

const TARGET = "https://copa2026.mpbarbosa.com/api/health";

const checkHealth = async () => {
  const result = await new Promise((resolve, reject) => {
    https
      .get(TARGET, { timeout: 10000 }, (res) => {
        let body = "";
        res.on("data", (chunk) => (body += chunk));
        res.on("end", () => resolve({ status: res.statusCode, body }));
      })
      .on("error", reject);
  });

  if (result.status !== 200) {
    throw new Error(`HTTP ${result.status} — expected 200`);
  }

  const json = JSON.parse(result.body);
  if (json.status !== "ok") {
    throw new Error(`status="${json.status}" — expected "ok"`);
  }

  log.info(
    "health",
    JSON.stringify({
      uptime: json.uptime,
      load1: json.load?.[0],
      memFree: json.system?.freeMem,
    }),
  );
};

exports.handler = async () =>
  synthetics.executeStep("health-check", checkHealth);
