#!/usr/bin/env python3
"""
merge_xmltv.py — Merge multiple XMLTV part files into one valid xmltv.xml.
Usage: python3 merge_xmltv.py <output.xml> <part1.xml> [part2.xml ...]
"""
import sys
import xml.etree.ElementTree as ET
from pathlib import Path


def merge(output_path, part_files):
    root = ET.Element("tv")
    for part in part_files:
        p = Path(part)
        if not p.exists():
            print(f"[merge_xmltv] WARNING: not found, skipping: {part}", flush=True)
            continue
        try:
            tv = ET.parse(str(p)).getroot()
            if tv.tag != "tv":
                print(f"[merge_xmltv] WARNING: root <{tv.tag}> != <tv>, skipping {part}", flush=True)
                continue
            count = sum(1 for _ in (root.append(child) or [child] for child in tv))
            print(f"[merge_xmltv] Merged {len(list(tv))} elements from {p.name}", flush=True)
        except ET.ParseError as e:
            print(f"[merge_xmltv] ERROR: parse failed {part}: {e}", flush=True)
            sys.exit(1)

    try:
        ET.indent(root, space="  ")
    except AttributeError:
        pass

    Path(output_path).parent.mkdir(parents=True, exist_ok=True)
    ET.ElementTree(root).write(output_path, encoding="utf-8", xml_declaration=True)
    print(f"[merge_xmltv] Wrote {output_path} ({len(list(root))} total elements)", flush=True)


if __name__ == "__main__":
    if len(sys.argv) < 3:
        print(f"Usage: {sys.argv[0]} <output.xml> <part1.xml> [part2.xml ...]")
        sys.exit(1)
    merge(sys.argv[1], sys.argv[2:])
