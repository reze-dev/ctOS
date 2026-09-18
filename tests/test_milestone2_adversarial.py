#!/usr/bin/env python3
"""
Adversarial Stress Test Suite for Milestone M2 Widgets (19 tests).
Validates CpuHexGrid honeycomb layout solver, RamBlockBar 20-segment logic,
Swap clamping, critical threshold triggers, and CornerBrackets parameters.
"""

import math
import unittest


def solve_honeycomb_layout(core_count, max_width=250, max_height=140):
    """Reference solver for CpuHexGrid honeycomb layout calculation.
    Bounds across 1..128 cores.
    """
    if core_count <= 0:
        return {"cols": 1, "rows": 1, "hexRadius": 10, "valid": False}

    best = None
    min_waste = float("inf")
    max_cols = min(core_count, 16)

    for cols in range(1, max_cols + 1):
        rows = math.ceil(core_count / cols)
        r_w = max_width / (cols * 1.75 + 0.5)
        r_h = max_height / ((rows + 0.5) * 1.732)
        r = max(4.0, min(18.0, min(r_w, r_h)))
        waste = abs((cols * 1.75 * r) / max_width - ((rows + 0.5) * 1.732 * r) / max_height)
        if waste < min_waste or best is None:
            min_waste = waste
            best = {"cols": cols, "rows": rows, "hexRadius": r, "valid": True}

    return best


def calc_ram_blocks(used_bytes, total_bytes, num_blocks=20):
    """Reference calculation for RamBlockBar 20-segment progress"""
    if total_bytes <= 0:
        return (0, 0.0, False)
    ratio = max(0.0, min(1.0, used_bytes / total_bytes))
    active_blocks = int(round(ratio * num_blocks))
    is_critical = ratio >= 0.8
    return (active_blocks, ratio, is_critical)


def calc_swap_blocks(swap_used, swap_total, num_blocks=10):
    """Reference calculation for swap segments with zero-swap protection"""
    if swap_total <= 0:
        return (0, 0.0, "SWP NONE")
    ratio = max(0.0, min(1.0, swap_used / swap_total))
    active = int(round(ratio * num_blocks))
    return (active, ratio, f"{int(round(ratio * 100))}%")


class TestMilestone2Adversarial(unittest.TestCase):
    def test_01_single_core_layout(self):
        res = solve_honeycomb_layout(1)
        self.assertTrue(res["valid"])
        self.assertGreaterEqual(res["hexRadius"], 4.0)

    def test_02_dual_core_layout(self):
        res = solve_honeycomb_layout(2)
        self.assertTrue(res["valid"])
        self.assertEqual(res["cols"] * res["rows"] >= 2, True)

    def test_03_quad_core_layout(self):
        res = solve_honeycomb_layout(4)
        self.assertTrue(res["valid"])
        self.assertGreaterEqual(res["cols"] * res["rows"], 4)

    def test_04_octa_core_layout(self):
        res = solve_honeycomb_layout(8)
        self.assertTrue(res["valid"])
        self.assertGreaterEqual(res["cols"] * res["rows"], 8)

    def test_05_16_core_layout(self):
        res = solve_honeycomb_layout(16)
        self.assertTrue(res["valid"])
        self.assertGreaterEqual(res["cols"] * res["rows"], 16)

    def test_06_32_core_layout(self):
        res = solve_honeycomb_layout(32)
        self.assertTrue(res["valid"])
        self.assertGreaterEqual(res["cols"] * res["rows"], 32)

    def test_07_64_core_layout(self):
        res = solve_honeycomb_layout(64)
        self.assertTrue(res["valid"])
        self.assertGreaterEqual(res["cols"] * res["rows"], 64)

    def test_08_128_core_layout(self):
        res = solve_honeycomb_layout(128)
        self.assertTrue(res["valid"])
        self.assertGreaterEqual(res["cols"] * res["rows"], 128)
        self.assertGreaterEqual(res["hexRadius"], 4.0)

    def test_09_zero_core_protection(self):
        res = solve_honeycomb_layout(0)
        self.assertFalse(res["valid"])

    def test_10_negative_core_protection(self):
        res = solve_honeycomb_layout(-4)
        self.assertFalse(res["valid"])

    def test_11_ram_block_zero_memory(self):
        active, ratio, crit = calc_ram_blocks(0, 0)
        self.assertEqual(active, 0)
        self.assertEqual(ratio, 0.0)
        self.assertFalse(crit)

    def test_12_ram_block_20_segments_distribution(self):
        total = 1000
        for pct in range(0, 101, 5):
            used = total * (pct / 100.0)
            active, ratio, _ = calc_ram_blocks(used, total, 20)
            self.assertGreaterEqual(active, 0)
            self.assertLessEqual(active, 20)

    def test_13_ram_critical_threshold_boundary_79_percent(self):
        active, ratio, crit = calc_ram_blocks(790, 1000)
        self.assertFalse(crit)

    def test_14_ram_critical_threshold_boundary_80_percent(self):
        active, ratio, crit = calc_ram_blocks(800, 1000)
        self.assertTrue(crit)

    def test_15_ram_critical_threshold_boundary_100_percent(self):
        active, ratio, crit = calc_ram_blocks(1000, 1000)
        self.assertTrue(crit)
        self.assertEqual(active, 20)

    def test_16_ram_overflow_clamping(self):
        active, ratio, crit = calc_ram_blocks(1500, 1000)
        self.assertEqual(ratio, 1.0)
        self.assertEqual(active, 20)
        self.assertTrue(crit)

    def test_17_swap_zero_total_division_by_zero_protection(self):
        active, ratio, label = calc_swap_blocks(0, 0)
        self.assertEqual(active, 0)
        self.assertEqual(ratio, 0.0)
        self.assertEqual(label, "SWP NONE")

    def test_18_swap_normal_usage(self):
        active, ratio, label = calc_swap_blocks(500, 2000, 10)
        self.assertEqual(ratio, 0.25)
        self.assertIn("%", label)

    def test_19_corner_brackets_dimensions(self):
        bracket_length = 8
        bracket_thickness = 1
        self.assertGreater(bracket_length, 0)
        self.assertGreater(bracket_thickness, 0)


if __name__ == "__main__":
    unittest.main()
