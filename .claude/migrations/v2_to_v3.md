# 마이그레이션: v2 → v3

## 목적

MVP 프로세스 특화 단계 추적 시스템 도입:
- `mvp_stage` (S1~S4 + null), `stage_status`, `stage_history` 필드 추가
- Legacy document_type(prd, marketing-brief, business-plan) → `custom`으로 변환
- Legacy design-spec / tech-spec → v3 체계 유지 (ID 재사용, S4로 매핑)

---

## 실행 절차

### 1단계: 모든 제품 project.json 순회

`.claude/state/` 디렉토리의 모든 하위 디렉토리를 열거합니다.
`_active_product.txt`, `_schema_version.txt` 등 파일(디렉토리 아님)은 건너뜁니다.

각 `{product_id}` 디렉토리에 대해:
- `.claude/state/{product_id}/project.json`이 존재하면 → 마이그레이션 적용
- 존재하지 않으면 → 건너뜀

### 2단계: project.json 변환 규칙

각 project.json에 대해 다음을 순서대로 적용합니다.

#### A. legacy document_type 처리

현재 `document_type` 값 확인:

| 기존 값 | 처리 |
|---------|------|
| `prd` | `legacy_document_type: "prd"` 저장, `document_type: "custom"` |
| `marketing-brief` | `legacy_document_type: "marketing-brief"` 저장, `document_type: "custom"` |
| `business-plan` | `legacy_document_type: "business-plan"` 저장, `document_type: "custom"` |
| `design-spec` | `legacy_document_type: "design-spec"` 저장, `document_type: "design-spec"` (유지, ID 재사용) |
| `tech-spec` | `legacy_document_type: "tech-spec"` 저장, `document_type: "tech-spec"` (유지, ID 재사용) |
| `product-brief`, `business-spec`, `pretotype-spec`, `product-spec`, `custom` | 변경 없음 |

> `legacy_document_type`은 기존 아티팩트 경로 참조 시 사용됩니다.
> 이미 해당 필드가 있으면 덮어쓰지 않습니다.

#### B. mvp_stage 추가

`mvp_stage` 필드가 없는 경우:

| 조건 | mvp_stage 값 |
|------|-------------|
| `legacy_document_type` == `tech-spec` | `"S4"` |
| `legacy_document_type` == `design-spec` | `"S4"` |
| `document_type` == `design-spec` | `"S4"` |
| `document_type` == `tech-spec` | `"S4"` |
| `legacy_document_type` == `prd` 또는 `document_type` == `product-spec` | `"S3"` |
| `document_type` == `pretotype-spec` | `"S2"` |
| `document_type` == `product-brief` 또는 `document_type` == `business-spec` | `"S1"` |
| `document_type` == `custom` (legacy 없음) | `"S1"` |
| 그 외 / 판단 불가 | `"S1"` |

#### C. stage_status 추가

`stage_status` 필드가 없으면: `"in_progress"` 추가

#### D. stage_history 추가

`stage_history` 필드가 없으면: `[]` 추가

### 3단계: 스키마 버전 업데이트

모든 제품 마이그레이션 완료 후:

```
.claude/state/_schema_version.txt → "v3"
```

---

## 검증 체크리스트

마이그레이션 완료 후 각 project.json에서 확인:

- [ ] `mvp_stage` 필드 존재 (S1~S4 또는 "S1" 기본값)
- [ ] `stage_status` 필드 존재 (`"in_progress"`)
- [ ] `stage_history` 필드 존재 (빈 배열)
- [ ] legacy 타입의 경우 `legacy_document_type` 필드 존재
- [ ] `_schema_version.txt` = `"v3"`

---

## 롤백 방법

마이그레이션 전 project.json 백업이 없으면 git으로 복구:

```bash
git checkout HEAD -- .claude/state/{product_id}/project.json
echo "v2" > .claude/state/_schema_version.txt
```
