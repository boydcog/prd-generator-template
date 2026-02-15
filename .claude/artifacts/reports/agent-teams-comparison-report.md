# Agent Teams vs Sub-Agent 방식 비교 보고서

**작성일**: 2026-02-13
**프로젝트**: Maththera PRD 생성
**비교 대상**: PRD v2 (Sub-Agent) vs PRD v3 (Agent Teams)

---

## 1. 실험 설계

### 1.1 동일 조건

| 항목 | 값 |
|------|-----|
| 프로젝트 | Maththera (AI 기반 난산증 인지 훈련 시스템) |
| 입력 증거(evidence) | 동일한 9개 소스 (7개 기존 + 2개 신규) |
| 문서 유형 | PRD (제품 요구사항 문서) |
| 출력 섹션 | document-types.yaml 기준 12개 섹션 |
| 모델 | Claude Opus |

### 1.2 차이점

| 항목 | v2 (Sub-Agent) | v3 (Agent Teams) |
|------|----------------|------------------|
| 생성 방식 | 단일 에이전트가 모든 증거를 읽고 직접 작성 | 5개 전문 에이전트 병렬 분석 → synth 에이전트 통합 |
| 에이전트 수 | 1 | 6 (biz, marketing, research, tech, pm, synth) |
| 병렬화 | 없음 | Wave 1: 5개 동시 실행 |
| 중간 산출물 | 없음 | JSON(claims/risks/questions) + MD (역할별) |
| 인용 추적 | 없음 (본문 내 텍스트 참조만) | citations.json (72건의 구조화된 인용) |
| 충돌 해결 | 해당 없음 (단일 저자) | conflicts.json (6건 식별, 5건 해결) |

---

## 2. 정량 비교

### 2.1 문서 규모

| 지표 | v2 | v3 | 차이 |
|------|-----|-----|------|
| 줄 수 | 724줄 | 857줄 | +18.4% |
| 파일 크기 | 34KB | 43KB | +25.3% |
| 출력 파일 수 | 2 (PRD.md, metadata.json) | 4 (PRD.md, citations.json, conflicts.json, metadata.json) | +2 |

### 2.2 분석 깊이

| 지표 | v2 | v3 | 비고 |
|------|-----|-----|------|
| 총 Claims 수 | 측정 불가 (비구조화) | 72건 | v3는 모든 주장이 구조화됨 |
| High confidence | - | 54건 (75%) | 신뢰도 등급 부여 |
| 인용(citations) | 텍스트 내 비공식 참조 | 72건 구조화 | chunk_id + line 범위 + SHA256 |
| 미해결 질문 | 약 10건 (텍스트 나열) | 20건 (우선순위 포함) | +100% |
| 리스크 | 약 8건 (텍스트 나열) | 12건 (severity 포함) | +50% |
| 충돌 식별 | 0건 | 6건 | 단일 저자라 충돌 자체가 발생 불가 |
| 페르소나 | 3개 | 3개 | 동일 |
| 기능 요구사항 | 12개 | 12개+ | v3가 수용 기준 더 상세 |

### 2.3 에이전트별 기여도 (v3 only)

| 에이전트 | Claims | 고유 관점 |
|---------|--------|----------|
| biz | 15 | 시장 규모, 수익 모델, 경쟁 분석, IP 전략 |
| marketing | 15 | 포지셔닝, 메시징 필러, 채널 전략, 톤앤매너 |
| research | 12 | 인지과학 이론 검증, 가설 타당성, 실험 설계 |
| tech | 12 | 아키텍처 결정, 성능 기준, 데이터 모델, 보안 |
| pm | 16 | 스코프 정의, 수용 기준, 마일스톤, 의존성 |
| synth | 2 | W/C 이중 태그 + 적응형 알고리즘 통합 인사이트 |

---

## 3. 정성 비교

### 3.1 v3가 우위인 영역

#### (1) 다관점 통합 (Multi-perspective Integration)

v2는 단일 저자가 모든 관점을 소화해야 하므로, 비즈니스/마케팅/기술 분석의 깊이가 균일하지 않다. 예를 들어 v2의 GTM 전략 섹션은 4~5줄로 간략한 반면, v3는 marketing 에이전트가 전담 분석한 15건의 claims를 기반으로 채널별 우선순위, 런칭 5단계, KOL 전략까지 구체적으로 서술한다.

#### (2) 충돌 감지 및 해결 (Conflict Resolution)

v3에서만 가능한 고유 가치이다. 6건의 충돌이 식별되었고, 이 중 5건이 해결되었다:

| 충돌 ID | 주제 | 관련 에이전트 | 해결 |
|---------|------|-------------|------|
| CONF-001 | 가격 전략 (단일 vs 2-tier) | biz ↔ marketing | 2-tier 채택 + 연간 할인 |
| CONF-002 | 무료 체험 기간 (14일 vs 7일) | biz ↔ marketing | 7일 채택 (A/B 테스트 예정) |
| CONF-003 | Probe MVP 포함 여부 | pm ↔ research ↔ tech | 수동 Probe만 포함, 자동은 Phase 2 |
| CONF-004 | 응답 시간 목표 (200ms vs 500ms) | tech ↔ pm | 200ms 채택 (기술적 달성 가능) |
| CONF-005 | L/C vs W/C 난이도 체계 관계 | research ↔ tech ↔ synth | 병행 운영 (W/C=적응형, L=리포팅) |
| CONF-006 | B2B vs B2C 우선순위 | biz ↔ marketing | 미해결 (파일럿 후 결정) |

이런 충돌은 단일 저자 방식에서는 **인식 자체가 불가능**하다. 한 사람이 쓰면 무의식적으로 하나의 관점을 선택하고 넘어가기 때문이다.

#### (3) 인용 추적 (Citation Traceability)

v3는 모든 주장에 `[CLM-001]`, `[TECH-003]` 같은 인용 마커가 있고, citations.json에서 원본 증거 청크의 정확한 위치(chunk_id, line_start, line_end, SHA256)를 추적할 수 있다. v2는 텍스트 내에서 비공식적으로 소스를 언급할 뿐, 체계적 추적이 불가능하다.

#### (4) 신뢰도 등급 (Confidence Scoring)

v3의 모든 claim에는 high/medium/low 신뢰도가 부여된다. 의사결정자는 "medium confidence" claim에 대해 추가 검증이 필요한지 즉시 판단할 수 있다. v2에는 이런 메타데이터가 없다.

### 3.2 v2가 우위인 영역

#### (1) 서사적 일관성 (Narrative Coherence)

v2는 단일 저자가 처음부터 끝까지 하나의 스토리라인으로 작성했기 때문에, 문서 전체의 **톤과 흐름이 자연스럽다**. v3는 synth가 5개 에이전트의 결과를 머지하면서 일부 섹션 간 문체 차이가 느껴진다.

#### (2) 작성 속도

v2는 단일 에이전트가 약 3~5분 만에 완성한 반면, v3는 Wave 1(5개 에이전트 병렬, 각 3~5분) + Wave 2(synth, 약 10분) = 총 약 15분이 소요되었다. 벽시계 기준으로는 비슷하지만, API 호출 비용은 v3가 약 6배 높다.

#### (3) 간결함

v2(724줄)가 v3(857줄)보다 짧다. PRD는 "읽히는 문서"이므로 지나친 분량이 오히려 가독성을 해칠 수 있다. 단, v3의 추가 분량은 대부분 충돌 해결, 수용 기준, 정량 지표 등 **실질적 내용**이다.

---

## 4. Agent Teams의 동작 원리

### 4.1 개념

Agent Teams(TeamCreate)는 Claude Code의 멀티 에이전트 협업 기능이다. 하나의 "팀"을 생성하고, 팀 내에서 여러 에이전트가 독립적으로 작업하면서 TaskList/SendMessage로 협업한다.

### 4.2 핵심 메커니즘

```
[Team Leader]
     |
     +--- TeamCreate("research-v3") --- 팀 생성
     |
     +--- TaskCreate(#1~#5) --- Wave 1 태스크 정의
     |    TaskCreate(#6, blockedBy: [1,2,3,4,5]) --- Wave 2 태스크
     |
     +--- Task(biz-agent, team_name="research-v3") --+
     |--- Task(marketing-agent, ...)                  |--- Wave 1 병렬
     |--- Task(research-agent, ...)                   |
     |--- Task(tech-agent, ...)                       |
     |--- Task(pm-agent, ...)                       --+
     |
     |    [각 에이전트가 독립적으로:]
     |    TaskList → TaskUpdate(claim) → 분석 → 파일 생성 → TaskUpdate(completed) → SendMessage
     |
     +--- [Wave 1 완료 확인]
     |
     +--- Task(synth-agent, team_name="research-v3") --- Wave 2 순차
     |
     +--- shutdown_request → TeamDelete --- 정리
```

### 4.3 주요 도구

