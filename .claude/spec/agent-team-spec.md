# Agent Team Specification (Single Source of Truth)

이 문서는 문서 생성 에이전트 팀의 **유일한 정의 문서**입니다.
모든 명령어와 에이전트는 이 사양을 참조해야 합니다.

> **동적 에이전트 로스터**: 실행 시 `.claude/spec/document-types.yaml`의 `agent_roles.wave1`에 의해
> 활성 역할이 결정됩니다. 아래 6역할 중 문서 유형에 해당하는 에이전트만 실행됩니다.

---

## 역할 로스터 (8역할)

| # | Role ID | 한국어명 | 책임 범위 |
|---|---------|---------|----------|
| 1 | `biz` | 비즈니스/전략 | 비즈니스 목표, 성공 지표, 경쟁 환경, 시장 기회 |
| 2 | `marketing` | 마케팅/GTM | 포지셔닝, 메시징 필러, 채널 전략, 런칭 계획 |
| 3 | `research` | 리서치 | 사용자 인사이트, 증거 맵, 가정 검증, 미지 영역 |
| 4 | `tech` | 기술 | 기술 타당성, 아키텍처, 통합, 비기능 요구사항 |
| 5 | `pm` | PM | 스코프(in/out), 요구사항, 마일스톤, 수용 기준, 의존성 |
| 6 | `critique` | 비판적 검토 | Wave 1 전체 결과 교차 검토, 논리적 오류/모순/누락 식별, 개선 권고 |
| 7 | `judge` | 판정관 | Phase 1+2 토론 결과 수신, 각 충돌 쌍 서술형 판정(승/패/무승부), 합의점 도출 |
| 8 | `synth` | 통합/종합 | Wave 1.5(debate 포함) 결과 머지, 충돌 해결, 최종 문서 작성 (문서 유형에 따라 구조 결정) |

---

## 실행 패턴

### Wave 1 — Phase 1: 개별 비판 (병렬)

biz, marketing, research, tech, pm 에이전트가 각각 독립적으로 실행됩니다.
각 에이전트는 `.claude/knowledge/evidence/` 내 증거 청크만 참조합니다.
**Debate Mode**: Phase 1 완료 후 에이전트는 종료하지 않고 Phase 2 메시지를 대기합니다.
각 에이전트는 `critical_issue` 필드에 자기 관점의 가장 치명적인 문제 1개를 반드시 포함합니다.

### Wave 1.5 — Phase 2: 교차 반박 (Clash Protocol)

**Step A (팀 리더 직접 수행)**: Wave 1 완료 후 모든 에이전트의 `critical_issue`를 읽고,
충돌 가능성이 높은 3-5개 쌍을 동적으로 선정하여 `debate/clashes.json`에 저장합니다.

**Step B (에이전트 간 소통)**: 팀 리더가 각 공격자 에이전트에게 SendMessage로 공격 대상 전달.
각 에이전트는 상대방의 `critical_issue`를 자신의 관점에서 반박하고 결과를 `debate/phase2/`에 저장합니다.

### Wave 1.75 — Phase 3: Judge 판정 (순차)

judge 에이전트가 Phase 1 + Phase 2 전체 결과를 읽고 각 충돌에 대해
서술형 판정(tech_wins / pm_wins / draw)을 내리고 합의점을 도출합니다.

### Wave 1.5(critique) — 비판적 검토 (Judge 완료 후, Wave 2 이전)

critique 에이전트가 Wave 1의 모든 결과(JSON + MD) + debate 결과를 읽고 비판적으로 검토합니다.
논리적 오류, 근거 없는 주장, 역할 간 모순, 누락된 관점을 식별하고 synth를 위한 개선 권고를 제공합니다.

### Wave 2 — 순차 (critique 완료 후)

synth 에이전트가 Wave 1, debate(clashes + phase2 + judgment), critique 결과를 모두 읽고 최종 문서를 생성합니다.
Judge의 `adopted_for_synth` 필드를 요구사항 결정 시 우선 반영합니다.
문서 구조는 `document-types.yaml`의 `output_sections`를 따릅니다.

---

## 모델 선택

각 에이전트에 할당되는 모델은 `.claude/spec/model-selection-spec.md`를 따릅니다.

- **Wave 1 기본**: `sonnet` (단일 도메인 구조화 분석)
- **Wave 2 기본**: `opus` (다중 소스 통합, 충돌 해결, 최종 문서 작성)
- 프로젝트별/문서 유형별 오버라이드 가능 (`project.json` > `document-types.yaml` > 기본값)

---

## 팀 통신 규칙 (TeamCreate 모드)

### 팀원 공통 절차 (Debate Mode)

