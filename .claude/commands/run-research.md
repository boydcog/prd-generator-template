# /run-research — 에이전트 팀 오케스트레이션

에이전트 팀을 실행하여 증거 기반 문서를 생성합니다.
문서 유형에 따라 활성 에이전트, 출력 구조, 저장 경로가 동적으로 결정됩니다.
각 실행은 새 버전(v1, v2, ...)으로 저장됩니다.

---

## 사전 조건 확인

실행 전 다음을 확인합니다:

1. **project.json 존재**: `.claude/state/project.json`이 있는지 확인. 없으면 `/init-project`를 먼저 실행하라고 안내.
2. **증거 인덱스 존재**: `.claude/knowledge/evidence/index/sources.jsonl`이 있는지 확인. 없으면 `/sync-drive`를 먼저 실행하라고 안내.
3. **증거 비어있지 않음**: sources.jsonl에 최소 1개 항목이 있는지 확인.

### Step 0.5: 문서 유형 설정 로드

1. `project.json`에서 `document_type` 필드를 읽습니다.
   - 필드가 없으면 기본값 `prd`를 사용합니다 (하위호환).
2. `.claude/spec/document-types.yaml`에서 해당 문서 유형의 설정을 로드합니다:
   - `agent_roles.wave1` → Wave 1에서 실행할 에이전트 목록
   - `allow_dynamic_roles` → 동적 역할 분석 활성화 여부
   - `output_dir_name` → 출력 디렉토리 이름
   - `output_file_name` → 최종 문서 파일명
   - `output_sections` → synth 에이전트에 전달할 문서 구조

### Step 0.6: 에이전트 역할 적합성 분석

> 이 단계는 `document-types.yaml`의 `allow_dynamic_roles`가 `true`일 때만 실행합니다.
> `false`이면 (예: custom 유형) 이 단계를 건너뛰고 Step 0.7로 진행합니다.

#### 0. 에러 핸들링

이 단계에서 오류 발생 시 기존 구성으로 안전하게 폴백합니다:
- `project.json` 읽기 실패 또는 필수 필드(`name`, `domain`) 누락 → "프로젝트 정보가 부족하여 역할 분석을 건너뜁니다." 안내 후 Step 0.7로 진행
- `sources.jsonl` 읽기 실패 → 증거 소스 없이 프로젝트 정보만으로 분석 시도
- 분석 중 예외 → "역할 분석 중 오류가 발생하여 기존 구성으로 진행합니다." 안내 후 Step 0.7로 진행
- 사용자에게 내부 파일 경로, 스택 트레이스, 증거 소스 원문을 노출하지 않습니다.

#### 1. 입력 수집

다음 정보를 수집합니다:
- `project.json`: `name`, `domain`, `core_problem`, `constraints`, `research_questions`
- `sources.jsonl`: 증거 소스 목록 (제목, 유형)
- `document-types.yaml`: 현재 문서 유형의 `agent_roles.wave1` 에이전트 목록

#### 2. 기존 dynamic_roles 확인

`project.json`에 `dynamic_roles` 배열이 이미 있는 경우:
- AskUserQuestion으로 확인합니다:
  > "이전 실행에서 추가된 역할이 있습니다: {역할 목록}. 유지할까요?"
- 선택지: "유지" / "재분석"
- "유지" 선택 시 → Step 0.7로 진행
- "재분석" 선택 시 → 아래 분석 계속

#### 3. 역할 갭 분석

Claude가 직접 수행합니다 (별도 에이전트 없음):

1. 프로젝트의 도메인, 핵심 문제, 제약사항, 증거 소스 제목을 분석합니다.
2. 기존 wave1 역할이 커버하는 영역을 파악합니다:
   - `biz`: 비즈니스 목표, 성공 지표, 경쟁 환경, 시장 기회
   - `marketing`: 포지셔닝, 메시징, 채널 전략, 런칭 계획
   - `research`: 사용자 인사이트, 증거 맵, 가정 검증
   - `tech`: 기술 타당성, 아키텍처, 비기능 요구사항
   - `pm`: 스코프, 요구사항, 마일스톤, 수용 기준
3. 프로젝트에 필요하지만 기존 역할로 커버되지 않는 영역을 식별합니다.
4. 커버되지 않는 영역이 있으면 동적 역할을 제안합니다.
   - 최대 3개까지 제안합니다.
   - 각 역할의 형식:
     ```
     role_id: 영문 소문자 (예: "ops", "pedagogy", "regulatory")
     name: 한국어 역할명 (예: "운영/프로세스")
     responsibility: 책임 범위 설명
     keywords: 증거 분배용 키워드 배열
     output_sections: 해당 역할의 필수 출력 섹션 배열
     ```

