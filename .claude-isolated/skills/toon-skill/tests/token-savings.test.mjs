#!/usr/bin/env node

/**
 * Token savings tests: Verify TOON achieves expected token reduction
 */

import { calculateTokenSavings, arrayToToon } from '../converters/toon-converter.mjs';
import assert from 'assert';

let testsPassed = 0;
let testsFailed = 0;

function test(name, fn) {
  try {
    fn();
    console.log(`✓ ${name}`);
    testsPassed++;
  } catch (error) {
    console.error(`✗ ${name}`);
    console.error(`  ${error.message}`);
    testsFailed++;
  }
}

console.log('=== Token Savings Tests ===\n');

// Test 1: Minimum savings for 5 items (threshold)
test('5 items: savings >= 25%', () => {
  const data = {
    items: Array.from({ length: 5 }, (_, i) => ({
      id: i + 1,
      name: `Item ${i + 1}`,
      status: 'active'
    }))
  };

  const stats = calculateTokenSavings(data);
  const savingsPercent = parseFloat(stats.savedPercent);

  console.log(`  Savings: ${stats.savedPercent} (${stats.savedTokens} tokens)`);
  assert(savingsPercent >= 25, `Expected >= 25%, got ${savingsPercent}%`);
});

// Test 2: Good savings for 10 items
test('10 items: savings >= 35%', () => {
  const data = {
    items: Array.from({ length: 10 }, (_, i) => ({
      id: i + 1,
      name: `Item ${i + 1}`,
      status: 'active',
      priority: 'high'
    }))
  };

  const stats = calculateTokenSavings(data);
  const savingsPercent = parseFloat(stats.savedPercent);

  console.log(`  Savings: ${stats.savedPercent} (${stats.savedTokens} tokens)`);
  assert(savingsPercent >= 35, `Expected >= 35%, got ${savingsPercent}%`);
});

// Test 3: High savings for 20 items
test('20 items: savings >= 45%', () => {
  const data = {
    items: Array.from({ length: 20 }, (_, i) => ({
      file: `src/file${i}.js`,
      line: 10 + i,
      severity: 'warning',
      message: `Issue #${i + 1}`
    }))
  };

  const stats = calculateTokenSavings(data);
  const savingsPercent = parseFloat(stats.savedPercent);

  console.log(`  Savings: ${stats.savedPercent} (${stats.savedTokens} tokens)`);
  assert(savingsPercent >= 45, `Expected >= 45%, got ${savingsPercent}%`);
});

// Test 4: Maximum savings for 50 items
test('50 items: savings >= 48%', () => {
  const data = {
    lsp_diagnostics: Array.from({ length: 50 }, (_, i) => ({
      file: `src/file${i % 10}.ts`,
      line: 10 + i,
      severity: ['error', 'warning', 'info'][i % 3],
      code: `TS${2000 + i}`,
      message: `Type error #${i + 1}`
    }))
  };

  const stats = calculateTokenSavings(data);
  const savingsPercent = parseFloat(stats.savedPercent);

  console.log(`  Savings: ${stats.savedPercent} (${stats.savedTokens} tokens)`);
  assert(savingsPercent >= 48, `Expected >= 48%, got ${savingsPercent}%`);
});

// Test 5: Code review warnings (realistic data)
test('Code review warnings: savings >= 40%', () => {
  const data = {
    warnings: [
      { category: 'security', file: 'src/app.js', line: 42, severity: 'BLOCKING', message: 'SQL injection vulnerability', suggestion: 'Use parameterized queries' },
      { category: 'code_quality', file: 'src/db.js', line: 15, severity: 'WARNING', message: 'Missing database index', suggestion: 'Add index on user_id' },
      { category: 'performance', file: 'src/api.js', line: 78, severity: 'INFO', message: 'Inefficient loop', suggestion: 'Use Array.map()' },
      { category: 'type_safety', file: 'src/utils.js', line: 123, severity: 'WARNING', message: 'Implicit type coercion', suggestion: 'Use strict equality' },
      { category: 'error_handling', file: 'src/service.js', line: 145, severity: 'WARNING', message: 'Swallowed exception', suggestion: 'Log or re-throw error' },
      { category: 'maintainability', file: 'src/parser.js', line: 56, severity: 'INFO', message: 'Complex function', suggestion: 'Extract helper function' },
      { category: 'best_practices', file: 'src/config.js', line: 12, severity: 'WARNING', message: 'Hardcoded value', suggestion: 'Move to env var' },
      { category: 'documentation', file: 'src/api.js', line: 201, severity: 'INFO', message: 'Missing JSDoc', suggestion: 'Add documentation' },
      { category: 'naming', file: 'src/helpers.js', line: 34, severity: 'INFO', message: 'Non-descriptive name', suggestion: 'Rename function' },
      { category: 'code_quality', file: 'src/validators.js', line: 89, severity: 'WARNING', message: 'Duplicate code', suggestion: 'Extract to shared function' }
    ]
  };

  const stats = calculateTokenSavings(data);
  const savingsPercent = parseFloat(stats.savedPercent);

  console.log(`  Savings: ${stats.savedPercent} (${stats.savedTokens} tokens)`);
  assert(savingsPercent >= 40, `Expected >= 40%, got ${savingsPercent}%`);
});

