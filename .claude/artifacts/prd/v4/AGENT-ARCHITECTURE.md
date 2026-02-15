# Maththera 에이전트 아키텍처 기술 문서

**프로젝트명**: Maththera
**버전**: 1.0
**작성일**: 2026-02-13
**상태**: Draft
**기반 문서**: PRD v4, tech/CLM-001~CLM-010, Adaptive Logic 알고리즘 사양

---

## 1. 개요

### 1.1 문서 목적

이 문서는 Maththera의 핵심 두뇌인 "Cogassist Agent"의 소프트웨어 아키텍처를 결정하기 위한 기술 문서다. 두 가지 후보 아키텍처를 구체적인 프롬프트, 데이터 플로우, 비용 추정까지 포함하여 비교하고, 최종 권장안을 제시한다.

### 1.2 핵심 결정 사항

| 결정 ID | 질문 | 영향 범위 |
|---------|------|----------|
| AD-001 | 에이전트를 단일 모놀리식으로 구축할 것인가, 역할 분리된 다중 에이전트로 구축할 것인가? | 전체 시스템 아키텍처, 비용, 레이턴시, 유지보수 |
| AD-002 | LLM 호출이 필요한 기능과 규칙 엔진으로 충분한 기능의 경계는 어디인가? | API 비용, 응답 일관성, 톤 가이드 준수율 |
| AD-003 | "에이전트"의 정의를 LLM 에이전트로 한정할 것인가, 소프트웨어 에이전트(자율 의사결정 모듈)로 확장할 것인가? | 설계 패러다임, 기술 스택 선택 |

### 1.3 용어 정의 (선행)

이 문서에서 "에이전트"는 두 가지 의미로 사용된다:

- **LLM 에이전트**: LLM API를 호출하여 자연어 이해/생성을 수행하는 소프트웨어 컴포넌트
- **소프트웨어 에이전트**: 자율적으로 환경을 관찰하고, 의사결정하고, 행동하는 소프트웨어 모듈 (LLM 유무 무관)

PRD v4의 "Cogassist Agent"는 후자에 가깝다. 규칙 기반 결정 트리 + FSM으로 적응형 로직을 구현하되 [tech/CLM-001], LLM은 특정 기능에 한정하여 사용한다.

---

## 2. 요구사항 분석

### 2.1 에이전트가 처리해야 할 기능 목록

PRD v4의 기능 요구사항을 에이전트 관점에서 재분류하면 다음과 같다.

| ID | 기능 | 복잡도 | 상태 의존성 | 실시간 요구 | LLM 필요? |
|----|------|--------|------------|------------|----------|
| F-01 | 문제 정의 (L-level, Cur-C, 전략 태그 설정) | 낮음 | 없음 (문제 DB 참조) | < 50ms | **불필요** - 사전 태깅된 CSV 조회 |
| F-02 | 관찰 기록 (RT 밀리초, 행동 태그 수집) | 낮음 | 세션 컨텍스트 | < 10ms | **불필요** - 이벤트 로깅 |
| F-03 | 오답 원인 분석 (관찰+문제정의 교차분석) | 중간 | F-01 + F-02 결과 | < 500ms | **조건부** - 4개 UC는 규칙, 미지 패턴은 LLM 폴백 |
| F-04 | 훈련 매핑 (원인 태그 -> 훈련 ID) | 낮음 | F-03 결과 | < 50ms | **불필요** - 룩업 테이블 |
| F-05 | 훈련 모듈 제시 (인터랙티브 콘텐츠) | 낮음 | F-04 결과 | < 200ms | **불필요** - UI 렌더링 |
| F-06 | 적응형 분기 (Route A/B 결정) | 높음 | 세션 전체 이력 | < 100ms | **불필요** - 결정 트리 + FSM |
| F-07 | 4가지 반응 패턴 분기 | 중간 | 현재 W/C + RT | < 100ms | **불필요** - 수치 비교 |
| F-08 | 3단계 복귀 루프 (Scaffolded Recovery) | 높음 | 세션 컨텍스트 (3단계 상태) | < 100ms | **불필요** - 상태 머신 |
| F-09 | Bridge Loop 처리 | 높음 | 3단계 루프 + 원래 문제 | < 100ms | **불필요** - 상태 머신 |
| F-10 | White-out 감지 및 후퇴 | 중간 | 연속 실패 패턴 | < 100ms | **불필요** - 규칙 기반 |
| F-11 | 변인 통제 Probe 출제 | 높음 | F-03 결과 (복합 원인) | < 200ms | **불필요** - 변인 제거 규칙 |
| F-12 | AI 피드백 생성 | 중간 | F-03~F-06 결과 + 톤 가이드 | < 200ms | **조건부** - 기본 템플릿 + 특수 상황에서 LLM |
| F-13 | 진단 질문 생성 | 중간 | 현재 문제 + 오답 패턴 | < 200ms | **조건부** - 기본 템플릿 + 신규 패턴에서 LLM |
| F-14 | 문제 선택 (W*C 필터링) | 낮음 | 현재 W/C 위치 | < 50ms | **불필요** - 인메모리 쿼리 |
| F-15 | Downscaling/Upscaling 전략 선택 | 중간 | 세션 이력 + 현재 단계 | < 100ms | **불필요** - 규칙 기반 |
| F-16 | 세션 컨텍스트 관리 | 낮음 | 전체 세션 | < 100ms | **불필요** - 데이터 저장/조회 |

### 2.2 LLM 필요도 요약

```
                    LLM 불필요 (13개)                 LLM 조건부 (3개)
    ┌──────────────────────────────────────┐  ┌─────────────────────────┐
    │ F-01  문제 정의                       │  │ F-03  오답 원인 분석      │
    │ F-02  관찰 기록                       │  │       (미지 패턴 폴백)    │
    │ F-04  훈련 매핑                       │  │ F-12  AI 피드백 생성      │
    │ F-05  훈련 모듈 제시                   │  │       (특수 상황)         │
    │ F-06  적응형 분기                      │  │ F-13  진단 질문 생성      │
    │ F-07  4가지 반응 패턴                  │  │       (신규 패턴)         │
    │ F-08  3단계 복귀 루프                  │  └─────────────────────────┘
    │ F-09  Bridge Loop                    │
    │ F-10  White-out 감지                  │
    │ F-11  변인 통제 Probe                  │
    │ F-14  문제 선택                       │
    │ F-15  Downscaling/Upscaling          │
    │ F-16  세션 컨텍스트 관리               │
    └──────────────────────────────────────┘
```

**핵심 발견**: 16개 기능 중 13개(81%)는 LLM 없이 규칙 기반으로 구현 가능하다. LLM이 조건부로 필요한 3개 기능도 기본 경로는 템플릿/규칙이며, LLM은 예외 처리 폴백이다.

### 2.3 상태 의존성 그래프

```
문제 제시 ─────────────────────────────────────────────────┐
    │                                                       │
    v                                                       │
[F-01] 문제 정의 ──┐                                        │
                    │                                       │
[F-02] 관찰 기록 ──┤                                        │
    (RT, 행동태그)  │                                        │
                    v                                       │
              [F-03] 오답 원인 분석 ──┐                      │
                    │                 │                      │
                    │           복합 원인?                    │
                    │           ┌─ Yes ──> [F-11] Probe ──> │ (재시작)
                    │           │                            │
                    │           └─ No                        │
                    v                                        │
              [F-04] 훈련 매핑                               │
                    │                                        │
                    v                                        │
              [F-06] 적응형 분기 ──┐                          │
                    │              │                          │
                    ├─ Route A ──> [F-14] 문제 선택 (W 하향)  │
                    │              │                          │
                    └─ Route B ──> [F-14] 문제 선택 (C 하향)  │
                                   │                         │
                    [F-07] 4가지 반응 패턴 ──┐                │
                                             │                │
                    ┌──────────────────────────┘               │
                    │                                         │
                    v                                         │
              [F-08] 3단계 복귀 루프 ──> [F-09] Bridge Loop    │
                    │                         │               │
                    │                   [F-10] White-out ──> │ (대폭 후퇴)
                    │                                         │
                    v                                         │
              [F-15] Downscaling/Upscaling                    │
                    │                                         │
                    v                                         │
              [F-12] AI 피드백 생성                            │
                    │                                         │
                    v                                         │
              [F-05] 훈련 모듈 제시 ──────────────────────────┘
                    │
                    v
              다음 문제 ──> [F-01]로 루프
```

