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
   - `agent_roles.wave1` → 회의(Discussion)에서 실행할 에이전트 목록
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
2. 기존 회의(Discussion) 역할이 커버하는 영역을 파악합니다:
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
- 회의(Discussion): 동적 역할도 기존 에이전트와 함께 Task tool로 병렬 실행
- 통합(Synth): 동적 에이전트 출력도 통합 대상에 포함

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

회의(Discussion) 에이전트 실행 전에 증거를 한 번만 읽고 역할별로 분배합니다. 에이전트당 컨텍스트를 60~70% 줄여 성능을 높입니다.

1. `sources.jsonl`과 전체 청크를 한 번만 읽습니다.
2. 각 청크를 키워드/주제로 분류하여 역할별 관련 청크를 분배합니다:
   - 비즈니스/시장/매출/KPI/경쟁 → `biz`, `marketing`
   - 사용자/인사이트/설문/페르소나 → `research`
   - 기술/아키텍처/API/인프라/성능 → `tech`
   - 요구사항/일정/마일스톤/스코프 → `pm`
   - **동적 역할**: `project.json`의 `dynamic_roles[].keywords`를 읽어 추가 매핑 생성
   - 분류 불가 → 모든 에이전트에 전달
3. 에이전트 프롬프트에 파일 경로 대신 **사전 조합된 텍스트**를 전달합니다.

### Step 0.8: 모델 결정

`.claude/spec/model-selection-spec.md`의 `resolveModel` 알고리즘에 따라 각 에이전트의 모델을 결정합니다.

1. `project.json`에서 `model_overrides` 필드를 확인합니다 (없으면 건너뜀).
2. `document-types.yaml`에서 현재 문서 유형의 `model_overrides` 필드를 확인합니다 (없으면 건너뜀).
3. 오버라이드가 없으면 기본값을 적용합니다:
   - 회의(Discussion) 에이전트 (고정 + 동적): `sonnet`
   - 판정(Judge) 에이전트: `opus`
   - 비평(Critique) 에이전트: `opus`
   - 통합(Synth) 에이전트: `opus`
4. 결정된 모델이 `opus`, `sonnet`, `haiku` 중 하나인지 검증합니다. 유효하지 않으면 해당 단계의 기본값으로 폴백합니다.

---

### 팀 구성

1. `TeamCreate(team_name="research-v{N}")`로 팀을 생성합니다.
2. 회의(Discussion) 역할마다 `TaskCreate` 호출:
   - subject: "{role_name} 분석 수행"
   - activeForm: "{role_name} 분석 중"
3. Judge용 `TaskCreate`:
   - subject: "토론 판정 수행"
   - activeForm: "토론 판정 중"
   - `addBlockedBy=[모든 회의 에이전트 task ID]`
4. Critique용 `TaskCreate`:
   - subject: "비판적 검토 수행"
   - activeForm: "비판적 검토 중"
   - `addBlockedBy=[judge task ID]`
5. Synth용 `TaskCreate`:
   - subject: "통합 문서 생성"
   - activeForm: "통합 문서 생성 중"
   - `addBlockedBy=[critique task ID]`

### 회의 (Discussion): 도메인 에이전트 병렬 생성

`document-types.yaml`의 `agent_roles.wave1`에 정의된 에이전트 + `project.json`의 `dynamic_roles`에 정의된 동적 에이전트를 합산하여 팀원으로 **병렬** 생성합니다.

모든 도메인 역할에 대해 **동시에** Task tool 호출:

```
Task(
  team_name="research-v{N}",
  name="{role}-agent",
  subagent_type="general-purpose",
  prompt="... (에이전트 프롬프트 + 회의 참석자 목록 + Peer Messaging Protocol)\n\n권장 모델: sonnet (Step 0.8에서 결정)"
)
```

> **주의**: Task tool에서 명시적 모델 지정을 지원하지 않으므로, 프롬프트 내 "권장 모델" 안내는 참고사항입니다.
> 실제 모델 선택은 에이전트의 기본 동작을 따릅니다.

각 에이전트에게 전달할 컨텍스트:
- `.claude/state/project.json` (프로젝트 설정)
- `.claude/knowledge/evidence/index/sources.jsonl` (증거 인덱스)
- `.claude/knowledge/evidence/chunks/` (증거 청크 파일들)
- `.claude/spec/agent-team-spec.md` (역할 정의 + JSON 계약 + Peer Messaging Protocol)
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