| 도구 | 용도 |
|------|------|
| `TeamCreate` | 팀 + 공유 태스크 리스트 생성 |
| `TaskCreate` | 태스크 정의 (blockedBy로 의존성 설정) |
| `TaskUpdate` | 태스크 상태 변경 (pending → in_progress → completed) |
| `SendMessage` | 에이전트 간 메시지 전달 (type: message/broadcast/shutdown_request) |
| `TaskList` | 태스크 현황 조회 |
| `TeamDelete` | 팀 + 태스크 리스트 정리 |

### 4.4 Sub-Agent(Task tool 단독)와의 차이

| 항목 | Sub-Agent (Task tool) | Agent Teams (TeamCreate) |
|------|----------------------|--------------------------|
| 협업 | 없음 (독립 실행) | 공유 태스크 리스트 + 메시지 |
| 상태 추적 | 없음 | TaskList로 진행 상황 실시간 확인 |
| 의존성 | 수동 관리 | blockedBy로 자동 관리 |
| 메시지 | 결과만 반환 | SendMessage로 실시간 소통 |
| 팀 리더 | 없음 | 팀 리더가 오케스트레이션 |
| 중간 결과 | 보이지 않음 | 태스크 상태로 추적 가능 |

---

## 5. Agent Teams의 장점

### 5.1 전문성 분리 (Separation of Concerns)

각 에이전트가 자신의 전문 영역에만 집중한다. biz 에이전트는 시장 규모와 수익 모델에, tech 에이전트는 아키텍처와 성능 기준에 집중한다. 단일 에이전트가 모든 관점을 동시에 고려하면 각 영역의 깊이가 얕아질 수밖에 없다.

### 5.2 충돌의 가시화 (Making Conflicts Visible)

서로 다른 에이전트가 같은 주제에 대해 다른 결론을 내릴 수 있다. 이 **충돌 자체가 가치 있는 정보**이다. 가격 전략에서 biz(단일 플랜 29,900원)와 marketing(2-tier 19,900/39,900원)의 의견 차이는 synth가 근거를 비교하여 최적안을 도출하는 데 활용되었다.

### 5.3 추적 가능성 (Traceability)

모든 주장(claim)이 역할별로 태깅되고, 원본 증거까지 추적 가능하다. PRD의 특정 문장이 어떤 에이전트의 어떤 분석에서 나왔는지 역추적할 수 있다.

### 5.4 병렬 실행 (Parallelism)

5개 Wave 1 에이전트가 동시에 실행되므로, 벽시계 기준 실행 시간은 가장 느린 에이전트 기준이다. 전체 분석 깊이 대비 실행 시간이 효율적이다.

### 5.5 구조화된 중간 산출물

각 에이전트가 JSON + MD 파일을 생성하므로, synth가 아닌 다른 용도(대시보드, 리포팅, 후속 분석)로도 중간 결과를 재활용할 수 있다.

---

## 6. 현재 구현의 문제점 및 개선 제안

### 6.1 팀원 에이전트의 태스크 미완료 처리

**문제**: Wave 1 에이전트들이 파일 생성은 완료했으나, TaskUpdate(completed)를 호출하지 않아 태스크가 `in_progress` 상태로 남았다. 팀 리더가 파일 존재 여부를 직접 확인(Glob)하고 수동으로 태스크를 completed로 전환해야 했다.

**원인**: 에이전트 프롬프트에 "TaskUpdate로 완료 처리"를 지시했으나, 에이전트가 SendMessage만 보내고 TaskUpdate를 생략한 케이스가 있었다.

**개선**: 에이전트 프롬프트에서 **완료 절차를 더 명시적으로** 강조하고, 팀 리더 측에서 SendMessage 수신 후 자동으로 TaskUpdate를 검증하는 로직 추가.

### 6.2 Shutdown 처리의 비동기성

**문제**: shutdown_request를 보내도 에이전트가 즉시 종료되지 않고, idle 상태에서 대기하는 경우가 있었다. idle_notification이 반복 수신되었다.

**원인**: 에이전트가 이미 idle 상태에서 shutdown_request를 수신하는 타이밍 문제.

**개선**: 이는 시스템 동작 방식의 한계이므로, 팀 리더가 idle 알림을 무시하고 TeamDelete로 최종 정리하면 된다.

### 6.3 synth 에이전트의 독립 실행

**문제**: 현재 synth 에이전트는 Agent Teams의 팀원이 아닌 독립 Task로 실행되었다. 따라서 synth는 TeamCreate의 SendMessage/TaskUpdate를 직접 활용하지 못하고, 파일 기반으로만 Wave 1 결과를 수신했다.

**개선**: synth도 팀원(Task with team_name)으로 등록하고, Wave 1 에이전트들이 SendMessage로 결과 요약을 보내면 synth가 수신하는 방식으로 전환. 이렇게 하면 파일 I/O 의존도가 줄고, 메시지 기반 협업의 이점을 더 활용할 수 있다.