### 2.4 실시간 제약 요약

PRD v4의 비기능 요구사항 [tech/CLM-010]:

| 구간 | 허용 레이턴시 | 비고 |
|------|-------------|------|
| RT 측정 ~ 오답 진단 완료 | < 2,000ms E2E | 아동 집중력 유지 |
| 문제 선택 쿼리 | < 50ms | C/W 복합 필터링 |
| 피드백 렌더링 | < 200ms | 즉시성 |
| 세션 상태 저장 | < 100ms | 컨텍스트 유실 방지 |

이 제약은 LLM API 호출(평균 500~2,000ms)과 긴장 관계에 있다. E2E 2초 내에 LLM 호출을 포함하려면 피드백 생성을 비동기로 처리하거나, LLM 호출 자체를 최소화해야 한다.

---

## 3. Option A: 단일 에이전트 (Monolithic)

### 3.1 아키텍처 설계

단일 에이전트 방식은 하나의 LLM 인스턴스가 시스템 프롬프트에 전체 도메인 지식과 규칙을 포함하고, 매 턴마다 모든 의사결정을 수행하는 구조다.

```
┌─────────────────────────────────────────────────────────┐
│                    Monolithic Agent                       │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │              System Prompt (~15K tokens)           │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────────────┐  │   │
│  │  │ 진단 규칙  │ │ 적응 규칙  │ │ 피드백 톤 가이드   │  │   │
│  │  │ (UC1~4)  │ │ (FSM)    │ │ (템플릿 풀)      │  │   │
│  │  └──────────┘ └──────────┘ └──────────────────┘  │   │
│  │  ┌──────────┐ ┌──────────┐ ┌──────────────────┐  │   │
│  │  │ W-Score  │ │ C-Tag    │ │ Probe 분기 규칙   │  │   │
│  │  │ 6차원 정의│ │ 15+6 정의│ │ Case A/B        │  │   │
│  │  └──────────┘ └──────────┘ └──────────────────┘  │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  ┌──────────────────┐  ┌─────────────────────────────┐  │
│  │   Tool Calls      │  │    Session Context          │  │
│  │ - query_problem() │  │ - current_step              │  │
│  │ - get_rt()        │  │ - original_problem          │  │
│  │ - save_session()  │  │ - scaffold_problem          │  │
│  │ - select_probe()  │  │ - w_position, c_position    │  │
│  │ - render_visual() │  │ - downscaling_state         │  │
│  └──────────────────┘  └─────────────────────────────┘  │
│                                                          │
│              LLM (Claude / GPT-4o)                       │
└─────────────────────────────────────────────────────────┘
          │                    ^
          v                    │
    ┌──────────┐        ┌──────────┐
    │ Problem  │        │ Client   │
    │ Bank DB  │        │ (App)    │
    └──────────┘        └──────────┘
```

### 3.2 시스템 프롬프트 구조

#### 3.2.1 프롬프트 전체 구조 (추정 ~15,000 토큰)

```
[ROLE] (~200 tokens)
너는 Maththera의 Cogassist Agent다. 난산증 아동의 오답을 인지 도메인별로
진단하고, Master Matrix 기반 적응형 훈련을 처방하는 AI 인지 훈련 튜터다.

[DIAGNOSTIC RULES] (~3,000 tokens)
## 5단계 오답 진단 파이프라인
1. 문제 정의: query_problem(problem_id)로 L-level, Cur-C, 전략 태그 로드
2. 관찰 기록: RT(ms)와 행동 태그를 세션 컨텍스트에 기록
3. 오답 원인 분석:
   - UC1 (전략 불일치): 정답 AND RT > 5000ms AND 전략태그 != 관찰태그
     → 원인: MAKE10_STRATEGY_UNAVAILABLE_COUNTING_FALLBACK
   - UC2 (공간 인지 결손): 오답값 == 특정_자릿수_부분합
     → 원인: SPATIAL_L4_PLACE_VALUE
   - UC3 (주의력/충동성): RT < 800ms AND 무작위_응답_패턴
     → 원인: ATTENTION_L0_IMPULSE
   - UC4 (복합 원인): 원인 후보 >= 2 → Probe 출제
     → select_probe(원인후보들) 호출
4. 훈련 매핑: CAUSE_TAG → TRAINING_ID 테이블 참조
5. 훈련 모듈: render_training(training_id) 호출

[ADAPTIVE LOGIC] (~3,500 tokens)
## 2경로 분기
- Route A (W 하향): 진단질문 정답 → C 유지, W_총점 낮은 문제
- Route B (C 하향): 진단질문 오답/양적관계 깨짐 → C -1~2

## 4가지 반응 패턴
| 반응 | C 조정 | W 조정 |
| 심각한 오답 | C -2 | W < 1.0 |
| 논리적 오답 | C 유지 | W -1.5 |
| 정답+느림 | C 유지 | W 동일 |
| 정답+빠름 | C+1 | W +1.0 |

## 3단계 복귀 루프
Step 1: 기준점 고정 (단순화 문제)
Step 2: 미세 조정 (가르기/가역성)
Step 3: 복귀 (원래 문제 재제시)

## Bridge Loop
100+90 성공 but 98+90 실패 → 빌려오기 전략 유도

## White-out
기준점 문제도 실패 → 10+9 수준으로 대폭 후퇴, C=5

[FEEDBACK RULES] (~2,000 tokens)
## 톤 가이드 (절대 준수)
- 3문장 이내, 문장당 10자 이내
- 반말 사용, 존댓말 금지
- 비난/단정/재촉/비교 금지
- 금지 표현: "틀렸어", "아니야", "왜 못해", "정신 차려", "빨리"

## 상황별 템플릿
| 정답 | "{칭찬}!" / "{확인}!" |
| 오답 | "괜찮아." / "{힌트}" / "다시 해볼까?" |
| 과정실수 | "거의 다 왔어!" / "{포인트}" / "다시!" |
| 무응답 | "괜찮아." / "하나씩 하자." |

[W-SCORE DEFINITION] (~1,500 tokens)
W1_연산: 덧셈 0, 뺄셈 +1.5
W2_자릿수: 한자리 0, 두자리 +3, 두자리x두자리 +4
W3_숫자크기: 6이상 +0.5, 양쪽 큰 수 +1.0
W4_복잡성: 받아올림/받아내림 +3.0
W5_특수수: 같은 수 -0.5, 10배수 -1.0
W6_표현: 가로셈 +0.5, 세로셈 0
W_총점 = max(0, W1+W2+W3+W4+W5+W6)

[C-TAG DEFINITION] (~1,500 tokens)
Cur-C1~C15 교육과정 단원 매핑 테이블
Cog-C1~C6 인지진단 개념 태그 + 전략 매핑

[TOOL DEFINITIONS] (~1,500 tokens)
query_problem(problem_id) -> {l_level, cur_c, strategy_tag, w_scores}
get_session_context() -> {step, original_problem, scaffold, w_pos, c_pos}
update_session(updates) -> void
select_next_problem(c_level, w_range) -> problem
select_probe(cause_candidates) -> probe_problem
save_observation(rt_ms, behavior_tags) -> void

[OUTPUT FORMAT] (~800 tokens)
항상 다음 JSON으로 응답:
{
  "action": "present_problem|feedback|diagnostic_question|training|probe",
  "problem_id": "...",
  "feedback_text": "...",
  "session_update": {...},
  "visual_mode": "ten_frame|coin|vertical|none",
  "next_step": "..."
}
```

#### 3.2.2 프롬프트 크기 추정

| 섹션 | 추정 토큰 |
|------|----------|
| ROLE | 200 |
| DIAGNOSTIC RULES | 3,000 |
| ADAPTIVE LOGIC | 3,500 |
| FEEDBACK RULES | 2,000 |
| W-SCORE DEFINITION | 1,500 |
| C-TAG DEFINITION | 1,500 |
| TOOL DEFINITIONS | 1,500 |
| OUTPUT FORMAT | 800 |
| **시스템 프롬프트 합계** | **~14,000** |
| 세션 컨텍스트 (대화 이력) | ~2,000~8,000 |
| **총 입력 토큰 (요청당)** | **~16,000~22,000** |

### 3.3 요청-응답 플로우

