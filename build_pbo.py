#!/usr/bin/env python3
"""
PBO Packer for PRA3 Server Addon
Packs the serverAddons/PRA3_Rewrite/addons/PRA3_Server directory into a PBO file.

Usage:
    python3 build_pbo.py [--output PATH]

PBO format reference:
    https://community.bistudio.com/wiki/PBO_File_Format
"""

import argparse
import hashlib
import os
import struct
import sys
from pathlib import Path

# --- PBO binary helpers ---

def write_asciiz(fp, text):
    """Write a null-terminated ASCII string."""
    fp.write(text.encode("ascii") + b"\x00")

def write_header_entry(fp, filename, packing=0, original_size=0, reserved=0, timestamp=0, data_size=0):
    """Write a single PBO header entry."""
    write_asciiz(fp, filename)
    fp.write(struct.pack("<IIIII", packing, original_size, reserved, timestamp, data_size))

def write_header_boundary(fp):
    """Write the empty entry that marks end of header."""
    write_header_entry(fp, "", packing=0, original_size=0, reserved=0, timestamp=0, data_size=0)

def collect_files(source_dir):
    """Collect all files from source directory, returning list of (relative_path, absolute_path, size)."""
    source = Path(source_dir)
    entries = []
    for filepath in sorted(source.rglob("*")):
        if filepath.is_file():
            rel = filepath.relative_to(source)
            # PBO uses backslash paths
            pbo_path = str(rel).replace("/", "\\")
            size = filepath.stat().st_size
            entries.append((pbo_path, str(filepath), size))
    return entries

def read_prefix(source_dir):
    """Read the $PBOPREFIX$ file if it exists."""
    prefix_file = Path(source_dir) / "$PBOPREFIX$"
    if prefix_file.exists():
        return prefix_file.read_text().strip()
    return ""

def build_pbo(source_dir, output_path):
    """Build a PBO file from source directory."""
    prefix = read_prefix(source_dir)
    entries = collect_files(source_dir)

    # Filter out $PBOPREFIX$ from entries (it's metadata, not packed as a file)
    entries = [(p, a, s) for p, a, s in entries if p != "$PBOPREFIX$"]

    print(f"[PBO] Source:  {source_dir}")
    print(f"[PBO] Prefix:  {prefix}")
    print(f"[PBO] Files:   {len(entries)}")
    print(f"[PBO] Output:  {output_path}")

    with open(output_path, "wb") as fp:
        # --- Write header ---

        # First entry: prefix property (special entry with packing type 0x56657273 = "Vers")
        write_asciiz(fp, "")  # empty filename for properties entry
        fp.write(struct.pack("<IIIII", 0x56657273, 0, 0, 0, 0))
        # Write prefix property
        write_asciiz(fp, "prefix")
        write_asciiz(fp, prefix)

        # Write file entries
        for pbo_path, abs_path, size in entries:
            write_header_entry(fp, pbo_path, packing=0, original_size=size,
                             reserved=0, timestamp=0, data_size=size)

        # Header boundary (empty entry)
        write_header_boundary(fp)

        # --- Write file data ---
        sha = hashlib.sha1()
        for pbo_path, abs_path, size in entries:
            with open(abs_path, "rb") as src:
                data = src.read()
                fp.write(data)
                sha.update(data)

        # --- Write checksum ---
        # Null byte followed by 20-byte SHA1 of all file data
        fp.write(b"\x00" + sha.digest())

    total_size = os.path.getsize(output_path)
    print(f"[PBO] Done!    {total_size:,} bytes written")


def main():
    parser = argparse.ArgumentParser(description="Pack PRA3 Server Addon into PBO")
    parser.add_argument("--source", default="serverAddons/PRA3_Rewrite/addons/PRA3_Server",
                        help="Source directory to pack")
    parser.add_argument("--output", default=None,
                        help="Output PBO file path (default: build/PRA3_Server.pbo)")
    args = parser.parse_args()

    # Resolve paths relative to script location
    script_dir = Path(__file__).parent
    source_dir = script_dir / args.source

    if not source_dir.exists():
        print(f"[PBO] ERROR: Source directory not found: {source_dir}", file=sys.stderr)
        sys.exit(1)

    if args.output:
        output_path = Path(args.output)
    else:
        output_path = script_dir / "build" / "PRA3_Server.pbo"

    output_path.parent.mkdir(parents=True, exist_ok=True)
    build_pbo(str(source_dir), str(output_path))


if __name__ == "__main__":
    main()
