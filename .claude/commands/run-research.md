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
   - `output_dir_name` → 출력 디렉토리 이름
   - `output_file_name` → 최종 문서 파일명
   - `output_sections` → synth 에이전트에 전달할 문서 구조

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

### Wave 1: 병렬 에이전트 실행 (동적)

`document-types.yaml`의 `agent_roles.wave1`에 정의된 에이전트만 Task tool로 **병렬** 실행합니다.

각 에이전트에게 전달할 컨텍스트:
- `.claude/state/project.json` (프로젝트 설정)
- `.claude/knowledge/evidence/index/sources.jsonl` (증거 인덱스)
- `.claude/knowledge/evidence/chunks/` (증거 청크 파일들)
- `.claude/spec/agent-team-spec.md` (역할 정의 및 JSON 계약)
- `.claude/spec/citation-spec.md` (인용 규칙)
- `.claude/spec/document-types.yaml` (문서 유형 정의)

#### 에이전트 목록 (문서 유형에 따라 활성화)

| Role ID | 에이전트 | 역할 | 출력 |
|---------|---------|------|------|
| `biz` | Biz/Strategy Agent | 비즈니스 목표, 성공 지표, 경쟁 환경 분석 | `agents/biz.json` + `agents/biz.md` |
| `marketing` | Marketing/GTM Agent | 포지셔닝, 메시징, 런칭 전략 | `agents/marketing.json` + `agents/marketing.md` |
| `research` | Research Agent | 사용자 인사이트, 증거 맵, 가정 검증 | `agents/research.json` + `agents/research.md` |
| `tech` | Tech Agent | 기술 타당성, 아키텍처, 비기능 요구사항 | `agents/tech.json` + `agents/tech.md` |
| `pm` | PM Agent | 스코프, 요구사항, 마일스톤, 수용 기준 | `agents/pm.json` + `agents/pm.md` |

예시: `document_type: marketing-brief`이면 biz, marketing, research만 실행.

```
Task(subagent_type="general-purpose", name="{role}-agent")
```

### Wave 2: Synth Agent (순차, Wave 1 완료 후)

Wave 1의 5개 에이전트 결과가 모두 완료된 후 실행합니다.

#### 6. Synth Agent
```
Task(subagent_type="general-purpose", name="synth-agent")
```
- 입력: Wave 1의 에이전트 JSON + MD 결과물 전체
- 역할: 통합, 충돌 해결, 최종 문서 작성

##### Synth 에이전트 지시사항:

1. **결과 수집**: Wave 1 에이전트의 JSON 출력을 읽습니다.
2. **충돌 식별**: 역할 간 상충하는 주장을 식별합니다.
   - 충돌 항목은 `conflicts.json`에 기록합니다.
3. **통합 문서 작성**: 모든 역할의 핵심 내용을 통합하여 최종 문서를 작성합니다.
   - 문서 구조는 `document-types.yaml`의 `output_sections`를 따릅니다.
   - synth 에이전트에게 `output_sections` 목록을 전달하여 해당 섹션으로 문서를 구성하게 합니다.
4. **인용 보고서**: 모든 인용을 `citations.json`에 기록합니다.
5. **출력**: 버전 디렉토리에 `{output_file_name}` 저장
   - 경로: `.claude/artifacts/{output_dir_name}/v{N}/{output_file_name}`

---

## 에이전트 프롬프트 템플릿

각 에이전트에게 전달하는 프롬프트 구조:

```
당신은 {role_name} 전문가입니다.

## 프로젝트 컨텍스트
{project.json 내용}

## 당신의 역할
{agent-team-spec.md에서 해당 역할 섹션}

## 증거 자료
다음 증거 인덱스와 청크를 참고하세요:
{sources.jsonl 내용}
{관련 청크 파일 내용}

## 출력 규칙
1. agent-team-spec.md의 JSON 계약을 준수하세요.
2. 모든 주장(claim)에는 반드시 citation을 포함하세요 (citation-spec.md 참조).
3. JSON 파일과 Markdown 파일을 모두 생성하세요.
4. JSON 키는 알파벳순으로 정렬하세요.

## 출력 경로
- JSON: .claude/artifacts/agents/{role}.json
- Markdown: .claude/artifacts/agents/{role}.md
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

## 완료 후 안내

1. `/verify`로 출력물의 구조와 인용을 검증하세요.
2. 문서를 검토하고 피드백이 있으면 `/run-research`를 다시 실행하면 v{N+1}이 생성됩니다.
3. 새로운 소스를 추가하려면 `/sync-drive` → `/run-research`를 다시 실행하세요.
4. 또는 `/auto-generate`로 전체 파이프라인을 한번에 재실행할 수 있습니다.