```
아동이 8+6=12 제출 (RT: 12,000ms)
         │
         v
Client ──> API Gateway ──> [Monolithic Agent]
                                    │
                           (1) 시스템 프롬프트 로드 (~14K tokens)
                           (2) 세션 컨텍스트 주입 (~4K tokens)
                           (3) 사용자 메시지 구성:
                               "problem: 8+6, answer: 12, rt: 12000ms"
                                    │
                           (4) LLM 추론 시작
                               - 문제 정의 참조 → STR_MAKE10 필요
                               - RT 12초 > 5초 임계값 → 느림 판정
                               - 정답 + 느림 = UC1 전략 불일치
                               - Tool call: query_problem(...)
                                    │
                           (5) Tool 응답 수신
                               - MAKE10_STRATEGY_UNAVAILABLE
                               - 훈련 매핑: T12 → T17
                                    │
                           (6) LLM 최종 응답 생성
                               - 피드백: "정답이야!" / "더 빠르게 해볼까?"
                               - 다음: 동일 C, 동일 W 다른 숫자
                                    │
                           (7) JSON 출력
                                    │
         <── 응답 ──────────────────┘

예상 레이턴시: 1,500~3,000ms (LLM 추론 + Tool 호출)
예상 토큰: 입력 ~18K + 출력 ~500 = ~18.5K tokens/요청
```

### 3.4 지식 베이스 구성

| 데이터 | 저장 방식 | 접근 방식 | 근거 |
|-------|----------|----------|------|
| 15,053문제 뱅크 | RDBMS + 인메모리 캐시 | Tool call (query_problem) | 2~5MB, 전체 로드 가능 [tech/CLM-004] |
| W-Score 규칙 | 시스템 프롬프트 직접 포함 | 프롬프트 내 참조 | 6개 차원 정의, ~300 tokens |
| C-Tag 매핑 테이블 | 시스템 프롬프트 직접 포함 | 프롬프트 내 참조 | 15+6개 태그, ~500 tokens |
| 원인-훈련 매핑 | 시스템 프롬프트 직접 포함 | 프롬프트 내 참조 | ~85개 매핑, ~400 tokens |
| 피드백 템플릿 풀 | 시스템 프롬프트 직접 포함 | 프롬프트 내 참조 | 상황별 20개+, ~600 tokens |
| 세션 이력 | Redis/DB | Tool call (get_session) | 가변 크기 |

### 3.5 장단점 분석

**장점:**

| 항목 | 설명 |
|------|------|
| 구현 단순성 | 하나의 프롬프트, 하나의 API 호출 경로. 빌드/배포 단위가 하나 |
| 전체 컨텍스트 접근 | 진단, 적응, 피드백 모든 정보를 한 번에 볼 수 있어 교차 참조 용이 |
| 디버깅 편의 | 단일 입출력 로그로 전체 의사결정 과정 추적 가능 |
| 초기 개발 속도 | 프롬프트 엔지니어링만으로 빠르게 프로토타입 가능 |

**단점:**

| 항목 | 설명 |
|------|------|
| 프롬프트 비대화 | ~14K 토큰 시스템 프롬프트. 규칙 추가 시 선형 증가 |
| 비용 비효율 | 매 요청마다 14K+ 입력 토큰 과금. 피드백만 필요해도 전체 규칙 로드 |
| 레이턴시 | LLM 추론 1.5~3초. E2E 2초 제약 위반 가능 |
| 일관성 리스크 | LLM이 규칙을 "이해"해야 함. 복잡한 수치 규칙에서 할루시네이션 가능 |
| 톤 가이드 위반 | LLM이 피드백을 자유 생성하면 10자 제한, 금지 표현 위반 발생 가능 |
| 확장성 한계 | 곱셈/나눗셈 추가 시 프롬프트 크기가 컨텍스트 윈도우 한계에 근접 |
| 테스트 어려움 | 규칙 변경이 전체 행동에 영향. 단위 테스트 불가, 전체 E2E만 가능 |

---

## 4. Option B: 다중 에이전트 오케스트레이션

### 4.1 아키텍처 설계

#### 4.1.1 에이전트 역할 분담

| 에이전트 | 역할 | LLM 사용 | 핵심 로직 |
|---------|------|---------|----------|
| **오케스트레이터** (Orchestrator) | 요청 라우팅, 에이전트 간 데이터 전달, 세션 관리 | 불필요 | 이벤트 기반 디스패처 |
| **진단 에이전트** (Diagnostic Agent) | 5단계 파이프라인 실행, 오답 원인 분석, Probe 결정 | 조건부 (미지 패턴 폴백) | 규칙 기반 결정 트리 |
| **분석 에이전트** (Analysis Agent) | 적응형 분기, 문제 선택, Downscaling/Upscaling, 세션 상태 전이 | 불필요 | FSM + W/C 쿼리 엔진 |
| **튜터 에이전트** (Tutor Agent) | AI 피드백 생성, 진단 질문 구성, 톤 가이드 준수 검증 | 조건부 (특수 상황) | 템플릿 엔진 + 필터 |

#### 4.1.2 시스템 구조도

```
                         ┌──────────────────┐
                         │     Client       │
                         │   (App/Web)      │
                         └────────┬─────────┘
                                  │
                                  v
                    ┌─────────────────────────────┐
                    │       API Gateway            │
                    └─────────────┬───────────────┘
                                  │
                                  v
┌─────────────────────────────────────────────────────────────────┐
│                     Orchestrator                                 │
│                  (Event-Driven Dispatcher)                        │
│                                                                  │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────────────┐  │
│  │ Event Queue  │    │ State Store │    │ Agent Router        │  │
│  │              │    │ (Redis)     │    │                     │  │
│  │ answer_submit│    │ session_ctx │    │ diagnostic_needed?  │  │
│  │ probe_result │    │ w_position  │    │ → Diagnostic Agent  │  │
│  │ timeout      │    │ c_position  │    │                     │  │
│  │ training_done│    │ loop_step   │    │ adaptation_needed?  │  │
│  │              │    │ probe_state │    │ → Analysis Agent    │  │
│  └─────────────┘    └─────────────┘    │                     │  │
│                                         │ feedback_needed?    │  │
│                                         │ → Tutor Agent       │  │
│                                         └─────────────────────┘  │
└───────────┬────────────────┬────────────────┬────────────────────┘
            │                │                │
            v                v                v
┌───────────────┐ ┌──────────────────┐ ┌─────────────────┐
│  Diagnostic   │ │   Analysis       │ │    Tutor        │
│  Agent        │ │   Agent          │ │    Agent        │
│               │ │                  │ │                 │
│ ┌───────────┐ │ │ ┌──────────────┐ │ │ ┌─────────────┐ │
│ │ Rule      │ │ │ │ FSM Engine   │ │ │ │ Template    │ │
│ │ Engine    │ │ │ │              │ │ │ │ Engine      │ │
│ │           │ │ │ │ 4-Pattern    │ │ │ │             │ │
│ │ UC1~UC4   │ │ │ │ State Trans. │ │ │ │ 4 Templates │ │
│ │ Matching  │ │ │ │              │ │ │ │ Slot Fill   │ │
│ └───────────┘ │ │ │ Route A/B    │ │ │ │ Tone Filter │ │
│ ┌───────────┐ │ │ │ Decision     │ │ │ └─────────────┘ │
│ │ Probe     │ │ │ └──────────────┘ │ │ ┌─────────────┐ │
│ │ Generator │ │ │ ┌──────────────┐ │ │ │ LLM Fallback│ │
│ │           │ │ │ │ Query Engine │ │ │ │ (Optional)  │ │
│ │ Variable  │ │ │ │              │ │ │ │             │ │
│ │ Control   │ │ │ │ W*C Filter   │ │ │ │ Unknown     │ │
│ └───────────┘ │ │ │ O(log N)     │ │ │ │ Situations  │ │
│ ┌───────────┐ │ │ └──────────────┘ │ │ └─────────────┘ │
│ │ LLM       │ │ │ ┌──────────────┐ │ │ ┌─────────────┐ │
│ │ Fallback  │ │ │ │ Recovery     │ │ │ │ Prohibition │ │
│ │ (Unknown  │ │ │ │ Loop         │ │ │ │ Filter      │ │
│ │  Patterns)│ │ │ │              │ │ │ │             │ │
│ └───────────┘ │ │ │ 3-Step       │ │ │ │ Regex +     │ │
│               │ │ │ Bridge Loop  │ │ │ │ Blacklist   │ │
│               │ │ │ White-out    │ │ │ └─────────────┘ │
│               │ │ └──────────────┘ │ │                 │
└───────────────┘ └──────────────────┘ └─────────────────┘
        │                │                     │
        └────────────────┴─────────────────────┘
                         │
                         v
              ┌──────────────────┐
              │   Problem Bank   │
              │   (In-Memory)    │
              │   15,053 items   │
              └──────────────────┘
```