#### 동적 역할 에이전트

`project.json`에 `dynamic_roles`가 있으면 해당 역할도 회의 단계에 포함하여 팀원으로 병렬 생성합니다.
동적 역할 에이전트의 프롬프트는 기존 템플릿과 동일하되:
- 역할 정의를 `agent-team-spec.md` 대신 `dynamic_roles[]`에서 로드
- 필수 섹션을 `dynamic_roles[].output_sections`에서 로드
- 출력 경로: `.claude/artifacts/agents/{role_id}.json` + `{role_id}.md`
- 회의 참석자 목록 + Peer Messaging Protocol을 동일하게 포함

### 회의 완료 → 토론 기록 수집

모든 도메인 에이전트가 완료되면 팀 리더가 다음을 수행합니다:

1. 각 에이전트의 JSON 출력에서 `peer_discussions` 배열을 수집
2. 모든 `peer_discussions`를 통합하여 `.claude/artifacts/agents/debate/discussions.json`에 저장
3. 미해결 충돌 (`outcome: "unresolved"`) 건수를 확인

### 판정 (Judge): 토론 판정 에이전트 생성 (순차, 회의 완료 후)

`TaskList`로 judge 태스크의 `blockedBy` 해소를 확인한 후 judge 팀원을 생성합니다.

```
Task(
  team_name="research-v{N}",
  name="judge-agent",
  subagent_type="general-purpose",
  prompt="... (judge 프롬프트 + 팀 통신 블록)\n\n권장 모델: opus (Step 0.8에서 결정)"
)
```

- 입력: 모든 도메인 에이전트 JSON (peer_discussions 포함) + `debate/discussions.json`
- 역할: 미해결 충돌에 대한 서술형 판정(승/패/무승부), 합의점 도출

##### Judge 팀원 절차:

1. `TaskList` → "토론 판정 수행" 태스크 클레임
2. `TaskUpdate(owner="judge-agent", status="in_progress")`
3. 회의 결과 읽기 (모든 역할의 JSON + `debate/discussions.json`)
4. **미해결 충돌 판정**:
   - `peer_discussions`에서 `outcome: "unresolved"` 항목을 수집
   - 각 충돌에 대해: 양측 주장, 근거, 증거를 비교 분석
   - 승/패/무승부 판정 + 판정 근거 서술
   - `adopted_for_synth`: synth가 최종 문서에 반영할 구체적 내용
5. **이미 해결된 합의 확인**: `outcome: "resolved"` 항목을 승인
6. **전체 토론 요약**: 인간 읽기용 `summary.md` 작성
7. `judgment.json` + `summary.md` 생성 → `debate/` 디렉토리에 저장
8. `TaskUpdate(status="completed")`
9. `SendMessage(recipient="team-lead", summary="토론 판정 완료")`

### 비평 (Critique): 비판적 검토 에이전트 생성 (순차, 판정 완료 후)

`TaskList`로 critique 태스크의 `blockedBy` 해소를 확인한 후 critique 팀원을 생성합니다.

```
Task(
  team_name="research-v{N}",
  name="critique-agent",
  subagent_type="general-purpose",
  prompt="... (critique 프롬프트 + 팀 통신 블록)\n\n권장 모델: opus (Step 0.8에서 결정)"
)
```

- 입력: 모든 도메인 에이전트 JSON + MD + `debate/discussions.json` + `debate/judgment.json` + `debate/summary.md`
- 역할: 전체 결과(토론 기록 + 판정 포함) 비판적 검토, 논리적 오류/모순/누락 식별

##### Critique 팀원 절차:

1. `TaskList` → "비판적 검토 수행" 태스크 클레임
2. `TaskUpdate(owner="critique-agent", status="in_progress")`
3. 회의 결과 + 판정 결과 읽기 (모든 역할의 JSON + MD + debate/ 전체)
4. **비판적 검토 수행**:
   - 역할별 비판 요약 (장점, 약점, 신뢰도)
   - 논리적 오류 또는 근거 없는 주장 식별 (citation 부재)
   - Judge 판정 결과의 타당성 검토
   - 이미 해결된 충돌은 제외, 남은 모순 식별
   - 누락된 관점 또는 갭 식별
   - synth를 위한 개선 권고사항 제시
