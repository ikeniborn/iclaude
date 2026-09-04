#!/usr/bin/env node

/**
 * Test Suite: SKILL.md Integration
 *
 * Tests for extractToonBlock() and validateSkillMd() functions.
 * These functions enable embedding TOON blocks in SKILL.md files
 * for token-optimized documentation.
 *
 * @module skill-md-integration.test
 */

import { extractToonBlock, validateSkillMd, toonToJson, jsonToToon } from '../converters/toon-converter.mjs';
import { writeFileSync, unlinkSync, mkdtempSync } from 'fs';
import { tmpdir } from 'os';
import { join } from 'path';
import { strict as assert } from 'assert';

/**
 * Test Helper: Create temporary SKILL.md with TOON blocks
 */
function createTempSkillMd(content) {
  const tempDir = mkdtempSync(join(tmpdir(), 'toon-test-'));
  const skillMdPath = join(tempDir, 'SKILL.md');
  writeFileSync(skillMdPath, content, 'utf8');
  return skillMdPath;
}

/**
 * Test Helper: Clean up temporary file
 */
function cleanupTemp(filePath) {
  try {
    unlinkSync(filePath);
  } catch (error) {
    // Ignore cleanup errors
  }
}

console.log('Running SKILL.md Integration Tests...\n');

// ============================================================================
// Test 1: extractToonBlock() - Extract single TOON block
// ============================================================================

console.log('Test 1: extractToonBlock() - Extract single TOON block');

const skillMdSingle = `
# Test Skill

## Quick Reference

| ID | Name | Type |
|----|------|------|
| Q1 | Name | text |
| Q2 | Type | enum |

## Structured Data (TOON)

\`\`\`toon
questionnaire[2]{id,name,type}:
  Q1,Name,text
  Q2,Type,enum
\`\`\`
`;

const tempPath1 = createTempSkillMd(skillMdSingle);
const extracted = extractToonBlock(tempPath1, 'questionnaire');

assert.ok(extracted, 'Should extract TOON block');
assert.ok(extracted.includes('questionnaire[2]'), 'Should contain array header');
assert.ok(extracted.includes('Q1,Name,text'), 'Should contain first row');
assert.ok(extracted.includes('Q2,Type,enum'), 'Should contain second row');

cleanupTemp(tempPath1);
console.log('✅ Passed: extractToonBlock() extracts single TOON block\n');

// ============================================================================
// Test 2: extractToonBlock() - Array not found
// ============================================================================

console.log('Test 2: extractToonBlock() - Array not found');

const tempPath2 = createTempSkillMd(skillMdSingle);
const notFound = extractToonBlock(tempPath2, 'nonexistent');

assert.strictEqual(notFound, null, 'Should return null for non-existent array');

cleanupTemp(tempPath2);
console.log('✅ Passed: extractToonBlock() returns null for missing array\n');

// ============================================================================
// Test 3: extractToonBlock() - Multiple TOON blocks
// ============================================================================

console.log('Test 3: extractToonBlock() - Multiple TOON blocks');

const skillMdMultiple = `
# Test Skill

\`\`\`toon
questions[2]{id,prompt}:
  Q1,Enter name
  Q2,Select type
\`\`\`

\`\`\`toon
errors[2]{code,message}:
  E001,Invalid input
  E002,Timeout
\`\`\`
`;

const tempPath3 = createTempSkillMd(skillMdMultiple);
const extractedQuestions = extractToonBlock(tempPath3, 'questions');
const extractedErrors = extractToonBlock(tempPath3, 'errors');

assert.ok(extractedQuestions, 'Should extract questions array');
assert.ok(extractedErrors, 'Should extract errors array');
assert.ok(extractedQuestions.includes('Enter name'), 'Questions should contain correct data');
assert.ok(extractedErrors.includes('Invalid input'), 'Errors should contain correct data');

cleanupTemp(tempPath3);
console.log('✅ Passed: extractToonBlock() handles multiple TOON blocks\n');

// ============================================================================
// Test 4: validateSkillMd() - Valid TOON blocks
// ============================================================================

console.log('Test 4: validateSkillMd() - Valid TOON blocks');

const tempPath4 = createTempSkillMd(skillMdMultiple);
const results = validateSkillMd(tempPath4);

assert.strictEqual(results.length, 2, 'Should find 2 TOON blocks');
assert.strictEqual(results[0].arrayName, 'questions', 'First block should be questions');
assert.strictEqual(results[1].arrayName, 'errors', 'Second block should be errors');
assert.ok(results[0].validation.valid, 'Questions block should be valid');
assert.ok(results[1].validation.valid, 'Errors block should be valid');
assert.ok(results[0].tokenSavings, 'Should calculate token savings for questions');
assert.ok(results[1].tokenSavings, 'Should calculate token savings for errors');

