"""Seeds two PendingReview AgentPlan rows so the plans-review UI has
something to act on. Submitted as the human admin (bypasses the strict
assignment check); SubmittedByResourceId is the human's own id, which
is fine for a UI smoke — the review queue cares about plan status,
not who submitted. Idempotent-ish: each run adds two more.

Run with backend up at http://localhost:5163.
"""
import io
import json
import sys
import urllib.request

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")

import os
BASE = os.environ.get("MORA_KNODE_API", "http://localhost:5163")
HUMAN_ID = "69f33ac19970f43fa673b115"  # ysh
TARGETS = [
    {
        "taskId": "69f4b3ef114fed107bb64b03",  # MK-80
        "title": "README + Quick start 정리",
        "estimateMinutes": 60,
        "steps": [
            {"description": "현재 README 의 미완성 섹션 표시", "estimateMinutes": 10},
            {"description": "Quick start (mongo + dotnet + flutter) 명령 추가", "estimateMinutes": 20},
            {"description": "agent flow 데모 curl 스니펫 박기", "estimateMinutes": 20},
            {"description": "self-review", "estimateMinutes": 10},
        ],
        "notes": "Phase 3 public 공개 직전 손볼 항목. 영어 우선이지만 한↔영 둘 다 유지 검토.",
    },
    {
        "taskId": "69f4badc114fed107bb64b12",  # MK-86
        "title": "matrix 팀 필터 UI 통합",
        "estimateMinutes": 90,
        "steps": [
            {"description": "Department / Project dropdown 컴포넌트 도입", "estimateMinutes": 30},
            {"description": "matrixLoadProvider 에 departmentId/projectId 파라미터 전달", "estimateMinutes": 25},
            {"description": "선택값을 sidebar 와 동기화 (현재 프로젝트 컨텍스트 인식)", "estimateMinutes": 20},
            {"description": "self-review + 한↔영 라벨", "estimateMinutes": 15},
        ],
    },
]


def post_plan(body):
    req = urllib.request.Request(BASE + "/api/agents/plans",
                                 data=json.dumps(body).encode("utf-8"),
                                 method="POST")
    req.add_header("Content-Type", "application/json")
    req.add_header("X-Dev-User-Id", HUMAN_ID)
    with urllib.request.urlopen(req) as r:
        return r.status, json.loads(r.read().decode("utf-8"))


def main():
    for t in TARGETS:
        code, plan = post_plan(t)
        print(f"  {code}  POST plan for taskId={t['taskId']} → id={plan['id'][:8]}…  status={plan['status']}")
    print("Done.")


if __name__ == "__main__":
    main()
