# 마이그레이션: v1 → v2 (멀티 제품 지원)

이 마이그레이션은 단일 제품 구조를 멀티 제품(product_id 네임스페이스) 구조로 전환합니다.

---

## 적용 조건

`.claude/state/_schema_version.txt`가 없거나 값이 `v1`일 때 실행합니다.

---

## 마이그레이션 절차

### Step 1: 데이터 유무 확인

1. `.claude/state/project.json` 파일이 존재하는지 확인합니다.
   - 파일이 **없으면**: 마이그레이션할 기존 데이터가 없는 신규 워크스페이스입니다. **Step 5로 바로 이동**하여 스키마 버전만 v2로 기록하고 절차를 종료합니다.
   - 파일이 **있으면**: Step 2로 계속합니다.

### Step 2: product_id 생성

1. `.claude/state/project.json`의 `name` 필드를 읽어 product_id 후보를 생성합니다:
   - 소문자 변환
   - 공백 → 하이픈 (`-`)
   - 특수문자 제거 (영문자, 숫자, 하이픈, 언더스코어만 허용)
   - 예: `"Maththera"` → `maththera`, `"My App 2.0"` → `my-app-2-0`
2. 생성된 product_id 후보를 사용자에게 표시합니다:
   ```
   기존 프로젝트 이름: {name}
   생성된 product_id: {product_id}
   ```
3. 다른 이름을 원하면 직접 입력받습니다.
   - 대부분의 경우 자동 생성된 값으로 진행합니다.
   - 빈 문자열이거나 유효하지 않은 입력(영문자/숫자/하이픈/언더스코어 외)이면 다시 요청합니다.

### Step 3: 충돌 검사

결정된 product_id로 이미 `.claude/state/{product_id}/` 디렉토리가 존재하는지 확인합니다.

**충돌이 없으면 (디렉토리 미존재)**: Step 4로 계속합니다.

**충돌이 있으면 (디렉토리 이미 존재)**:

1. 기존 디렉토리 안의 내용을 간략히 표시합니다:
   ```
   이미 '{product_id}' 제품이 존재합니다:
     - project.json: {있음/없음}
     - 문서 버전: v{N} ({있음/없음})
   ```
2. 사용자에게 선택지를 제시합니다:
   - **a) 다른 이름 사용**: 새 product_id 직접 입력 → Step 2의 3번으로 돌아가 재입력
   - **b) 자동 접미사 사용**: `{product_id}-legacy` 형태로 자동 결정 → 그대로 계속
   - **c) 기존 데이터 덮어쓰기**: 기존 `{product_id}/` 내용을 이동 데이터로 교체 (기존 데이터 유실 주의)
3. 사용자 선택에 따라 처리 후 Step 4로 계속합니다.

> **자동 접미사 규칙**: `{product_id}-legacy`가 또 충돌하면 `{product_id}-legacy-2`, `{product_id}-legacy-3` 순으로 증가합니다.

### Step 4: 디렉토리 생성 및 파일 이동

1. 대상 디렉토리를 생성합니다:
   ```
   .claude/state/{product_id}/
   .claude/artifacts/{product_id}/
   .claude/knowledge/{product_id}/
   ```

2. **skip-worktree 해제** (v1에서 manifests 보호용으로 설정되어 있음):
   ```bash
   git update-index --no-skip-worktree .claude/manifests/drive-sources.yaml 2>/dev/null || true
   git update-index --no-skip-worktree .claude/manifests/project-defaults.yaml 2>/dev/null || true
   git update-index --no-skip-worktree .claude/manifests/admins.yaml 2>/dev/null || true
   ```
   > v2에서는 템플릿 파일을 직접 수정하지 않으므로 skip-worktree가 불필요합니다.