5. `critique.json` + `critique.md` 생성:
   - JSON: agent-team-spec.md의 공통 Envelope 준수
   - MD: 역할별 비판 내용을 구조화된 마크다운으로 작성
6. `TaskUpdate(status="completed")`
7. `SendMessage(recipient="team-lead", summary="비판적 검토 완료")`

### 통합 (Synth): 통합 에이전트 생성 (순차, 비평 완료 후)

`TaskList`로 synth 태스크의 `blockedBy` 해소를 확인한 후 synth 팀원을 생성합니다.

```
Task(
  team_name="research-v{N}",
  name="synth-agent",
  subagent_type="general-purpose",
  prompt="... (synth 프롬프트 + 팀 통신 블록)\n\n권장 모델: opus (Step 0.8에서 결정)"
)
```

- 입력: 모든 도메인 에이전트 JSON + MD (동적 역할 포함) + debate/ 전체 (discussions, judgment, summary) + critique.json/md
- 역할: Judge의 `adopted_for_synth` 우선 반영, 비판 지적 고려, 충돌 해결, 최종 문서 작성

##### Synth 팀원 절차:

1. `TaskList` → "통합 문서 생성" 태스크 클레임
2. `TaskUpdate(owner="synth-agent", status="in_progress")`
3. 전체 결과 읽기 (회의 결과 + debate/ + critique)
4. **Judge 판정 반영**: `judgment.json`의 `adopted_for_synth` 필드를 요구사항 결정 시 우선 반영
5. **충돌 식별 및 해결**: 역할 간 상충하는 주장 중 Judge가 판정하지 않은 잔여 충돌을 해결
   - 충돌 항목은 `conflicts.json`에 기록
6. **전문가 토론 요약 섹션 작성**: `debate/summary.md` 기반으로 토론 핵심 내용 요약
7. **통합 문서 작성**: 모든 역할(고정 + 동적)의 핵심 내용을 통합하여 최종 문서 작성
   - 문서 구조는 `document-types.yaml`의 `output_sections`를 따름
   - 동적 역할의 관점은 관련 섹션에 자연스럽게 통합 (별도 섹션 불필요)
8. **인용 보고서**: 모든 인용을 `citations.json`에 기록
9. **출력**: 버전 디렉토리에 `{output_file_name}` 저장
   - 경로: `.claude/artifacts/{output_dir_name}/v{N}/{output_file_name}`
10. `TaskUpdate(status="completed")`
11. `SendMessage(recipient="team-lead", summary="통합 문서 생성 완료")`

### 팀 정리

1. 모든 팀원에게 `SendMessage(type="shutdown_request")` 전송
2. 승인 수신 후 `TeamDelete()` 호출

---

## 에이전트 프롬프트 템플릿

### 회의(Discussion) 에이전트 프롬프트 — 고정 역할

