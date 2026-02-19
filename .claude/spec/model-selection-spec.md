# Model Selection Specification

에이전트 팀에서 각 역할에 할당하는 모델 선택 기준을 정의합니다.

---

## 사용 가능한 모델

| 모델 | 특성 | 비용 | 적합한 작업 |
|------|------|------|------------|
| `opus` | 최고 품질. 복잡한 추론, 다중 소스 통합, 미묘한 판단 | 높음 | 교차 소스 종합, 충돌 해결, 최종 문서 작성 |
| `sonnet` | 균형. 빠른 속도와 높은 품질 | 중간 | 단일 도메인 구조화 분석, 증거 기반 추론 |
| `haiku` | 최고 속도. 간단한 작업에 효율적 | 낮음 | 검증, 분류, 형식 변환 |

---

## 선택 기준

| 기준 | 모델 | 예시 |
|------|------|------|
| 여러 역할의 출력을 교차 참조하여 종합 | `opus` | synth (Wave 2) |
| 사전 필터링된 증거 내 단일 도메인 분석 | `sonnet` | Wave 1 에이전트 (biz, marketing, research, tech, pm, 동적 역할) |
| 스키마 검증, 형식 확인, 단순 분류 | `haiku` | (현재 미사용, 향후 verify 자동화 등) |

---

## 기본 모델 매핑

| 역할 | Wave | 기본 모델 | 근거 |
|------|------|----------|------|
| biz, marketing, research, tech, pm | Wave 1 | `sonnet` | 사전 필터링된 증거 내 단일 도메인 구조화 분석 |
| 동적 역할 (dynamic_roles) | Wave 1 | `sonnet` | 기존 Wave 1 에이전트와 동일 |
| synth | Wave 2 | `opus` | 다중 소스 통합, 충돌 해결, 최종 문서 작성 |

---

## 오버라이드 메커니즘

모델은 3단계 우선순위로 결정됩니다 (높은 것이 우선):

### 1. project.json (프로젝트별)

```json
{
  "model_overrides": {
    "wave1": "opus",
    "wave2": "opus",
    "roles": {
      "tech": "opus",
      "research": "haiku"
    }
  }
}
```

- `model_overrides.roles.{role_id}` — 특정 역할의 모델 지정
- `model_overrides.wave1` — Wave 1 전체 기본 모델 변경
- `model_overrides.wave2` — Wave 2 전체 기본 모델 변경

### 2. document-types.yaml (문서 유형별)

```yaml
prd:
  model_overrides:
    wave1: sonnet
    wave2: opus
```

- 문서 유형 정의에 `model_overrides` 필드를 추가하여 유형별 기본 모델 설정

### 3. 기본값 (이 사양서)

- Wave 1: `sonnet`
- Wave 2: `opus`

---

## 모델 결정 알고리즘

```
function resolveModel(role_id, wave):
  # 1. project.json 역할별 오버라이드
  if project.model_overrides.roles[role_id] exists:
    return project.model_overrides.roles[role_id]

  # 2. project.json wave별 오버라이드
  if project.model_overrides[wave] exists:
    return project.model_overrides[wave]

  # 3. document-types.yaml 오버라이드
  if doc_type.model_overrides[wave] exists:
    return doc_type.model_overrides[wave]

  # 4. 기본값
  if wave == "wave1": return "sonnet"
  if wave == "wave2": return "opus"
```

---

## 유효성 검증

- `resolveModel`이 반환하는 값은 반드시 `opus`, `sonnet`, `haiku` 중 하나여야 합니다.
- 유효하지 않은 모델명이 지정되면 해당 wave의 기본값으로 폴백합니다.
- 폴백 시 "모델 '{invalid}' 는 유효하지 않습니다. 기본값 '{default}'를 사용합니다." 로그를 남깁니다.

---

## 구현 제약사항

### Task Tool의 모델 선택 제한

현재 Claude Code의 Task tool은 명시적 모델 지정 파라미터(`model=`)를 지원하지 않습니다.
따라서 이 스펙에서 정의한 `resolveModel()` 결과는:

- **프롬프트 내 권장 모델 안내**로만 활용 가능 (참고사항 수준)
- 실제 에이전트 모델 선택은 Claude Code의 기본 동작을 따름

이 스펙의 오버라이드 체계는 향후 Task tool이 모델 지정을 지원할 때 적용될 수 있도록 정의되었습니다.