#### 4.1.3 에이전트 간 통신 프로토콜

에이전트 간 통신은 구조화된 메시지 엔벨로프를 사용한다.

```json
// 오케스트레이터 → 진단 에이전트
{
  "type": "diagnostic_request",
  "request_id": "req-20260213-001",
  "payload": {
    "problem_id": "P-0847",
    "problem": "8+6",
    "correct_answer": 14,
    "student_answer": 14,
    "rt_ms": 12000,
    "behavior_tags": ["OBS_OVERRELIANCE_COUNTING"],
    "session_context": {
      "current_step": "normal",
      "w_position": 4.5,
      "c_position": 7,
      "loop_state": null
    }
  }
}

// 진단 에이전트 → 오케스트레이터
{
  "type": "diagnostic_result",
  "request_id": "req-20260213-001",
  "payload": {
    "cause_tag": "MAKE10_STRATEGY_UNAVAILABLE_COUNTING_FALLBACK",
    "cause_domain": "STRATEGY",
    "confidence": "high",
    "training_ids": ["T12", "T17"],
    "probe_needed": false,
    "reasoning": "정답이나 RT 12초 > 5초 임계값. STR_MAKE10 요구 vs OBS_COUNTING 관찰."
  }
}

// 오케스트레이터 → 분석 에이전트
{
  "type": "adaptation_request",
  "request_id": "req-20260213-001",
  "payload": {
    "diagnostic_result": { /* 위 결과 */ },
    "response_pattern": "correct_slow",
    "current_w": 4.5,
    "current_c": 7
  }
}

// 분석 에이전트 → 오케스트레이터
{
  "type": "adaptation_result",
  "request_id": "req-20260213-001",
  "payload": {
    "route": "fluency_drill",
    "next_problem": {
      "problem_id": "P-0851",
      "problem": "7+5",
      "w_total": 4.5,
      "c_level": 7
    },
    "c_adjustment": 0,
    "w_adjustment": 0,
    "downscaling_strategy": null,
    "loop_state_update": null
  }
}

// 오케스트레이터 → 튜터 에이전트
{
  "type": "feedback_request",
  "request_id": "req-20260213-001",
  "payload": {
    "situation": "correct_slow",
    "problem": "8+6",
    "student_answer": 14,
    "cause_tag": "MAKE10_STRATEGY_UNAVAILABLE_COUNTING_FALLBACK",
    "training_context": "fluency_drill"
  }
}

// 튜터 에이전트 → 오케스트레이터
{
  "type": "feedback_result",
  "request_id": "req-20260213-001",
  "payload": {
    "feedback_text": "정답이야!",
    "hint_text": "더 빠르게 해볼까?",
    "visual_mode": "none",
    "tone_check_passed": true
  }
}
```

#### 4.1.4 상태 공유 방식

```
┌─────────────────────────────────────────────┐
│              Shared State Store (Redis)       │
│                                              │
│  session:{user_id} = {                       │
│    current_step: "scaffolded_recovery_2",    │
│    original_problem: "98+90",                │
│    scaffold_problem: "100+90",               │
│    w_position: 8.0,                          │
│    c_position: 8,                            │
│    loop_state: {                             │
│      type: "three_step_recovery",            │
│      step: 2,                                │
│      step_results: [                         │
│        { step: 1, problem: "100+90",         │
│          answer: 190, correct: true }        │
│      ]                                       │
│    },                                        │
│    downscaling: {                            │
│      active: true,                           │
│      strategy: "number_simplification",      │
│      visual_aids: ["ten_frame"]              │
│    },                                        │
│    probe_state: null,                        │
│    history: [...]                            │
│  }                                           │
└─────────────────────────────────────────────┘
         ^          ^          ^
         │          │          │
    Diagnostic  Analysis    Tutor
    (읽기전용)   (읽기/쓰기)  (읽기전용)
```

**소유권 규칙**: 세션 상태의 쓰기 권한은 분석 에이전트에 집중한다. 진단 에이전트와 튜터 에이전트는 읽기 전용으로 접근한다. 이를 통해 상태 충돌을 원천 차단한다.

### 4.2 각 에이전트 프롬프트 설계

#### 4.2.1 진단 에이전트 프롬프트 (LLM 폴백 모드, ~4,000 tokens)

진단 에이전트는 기본적으로 코드 기반 규칙 엔진이다. LLM은 4개 UC에 해당하지 않는 미지의 오답 패턴이 감지될 때만 호출된다.

```
[ROLE] (~100 tokens)
너는 Maththera 진단 에이전트다. 아동의 오답 원인을 인지 도메인별로 분류한다.
규칙 엔진이 처리하지 못한 미지의 오답 패턴을 분석하는 것이 네 임무다.

[CONTEXT] (~500 tokens)
이미 규칙 엔진이 다음을 확인했으나 매칭 실패:
- UC1 (전략 불일치): 해당 없음
- UC2 (공간 인지 결손): 해당 없음
- UC3 (주의력/충동성): 해당 없음
- UC4 (복합 원인): 해당 없음

[INPUT DATA] (~300 tokens)
문제: {problem}
정답: {correct_answer}
아동 답: {student_answer}
RT: {rt_ms}ms
행동 태그: {behavior_tags}
문제 정의: L={l_level}, C={c_level}, 전략={strategy_tag}

[ANALYSIS FRAMEWORK] (~2,000 tokens)
C-S-E 3축 인지 모델 참조:
- C (Concept): Cog-C1~C6 위계. 하위 결함이 상위를 무너뜨림
- S (Strategy): S1~S7. 각 S는 대응 C에 의존
- E (Execution): E1(정보유지) x E2(절차단계) x E3(수크기)

분석 절차:
1. 오답값의 수리적 패턴 분석 (정답과의 차이, 특정 자릿수 부분합 등)
2. RT와 행동 태그의 교차 분석
3. C-S-E 중 어느 축의 결함인지 추론
4. 가장 유력한 원인 태그 1개 + 차순위 태그 1개 제시

[OUTPUT FORMAT] (~200 tokens)
반드시 다음 JSON으로 응답:
{
  "primary_cause": { "tag": "...", "domain": "...", "confidence": "..." },
  "secondary_cause": { "tag": "...", "domain": "...", "confidence": "..." },
  "reasoning": "분석 근거 (2문장 이내)",
  "probe_recommended": true/false
}
```

**프롬프트 크기**: ~4,000 tokens (시스템) + ~500 tokens (입력) = ~4,500 tokens/요청
**호출 빈도**: 전체 요청의 ~5~15% (대부분 규칙 엔진이 처리)

#### 4.2.2 분석 에이전트 프롬프트 (LLM 불필요)

분석 에이전트는 순수 코드로 구현한다. LLM을 사용하지 않는다.

