# PRD Generator Template

Google Drive 문서를 기반으로 6역할 에이전트 팀이 PRD, 디자인 사양서, 마케팅 브리프 등 다양한 문서를 자동 생성하는 Claude Code 프로젝트 템플릿.

## Changelog

[전체 변경 이력 보기](CHANGELOG.md)

## 어떤 문제를 해결하는가

기획 문서 작성은 여러 관점(비즈니스, 마케팅, 기술, PM 등)의 분석이 필요하고, 출처 기반의 인용과 구조적 일관성을 유지해야 합니다. 이 템플릿은 Google Drive에 올려둔 참고 자료만 연결하면, 에이전트 팀이 증거 기반으로 문서를 자동 생성합니다.

## 누구를 위한 도구인가

- PRD/기획 문서를 빠르게 초안 작성하고 싶은 PM, 기획자
- 증거 기반 문서를 필요로 하는 팀
- Claude Code 환경에서 문서 자동화 워크플로우를 구축하려는 개발자

---

## 핵심 기능

1. **자동 파이프라인 (`/auto-generate`)** — Drive 동기화 → 에이전트 리서치 → 검증 → 완료 보고를 사용자 개입 없이 자동 실행
2. **멀티 제품 지원 (`/switch-product`)** — 하나의 워크스페이스에서 여러 제품을 `product_id`로 분리 관리, 즉시 전환 가능
3. **범용 문서 유형 (6종)** — PRD, 디자인 사양서, 마케팅 브리프, 사업 계획서, 기술 사양서, 사용자 정의
4. **6역할 에이전트 팀** — biz, marketing, research, tech, pm, synth가 병렬/순차로 협업
5. **GitHub Issue 자동 생성 (`/create-issue`)** — 사용자 피드백을 즉시 Issue로 기록
6. **사용자 아이덴티티** — `.user-identity`로 작성자 추적, PR/Issue에 자동 반영
7. **브랜치 워크플로우** — main 기반 작업 + feature 브랜치 PR 생성 후 자동 복귀
8. **PR/Issue 템플릿** — `.claude/templates/`의 표준 템플릿으로 일관된 형식 보장
9. **프로젝트 공유 (`/share-project`)** — 생성된 문서와 메타데이터를 PR로 팀에 공유
10. **Drive 업로드 (`/upload-drive`)** — 생성된 문서를 Google Drive에 HTML 서식 유지하여 업로드
11. **관리자 모드 (`/admin`)** — 템플릿 maintainer 전용. 요구사항 → 플랜 → 구현 → 검증 → PR 자동 생성
12. **자동 마이그레이션** — 템플릿 업데이트 시 세션 시작 시 자동으로 스키마 마이그레이션 실행
13. **Worktree 기반 브랜치 격리** — 여러 세션이 동시 작업해도 브랜치 충돌 없음
14. **MVP Kill Gate 검토 (`/gate-review`)** — S1~S5 단계별 완료 기준을 항목별로 검토하고 Go/Pivot/Kill 결정을 기록

---

## 작동 방식

### 파이프라인 흐름

```
사용자: "자동으로 만들어줘"
         │
         ▼
┌─────────────────────┐
│Phase 1: sync-drive  │  Google Drive 문서 → 증거 청크 변환
└─────────┬───────────┘
          ▼
┌─────────────────────┐
│Phase 2: run-research│  회의(병렬 토론) → 판정 → 비평 → 통합
└─────────┬───────────┘
          ▼
┌─────────────────────┐
│Phase 3: verify      │  구조/스키마/인용/완전성 검증
└─────────┬───────────┘
          ▼
┌─────────────────────┐
│Phase 4: 완료 보고     │  문서 요약 + /upload-drive 제안
└─────────────────────┘
```

### 문서 유형별 에이전트 매핑

| 문서 유형 | biz | marketing | research | tech | pm | judge | critique | synth |
|----------|:---:|:---------:|:--------:|:----:|:--:|:-----:|:--------:|:-----:|
| 제품 요구사항 문서 (prd) | O | O | O | O | O | O | O | O |
| 디자인 사양서 (design-spec) | - | - | O | O | O | O | O | O |
| 마케팅 브리프 (marketing-brief) | O | O | O | - | - | O | O | O |
| 사업 계획서 (business-plan) | O | O | O | O | - | O | O | O |
| 기술 사양서 (tech-spec) | - | - | O | O | O | O | O | O |
| 사용자 정의 (custom) | 선택 | 선택 | 선택 | 선택 | 선택 | O | O | O |

> **모델 선택**: 회의(Discussion) 에이전트는 `sonnet`, 판정/비평/통합은 `opus`가 기본값입니다. 문서 유형별/프로젝트별 오버라이드가 가능합니다. 상세: `.claude/spec/model-selection-spec.md`

---

## MVP 프로세스 (Kill Gate 기반)

이 템플릿은 단순 문서 생성 외에 **5단계 Kill Gate 기반 MVP 개발 프로세스**를 지원합니다.
각 단계는 Gate를 통과해야 다음 단계로 진행되며, `/gate-review`로 Go/Pivot/Kill을 결정합니다.

### 단계 흐름

```
S1 Brief (1W) → [Gate 1] → S2 Pretotype (2W) → [Gate 2 Kill Gate] → S3 Prototype (4W) → [Gate 3] → S4 Freeze (2W) → [Gate 4] → S5 MVP
```

