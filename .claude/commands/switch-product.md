# /switch-product — 활성 제품 전환

현재 작업 중인 제품(product_id)을 전환하거나 새 제품을 초기화합니다.

---

## 실행 절차

### Step 1: 현재 상태 확인

1. `.claude/state/_active_product.txt`를 읽어 현재 활성 제품 표시.
2. `.claude/state/` 하위 디렉토리를 열거하여 기존 제품 목록 확보:
   - `_` 로 시작하는 항목(예: `_active_product.txt`, `_schema_version.txt`)은 제품 폴더가 아니므로 제외.
   - 나머지 서브디렉토리 이름이 product_id 목록.
3. 표시 형식:
   ```
   현재 활성 제품: maththera

   등록된 제품 목록:
   1. maththera  ← 현재
   2. new-product-a
   3. new-product-b
   ```

### Step 2: 전환 선택

`$ARGUMENTS`로 product_id가 전달된 경우:
- 해당 product_id로 바로 전환 (Step 3으로 이동).

`$ARGUMENTS`가 없는 경우:
- 사용자에게 질문: "어떤 제품으로 전환하시겠습니까? (번호 또는 이름 입력, 새 제품은 이름 입력)"
- 번호 선택 → 해당 product_id로 전환.
- 목록에 없는 이름 입력 → 새 제품 생성 흐름 (Step 4).

### Step 3: 기존 제품으로 전환

1. 선택된 product_id의 `.claude/state/{product_id}/project.json`이 존재하는지 확인.
   - 없으면: "'{product_id}' 제품을 찾을 수 없습니다." 안내 후 목록 재표시.
2. `.claude/state/_active_product.txt`를 `{product_id}`로 업데이트.
3. 전환된 제품의 상태 요약 표시:
   ```
   제품 전환 완료: {product_id}

   프로젝트: {name}
   문서 유형: {document_type}
   마지막 동기화: {sync-ledger.json의 last_sync_time, 없으면 "없음"}
   현재 버전: v{current_version}
   ```

### Step 4: 새 제품 생성

입력된 이름이 목록에 없으면:
1. "'{입력값}' 제품이 없습니다. 새로 시작하시겠습니까?" 확인.
2. 확인 → `/init-project` 실행 (새 제품 인터뷰).
3. 취소 → Step 2로 돌아가 재선택.

---

## 완료 후

전환된 product_id가 모든 후속 명령의 기본 대상이 됩니다.
CLAUDE.md의 세션 시작 규칙에 따라 이후 작업이 자동으로 진행됩니다.