```python
# 의사코드 — 분석 에이전트 핵심 로직

class AnalysisAgent:
    def __init__(self, problem_bank: ProblemBank, session_store: SessionStore):
        self.bank = problem_bank      # 15,053문제 인메모리
        self.session = session_store   # Redis

    def process(self, diagnostic_result, response_pattern, current_w, current_c):
        # 1. 4가지 반응 패턴에 따른 W/C 조정
        adjustments = self._calculate_adjustments(response_pattern, current_w, current_c)

        # 2. Route A/B 결정
        if diagnostic_result.cause_domain == "STRATEGY":
            route = "A"  # W 하향 (전략은 아는데 계산에서 막힘)
        elif diagnostic_result.cause_domain in ("CONCEPT", "SPATIAL"):
            route = "B"  # C 하향 (개념 자체를 모름)
        elif diagnostic_result.cause_domain == "ATTENTION":
            route = "ATTENTION"  # 주의력 환기 우선
        else:
            route = "A"  # 기본값

        # 3. 문제 선택 (O(log N) 이진 검색)
        next_problem = self.bank.query(
            c_level=adjustments.new_c,
            w_range=(adjustments.new_w - 0.5, adjustments.new_w + 0.5)
        )

        # 4. 복귀 루프 상태 관리
        loop_state = self._update_loop_state(diagnostic_result, response_pattern)

        # 5. Downscaling/Upscaling 전략 선택
        scaling = self._determine_scaling(response_pattern, loop_state)

        return AdaptationResult(
            route=route,
            next_problem=next_problem,
            adjustments=adjustments,
            loop_state=loop_state,
            scaling=scaling
        )

    def _calculate_adjustments(self, pattern, w, c):
        match pattern:
            case "severe_error":     return Adj(c_delta=-2, new_w=min(w, 1.0))
            case "logical_error":    return Adj(c_delta=0,  new_w=w - 1.5)
            case "correct_slow":     return Adj(c_delta=0,  new_w=w)
            case "correct_fast":     return Adj(c_delta=+1, new_w=w + 1.0)

    def _update_loop_state(self, diag, pattern):
        session = self.session.get_current()
        if session.loop_state:
            # 3단계 복귀 루프 진행 중
            if session.loop_state.step == 1 and pattern.startswith("correct"):
                return LoopState(step=2, ...)  # 미세 조정으로 진행
            elif session.loop_state.step == 2 and pattern.startswith("correct"):
                return LoopState(step=3, ...)  # 원래 문제 복귀
            elif session.loop_state.step == 3:
                if pattern.startswith("correct"):
                    return None  # 루프 완료
                else:
                    return self._handle_bridge_or_whiteout(session)
        return None

    def _handle_bridge_or_whiteout(self, session):
        # Bridge Loop: 기준점 성공 but 원래 문제 실패
        if session.loop_state.step_results[0].correct:  # Step 1 성공했었음
            return LoopState(type="bridge_loop", ...)
        # White-out: 기준점도 실패
        else:
            return LoopState(type="whiteout", c_fallback=5, ...)
```

**프롬프트 크기**: 0 tokens (코드 기반, LLM 호출 없음)
**호출 빈도**: 100% (모든 요청)

#### 4.2.3 튜터 에이전트 프롬프트 (LLM 폴백 모드, ~3,000 tokens)

튜터 에이전트도 기본은 템플릿 엔진이다. LLM은 기존 템플릿으로 커버되지 않는 특수 상황에서만 호출된다.

```
[ROLE] (~100 tokens)
너는 Maththera 튜터 에이전트다. 난산증 아동에게 따뜻하고 격려하는 피드백을
제공한다. 템플릿 엔진이 처리하지 못한 특수 상황의 피드백을 생성한다.

[ABSOLUTE CONSTRAINTS] (~500 tokens)
## 절대 준수 규칙 (위반 시 출력 거부)
1. 전체 3문장 이내
2. 문장당 10자 이내 (수식/힌트: 최대 15자)
3. 반말 사용 (존댓말 1자라도 포함 시 거부)
4. 금지 표현: "틀렸어", "아니야", "왜 못해", "정신 차려",
   "빨리", "당연히", 비꼼, 평가, 비교
5. 힌트는 1개만
6. 정답을 직접 말하지 않기

[SITUATION] (~200 tokens)
상황: {situation}
문제: {problem}
아동 답: {student_answer}
원인: {cause_tag}

[EXAMPLES] (~1,500 tokens)
## 정답
- "좋아!" / "맞았어!"
- "대단해!" / "정답이야!"
- "잘했어!" / "완벽해!"

## 오답
- "괜찮아." / "한번 더!" / "다시 해볼까?"
- "괜찮아." / "천천히 해봐." / "할 수 있어!"

## 과정 실수
- "거의 다 왔어!" / "자리만 봐!" / "다시!"
- "아깝다!" / "하나만 봐!" / "해볼까?"

## 무응답
- "괜찮아." / "하나씩 하자."
- "괜찮아." / "같이 해볼까?"

## 진단 질문 (Bridge Loop 시)
- "8이 10 되려면?" / "몇 개 더 필요해?"

[OUTPUT FORMAT] (~200 tokens)
{
  "feedback_lines": ["문장1", "문장2"],
  "hint": "힌트 (있을 때만)",
  "char_count_check": { "line1": N, "line2": N },
  "prohibition_check": true
}
```

**프롬프트 크기**: ~3,000 tokens (시스템) + ~300 tokens (입력) = ~3,300 tokens/요청
**호출 빈도**: 전체 요청의 ~5~10% (대부분 템플릿 엔진이 처리)

#### 4.2.4 프롬프트 크기 비교

| 에이전트 | 시스템 프롬프트 | 입력 | 합계 | 호출 빈도 |
|---------|--------------|------|------|----------|
| 진단 (LLM 폴백) | ~4,000 | ~500 | ~4,500 | ~10% |
| 분석 | 0 (코드) | 0 | 0 | 100% (코드) |
| 튜터 (LLM 폴백) | ~3,000 | ~300 | ~3,300 | ~8% |
| **가중 평균** | | | **~780** | **요청당** |
| Monolithic (비교) | ~14,000 | ~4,000 | ~18,000 | 100% |

### 4.3 오케스트레이션 로직

#### 4.3.1 요청 라우팅 플로우차트

```
아동 응답 수신
    │
    v
[Orchestrator] 이벤트 수신: answer_submitted
    │
    ├─(1) 진단 에이전트 호출 ──────────────────────────────────┐
    │     입력: problem, answer, rt, behaviors                  │
    │     ┌─ 규칙 엔진 매칭 성공 (UC1~4) ──> 결과 반환         │
    │     └─ 규칙 매칭 실패 ──> LLM 폴백 호출 ──> 결과 반환    │
    │                                                           │
    │<──────────────── diagnostic_result ────────────────────────┘
    │
    ├─ probe_needed == true?
    │     ├─ Yes ──> Probe 문제 생성 ──> Client에 전송 ──> (대기)
    │     │          probe_result 수신 후 진단 에이전트 재호출
    │     └─ No ──> 계속
    │
    ├─(2) 분석 에이전트 호출 ──────────────────────────────────┐
    │     입력: diagnostic_result, response_pattern, w, c       │
    │     순수 코드 실행 (< 10ms)                               │
    │                                                           │
    │<──────────────── adaptation_result ────────────────────────┘
    │
    ├─(3) 튜터 에이전트 호출 ──────────────────────────────────┐
    │     입력: situation, problem, answer, cause_tag            │
    │     ┌─ 템플릿 매칭 성공 ──> 결과 반환 (< 5ms)            │
    │     └─ 매칭 실패 ──> LLM 폴백 호출 ──> 결과 반환         │
    │                                                           │
    │<──────────────── feedback_result ──────────────────────────┘
    │
    ├─(4) 세션 상태 업데이트
    │     입력: adaptation_result의 session_update
    │     Redis 저장 (< 10ms)
    │
    ├─(5) 클라이언트 응답 조립
    │     {
    │       feedback: feedback_result,
    │       next_problem: adaptation_result.next_problem,
    │       visual_mode: adaptation_result.scaling.visual_mode,
    │       training: adaptation_result.training_ids
    │     }
    │
    v
Client에 응답 전송
```

#### 4.3.2 레이턴시 분석 (정상 경로)

```
아동 응답 수신 ──────────────────────────────────────────> 클라이언트 응답
    │                                                          │
    ├─ 진단 에이전트 (규칙): ~5ms ─┐                           │
    │                               │                           │
    ├─ 분석 에이전트 (코드): ~10ms ─┤ 순차 실행: ~25ms          │
    │                               │                           │
    ├─ 튜터 에이전트 (템플릿): ~5ms ┘                           │
    │                                                           │
    ├─ 세션 저장: ~10ms                                         │
    │                                                           │
    ├─ 응답 조립 + 전송: ~5ms                                    │
    │                                                           │
    └──────────────── 총: ~40ms ────────────────────────────────┘
```

```
LLM 폴백 경로 (~10% 확률):

    ├─ 진단 에이전트 (LLM): ~1,500ms ─┐
    │                                   │ 순차 실행: ~1,525ms
    ├─ 분석 에이전트 (코드): ~10ms ─────┤
    │                                   │
    ├─ 튜터 에이전트 (템플릿): ~5ms ────┘
    │                          또는
    ├─ 튜터 에이전트 (LLM): ~1,000ms ──> 총: ~2,525ms
    │
    └── 최악: 진단 LLM + 튜터 LLM = ~2,525ms (E2E 제약 근접)
```

#### 4.3.3 에러 처리 및 폴백

