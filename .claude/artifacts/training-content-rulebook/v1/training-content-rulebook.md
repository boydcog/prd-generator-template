# Maththera 훈련 컨텐츠 룰북

> **문서 유형**: 훈련 컨텐츠 생성 종합 사양서 (Content Rule Spec + Design Guide + Agent Prompt Spec)
> **버전**: v1
> **생성일**: 2026-02-12
> **목적**: AI 에이전트가 훈련 컨텐츠를 자동 생성할 때 따라야 할 룰, 제약 조건, 설계 가이드를 정의

---

## 목차

1. [Part 1: Content Rule Spec](#part-1-content-rule-spec) — 룰 정의, 제약 조건, 파라미터
2. [Part 2: Training Design Guide](#part-2-training-design-guide) — 모듈별 설계 가이드
3. [Part 3: Agent Prompt Spec](#part-3-agent-prompt-spec) — 에이전트 역할, 입출력, 검증 규칙
4. [Appendix](#appendix) — 참조 테이블

---

# Part 1: Content Rule Spec

## 1.1 시스템 개요

Maththera의 훈련 컨텐츠는 다음 파이프라인을 통해 생성됩니다:

```
[문제정의 13,981개] → [C-S-E 3축 진단] → [오답원인 85개] → [훈련모듈 30+2개]
                                                                    ↓
                                                          [컨텐츠 렌더링]
                                                          [피드백 생성]
                                                          [통과 판정]
```

**핵심 원칙**: 모든 훈련 컨텐츠는 **증거 기반(Evidence-based)**으로 생성됩니다. 에이전트의 자의적 해석은 허용되지 않으며, 아래 정의된 룰에 의해서만 컨텐츠가 결정됩니다.

---

## 1.2 C-S-E 인지 모델 (진단 프레임워크)

훈련 컨텐츠 생성의 모든 결정은 C-S-E 모델에 기반합니다.

### C: 개념 (Concept) — 장기기억의 수 표상

뇌의 후두정엽(IPS)에 저장된 수학적 지식. 6단계 계층 구조:

| 레벨 | 태그 | 정의 | 진단 포인트 |
|------|------|------|------------|
| 1 | **C1 기수성** | 숫자 기호 ↔ 실제 양의 일치 | '7'을 보고 물체 7개를 떠올리는가? |
| 2 | **C2 크기 비교** | 수의 서열 인지, 연산 방향성 | 7이 3보다 '많다'는 직관적 이해 |
| 3 | **C3 수 감각** | 기준수(5, 10)와의 상대적 거리감 | 7은 5에 가까운가, 10에 가까운가? |
| 4 | **C4 자릿수 원리** | 10진법 구조, 묶음 단위 인식 | 23 = 20 + 3 (2+3이 아님) |
| 5 | **C5 결합/분해** | 수를 부분으로 가르거나 전체로 모으기 | 8 = 3+5 = 2+6 (다양한 분해) |
| 6 | **C6 가역성** | 덧셈 ↔ 뺄셈 역관계 이해 | 8+2=10이면, 10-2=8 |

**계층 규칙**: 하위 단계 결함이 있으면 상위 단계 전체가 무너짐. C1 → C2 → C3 → C4 → C5 → C6 순서로 반드시 확보.

**추가 세분화 (확정 예정)**:
- **C5a (합성)**: 3과 2를 보고 5를 떠올리는 능력
- **C5b (분해)**: 10을 보고 7과 3으로 가르는 능력
- **C1-Zero**: 0의 기수적 특성과 '자리 지키기' 기능 (서브태그)

### S: 전략 (Strategy) — 전전두엽의 문제 해결 설계

7단계 전략 체계. 각 전략은 특정 C 레벨에 연결됩니다:

| 레벨 | 태그 | 전략명 | 연결 개념 | 예시 |
|------|------|--------|---------|------|
| 1 | **S1** | 전부 세기 (Count-all) | C1 | 3+2 → "1,2,3—1,2—1,2,3,4,5" |
| 2 | **S2** | 큰 수부터 이어 세기 (Min) | C2 | 3+28 → "28—29,30,31" |
| 3 | **S3** | 기준수 근접 (Benchmark) | C3 | 9+5 → "9→10→14" |
| 4 | **S4** | 구조적 점프 (Chunking) | C4 | 25+12 → "25+10=35, +2=37" |
| 5 | **S5** | 분해 합산 (Make 10) | C5 | 8+7 → "8+2=10, +5=15" |
| 6 | **S6** | 추정/검증 (Estimation) | C6 | "30 근처겠네" → 32 → 검산 |
| 7 | **S7** | 유형 분류 (Pre-Planning) | C1~C6 통합 | 문제 보고 전략 미리 선택 |

### E: 집행 (Execution) — 작업기억 부하

| 차원 | 설명 | 값 범위 |
|------|------|--------|
| **E1** | 정보 유지량 (피연산자 자릿수) | 1자리 / 2자리 |
| **E2** | 절차적 단계 (받아올림 유무) | 없음 / 있음 / 연쇄 |
| **E3** | 수의 물리적 크기 | Low(0~4) / Mid(5~7) / High(8~9) |

**난산증 아동 특성**: E1+E2+E3 부하가 높아지면 급격한 성능 저하 → 충동적 반응(찍기) 발생.

---

## 1.3 Concept Tag 트리거 룰

### 절대 규칙

1. **Bottom-up Selection**: 기초 문항에서는 하위 개념 태그만 스캔
   - 예: 3+0 → C1, C2만 활성화 (C3~C6 스캔 금지)
   - 목적: 과진단 방지

2. **문제 유형별 활성화 테이블**: 아래 표에 따라 엄격히 적용

### A. 한자리수 + 한자리수

| 태그 | 활성화 조건 | 인지적 의미 |
|------|-----------|-----------|
| C1 | A=0 또는 B=0 | 0의 양적 처리 |
| C2 | 항상 (Always) | 덧셈의 방향성 |
| C3 | 합 4~6(기준5) 또는 8~12(기준10) | 기준수 거리감 |
| C4 | 합 ≥ 10 | 10 묶음 형성 |
| C5 | A,B > 0 모두 0 아닐 때 | 결합 능력 |
| C6 | 미지수 문항에서만 (3+?=7) | 가역성 |

### B. 한자리수 - 한자리수

| 태그 | 활성화 조건 | 인지적 의미 |
|------|-----------|-----------|
| C1 | B=0 또는 결과=0 | 0의 처리 |
| C2 | 항상 (Always) | 감소성 |
| C3 | 차=0,1 또는 4,5,6 | 수직선 거리감 |
| C4 | **비활성** | 한자리 뺄셈은 십진법 관련 없음 |
| C5 | B>0 이고 A≠B | 전체-부분 관계 |
| C6 | 항상 (Always) | 역관계 |

### C. 두자리수 - 한자리수

| 태그 | 활성화 조건 | 인지적 의미 |
|------|-----------|-----------|
| C1 | 결과의 일의 자리=0 | 0 포함 수의 기수적 가치 |
| C2 | 항상 (Always) | 방향성 |
| C3 | 받아내림 발생 또는 결과 ≈ 10,20 | 경계 횡단 |
| C4 | 항상 (Always) | 구조적 분리 필수 |
| C5 | C>0 이고 AB≠C | 실질적 분해 |
| C6 | 항상 (Always) | 역관계 호출 |

### D. 두자리수 + 두자리수

| 태그 | 활성화 조건 | 인지적 의미 |
|------|-----------|-----------|
| C1 | 피가수/가수가 10의 배수 또는 결과=100 | 자리 지키기 |
| C2 | 항상 (Always) | 두 양의 합산 방향성 |
| C3 | 받아올림 발생 또는 합 ≥ 100 | 십진법 경계 초과 |
| C4 | 항상 (Always) | 십진 구조 분리/결합 필수 |
| C5 | 항상 (Always) | 각 자릿수별 병합 필수 |

### E. 두자리수 - 두자리수

| 태그 | 활성화 조건 | 인지적 의미 |
|------|-----------|-----------|
| C1 | 일의 자리=0 또는 결과=0 | 자리 지키기 |
| C2 | 항상 (Always) | 감소성 |
| C3 | 받아내림 발생 또는 결과 ≈ 10,20 | 경계 횡단 |
| C4 | 항상 (Always) | 구조적 분리 필수 |
| C5 | CD>0 이고 AB≠CD | 복합 분해 |
| C6 | 항상 (Always) | 역관계 호출 |

---

## 1.4 Level Tag (L-level): 아동 역량 진단 기준

### 6단계 레벨 체계

| 레벨 | 설명 | 피연산자 | 받아올림 | 수크기 | 문제 수 |
|------|------|---------|---------|--------|---------|
| **L0** | 기초 미달 | 한자리 | X | Low(0~4) | — |
| **L1** | 기초 | 한자리 | X | Mid(5~7) | 81개 (0.5%) |
| **L2** | 기초+ | 한자리 | O | Low | 2,513개 (16.7%) |
| **L3** | 중급 | 두자리 | O | Mid | 4,216개 (28.0%) |
| **L4** | 중상급 | 두자리 | O | High | 5,503개 (36.6%) |
| **L5** | 고급 | 두자리 | O (연쇄) | 최고 | 2,736개 (18.2%) |

### 레벨 점수 산정 (6개 가중 요소)

| 요소 | 가중치 | 기준 |
|------|--------|------|
| W1 연산 | 1.5점 | 뺄셈 > 덧셈 |
| W2 자릿수 | 3.0점 | 자리 수가 많을수록 |
| W3 숫자크기 | 0.5점 | 8~9 > 5~7 > 0~4 |
| W4 복잡성 | 3.0점 | 받아올림/빌려오기 있음 |
| W5 특수수 | -1.0~-0.5점 | 0, 5, 10 감점 |
| W6 표현 | 0.5점 | 기본 가산점 |

---

## 1.5 C-Level (문항 복잡도): 문제 구조 기준

| C-Level | 복잡도 | 특징 |
|---------|--------|------|
| **C1** | 최저 | 기본 덧셈/뺄셈 |
| **C2** | 낮음 | 한자리수 조합 |
| **C3** | 중간 | 기준수 활용 필요 |
| **C4** | 높음 | 받아올림/받아내림 |
| **C5** | 최고 | 연쇄적 올림/내림 |

---

## 1.6 오답 진단 → 훈련 매핑 파이프라인

### 진단 흐름

```
[1. 문제 출제]
    ↓
[2. 응답 수집] — 답, RT(반응시간), 변경 횟수
    ↓
[3. 트리거 룰 평가] — 문제 유형별 Concept Tag 활성화
    ↓
[4. C-S-E 3축 분석]
    ├── C축: 어떤 개념이 결함인가?
    ├── S축: 어떤 전략을 사용(또는 미사용)했는가?
    └── E축: 작업기억 부하가 원인인가?
    ↓
[5. error_tag 확정] — 85개 중 1개
    ↓
[6. 신뢰도(confidence) 산출] — 0.65~0.98
    ↓
[7. Training Mapping DB 조회]
    ↓
[8. training_id 결정] — 30+2개 중 1개
    ↓
[9. 선행 훈련(prereq) 확인]
    ├── 충족: 해당 훈련 실행
    └── 미충족: 선행 훈련으로 자동 분기
    ↓
[10. 컨텐츠 렌더링 및 피드백 생성]
    ↓
[11. 통과 판정]
    ├── pass_criterion 충족: 재진단 문제 출제
    └── 미충족 (5회 연속 오답): fallback_module로 분기
```

### 매핑 규칙

| 규칙 | 설명 |
|------|------|
| **1:1 우선** | 각 error_tag는 정확히 하나의 training_id로 매핑 |
| **N:1 허용** | 여러 error_tag가 같은 training_id를 공유 가능 |
| **MECE 보증** | 7대 인지 카테고리 간 중복 없음, 85개 오답원인 간 중복 없음 |
| **순환 금지** | 선행 훈련(prerequisite) 간 순환 의존 구조 불허 |

---

## 1.7 7대 인지 카테고리별 오답 원인 분류

| # | 카테고리 | 뇌 영역 | 대표 error_tag | 연결 훈련 유형 |
|---|---------|--------|---------------|-------------|
| 1 | **시지각** | 후두엽 | VISUAL_L1_NUMBER_SHAPE | Perception |
| 2 | **공간처리** | 두정엽 | SPATIAL_L4_PLACE_VALUE | Perception/Concept |
| 3 | **주의력** | 전두엽 | ATTENTION_L0_IMPULSE | Intervention |
| 4 | **수개념** | IPS | CONCEPT_L1_CARDINALITY | Concept |
| 5 | **자동화** | 기저핵 | FACT_FLUENCY_L1_SLOW | Drill |
| 6 | **작업기억** | PFC | MEMORY_L4_OVERWHELM | Intervention/Strategy |
| 7 | **연산전략** | 전전두엽 | STRATEGY_L4_CARRY_MISSING | Strategy |

---

## 1.8 필수 제약 조건

### 인지 제약

| # | 제약 | 설명 | 위반 시 |
|---|------|------|--------|
| IC-1 | **개념 태그 정합성** | 훈련 모듈은 매핑된 error_tag의 개념 결함만 교정 | 다른 개념 태그 활성화 유도 금지 |
| IC-2 | **계층적 의존성** | C1→C2→C3→C4→C5→C6 순서 준수 | C1 결함 시 C5 훈련 절대 금지 |
| IC-3 | **Prerequisite 규칙** | prerequisites 배열의 모든 훈련 선통과 필수 | 선행 훈련으로 강제 분기 |
| IC-4 | **Bottom-up 스캔** | 기초 문항에서 하위 태그만 평가 | 과진단 방지 |

### 난이도 제약

| # | 제약 | 설명 |
|---|------|------|
| DC-1 | **L-Level 범위** | 아동 현재 L-level 기준 ±1 범위 내 훈련만 제시 |
| DC-2 | **C-Level 단계성** | 단일 훈련 내 C-level 점프 금지 (C1→C2→C3 순서) |
| DC-3 | **Carry/Borrow 통제** | 받아올림 없는 문제 우선, 이후 30% 비율로 도입 |

### 콘텐츠 설계 제약

| # | 제약 | 수치 |
|---|------|------|
| CC-1 | 화면당 최대 항목 수 | **5개** |
| CC-2 | 텍스트 최대 길이 | **50자** |
| CC-3 | 선택지 최대 수 | **4개** |
| CC-4 | 시각 메타포 혼용 | **금지** (같은 훈련 내 단일 메타포) |
| CC-5 | 추상적 기호만 사용 | **금지** (반드시 시각화 병행) |

### 피드백 제약

| # | 제약 | 수치 |
|---|------|------|
| FC-1 | 최대 문장 수 | **3문장** (절대) |
| FC-2 | 문장당 최대 글자 | **10자** (수식 포함 시 15자) |
| FC-3 | 힌트 수 | **1개만** (다중 힌트 금지) |
| FC-4 | 어체 | **반말** (존댓말 금지) |
| FC-5 | 정답 직접 노출 | **금지** (최후의 수단 제외) |

### 통과 기준 제약

| # | 제약 | 수치 |
|---|------|------|
| PC-1 | 기본 정답률 | **85% 이상** |
| PC-2 | 최소 시행 횟수 | **5회 이상** |
| PC-3 | RT 기준 | **평균 < 3초** (연령별 조정) |
| PC-4 | 연속 오답 분기 | **5회 연속 오답 → fallback 모듈** |

### 데이터 수집 제약

| # | 제약 | 수치 |
|---|------|------|
| DT-1 | 훈련당 최소 응답 | **5회** |
| DT-2 | 아동당 최소 세션 | **3회** |
| DT-3 | 분석용 최소 데이터셋 | **20건** |
| DT-4 | RT 측정 | 클라이언트 사이드, `performance.now()` (ms 단위) |
| DT-5 | 신뢰도 최소값 | **0.65** (미달 시 경보) |
| DT-6 | 훈련 매핑 신뢰도 | **0.70 이상** 필수 |

---

## 1.9 금지 표현 목록 (Blacklist)

### 절대 사용 금지

| 카테고리 | 금지 표현 |
|---------|---------|
| **부정** | "틀렸어", "아니야", "왜 몰라", "당연히" |
| **재촉** | "빨리", "서둘러", "아직도?" |
| **비하** | "그것도 몰라?", "쉬운데?", "정신 차려" |
| **비교** | "누구는 더 잘하는데", "다른 애들은..." |
| **벌점** | "x개 더 풀어야 해", "실패했어", "0점" |

### 대체 표현

| 금지 표현 | 대체 표현 |
|---------|---------|
| "틀렸어" | "다시 해보자", "한 번 더!" |
| "왜 모르지?" | "어려우니? 천천히 해" |
| "빨리" | "괜찮아, 천천히 해" |
| "실패했어" | "아깝다! 다시!" |

---

# Part 2: Training Design Guide

## 2.1 훈련 모듈 5대 유형

| 유형 | 목적 | 대상 인지 영역 | 대표 모듈 |
|------|------|-------------|---------|
| **Perception** (지각) | 시각적 수 표상 강화 | 시지각, 공간처리 | T04, T06, T22 |
| **Concept** (개념) | 수 개념의 계층적 이해 | 수개념, 기수성 | T12, T15 |
| **Strategy** (전략) | 연산 전략 습득 | 연산전략, 자동화 | T08, T11, T18, T24 |
| **Drill** (자동화) | 반사적 처리 훈련 | 자동화, 작업기억 | T27 |
| **Intervention** (긴급 개입) | 즉시 개입 | 주의력, 작업기억 | T30, T19 |

---

## 2.2 MVP Phase 1 핵심 모듈 상세 설계

### T12: 10짝찾기

```yaml
training_id: T12
name: 10짝찾기
type: Concept
target_concept: C5
target_concepts_array: [C5a, C5b]
target_error_tags:
  - CONCEPT_C5_DECOMPOSITION_UNABLE
  - CONCEPT_C5_SUBITIZING_INCOMPLETE
  - MAKE10_STRATEGY_UNAVAILABLE_COUNTING_FALLBACK
  # (+ 5개 추가, 총 8개 오답원인 커버)

content_config:
  pairs:
    - sum: 10
      decompositions: [[1,9], [2,8], [3,7], [4,6], [5,5]]
    - sum: 5
      decompositions: [[1,4], [2,3]]
    - sum: 6
      decompositions: [[1,5], [2,4], [3,3]]
  visual_mode: gold_bar_matching
  progression: increasing_complexity

visual_metaphor:
  primary: gold_bar_decomposition
  colors: [blue, red, gold]
  elements: [gold_bar_of_10, decomposed_units, recomposed_parts]

pass_criterion:
  type: accuracy_or_rt
  accuracy_threshold: 0.85
  min_trials: 5
  rt_threshold_ms: 3000

prerequisites: [T04]
fallback_training_id: T15
repeat_count: 3
difficulty_progression: adaptive
```

**설계 원칙**:
- 10의 보수 짝을 시각적으로 매칭하는 게임
- 금색 막대(10)를 두 조각으로 쪼개거나 합치는 인터랙션
- 숫자 조합의 다양성을 점진적으로 증가

**피드백 예시**:
- 정답: "좋아! 딱 맞아!"
- 오답: "괜찮아. 합이 10이야. 다시 해볼까?"
- 무응답: "괜찮아. 이거 봐. 어느 게 짝일까?"

---

### T15: 짝꿍수 암기

```yaml
training_id: T15
name: 짝꿍수 암기
type: Concept
target_concept: C5
target_error_tags:
  - CONCEPT_C5_COMPLEMENT_UNKNOWN
  # (+ 5개, 총 6개)

content_config:
  target_sums: [5, 10]
  mode: flash_card_with_visual
  time_limit_per_card_ms: 5000
  visual_aid: block_pair

pass_criterion:
  type: accuracy_and_rt
  accuracy_threshold: 0.90
  min_trials: 10
  rt_threshold_ms: 2000

prerequisites: []
fallback_training_id: T04
```

---

### T04: 순간포착 1~5

```yaml
training_id: T04
name: 순간포착 1~5
type: Perception
target_concept: C1
target_error_tags:
  - VISUAL_L1_NUMBER_SHAPE
  - CONCEPT_L1_CARDINALITY
  # (+ 3개, 총 5개)

content_config:
  display_duration_ms: 1500  # 1.5초 노출 후 사라짐
  quantity_range: [1, 5]
  visual_mode: dot_array
  arrangement: random  # 규칙적 배열 금지 (subitizing 훈련)

pass_criterion:
  type: accuracy
  accuracy_threshold: 0.80
  min_trials: 10

prerequisites: []
```

---

### T22: 10격자 채우기

```yaml
training_id: T22
name: 10격자채우기
type: Concept
target_concept: C4
target_error_tags:
  - SPATIAL_L4_PLACE_VALUE
  - CONCEPT_L4_TENS_STRUCTURE
  # (+ 2개, 총 4개)

content_config:
  grid_size: 10  # 2x5 격자
  fill_mode: drag_and_drop
  visual_elements: [blue_block, gold_bar_transform]
  highlight_on_complete: true  # 10개 채우면 금색으로 변환

pass_criterion:
  type: accuracy_or_rt
  accuracy_threshold: 0.85
  min_trials: 5
  rt_threshold_ms: 4000

prerequisites: [T04]
```

---

### T08: 수직선 점프

```yaml
training_id: T08
name: 수직선점프
type: Strategy
target_concept: C3
target_error_tags:
  - CONCEPT_L3_NUMBER_SENSE
  - STRATEGY_S3_BENCHMARK_UNAVAILABLE
  # (+ 2개, 총 4개)

content_config:
  number_line_range: [0, 20]
  jump_types: [+1, +2, +5, +10]
  visual_mode: animated_frog_jump
  landmarks: [0, 5, 10, 15, 20]

pass_criterion:
  type: accuracy
  accuracy_threshold: 0.85
  min_trials: 8

prerequisites: [T06]
```

---

### T18: 자릿값 분해

```yaml
training_id: T18
name: 자릿값분해
type: Concept
target_concept: C4
target_error_tags:
  - SPATIAL_L4_PLACE_VALUE
  - STRATEGY_L4_PLACEVALUE
  # (+ 1개, 총 3개)

content_config:
  target_numbers_range: [11, 99]
  visual_mode: place_value_grid
  grid_size: 10
  color_tens: gold_bar
  color_ones: blue_block
  interaction: drag_split  # 숫자를 십/일의 자리로 분리

pass_criterion:
  type: accuracy
  accuracy_threshold: 0.85
  min_trials: 8

prerequisites: [T22]
```

---

### T11: 더하기 카운터

```yaml
training_id: T11
name: 더하기카운터
type: Strategy
target_concept: C2
target_error_tags:
  - STRATEGY_S2_MIN_UNAVAILABLE
  - FACT_FLUENCY_L1_SLOW
  # (+ 1개, 총 3개)

content_config:
  mode: counting_up_from_larger
  range: [1, 9]
  visual_aid: number_path_highlight
  audio_feedback: true

pass_criterion:
  type: accuracy_and_rt
  accuracy_threshold: 0.80
  min_trials: 10
  rt_threshold_ms: 5000

prerequisites: [T06]
```

---

### T24: 보정 화살표

```yaml
training_id: T24
name: 보정화살표
type: Strategy
target_concept: C4
target_error_tags:
  - STRATEGY_L4_CARRY_MISSING
  - STRATEGY_L4_BORROW_MISSING
  # (+ 1개, 총 3개)

content_config:
  mode: carry_borrow_visualization
  visual_elements: [arrow_up, arrow_down, place_value_columns]
  animation: step_by_step_carry

pass_criterion:
  type: accuracy
  accuracy_threshold: 0.85
  min_trials: 8

prerequisites: [T18, T22]
```

---

### T06: 크기 비교

```yaml
training_id: T06
name: 크기비교
type: Perception
target_concept: C2
target_error_tags:
  - CONCEPT_L2_MAGNITUDE
  # (+ 1개, 총 2개)

content_config:
  comparison_mode: visual_balance
  range: [1, 20]
  visual_metaphor: seesaw  # 시소
  response_type: tap_larger

pass_criterion:
  type: accuracy
  accuracy_threshold: 0.90
  min_trials: 10

prerequisites: [T04]
```

---

### T27: 배수 패턴

```yaml
training_id: T27
name: 배수패턴
type: Drill
target_concept: C4
target_error_tags:
  - STRATEGY_L4_PATTERN_UNRECOGNIZED
  # (+ 1개, 총 2개)

content_config:
  patterns: [+2, +5, +10]
  mode: pattern_completion
  visual_mode: animated_sequence
  time_pressure: moderate

pass_criterion:
  type: accuracy_and_rt
  accuracy_threshold: 0.85
  min_trials: 10
  rt_threshold_ms: 3000

prerequisites: [T08]
```

---

### T30: 주의력 환기 (긴급 개입)

```yaml
training_id: T30
name: 주의력환기
type: Intervention
target_concept: null  # 개념 교정이 아닌 상태 조절
trigger: ATTENTION_L0_IMPULSE  # RT < 1초 + 오답
always_available: true  # 선행 훈련 없이 언제든 활성화

content_config:
  mode: attention_reset
  activities:
    - deep_breathing_animation  # 숨쉬기 애니메이션
    - color_matching_game  # 간단한 색깔 맞추기
    - rhythm_tap  # 리듬 따라 탭하기
  duration_seconds: 30

feedback_override:
  tone: ultra_gentle
  template: "쉬어가자. 천천히. 준비되면 눌러."
```

---

### T19: 단계별 힌트 표시 (긴급 개입)

```yaml
training_id: T19
name: 단계별힌트표시
type: Intervention
target_concept: null
trigger: MEMORY_L4_OVERWHELM  # 인지 부하 과다 감지
always_available: true

content_config:
  mode: scaffolded_hint
  hint_levels:
    - level_1: visual_cue  # 시각적 단서만
    - level_2: partial_solution  # 중간 단계 보여주기
    - level_3: guided_step  # 한 단계씩 안내
  max_hints_per_problem: 3

feedback_override:
  tone: encouraging
  template: "하나씩 하자. 여기 봐."
```

---

## 2.3 시각 메타포 통합 체계

모든 훈련 모듈은 **기찻길 + 블록** 통합 메타포를 사용합니다:

| 단계 | C/S 지표 | 메타포 | AI 발문 예시 |
|------|---------|--------|------------|
| 1. 기초 | C1/S1 | 기찻길 낱개 블록 | "블록을 하나씩 놓아볼까? 모두 몇 개니?" |
| 2. 비교 | C2/S2 | 기차 길이 비교 | "어떤 기차가 더 길지? 큰 기차 뒤에 연결해!" |
| 3. 기준 | C3/S3 | 5번 정거장 + 색상 변화 | "5번 정거장을 지나서 몇 칸 더 가야 해?" |
| 4. 단위 | C4/S4 | 황금 기차 변신 | "10개가 모여서 황금 기차가 됐어!" |
| 5. 연산 | C5/S5 | 5-10 채우기 작전 | "10번 역까지 한 칸 남았네! 빌려올까?" |
| 6. 검토 | C6/S6 | 기차 후진 | "기차를 거꾸로 돌려보자. 처음으로 돌아왔니?" |

### 메타포 적용 규칙

1. **동일 훈련 내 단일 메타포**: 기차와 블록을 번갈아 사용하지 않음
2. **단계별 일관성**: C1 수준 훈련은 항상 '낱개 블록' 메타포
3. **점진적 추상화**: 구체물(블록) → 반추상(기찻길) → 추상(숫자)
4. **색상 일관성**: 파란색=낱개, 금색=10묶음, 빨간색=조합용

---

## 2.4 피드백 템플릿

### 4가지 상황별 응답 구조

| 상황 | 구성 | 예시 |
|------|------|------|
| **정답** | 칭찬(1) + 확인(1) | "좋아! 정답이야! 다음 가자!" |
| **오답** | 공감(1) + 힌트(1) + 재도전(1) | "괜찮아. 하나만 더! 다시 해볼까?" |
| **실수** (과정은 좋았으나) | 칭찬(1) + 포인트힌트(1) + 재시도(1) | "거의 다 왔어! 자리만 봐! 한 번 더!" |
| **무응답** | 안심(1) + 작은단계(1) + 선택지(1) | "괜찮아. 하나씩 하자. 어느 게 맞아?" |

### 힌트 작성 규칙

1. **1개만 제시** (절대)
2. **정답 직접 노출 금지** (최후의 수단만 허용)
3. **아이가 할 수 있는 행동으로 표현**: "손가락 써봐", "하나 더해봐", "2부터 세봐"
4. **문장 유형**: 명령형 또는 질문형만 허용

---

# Part 3: Agent Prompt Spec

## 3.1 에이전트 역할 정의

훈련 컨텐츠 생성에는 다음 3가지 에이전트가 필요합니다:

### Agent 1: Content Designer (컨텐츠 설계자)

```yaml
role: content_designer
responsibility: 훈련 모듈의 컨텐츠 구조, 인터랙션, 시각 요소 설계
input:
  - training_id
  - target_error_tags
  - target_concept
  - L_level_range
  - C_level_range
output:
  format: JSON + Markdown
  files:
    - content/{training_id}/config.json    # 기술적 설정
    - content/{training_id}/design.md      # 설계 문서
    - content/{training_id}/screens.json   # 화면별 구성
```

**시스템 프롬프트 핵심**:
```
당신은 난산증 아동을 위한 수학 훈련 컨텐츠 설계자입니다.

절대 규칙:
1. 모든 설계는 C-S-E 인지 모델에 기반해야 합니다.
2. training_id에 매핑된 error_tag의 인지 영역만 교정합니다.
3. 시각 메타포는 기찻길+블록 체계를 따릅니다.
4. 화면당 최대 5개 항목, 텍스트 50자 이하.
5. 추상적 기호만 사용하지 마세요. 반드시 시각화를 병행합니다.

입력으로 받는 것:
- training_id: 설계할 훈련 모듈 ID
- target_error_tags: 교정 대상 오답원인 목록
- target_concept: 타겟 개념 태그 (C1~C6)
- L_level_range: 아동 역량 범위
- C_level_range: 문항 복잡도 범위

출력해야 하는 것:
1. config.json: content_config, pass_criterion, prerequisites, visual_metaphor
2. design.md: 설계 의도, 인터랙션 흐름, 난이도 진행
3. screens.json: 화면별 레이아웃, 요소, 전환 조건
```

### Agent 2: Feedback Writer (피드백 작성자)

```yaml
role: feedback_writer
responsibility: 훈련 중 아동에게 제공할 피드백 텍스트 생성
input:
  - training_id
  - situation_type: [correct, incorrect, partial, no_response]
  - error_context: 오답 유형 정보
output:
  format: JSON
  files:
    - content/{training_id}/feedback.json
```

**시스템 프롬프트 핵심**:
```
당신은 난산증 아동을 위한 따뜻한 튜터입니다.

절대 규칙:
1. 반말만 사용합니다.
2. 최대 3문장, 문장당 10자 이내.
3. 힌트는 1개만.
4. 금지 표현: "틀렸어", "아니야", "왜 몰라", "빨리", "그것도 몰라?"
5. 정답을 직접 말하지 마세요.

상황별 구조:
- 정답: 칭찬 + 확인
- 오답: 공감 + 힌트 + 재도전
- 실수: 칭찬 + 포인트 + 재시도
- 무응답: 안심 + 작은단계 + 선택지

출력 형식:
{
  "situation": "correct|incorrect|partial|no_response",
  "messages": ["문장1", "문장2", "문장3"],
  "hint": "힌트 텍스트 (nullable)",
  "tone": "encouraging|gentle|celebrating"
}
```

### Agent 3: Rule Validator (룰 검증자)

```yaml
role: rule_validator
responsibility: 생성된 컨텐츠가 룰북의 모든 제약을 준수하는지 검증
input:
  - content_config (Agent 1 출력)
  - feedback_set (Agent 2 출력)
  - training_module_spec (룰북 참조)
output:
  format: JSON
  files:
    - validation/{training_id}/report.json
```

**시스템 프롬프트 핵심**:
```
당신은 Maththera 훈련 컨텐츠의 품질 검증자입니다.

검증 항목:

[인지 제약 검증]
□ IC-1: 컨텐츠가 target_concept 외 개념을 교정하려 하지 않는가?
□ IC-2: 선행 개념 계층이 존중되는가? (C1→C2→...→C6)
□ IC-3: prerequisites 충족 여부가 확인되는가?
□ IC-4: 기초 문항에서 하위 태그만 스캔되는가?

[난이도 제약 검증]
□ DC-1: L-level 범위가 ±1 이내인가?
□ DC-2: C-level 점프가 없는가?
□ DC-3: Carry/Borrow 도입 비율이 30% 이하인가?

[콘텐츠 설계 제약 검증]
□ CC-1: 화면당 항목 ≤ 5개?
□ CC-2: 텍스트 ≤ 50자?
□ CC-3: 선택지 ≤ 4개?
□ CC-4: 메타포 혼용 없음?
□ CC-5: 시각화 병행됨?

[피드백 제약 검증]
□ FC-1: 문장 ≤ 3개?
□ FC-2: 문장당 ≤ 10자?
□ FC-3: 힌트 ≤ 1개?
□ FC-4: 반말 사용?
□ FC-5: 금지 표현 미포함?

[통과 기준 검증]
□ PC-1: accuracy_threshold ≥ 0.85?
□ PC-2: min_trials ≥ 5?
□ PC-3: rt_threshold_ms 설정됨?
□ PC-4: fallback_module 지정됨?

[데이터 무결성 검증]
□ DT-1~6: 수집 기준 충족?

출력:
{
  "training_id": "T12",
  "validation_result": "PASS|FAIL",
  "checks": [
    {"id": "IC-1", "result": "PASS|FAIL", "detail": "..."},
    ...
  ],
  "total_checks": 20,
  "passed": 20,
  "failed": 0,
  "warnings": []
}
```

---

## 3.2 에이전트 실행 패턴

### Wave 1: 병렬 생성

```
[Content Designer] ──→ config.json, design.md, screens.json
[Feedback Writer]  ──→ feedback.json
```

### Wave 2: 검증

```
[Rule Validator] ←── Wave 1 출력물 전체
                 ──→ validation/report.json
```

### Wave 3: 수정 (검증 실패 시)

```
[Content Designer] ←── report.json (FAIL 항목)
[Feedback Writer]  ←── report.json (FAIL 항목)
                   ──→ 수정된 출력물
                   ──→ [Rule Validator] 재검증
```

---

## 3.3 에이전트 입출력 계약 (JSON Schema)

### Content Config Schema

```json
{
  "$schema": "content_config_v1",
  "required": [
    "training_id",
    "name",
    "type",
    "target_concept",
    "target_error_tags",
    "content_config",
    "visual_metaphor",
    "pass_criterion",
    "prerequisites"
  ],
  "properties": {
    "training_id": { "type": "string", "pattern": "^T\\d{2}$" },
    "name": { "type": "string", "maxLength": 20 },
    "type": { "enum": ["Perception", "Concept", "Strategy", "Drill", "Intervention"] },
    "target_concept": { "enum": ["C1", "C2", "C3", "C4", "C5", "C5a", "C5b", "C6", null] },
    "target_error_tags": { "type": "array", "items": { "type": "string" }, "minItems": 1 },
    "content_config": { "type": "object" },
    "visual_metaphor": {
      "type": "object",
      "properties": {
        "primary": { "type": "string" },
        "colors": { "type": "array", "items": { "type": "string" } },
        "elements": { "type": "array", "items": { "type": "string" } }
      }
    },
    "pass_criterion": {
      "type": "object",
      "properties": {
        "type": { "enum": ["accuracy", "rt", "accuracy_or_rt", "accuracy_and_rt"] },
        "accuracy_threshold": { "type": "number", "minimum": 0.80, "maximum": 1.0 },
        "min_trials": { "type": "integer", "minimum": 5 },
        "rt_threshold_ms": { "type": "integer", "minimum": 1000 }
      }
    },
    "prerequisites": { "type": "array", "items": { "type": "string" } },
    "fallback_training_id": { "type": "string" },
    "repeat_count": { "type": "integer", "minimum": 1 },
    "difficulty_progression": { "enum": ["fixed", "adaptive", "linear"] }
  }
}
```

### Feedback Schema

```json
{
  "$schema": "feedback_v1",
  "required": ["training_id", "feedback_set"],
  "properties": {
    "training_id": { "type": "string" },
    "feedback_set": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["situation", "messages", "tone"],
        "properties": {
          "situation": { "enum": ["correct", "incorrect", "partial", "no_response"] },
          "messages": {
            "type": "array",
            "maxItems": 3,
            "items": { "type": "string", "maxLength": 15 }
          },
          "hint": { "type": ["string", "null"], "maxLength": 15 },
          "tone": { "enum": ["encouraging", "gentle", "celebrating", "ultra_gentle"] }
        }
      }
    }
  }
}
```

### Validation Report Schema

```json
{
  "$schema": "validation_report_v1",
  "required": ["training_id", "validation_result", "checks"],
  "properties": {
    "training_id": { "type": "string" },
    "validation_result": { "enum": ["PASS", "FAIL"] },
    "checks": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["id", "result"],
        "properties": {
          "id": { "type": "string" },
          "result": { "enum": ["PASS", "FAIL", "WARN"] },
          "detail": { "type": "string" }
        }
      }
    },
    "total_checks": { "type": "integer" },
    "passed": { "type": "integer" },
    "failed": { "type": "integer" },
    "warnings": { "type": "array", "items": { "type": "string" } }
  }
}
```

---

## 3.4 CI 검증 자동화 체크리스트

에이전트가 생성한 컨텐츠를 자동 검증하기 위한 체크 항목:

```yaml
integrity_checks:
  # 구조적 무결성
  - error_tag_uniqueness: "85개 모두 고유한가?"
  - category_membership: "7개 카테고리에 중복 배치 없는가?"
  - training_mapping_completeness: "모든 error_tag가 training_id에 매핑되었는가?"
  - prerequisite_validity: "모든 prerequisite이 유효한 training_id인가?"
  - circular_dependency_check: "선행 훈련 간 순환 구조 없는가?"
  - level_range_validity: "L_level과 C_level 범위가 유효한가?"

  # 컨텐츠 제약
  - screen_item_limit: "화면당 5개 이하인가?"
  - text_length_limit: "텍스트 50자 이하인가?"
  - choice_count_limit: "선택지 4개 이하인가?"
  - metaphor_consistency: "같은 훈련 내 단일 메타포인가?"

  # 피드백 제약
  - sentence_count: "3문장 이내인가?"
  - sentence_length: "문장당 10자 이내인가?"
  - hint_count: "힌트 1개 이하인가?"
  - blacklist_check: "금지 표현 미포함인가?"
  - honorific_check: "존댓말 미사용인가?"

  # 통과 기준
  - accuracy_threshold: "0.85 이상인가?"
  - min_trials: "5회 이상인가?"
  - fallback_defined: "fallback 모듈이 지정되었는가?"
```

---

# Appendix

## A. 유스케이스 시나리오

### UC1: 전략 미숙 (정답이지만 비효율적)

| 단계 | 내용 |
|------|------|
| 문제 | 8+6=14 (정답) |
| 관찰 | RT: 12초(느림), 행동: 하나씩 세기(OBS_OVERRELIANCE_COUNTING) |
| 진단 | STR_MAKE10 요구 ≠ OBS_COUNTING 실행 → 전략 불일치 |
| error_tag | MAKE10_STRATEGY_UNAVAILABLE_COUNTING_FALLBACK |
| 훈련 | T12(10짝찾기) → T17(10만들어더하기) |

### UC2: 자릿값 혼동

| 단계 | 내용 |
|------|------|
| 문제 | 23+4=? (정답: 27) |
| 관찰 | 오답: 6 (2+4=6, 십의 자리를 낱개로 처리) |
| 진단 | 패턴: 오답값이 "십의자리+일의자리 가수" 부분 계산 결과와 일치 |
| error_tag | SPATIAL_L4_PLACE_VALUE |
| 훈련 | T26(자릿값이해) |

### UC3: 충동적 반응

| 단계 | 내용 |
|------|------|
| 문제 | 18+6=? (정답: 24) |
| 관찰 | RT: 0.8초, 무작위 선택 |
| 진단 | RT < 1초 + 오답 = 충동 의심. L(아동) < C(문제) |
| error_tag | ATTENTION_L0_IMPULSE |
| 훈련 | T30(주의력환기) 즉시 개입 |

### UC4: Probe 기반 변인 통제

| 단계 | 내용 |
|------|------|
| 문제 | 28+15=? (정답: 43), 오답: 33 (정답에서 -10) |
| Probe | 20+15 출제 (받아올림 제거) |
| Case A | Probe도 오답 → SPATIAL_L4_ALIGNMENT → T26 |
| Case B | Probe 정답 → STRATEGY_L4_PLACEVALUE → T27 |

---

## B. 48단계 난이도 매트릭스 (발췌)

| 난이도 | 피연산자 | 결과 | 받아올림 | 수크기 | 예시 |
|--------|---------|------|---------|--------|------|
| 1 | 1자리 | 1자리 | X | Low | 2+1 |
| 2 | 1자리 | 1자리 | X | Mid | 6+2 |
| 3 | 1자리 | 1자리 | X | High | 8+1 |
| 10 | 1자리 | 2자리 | O | Low | 6+4 |
| 15 | 2자리 | 2자리 | O | High | 38+5 |
| 33 | 2자리 | 3자리 | O (연쇄) | High | 89+75 |
| 48 | 2자리 | 3자리 | O (최대) | 최고 | 99+99 |

---

## C. 훈련 모듈 의존 그래프

```
T04 (순간포착) ───→ T12 (10짝찾기) ───→ T17 (10만들어더하기)*
       ↓
T06 (크기비교) ───→ T08 (수직선점프) ───→ T27 (배수패턴)
       ↓
T22 (10격자채우기) ───→ T18 (자릿값분해) ───→ T24 (보정화살표)

T11 (더하기카운터) [T06 선행]
T15 (짝꿍수 암기) [선행 없음]

* T17은 MVP Phase 1 제외, Phase 2에서 구현
```

---

## D. 개념 태그 판단 상태

| 상태 | 판단 요약 | 관찰 지표 |
|------|---------|---------|
| **정상 (Normal)** | 데이터 유효 | 정답, 해당 개념 완벽 인출 |
| **오류 (Distorted)** | 데이터 오염 | 개념 사용 시도하나 결과 고정적 오류 |
| **부분 누락 (Incomplete)** | 데이터 손실 | 중간 단계까지 사용, 마지막 처리 누락 |
| **치명적 오류 (Void)** | 데이터 부재 | 해당 개념 고려 흔적 전무 |

---

## E. MVP Phase 1 마일스톤

| 주차 | 마일스톤 | 훈련 모듈 |
|------|---------|---------|
| W5 | 핵심 수감각 훈련 | T12, T15 |
| W6 | 개념/지각 훈련 | T04, T22, T08 |
| W7 | 전략 훈련 | T18, T11, T24 |
| W8 | 나머지 + 통합 | T06, T27, T30, T19 |
| W9~10 | 파일럿 검증 (n=20) | 전체 |
| W11 | C5a/C5b 분리, C1-Zero 구현 | 매핑 재조정 |
| W12 | 두자리수 확장 | 신규 모듈 수요 평가 |

---

## F. 미검증 영역 및 리스크

| 항목 | 상태 | 필요 액션 | 시기 |
|------|------|---------|------|
| 훈련 모듈 교정 효과 | **미검증** | Pre/Post 비교 실험 | Phase 3 |
| Probe UX 영향 | **부분 검증** | 아동 사용성 테스트 | Phase 2 |
| 보이스 톤 불안 완화 | **미검증** | A/B 테스트 | Phase 2 |
| 시각 메타포 효과 | **미검증** | 프로토타입 테스트 | Phase 1 |
| 뺄셈 전략 태그 완성도 | **진행중** | 도메인 전문가 검토 | Phase 1 |

---

> **이 문서는 Maththera 훈련 컨텐츠 자동 생성의 단일 참조점(Single Source of Truth)입니다.**
> 에이전트는 이 룰북에 정의되지 않은 규칙을 자의적으로 생성하거나 적용해서는 안 됩니다.