```
당신은 {role_name} 전문가입니다.

## 프로젝트 컨텍스트
{project.json 내용}

## 당신의 역할
{agent-team-spec.md에서 해당 역할 섹션}

## 회의 참석자
아래 에이전트들과 실시간으로 소통할 수 있습니다:
{참석자 목록: 각 role-agent 이름 + 담당 영역}
예시:
- biz-agent: 비즈니스 목표, 성공 지표, 경쟁 환경, 시장 기회
- marketing-agent: 포지셔닝, 메시징, 채널 전략, 런칭 계획
- research-agent: 사용자 인사이트, 증거 맵, 가정 검증
- tech-agent: 기술 타당성, 아키텍처, 비기능 요구사항
- pm-agent: 스코프, 요구사항, 마일스톤, 수용 기준

## 소통 규칙 (Peer Messaging Protocol)
분석 도중 다른 역할에 영향을 주는 문제를 발견하면:
→ 해당 에이전트에게 직접 SendMessage를 보내 질문/의견을 전달하세요.
→ 응답을 받으면 자신의 분석에 반영하세요.
→ 같은 상대, 같은 주제로 최대 3회 왕복 교환 후에도 합의 안 되면 peer_discussions에 outcome: "unresolved"로 기록하세요.
→ 에이전트당 총 발신 메시지: 최대 10개.

다른 에이전트로부터 질문/의견을 받으면:
→ 반드시 자신의 관점에서 응답하세요.
→ 응답에는: 자신의 관점 + 수용/반박 의사 + 근거를 포함하세요.
→ 필요시 자신의 분석을 수정하세요.

## 증거 자료 (사전 필터링됨)
Step 0.7에서 이 역할에 관련된 증거만 선별하여 전달합니다.
전체 인덱스가 아닌, 역할별로 분배된 청크 텍스트를 포함합니다:
{역할별 사전 조합된 증거 텍스트}

## 출력 규칙
1. agent-team-spec.md의 JSON 계약을 준수하세요.
2. 모든 주장(claim)에는 반드시 citation을 포함하세요 (citation-spec.md 참조).
3. critical_issue: 자기 관점에서 가장 치명적인 문제 1개를 반드시 포함하세요.
4. peer_discussions: 회의 중 다른 에이전트와 나눈 토론을 기록하세요 (토론 없으면 빈 배열).
5. JSON 파일과 Markdown 파일을 모두 생성하세요.
6. JSON 키는 알파벳순으로 정렬하세요.

## 출력 경로
- JSON: .claude/artifacts/agents/{role}.json
- Markdown: .claude/artifacts/agents/{role}.md

## 팀 통신 (필수)
당신은 "research-v{N}" 팀의 "{role}-agent" 팀원입니다.
`.claude/spec/agent-team-spec.md`의 "팀원 공통 절차 (Live Meeting Mode)"를 반드시 따르세요.
태스크명: "{role_name} 분석 수행"
```

### 회의(Discussion) 에이전트 프롬프트 — 동적 역할

고정 역할과 동일한 구조이되, 역할 정의를 `project.json`의 `dynamic_roles`에서 로드합니다:

```
당신은 {dynamic_roles[].name} 전문가입니다.

## 프로젝트 컨텍스트
{project.json 내용}

## 당신의 역할
- 역할명: {dynamic_roles[].name}
- 책임 범위: {dynamic_roles[].responsibility}
- 필수 출력 섹션: {dynamic_roles[].output_sections}

## 회의 참석자
아래 에이전트들과 실시간으로 소통할 수 있습니다:
{참석자 목록: 각 role-agent 이름 + 담당 영역}

## 소통 규칙 (Peer Messaging Protocol)
분석 도중 다른 역할에 영향을 주는 문제를 발견하면:
→ 해당 에이전트에게 직접 SendMessage를 보내 질문/의견을 전달하세요.
→ 응답을 받으면 자신의 분석에 반영하세요.
→ 같은 상대, 같은 주제로 최대 3회 왕복 교환 후에도 합의 안 되면 peer_discussions에 outcome: "unresolved"로 기록하세요.
→ 에이전트당 총 발신 메시지: 최대 10개.

다른 에이전트로부터 질문/의견을 받으면:
→ 반드시 자신의 관점에서 응답하세요.
→ 응답에는: 자신의 관점 + 수용/반박 의사 + 근거를 포함하세요.
→ 필요시 자신의 분석을 수정하세요.

## 증거 자료 (사전 필터링됨)
Step 0.7에서 이 역할의 keywords에 매칭된 증거만 선별하여 전달합니다:
{역할별 사전 조합된 증거 텍스트}

## 출력 규칙
1. agent-team-spec.md의 JSON 계약(공통 Envelope)을 준수하세요.
2. 모든 주장(claim)에는 반드시 citation을 포함하세요 (citation-spec.md 참조).
3. critical_issue: 자기 관점에서 가장 치명적인 문제 1개를 반드시 포함하세요.
4. peer_discussions: 회의 중 다른 에이전트와 나눈 토론을 기록하세요 (토론 없으면 빈 배열).
5. JSON 파일과 Markdown 파일을 모두 생성하세요.
6. JSON 키는 알파벳순으로 정렬하세요.

## 출력 경로
- JSON: .claude/artifacts/agents/{role_id}.json
- Markdown: .claude/artifacts/agents/{role_id}.md

## 팀 통신 (필수)
당신은 "research-v{N}" 팀의 "{role}-agent" 팀원입니다.
`.claude/spec/agent-team-spec.md`의 "팀원 공통 절차 (Live Meeting Mode)"를 반드시 따르세요.
태스크명: "{role_name} 분석 수행"
```