| 에러 상황 | 폴백 전략 |
|----------|----------|
| 진단 에이전트 LLM 타임아웃 (> 3초) | `UNKNOWN` 태그 반환 + 수동 리뷰 큐 등록 [pm/RSK-004] |
| 진단 에이전트 규칙 매칭 실패 + LLM 실패 | 가장 빈번한 원인 태그를 기본값으로 사용 + 알림 |
| 분석 에이전트 문제 검색 실패 (해당 W/C 범위 문제 없음) | W 범위를 +-1.0 확장하여 재검색 |
| 튜터 에이전트 LLM 톤 가이드 위반 | 금지어 필터가 차단 후 안전한 기본 템플릿("괜찮아. 다시 해볼까?") 사용 |
| 세션 스토어 연결 실패 | 로컬 인메모리 캐시로 폴백 (세션 영속성 저하) |
| Probe 응답 타임아웃 (> 30초) | 무응답 처리: ATTENTION 도메인 우선 |

### 4.4 장단점 분석

**장점:**

| 항목 | 설명 |
|------|------|
| LLM 비용 절감 | 90%+ 요청이 코드/템플릿으로 처리. LLM 호출은 예외 경로에만 |
| 레이턴시 | 정상 경로 ~40ms. E2E 2초 제약을 여유 있게 충족 |
| 일관성 | 규칙 엔진 + FSM = 결정론적 출력. 동일 입력 → 동일 출력 100% 보장 |
| 톤 가이드 준수 | 템플릿 기반 + 금지어 필터 = 위반율 0% (LLM 폴백 시에도 후처리 필터) |
| 테스트 용이성 | 각 에이전트 독립 단위 테스트 가능. 규칙/FSM은 100% 커버리지 가능 |
| 장애 격리 | 진단 LLM 실패해도 분석/튜터는 정상 동작. 부분 장애 허용 |
| 확장성 | 새 UC 추가 = 규칙 추가. 새 에이전트 추가 = 독립 모듈 추가 |

**단점:**

| 항목 | 설명 |
|------|------|
| 초기 개발 복잡도 | 오케스트레이터 + 3개 에이전트 + 통신 프로토콜 + 상태 관리 |
| 에이전트 간 계약 관리 | JSON 엔벨로프 스키마 변경 시 전 에이전트 업데이트 필요 |
| 교차 참조 제한 | 진단 결과를 보고 피드백을 동적으로 조정하려면 오케스트레이터 경유 필요 |
| 운영 복잡도 | 모니터링 포인트가 4배 (오케스트레이터 + 3 에이전트) |
| 디버깅 | 분산 트레이싱 필요. 단일 요청이 여러 에이전트를 경유 |

---

## 5. 비교 분석

### 5.1 기술적 비교 매트릭스

| 평가 축 | Option A (Monolithic) | Option B (Multi-Agent) | 우위 |
|---------|----------------------|----------------------|------|
| **프롬프트 복잡도** | ~14K tokens 단일 프롬프트. 모든 규칙을 자연어로 기술 | 0 tokens (90%) ~ 4.5K tokens (10%). 규칙은 코드 | **B** |
| **컨텍스트 윈도우** | 매 요청 ~18K tokens 소비. 세션 길어지면 30K+ | 가중 평균 ~780 tokens/요청. 윈도우 압박 없음 | **B** |
| **상태 관리** | 대화 이력에 암묵적 포함. LLM이 "기억"해야 함 | Redis에 명시적 저장. 코드가 읽고 씀 | **B** |
| **장애 격리** | 단일 장애점. LLM 다운 = 전체 다운 | 진단 LLM 다운해도 분석/튜터 정상. 부분 서비스 가능 | **B** |
| **테스트 용이성** | 프롬프트 기반 = 비결정론적. E2E만 가능 | 규칙/FSM = 결정론적 단위 테스트. 커버리지 100% 가능 | **B** |
| **레이턴시** | 1.5~3초 (매 요청 LLM) | 정상 ~40ms, 폴백 ~2.5초 | **B** |
| **비용 (API)** | ~18K tokens/요청 x 100% = 높음 | ~780 tokens/요청 (가중) = 매우 낮음 | **B** |
| **확장성** | 규칙 추가 = 프롬프트 비대화. 한계 명확 | 규칙 추가 = 코드 추가. 선형 확장 | **B** |
| **디버깅 용이성** | 단일 로그. 간단 | 분산 트레이싱 필요. 복잡 | **A** |
| **일관성** | LLM 의존 = 비결정론적. 같은 입력에 다른 출력 가능 | 규칙/FSM = 결정론적. 동일 입출력 보장 | **B** |
| **초기 개발 속도** | 빠름 (프롬프트만 작성) | 느림 (오케스트레이터 + 에이전트 + 프로토콜) | **A** |
| **교차 참조** | 전체 컨텍스트 한 번에 접근 | 오케스트레이터 경유 필요 | **A** |
| **전체 점수** | 3/12 우위 | **9/12 우위** | **B** |

### 5.2 비용 비교 (월간 추정)

**가정**: MAU 5,000명, 사용자당 월 20세션, 세션당 15문제 = 월 1,500,000 요청

#### Option A (Monolithic)

```
입력: 18,000 tokens/요청 x 1,500,000 = 27,000M tokens
출력: 500 tokens/요청 x 1,500,000 = 750M tokens

Claude Sonnet 기준 ($3/M input, $15/M output):
  입력: 27,000 x $3 = $81,000
  출력: 750 x $15 = $11,250
  합계: ~$92,250/월

GPT-4o 기준 ($2.50/M input, $10/M output):
  입력: 27,000 x $2.50 = $67,500
  출력: 750 x $10 = $7,500
  합계: ~$75,000/월
```

#### Option B (Multi-Agent)

```
LLM 호출 비율: ~10% = 150,000 요청
  진단 LLM: 4,500 tokens x 75,000 = 337.5M tokens
  튜터 LLM: 3,300 tokens x 75,000 = 247.5M tokens
  출력: 300 tokens x 150,000 = 45M tokens

Claude Sonnet 기준:
  입력: 585 x $3 = $1,755
  출력: 45 x $15 = $675
  합계: ~$2,430/월

GPT-4o 기준:
  입력: 585 x $2.50 = $1,462.50
  출력: 45 x $10 = $450
  합계: ~$1,912.50/월

코드 실행 비용 (서버):
  ~$200~500/월 (Redis + 컴퓨팅)

총합: ~$2,630~$2,930/월
```

#### 비용 비교 요약

| | Option A | Option B | 절감율 |
|--|---------|---------|--------|
| Claude Sonnet | ~$92,250/월 | ~$2,930/월 | **96.8%** |
| GPT-4o | ~$75,000/월 | ~$2,413/월 | **96.8%** |

### 5.3 Maththera 특수 상황 분석

#### 5.3.1 RT 기반 실시간 분기

**질문**: RT(밀리초) 기반 실시간 분기에 적합한 아키텍처는?

**분석**: RT 측정은 클라이언트 사이드 로컬 타이머로 수행하며 [tech/CLM-010], 서버에서는 이 수치를 받아 임계값(5초, 0.8초)과 비교하는 단순 조건 분기다. LLM이 수치를 "이해"하는 것보다 코드의 `if (rt > 5000)` 비교가 100% 정확하고 0ms에 가깝다.

**적합**: **Option B**. 분석 에이전트의 코드 기반 처리가 정확도와 속도 모두 우월.

#### 5.3.2 Bridge Loop / White-out 상태 전이

**질문**: 복잡한 상태 전이(3단계 루프 -> Bridge Loop -> White-out)에 적합한 아키텍처는?

**분석**: Bridge Loop는 "100+90=190 성공 but 98+90 실패" 패턴을 감지하고, White-out은 "100+90도 실패" 패턴을 감지한다. 이 두 분기는 세션 컨텍스트의 `loop_state.step_results` 배열을 참조하는 조건 분기다.

Monolithic 에이전트가 대화 이력에서 "이전에 100+90을 맞혔는지"를 추론하는 것보다, FSM이 `step_results[0].correct == true`를 확인하는 것이 결정론적이다.

특히 White-out의 "10+9 수준으로 대폭 후퇴" 결정은, LLM이 컨텍스트를 잃어버리면 잘못된 수준으로 후퇴할 수 있다. FSM은 `c_fallback=5`를 하드코딩할 수 있다.

**적합**: **Option B**. FSM의 결정론적 상태 전이가 필수.

#### 5.3.3 톤 가이드 100% 준수

