# /gate-review — MVP 킬 게이트 검토

현재 단계의 완료 기준을 항목별로 검토하고 Go/Stop 결정을 기록합니다.
결정에 따라 `project.json`의 `mvp_stage`, `stage_status`, `stage_history`를 업데이트합니다.

---

## 실행 절차

### Step 1: 현재 상태 로드

1. `.claude/state/_active_product.txt`에서 `{active_product}` 로드.
2. `.claude/state/{active_product}/project.json`에서 다음 필드 확인:
   - `mvp_stage`: 현재 단계 (S1~S5, null)
   - `stage_status`: `in_progress` | `gate_passed` | `gate_stopped`

### Step 2: 사전 조건 확인

- `mvp_stage`가 null이거나 `document_type`이 `custom`이면:
  ```
  이 프로젝트는 MVP 프로세스 단계가 설정되지 않았습니다.
  킬 게이트 검토는 S1~S5 단계에서만 사용 가능합니다.
  ```
  → 종료.

- `stage_status`가 `gate_stopped`이면:
  ```
  === S{N} 킬 게이트: 중단됨 ===
  이전에 Stop 결정이 내려졌습니다.
  계속 진행하려면 "재개"를 입력하거나, /init-project로 새 단계를 시작하세요.
  ```
  → 종료 (사용자가 "재개" 입력 시 step 3으로 진행, `stage_status`를 `in_progress`로 초기화).

### Step 3: 단계 요약 표시

```
=== S{N} Kill Gate 검토 ===
현재 단계: S{N} {단계명}
활성 제품: {product_name}
단계 시작: {stage_started_at 또는 project created_at}

생성된 문서:
  - {document_type} (v{current_version})
  [stage_history에 documents_generated가 있으면 목록 표시]
================================
```

단계명 매핑:
- S1 → Brief (1W)
- S2 → Pretotype (2W)
- S3 → Prototype (1W)
- S4 → Freeze (0.5W)

### Step 4: Gate Criteria 로드

`.claude/spec/document-types.yaml`에서 현재 단계의 기준을 가져옵니다:

- `doc_category: master` 문서의 `gate_criteria` 사용.
- S1의 경우: `product-brief`의 `gate_criteria`.
- S2의 경우: `pretotype-spec`의 `gate_criteria`.
- S3의 경우: `product-spec`의 `gate_criteria`.
- S4의 경우: `document_type`이 `design-spec`이든 `tech-spec`이든 관계없이 항상 `design-spec`의 `gate_criteria`를 사용합니다.
  (`tech-spec`의 `gate_criteria`는 비어있으므로, S4 판정은 항상 `design-spec` 기준을 따릅니다.)
- **S5의 경우**: `document-types.yaml`에 S5 문서 유형이 없으므로 이 파일 하단 "S5 게이트 기준" 섹션의 고정 기준 3개를 사용합니다.
- 기준이 비어있으면: "이 단계에는 정의된 킬 게이트 기준이 없습니다. 다음 단계로 바로 진행하시겠습니까?" 확인.

### Step 5: 기준별 판정

각 기준 항목을 순서대로 표시하고 입력을 받습니다:

```
기준 확인 ({현재번호}/{전체}):
"{기준 내용}"

→ go / stop / 보류 중 선택 (또는 근거 메모 입력):
```

- `go`: 기준 충족 → 다음 항목
- `stop`: 기준 미충족 → 이유를 추가로 입력받음
  ```
  중단 사유를 입력해주세요:
  ```
- `보류`: 아직 확인 불가 → 다음 항목 (전체 완료 후 보류 항목 재확인)

보류 항목이 있으면 전체 순회 후 재확인:
```
보류 항목 {N}개가 남아있습니다. 지금 결정하시겠습니까?
```

### Step 6: 결과 처리

#### 전원 go → 단계 승인

```
=== S{N} 킬 게이트 통과! ===
모든 기준이 충족되었습니다.
다음 단계: S{N+1}
```

**저장 1 — 킬 게이트 로그 파일 생성** (담당자 확인 전에 항상 저장)

`.claude/artifacts/{active_product}/gate-review/S{N}-{YYYYMMDD-HHmm}.md`에 상세 내역을 저장합니다:
```markdown
# S{N} 킬 게이트 검토 결과

- **단계**: S{N} {단계명}
- **제품**: {product_name}
- **검토 일시**: {ISO 타임스탬프}
- **최종 결정**: Go ✅

## 기준별 판정

| # | 기준 | 결정 | 사유 |
|---|------|------|------|
| 1 | {기준 내용} | Go / Stop / 보류 | {사유 (stop인 경우)} |
| 2 | {기준 내용} | Go | — |
...

## 종합 메모

{전체 검토 과정에서 나온 주요 논의 및 메모}
```

담당자 확인:
```
S{N+1} 단계로 넘어갈 준비가 되셨나요? (예 / 아니요)
```
- **아니요**: 로그 파일 하단에 `단계 전환: 보류 (담당자 미확인)` 항목을 추가합니다. project.json 변경 없이 현재 단계(S{N}) 유지. "S{N}에 머무릅니다. 준비되면 /gate-review를 다시 실행하세요." 안내 후 Step 7로 이동.
- **예**: 로그 파일 하단에 `단계 전환: 확인 완료` 항목을 추가하고 아래 project.json 업데이트 진행.

