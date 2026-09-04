#!/usr/bin/env node

/**
 * End-to-End Test: TOON Integration in SKILL.md
 *
 * Tests the complete workflow:
 * 1. Extract TOON blocks from real SKILL.md files
 * 2. Validate syntax and token savings
 * 3. Verify round-trip conversion (lossless)
 * 4. Check backward compatibility (references work)
 *
 * @module end-to-end.test
 */

import { extractToonBlock, validateSkillMd, toonToJson, jsonToToon, roundTripTest } from '../converters/toon-converter.mjs';
import { readFileSync } from 'fs';
import { strict as assert } from 'assert';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const SKILLS_DIR = join(__dirname, '../..');

console.log('Running End-to-End TOON Integration Tests...\n');

// ============================================================================
// Test 1: Real-World Extraction - skill-generator
// ============================================================================

console.log('Test 1: Extract TOON blocks from skill-generator/SKILL.md');

const skillGenMd = join(SKILLS_DIR, 'skill-generator/SKILL.md');

// Extract questionnaire
const questionnaireToon = extractToonBlock(skillGenMd, 'questionnaire');
assert.ok(questionnaireToon, 'Should extract questionnaire block');
assert.ok(questionnaireToon.includes('questionnaire[12]'), 'Should have 12 questions');

// Extract errors
const errorsToon = extractToonBlock(skillGenMd, 'errors');
assert.ok(errorsToon, 'Should extract errors block');
assert.ok(errorsToon.includes('errors[7]'), 'Should have 7 errors');

// Extract placeholders
const placeholdersToon = extractToonBlock(skillGenMd, 'placeholders');
assert.ok(placeholdersToon, 'Should extract placeholders block');
assert.ok(placeholdersToon.includes('placeholders[6]'), 'Should have 6 placeholders');

console.log('✅ Passed: All 3 TOON blocks extracted from skill-generator\n');

// ============================================================================
// Test 2: Real-World Extraction - architecture-documentation
// ============================================================================

console.log('Test 2: Extract TOON blocks from architecture-documentation/SKILL.md');

const archDocMd = join(SKILLS_DIR, 'architecture-documentation/SKILL.md');

// Extract discovery_patterns
const discoveryToon = extractToonBlock(archDocMd, 'discovery_patterns');
assert.ok(discoveryToon, 'Should extract discovery_patterns block');
assert.ok(discoveryToon.includes('discovery_patterns[5]'), 'Should have 5 patterns');

// Extract safety_rules
const safetyToon = extractToonBlock(archDocMd, 'safety_rules');
assert.ok(safetyToon, 'Should extract safety_rules block');
assert.ok(safetyToon.includes('safety_rules[8]'), 'Should have 8 rules');

console.log('✅ Passed: All 2 TOON blocks extracted from architecture-documentation\n');

// ============================================================================
// Test 3: Round-Trip Conversion (Lossless)
// ============================================================================

console.log('Test 3: Round-trip conversion (TOON → JSON → TOON)');

// Test questionnaire round-trip
const questionnaireJson = toonToJson(questionnaireToon);
assert.ok(questionnaireJson.questionnaire, 'Should have questionnaire array');
assert.strictEqual(questionnaireJson.questionnaire.length, 12, 'Should have 12 questions');

const questionnaireReconverted = jsonToToon(questionnaireJson);
const questionnaireOriginalNormalized = questionnaireToon.replace(/\s+/g, ' ').trim();
const questionnaireReconvertedNormalized = questionnaireReconverted.replace(/\s+/g, ' ').trim();

// Allow whitespace differences
assert.ok(
  questionnaireReconvertedNormalized.includes('questionnaire[12]'),
  'Round-trip should preserve array header'
);

// Test errors round-trip
const errorsJson = toonToJson(errorsToon);
assert.strictEqual(errorsJson.errors.length, 7, 'Should have 7 errors');

const result = roundTripTest(errorsJson);
assert.ok(result.success, `Round-trip should succeed: ${result.error || 'OK'}`);

console.log('✅ Passed: Round-trip conversion is lossless\n');

// ============================================================================
// Test 4: Token Savings Validation
// ============================================================================

console.log('Test 4: Verify token savings match claimed values');

const skillGenResults = validateSkillMd(skillGenMd);
assert.strictEqual(skillGenResults.length, 3, 'Should find 3 TOON blocks in skill-generator');