**질문**: 3문장, 10자, 반말, 금지 표현 0% 위반을 보장하려면?

**분석**: PRD v4는 명시적으로 "LLM 자유 생성 금지, 템플릿 기반" [tech/CLM-009]을 결정했다. 이는 사전 검수된 템플릿 풀에서 선택하고 변수 슬롯만 채우는 방식이다.

Monolithic 에이전트는 프롬프트에 규칙을 명시해도 LLM 특성상 가끔 위반이 발생한다 (특히 긴 컨텍스트에서 instruction following 성능 저하). 후처리 필터를 추가해야 하는데, 그러면 결국 코드 기반 검증 레이어가 필요하다.

Multi-Agent의 튜터 에이전트는 기본이 템플릿 엔진이므로, 위반이 구조적으로 불가능하다. LLM 폴백 시에도 금지어 필터 + 글자수 검증 레이어가 존재한다.

**적합**: **Option B**. 템플릿 엔진 + 필터 = 100% 준수 보장.

#### 5.3.4 변인 통제 Probe 상태 추적

**질문**: UC4의 Probe 출제 -> 응답 수집 -> Case A/B 확정 과정에서 상태를 정확히 추적하려면?

**분석**: Probe는 비동기 이벤트다. 원래 문제(28+15)의 진단이 보류되고, Probe(20+15)의 결과를 기다린 후 원래 문제의 진단을 확정한다.

Monolithic 에이전트에서 이 상태를 추적하려면 대화 이력에 "지금 Probe 대기 중이다"라는 정보를 유지해야 한다. LLM은 대화가 길어지면 이 맥락을 잃을 수 있다.

Multi-Agent에서는 `session.probe_state = { original_problem: "28+15", probe_problem: "20+15", candidates: ["SPATIAL_L4_ALIGNMENT", "STRATEGY_L4_PLACEVALUE"] }`로 명시적 저장하고, Probe 응답 수신 시 진단 에이전트가 이를 읽어 Case A/B를 확정한다.

**적합**: **Option B**. 명시적 상태 저장이 비동기 이벤트 처리에 필수.

### 5.4 하이브리드 접근 가능성

#### 5.4.1 핵심 통찰: "에이전트 != LLM"

PRD v4의 tech 에이전트는 이미 다음을 결정했다:

> "규칙 기반 결정 트리 + FSM으로 전체 적응형 로직 구현 가능. ML 불필요" [tech/CLM-001]
> "템플릿 기반 피드백 시스템. LLM 자유 생성 금지" [tech/CLM-009]
> "15,053문제 인메모리 처리 가능, O(log N) 쿼리" [tech/CLM-004]

이 결정들은 사실상 **"LLM 에이전트는 핵심 경로에 불필요하다"**는 결론이다. Maththera의 "에이전트"는 LLM 에이전트가 아니라, 자율적으로 의사결정하는 소프트웨어 에이전트다.

#### 5.4.2 LLM이 정말 필요한 곳 vs 규칙 엔진이 충분한 곳

```
┌─────────────────────────────────────────────────────────┐
│                    규칙 엔진 영역                         │
│              (결정론적, 코드 기반, LLM 불필요)             │
│                                                          │
│  ┌─────────────────────────────────────────────────┐    │
│  │ 5단계 파이프라인 (UC1~UC4)                       │    │
│  │ W/C 이중태그 쿼리                                │    │
│  │ 4가지 반응 패턴 분기                              │    │
│  │ Route A/B 결정                                   │    │
│  │ 3단계 복귀 루프 / Bridge Loop / White-out         │    │
│  │ 변인 통제 Probe 출제/확정                         │    │
│  │ Downscaling/Upscaling 전략 선택                   │    │
│  │ 피드백 템플릿 선택 + 변수 충전                     │    │
│  │ 금지어 필터                                      │    │
│  │ 세션 컨텍스트 관리                                │    │
│  └─────────────────────────────────────────────────┘    │
│                                                          │
│  처리 비율: ~90%+ of all requests                        │
│  레이턴시: < 50ms                                        │
│  비용: 서버 비용만 (~$200~500/월)                         │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│                     LLM 영역                             │
│             (비결정론적, 자연어 이해/생성 필요)             │
│                                                          │
│  ┌─────────────────────────────────────────────────┐    │
│  │ 미지의 오답 패턴 분석 (UC1~4 미매칭)              │    │
│  │   → "이 오답 패턴은 어떤 인지 도메인 결함인가?"    │    │
│  │                                                  │    │
│  │ 특수 상황 피드백 생성 (템플릿 미매칭)              │    │
│  │   → 기존 템플릿으로 커버 안 되는 상황              │    │
│  │                                                  │    │
│  │ [Phase 2] 음성 입력 NLU                          │    │
│  │   → 아동의 자유 응답 의도 파악                     │    │
│  │                                                  │    │
│  │ [Phase 2] 보호자/교사 리포트 자연어 생성           │    │
│  │   → 진단 결과를 이해하기 쉬운 설명으로 변환        │    │
│  └─────────────────────────────────────────────────┘    │
│                                                          │
│  처리 비율: ~10% of requests (Phase 1)                   │
│  레이턴시: 1~2초                                         │
│  비용: ~$2,000~3,000/월 (MAU 5,000 기준)                 │
└─────────────────────────────────────────────────────────┘
```

#### 5.4.3 하이브리드 아키텍처: "코드 에이전트 + LLM 보조"

이 분석의 결론은, Option A와 Option B의 이분법이 아니라 **하이브리드 구조**가 최적이라는 것이다.

```
┌──────────────────────────────────────────────────────────┐
│              Hybrid Architecture (권장)                    │
│                                                           │
│  ┌─────────────────────────────────────────────────────┐ │
│  │         Code-Based Agent Layer (핵심 경로)           │ │
│  │                                                      │ │
│  │  Orchestrator ──> Diagnostic ──> Analysis ──> Tutor  │ │
│  │  (이벤트 기반)    (규칙 엔진)    (FSM+쿼리)  (템플릿) │ │
│  │                                                      │ │
│  │  레이턴시: < 50ms | 결정론적 | LLM 호출 0             │ │
│  └─────────────────────────────┬───────────────────────┘ │
│                                 │                         │
│                          규칙 매칭 실패?                   │
│                          ┌─ No ──> 응답 반환               │
│                          │                                │
│                          └─ Yes ──┐                       │
│                                    v                      │
│  ┌─────────────────────────────────────────────────────┐ │
│  │          LLM Fallback Layer (예외 경로)              │ │
│  │                                                      │ │
│  │  Unknown Pattern Analyzer  │  Creative Feedback Gen  │ │
│  │  (미지 오답 원인 분석)      │  (특수 상황 피드백)      │ │
│  │                                                      │ │
│  │  레이턴시: 1~2초 | 비결정론적 | 후처리 필터 필수       │ │
│  └─────────────────────────────────────────────────────┘ │
│                                                           │
└──────────────────────────────────────────────────────────┘
```

---

## 6. 권장안

### 6.1 종합 판단

**권장**: Option B 기반 하이브리드 아키텍처 (코드 에이전트 + LLM 폴백)

| 판단 근거 | 설명 |
|----------|------|
| PRD v4 정합성 | tech/CLM-001(규칙 기반), CLM-009(템플릿 기반)과 완전 일치 |
| 비용 효율 | 월 API 비용 96.8% 절감 ($92K → $3K) |
| 레이턴시 | 정상 경로 ~40ms. E2E 2초 제약 초과 달성 |
| 일관성 | 결정론적 출력. 동일 입력 → 동일 출력. 치료적 재현성 확보 |
| 톤 가이드 | 템플릿 + 필터 = 100% 준수. 아동 안전 보장 |
| 확장성 | 곱셈/나눗셈 = 규칙 추가. Phase 2 LLM 기능 = 폴백 레이어 확장 |
| 테스트 | UC1~4 + FSM = 단위 테스트 100% 커버리지 가능 |

### 6.2 선택 기준 (Decision Matrix)

