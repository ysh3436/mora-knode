#!/usr/bin/env python3
"""
One-time migration: convert TaskItem.Status from BSON int to BSON string.

When TaskStatus was first persisted, the C# default for an enum field is
int. We later switched the field to BsonRepresentation.String so the
sparse integer values in the enum (10/20/30/40/50/51/52) can be reordered
freely without breaking stored data — the source of truth is now the
enum *name* on disk.

Run this **once**, while the backend is stopped. Idempotent: documents
that already have a string status are skipped. After this, the enum's
integer values are purely a sort/order signal in code.

Usage:
    python tools/migrate_task_status_to_string.py [--mongo URI] [--db NAME]
"""
from __future__ import annotations

import argparse
import sys

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
    sys.stderr.reconfigure(encoding="utf-8")

# Mapping is the integer order the original enum was declared in (before
# sparse values were introduced). Anything outside this set was never
# valid; we leave such documents untouched and report them.
INT_TO_NAME = {
    0: "NotStarted",
    1: "InProgress",
    2: "Blocked",
    3: "Done",
    # 4 was a brief intermediate value used during a prior renaming step
    # (PlanReview → InReview). Map both to the current InReview name.
    4: "InReview",
}


def main() -> None:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--mongo", default="mongodb://localhost:27017")
    ap.add_argument("--db", default="mora_knode_dev")
    args = ap.parse_args()

    try:
        from pymongo import MongoClient
    except ImportError:
        sys.exit("pymongo is required: pip install pymongo")

    db = MongoClient(args.mongo)[args.db]
    tasks = db["tasks"]

    total = tasks.count_documents({})
    already_string = tasks.count_documents({"Status": {"$type": "string"}})
    print(f"Connected to {args.db}.tasks — {total} docs ({already_string} already string)")

    updated = 0
    for old, name in INT_TO_NAME.items():
        result = tasks.update_many({"Status": old}, {"$set": {"Status": name}})
        if result.modified_count:
            print(f'  {old} -> "{name}": {result.modified_count}')
            updated += result.modified_count

    leftovers = tasks.count_documents(
        {"Status": {"$nin": list(INT_TO_NAME.values()) + list(INT_TO_NAME.keys())}}
    )
    print()
    print(f"Updated: {updated}")
    if leftovers:
        print(f"WARNING: {leftovers} document(s) have an unrecognized Status value — inspect manually.")


if __name__ == "__main__":
    main()
