#!/usr/bin/env python3
"""
Adversarial Stress Test Suite for SystemMonitorService (20 tests).
Validates mathematical boundary conditions, zero-division protection,
counter-wrap resilience, 128-core scaling, and procfs parsing logic.
"""

import math
import unittest


def parse_cpu_stat(raw_text, prev_cpu_totals=None):
    """Reference implementation of SystemMonitorService._parseCpuStat"""
    if not raw_text or not raw_text.strip():
        return (0.0, [])

    lines = raw_text.strip().split("\n")
    cpu_total = 0.0
    thread_loads = []

    for line in lines:
        line = line.strip()
        if not line.startswith("cpu"):
            continue

        parts = line.split()
        if len(parts) < 5:
            continue

        label = parts[0]
        try:
            user = float(parts[1])
            nice = float(parts[2])
            system = float(parts[3])
            idle = float(parts[4])
            iowait = float(parts[5]) if len(parts) > 5 else 0.0
            irq = float(parts[6]) if len(parts) > 6 else 0.0
            softirq = float(parts[7]) if len(parts) > 7 else 0.0
            steal = float(parts[8]) if len(parts) > 8 else 0.0
        except ValueError:
            continue

        idle_all = idle + iowait
        system_all = system + irq + softirq
        virt_all = steal
        total = user + nice + system_all + idle_all + virt_all
        busy = total - idle_all

        load = 0.0
        if prev_cpu_totals is not None and label in prev_cpu_totals:
            p_total, p_busy = prev_cpu_totals[label]
            delta_total = total - p_total
            delta_busy = busy - p_busy
            if delta_total > 0:
                load = max(0.0, min(1.0, delta_busy / delta_total))
        elif total > 0:
            load = max(0.0, min(1.0, busy / total))

        if label == "cpu":
            cpu_total = load
        elif label.startswith("cpu") and label[3:].isdigit():
            thread_loads.append(load)

    return (cpu_total, thread_loads)


def parse_meminfo(raw_text):
    """Reference implementation of SystemMonitorService._parseMemInfo"""
    if not raw_text or not raw_text.strip():
        return (0, 0, 0, 0)

    mem_total = 0
    mem_avail = 0
    swap_total = 0
    swap_free = 0

    for line in raw_text.strip().split("\n"):
        parts = line.split(":")
        if len(parts) < 2:
            continue
        key = parts[0].strip()
        tokens = parts[1].strip().split()
        if not tokens:
            continue
        val_str = tokens[0]
        try:
            val_kb = float(val_str)
        except ValueError:
            continue
        val_bytes = val_kb * 1024

        if key == "MemTotal":
            mem_total = val_bytes
        elif key == "MemAvailable":
            mem_avail = val_bytes
        elif key == "SwapTotal":
            swap_total = val_bytes
        elif key == "SwapFree":
            swap_free = val_bytes

    mem_used = max(0.0, mem_total - mem_avail)
    swap_used = max(0.0, swap_total - swap_free)
    return (mem_used, mem_total, swap_used, swap_total)


def format_bytes(bytes_val):
    """Reference implementation of SystemMonitorService.formatBytes"""
    if bytes_val is None:
        return "0 B"
    try:
        b = float(bytes_val)
    except (ValueError, TypeError):
        return "0 B"
    if math.isnan(b) or b <= 0:
        return "0 B"
    units = ["B", "KB", "MB", "GB", "TB"]
    i = 0
    while b >= 1024.0 and i < len(units) - 1:
        b /= 1024.0
        i += 1
    if i == 0:
        return f"{int(b)} B"
    return f"{b:.1f} {units[i]}"