3. 아래 파일들을 이동합니다 (원본은 이동 후 삭제):

   | 원본 경로 | 새 경로 | 방식 |
   |----------|--------|------|
   | `.claude/state/project.json` | `.claude/state/{product_id}/project.json` | mv |
   | `.claude/state/sync-ledger.json` | `.claude/state/{product_id}/sync-ledger.json` | mv |
   | `.claude/state/sync-log.jsonl` | `.claude/state/{product_id}/sync-log.jsonl` | mv |
   | `.claude/state/evidence-distribution.json` | `.claude/state/{product_id}/evidence-distribution.json` | mv |
   | `.claude/manifests/drive-sources.yaml` | `.claude/manifests/drive-sources-{product_id}.yaml` | **cp** (원본 유지) |
   | `.claude/artifacts/agents/` (전체) | `.claude/artifacts/{product_id}/agents/` | mv |
   | `.claude/artifacts/prd/` (있으면) | `.claude/artifacts/{product_id}/prd/` | mv |
   | `.claude/artifacts/tech-spec/` (있으면) | `.claude/artifacts/{product_id}/tech-spec/` | mv |
   | `.claude/artifacts/design-spec/` (있으면) | `.claude/artifacts/{product_id}/design-spec/` | mv |
   | `.claude/artifacts/marketing-brief/` (있으면) | `.claude/artifacts/{product_id}/marketing-brief/` | mv |
   | `.claude/artifacts/business-plan/` (있으면) | `.claude/artifacts/{product_id}/business-plan/` | mv |
   | `.claude/artifacts/training-content-rulebook/` (있으면) | `.claude/artifacts/{product_id}/training-content-rulebook/` | mv |
   | `.claude/artifacts/reports/` (있으면) | `.claude/artifacts/{product_id}/reports/` | mv |
   | `.claude/artifacts/tutor-prompt/` (있으면) | `.claude/artifacts/{product_id}/tutor-prompt/` | mv |
   | `.claude/knowledge/evidence/` (전체) | `.claude/knowledge/{product_id}/evidence/` | mv |

   **주의**: 위 목록에 없는 `.claude/artifacts/` 또는 `.claude/knowledge/` 하위 디렉토리가 있으면 모두 `{product_id}/` 하위로 이동합니다.

4. **`drive-sources.yaml` 템플릿 복원**:
   - 위 테이블에서 `drive-sources.yaml`은 **cp(복사)** 입니다. 원본(템플릿)은 그대로 유지됩니다.
   - 사용자가 v1에서 직접 수정한 내용은 `drive-sources-{product_id}.yaml` 인스턴스에 보존됩니다.
   - 원본 `drive-sources.yaml`을 git의 tracked 버전(깨끗한 템플릿)으로 복원합니다:
     ```bash
     git checkout .claude/manifests/drive-sources.yaml
     ```
   - 이후 git pull로 admin이 배포하는 템플릿 업데이트를 정상적으로 수신합니다.

5. 이동이 완료되면 원본 빈 디렉토리를 삭제합니다.

### Step 6: 활성 제품 포인터 및 스키마 버전 기록

1. 활성 제품 포인터를 생성합니다:
   ```
   .claude/state/_active_product.txt
   ```
   내용: `{product_id}` (신규 워크스페이스의 경우 이 파일만 생성하지 않고 건너뜁니다)

2. 스키마 버전을 기록합니다:
   ```
   .claude/state/_schema_version.txt
   ```
   내용: `v2`

### Step 7: 마이그레이션 완료 보고

**기존 데이터가 있었던 경우:**
```
스키마 v1 → v2 마이그레이션 완료
  - product_id: {product_id}
  - 이동된 파일: {N}개
  - 활성 제품: {product_id}

이제 하나의 워크스페이스에서 여러 제품을 /switch-product로 전환할 수 있습니다.
```

**신규 워크스페이스인 경우:**
```
스키마 v2 초기화 완료 (마이그레이션할 데이터 없음)
이후 /auto-generate로 첫 프로젝트를 시작하세요.
```

---

## 롤백 방법 (수동)

마이그레이션을 되돌리려면:

1. `.claude/state/{product_id}/` 하위 파일들을 `.claude/state/`로 복원
2. `.claude/manifests/drive-sources-{product_id}.yaml` 내용을 `.claude/manifests/drive-sources.yaml`에 덮어씀
3. `.claude/manifests/drive-sources-{product_id}.yaml` 삭제
4. `.claude/artifacts/{product_id}/` 하위를 `.claude/artifacts/`로 복원
5. `.claude/knowledge/{product_id}/` 하위를 `.claude/knowledge/`로 복원
6. `.claude/state/_active_product.txt` 삭제
7. `.claude/state/_schema_version.txt` 삭제 또는 `v1`으로 변경
8. manifests에 skip-worktree 재적용: `git update-index --skip-worktree .claude/manifests/*.yaml`

---

## 에러 처리

- 원본 파일이 없는 경우: 해당 항목을 스킵합니다.
- 이동 실패 시: 실패 항목을 보고하고 계속 진행합니다.
- 모든 이동 완료 후 `_schema_version.txt`를 업데이트합니다 (부분 완료 방지).
- 이동 중 에러가 발생해도 이미 이동된 파일은 유지합니다. 재실행 시 이미 이동된 파일은 스킵합니다.
