#!/usr/bin/env python3
"""
merge_xmltv.py — Merge multiple XMLTV part files into one valid xmltv.xml.

Usage:
    python3 merge_xmltv.py <output.xml> <part1.xml> [part2.xml ...]

Each part file is a complete XMLTV document with a <tv> root element.
This script parses each one properly and appends all <channel> and
<programme> child elements into a single merged <tv> root.
"""

import sys
import xml.etree.ElementTree as ET
from pathlib import Path


def merge(output_path: str, part_files: list[str]) -> None:
    root = ET.Element("tv")

    for part in part_files:
        p = Path(part)
        if not p.exists():
            print(f"[merge_xmltv] WARNING: part file not found, skipping: {part}", flush=True)
            continue
        try:
            tree = ET.parse(str(p))
            tv = tree.getroot()
            if tv.tag != "tv":
                print(f"[merge_xmltv] WARNING: root tag is <{tv.tag}>, expected <tv> — skipping {part}", flush=True)
                continue
            count = 0
            for child in tv:
                root.append(child)
                count += 1
            print(f"[merge_xmltv] Merged {count} elements from {part}", flush=True)
        except ET.ParseError as e:
            print(f"[merge_xmltv] ERROR: failed to parse {part}: {e}", flush=True)
            sys.exit(1)

    tree_out = ET.ElementTree(root)
    try:
        ET.indent(tree_out, space="  ")
    except AttributeError:
        pass  # Python < 3.9

    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    tree_out.write(output_path, encoding="utf-8", xml_declaration=True)
    print(f"[merge_xmltv] Wrote merged XMLTV → {output_path} ({len(list(root))} total elements)", flush=True)


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <output.xml> <part1.xml> [part2.xml ...]")
        sys.exit(1)
    merge(sys.argv[1], sys.argv[2:])