#### 4. 제안이 없는 경우

- "기존 에이전트 구성이 이 프로젝트에 적합합니다." 로그 후 Step 0.7로 진행합니다.

#### 5. 제안이 있는 경우

AskUserQuestion으로 사용자 승인을 받습니다:
> "프로젝트 분석 결과, 다음 역할을 추가하면 더 포괄적인 문서를 생성할 수 있습니다:"

각 역할의 ID, 이름, 책임 범위를 표시합니다.
선택지: "모두 추가" / "선택적 추가" / "기존 구성 유지"
- "선택적 추가" 시 multiSelect로 개별 역할 선택 가능

#### 6. 역할 ID 검증

승인된 각 역할에 대해 저장 전 검증합니다:
- `role_id`가 `/^[a-z][a-z0-9-]*$/` 패턴에 맞는지 확인 (영문 소문자 시작, 소문자/숫자/하이픈만 허용)
- 기존 역할 ID(`biz`, `marketing`, `research`, `tech`, `pm`, `synth`)와 중복되지 않는지 확인
- `name`, `responsibility`가 빈 문자열이 아닌지 확인
- `keywords` 배열에 최소 1개 항목이 있는지 확인
- `output_sections` 배열에 최소 1개 항목이 있는지 확인
- 검증 실패 시 해당 역할을 제외하고 "역할 '{role_id}' 형식이 올바르지 않아 제외되었습니다." 안내

#### 7. 승인된 역할 저장

- `project.json`에 `dynamic_roles` 배열을 추가(또는 갱신)합니다.
- 각 항목: `{ role_id, name, responsibility, keywords, output_sections }`
- 기존 `agent_roles` 배열이 있으면 동적 역할 ID도 추가합니다.
- 감사 추적: `dynamic_roles_meta` 객체도 함께 저장합니다:
  ```json
  {
    "updated_by": "<.user-identity 값>",
    "updated_at": "<ISO 8601 타임스탬프>",
    "action": "add|reanalyze|keep",
    "previous_roles": ["<이전 role_id 목록, 없으면 빈 배열>"]
  }
  ```

#### 8. 후속 단계 연동

- Step 0.7: 동적 역할의 `keywords`를 사용하여 추가 청크 분배
- Wave 1: 동적 역할도 기존 에이전트와 함께 Task tool로 병렬 실행
- Wave 2 (Synth): 동적 에이전트 출력도 통합 대상에 포함

---

## 버전 관리

### 버전 번호 결정

1. `.claude/artifacts/{output_dir_name}/` 디렉토리에서 기존 버전 폴더를 확인합니다 (`v1/`, `v2/`, ...).
   - `{output_dir_name}`은 `document-types.yaml`에서 로드한 값입니다.
2. 가장 높은 번호 + 1을 새 버전으로 사용합니다.
3. 첫 실행이면 `v1`입니다.

### 출력 경로 구조

```
.claude/artifacts/{output_dir_name}/
├── v1/
│   ├── {output_file_name}
│   ├── citations.json
│   ├── conflicts.json
│   └── metadata.json       # 버전 메타데이터
├── v2/
│   ├── {output_file_name}
│   ├── ...
└── latest -> v2/           # (심볼릭 링크 또는 latest.json으로 최신 버전 참조)
```

### 버전 메타데이터 (`metadata.json`)

```json
{
  "version": 2,
  "created_at": "2024-01-15T09:30:00Z",
  "evidence_index_sha256": "<sha256>",
  "source_count": 3,
  "project_name": "<프로젝트명>"
}
```

---

## 실행 절차

### Step 0.7: 증거 사전 로드 및 역할별 분배

Wave 1 에이전트 실행 전에 증거를 한 번만 읽고 역할별로 분배합니다. 에이전트당 컨텍스트를 60~70% 줄여 성능을 높입니다.

1. `sources.jsonl`과 전체 청크를 한 번만 읽습니다.
2. 각 청크를 키워드/주제로 분류하여 역할별 관련 청크를 분배합니다:
   - 비즈니스/시장/매출/KPI/경쟁 → `biz`, `marketing`
   - 사용자/인사이트/설문/페르소나 → `research`
   - 기술/아키텍처/API/인프라/성능 → `tech`
   - 요구사항/일정/마일스톤/스코프 → `pm`
   - **동적 역할**: `project.json`의 `dynamic_roles[].keywords`를 읽어 추가 매핑 생성
   - 분류 불가 → 모든 에이전트에 전달
