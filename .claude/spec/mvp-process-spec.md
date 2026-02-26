# 이모코그 AI MVP 개발 프로세스 v1.0

Kill Gate 기반 5단계 프로세스. 각 단계는 Gate를 통과해야 다음 단계로 진행됩니다.
시스템 연동: `project.json`의 `mvp_stage` 필드 + `/gate-review` 커맨드.

---

## 프로세스 개요

```
S1 Brief (1W) ─→ [Gate 1] ─→ S2 Pretotype (2W) ─→ [Gate 2 Kill Gate] ─→ S3 Prototype (4W) ─→ [Gate 3] ─→ S4 Freeze (2W) ─→ [Gate 4] ─→ S5 MVP
```

| 단계 | 이름 | 기간 | 핵심 질문 | Kill Gate |
|------|------|------|-----------|-----------|
| S1 | Brief | 1W | "이 문제가 실재하는가?" | 아니오 |
| S2 | Pretotype | 2W | "시장이 이 솔루션에 반응하는가?" | **예** |
| S3 | Prototype | 4W | "핵심 기능이 동작하는가?" | 아니오 |
| S4 | Freeze | 2W | "AI 개발을 시작할 수 있는가?" | 아니오 |
| S5 | MVP | - | "P0 기능이 출시 가능한가?" | 아니오 |

> **Kill Gate(S2)**: 시장 반응이 없으면 S3(프로토타입)으로 진행하지 않습니다. 피봇 또는 중단.

---

## 문서 체계

### 2 Master Doc (전체 과정을 통해 살아있는 문서)

| 문서 | 생성 단계 | 파일명 | 역할 |
|------|-----------|--------|------|
| Product Brief | S1 | `PRODUCT-BRIEF.md` | 시장·사용자·사업성 전략 정의 |
| Product Spec | S3 | `PRODUCT-SPEC.md` | 기능 범위·AC·플로우 명세 |

### 4 Stage/Handoff Doc (단계 전환 시 생성)

| 문서 | 생성 단계 | 파일명 | 역할 |
|------|-----------|--------|------|
| Business Spec | S1 | `BUSINESS-SPEC.md` | 비즈니스 모델·시장 분석 상세화 |
| Pretotype Spec | S2 | `PRETOTYPE-SPEC.md` | XYZ 가설·실험 설계·결과 |
| Design Spec | S4 | `DESIGN-SPEC.md` | UI/UX 화면 레이아웃·상호작용 명세 |
| Tech Spec | S4 | `TECH-SPEC.md` | 기술 아키텍처·AI 구현 가이드 |

### 문서 의존 관계

```
Product Brief ──→ Business Spec  (S1 인풋 → S1 스테이지 상세화)
Business Spec ──→ Pretotype Spec (S1 §6.3 Kill Assumptions → S2 XYZ 가설)
Pretotype Spec ──→ Product Spec  (S2 결과 §5-4 → S3 기능 우선순위)
Product Spec  ──→ Design Spec    (S3 AC·플로우 → S4 화면 명세)
Product Spec  ──→ Tech Spec      (S3 AC → S4 API 명세·기술 스택)
Design Spec + Tech Spec ──→ S5   (AI 개발 인풋)
```

---

## S1 Brief (1주)

### 목표

문제의 실재성과 사업성 방향을 검증합니다. 아직 솔루션을 정의하지 않습니다.

### 핵심 활동

1. 사용자 인터뷰·관찰 최소 5건
2. 시장규모(TAM·SAM) 수치 산출
3. Kill Assumptions(핵심 가정) 3개+ 도출
4. 사업성 경로(PMF 시나리오) 1개+ 정의

### 산출물

| 문서 | 유형 | `document_type` |
|------|------|-----------------|
| Product Brief | master | `product-brief` |
| Business Spec | stage | `business-spec` |

### Gate 1 기준 (`product-brief.gate_criteria`)

- [ ] 시장규모(TAM·SAM) 수치 근거 제시
- [ ] 단위 경제성 초기 검토 (LTV/CAC 방향성)
- [ ] 핵심 가정 3개 이상 명시
- [ ] 문제 실재성 확인 (인터뷰/관찰 최소 5건)
- [ ] 사업성 경로 (PMF 시나리오) 1개 이상

**Gate 1**: Kill Gate 아님. 모든 기준 Go → S2 진행. Stop 시 S1 재작업.

---

## S2 Pretotype (2주)

### 목표

실제 제품 없이 시장 반응을 측정합니다. XYZ 가설을 데이터로 검증합니다.

### 핵심 활동

1. XYZ 가설 도출 (X=고객, Y=행동, Z=결과)
2. Pretotype 기법 선택 (Fake Door / Landing Page / Concierge 등)
3. 90일 내 검증 목표 수치 설정
4. 실험 실행 → 데이터 수집 → Skin in the Game 측정
5. Go/Pivot/Kill 판정

### 산출물

| 문서 | 유형 | `document_type` |
|------|------|-----------------|
| Pretotype Spec | stage | `pretotype-spec` |

Pretotype Spec은 실험 전(§1~§2)과 실험 후(§3~§5) 두 파트로 구성됩니다.

### Gate 2 기준 (`pretotype-spec.gate_criteria`) — **Kill Gate**

- [ ] XYZ 가설 명확히 도출 (X=고객, Y=행동, Z=결과)
- [ ] 90일 내 검증 목표 수치 설정 (결제/가입 N명)
- [ ] Pretotype 실험 방법 구체화 (방법·기간·비용)
- [ ] 실패 기준(Stop Signal) 사전 정의

**Gate 2 (Kill Gate)**:
- **Go**: 시장 반응 확인 (Skin in the Game 30+, NPQ 2개+ 충족) → S3
- **Pivot**: 부분 반응 (방향은 맞으나 수치 미달) → S2 재실험 (1회 허용)
- **Kill**: 수요 없음 → 프로젝트 종료 또는 대폭 피봇 후 S1 재시작