### Judge 에이전트 프롬프트

```
당신은 토론 판정관입니다.

## 프로젝트 컨텍스트
{project.json 내용}

## 당신의 역할
- 역할명: 판정관 (Judge)
- 책임 범위: 회의 중 발생한 미해결 충돌에 대해 서술형 판정을 작성하고 합의점을 도출합니다.

## 검토 대상
회의 에이전트들의 JSON 파일 (peer_discussions 포함):
{활성 에이전트 목록의 JSON 경로}
토론 기록: .claude/artifacts/agents/debate/discussions.json

## 판정 규칙
1. peer_discussions에서 outcome: "unresolved" 항목을 모두 수집하세요.
2. 각 충돌에 대해: 양측 주장, 근거, 증거를 비교 분석하세요.
3. 판정: tech_wins | pm_wins | biz_wins | ... | draw 형식으로 결정하세요.
4. reasoning: 왜 해당 판정이 타당한지 서술하세요.
5. consensus_point: 양측에서 수용 가능한 합의점을 제시하세요.
6. adopted_for_synth: synth가 최종 문서에 반영할 구체적 내용을 명시하세요.
7. outcome: "resolved" 항목은 already_resolved에 확인 기록하세요.
8. overall_summary: 전체 토론의 핵심 흐름을 요약하세요.

## 출력 형식
agent-team-spec.md의 "Judge 출력 계약"을 준수하세요.

## 출력 경로
- JSON: .claude/artifacts/agents/debate/judgment.json
- Markdown: .claude/artifacts/agents/debate/summary.md

## 팀 통신 (필수)
당신은 "research-v{N}" 팀의 "judge-agent" 팀원입니다.
`.claude/spec/agent-team-spec.md`의 "팀원 공통 절차"를 반드시 따르세요.
태스크명: "토론 판정 수행"
```

### Critique 에이전트 프롬프트

```
당신은 비판적 검토 전문가입니다.

## 프로젝트 컨텍스트
{project.json 내용}

## 당신의 역할
- 역할명: 비판적 검토
- 책임 범위: 도메인 에이전트들의 분석 결과 + 토론 기록 + Judge 판정을 교차 검토하여 논리적 오류, 모순, 누락된 관점을 식별합니다.

## 검토 대상
도메인 에이전트들의 JSON 파일:
{활성 에이전트 목록의 JSON 경로}
토론 기록 및 판정:
- .claude/artifacts/agents/debate/discussions.json
- .claude/artifacts/agents/debate/judgment.json
- .claude/artifacts/agents/debate/summary.md

## 검토 항목
1. **논리적 오류**: 추론 과정에서의 논리적 오류 또는 근거 없는 주장 (citation 부재)
2. **역할 간 모순**: Judge가 판정하지 않은 잔여 모순
3. **Judge 판정 검증**: 판정 근거의 타당성 검토
4. **누락된 관점**: 중요하지만 어느 역할도 다루지 않은 영역
5. **지나친 낙관주의**: 현실성 없는 가정 또는 지나치게 낙관적인 평가

## 출력 규칙
1. agent-team-spec.md의 JSON 계약을 준수하세요.
2. 각 비판 항목은 하나의 claim으로 표현하세요.
3. 가능하면 해당 source의 chunk_id로 citation을 포함하세요.
4. JSON 키는 알파벳순으로 정렬하세요.

## 출력 경로
- JSON: .claude/artifacts/agents/critique.json
- Markdown: .claude/artifacts/agents/critique.md

## 팀 통신 (필수)
당신은 "research-v{N}" 팀의 "critique-agent" 팀원입니다.
`.claude/spec/agent-team-spec.md`의 "팀원 공통 절차"를 반드시 따르세요.
태스크명: "비판적 검토 수행"
```

### Synth 에이전트 프롬프트