**저장 2 — project.json stage_history 업데이트**

1. 기존 `stage_history` 배열을 로드합니다.
2. 다음 항목을 배열 끝에 **append** 합니다 (기존 이력 보존):
```json
{
  "stage": "S{N}",
  "entered_at": "{이전 또는 created_at}",
  "documents_generated": ["{document_type}"],
  "gate_decision": "go",
  "gate_decided_at": "{현재 ISO 타임스탬프}",
  "gate_notes": "전원 go",
  "gate_log": ".claude/artifacts/{active_product}/gate-review/S{N}-{YYYYMMDD-HHmm}.md"
}
```
3. `mvp_stage: "S{N+1}"`, `stage_status: "in_progress"`, 수정된 `stage_history` 배열을 project.json에 저장합니다.

S4 이후 통과 시:
```
=== S4 Freeze 완료 ===
MVP 개발 준비가 완료되었습니다!
다음: S5 MVP 빌드 단계로 진행합니다.
```

S4 완료 핸드오프 안내를 출력합니다:
```
=== S5 MVP 빌드 — 개발 핸드오프 ===

아래 세 문서를 코딩 에이전트 또는 개발팀에 전달하세요.

📄 Product Spec  → .claude/artifacts/{active_product}/product-spec/v{latest}/PRODUCT-SPEC.md
   (무엇을 만들지: 핵심 기능, Acceptance Criteria, 플로우)

🎨 Design Spec   → .claude/artifacts/{active_product}/design-spec/v{latest}/DESIGN-SPEC.md
   (어떻게 보이는지: UI/UX 사양, 컴포넌트, 토큰, 접근성)

⚙️  Tech Spec     → .claude/artifacts/{active_product}/tech-spec/v{latest}/TECH-SPEC.md
   (어떻게 만드는지: 기술 스택, 아키텍처, 인테그레이션 가이드)

코딩 에이전트에게 넘길 때는 세 문서를 모두 컨텍스트로 제공하세요.
개발팀에 넘길 때는 위 경로의 파일을 공유하거나 /upload-drive로 Drive에 올리세요.
===================================
```

#### stop 포함 → 단계 중단

```
=== S{N} 킬 게이트: Stop ===
중단된 기준:
  - {기준}: {사유}

현재 단계(S{N})를 계속 진행하거나, 방향을 재검토하세요.
```

**저장 1 — 킬 게이트 로그 파일 생성** (go와 동일 형식, 결정 칸에 Stop 표기)

**저장 2 — project.json stage_history 업데이트**

1. 기존 `stage_history` 배열을 로드합니다.
2. 다음 항목을 배열 끝에 **append** 합니다 (기존 이력 보존):
```json
{
  "stage": "S{N}",
  "entered_at": "{이전 또는 created_at}",
  "documents_generated": ["{document_type}"],
  "gate_decision": "stop",
  "gate_decided_at": "{현재 ISO 타임스탬프}",
  "gate_notes": "{stop 기준과 사유 요약}",
  "gate_log": ".claude/artifacts/{active_product}/gate-review/S{N}-{YYYYMMDD-HHmm}.md"
}
```
3. `stage_status: "gate_stopped"`, 수정된 `stage_history` 배열을 project.json에 저장합니다.

#### 보류 포함 (stop 없음) → 미완료

```
보류 항목이 {N}개 있어 게이트 결정을 완료하지 않았습니다.
확인 후 /gate-review를 다시 실행해주세요.
```
→ project.json 변경 없음.

### Step 7: 완료 후 안내

**Go 결정 + 예(S{N+1} 전환 완료) 시:**
```
다음 추천 액션:
  - S{N+1} 단계 문서 생성: /auto-generate
  - 소스 추가 후 시작: /init-project
```

**Go 결정 + 아니요(S{N} 유지) 시:**
```
S{N} 단계를 계속 진행합니다.
준비가 되면 /gate-review를 다시 실행하여 S{N+1}로 전환하세요.
```

**Stop 결정 시:**
```
다음 추천 액션:
  - 현재 단계 문서 보완 후 재검토: /auto-generate → /gate-review
  - 방향 재설정: /init-project
```

---

## S5 게이트 기준 (mvp_stage: S5)

S4 통과 후 mvp_stage가 S5인 경우의 고정 기준:

1. P0 기능 전부 작동 확인
2. 치명적 버그 없음 (P0 버그 0개)
3. 내부 사용자 테스트 통과

---

## 출력

- `.claude/artifacts/{active_product}/gate-review/S{N}-{YYYYMMDD-HHmm}.md` — 기준별 판정 상세 로그 (go/stop/보류, 사유 포함)
- `.claude/state/{active_product}/project.json` — `mvp_stage`, `stage_status`, `stage_history` 업데이트 (로그 파일 경로 포함)

---

## 완료 후

Go 결정이 내려진 경우 `/auto-generate`를 통해 다음 단계 문서 생성으로 자동 진행 가능합니다.