| 단계 | 이름 | 기간 | 핵심 질문 | Kill Gate |
|------|------|------|-----------|:---------:|
| S1 | Brief | 1W | "이 문제가 실재하는가?" | - |
| S2 | Pretotype | 2W | "시장이 이 솔루션에 반응하는가?" | **예** |
| S3 | Prototype | 4W | "핵심 기능이 동작하는가?" | - |
| S4 | Freeze | 2W | "AI 개발을 시작할 수 있는가?" | - |
| S5 | MVP | - | "P0 기능이 출시 가능한가?" | - |

> **Kill Gate(S2)**: 시장 반응이 없으면 S3(프로토타입)으로 진행하지 않습니다. Skin in the Game 30+ 미달 시 Pivot 또는 Kill.

### 단계별 산출 문서

| 단계 | 산출 문서 | `document_type` | 유형 |
|------|-----------|-----------------|------|
| S1 | Product Brief | `product-brief` | Master Doc (이후 단계에서도 유지) |
| S1 | Business Spec | `business-spec` | Stage Doc |
| S2 | Pretotype Spec | `pretotype-spec` | Stage Doc |
| S3 | Product Spec | `product-spec` | Master Doc (이후 단계에서도 유지) |
| S4 | Design Spec | `design-spec` | Handoff Doc |
| S4 | Tech Spec | `tech-spec` | Handoff Doc |

### Kill Gate 워크플로우

```
/init-project (단계 선택)
     → /auto-generate (해당 단계 문서 생성)
     → /gate-review (Go/Stop 항목별 판정)
           ├─ Go   → mvp_stage 자동 업데이트 → 다음 단계 /auto-generate
           ├─ Pivot → 현재 단계 재작업 후 /gate-review 재실행 (S2 전용)
           └─ Kill  → 프로젝트 중단 기록
```

상세: `.claude/spec/mvp-process-spec.md`

---

## 빠른 시작

### 1. 환경 설정 (포크/다른 조직 배포 시)

`env.yml`을 열어 조직에 맞게 수정합니다. **이 파일 하나만 변경하면 전체 프로젝트에 반영됩니다.**

```yaml
github:
  owner: boydcog                       # GitHub 사용자명 또는 조직명
  repo: prd-generator-template         # 저장소 이름
  default_reviewers: boydcog            # PR 리뷰어 (쉼표 구분)
  default_assignees: boydcog            # Issue/PR 담당자 (쉼표 구분)

contact:
  name: Boyd                           # 토큰 요청 연락처
  channel: 슬랙                        # 연락 채널
```

### 2. GitHub 토큰 설정

프로젝트 루트에 `.gh-token` 파일을 생성합니다 (gitignored). 관리자에게 요청하세요 (연락처: `env.yml`의 `contact` 참조).

### 3. 사용자 아이덴티티 설정

첫 실행 시 자동으로 이름을 물어봅니다. 수동 설정:

```bash
echo "홍길동" > .user-identity
```

### 4. 실행

Claude Code 세션을 시작하면 SessionStart hook이 상태를 자동 감지합니다.

- 초기 설정이 필요하면 → `/init-project` 자동 실행
- 모든 설정이 완료되었으면 → "자동으로 만들어줘" 입력

---

## 파일 구조

> 상세 구조는 `CLAUDE.md`의 "파일 구조" 섹션을 참조하세요.

```
.
├── CLAUDE.md                    ← 프로젝트 규칙 (Single Source of Truth)
├── CHANGELOG.md                 ← 변경 이력 (날짜별 관리)
├── README.md                    ← 이 파일 (프로젝트 context 문서)
├── env.yml                      ← 환경 설정 (조직/배포별 변수)
├── .gh-token                    ← GitHub 토큰 (gitignored)
├── .user-identity               ← 사용자 이름 (gitignored)
├── .claude/
│   ├── commands/                ← 슬래시 명령어 (10개, switch-product 포함)
│   ├── migrations/              ← 스키마 마이그레이션 지침 (tracked)
│   ├── templates/               ← PR/Issue 템플릿
│   ├── manifests/               ← 설정 (drive-sources-{product_id}.yaml, admins 등)
│   ├── spec/                    ← 사양서 (agent-team, document-types 등)
│   ├── hooks/                   ← SessionStart hook (migration 감지 포함)
│   ├── state/                   ← 상태 (generated, gitignored)
│   │   ├── _active_product.txt  ← 현재 활성 제품 포인터
│   │   ├── _schema_version.txt  ← 현재 적용된 스키마 버전
│   │   └── {product_id}/        ← 제품별 상태
│   ├── knowledge/               ← 증거 (generated, gitignored)
│   │   └── {product_id}/        ← 제품별 증거 데이터
│   └── artifacts/               ← 출력물 (generated, gitignored)
│       └── {product_id}/        ← 제품별 출력물
```

## 지원 문서 유형

| 유형 ID | 이름 | 설명 | 출력 파일 |
|---------|------|------|----------|
| `prd` | 제품 요구사항 문서 | 제품 기획을 위한 종합 요구사항 문서 | `PRD.md` |
| `design-spec` | 디자인 사양서 | UI/UX 디자인 상세 사양 및 가이드라인 | `DESIGN-SPEC.md` |
| `marketing-brief` | 마케팅 브리프 | 마케팅 전략 및 캠페인 기획 문서 | `MARKETING-BRIEF.md` |
| `business-plan` | 사업 계획서 | 사업 타당성 및 실행 계획 문서 | `BUSINESS-PLAN.md` |
| `tech-spec` | 기술 사양서 | 기술 아키텍처 및 구현 상세 문서 | `TECH-SPEC.md` |
| `custom` | 사용자 정의 | 사용자가 에이전트와 섹션을 직접 정의 | `DOCUMENT.md` |