3. 에이전트 프롬프트에 파일 경로 대신 **사전 조합된 텍스트**를 전달합니다.

---

### Wave 0: 팀 구성

1. `TeamCreate(team_name="research-v{N}")`로 팀을 생성합니다.
2. Wave 1 역할마다 `TaskCreate` 호출:
   - subject: "{role_name} 분석 수행"
   - activeForm: "{role_name} 분석 중"
3. Synth용 `TaskCreate` + `TaskUpdate(addBlockedBy=[모든 wave1 task ID])`

### Wave 1: 팀원 병렬 생성 (동적)

`document-types.yaml`의 `agent_roles.wave1`에 정의된 에이전트 + `project.json`의 `dynamic_roles`에 정의된 동적 에이전트를 합산하여 TeamCreate 팀원으로 **병렬** 생성합니다.

모든 Wave 1 역할에 대해 **동시에** Task tool 호출:

```
Task(
  team_name="research-v{N}",
  name="{role}-agent",
  subagent_type="general-purpose",
  model="opus",
  prompt="... (에이전트 프롬프트 + 팀 통신 블록)"
)
```

각 에이전트에게 전달할 컨텍스트:
- `.claude/state/project.json` (프로젝트 설정)
- `.claude/knowledge/evidence/index/sources.jsonl` (증거 인덱스)
- `.claude/knowledge/evidence/chunks/` (증거 청크 파일들)
- `.claude/spec/agent-team-spec.md` (역할 정의 및 JSON 계약)
- `.claude/spec/citation-spec.md` (인용 규칙)
- `.claude/spec/document-types.yaml` (문서 유형 정의)

#### 팀원 실행 절차

1. `TaskList` → 자기 태스크 찾기
2. `TaskUpdate(owner, status=in_progress)`
3. 증거 분석 + JSON/MD 파일 생성
4. `TaskUpdate(status=completed)`
5. `SendMessage(recipient="team-lead", summary="{role} 분석 완료")`
6. `shutdown_request` 대기 → 승인

#### 에이전트 목록 (문서 유형에 따라 활성화)

| Role ID | 에이전트 | 역할 | 출력 |
|---------|---------|------|------|
| `biz` | Biz/Strategy Agent | 비즈니스 목표, 성공 지표, 경쟁 환경 분석 | `agents/biz.json` + `agents/biz.md` |
| `marketing` | Marketing/GTM Agent | 포지셔닝, 메시징, 런칭 전략 | `agents/marketing.json` + `agents/marketing.md` |
| `research` | Research Agent | 사용자 인사이트, 증거 맵, 가정 검증 | `agents/research.json` + `agents/research.md` |
| `tech` | Tech Agent | 기술 타당성, 아키텍처, 비기능 요구사항 | `agents/tech.json` + `agents/tech.md` |
| `pm` | PM Agent | 스코프, 요구사항, 마일스톤, 수용 기준 | `agents/pm.json` + `agents/pm.md` |

예시: `document_type: marketing-brief`이면 biz, marketing, research만 실행.

#### 동적 역할 에이전트

`project.json`에 `dynamic_roles`가 있으면 해당 역할도 Wave 1에 포함하여 팀원으로 병렬 생성합니다.
동적 역할 에이전트의 프롬프트는 기존 템플릿과 동일하되:
- 역할 정의를 `agent-team-spec.md` 대신 `dynamic_roles[]`에서 로드
- 필수 섹션을 `dynamic_roles[].output_sections`에서 로드
- 출력 경로: `.claude/artifacts/agents/{role_id}.json` + `{role_id}.md`

### Wave 2: Synth 팀원 생성 (순차, Wave 1 완료 후)

`TaskList`로 synth 태스크의 `blockedBy` 해소를 확인한 후 synth 팀원을 생성합니다.

```
Task(
  team_name="research-v{N}",
  name="synth-agent",
  subagent_type="general-purpose",
  model="opus",
  prompt="... (synth 프롬프트 + 팀 통신 블록)"
)
```

- 입력: Wave 1의 에이전트 JSON + MD 결과물 전체 (동적 역할 출력 포함)
- 역할: 통합, 충돌 해결, 최종 문서 작성

##### Synth 팀원 절차:

1. `TaskList` → "통합 문서 생성 (synth)" 태스크 클레임
2. `TaskUpdate(owner="synth-agent", status="in_progress")`
3. Wave 1 결과 읽기 (모든 역할의 JSON + MD)
4. **충돌 식별**: 역할 간 상충하는 주장을 식별합니다.
   - 충돌 항목은 `conflicts.json`에 기록합니다.
