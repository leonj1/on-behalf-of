#!/usr/bin/env node

// Test CORS from browser perspective
const https = require('https');

const options = {
  hostname: 'consent-api.joseserver.com',
  port: 443,
  path: '/applications',
  method: 'GET',
  headers: {
    'Origin': 'https://consent.joseserver.com',
    'User-Agent': 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36'
  }
};

console.log('Testing CORS from browser perspective...');

const req = https.request(options, (res) => {
  console.log('Status:', res.statusCode);
  console.log('Headers:');
  for (const [key, value] of Object.entries(res.headers)) {
    if (key.toLowerCase().includes('access-control') || key.toLowerCase().includes('origin')) {
      console.log(`  ${key}: ${value}`);
    }
  }
  
  let data = '';
  res.on('data', (chunk) => {
    data += chunk;
  });
  
  res.on('end', () => {
    console.log('Response length:', data.length);
    console.log('CORS headers present:', 
      res.headers['access-control-allow-origin'] ? 'YES' : 'NO');
  });
});

req.on('error', (e) => {
  console.error('Error:', e);
});

req.end();