---

## S3 Prototype (4주)

### 목표

핵심 기능(P0)을 시연 가능한 수준으로 구현하고 PM·CEO·CTO 승인을 받습니다.

### 핵심 활동

1. P0 기능 스코프 확정 (Pretotype Spec §5-4 인풋 기반)
2. 핵심 플로우 및 수용 기준(AC) 명세
3. 기술 리스크 식별 및 해소
4. 프로토타입 빌드 → 데모 승인

### 산출물

| 문서 | 유형 | `document_type` |
|------|------|-----------------|
| Product Spec | master | `product-spec` |

### Gate 3 기준 (`product-spec.gate_criteria`)

- [ ] 시연 환경에서 핵심 기능(P0) 동작 확인
- [ ] PM·CEO·CTO 데모 승인
- [ ] §3 플로우·§4 AC 완성
- [ ] 미해결 기술 리스크 없음

**Gate 3**: Kill Gate 아님. 전원 Go → S4 진행.

---

## S4 Freeze (2주)

### 목표

AI가 실제로 개발할 수 있는 수준의 설계 문서를 완성합니다. 이후 스코프 변경 금지(Freeze).

### 핵심 활동

1. 모든 P0 화면 레이아웃 명세 (AI 생성 가능 수준)
2. 기술 스택 확정 및 아키텍처 설계
3. API 명세 — Product Spec AC와 매핑
4. PM·디자이너·엔지니어 3자 합의

### 산출물

| 문서 | 유형 | `document_type` |
|------|------|-----------------|
| Design Spec | handoff | `design-spec` |
| Tech Spec | handoff | `tech-spec` |

### Gate 4 기준 (`design-spec.gate_criteria`)

- [ ] 모든 P0 화면 레이아웃 명세 완성 & AI 생성 가능 수준
- [ ] Tech Spec §1~§8 전 섹션 완성
- [ ] Product Spec AC와 API 명세 매핑 완성
- [ ] Design Spec 기술 스택과 Tech Spec §1 일치
- [ ] PM·디자이너·엔지니어 3자 합의

**Gate 4**: Kill Gate 아님. 전원 Go → S5 진행.

---

## S5 MVP

### 목표

P0 기능을 실제 배포 가능한 수준으로 빌드합니다.

### 핵심 활동

1. Design Spec + Tech Spec 기반 AI 개발
2. P0 기능 전부 작동 확인
3. 치명적 버그(P0 버그) 제거
4. 내부 사용자 테스트

### Gate 5 기준 (고정)

- [ ] P0 기능 전부 작동 확인
- [ ] 치명적 버그 없음 (P0 버그 0개)
- [ ] 내부 사용자 테스트 통과

---

## Kill Gate 논리

### Go/Pivot/Kill 결정 체계

```
[S2 Gate 결과]
  ├─ Skin in the Game 30+ AND NPQ 2개+  →  Go → S3
  ├─ Skin 10 수준 OR NPQ 1개             →  Pivot → S2 재실험 (1회)
  └─ Skin 0 OR NPQ 0                     →  Kill → 프로젝트 종료
```

S2 이외 Gate에서 Stop이 발생하면 재작업 후 해당 Gate 재검토 (Kill은 발생하지 않음).

### project.json 상태 필드

| 필드 | 값 | 의미 |
|------|-----|------|
| `mvp_stage` | `S1`~`S5`, `null` | 현재 단계 |
| `stage_status` | `in_progress` | 단계 진행 중 |
| `stage_status` | `gate_passed` | Gate 통과, 다음 단계 대기 |
| `stage_status` | `gate_stopped` | Gate Stop 결정 |
| `stage_history` | 배열 | 단계별 이력 (결정·타임스탬프·문서 목록) |

---

## 시스템 연동

### `/init-project`

인터뷰 중 MVP 단계 선택 → `project.json`에 `mvp_stage`, `stage_status: "in_progress"` 설정.
선택한 단계에 맞는 `document_type`이 자동 결정됩니다:

| 선택 단계 | 기본 `document_type` |
|-----------|----------------------|
| S1 | `product-brief` (+ `business-spec` 보조) |
| S2 | `pretotype-spec` |
| S3 | `product-spec` |
| S4 | `design-spec` (+ `tech-spec` 보조) |

### `/auto-generate`

현재 `mvp_stage`와 `document_type`에 맞는 템플릿을 `.claude/templates/{output_dir_name}/`에서 로드하여 문서를 생성합니다.

### `/run-research`

Synth 에이전트가 `.claude/templates/{output_dir_name}/[프로젝트명]*.md` 로컬 템플릿의 섹션 구조를 뼈대로 최종 문서를 작성합니다.

### `/gate-review`

`project.json`의 `mvp_stage`와 `document-types.yaml`의 `gate_criteria`를 기반으로 항목별 Go/Stop 판정을 수행합니다.
결정 결과는 `stage_history`에 append되고 `mvp_stage`·`stage_status`가 업데이트됩니다.

---

## 단계 전환 시퀀스

```
사용자: "S2 시작해줘"
  → /init-project (document_type: pretotype-spec, mvp_stage: S2)
  → /auto-generate (Pretotype Spec 생성)
  → 실험 실행 (시스템 외부)
  → /auto-generate (Pretotype Spec §3~§5 결과 반영)
  → /gate-review (S2 Kill Gate 판정)
    ├─ Go  → mvp_stage: S3, /auto-generate (Product Spec)
    ├─ Pivot → S2 재실험 후 /gate-review 재실행
    └─ Kill → stage_status: gate_stopped, 프로젝트 중단 안내
```