5. **통합 문서 작성**: 모든 역할(고정 + 동적)의 핵심 내용을 통합하여 최종 문서를 작성합니다.
   - 문서 구조는 `document-types.yaml`의 `output_sections`를 따릅니다.
   - `output_sections` 목록을 사용하여 해당 섹션으로 문서를 구성합니다.
   - 동적 역할의 관점은 관련 섹션에 자연스럽게 통합합니다 (별도 섹션을 만들지 않음).
6. **인용 보고서**: 모든 인용을 `citations.json`에 기록합니다.
7. **출력**: 버전 디렉토리에 `{output_file_name}` 저장
   - 경로: `.claude/artifacts/{output_dir_name}/v{N}/{output_file_name}`
8. `TaskUpdate(status="completed")`
9. `SendMessage(recipient="team-lead", summary="통합 문서 생성 완료")`

### Wave 3: 팀 정리

1. 모든 팀원에게 `SendMessage(type="shutdown_request")` 전송
2. 승인 수신 후 `TeamDelete()` 호출

---

## 에이전트 프롬프트 템플릿

### 고정 역할 에이전트 프롬프트

```
당신은 {role_name} 전문가입니다.

## 프로젝트 컨텍스트
{project.json 내용}

## 당신의 역할
{agent-team-spec.md에서 해당 역할 섹션}

## 증거 자료 (사전 필터링됨)
Step 0.7에서 이 역할에 관련된 증거만 선별하여 전달합니다.
전체 인덱스가 아닌, 역할별로 분배된 청크 텍스트를 포함합니다:
{역할별 사전 조합된 증거 텍스트}

## 출력 규칙
1. agent-team-spec.md의 JSON 계약을 준수하세요.
2. 모든 주장(claim)에는 반드시 citation을 포함하세요 (citation-spec.md 참조).
3. JSON 파일과 Markdown 파일을 모두 생성하세요.
4. JSON 키는 알파벳순으로 정렬하세요.

## 출력 경로
- JSON: .claude/artifacts/agents/{role}.json
- Markdown: .claude/artifacts/agents/{role}.md
```

### 동적 역할 에이전트 프롬프트

고정 역할과 동일한 구조이되, 역할 정의를 `project.json`의 `dynamic_roles`에서 로드합니다:

```
당신은 {dynamic_roles[].name} 전문가입니다.

## 프로젝트 컨텍스트
{project.json 내용}

## 당신의 역할
- 역할명: {dynamic_roles[].name}
- 책임 범위: {dynamic_roles[].responsibility}
- 필수 출력 섹션: {dynamic_roles[].output_sections}

## 증거 자료 (사전 필터링됨)
Step 0.7에서 이 역할의 keywords에 매칭된 증거만 선별하여 전달합니다:
{역할별 사전 조합된 증거 텍스트}

## 출력 규칙
1. agent-team-spec.md의 JSON 계약(공통 Envelope)을 준수하세요.
2. 모든 주장(claim)에는 반드시 citation을 포함하세요 (citation-spec.md 참조).
3. JSON 파일과 Markdown 파일을 모두 생성하세요.
4. JSON 키는 알파벳순으로 정렬하세요.

## 출력 경로
- JSON: .claude/artifacts/agents/{role_id}.json
- Markdown: .claude/artifacts/agents/{role_id}.md

## 팀 통신 (필수)
당신은 "research-v{N}" 팀의 "{role}-agent" 팀원입니다.

1. TaskList → "{role_name} 분석 수행" 태스크 찾기
2. TaskUpdate(owner="{role}-agent", status="in_progress")
3. 분석 완료 후:
   a. TaskUpdate(status="completed")
   b. SendMessage(type="message", recipient="team-lead",
      content="{role} 분석 완료. claims: {N}건, risks: {N}건. 핵심: {요약}",
      summary="{role} 분석 완료")
4. shutdown_request 수신 시 승인
```

### Synth 에이전트 팀 통신 블록

synth 에이전트 프롬프트 끝에도 동일한 팀 통신 블록을 추가합니다 (태스크명만 변경):