// Test 6: Dependency graph (nested structure)
test('Dependency graph: savings >= 45%', () => {
  const data = {
    dependency_graph: {
      nodes: [
        { id: 'proxy-mgmt', label: 'Proxy Management', type: 'module', layer: 'infrastructure' },
        { id: 'oauth-handler', label: 'OAuth Handler', type: 'function', layer: 'business' },
        { id: 'token-refresh', label: 'Token Refresh', type: 'function', layer: 'business' },
        { id: 'api-client', label: 'API Client', type: 'class', layer: 'business' }
      ],
      edges: [
        { from: 'proxy-mgmt', to: 'oauth-handler', type: 'required', description: 'OAuth for proxies' },
        { from: 'oauth-handler', to: 'token-refresh', type: 'required', description: 'Refresh tokens' },
        { from: 'api-client', to: 'oauth-handler', type: 'required', description: 'API auth' }
      ]
    }
  };

  const stats = calculateTokenSavings(data);
  const savingsPercent = parseFloat(stats.savedPercent);

  console.log(`  Savings: ${stats.savedPercent} (${stats.savedTokens} tokens)`);
  assert(savingsPercent >= 45, `Expected >= 45%, got ${savingsPercent}%`);
});

// Test 7: Verify stats structure
test('Token stats structure', () => {
  const data = { items: [{ id: 1 }, { id: 2 }, { id: 3 }, { id: 4 }, { id: 5 }] };
  const stats = calculateTokenSavings(data);

  assert(typeof stats.jsonTokens === 'number', 'jsonTokens should be number');
  assert(typeof stats.toonTokens === 'number', 'toonTokens should be number');
  assert(typeof stats.savedTokens === 'number', 'savedTokens should be number');
  assert(typeof stats.savedPercent === 'string', 'savedPercent should be string');
  assert(stats.savedPercent.endsWith('%'), 'savedPercent should end with %');
  assert(typeof stats.jsonSize === 'number', 'jsonSize should be number');
  assert(typeof stats.toonSize === 'number', 'toonSize should be number');

  console.log(`  Stats: ${JSON.stringify(stats)}`);
});

// Test 8: Verify TOON size < JSON size
test('TOON size < JSON size', () => {
  const data = {
    items: Array.from({ length: 10 }, (_, i) => ({
      id: i + 1,
      name: `Item ${i + 1}`,
      status: 'active'
    }))
  };

  const stats = calculateTokenSavings(data);

  assert(stats.toonSize < stats.jsonSize, `TOON size (${stats.toonSize}) should be < JSON size (${stats.jsonSize})`);
  assert(stats.toonTokens < stats.jsonTokens, `TOON tokens (${stats.toonTokens}) should be < JSON tokens (${stats.jsonTokens})`);
  assert(stats.savedTokens > 0, 'Saved tokens should be > 0');

  console.log(`  JSON: ${stats.jsonSize} bytes (${stats.jsonTokens} tokens)`);
  console.log(`  TOON: ${stats.toonSize} bytes (${stats.toonTokens} tokens)`);
});

console.log(`\n=== Results ===`);
console.log(`Passed: ${testsPassed}`);
console.log(`Failed: ${testsFailed}`);

if (testsFailed > 0) {
  process.exit(1);
} else {
  console.log('\n✓ All token savings tests passed!');
}
