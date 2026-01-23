#!/usr/bin/env node

/**
 * Round-trip tests: JSON → TOON → JSON (lossless conversion)
 */

import { jsonToToon, toonToJson, arrayToToon, roundTripTest } from '../converters/toon-converter.mjs';
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

console.log('=== Round-trip Tests ===\n');

// Test 1: Simple array round-trip
test('Simple array round-trip', () => {
  const input = {
    items: [
      { id: 1, name: 'Alice' },
      { id: 2, name: 'Bob' }
    ]
  };

  const toon = jsonToToon(input);
  const output = toonToJson(toon);
  assert.deepStrictEqual(input, output, 'Round-trip failed for simple array');
});

// Test 2: Nested structure round-trip
test('Nested structure round-trip', () => {
  const input = {
    graph: {
      nodes: [{ id: 'a' }, { id: 'b' }],
      edges: [{ from: 'a', to: 'b' }]
    }
  };

  const result = roundTripTest(input);
  assert(result.success, `Round-trip failed: ${result.error}`);
});

// Test 3: Code review warnings round-trip
test('Code review warnings round-trip', () => {
  const input = {
    warnings: [
      { category: 'security', file: 'app.js', line: 42, severity: 'BLOCKING', message: 'SQL injection', suggestion: 'Use params' },
      { category: 'code_quality', file: 'db.js', line: 15, severity: 'WARNING', message: 'Missing index', suggestion: 'Add index' },
      { category: 'performance', file: 'api.js', line: 78, severity: 'INFO', message: 'Inefficient loop', suggestion: 'Use map()' }
    ]
  };

  const result = roundTripTest(input);
  assert(result.success, `Round-trip failed: ${result.error}`);
});

// Test 4: Execution steps round-trip
test('Execution steps round-trip', () => {
  const input = {
    execution_steps: [
      { step_number: 1, description: 'Create API endpoint', validation: 'Run pytest' },
      { step_number: 2, description: 'Add validation', validation: 'Check types' },
      { step_number: 3, description: 'Write tests', validation: 'Coverage 100%' }
    ]
  };

  const result = roundTripTest(input);
  assert(result.success, `Round-trip failed: ${result.error}`);
});

// Test 5: Special characters (commas, quotes) round-trip
test('Special characters round-trip', () => {
  const input = {
    items: [
      { file: 'app.js', message: 'Error: invalid input, check validation' },
      { file: 'db.js', message: 'Warning: missing index, columns: email, username' },
      { file: 'api.js', message: 'Consider refactoring: "split, map, filter" chain' }
    ]
  };

  const result = roundTripTest(input);
  assert(result.success, `Round-trip failed: ${result.error}`);
});

// Test 6: Large dataset (50 items) round-trip
test('Large dataset round-trip', () => {
  const input = {
    lsp_diagnostics: Array.from({ length: 50 }, (_, i) => ({
      file: `src/file${i % 10}.ts`,
      line: 10 + i,
      severity: ['error', 'warning', 'info'][i % 3],
      code: `TS${2000 + i}`,
      message: `Type error #${i + 1}`
    }))
  };

  const result = roundTripTest(input);
  assert(result.success, `Round-trip failed: ${result.error}`);
});

// Test 7: Empty array round-trip
test('Empty array round-trip', () => {
  const input = {
    items: []
  };

  const result = roundTripTest(input);
  assert(result.success, `Round-trip failed: ${result.error}`);
});

// Test 8: Null/undefined values round-trip
test('Null/undefined values round-trip', () => {
  const input = {
    items: [
      { id: 1, name: 'Alice', age: null },
      { id: 2, name: 'Bob', age: 30 },
      { id: 3, name: 'Charlie', age: null }
    ]
  };

  const result = roundTripTest(input);
  assert(result.success, `Round-trip failed: ${result.error}`);
});

// Test 9: arrayToToon manual round-trip
test('arrayToToon manual round-trip', () => {
  const items = [
    { id: 1, name: 'Alice', role: 'admin' },
    { id: 2, name: 'Bob', role: 'user' },
    { id: 3, name: 'Charlie', role: 'user' }
  ];

  const toon = arrayToToon('items', items, ['id', 'name', 'role']);
  const parsed = toonToJson(toon);

  assert.deepStrictEqual(parsed.items, items, 'arrayToToon round-trip failed');
});

// Test 10: Dependency graph round-trip
test('Dependency graph round-trip', () => {
  const input = {
    dependency_graph: {
      nodes: [
        { id: 'a', label: 'Component A', type: 'module', layer: 'business' },
        { id: 'b', label: 'Component B', type: 'class', layer: 'infrastructure' }
      ],
      edges: [
        { from: 'a', to: 'b', type: 'required', description: 'Uses B for data access' }
      ]
    }
  };

  const result = roundTripTest(input);
  assert(result.success, `Round-trip failed: ${result.error}`);
});

console.log(`\n=== Results ===`);
console.log(`Passed: ${testsPassed}`);
console.log(`Failed: ${testsFailed}`);

if (testsFailed > 0) {
  process.exit(1);
} else {
  console.log('\n✓ All round-trip tests passed! Lossless conversion confirmed.');
}
