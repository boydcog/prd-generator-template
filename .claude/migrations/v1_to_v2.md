# 마이그레이션: v1 → v2 (멀티 제품 지원)

이 마이그레이션은 단일 제품 구조를 멀티 제품(product_id 네임스페이스) 구조로 전환합니다.

---

## 적용 조건

`.claude/state/_schema_version.txt`가 없거나 값이 `v1`일 때 실행합니다.

---

## 마이그레이션 절차

### Step 1: product_id 결정

1. `.claude/state/project.json` 파일이 존재하는지 확인합니다.
   - 파일이 **없으면**: 마이그레이션할 데이터가 없으므로 **Step 5로 바로 이동**하여 스키마 버전만 업데이트하고 절차를 종료합니다.
2. `.claude/state/project.json`을 읽습니다.
3. `name` 필드를 읽어 product_id를 생성합니다:
   - 소문자 변환
   - 공백 → 하이픈 (`-`)
   - 특수문자 제거 (영문자, 숫자, 하이픈만 허용)
   - 예: `"Maththera"` → `maththera`, `"My App 2.0"` → `my-app-2-0`
4. product_id를 사용자에게 표시하고 변경을 원하면 수정 입력받습니다.
   - 대부분의 경우 자동 생성된 값으로 진행합니다.

### Step 2: 디렉토리 생성

```
.claude/state/{product_id}/
.claude/artifacts/{product_id}/
.claude/knowledge/{product_id}/
```

### Step 3: 파일 이동

아래 파일들을 이동합니다 (원본은 이동 후 삭제):

| 원본 경로 | 새 경로 |
|----------|--------|
| `.claude/state/project.json` | `.claude/state/{product_id}/project.json` |
| `.claude/state/sync-ledger.json` | `.claude/state/{product_id}/sync-ledger.json` |
| `.claude/state/sync-log.jsonl` | `.claude/state/{product_id}/sync-log.jsonl` |
| `.claude/state/evidence-distribution.json` | `.claude/state/{product_id}/evidence-distribution.json` |
| `.claude/manifests/drive-sources.yaml` | `.claude/manifests/drive-sources-{product_id}.yaml` |
| `.claude/artifacts/agents/` (전체) | `.claude/artifacts/{product_id}/agents/` |
| `.claude/artifacts/prd/` (있으면) | `.claude/artifacts/{product_id}/prd/` |
| `.claude/artifacts/tech-spec/` (있으면) | `.claude/artifacts/{product_id}/tech-spec/` |
| `.claude/artifacts/design-spec/` (있으면) | `.claude/artifacts/{product_id}/design-spec/` |
| `.claude/artifacts/marketing-brief/` (있으면) | `.claude/artifacts/{product_id}/marketing-brief/` |
| `.claude/artifacts/business-plan/` (있으면) | `.claude/artifacts/{product_id}/business-plan/` |
| `.claude/artifacts/training-content-rulebook/` (있으면) | `.claude/artifacts/{product_id}/training-content-rulebook/` |
| `.claude/artifacts/reports/` (있으면) | `.claude/artifacts/{product_id}/reports/` |
| `.claude/artifacts/tutor-prompt/` (있으면) | `.claude/artifacts/{product_id}/tutor-prompt/` |
| `.claude/knowledge/evidence/` (전체) | `.claude/knowledge/{product_id}/evidence/` |

**주의**: 위 목록에 없는 `.claude/artifacts/` 또는 `.claude/knowledge/` 하위 디렉토리가 있으면 모두 `{product_id}/` 하위로 이동합니다.

### Step 4: 활성 제품 포인터 생성

```
.claude/state/_active_product.txt
```
내용: `{product_id}`

### Step 5: 스키마 버전 업데이트

```
.claude/state/_schema_version.txt
```
내용: `v2`

### Step 6: 마이그레이션 완료 보고

사용자에게 알립니다:
> "기존 데이터를 '{product_id}' 제품으로 마이그레이션했습니다. (v1 → v2)"

---

## 롤백 방법 (수동)

마이그레이션을 되돌리려면:

1. `.claude/state/{product_id}/` 하위 파일들을 `.claude/state/`로 복원
2. `.claude/manifests/drive-sources-{product_id}.yaml` → `.claude/manifests/drive-sources.yaml`로 복원
3. `.claude/artifacts/{product_id}/` 하위를 `.claude/artifacts/`로 복원
4. `.claude/knowledge/{product_id}/` 하위를 `.claude/knowledge/`로 복원
5. `.claude/state/_active_product.txt` 삭제
6. `.claude/state/_schema_version.txt` 삭제 또는 `v1`로 변경

---

## 에러 처리

- 원본 파일이 없는 경우: 해당 항목을 스킵합니다.
- 이동 실패 시: 실패 항목을 보고하고 계속 진행합니다.
- 모든 이동 완료 후 `_schema_version.txt`를 업데이트합니다 (부분 완료 방지).