def parse_net_dev(raw_text, prev_rx=-1, prev_tx=-1, elapsed_sec=1.0):
    """Reference implementation of SystemMonitorService._parseNetDev"""
    if not raw_text or not raw_text.strip():
        return (0.0, 0.0, 0, 0)

    lines = raw_text.strip().split("\n")
    aggregate_rx = 0
    aggregate_tx = 0

    for line in lines[2:] if len(lines) > 2 else lines:
        line = line.strip()
        if not line or ":" not in line:
            continue
        colon_idx = line.find(":")
        iface = line[:colon_idx].strip()
        if iface == "lo":
            continue
        stats_part = line[colon_idx + 1:].strip()
        cols = stats_part.split()
        if len(cols) < 9:
            continue
        try:
            rx = int(cols[0])
            tx = int(cols[8])
        except ValueError:
            continue
        aggregate_rx += rx
        aggregate_tx += tx

    rx_rate = 0.0
    tx_rate = 0.0
    if prev_rx >= 0 and prev_tx >= 0 and elapsed_sec > 0.1:
        delta_rx = aggregate_rx - prev_rx
        delta_tx = aggregate_tx - prev_tx
        rx_rate = delta_rx / elapsed_sec if delta_rx >= 0 else 0.0
        tx_rate = delta_tx / elapsed_sec if delta_tx >= 0 else 0.0

    return (rx_rate, tx_rate, aggregate_rx, aggregate_tx)


