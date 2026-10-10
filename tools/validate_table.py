#!/usr/bin/env python3
"""Validate content/emergence_table.csv.

Checks:
  - required columns present, ids and names unique
  - every name referenced in emits / collapse_into / eats / eat_emits / recipes exists
    (`*` = anything; recipe results in parentheses are effects, not objects)
  - enum columns (act / pattern / size / anchored / status) hold known values
  - collapse_n and collapse_into come in pairs
  - approved rows that can be shown on their own have a caption line

Usage: python3 tools/validate_table.py [path/to/emergence_table.csv]
Exit code 1 on errors; warnings never fail.
"""
import csv
import sys
from pathlib import Path

DEFAULT = Path(__file__).resolve().parent.parent / "content" / "emergence_table.csv"

COLUMNS = [
    "id", "name", "act", "tier", "pattern", "size", "anchored", "emits",
    "collapse_n", "collapse_into", "eats", "eat_emits", "recipes", "line",
    "status", "owner", "notes",
]
ACTS = {"0", "1", "2", "3", "D"}
PATTERNS = {"", "container", "reproduce", "concept", "system", "recursive"}
SIZES = {"S", "M", "L", "XL", "-"}
STATUSES = {"idea", "approved", "modeled", "in-game", "cut"}


def split_list(cell, sep):
    return [p.strip() for p in cell.split(sep) if p.strip()]


def ref_name(part):
    # "钱×20" -> "钱"
    return part.split("×")[0].strip()


def main():
    path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT
    with path.open(encoding="utf-8", newline="") as f:
        reader = csv.DictReader(f)
        missing = [c for c in COLUMNS if c not in (reader.fieldnames or [])]
        rows = list(reader)

    errors, warnings = [], []
    if missing:
        errors.append(f"missing columns: {missing}")
        return report(path, rows, errors, warnings)

    ids, names = set(), set()
    for r in rows:
        if r["id"] in ids:
            errors.append(f"duplicate id: {r['id']}")
        if r["name"] in names:
            errors.append(f"duplicate name: {r['name']}")
        ids.add(r["id"])
        names.add(r["name"])

    def check_ref(row, field, name):
        if name != "*" and name not in names:
            errors.append(f"{row['id']}.{field}: unknown name '{name}'")

    for r in rows:
        rid = r["id"]
        if r["act"] not in ACTS:
            errors.append(f"{rid}.act: '{r['act']}' not in {sorted(ACTS)}")
        if r["pattern"] not in PATTERNS:
            errors.append(f"{rid}.pattern: '{r['pattern']}'")
        if r["size"] not in SIZES:
            errors.append(f"{rid}.size: '{r['size']}' not in {sorted(SIZES)}")
        if r["anchored"] not in {"", "y"}:
            errors.append(f"{rid}.anchored: use 'y' or empty")
        if r["status"] not in STATUSES:
            errors.append(f"{rid}.status: '{r['status']}'")

        for field in ("emits", "eat_emits"):
            for part in split_list(r[field], ";"):
                check_ref(r, field, ref_name(part))
        for part in split_list(r["eats"], "|"):
            check_ref(r, "eats", ref_name(part))
        if r["collapse_into"]:
            check_ref(r, "collapse_into", r["collapse_into"])
        if bool(r["collapse_n"]) != bool(r["collapse_into"]):
            errors.append(f"{rid}: collapse_n and collapse_into must both be set or both empty")
        if r["collapse_n"] and not r["collapse_n"].isdigit():
            errors.append(f"{rid}.collapse_n: not an integer")
        if bool(r["eats"]) != bool(r["eat_emits"]) and "回收站" not in r["name"]:
            warnings.append(f"{rid}: eats without eat_emits (or vice versa)")

        for part in split_list(r["recipes"], ";"):
            if "→" not in part:
                errors.append(f"{rid}.recipes: '{part}' missing →")
                continue
            hitter, result = (s.strip() for s in part.split("→", 1))
            check_ref(r, "recipes", hitter)
            if not (result.startswith("(") and result.endswith(")")):
                check_ref(r, "recipes", result)

        if r["status"] == "approved" and r["size"] != "-" and r["emits"] and not r["line"]:
            warnings.append(f"{rid}: approved emitter without a caption line")

    return report(path, rows, errors, warnings)


def report(path, rows, errors, warnings):
    by_status = {}
    for r in rows:
        by_status[r.get("status", "?")] = by_status.get(r.get("status", "?"), 0) + 1
    print(f"{path.name}: {len(rows)} rows  " + "  ".join(f"{k}={v}" for k, v in sorted(by_status.items())))
    for w in warnings:
        print(f"  warn  {w}")
    for e in errors:
        print(f"  ERROR {e}")
    print("OK" if not errors else f"{len(errors)} error(s)")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
