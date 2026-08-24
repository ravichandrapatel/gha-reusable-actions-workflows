#!/usr/bin/env python3
"""Unit tests for resolve-node-version action."""

from __future__ import annotations

import unittest

from resolve_node_version import resolve_node_version


class ResolveNodeVersionTests(unittest.TestCase):
    def test_range_picks_highest_below_exclusive_upper(self) -> None:
        self.assertEqual(resolve_node_version(">=18.20.0 <22.0.0"), "21")

    def test_simple_version_unchanged(self) -> None:
        self.assertEqual(resolve_node_version("20.11.1"), "20.11.1")

    def test_upper_bound_below_lower_uses_lower(self) -> None:
        self.assertEqual(resolve_node_version(">=18.20.0 <19.0.0"), "18.20")


if __name__ == "__main__":
    unittest.main()
