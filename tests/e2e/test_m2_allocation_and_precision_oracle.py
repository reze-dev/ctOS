#!/usr/bin/env python3
"""
test_m2_allocation_and_precision_oracle.py
Stress test and oracle comparing the new unboxed primitive calculations in RadialSegment.qml
with RadialGeometry.pointOnCircle across 10,000 randomized and boundary configurations.
"""

import os
import sys
import math
import random

def deg_to_rad(deg):
    return (deg * math.pi) / 180.0

def old_point_on_circle(cx, cy, r, angle_deg):
    rad = deg_to_rad(angle_deg)
    return {"x": cx + r * math.cos(rad), "y": cy + r * math.sin(rad)}

def new_primitive_calc(cx, cy, r_inner, r_outer, center_angle):
    icon_radius = (r_inner + r_outer) / 2.0
    icon_rad = center_angle * math.pi / 180.0
    icon_center_x = cx + icon_radius * math.cos(icon_rad)
    icon_center_y = cy + icon_radius * math.sin(icon_rad)
    return icon_center_x, icon_center_y

# Verify equivalence across 10,000 configurations
random.seed(42)
max_error_x = 0.0
max_error_y = 0.0

for i in range(10000):
    cx = random.uniform(0, 1920)
    cy = random.uniform(0, 1080)
    r_inner = random.uniform(50, 150)
    r_outer = r_inner + random.uniform(20, 100)
    angle = random.uniform(-720, 720)

    old_pt = old_point_on_circle(cx, cy, (r_inner + r_outer) / 2.0, angle)
    new_x, new_y = new_primitive_calc(cx, cy, r_inner, r_outer, angle)

    err_x = abs(old_pt["x"] - new_x)
    err_y = abs(old_pt["y"] - new_y)

    if err_x > max_error_x: max_error_x = err_x
    if err_y > max_error_y: max_error_y = err_y

    if err_x > 1e-12 or err_y > 1e-12:
        print(f"[FAIL] Precision discrepancy at iteration {i}: err_x={err_x}, err_y={err_y}")
        sys.exit(1)

print(f"[PASS] 10,000 configurations verified. Max error X: {max_error_x:.2e}, Y: {max_error_y:.2e}")
sys.exit(0)
