"""One-shot cleanup: MK-26 (Phase 1.5 원안 plan) 트리의 stale 자식들을
실제 진행 상황에 맞춰 status 정리. MK-75 (replan) 트리로 작업이 흘러
MK-26 이 평행 plan 으로 남아있던 상태를 해소.

13개 leaf task status 변경:
  Done:      MK-37, 39, 40, 42, 45, 48 (실제 shipped via MK-81/82)
  Cancelled: MK-31, 33, 34, 38, 43, 44, 46
             (분할 / Phase 2 확장 이동 / 중복 / BSON 자동 처리)

부모 task (MK-30, 36, 41, 26) 는 자식 rollup 으로 자동 Done 갱신.

Run with backend up at http://localhost:5163.
"""
import io
import json
import sys
import urllib.request

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

BASE = "http://localhost:5163"
HUMAN = "69f33ac19970f43fa673b115"
PROJECT_MORA = "69f4404e24095755bdd41bdb"

# (number, new_status, changeReason)
TRANSITIONS = [
    # Done — 실제 shipped via MK-75 트리
    (37, "Done", "MK-75 트리에서 AgentPlan 모델로 단순화 구현됨 (MK-82). 이름은 다르지만 동등 기능"),
    (39, "Done", "MongoContext + AgentPlanRepository 구현됨 (MK-82). AgentRunRepository 는 MK-38 이동분에 흡수"),
    (40, "Done", "AgentPlan 컬렉션 인덱스 추가 (MK-82)"),
    (42, "Done", "/api/agents/plans/* 구현 (MK-82) — submit/list/get/approve/reject/revert"),
    (45, "Done", "Program.cs 등록 + tools/demo_agent_flow.py 25-assertion E2E (MK-82)"),
    (48, "Done", "/api/agents identity + 토큰 + RBAC 구현 (MK-81)"),
    # Cancelled — 계획 단계 취소 (분할 / 이동 / 중복 / 불필요)
    (31, "Cancelled", "5종 한꺼번에 도입 → 분할. Tier 2 의 새 task (Git + AcceptanceCriteria 우선) 로 대체"),
    (33, "Cancelled", "MongoDB BSON 자동 처리 — 별도 회귀 task 불필요"),
    (34, "Cancelled", "MK-31 와 함께 Tier 2 새 task 로 흡수"),
    (38, "Cancelled", "AgentRun (실행 메트릭) — Phase 2 확장 (MK-60 트리) 으로 이동. 현재 dogfooding 우선순위 낮음"),
    (43, "Cancelled", "work-queue GET 만 구현됨 (MK-82). claim/release lock 은 multi-agent dogfooding 후 평가 — 별도 task 로"),
    (44, "Cancelled", "/api/agents/runs — Phase 2 확장으로 이동. ADR-005 비차별 원칙으로 선택적 메트릭"),
    (46, "Cancelled", "MK-54 (Phase 2 확장 자식) 와 동일 항목 — 중복"),
]


def request(method, path, *, body=None):
    data = json.dumps(body, ensure_ascii=False).encode("utf-8") if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, method=method)
    req.add_header("Content-Type", "application/json")
    req.add_header("X-Dev-User-Id", HUMAN)
    with urllib.request.urlopen(req) as r:
        text = r.read().decode("utf-8")
        return r.status, json.loads(text) if text else None


def main():
    code, tasks = request("GET", f"/api/projects/{PROJECT_MORA}/tasks")
    by_number = {t.get("number"): t for t in tasks if t.get("number") is not None}

    for number, new_status, reason in TRANSITIONS:
        t = by_number.get(number)
        if t is None:
            print(f"  -- MK-{number}: not found, skipping")
            continue
        if t["status"] == new_status:
            print(f"  ··  MK-{number} already {new_status}")
            continue
        before = t["status"]
        t["status"] = new_status
        t["changeReason"] = reason
        t["changedBy"] = "system (cleanup_mk26_stale_tree)"
        code, _ = request("PUT", f"/api/tasks/{t['id']}", body=t)
        print(f"  {code}  MK-{number:>3}  {before} → {new_status}  ({reason[:50]}…)")

    print()
    print("# Verification — parent rollup")
    code, after = request("GET", f"/api/projects/{PROJECT_MORA}/tasks")
    after_by_number = {t.get("number"): t for t in after if t.get("number") is not None}
    for parent_n in (27, 30, 36, 41, 26):
        p = after_by_number.get(parent_n)
        if p:
            print(f"  MK-{parent_n:>3}  {p['status']}  ← parent")


if __name__ == "__main__":
    main()
