---
source_file: "tests/test_patterns_examples.py"
type: "rationale"
community: "mask_token"
location: "L607"
tags:
  - graphify/rationale
  - graphify/EXTRACTED
  - community/mask_token
---

# ${var+x} idiom: empty PII_PROXY_MASK_TOKEN is SET, not missing.

## Connections
- [[.test_env_empty_string_is_set()]] - `rationale_for` [EXTRACTED]

#graphify/rationale #graphify/EXTRACTED #community/mask_token