| 기준 | 가중치 | Option A | Option B Hybrid | 근거 |
|------|--------|---------|----------------|------|
| 치료적 재현성 (동일 입력 → 동일 출력) | 25% | 2/5 | 5/5 | 임상 효과 추적의 전제 조건 |
| 아동 안전 (톤 가이드 위반 = 0) | 25% | 3/5 | 5/5 | 난산증 아동의 수학 불안 악화 방지 |
| 운영 비용 | 20% | 1/5 | 5/5 | 월 $92K vs $3K |
| 레이턴시 (E2E < 2초) | 15% | 2/5 | 5/5 | 아동 집중력 유지 |
| 초기 개발 속도 | 10% | 5/5 | 3/5 | Monolithic이 빠르나 가중치 낮음 |
| 확장성 | 5% | 2/5 | 4/5 | Phase 2~3 기능 추가 대비 |
| **가중 합계** | 100% | **2.45** | **4.80** | |

### 6.3 구현 로드맵

#### Phase 1-0: 코어 아키텍처 (Week 0~2)

| 주차 | 산출물 | 세부 |
|------|--------|------|
| W0 | 오케스트레이터 스켈레톤 | 이벤트 기반 디스패처, 메시지 엔벨로프 정의, Redis 세션 스토어 |
| W1 | 진단 에이전트 (규칙 엔진) | UC1~UC4 패턴 매칭, 원인-훈련 매핑 테이블 |
| W1 | 분석 에이전트 (FSM) | 4가지 반응 패턴, Route A/B, 문제 선택 쿼리 |
| W2 | 튜터 에이전트 (템플릿) | 4가지 상황 템플릿 풀(20개+), 금지어 필터, 글자수 검증 |
| W2 | E2E 통합 테스트 | UC1~UC4 시나리오 전체 관통 테스트 |

#### Phase 1-1: 상태 머신 + 복귀 루프 (Week 3~4)

| 주차 | 산출물 | 세부 |
|------|--------|------|
| W3 | 3단계 복귀 루프 FSM | 기준점 고정 → 미세 조정 → 복귀 |
| W3 | Bridge Loop 로직 | 기준점 성공/원래 실패 분기, 빌려오기 전략 |
| W4 | White-out 감지 | 기준점도 실패 → C=5 후퇴 |
| W4 | 변인 통제 Probe 비동기 처리 | Probe 출제 → 대기 → Case A/B 확정 |

#### Phase 1-2: LLM 폴백 레이어 (Week 5~6)

| 주차 | 산출물 | 세부 |
|------|--------|------|
| W5 | 진단 LLM 폴백 | 미지 패턴 분석 프롬프트, UNKNOWN 태그 + 리뷰 큐 |
| W5 | 튜터 LLM 폴백 | 특수 상황 피드백 생성, 톤 가이드 후처리 필터 |
| W6 | 폴백 통합 테스트 | 규칙 실패 → LLM 폴백 → 후처리 필터 E2E |

#### Phase 1-3: 모니터링 + 최적화 (Week 7~8)

| 주차 | 산출물 | 세부 |
|------|--------|------|
| W7 | 분산 트레이싱 | 요청 ID 기반 전 에이전트 로그 추적 |
| W7 | LLM 폴백 빈도 모니터링 | 미지 패턴 수집 → 규칙 추가 피드백 루프 |
| W8 | 성능 최적화 | 캐시, 배치 처리, 프롬프트 최적화 |

#### Phase 2 (미래): LLM 기능 확장

| 기능 | 시기 | 설명 |
|------|------|------|
| STT + NLU 에이전트 | Phase 2 W1~4 | 음성 입력 의도 분석. 별도 에이전트로 추가 |
| 보호자 리포트 생성 | Phase 2 W5~6 | 진단 결과를 자연어 설명으로 변환. LLM 활용 |
| 자율 학습 (Agent Learning) | Phase 2 W7+ | LLM 폴백 로그에서 신규 규칙 자동 추출 |

---

## 7. 부록

### 7.1 용어 정의

| 용어 | 정의 |
|------|------|
| W-Score | Working Memory Score. 문제의 작업기억 부하를 6차원으로 정량화한 점수 (0~9.5) |
| C-Tag | Concept Tag. Cur-C(교육과정 단원 1~15) + Cog-C(인지진단 1~6) |
| FSM | Finite State Machine. 유한 상태 머신. 상태와 전이 조건으로 행동을 정의 |
| Route A | W 하향 경로. 전략은 알지만 계산에서 막힐 때 작업기억 부하를 낮춤 |
| Route B | C 하향 경로. 개념 자체를 모를 때 교육과정 단계를 후퇴시킴 |
| Bridge Loop | 기준점 문제(100+90)는 풀지만 원래 문제(98+90)로 돌아가면 막히는 현상 |
| White-out | 기준점 문제도 풀지 못하는 상태. 대폭 후퇴 필요 |
| Probe | 변인 통제 확인 문제. 오답 원인이 복수일 때 하나의 변인을 제거하여 원인 확정 |
| Scaffolded Recovery | 3단계 복귀 루프: 기준점 고정 → 미세 조정 → 원래 문제 복귀 |
| Downscaling | 문제 난이도를 낮추는 전략 (시각 보조, 단계 분리, 숫자 축소, 세로셈) |
| Upscaling | 문제 난이도를 높이는 전략 (시각 제거, 추상화, 수치 확장) |
| UC1~UC4 | 유스케이스 1~4. 전략 불일치, 공간 인지 결손, 주의력/충동성, 복합 원인 감별 |
| RT | Response Time. 문제 제시부터 응답까지의 시간 (밀리초) |
| LLM Fallback | 규칙 엔진/템플릿이 처리하지 못한 예외 상황에서 LLM API를 호출하는 보조 경로 |

### 7.2 참고 문헌

| ID | 문서 | 참조 내용 |
|----|------|----------|
| tech/CLM-001 | PRD v4 기술 노트 | 규칙 기반 결정 트리 + FSM 결정 |
| tech/CLM-003 | PRD v4 기술 노트 | 4가지 반응 패턴 상태 전이 |
| tech/CLM-004 | PRD v4 기술 노트 | 15,053문제 인메모리, O(log N) |
| tech/CLM-007 | PRD v4 기술 노트 | 객관식 입력 방식 결정 |
| tech/CLM-008 | PRD v4 기술 노트 | Downscaling 4전략 / Upscaling 3전략 |
| tech/CLM-009 | PRD v4 기술 노트 | 템플릿 기반 피드백, LLM 자유 생성 금지 |
| tech/CLM-010 | PRD v4 비기능 요구사항 | RT 10ms 정밀도, E2E 2초 |
| biz/CLM-002 | PRD v4 비즈니스 분석 | 정답이어도 느리면 전략 미숙 진단 |
| biz/CLM-005 | PRD v4 비즈니스 분석 | 변인 통제 Probe 기반 감별 진단 |
| pm/CLM-003 | PRD v4 PM 분석 | 5단계 오답 진단 파이프라인 |
| pm/CLM-007 | PRD v4 PM 분석 | 변인 통제 Probe 시스템 |
| pm/CLM-008 | PRD v4 PM 분석 | AI 피드백 톤 가이드 |
| research/CLM-002 | PRD v4 리서치 | C-S-E 3축 인지 모델 |
| pedagogy/CLM-Route-A | PRD v4 교육학 분석 | Route A 작업기억 최적화 |
| pedagogy/CLM-Route-B | PRD v4 교육학 분석 | Route B 개념적 후퇴 |
| pedagogy/CLM-Bridge | PRD v4 교육학 분석 | Bridge Loop 빌려오기 전략 |
| pedagogy/CLM-Whiteout | PRD v4 교육학 분석 | White-out 대폭 후퇴 |
| SRC-adaptive-logic | 원본 증거 | 데이터 기반 오답 교정 알고리즘 전문 |

### 7.3 결정 로그

| 날짜 | 결정 ID | 결정 | 근거 |
|------|---------|------|------|
| 2026-02-13 | AD-001 | Option B Hybrid 채택 | 비용 96.8% 절감, E2E 40ms, 결정론적 출력, 톤 가이드 100% |
| 2026-02-13 | AD-002 | LLM은 예외 경로에만 사용 | 16개 기능 중 13개 규칙 기반, LLM 조건부 3개 |
| 2026-02-13 | AD-003 | 소프트웨어 에이전트 패러다임 채택 | PRD v4 tech 결정(규칙+FSM)과 일치 |

---

*이 문서는 PRD v4, 기술 평가 보고서(tech.md), Adaptive Logic 알고리즘 사양, Master Matrix 유스케이스 시나리오를 기반으로 작성되었습니다. 모든 핵심 주장에는 [에이전트/CLM-ID] 형식의 출처가 표기되어 있습니다.*
