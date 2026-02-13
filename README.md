# PRD Generator Template

Google Drive 문서를 기반으로 6역할 에이전트 팀이 PRD, 디자인 사양서, 마케팅 브리프 등 다양한 문서를 자동 생성하는 Claude Code 프로젝트 템플릿.

## 어떤 문제를 해결하는가

기획 문서 작성은 여러 관점(비즈니스, 마케팅, 기술, PM 등)의 분석이 필요하고, 출처 기반의 인용과 구조적 일관성을 유지해야 합니다. 이 템플릿은 Google Drive에 올려둔 참고 자료만 연결하면, 에이전트 팀이 증거 기반으로 문서를 자동 생성합니다.

## 누구를 위한 도구인가

- PRD/기획 문서를 빠르게 초안 작성하고 싶은 PM, 기획자
- 증거 기반 문서를 필요로 하는 팀
- Claude Code 환경에서 문서 자동화 워크플로우를 구축하려는 개발자

---

## 핵심 기능

1. **자동 파이프라인 (`/auto-generate`)** — Drive 동기화 → 에이전트 리서치 → 검증 → 완료 보고를 사용자 개입 없이 자동 실행
2. **범용 문서 유형 (6종)** — PRD, 디자인 사양서, 마케팅 브리프, 사업 계획서, 기술 사양서, 사용자 정의
3. **6역할 에이전트 팀** — biz, marketing, research, tech, pm, synth가 병렬/순차로 협업
4. **GitHub Issue 자동 생성 (`/create-issue`)** — 사용자 피드백을 즉시 Issue로 기록
5. **사용자 아이덴티티** — `.user-identity`로 작성자 추적, PR/Issue에 자동 반영
6. **브랜치 워크플로우** — main 기반 작업 + feature 브랜치 PR 생성 후 자동 복귀
7. **PR/Issue 템플릿** — `.claude/templates/`의 표준 템플릿으로 일관된 형식 보장
8. **프로젝트 공유 (`/share-project`)** — 생성된 문서와 메타데이터를 PR로 팀에 공유

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
│Phase 2: run-research│  Wave 1 (병렬) → Wave 2 (통합)
└─────────┬───────────┘
          ▼
┌─────────────────────┐
│Phase 3: verify      │  구조/스키마/인용/완전성 검증
└─────────┬───────────┘
          ▼
┌─────────────────────┐
│Phase 4: 완료 보고     │  문서 요약 + Drive 업로드 제안
└─────────────────────┘
```

### 문서 유형별 에이전트 매핑

| 문서 유형 | biz | marketing | research | tech | pm | synth |
|----------|:---:|:---------:|:--------:|:----:|:--:|:-----:|
| 제품 요구사항 문서 (prd) | O | O | O | O | O | O |
| 디자인 사양서 (design-spec) | - | - | O | O | O | O |
| 마케팅 브리프 (marketing-brief) | O | O | O | - | - | O |
| 사업 계획서 (business-plan) | O | O | O | O | - | O |
| 기술 사양서 (tech-spec) | - | - | O | O | O | O |
| 사용자 정의 (custom) | 선택 | 선택 | 선택 | 선택 | 선택 | O |

---

## 빠른 시작

### 1. GitHub 토큰 설정

프로젝트 루트에 `.gh-token` 파일을 생성합니다 (gitignored). Boyd에게 슬랙으로 요청하세요.

### 2. 사용자 아이덴티티 설정

첫 실행 시 자동으로 이름을 물어봅니다. 수동 설정:

```bash
echo "홍길동" > .user-identity
```

### 3. 실행

Claude Code 세션을 시작하면 SessionStart hook이 상태를 자동 감지합니다.

- 초기 설정이 필요하면 → `/init-project` 자동 실행
- 모든 설정이 완료되었으면 → "자동으로 만들어줘" 입력

---

## 파일 구조

> 상세 구조는 `CLAUDE.md`의 "파일 구조" 섹션을 참조하세요.

```
.
├── CLAUDE.md                    ← 프로젝트 규칙 (Single Source of Truth)
├── README.md                    ← 이 파일 (프로젝트 context 문서)
├── .gh-token                    ← GitHub 토큰 (gitignored)
├── .user-identity               ← 사용자 이름 (gitignored)
├── .claude/
│   ├── commands/                ← 슬래시 명령어 (7개)
│   ├── templates/               ← PR/Issue 템플릿
│   ├── manifests/               ← 설정 (drive-sources, project-defaults)
│   ├── spec/                    ← 사양서 (agent-team, document-types 등)
│   ├── hooks/                   ← SessionStart hook
│   ├── state/                   ← 상태 (generated, gitignored)
│   ├── knowledge/               ← 증거 (generated, gitignored)
│   └── artifacts/               ← 출력물 (generated, gitignored)
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

---

## Changelog

<details>
<summary>v0.1.1 — 프로젝트 공유 명령 추가 (2026-02-13)</summary>

- `/share-project` 명령 추가 — 프로젝트 결과물(문서, 메타데이터)을 PR로 팀에 공유
- `project/{name}` 브랜치에 gitignore된 artifacts를 강제 추가하여 PR 생성
- 민감 정보(`.gh-token`) 및 대용량 청크 자동 제외
- PR 본문에 프로젝트 요약, 포함 파일, 관련 이슈 자동 포함
- "공유해줘" / "PR 올려줘" 등 자연어 트리거 지원

</details>

<details>
<summary>v0.1.0 — 초기 버전 (2026-02-12)</summary>

- 6역할 에이전트 팀 (biz, marketing, research, tech, pm, synth)
- Wave 1 병렬 + Wave 2 순차 실행 패턴
- `/auto-generate` 전체 파이프라인 자동 실행 (sync → research → verify → 완료)
- 6종 문서 유형 지원 (`document-types.yaml` 레지스트리)
- Google Drive 동기화 (`/sync-drive`)
- 증거 청크 시스템 (`knowledge/evidence/`)
- JSON 출력 계약 (claims, citations, risks, open_questions)
- `/init-project` 프로젝트 초기화
- `/run-research` 에이전트 리서치 실행
- `/verify` 구조/스키마/인용/완전성 검증
- `/create-issue` GitHub Issue 자동 생성
- `.user-identity` 사용자 아이덴티티 시스템
- PR/Issue 템플릿 (`.claude/templates/`)
- 브랜치 워크플로우 (main 기반 + feature 브랜치 자동 복귀)
- SessionStart hook 상태 감지 및 자동 실행
- 인용 사양 (`citation-spec.md`) + 증거 정규화 사양 (`evidence-spec.md`)

</details>
