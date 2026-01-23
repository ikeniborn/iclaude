#!/usr/bin/env node

/**
 * TOON Converter - Wrapper around @toon-format/toon for architecture documentation
 *
 * Provides simple API for converting between JSON/YAML and TOON formats.
 * Used by architecture-documentation skill for token-efficient structured output.
 *
 * Usage (ES Module):
 *   import { jsonToToon, toonToJson, componentsToToon, edgesToToon } from './toon-converter.mjs';
 *
 *   // Generic conversion
 *   const toonString = jsonToToon({ components: [...] });
 *   const jsonObj = toonToJson(toonString);
 *
 *   // Specific converters
 *   const componentsToon = componentsToToon(componentsArray);
 *   const edgesToon = edgesToToon(edgesArray);
 *
 * @module toon-converter
 * @version 1.0.0
 */

import { encode, decode } from '@toon-format/toon';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, resolve } from 'path';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

/**
 * Convert JSON object to TOON string
 *
 * @param {Object} jsonObj - JSON object to convert
 * @param {Object} options - Encoding options
 * @param {string} options.delimiter - Delimiter for arrays: ',' (default), '\t', '|'
 * @param {number} options.indent - Indentation size (default: 2)
 * @returns {string} TOON formatted string
 *
 * @example
 * const toon = jsonToToon({ components: [{ id: 'foo', name: 'Foo' }] });
 * // Returns: components[1]{id,name}:\n  foo,Foo
 */
function jsonToToon(jsonObj, options = {}) {
  const defaultOptions = {
    delimiter: ',',
    indent: 2
  };

  const mergedOptions = { ...defaultOptions, ...options };

  try {
    return encode(jsonObj, mergedOptions);
  } catch (error) {
    throw new Error(`Failed to encode JSON to TOON: ${error.message}`);
  }
}

/**
 * Convert TOON string to JSON object
 *
 * @param {string} toonString - TOON formatted string
 * @param {Object} options - Decoding options
 * @param {boolean} options.strict - Enable strict mode (default: true)
 * @returns {Object} Parsed JSON object
 *
 * @example
 * const json = toonToJson('components[1]{id,name}:\n  foo,Foo');
 * // Returns: { components: [{ id: 'foo', name: 'Foo' }] }
 */
function toonToJson(toonString, options = {}) {
  const defaultOptions = {
    strict: true
  };

  const mergedOptions = { ...defaultOptions, ...options };

  try {
    return decode(toonString, mergedOptions);
  } catch (error) {
    throw new Error(`Failed to decode TOON to JSON: ${error.message}`);
  }
}

/**
 * Convert components array to TOON tabular format
 *
 * @param {Array} components - Array of component objects
 * @param {string} components[].id - Component ID (kebab-case)
 * @param {string} components[].name - Component name
 * @param {string} components[].type - Component type (module, class, function, etc.)
 * @param {string} components[].path - File path or location
 * @param {string} components[].description - Component description
 * @param {string} components[].layer - Architectural layer
 * @returns {string} TOON formatted components table
 *
 * @example
 * const toon = componentsToToon([
 *   { id: 'proxy-mgmt', name: 'Proxy Management', type: 'module',
 *     path: 'iclaude.sh:100-200', description: 'Handle proxy config', layer: 'infrastructure' }
 * ]);
 */
function componentsToToon(components) {
  if (!Array.isArray(components) || components.length === 0) {
    throw new Error('Components must be a non-empty array');
  }

  // Validate required fields
  const requiredFields = ['id', 'name', 'type', 'path', 'description', 'layer'];
  const firstComponent = components[0];
  const missingFields = requiredFields.filter(field => !(field in firstComponent));

  if (missingFields.length > 0) {
    throw new Error(`Missing required fields in components: ${missingFields.join(', ')}`);
  }

  return jsonToToon({ components });
}

/**
 * Convert dependency graph (nodes + edges) to TOON format
 *
 * @param {Array} nodes - Array of node objects
 * @param {string} nodes[].id - Node ID
 * @param {string} nodes[].label - Node label
 * @param {string} nodes[].type - Node type
 * @param {string} nodes[].layer - Architectural layer
 * @param {Array} edges - Array of edge objects
 * @param {string} edges[].from - Source node ID
 * @param {string} edges[].to - Target node ID
 * @param {string} edges[].type - Edge type (required, optional, dev)
 * @param {string} edges[].description - Edge description
 * @returns {string} TOON formatted dependency graph
 *
 * @example
 * const toon = dependencyGraphToToon(
 *   [{ id: 'a', label: 'A', type: 'component', layer: 'business' }],
 *   [{ from: 'a', to: 'b', type: 'required', description: 'Uses B' }]
 * );
 */
function dependencyGraphToToon(nodes, edges) {
  if (!Array.isArray(nodes) || nodes.length === 0) {
    throw new Error('Nodes must be a non-empty array');
  }

  if (!Array.isArray(edges) || edges.length === 0) {
    throw new Error('Edges must be a non-empty array');
  }

  return jsonToToon({ dependency_graph: { nodes, edges } });
}

/**
 * Convert edges array to TOON tabular format
 *
 * @param {Array} edges - Array of edge objects
 * @param {string} edges[].from - Source node ID
 * @param {string} edges[].to - Target node ID
 * @param {string} edges[].type - Edge type
 * @param {string} edges[].description - Edge description
 * @returns {string} TOON formatted edges table
 */
function edgesToToon(edges) {
  if (!Array.isArray(edges) || edges.length === 0) {
    throw new Error('Edges must be a non-empty array');
  }

  return jsonToToon({ edges });
}

