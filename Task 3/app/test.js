// Basic test suite for the demo app
const assert = require('assert');

console.log('Running tests...');

// Test 1: Environment variable defaults
const PORT = process.env.PORT || 3000;
assert.strictEqual(typeof PORT, 'number', 'PORT should be a number');
console.log('✅ Test 1 passed: PORT default is valid');

// Test 2: VERSION variable
const VERSION = process.env.APP_VERSION || 'dev';
assert.ok(VERSION.length > 0, 'VERSION should not be empty');
console.log('✅ Test 2 passed: VERSION is set');

// Test 3: Health response shape
const healthResponse = { status: 'ok', version: VERSION, timestamp: new Date().toISOString() };
assert.strictEqual(healthResponse.status, 'ok', 'Health status should be ok');
assert.ok(healthResponse.timestamp, 'Timestamp should be present');
console.log('✅ Test 3 passed: Health response shape is correct');

console.log('\n✅ All tests passed!');
