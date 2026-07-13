---
type: official_reference
tool: kubernetes
authority: external_reference
---

Subtracts hugepage capacity from `memory.available` so the kubelet's eviction
signal reflects actual regular-memory availability. Without this gate, hugepage
reservations inflate `AvailableBytes`, delaying eviction and causing OOM kills
on nodes with hugepages configured.