/**
 * Calculate token savings between JSON and TOON formats
 *
 * @param {Object} jsonObj - JSON object to compare
 * @returns {Object} Token statistics
 * @returns {number} returns.jsonTokens - Estimated JSON tokens
 * @returns {number} returns.toonTokens - Estimated TOON tokens
 * @returns {number} returns.savedTokens - Absolute token savings
 * @returns {string} returns.savedPercent - Percentage savings (formatted)
 *
 * @example
 * const stats = calculateTokenSavings({ components: [...] });
 * console.log(`Saved ${stats.savedPercent} tokens`);
 */
function calculateTokenSavings(jsonObj) {
  const jsonString = JSON.stringify(jsonObj, null, 2);
  const toonString = jsonToToon(jsonObj);

  // Rough token estimation: ~4 characters per token (GPT tokenizer approximation)
  const jsonTokens = Math.ceil(jsonString.length / 4);
  const toonTokens = Math.ceil(toonString.length / 4);
  const savedTokens = jsonTokens - toonTokens;
  const savedPercent = ((savedTokens / jsonTokens) * 100).toFixed(1) + '%';

  return {
    jsonTokens,
    toonTokens,
    savedTokens,
    savedPercent,
    jsonSize: jsonString.length,
    toonSize: toonString.length
  };
}

/**
 * Validate TOON string for correctness
 *
 * @param {string} toonString - TOON string to validate
 * @returns {Object} Validation result
 * @returns {boolean} returns.valid - Whether TOON is valid
 * @returns {string} returns.error - Error message if invalid
 *
 * @example
 * const result = validateToon('components[1]{id,name}:\n  foo,Foo');
 * if (!result.valid) console.error(result.error);
 */
function validateToon(toonString) {
  try {
    toonToJson(toonString);
    return { valid: true };
  } catch (error) {
    return { valid: false, error: error.message };
  }
}

/**
 * Round-trip test: JSON → TOON → JSON
 *
 * @param {Object} jsonObj - JSON object to test
 * @returns {Object} Test result
 * @returns {boolean} returns.success - Whether round-trip succeeded
 * @returns {string} returns.error - Error message if failed
 * @returns {Object} returns.original - Original JSON (if success)
 * @returns {Object} returns.roundtrip - Round-trip JSON (if success)
 *
 * @example
 * const result = roundTripTest({ components: [...] });
 * console.log(result.success ? 'Lossless!' : 'Failed: ' + result.error);
 */
function roundTripTest(jsonObj) {
  try {
    const toonString = jsonToToon(jsonObj);
    const roundtripJson = toonToJson(toonString);

    // Deep equality check
    const originalStr = JSON.stringify(jsonObj);
    const roundtripStr = JSON.stringify(roundtripJson);

    if (originalStr === roundtripStr) {
      return { success: true, original: jsonObj, roundtrip: roundtripJson };
    } else {
      return {
        success: false,
        error: 'Round-trip data mismatch',
        original: jsonObj,
        roundtrip: roundtripJson
      };
    }
  } catch (error) {
    return { success: false, error: error.message };
  }
}

// Export all functions
export {
  jsonToToon,
  toonToJson,
  componentsToToon,
  dependencyGraphToToon,
  edgesToToon,
  calculateTokenSavings,
  validateToon,
  roundTripTest
};

// CLI mode
if (import.meta.url === `file://${process.argv[1]}`) {
  const args = process.argv.slice(2);
  const command = args[0];

  if (!command || command === '--help' || command === '-h') {
    console.log(`
TOON Converter CLI
Usage: node toon-converter.js <command> [options]

Commands:
  encode <input.json>           Convert JSON file to TOON
  decode <input.toon>           Convert TOON file to JSON
  test <input.json>             Run round-trip test on JSON file
  stats <input.json>            Show token savings statistics

Examples:
  node toon-converter.js encode components.json
  node toon-converter.js decode components.toon
  node toon-converter.js test components.json
  node toon-converter.js stats components.json
    `);
    process.exit(0);
  }

  const inputFile = args[1];

  if (!inputFile) {
    console.error('Error: Input file required');
    process.exit(1);
  }

  try {
    switch (command) {
      case 'encode': {
        const jsonContent = readFileSync(inputFile, 'utf8');
        const jsonObj = JSON.parse(jsonContent);
        const toonString = jsonToToon(jsonObj);
        console.log(toonString);
        break;
      }

      case 'decode': {
        const toonContent = readFileSync(inputFile, 'utf8');
        const jsonObj = toonToJson(toonContent);
        console.log(JSON.stringify(jsonObj, null, 2));
        break;
      }

      case 'test': {
        const jsonContent = readFileSync(inputFile, 'utf8');
        const jsonObj = JSON.parse(jsonContent);
        const result = roundTripTest(jsonObj);

        if (result.success) {
          console.log('✓ Round-trip test passed! Lossless conversion confirmed.');
        } else {
          console.error('✗ Round-trip test failed:', result.error);
          process.exit(1);
        }
        break;
      }

      case 'stats': {
        const jsonContent = readFileSync(inputFile, 'utf8');
        const jsonObj = JSON.parse(jsonContent);
        const stats = calculateTokenSavings(jsonObj);

        console.log(`Token Statistics:
  JSON: ~${stats.jsonTokens} tokens (${stats.jsonSize} bytes)
  TOON: ~${stats.toonTokens} tokens (${stats.toonSize} bytes)
  Saved: ~${stats.savedTokens} tokens (-${stats.savedPercent})
        `);
        break;
      }

      default:
        console.error(`Unknown command: ${command}`);
        process.exit(1);
    }
  } catch (error) {
    console.error('Error:', error.message);
    process.exit(1);
  }
}