cleanupTemp(tempPath4);
console.log('✅ Passed: validateSkillMd() validates multiple blocks\n');

// ============================================================================
// Test 5: validateSkillMd() - Invalid TOON syntax
// ============================================================================

console.log('Test 5: validateSkillMd() - Invalid TOON syntax');

const skillMdInvalid = `
# Test Skill

\`\`\`toon
broken[2]{id,name}:
  A,Value1
  B,Value2,TooMany
\`\`\`
`;

const tempPath5 = createTempSkillMd(skillMdInvalid);
const resultsInvalid = validateSkillMd(tempPath5);

assert.strictEqual(resultsInvalid.length, 1, 'Should find 1 TOON block');
assert.strictEqual(resultsInvalid[0].validation.valid, false, 'Block should be invalid');
assert.ok(resultsInvalid[0].validation.error, 'Should provide error message');

cleanupTemp(tempPath5);
console.log('✅ Passed: validateSkillMd() detects invalid syntax\n');

// ============================================================================
// Test 6: validateSkillMd() - No TOON blocks
// ============================================================================

console.log('Test 6: validateSkillMd() - No TOON blocks');

const skillMdEmpty = `
# Test Skill

Just regular markdown content with no TOON blocks.

| Table | Header |
|-------|--------|
| A     | B      |
`;

const tempPath6 = createTempSkillMd(skillMdEmpty);
const resultsEmpty = validateSkillMd(tempPath6);

assert.strictEqual(resultsEmpty.length, 0, 'Should find no TOON blocks');

cleanupTemp(tempPath6);
console.log('✅ Passed: validateSkillMd() handles files without TOON blocks\n');

// ============================================================================
// Test 7: Round-trip conversion through extractToonBlock()
// ============================================================================

console.log('Test 7: Round-trip conversion through extractToonBlock()');

const originalJson = {
  components: [
    { id: 'proxy-mgmt', name: 'Proxy Management', type: 'module' },
    { id: 'oauth-token', name: 'OAuth Token', type: 'function' }
  ]
};

const toonString = jsonToToon(originalJson);
const skillMdRoundtrip = `
# Architecture

\`\`\`toon
${toonString}
\`\`\`
`;

const tempPath7 = createTempSkillMd(skillMdRoundtrip);
const extractedRoundtrip = extractToonBlock(tempPath7, 'components');
const reconstructedJson = toonToJson(extractedRoundtrip);

assert.deepStrictEqual(reconstructedJson, originalJson, 'Round-trip should preserve data');

cleanupTemp(tempPath7);
console.log('✅ Passed: Round-trip conversion is lossless\n');

// ============================================================================
// Test 8: Token savings calculation accuracy
// ============================================================================

console.log('Test 8: Token savings calculation accuracy');

const tempPath8 = createTempSkillMd(skillMdMultiple);
const resultsWithSavings = validateSkillMd(tempPath8);

resultsWithSavings.forEach(result => {
  if (result.validation.valid) {
    assert.ok(result.tokenSavings.jsonTokens > 0, 'JSON tokens should be positive');
    assert.ok(result.tokenSavings.toonTokens > 0, 'TOON tokens should be positive');
    assert.ok(result.tokenSavings.savedTokens >= 0, 'Saved tokens should be non-negative');
    assert.ok(result.tokenSavings.savedPercent.endsWith('%'), 'Saved percent should have % suffix');
  }
});

cleanupTemp(tempPath8);
console.log('✅ Passed: Token savings calculated correctly\n');

// ============================================================================
// Summary
// ============================================================================

console.log('========================================');
console.log('All SKILL.md Integration Tests Passed! ✅');
console.log('========================================');
console.log('');
console.log('New functions tested:');
console.log('  • extractToonBlock(skillMdPath, arrayName)');
console.log('  • validateSkillMd(skillMdPath)');
console.log('');
console.log('Coverage:');
console.log('  ✅ Extract single TOON block');
console.log('  ✅ Extract from multiple TOON blocks');
console.log('  ✅ Handle missing arrays (return null)');
console.log('  ✅ Validate all TOON blocks in file');
console.log('  ✅ Detect invalid TOON syntax');
console.log('  ✅ Handle files without TOON blocks');
console.log('  ✅ Lossless round-trip conversion');
console.log('  ✅ Token savings calculation accuracy');
console.log('');
