// CloudWatch Synthetics runtime: syn-nodejs-puppeteer-9.x
// Checks https://copa2026.mpbarbosa.com/ — HTTP 200 only
const synthetics = require('Synthetics');
const https = require('https');

const TARGET = 'https://copa2026.mpbarbosa.com/';

const checkRoot = async () => {
  const status = await new Promise((resolve, reject) => {
    https.get(TARGET, { timeout: 10000 }, res => resolve(res.statusCode))
      .on('error', reject);
  });

  if (status !== 200) {
    throw new Error(`HTTP ${status} — expected 200`);
  }
};

exports.handler = async () => synthetics.executeStep('root-check', checkRoot);
