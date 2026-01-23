#!/usr/bin/env node

/**
 * TOON Converter - Wrapper for architecture-documentation skill
 *
 * This is a re-export wrapper around centralized toon-skill converter.
 * Maintains backward compatibility for architecture-documentation skill.
 *
 * @deprecated Use toon-skill directly for new code:
 *   import { ... } from '../../toon-skill/converters/toon-converter.mjs';
 *
 * @module toon-converter
 * @version 2.0.0
 */

// Re-export all functions from centralized toon-skill
export {
  // Generic converters
  jsonToToon,
  toonToJson,
  arrayToToon,
  nestedToToon,

  // Specialized converters (for architecture-documentation)
  componentsToToon,
  dependencyGraphToToon,
  edgesToToon,

  // Utilities
  calculateTokenSavings,
  validateToon,
  roundTripTest
} from '../../toon-skill/converters/toon-converter.mjs';
