#!/usr/bin/env python3
"""
qml_inspector.py - Static and contract inspection tool for ctOS QML files.

Provides deterministic parsing and validation of QML components, properties,
methods, signals, imports, boundary constraints, and banned patterns.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple


def strip_comments(text: str) -> str:
    """Strip single-line and multi-line comments from QML text."""
    # Remove block comments
    text = re.sub(r'/\*.*?\*/', '', text, flags=re.DOTALL)
    # Remove line comments
    text = re.sub(r'//.*$', '', text, flags=re.MULTILINE)
    return text


def find_properties(text: str) -> Dict[str, Dict[str, Any]]:
    """
    Extract property declarations from QML.
    Matches: [readonly] property [type] [name]: [default_val]
    """
    cleaned = strip_comments(text)
    pattern = re.compile(
        r'(?:(readonly)\s+)?property\s+([A-Za-z0-9_<>]+)\s+([A-Za-z0-9_]+)(?:\s*:\s*([^;\n]+))?',
        re.MULTILINE
    )
    props = {}
    for match in pattern.finditer(cleaned):
        readonly = bool(match.group(1))
        prop_type = match.group(2)
        prop_name = match.group(3)
        default_val = match.group(4).strip() if match.group(4) else None
        props[prop_name] = {
            "type": prop_type,
            "readonly": readonly,
            "default": default_val
        }
    return props


def find_methods(text: str) -> List[str]:
    """Extract declared function/method names from QML."""
    cleaned = strip_comments(text)
    pattern = re.compile(
        r'function\s+([A-Za-z0-9_]+)\s*\(([^)]*)\)',
        re.MULTILINE
    )
    methods = []
    for match in pattern.finditer(cleaned):
        methods.append(match.group(1))
    return methods


def find_signals(text: str) -> List[str]:
    """Extract declared signal names from QML."""
    cleaned = strip_comments(text)
    pattern = re.compile(
        r'signal\s+([A-Za-z0-9_]+)(?:\s*\(([^)]*)\))?',
        re.MULTILINE
    )
    signals = []
    for match in pattern.finditer(cleaned):
        signals.append(match.group(1))
    return signals


def find_imports(text: str) -> List[str]:
    """Extract all import statements from QML."""
    cleaned = strip_comments(text)
    pattern = re.compile(r'import\s+([^\n;]+)', re.MULTILINE)
    return [match.group(1).strip() for match in pattern.finditer(cleaned)]


def check_greeter_imports(path: Path) -> List[Tuple[str, int, str]]:
    """Scan directory or file for any import referencing greeter."""
    violations = []
    files_to_check = []
    if path.is_file():
        files_to_check.append(path)
    elif path.is_dir():
        for root, _, files in os.walk(path):
            for f in files:
                if f.endswith('.qml') or f.endswith('.js'):
                    files_to_check.append(Path(root) / f)

    for fpath in files_to_check:
        try:
            with open(fpath, 'r', encoding='utf-8') as f:
                for idx, line in enumerate(f, 1):
                    # Check for import of greeter
                    if re.search(r'import\s+.*greeter', line, re.IGNORECASE):
                        violations.append((str(fpath), idx, line.strip()))
                    # Also check for direct path reference to greeter config or resources
                    if re.search(r'["\'][^"\']*greeter[^"\']*["\']', line, re.IGNORECASE):
                        violations.append((str(fpath), idx, line.strip()))
        except Exception as e:
            violations.append((str(fpath), 0, f"Error reading file: {e}"))
    return violations


def check_polling_loops(path: Path) -> List[Tuple[str, int, str]]:
    """
    Scan for forbidden polling loops:
    - Process with `running: true`
    - `while true; do ... sleep`
    - `sh -c "echo ..."`
    """
    violations = []
    files_to_check = []
    if path.is_file():
        files_to_check.append(path)
    elif path.is_dir():
        for root, _, files in os.walk(path):
            for f in files:
                if f.endswith('.qml') or f.endswith('.js'):
                    files_to_check.append(Path(root) / f)

    for fpath in files_to_check:
        try:
            content = fpath.read_text(encoding='utf-8')
            # Check for Process { ... running: true ... }
            if re.search(r'Process\s*\{[^}]*running\s*:\s*true', content, re.DOTALL):
                violations.append((str(fpath), 1, "Persistent Process loop with running: true detected"))
            # Check for while true in shell strings
            if re.search(r'while\s+true\s*;', content):
                violations.append((str(fpath), 1, "Shell while-loop detected"))
            # Check for sh -c
            if re.search(r'["\']sh["\']\s*,\s*["\']-c["\']', content):
                violations.append((str(fpath), 1, "Spawning subshell via sh -c detected"))
        except Exception as e:
            violations.append((str(fpath), 0, f"Error reading file: {e}"))
    return violations


def check_formatting(path: Path) -> List[Tuple[str, int, str]]:
    """Check .qmlformat.ini compliance: 4 spaces indentation, no tabs, Unix newlines."""
    violations = []
    files_to_check = []
    if path.is_file():
        files_to_check.append(path)
    elif path.is_dir():
        for root, _, files in os.walk(path):
            for f in files:
                if f.endswith('.qml'):
                    files_to_check.append(Path(root) / f)

    for fpath in files_to_check:
        try:
            raw_bytes = fpath.read_bytes()
            if b'\r\n' in raw_bytes:
                violations.append((str(fpath), 1, "Windows CRLF newline detected (must be LF)"))
            lines = raw_bytes.decode('utf-8').split('\n')
            for idx, line in enumerate(lines, 1):
                if '\t' in line:
                    violations.append((str(fpath), idx, "Tab character found (must use 4 spaces)"))
                    break
        except Exception as e:
            violations.append((str(fpath), 0, f"Error reading file: {e}"))
    return violations


def main():
    parser = argparse.ArgumentParser(description="QML Contract Inspector")
    subparsers = parser.add_subparsers(dest="command", required=True)

    # Command: has-property
    p_prop = subparsers.add_parser("has-property")
    p_prop.add_argument("file", type=Path)
    p_prop.add_argument("property_name")
    p_prop.add_argument("--type", dest="expected_type", default=None)
    p_prop.add_argument("--readonly", action="store_true")

    # Command: has-method
    p_meth = subparsers.add_parser("has-method")
    p_meth.add_argument("file", type=Path)
    p_meth.add_argument("method_name")

    # Command: has-signal
    p_sig = subparsers.add_parser("has-signal")
    p_sig.add_argument("file", type=Path)
    p_sig.add_argument("signal_name")

    # Command: check-greeter
    p_greet = subparsers.add_parser("check-greeter")
    p_greet.add_argument("target", type=Path)

    # Command: check-polling
    p_poll = subparsers.add_parser("check-polling")
    p_poll.add_argument("target", type=Path)

    # Command: check-format
    p_fmt = subparsers.add_parser("check-format")
    p_fmt.add_argument("target", type=Path)

    # Command: dump-contract
    p_dump = subparsers.add_parser("dump-contract")
    p_dump.add_argument("file", type=Path)

    args = parser.parse_args()

    if args.command == "has-property":
        if not args.file.exists():
            print(f"Error: File {args.file} does not exist", file=sys.stderr)
            sys.exit(2)
        content = args.file.read_text(encoding='utf-8')
        props = find_properties(content)
        if args.property_name not in props:
            print(f"Property '{args.property_name}' not found in {args.file}")
            sys.exit(1)
        prop_info = props[args.property_name]
        if args.expected_type and prop_info["type"].lower() != args.expected_type.lower():
            print(f"Property '{args.property_name}' has type '{prop_info['type']}', expected '{args.expected_type}'")
            sys.exit(1)
        if args.readonly and not prop_info["readonly"]:
            print(f"Property '{args.property_name}' is not readonly")
            sys.exit(1)
        print(f"OK: Property '{args.property_name}' matches ({prop_info})")
        sys.exit(0)

    elif args.command == "has-method":
        if not args.file.exists():
            print(f"Error: File {args.file} does not exist", file=sys.stderr)
            sys.exit(2)
        content = args.file.read_text(encoding='utf-8')
        methods = find_methods(content)
        if args.method_name not in methods:
            print(f"Method '{args.method_name}' not found in {args.file}")
            sys.exit(1)
        print(f"OK: Method '{args.method_name}' found")
        sys.exit(0)

    elif args.command == "has-signal":
        if not args.file.exists():
            print(f"Error: File {args.file} does not exist", file=sys.stderr)
            sys.exit(2)
        content = args.file.read_text(encoding='utf-8')
        signals = find_signals(content)
        if args.signal_name not in signals:
            print(f"Signal '{args.signal_name}' not found in {args.file}")
            sys.exit(1)
        print(f"OK: Signal '{args.signal_name}' found")
        sys.exit(0)

    elif args.command == "check-greeter":
        if not args.target.exists():
            print(f"Target {args.target} does not exist (clean pass)")
            sys.exit(0)
        violations = check_greeter_imports(args.target)
        if violations:
            print(f"Found {len(violations)} greeter isolation violations:")
            for v in violations:
                print(f"  {v[0]}:{v[1]}: {v[2]}")
            sys.exit(1)
        print("OK: Zero greeter imports or references found")
        sys.exit(0)

    elif args.command == "check-polling":
        if not args.target.exists():
            print(f"Target {args.target} does not exist (clean pass)")
            sys.exit(0)
        violations = check_polling_loops(args.target)
        if violations:
            print(f"Found {len(violations)} polling loop violations:")
            for v in violations:
                print(f"  {v[0]}:{v[1]}: {v[2]}")
            sys.exit(1)
        print("OK: Zero polling loops or persistent shell processes found")
        sys.exit(0)

    elif args.command == "check-format":
        if not args.target.exists():
            print(f"Target {args.target} does not exist")
            sys.exit(2)
        violations = check_formatting(args.target)
        if violations:
            print(f"Found {len(violations)} formatting violations:")
            for v in violations:
                print(f"  {v[0]}:{v[1]}: {v[2]}")
            sys.exit(1)
        print("OK: All files adhere to formatting rules")
        sys.exit(0)

    elif args.command == "dump-contract":
        if not args.file.exists():
            print(f"Error: File {args.file} does not exist", file=sys.stderr)
            sys.exit(2)
        content = args.file.read_text(encoding='utf-8')
        data = {
            "file": str(args.file),
            "imports": find_imports(content),
            "properties": find_properties(content),
            "methods": find_methods(content),
            "signals": find_signals(content)
        }
        print(json.dumps(data, indent=2))
        sys.exit(0)


if __name__ == "__main__":
    main()