**Phase 1 (개별 비판):**
1. `TaskList`로 Phase 1 태스크 확인
2. `TaskUpdate`로 클레임 (owner + in_progress)
3. 분석 수행 + **`critical_issue` 포함** 파일 생성
4. `TaskUpdate`로 완료 (completed)
5. `SendMessage`로 팀 리더에게 "Phase 1 완료, Phase 2 대기 중" 전송
6. **Phase 2 메시지 또는 shutdown_request 대기**

**Phase 2 (교차 반박, 팀 리더로부터 할당된 경우):**
7. 팀 리더로부터 공격 대상 정보 수신 (SendMessage)
8. 자신의 Phase 1 출력 + 공격 대상의 `critical_issue`를 바탕으로 교차 반박 작성
9. Phase 2 결과 파일 생성 (`.claude/artifacts/agents/debate/phase2/{attacker}-attacks-{target}.json` + `.md`)
10. `SendMessage`로 팀 리더에게 "Phase 2 완료" 전송
11. `shutdown_request` 수신 시 승인

> **Phase 2가 할당되지 않은 에이전트**: Phase 1 완료 후 shutdown_request를 받으면 즉시 승인합니다.

### 팀 리더 역할

1. `TeamCreate`로 팀 생성
2. `TaskCreate`로 태스크 정의 (Wave 1 Phase 1 + critique + judge + synth)
3. `blockedBy` 설정: critique → Wave 1 전체, judge → critique, synth → judge
4. `Task` tool로 Wave 1 팀원 병렬 생성
5. Wave 1 Phase 1 완료 메시지 수신 → 모든 `critical_issue` 읽기
6. **동적 Clash Pair 분석** → 충돌 쌍 3-5개 선정 → `debate/clashes.json` 저장
7. 각 공격자 에이전트에게 `SendMessage`로 Phase 2 할당 (공격 대상 + 각도 포함)
8. Phase 2 완료 메시지 수집 후 judge 팀원 생성
9. judge 완료 후 critique 팀원 생성
10. critique 완료 후 synth 팀원 생성
11. 전체 완료 후 모든 팀원에게 `shutdown_request` → `TeamDelete`

---

## JSON 출력 계약 (공통 Envelope)

모든 역할 에이전트는 다음 JSON 구조로 출력해야 합니다.

```json
{
  "role": "<role_id>",
  "version": "1.0",
  "project": "<project_name>",
  "inputs": {
    "evidence_index": ".claude/knowledge/evidence/index/sources.jsonl",
    "chunks_used": ["<chunk_id_1>", "<chunk_id_2>"]
  },
  "critical_issue": {
    "id": "CI-001",
    "statement": "자기 관점에서 가장 치명적인 문제 1개 (Phase 2 교차 반박의 기반)",
    "impact": "high",
    "citations": [
      {
        "chunk_id": "SRC-<name>@<hash>#chunk-0001",
        "source_name": "문서명",
        "line_start": 12,
        "line_end": 18,
        "quote_sha256": "<sha256>"
      }
    ]
  },
  "claims": [
    {
      "id": "CLM-001",
      "statement": "주장 내용",
      "confidence": "high|medium|low",
      "citations": [
        {
          "chunk_id": "SRC-<name>@<hash>#chunk-0001",
          "source_name": "문서명",
          "line_start": 12,
          "line_end": 18,
          "quote_sha256": "<sha256>"
        }
      ]
    }
  ],
  "open_questions": [
    {
      "id": "Q-001",
      "question": "미해결 질문",
      "priority": "high|medium|low",
      "citations": []
    }
  ],
  "risks": [
    {
      "id": "RSK-001",
      "risk": "리스크 설명",
      "impact": "high|medium|low",
      "mitigation": "완화 방안",
      "citations": []
    }
  ]
}
```

### 필수 규칙

1. **critical_issue 필수**: 모든 Wave 1 에이전트는 `critical_issue` 필드를 반드시 포함해야 합니다. 이 필드는 Phase 2 교차 반박의 기반이 됩니다.
2. **citations 필수**: `claims[]`의 모든 항목에는 최소 1개의 citation이 있어야 합니다. `critical_issue`에도 가능하면 citation을 포함합니다.
3. **open_questions, risks**: citation이 없을 수 있으나, 가능하면 포함합니다.
4. **chunk_id 형식**: `citation-spec.md`에 정의된 형식을 따릅니다.
5. **JSON 정렬**: 키는 알파벳순으로 정렬하여 결정론적 출력을 보장합니다.

---

## Phase 2 출력 계약 (교차 반박)

Wave 1 에이전트가 Phase 2 할당을 받으면 다음 형식으로 출력합니다.

