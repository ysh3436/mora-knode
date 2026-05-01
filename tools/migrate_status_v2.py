"""TaskStatus v1 → v2 lifecycle migration.

v1 (7-state): NotStarted / InReview / InProgress / Blocked / Done / Cancelled / Dropped
v2 (9-state): Created / Planning / PlanReview / InProgress / WorkReview / OnHold / Done / Cancelled / Dropped
              + IsWaiting boolean flag (default false)

Mapping:
  NotStarted → Created
  InReview   → WorkReview     (most usage was post-work review)
  InProgress → InProgress     (unchanged)
  Blocked    → OnHold         (manual user pause semantics)
  Done       → Done            (unchanged)
  Cancelled  → Cancelled      (계획 단계 취소; unchanged)
  Dropped    → Dropped        (작업 후 폐기; preserved separately from Cancelled)

Procedure:
  1. Backup current tasks collection to JSON file
  2. Update each task's Status string + add IsWaiting: false
  3. Write a ChangeLog entry per migrated task (reason="auto: migrated from v1 status", changedBy="system")

Idempotent: running twice on already-migrated DB is a no-op (status names already v2).
"""
import json
import sys
import io
from datetime import datetime
from pathlib import Path

import pymongo
from bson import ObjectId

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

MONGO_URL = "mongodb://localhost:27017"
DB_NAME = "mora_knode_dev"

V1_TO_V2 = {
    "NotStarted": "Created",
    "InReview":   "WorkReview",
    "InProgress": "InProgress",
    "Blocked":    "OnHold",
    "Done":       "Done",
    "Cancelled":  "Cancelled",
    "Dropped":    "Dropped",
}

V2_VALUES = {"Created", "Planning", "PlanReview", "InProgress",
             "WorkReview", "OnHold", "Done", "Cancelled", "Dropped"}


def main():
    client = pymongo.MongoClient(MONGO_URL)
    db = client[DB_NAME]
    tasks = db["tasks"]
    change_logs = db["change_logs"]

    docs = list(tasks.find({}))

    # 1. Backup (separate dict so we don't mutate the BSON _id we need later)
    backup_dir = Path(__file__).parent / "backups"
    backup_dir.mkdir(exist_ok=True)
    ts = datetime.utcnow().strftime("%Y%m%d_%H%M%S")
    backup_path = backup_dir / f"tasks_pre_v2_{ts}.json"
    with open(backup_path, "w", encoding="utf-8") as f:
        for d in docs:
            backup_doc = {k: (str(v) if k == "_id" else v) for k, v in d.items()}
            f.write(json.dumps(backup_doc, default=str, ensure_ascii=False) + "\n")
    print(f"backup: {backup_path}  ({len(docs)} docs)")

    # 2. Migrate each task
    migrated = 0
    skipped_already_v2 = 0
    unknown = []
    now = datetime.utcnow()

    for doc in docs:
        old_status = doc.get("Status")
        oid = doc["_id"]  # ObjectId, used directly
        if old_status in V2_VALUES:
            # Already migrated. Just ensure IsWaiting present.
            if "IsWaiting" not in doc:
                tasks.update_one({"_id": oid}, {"$set": {"IsWaiting": False}})
            skipped_already_v2 += 1
            continue
        new_status = V1_TO_V2.get(old_status)
        if new_status is None:
            unknown.append((str(oid), old_status))
            continue

        # 2a. Update task
        tasks.update_one(
            {"_id": oid},
            {"$set": {
                "Status": new_status,
                "IsWaiting": False,
                "UpdatedAt": now,
            }}
        )

        # 2b. ChangeLog entry — match existing schema (ChangeEntityType.Task = 1, ChangedAt not Timestamp)
        change_logs.insert_one({
            "_id": ObjectId(),
            "EntityType": 1,  # ChangeEntityType.Task
            "EntityId": oid,
            "Field": "Status",
            "BeforeValue": old_status,
            "AfterValue": new_status,
            "Reason": "auto: migrated from v1 status",
            "ChangedBy": "system",
            "ChangedAt": now,
        })
        migrated += 1

    # 3. Report
    print(f"migrated: {migrated}")
    print(f"skipped (already v2): {skipped_already_v2}")
    if unknown:
        print(f"UNKNOWN status values: {unknown}")
        sys.exit(1)

    # 4. Verify distribution
    print("\nstatus distribution (v2):")
    for d in tasks.aggregate([{"$group": {"_id": "$Status", "n": {"$sum": 1}}}, {"$sort": {"n": -1}}]):
        print(f"  {d['_id']}: {d['n']}")

    print(f"\nIsWaiting=false count: {tasks.count_documents({'IsWaiting': False})}")
    print(f"IsWaiting missing count: {tasks.count_documents({'IsWaiting': {'$exists': False}})}")


if __name__ == "__main__":
    main()