### 6.4 에이전트 간 교차 검증 미활용

**문제**: Wave 1 에이전트들은 서로의 결과를 읽지 않고 독립적으로만 분석했다. 교차 검증(cross-validation)이 이루어지지 않았다.

**개선**: Wave 1 완료 후, Wave 1.5 단계를 추가하여 각 에이전트가 다른 에이전트의 claims를 검토하고 반박/보강하는 "리뷰 라운드"를 도입. 이는 Agent Teams의 메시지 기능을 더 적극적으로 활용하는 방법이다.

### 6.5 비용 효율성

**문제**: 5개 Opus 에이전트를 동시 실행하므로 API 비용이 단일 에이전트 대비 약 6배이다.

**개선**:
- Wave 1 에이전트에 Sonnet 모델을 사용하고, synth에만 Opus를 사용하는 하이브리드 전략.
- 각 에이전트의 evidence 분배를 최적화하여 불필요한 중복 읽기를 제거.

---

## 7. 종합 평가

### 7.1 품질 점수 (5점 만점)

| 평가 항목 | v2 (Sub-Agent) | v3 (Agent Teams) | 비고 |
|----------|---------------|------------------|------|
| 내용 깊이 | 3.5 | 4.5 | v3는 역할별 전문 분석 |
| 구조적 완성도 | 4.0 | 4.5 | v3는 citations/conflicts 포함 |
| 인용 추적성 | 2.0 | 5.0 | v3는 체계적 인용 시스템 |
| 다관점 통합 | 2.5 | 4.5 | 충돌 식별/해결이 핵심 가치 |
| 서사적 일관성 | 4.5 | 3.5 | v2가 더 자연스러운 흐름 |
| 비용 효율 | 5.0 | 2.0 | v3는 6배 비용 |
| 재사용성 | 2.0 | 4.5 | v3의 중간 산출물 재활용 가능 |
| **종합** | **3.4** | **4.1** | **v3가 +0.7점 우위** |

### 7.2 언제 어떤 방식을 사용할까

| 상황 | 권장 방식 | 이유 |
|------|----------|------|
| 빠른 초안이 필요할 때 | Sub-Agent (v2) | 속도와 비용 효율 |
| 투자자/이해관계자 대상 공식 문서 | Agent Teams (v3) | 깊이, 추적성, 신뢰도 |
| 다수 이해관계자의 관점 통합이 필요 | Agent Teams (v3) | 충돌 감지가 핵심 가치 |
| 증거 소스가 3개 미만 | Sub-Agent (v2) | 분석할 양이 적으면 팀 불필요 |
| 증거 소스가 5개 이상 | Agent Teams (v3) | 에이전트별 증거 분배의 이점 |
| 반복 개선 (v4, v5...) | Agent Teams (v3) | 이전 버전의 conflicts를 입력으로 활용 |

### 7.3 결론

Agent Teams(TeamCreate)는 **"여러 전문가가 같은 문제를 다른 각도에서 분석하고, 그 결과를 통합하는"** 과정을 자동화한다. 이 과정에서 발생하는 **충돌의 가시화**와 **인용 추적**이 가장 큰 차별 가치이다.

단, 모든 문서 생성에 Agent Teams가 필요한 것은 아니다. 간단한 문서나 빠른 초안에는 Sub-Agent 방식이 더 효율적이다. Agent Teams는 **공식 문서, 깊이 있는 분석, 다관점 통합**이 필요한 상황에서 진가를 발휘한다.

현재 구현에서 가장 중요한 개선점은:
1. synth를 팀원으로 등록하여 메시지 기반 협업 활용
2. Wave 1.5 교차 검증 라운드 도입
3. 비용 최적화를 위한 모델 하이브리드 전략

---

## 부록: 파일 목록

### PRD v2 (Sub-Agent 방식)
```
.claude/artifacts/prd/v2/
├── PRD.md         (34KB, 724줄)
└── metadata.json  (1.4KB)
```

### PRD v3 (Agent Teams 방식)
```
.claude/artifacts/prd/v3/
├── PRD.md         (43KB, 857줄)
├── citations.json (19KB, 72건 인용)
├── conflicts.json (5KB, 6건 충돌)
└── metadata.json  (3KB)

.claude/artifacts/agents/     (Wave 1 중간 산출물)
├── biz.json + biz.md
├── marketing.json + marketing.md
├── research.json + research.md
├── tech.json + tech.md
└── pm.json + pm.md
```