```json
{
  "attacker_role": "<공격자 role_id>",
  "clash_id": "CLASH-001",
  "target_role": "<공격 대상 role_id>",
  "target_critical_issue_id": "CI-001",
  "attack_argument": "공격자 관점에서의 구체적 반박 논거",
  "attack_evidence": "반박을 뒷받침하는 근거 (증거 또는 논리)",
  "proposed_resolution": "공격자가 제안하는 해결 방향",
  "citations": []
}
```

출력 경로: `.claude/artifacts/agents/debate/phase2/{attacker}-attacks-{target}.json` + `.md`

---

## Judge 출력 계약

```json
{
  "role": "judge",
  "version": "1.0",
  "project": "<project_name>",
  "clashes": [
    {
      "clash_id": "CLASH-001",
      "attacker": "<role_id>",
      "target": "<role_id>",
      "judgment": "attacker_wins | target_wins | draw",
      "reasoning": "판정 근거 서술 (어떤 논거가 더 타당한지, 왜)",
      "consensus_point": "양측에서 수용 가능한 합의점",
      "adopted_for_synth": "최종 문서 요구사항에 반영할 구체적 내용"
    }
  ],
  "unresolved_clashes": [
    {
      "clash_id": "CLASH-003",
      "reason": "미판정 사유 (예: Phase 2 응답 없음)"
    }
  ],
  "overall_summary": "전체 토론 요약 — 핵심 충돌과 합의 방향"
}
```

출력 경로: `.claude/artifacts/agents/debate/judgment.json` + `.claude/artifacts/agents/debate/summary.md`

---

## 역할별 필수 섹션

### biz (비즈니스/전략)
- 문제 정의 및 기회
- 대상 사용자/고객
- 비즈니스 목표 및 성공 지표 (KPI)
- 경쟁 환경 분석
- 수익 모델 / 비용 구조

### marketing (마케팅/GTM)
- 포지셔닝 전략
- 핵심 메시징 필러
- 타겟 채널
- 런칭 단계 계획
- 차별화 포인트

### research (리서치)
- 사용자 인사이트 요약
- 증거 맵 (출처별 핵심 발견)
- 가정 목록 및 검증 상태
- 미지 영역 (unknowns)
- 추가 리서치 필요 항목

### tech (기술)
- 기술 타당성 평가
- 아키텍처 개요
- 주요 기술 의사결정
- 통합 포인트 (외부 시스템)
- 비기능 요구사항 (성능, 보안, 확장성)

### pm (PM)
- 스코프 정의 (In-Scope / Out-of-Scope)
- 기능 요구사항 목록
- 비기능 요구사항
- 마일스톤 및 일정
- 수용 기준 (Acceptance Criteria)
- 의존성

### critique (비판적 검토)
- 역할별 비판 요약 (각 에이전트의 장점/약점)
- 논리적 오류 또는 근거 없는 주장 (citation 없는 claims)
- 역할 간 모순 및 충돌 (예: biz vs tech 간 상충)
- 누락된 관점 / 갭 (기존 Wave 1 역할로 커버되지 않는 부분)
- synth를 위한 개선 권고사항

### judge (판정관)
- 각 Clash Pair별 판정: attacker_wins / target_wins / draw
- 판정 근거: 어느 논거가 더 타당하고 증거 기반인지 서술
- 합의점 도출: 양측에서 수용 가능한 중간 지점
- `adopted_for_synth`: synth 에이전트가 요구사항 작성 시 반영할 구체적 내용
- 전체 토론 요약: 핵심 충돌과 결과 서술 (`summary.md`)

### synth (통합/종합)
- Wave 1 + debate(clashes + phase2 + judgment) + critique 결과 통합 요약
- Judge의 `adopted_for_synth` 필드를 요구사항 작성 시 우선 반영
- critique의 지적 사항 고려하여 충돌 사항 및 해결 내용 반영 (`conflicts.json`)
- 최종 문서 렌더링 (`{output_file_name}` — `document-types.yaml` 참조)
- 인용 보고서 (`citations.json`)
- 미해결 질문 종합
- **문서 구조**: `document-types.yaml`의 `output_sections`에 정의된 섹션을 순서대로 작성
- **전문가 토론 요약 섹션**: `debate/summary.md`의 내용을 기반으로 작성

---

## 동적 역할 (Dynamic Roles)

프로젝트 주제에 따라 기존 역할로 커버되지 않는 영역이 감지되면,
`run-research` Step 0.6에서 추가 역할을 자동 제안합니다.

### 동적 역할 규칙

