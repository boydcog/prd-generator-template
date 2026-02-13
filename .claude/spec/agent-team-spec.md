# Agent Team Specification (Single Source of Truth)

이 문서는 문서 생성 에이전트 팀의 **유일한 정의 문서**입니다.
모든 명령어와 에이전트는 이 사양을 참조해야 합니다.

> **동적 에이전트 로스터**: 실행 시 `.claude/spec/document-types.yaml`의 `agent_roles.wave1`에 의해
> 활성 역할이 결정됩니다. 아래 6역할 중 문서 유형에 해당하는 에이전트만 실행됩니다.

---

## 역할 로스터 (6역할)

| # | Role ID | 한국어명 | 책임 범위 |
|---|---------|---------|----------|
| 1 | `biz` | 비즈니스/전략 | 비즈니스 목표, 성공 지표, 경쟁 환경, 시장 기회 |
| 2 | `marketing` | 마케팅/GTM | 포지셔닝, 메시징 필러, 채널 전략, 런칭 계획 |
| 3 | `research` | 리서치 | 사용자 인사이트, 증거 맵, 가정 검증, 미지 영역 |
| 4 | `tech` | 기술 | 기술 타당성, 아키텍처, 통합, 비기능 요구사항 |
| 5 | `pm` | PM | 스코프(in/out), 요구사항, 마일스톤, 수용 기준, 의존성 |
| 6 | `synth` | 통합/종합 | Wave 1 역할 결과 머지, 충돌 해결, 최종 문서 작성 (문서 유형에 따라 구조 결정) |

---

## 실행 패턴

### Wave 1 — 병렬 (5개 동시)

biz, marketing, research, tech, pm 에이전트가 각각 독립적으로 실행됩니다.
각 에이전트는 `.claude/knowledge/evidence/` 내 증거 청크만 참조합니다.

### Wave 2 — 순차 (Wave 1 완료 후)

synth 에이전트가 Wave 1의 결과를 읽고 최종 문서를 생성합니다.
문서 구조는 `document-types.yaml`의 `output_sections`를 따릅니다.

---

## 팀 통신 규칙 (TeamCreate 모드)

### 팀원 공통 절차

1. `TaskList`로 태스크 확인
2. `TaskUpdate`로 클레임 (owner + in_progress)
3. 분석 수행 + 파일 생성
4. `TaskUpdate`로 완료 (completed)
5. `SendMessage`로 팀 리더에게 요약 전송
6. `shutdown_request` 수신 시 승인

### 팀 리더 역할

1. `TeamCreate`로 팀 생성
2. `TaskCreate`로 태스크 정의 (Wave 1 + Wave 2)
3. Wave 2 태스크에 `blockedBy` 설정
4. `Task` tool로 팀원 생성 (Wave 1 병렬, Wave 2 순차)
5. 완료 메시지 수신 → 사용자에게 진행 상황 보고
6. 전체 완료 후 `shutdown_request` → `TeamDelete`

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

1. **citations 필수**: `claims[]`의 모든 항목에는 최소 1개의 citation이 있어야 합니다.
2. **open_questions, risks**: citation이 없을 수 있으나, 가능하면 포함합니다.
3. **chunk_id 형식**: `citation-spec.md`에 정의된 형식을 따릅니다.
4. **JSON 정렬**: 키는 알파벳순으로 정렬하여 결정론적 출력을 보장합니다.

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

### synth (통합/종합)
- Wave 1 역할 결과 통합 요약
- 충돌 사항 및 해결 내용 (`conflicts.json`)
- 최종 문서 렌더링 (`{output_file_name}` — `document-types.yaml` 참조)
- 인용 보고서 (`citations.json`)
- 미해결 질문 종합
- **문서 구조**: `document-types.yaml`의 `output_sections`에 정의된 섹션을 순서대로 작성

---

## 동적 역할 (Dynamic Roles)

프로젝트 주제에 따라 기존 역할로 커버되지 않는 영역이 감지되면,
`run-research` Step 0.6에서 추가 역할을 자동 제안합니다.

### 동적 역할 규칙

1. **역할 ID**: `/^[a-z][a-z0-9-]*$/` 패턴 준수 (영문 소문자 시작, 소문자/숫자/하이픈만 허용). 기존 역할 ID(`biz`, `marketing`, `research`, `tech`, `pm`, `synth`)와 중복 불가. 저장 전 반드시 검증.
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

| 에이전트 | JSON | Markdown |
|---------|------|----------|
| biz | `.claude/artifacts/agents/biz.json` | `.claude/artifacts/agents/biz.md` |
| marketing | `.claude/artifacts/agents/marketing.json` | `.claude/artifacts/agents/marketing.md` |
| research | `.claude/artifacts/agents/research.json` | `.claude/artifacts/agents/research.md` |
| tech | `.claude/artifacts/agents/tech.json` | `.claude/artifacts/agents/tech.md` |
| pm | `.claude/artifacts/agents/pm.json` | `.claude/artifacts/agents/pm.md` |
| synth | `.claude/artifacts/{output_dir}/v{N}/{output_file}` | — |
| synth | `.claude/artifacts/{output_dir}/v{N}/citations.json` | — |
| synth | `.claude/artifacts/{output_dir}/v{N}/conflicts.json` | — |

> `{output_dir}`, `{output_file}`은 `document-types.yaml`의 해당 문서 유형에서 결정됩니다.