class TestSystemMonitorAdversarial(unittest.TestCase):
    def test_01_empty_stat(self):
        total, threads = parse_cpu_stat("")
        self.assertEqual(total, 0.0)
        self.assertEqual(threads, [])

    def test_02_corrupted_stat(self):
        total, threads = parse_cpu_stat("cpu invalid tokens not numbers\n")
        self.assertEqual(total, 0.0)
        self.assertEqual(threads, [])

    def test_03_zero_delta_division_protection(self):
        prev = {"cpu": (1000, 500)}
        raw = "cpu 100 0 100 800 0 0 0 0\n"
        total, threads = parse_cpu_stat(raw, prev)
        self.assertEqual(total, 0.0)

    def test_04_negative_delta_counter_wrap(self):
        prev = {"cpu": (2000, 1000)}
        raw = "cpu 100 0 100 800 0 0 0 0\n"
        total, threads = parse_cpu_stat(raw, prev)
        self.assertEqual(total, 0.0)

    def test_05_load_clamped_upper(self):
        prev = {"cpu": (1000, 200)}
        raw = "cpu 800 0 800 0 0 0 0 0\n"
        total, _ = parse_cpu_stat(raw, prev)
        self.assertLessEqual(total, 1.0)

    def test_06_load_clamped_lower(self):
        prev = {"cpu": (1000, 500)}
        raw = "cpu 100 0 0 1000 0 0 0 0\n"
        total, _ = parse_cpu_stat(raw, prev)
        self.assertGreaterEqual(total, 0.0)

    def test_07_scaling_128_cores(self):
        lines = ["cpu 128000 0 64000 500000 0 0 0 0"]
        prev = {"cpu": (0, 0)}
        for c in range(128):
            lines.append(f"cpu{c} 1000 0 500 4000 0 0 0 0")
            prev[f"cpu{c}"] = (0, 0)
        raw = "\n".join(lines)
        total, threads = parse_cpu_stat(raw, prev)
        self.assertEqual(len(threads), 128)
        self.assertTrue(all(0.0 <= l <= 1.0 for l in threads))

    def test_08_empty_meminfo(self):
        used, total, s_used, s_total = parse_meminfo("")
        self.assertEqual(used, 0)
        self.assertEqual(total, 0)
        self.assertEqual(s_used, 0)
        self.assertEqual(s_total, 0)

    def test_09_corrupt_meminfo(self):
        raw = "MemTotal: corrupted kB\nSwapTotal: ??? kB\n"
        used, total, s_used, s_total = parse_meminfo(raw)
        self.assertEqual(used, 0)
        self.assertEqual(total, 0)

    def test_10_missing_swap_meminfo(self):
        raw = "MemTotal: 16384000 kB\nMemAvailable: 8192000 kB\nSwapTotal: 0 kB\nSwapFree: 0 kB\n"
        used, total, s_used, s_total = parse_meminfo(raw)
        self.assertEqual(total, 16777216000)
        self.assertEqual(used, 8388608000)
        self.assertEqual(s_used, 0)
        self.assertEqual(s_total, 0)

    def test_11_mem_available_greater_than_total(self):
        raw = "MemTotal: 8000 kB\nMemAvailable: 10000 kB\n"
        used, total, _, _ = parse_meminfo(raw)
        self.assertEqual(used, 0)
        # Fuzz test lines with missing values (e.g. "MemTotal:\n", "::::\n")
        fuzz_used, fuzz_total, fuzz_s_used, fuzz_s_total = parse_meminfo("MemTotal:\nMemAvailable:\nSwapTotal:\nSwapFree:\n")
        self.assertEqual(fuzz_total, 0)
        self.assertEqual(fuzz_used, 0)
        self.assertEqual(fuzz_s_total, 0)
        self.assertEqual(fuzz_s_used, 0)
        fuzz_empty_colons = parse_meminfo(":::::\n\n::::\n")
        self.assertEqual(fuzz_empty_colons, (0, 0, 0, 0))

    def test_12_format_bytes_zero(self):
        self.assertEqual(format_bytes(0), "0 B")
        self.assertEqual(format_bytes(-50), "0 B")
        self.assertEqual(format_bytes(None), "0 B")
        self.assertEqual(format_bytes(float("nan")), "0 B")
        self.assertEqual(format_bytes(math.nan), "0 B")

    def test_13_format_bytes_small(self):
        self.assertEqual(format_bytes(512), "512 B")
        self.assertEqual(format_bytes(1023), "1023 B")

    def test_14_format_bytes_kb(self):
        self.assertEqual(format_bytes(1024), "1.0 KB")
        self.assertEqual(format_bytes(2048), "2.0 KB")

    def test_15_format_bytes_mb(self):
        self.assertEqual(format_bytes(1048576), "1.0 MB")
        self.assertEqual(format_bytes(13002342.4), "12.4 MB")

    def test_16_format_bytes_gb(self):
        self.assertEqual(format_bytes(1073741824), "1.0 GB")
        self.assertEqual(format_bytes(17179869184.0), "16.0 GB")

    def test_17_format_bytes_tb(self):
        self.assertEqual(format_bytes(1099511627776), "1.0 TB")

    def test_18_debounce_interval_guard(self):
        sample = (
            "Inter-|   Receive                                                |  Transmit\n"
            " face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed\n"
            "  eth0: 1048576       0    0    0    0     0          0         0   524288       0    0    0    0     0       0          0\n"
        )
        # With elapsed_sec <= 0.1, rate calculation is debounced (returns 0.0)
        rx_rate, tx_rate, rx_tot, tx_tot = parse_net_dev(sample, prev_rx=0, prev_tx=0, elapsed_sec=0.05)
        self.assertEqual(rx_rate, 0.0)
        self.assertEqual(tx_rate, 0.0)
        self.assertEqual(rx_tot, 1048576)
        self.assertEqual(tx_tot, 524288)

        # With elapsed_sec > 0.1, rate is computed
        rx_rate, tx_rate, _, _ = parse_net_dev(sample, prev_rx=0, prev_tx=0, elapsed_sec=1.0)
        self.assertEqual(rx_rate, 1048576.0)
        self.assertEqual(tx_rate, 524288.0)

    def test_19_rx_tx_counter_wrap(self):
        # When 32-bit counter wraps around (curr < prev), rate is clamped to 0.0 instead of negative
        sample = (
            "Inter-|   Receive                                                |  Transmit\n"
            " face |bytes    packets errs drop fifo frame compressed multicast|bytes    packets errs drop fifo colls carrier compressed\n"
            "  eth0:    5000       0    0    0    0     0          0         0     5000       0    0    0    0     0       0          0\n"
        )
        prev_rx = 4000000000
        prev_tx = 4000000000
        rx_rate, tx_rate, rx_tot, tx_tot = parse_net_dev(sample, prev_rx=prev_rx, prev_tx=prev_tx, elapsed_sec=1.0)
        self.assertEqual(rx_rate, 0.0)
        self.assertEqual(tx_rate, 0.0)
        self.assertEqual(rx_tot, 5000)
        self.assertEqual(tx_tot, 5000)

    def test_20_multi_thread_irregular_indices(self):
        raw = "cpu 100 0 50 200\ncpu0 50 0 25 100\ncpu2 50 0 25 100\n"
        _, threads = parse_cpu_stat(raw)
        self.assertEqual(len(threads), 2)


if __name__ == "__main__":
    unittest.main()