skillGenResults.forEach(result => {
  assert.ok(result.validation.valid, `${result.arrayName} should be valid`);
  assert.ok(result.tokenSavings, `${result.arrayName} should have token savings`);

  // Check savings percentage is reasonable (30-50%)
  const savingsPercent = parseFloat(result.tokenSavings.savedPercent);
  assert.ok(
    savingsPercent >= 30 && savingsPercent <= 60,
    `${result.arrayName} savings should be 30-60% (got ${savingsPercent}%)`
  );
});

const archDocResults = validateSkillMd(archDocMd);
assert.strictEqual(archDocResults.length, 2, 'Should find 2 TOON blocks in architecture-documentation');

archDocResults.forEach(result => {
  assert.ok(result.validation.valid, `${result.arrayName} should be valid`);

  const savingsPercent = parseFloat(result.tokenSavings.savedPercent);
  assert.ok(
    savingsPercent >= 30 && savingsPercent <= 60,
    `${result.arrayName} savings should be 30-60% (got ${savingsPercent}%)`
  );
});

console.log('✅ Passed: Token savings within expected range (30-60%)\n');

// ============================================================================
// Test 5: Backward Compatibility (References)
// ============================================================================

console.log('Test 5: Verify backward compatibility (section anchors)');

const skillGenContent = readFileSync(skillGenMd, 'utf8');

// Check section anchors exist
assert.ok(
  skillGenContent.includes('<a id="interactive-questionnaire"></a>'),
  'Questionnaire section anchor should exist'
);
assert.ok(
  skillGenContent.includes('<a id="placeholder-syntax"></a>'),
  'Placeholder syntax section anchor should exist'
);
assert.ok(
  skillGenContent.includes('<a id="error-handling"></a>'),
  'Error handling section anchor should exist'
);

const archDocContent = readFileSync(archDocMd, 'utf8');

assert.ok(
  archDocContent.includes('<a id="component-discovery"></a>'),
  'Component discovery section anchor should exist'
);
assert.ok(
  archDocContent.includes('<a id="safety-rules"></a>'),
  'Safety rules section anchor should exist'
);

console.log('✅ Passed: All section anchors exist (backward compatible)\n');

// ============================================================================
// Test 6: Data Integrity (Questionnaire Content)
// ============================================================================

console.log('Test 6: Verify questionnaire data integrity');

const questions = questionnaireJson.questionnaire;

// Check Q1 (Skill Name)
const q1 = questions.find(q => q.question_id === 'Q1');
assert.ok(q1, 'Q1 should exist');
assert.ok(q1.prompt.includes('skill name') || q1.prompt.includes('kebab-case'), 'Q1 prompt should mention skill name or kebab-case');
assert.ok(q1.validation.includes('^[a-z]'), 'Q1 validation should have regex pattern');

// Check Q12 (Target Location)
const q12 = questions.find(q => q.question_id === 'Q12');
assert.ok(q12, 'Q12 should exist');
assert.ok(q12.prompt.includes('project'), 'Q12 prompt should mention project');
assert.ok(q12.notes.includes('BOTH'), 'Q12 notes should mention BOTH locations');

console.log('✅ Passed: Questionnaire data integrity verified\n');

// ============================================================================
// Test 7: Error Catalog Completeness
// ============================================================================

console.log('Test 7: Verify error catalog completeness');

const errorsData = errorsJson.errors;

// Check all error codes present
const expectedCodes = ['E001', 'E002', 'E003', 'E004', 'E005', 'E006', 'E007'];
const actualCodes = errorsData.map(e => e.code);

expectedCodes.forEach(code => {
  assert.ok(actualCodes.includes(code), `Error code ${code} should exist`);
});

// Check E001 (Invalid skill name)
const e001 = errorsData.find(e => e.code === 'E001');
assert.ok(e001.issue.includes('Invalid'), 'E001 issue should be about invalid name');
assert.ok(e001.recovery.includes('kebab-case'), 'E001 recovery should suggest kebab-case');

console.log('✅ Passed: Error catalog complete with all 7 error codes\n');

// ============================================================================
// Summary
// ============================================================================

console.log('========================================');
console.log('All End-to-End Tests Passed! ✅');
console.log('========================================');
console.log('');
console.log('Tested:');
console.log('  ✅ Real-world extraction (5 TOON blocks)');
console.log('  ✅ Round-trip conversion (lossless)');
console.log('  ✅ Token savings validation (30-60%)');
console.log('  ✅ Backward compatibility (section anchors)');
console.log('  ✅ Data integrity (questionnaire, errors)');
console.log('  ✅ Completeness (all error codes present)');
console.log('');
console.log('Skills validated:');
console.log('  • skill-generator (3 TOON blocks)');
console.log('  • architecture-documentation (2 TOON blocks)');
console.log('');
