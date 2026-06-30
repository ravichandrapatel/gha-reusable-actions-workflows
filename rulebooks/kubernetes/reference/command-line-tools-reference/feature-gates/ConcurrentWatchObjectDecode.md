---
type: official_reference
tool: kubernetes
authority: external_reference
---

Enable concurrent watch object decoding. This is to avoid starving the API server's
watch cache when a conversion webhook is installed.
