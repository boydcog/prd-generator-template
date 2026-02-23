# /init-project — 프로젝트 설정 인터뷰

대화형 인터뷰를 통해 프로젝트 정보를 수집하고 설정 파일을 생성합니다.
세션 시작 시 기존 소스 확인 및 새 소스 입력을 처리합니다.

---

## 실행 절차

### Step -1: 사용자 아이덴티티 확인

1. `.user-identity` 파일이 존재하는지 확인합니다.
2. **있으면**: 이름을 읽어 "안녕하세요, {이름}님!" 인사합니다.
3. **없으면**: "처음 사용하시나요? 이름을 알려주세요." 질문 후 입력받아 `.user-identity`에 저장합니다.

### Step 0: 활성 제품 및 기존 상태 확인

1. `.claude/state/_active_product.txt`를 읽어 현재 활성 제품 확인.
2. **활성 제품이 있고, `.claude/state/{active_product}/project.json`이 존재하면:**
   - 기존 프로젝트 정보를 요약하여 보여줍니다.
   - "기존 [{active_product}] 설정을 유지하시겠습니까, 새 제품을 시작하시겠습니까?" 질문.
   - 유지 선택 시 → Step 1-A (소스 확인)로 이동.
   - 새 제품 선택 시 → Step 1-B (인터뷰)로 이동.
3. **활성 제품이 없거나 project.json이 없으면**: Step 1-B (인터뷰)로 이동.

### Step 1-A: 기존 소스 확인 & 갱신

1. `.claude/manifests/drive-sources-{active_product}.yaml`의 `sources[]`를 읽습니다.
2. 소스가 있으면:
   - 등록된 소스 목록을 표시합니다:
     ```
     📄 등록된 Drive 소스:
     1. 시장 분석 보고서 (doc) — https://docs.google.com/...
     2. 경쟁사 데이터 (sheet) — https://docs.google.com/...
     ```
   - "추가할 소스가 있나요?" 질문.
   - 있으면 URL을 입력받아 manifest에 추가.
3. 소스가 없으면:
   - "참고할 Google Drive 문서 링크를 입력해주세요." 요청.
   - 최소 1개 이상 입력받습니다.
4. `/sync-drive`를 실행할지 물어봅니다.

### Step 1-B: 프로젝트 정보 수집 (새 프로젝트)

사용자에게 다음 항목을 순서대로 질문합니다.
각 질문에 대해 기본값이 있으면 표시하고, 사용자가 비워두면 기본값을 적용합니다.

| # | 질문 | 기본값 | 필수 |
|---|------|--------|------|
| 1 | 프로젝트 이름은 무엇인가요? | — | Y |
| 1-1 | 어떤 문서를 만들까요? (PRD / 디자인 사양서 / 마케팅 브리프 / 사업 계획서 / 기술 사양서 / 직접 정의) | PRD | Y |
| 2 | 대상 사용자(고객)는 누구인가요? | — | Y |
| 3 | 프로젝트의 도메인/산업 분야는? | — | N |
| 4 | 핵심 문제 또는 기회는 무엇인가요? | — | Y |
| 5 | 주요 제약사항이 있나요? (기술, 예산, 일정 등) | 없음 | N |
| 6 | 답을 찾고 싶은 핵심 연구 질문은? (복수 가능) | — | Y |
| 7 | 참고할 Google Drive 문서 링크가 있나요? (복수 가능) | 없음 | N |
| 8 | 출력 언어 선호는? | ko | N |

질문 1 이후, **product_id를 생성**합니다:
- 프로젝트 이름을 소문자 + 하이픈 형식으로 변환 (예: `"Maththera"` → `maththera`, `"My App"` → `my-app`).
- 생성된 product_id를 표시하고, 변경을 원하면 수정 입력받습니다.

### Step 2: Drive 링크 처리

질문 7 또는 Step 1-A에서 Drive 링크를 제공한 경우:

1. 각 URL에서 문서 유형을 자동 감지합니다:
   - `docs.google.com/document/` → `type: doc`
   - `docs.google.com/spreadsheets/` → `type: sheet`
2. 각 링크에 대해 이름(name)을 확인합니다.
   - Playwright로 Drive 페이지에 접속하여 파일명을 자동으로 가져올 수 있으면 자동 설정.
   - 가져올 수 없으면 사용자에게 이름을 입력받습니다.
3. `.claude/manifests/drive-sources-{product_id}.yaml`의 `sources[]`에 추가합니다.
4. Sheets의 경우 내보내기 형식을 물어봅니다: CSV (기본) 또는 MD.

### Step 3: project.json 생성

`.claude/state/{product_id}/project.json`을 생성합니다:

```json
{
  "product_id": "<product_id>",
  "name": "<프로젝트명>",
  "document_type": "<문서유형 ID: prd|design-spec|marketing-brief|business-plan|tech-spec|custom>",
  "target_users": "<대상 사용자>",
  "domain": "<도메인>",
  "core_problem": "<핵심 문제>",
  "constraints": ["<제약1>", "<제약2>"],
  "research_questions": ["<질문1>", "<질문2>"],
  "language": "ko",
  "created_at": "<ISO 타임스탬프>",
  "agent_roles": ["<document-types.yaml의 wave1 에이전트>", "synth"],
  "current_version": 0
}
```

**문서 유형에 따른 agent_roles 결정**:
- `.claude/spec/document-types.yaml`에서 선택한 `document_type`의 `agent_roles.wave1`을 읽어 `agent_roles`에 설정합니다.
- synth는 항상 포함됩니다.
- `custom` 선택 시: 사용자에게 에이전트(biz, marketing, research, tech, pm)를 직접 선택하게 하고, 출력 섹션도 직접 정의하게 합니다.

### Step 4: 활성 제품 포인터 업데이트

`.claude/state/_active_product.txt`를 `{product_id}`로 씁니다.

### Step 5: 설정 확인

생성된 설정을 사용자에게 요약하여 보여주고 확인을 받습니다.
수정이 필요하면 해당 항목만 다시 질문합니다.

---

## 출력

- `.claude/state/{product_id}/project.json` — 프로젝트 설정 파일
- `.claude/manifests/drive-sources-{product_id}.yaml` — Drive 링크 추가 (제공된 경우)
- `.claude/state/_active_product.txt` — 활성 제품 포인터

---

## 완료 후

설정이 저장되었습니다.
auto-generate에서 호출된 경우 자동으로 다음 단계(Drive 동기화)로 진행합니다.
