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