1. **역할 ID**: `/^[a-z][a-z0-9-]*$/` 패턴 준수 (영문 소문자 시작, 소문자/숫자/하이픈만 허용). 기존 역할 ID(`biz`, `marketing`, `research`, `tech`, `pm`, `critique`, `synth`)와 중복 불가. 저장 전 반드시 검증.
2. **JSON 계약**: 기존 에이전트와 동일한 공통 Envelope 사용 (위 "JSON 출력 계약" 참조)
3. **출력 경로**: `.claude/artifacts/agents/{role_id}.json` + `{role_id}.md`
4. **증거 분배**: `keywords` 배열의 키워드로 관련 청크를 필터링하여 분배
5. **최대 개수**: 동적 역할은 최대 3개까지 제안 (너무 많으면 품질 저하)
6. **저장 위치**: `project.json`의 `dynamic_roles[]` (프로젝트별, gitignored 상태 파일). `document-types.yaml`이나 `agent-team-spec.md`에는 반영하지 않음 (템플릿 파일 보호).
7. **synth 통합**: synth 에이전트는 동적 역할 출력도 Wave 1 결과로 동일하게 처리
8. **허용 플래그**: `document-types.yaml`의 `allow_dynamic_roles`가 `true`인 문서 유형에서만 활성화
9. **필수 필드 검증**: 각 동적 역할은 `role_id`, `name`(비어있지 않음), `responsibility`(비어있지 않음), `keywords`(최소 1개), `output_sections`(최소 1개)를 모두 갖추어야 함. 검증 실패 시 해당 역할 제외.
10. **감사 추적**: `project.json`에 `dynamic_roles_meta` 객체를 함께 저장 (변경자, 시각, 액션, 이전 역할 목록)

### 동적 역할 데이터 구조

`project.json`에 저장되는 각 동적 역할의 형식:

```json
{
  "role_id": "ops",
  "name": "운영/프로세스",
  "responsibility": "운영 프로세스 분석, 워크플로우 최적화, 변경 관리",
  "keywords": ["운영", "프로세스", "워크플로우", "SOP", "변경관리"],
  "output_sections": ["운영 현황 분석", "프로세스 개선 방안", "변경 관리 계획"]
}
```

### 동적 역할 프롬프트 템플릿

기존 에이전트 프롬프트 템플릿과 동일하되, 역할 정의를 `agent-team-spec.md`의 고정 섹션 대신
`project.json`의 `dynamic_roles`에서 로드합니다:

- 역할명 → `dynamic_roles[].name`
- 책임 범위 → `dynamic_roles[].responsibility`
- 필수 섹션 → `dynamic_roles[].output_sections`

---

## 출력 파일 경로

### Phase 1 (Wave 1 에이전트)

| 에이전트 | JSON | Markdown |
|---------|------|----------|
| biz | `.claude/artifacts/agents/biz.json` | `.claude/artifacts/agents/biz.md` |
| marketing | `.claude/artifacts/agents/marketing.json` | `.claude/artifacts/agents/marketing.md` |
| research | `.claude/artifacts/agents/research.json` | `.claude/artifacts/agents/research.md` |
| tech | `.claude/artifacts/agents/tech.json` | `.claude/artifacts/agents/tech.md` |
| pm | `.claude/artifacts/agents/pm.json` | `.claude/artifacts/agents/pm.md` |

### Phase 2 (교차 반박)

| 파일 | 설명 |
|------|------|
| `.claude/artifacts/agents/debate/clashes.json` | 팀 리더가 결정한 동적 Clash Pair 목록 |
| `.claude/artifacts/agents/debate/phase2/{attacker}-attacks-{target}.json` | 교차 반박 JSON |
| `.claude/artifacts/agents/debate/phase2/{attacker}-attacks-{target}.md` | 교차 반박 서술형 |

### Phase 3 (Judge)

| 파일 | 설명 |
|------|------|
| `.claude/artifacts/agents/debate/judgment.json` | Judge 판정 결과 (승/패/무승부 + 합의점) |
| `.claude/artifacts/agents/debate/summary.md` | 인간 읽기용 전체 토론 요약 |

### Critique & Synth

| 에이전트 | JSON | Markdown |
|---------|------|----------|
| critique | `.claude/artifacts/agents/critique.json` | `.claude/artifacts/agents/critique.md` |
| synth | `.claude/artifacts/{output_dir}/v{N}/{output_file}` | — |
| synth | `.claude/artifacts/{output_dir}/v{N}/citations.json` | — |
| synth | `.claude/artifacts/{output_dir}/v{N}/conflicts.json` | — |

> `{output_dir}`, `{output_file}`은 `document-types.yaml`의 해당 문서 유형에서 결정됩니다.