```
## 팀 통신 (필수)
당신은 "research-v{N}" 팀의 "synth-agent" 팀원입니다.

1. TaskList → "통합 문서 생성 (synth)" 태스크 찾기
2. TaskUpdate(owner="synth-agent", status="in_progress")
3. 통합 완료 후:
   a. TaskUpdate(status="completed")
   b. SendMessage(type="message", recipient="team-lead",
      content="통합 문서 생성 완료. 섹션: {N}개, 인용: {N}건. 핵심: {요약}",
      summary="통합 문서 생성 완료")
4. shutdown_request 수신 시 승인
```

---

## 완료 후: Drive 업로드 확인

문서 생성이 완료되면 사용자에게 물어봅니다:

> "{document_type_name} v{N}이 생성되었습니다. Google Drive에 업로드하시겠습니까?"

### 업로드 시 동작 (Playwright 브라우저)

**중요: 업로드는 중간에 멈추지 않고 한 번에 완료합니다. 섹션별로 끊지 않습니다.**

#### Step 1: 사용자가 저장 위치 지정

1. `browser_navigate`로 `https://drive.google.com` 을 엽니다.
2. 사용자에게 안내합니다:
   > "Google Drive가 열렸습니다. 문서를 저장할 폴더로 이동한 후 '확인'을 입력해주세요."
3. 사용자가 "확인" (또는 동의 의사)을 입력할 때까지 **이 단계에서만** 대기합니다.
4. 사용자 확인 후 `browser_evaluate`로 현재 URL에서 폴더 ID를 추출합니다:
   ```javascript
   // URL 형태: https://drive.google.com/drive/folders/{FOLDER_ID}
   window.location.href;
   ```
5. 추출한 폴더 URL을 `.claude/manifests/drive-sources.yaml`의 `upload_folder`에 저장합니다 (다음부터 재사용).

#### Step 2: 문서 HTML 변환 (일괄)

1. 생성된 `.md` 파일 전체를 읽습니다.
2. Markdown → HTML로 한 번에 변환합니다 (heading, bold, table, list 등 서식 포함).
3. 변환된 HTML을 하나의 문자열 변수에 저장합니다.

#### Step 3: 해당 폴더에 Google Docs 생성 + 내용 삽입

1. 사용자가 지정한 Drive 폴더에서 `browser_click`으로 "새로 만들기" → "Google Docs" → "빈 문서"를 클릭합니다.
   - 또는 `browser_navigate`로 `https://docs.google.com/document/create` 접속 후, 생성된 문서를 해당 폴더로 이동.
2. `browser_evaluate`로 문서 제목을 `{type}-{project}-v{N}`으로 설정합니다.
3. **단일 `browser_evaluate` 호출**로 전체 HTML을 삽입합니다:
   ```javascript
   // 전체 문서를 한 번에 삽입 — 섹션별로 나누지 않음
   document.querySelector('.kix-appview-editor').focus();
   document.execCommand('insertHTML', false, fullHtmlContent);
   ```
4. 삽입 완료 확인 (스크린샷 1회).

#### Step 4: 결과 보고

1. 업로드 파일:
   - `{output_file_name}` (문서 본문 — HTML 서식 유지)
   - `citations.json` (인용 보고서, 선택)
2. 업로드 완료 후 Drive 링크를 사용자에게 공유합니다.

#### Step 5: 브라우저 종료

업로드 완료 후 `browser_close`를 호출하여 브라우저를 종료합니다.

**금지사항**:
- 개인 Drive 루트에 무단 생성 (반드시 사용자가 지정한 폴더에 저장)
- plain text 붙여넣기 (서식 사라짐)
- 섹션별 분할 삽입 (중간에 끊기고 사용자 입력 대기 발생)
- 삽입 중 사용자에게 "계속하시겠습니까?" 같은 질문 (위치 확인은 Step 1에서만)

### 업로드 거부 시

- "나중에 `/run-research --upload`로 업로드할 수 있습니다."를 안내합니다.

---

## 출력

| 파일 | 설명 |
|------|------|
| `.claude/artifacts/agents/{role}.json` | 각 역할의 구조화된 출력 |
| `.claude/artifacts/agents/{role}.md` | 각 역할의 서술형 요약 |
| `.claude/artifacts/{output_dir}/v{N}/{output_file}` | 최종 통합 문서 (버전별) |
| `.claude/artifacts/{output_dir}/v{N}/citations.json` | 전체 인용 보고서 |
| `.claude/artifacts/{output_dir}/v{N}/conflicts.json` | 역할 간 충돌 보고서 |
| `.claude/artifacts/{output_dir}/v{N}/metadata.json` | 버전 메타데이터 |

---

## 완료 후

auto-generate에서 호출된 경우 자동으로 다음 단계(검증)로 진행합니다.
