# 마이그레이션: v3 → v4

## 변경 개요

| 항목 | 변경 내용 |
|------|----------|
| agents/ 경로 | 단일 공유 → 버전별 독립 (`{doc_type}/v{N}/agents/`) |
| PR 자동 생성 | 자동 생성 → 사용자 확인 후 생성 |

---

## 마이그레이션 절차

### Step 1: 스키마 버전 업데이트

`.claude/state/_schema_version.txt` 파일을 `v4`로 업데이트합니다.

### Step 2: 레거시 agents/ 디렉토리 보존

각 제품의 기존 `agents/` 디렉토리를 확인합니다:

```
for each {product_id} in .claude/state/:
  if .claude/artifacts/{product_id}/agents/ exists:
    rename: .claude/artifacts/{product_id}/agents/
    to:     .claude/artifacts/{product_id}/agents/_legacy/
```

- 이름 변경 이유: 기존 데이터를 보존하면서 신규 실행이 덮어쓰는 것을 방지합니다.
- `_legacy/` 디렉토리의 데이터는 수동 참조 전용입니다. 자동 워크플로우에서는 무시됩니다.

### Step 3: 기존 에이전트 출력 이동 (선택사항)

기존 `_legacy/` 에이전트 로그를 최신 버전 디렉토리로 이동하려는 경우:

```
# 각 제품에 대해:
product_id = {product_id}
doc_type = project.json의 document_type (없으면 "prd")
latest_version = artifacts/{product_id}/{doc_type}/의 최고 v{N}

if latest_version exists:
  copy .claude/artifacts/{product_id}/agents/_legacy/*
  to   .claude/artifacts/{product_id}/{doc_type}/{latest_version}/agents/
```

- 이 단계는 선택사항입니다. 이동하지 않아도 신규 `/run-research` 실행은 정상 동작합니다.

### Step 4: 확인

마이그레이션 완료 후:
- `.claude/state/_schema_version.txt`가 `v4`인지 확인
- `_legacy/` 디렉토리가 존재하면 마이그레이션 성공
- `/verify`로 구조 검사 실행

---

## 롤백

롤백이 필요한 경우:
1. `_schema_version.txt`를 `v3`으로 복원
2. `_legacy/`를 다시 `agents/`로 이름 변경