```
당신은 문서 통합 전문가입니다.

## 프로젝트 컨텍스트
{project.json 내용}

## 당신의 역할
- 역할명: 통합/종합 (Synth)
- 책임 범위: 회의 결과 + 판정 + 비평을 모두 통합하여 최종 문서를 작성합니다.

## 입력 파일
도메인 에이전트 결과:
{활성 에이전트 목록의 JSON/MD 경로}
토론 기록 및 판정:
- .claude/artifacts/agents/debate/discussions.json
- .claude/artifacts/agents/debate/judgment.json
- .claude/artifacts/agents/debate/summary.md
비판적 검토:
- .claude/artifacts/agents/critique.json
- .claude/artifacts/agents/critique.md

## 통합 규칙
1. **Judge 판정 우선 반영**: judgment.json의 adopted_for_synth 필드를 요구사항 결정 시 우선 반영하세요.
2. **critique 지적 고려**: critique의 권고사항을 최종 문서에 반영하세요.
3. **전문가 토론 요약 섹션**: debate/summary.md 기반으로 토론 핵심 내용을 요약하는 섹션을 포함하세요.
4. **문서 구조**: document-types.yaml의 output_sections에 정의된 섹션을 순서대로 작성하세요.
5. **동적 역할 통합**: 동적 역할의 관점은 관련 섹션에 자연스럽게 통합하세요 (별도 섹션 불필요).
6. **충돌 기록**: 잔여 충돌은 conflicts.json에 기록하세요.
7. **인용 보고서**: 모든 인용을 citations.json에 기록하세요.

## 출력 경로
- 최종 문서: .claude/artifacts/{output_dir_name}/v{N}/{output_file_name}
- 인용 보고서: .claude/artifacts/{output_dir_name}/v{N}/citations.json
- 충돌 보고서: .claude/artifacts/{output_dir_name}/v{N}/conflicts.json
- 메타데이터: .claude/artifacts/{output_dir_name}/v{N}/metadata.json

## 팀 통신 (필수)
당신은 "research-v{N}" 팀의 "synth-agent" 팀원입니다.
`.claude/spec/agent-team-spec.md`의 "팀원 공통 절차"를 반드시 따르세요.
태스크명: "통합 문서 생성"
```

---

## 완료 후: Drive 업로드 확인

문서 생성이 완료되면:

### `/auto-generate`에서 호출된 경우
- 업로드 프롬프트를 **스킵**합니다.
- 컨텍스트: 프롬프트에 `called_from: auto-generate` 표시가 있음을 확인.
- 완료 상태만 반환 → auto-generate가 다음 단계(업로드 여부) 판단.

### 단독 실행된 경우 (`/run-research` 직접 호출)
사용자에게 물어봅니다:

> "{document_type_name} v{N}이 생성되었습니다. Google Drive에 업로드하시겠습니까?"

- 수락 시: `/upload-drive`를 실행합니다.
- 거부 시: "나중에 `/upload-drive`로 업로드할 수 있습니다."를 안내합니다.

---

## 출력

| 파일 | 설명 |
|------|------|
| `.claude/artifacts/agents/{role}.json` | 회의(Discussion) 각 역할의 구조화된 출력 (peer_discussions 포함) |
| `.claude/artifacts/agents/{role}.md` | 회의(Discussion) 각 역할의 서술형 요약 |
| `.claude/artifacts/agents/debate/discussions.json` | 팀 리더가 취합한 전체 peer_discussions |
| `.claude/artifacts/agents/debate/judgment.json` | Judge 판정 결과 (미해결 충돌 승/패/무승부) |
| `.claude/artifacts/agents/debate/summary.md` | 인간 읽기용 전체 토론 요약 |
| `.claude/artifacts/agents/critique.json` | 비평(Critique) 비판적 검토 구조화된 출력 |
| `.claude/artifacts/agents/critique.md` | 비평(Critique) 비판적 검토 서술형 요약 |
| `.claude/artifacts/{output_dir}/v{N}/{output_file}` | 최종 통합 문서 (버전별) |
| `.claude/artifacts/{output_dir}/v{N}/citations.json` | 전체 인용 보고서 |
| `.claude/artifacts/{output_dir}/v{N}/conflicts.json` | 역할 간 충돌 보고서 |
| `.claude/artifacts/{output_dir}/v{N}/metadata.json` | 버전 메타데이터 |

---

## 완료 후

auto-generate에서 호출된 경우 자동으로 다음 단계(검증)로 진행합니다.
