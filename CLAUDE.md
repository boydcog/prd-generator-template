# PRD Generator Template

이 프로젝트는 Google Drive 문서를 기반으로 에이전트 팀이 다양한 문서(PRD, 디자인 사양서, 마케팅 브리프 등)를 생성하는 자동화 도구입니다.
**사용자는 슬래시 명령어를 직접 입력하지 않습니다.** Claude가 상태를 감지하고 다음 단계를 자동으로 실행합니다.

---

## 세션 시작 시 반드시 따를 규칙

### 1. 상태 감지 → 자동 실행

SessionStart hook의 출력을 확인하고 다음 로직을 따릅니다:

```
추천 액션이 "init-project"일 때:
  → "프로젝트를 설정하겠습니다." 안내 후 /init-project 실행

추천 액션이 "auto-generate"일 때:
  → "전체 파이프라인을 자동 실행하겠습니다." 안내 후 /auto-generate 실행

추천 액션이 "sync-drive"일 때:
  → "Drive 문서를 동기화하겠습니다." 안내 후 /sync-drive 실행

추천 액션이 "run-research"일 때:
  → "문서를 생성하겠습니다." 안내 후 /run-research 실행

추천 액션이 "sync-drive-or-update"일 때:
  → 기존 문서 버전을 알려주고 "문서를 다시 동기화할까요, 새 문서를 생성할까요?" 질문
```

### 2. 연속 실행 원칙

**사용자 입력이 필요하지 않은 작업은 끝까지 멈추지 않고 연속 실행합니다.**

- 중간에 "계속하시겠습니까?", "다음 단계를 진행할까요?" 같은 질문을 하지 않습니다.
- 각 단계 완료 시 로그만 남기고 즉시 다음 단계로 넘어갑니다.
- 모든 작업이 끝난 후 **한 번만** 결과를 보고합니다:
  1. 완료된 작업 요약
  2. 생성된 파일 경로
  3. 다음 추천 액션 (사용자가 선택할 수 있는 옵션)
- 사용자 입력이 **반드시** 필요한 경우만 예외: URL 입력, 선택지 결정 등

### 3. 모든 작업 전 verify

어떤 작업이든 시작하기 전에 `.claude/commands/verify.md`의 구조 검사를 먼저 수행합니다.
문제가 발견되면 자동으로 수정한 후 진행합니다.

### 4. 사용자 요청 감지

사용자가 자연어로 요청하면 적절한 명령을 자동 실행합니다:
- "문서 추가해줘" / "새 링크" → Drive URL 입력받기 → manifest 추가 → /sync-drive
- "PRD 만들어줘" / "기획서" / "문서 생성" → /run-research
- "자동으로 만들어줘" / "전체 실행" / "한번에" → /auto-generate
- "확인해줘" / "검증" → /verify
- "업로드" / "드라이브에 올려줘" → 문서를 Drive에 업로드
- "수정해줘" / "개선해줘" → 해당 내용 수정 후 새 버전 생성
- "이슈 올려줘" / "기록해줘" → /create-issue

### 5. 사용자 피드백 → Issue 자동 생성

사용자가 피드백/질문을 제공하면:
1. 해당 내용을 즉시 처리합니다.
2. `/create-issue`를 자동 실행하여 GitHub Issue로 기록합니다.

---

## 사용자 아이덴티티

- `.user-identity` 파일에 사용자 이름이 저장됩니다 (gitignored).
- 파일이 없으면 처음 사용 시 이름을 입력받아 저장합니다: "처음 사용하시나요? 이름을 알려주세요."
- PR, Issue 생성 시 작성자로 사용합니다.
- SessionStart hook에서 자동으로 로드하여 인사합니다.

---

## 문서 유형

이 프로젝트는 PRD뿐 아니라 다양한 문서 유형을 지원합니다.
문서 유형 레지스트리: `.claude/spec/document-types.yaml`

| 유형 ID | 이름 | 설명 |
|---------|------|------|
| `prd` | 제품 요구사항 문서 | 기본값. 제품 기획 종합 문서 |
| `design-spec` | 디자인 사양서 | UI/UX 디자인 상세 사양 |
| `marketing-brief` | 마케팅 브리프 | 마케팅 전략 및 캠페인 기획 |
| `business-plan` | 사업 계획서 | 사업 타당성 및 실행 계획 |
| `tech-spec` | 기술 사양서 | 기술 아키텍처 및 구현 상세 |
| `custom` | 사용자 정의 | 에이전트/섹션을 직접 정의 |

- `project.json`에 `document_type` 필드가 없으면 기본값 `prd` 적용 (하위호환).
- 문서 유형에 따라 활성 에이전트, 출력 섹션, 저장 경로가 자동 결정됩니다.

---

## 권한 및 실행 규칙

- 이 프로젝트 내의 모든 파일은 자유롭게 읽기/쓰기/이동할 수 있습니다.
- 필요한 의존성(git, gh 등)은 사용자에게 묻지 않고 설치합니다.
- Bash 명령은 이 프로젝트의 작업에 필요하면 자유롭게 실행합니다.
- 사용자에게 기술적인 명령어를 보여주지 않습니다. 결과만 알려줍니다.

---

## Agent Teams 규칙

`/run-research` 실행 시 반드시 Agent Teams를 사용합니다:

1. **Wave 1**: Task tool로 `document-types.yaml`의 `agent_roles.wave1`에 정의된 에이전트를 **병렬** 실행
2. **Wave 2**: Wave 1 완료 후 synth 에이전트 실행
3. 각 에이전트에게 `.claude/spec/agent-team-spec.md`의 역할과 JSON 계약을 전달합니다.
4. 진행 상황을 사용자에게 알려줍니다:
   - "{N}개 분석 에이전트를 시작합니다..."
   - 각 에이전트 완료 시: "{역할} 분석 완료"
   - "통합 에이전트를 시작합니다..."
   - "{문서유형} v{N} 생성 완료!"

---

## Git 및 GitHub 규칙

### git pull 우선

모든 명령 실행 전에 `git pull origin main`을 실행합니다 (SessionStart hook에서 자동 처리).

### GitHub 토큰

- `.gh-token` 파일이 프로젝트 루트에 있으면 자동으로 로드합니다.
- 이 파일은 gitignored입니다. 슬랙으로 공유받습니다.
- 토큰이 없으면 PR 생성을 건너뛰고 로컬 브랜치만 생성합니다.
- **토큰이 없는 경우 사용자에게 안내**: "GitHub 토큰이 없어서 PR을 생성할 수 없습니다. Boyd에게 `.gh-token` 파일을 슬랙으로 요청해주세요."

### git repo 전환

`.git/` 디렉토리가 없으면 (zip 배포):
1. `git init`
2. `git remote add origin https://github.com/boydcog/prd-generator-template.git`
3. `git fetch origin main`
4. 자동 처리 (SessionStart hook)

---

## 에러 핸들링

### 원칙: 실패해도 끝까지 완수

1. **자체 해결 시도**: 에러가 발생하면 원인을 분석하고 자동 수정합니다.
2. **수정 불가능한 경우**:
   a. `issue/{문제요약}` 브랜치를 생성합니다.
   b. 문제 내용과 재현 방법을 기록합니다.
   c. GH_TOKEN이 있으면 PR을 생성합니다.
   d. GH_TOKEN이 없으면 브랜치만 push하고 사용자에게 안내합니다.
3. **사용자 안내**: 기술적 세부사항이 아닌, 무엇이 문제이고 어떻게 되었는지 간단히 알려줍니다.

### PR 생성 규칙

- gitignored 파일이라도 개선이 필요한 설정/구조는 확인합니다.
- PR 제목: `fix: {문제 요약}` 또는 `improve: {개선 요약}`
- **PR 본문**: `.claude/templates/pr-template.md` 템플릿을 사용합니다. 모든 필드를 필수 기입합니다:
  - `{user_name}`: `.user-identity`에서 로드
  - `{timestamp}`: 현재 시각 (ISO 8601)
  - `{project_name}`: `project.json`에서 로드
  - `{document_type}`: `project.json`에서 로드 (기본값: prd)
  - `{version}`: 현재 문서 버전
  - `{branch_name}`: 현재 브랜치명
  - `{change_summary}`, `{detailed_changes}`, `{reason}`, `{file_list}`: 변경 내용 기반

### 사용자 피드백 감지

사용자가 "이 부분 좀 고쳐줘", "여기가 이상해" 등의 피드백을 주면:
1. 해당 내용을 즉시 수정합니다.
2. 수정 후 새 문서 버전을 생성할지 물어봅니다.
3. 구조적 문제라면 issue 브랜치 + PR로 처리합니다.
4. `/create-issue`를 자동 실행하여 피드백을 GitHub Issue로 기록합니다.

---

## 브랜치 워크플로우

### 원칙

- **작업 브랜치는 항상 main**입니다.
- PR 생성 시에만 feature 브랜치로 전환합니다.
- PR 생성 후 **반드시 main으로 복귀**합니다.
- SessionStart hook에서 main이 아닌 브랜치에 있으면 자동 전환합니다.

### PR 생성 절차

1. `git pull origin main`
2. `git checkout -b {branch_name}`
   - 문서: `doc/{type}-v{N}` (예: `doc/prd-v3`)
   - 수정: `fix/{요약}`
   - 이슈: `issue/{이슈번호}-{요약}`
3. `git add` + `git commit`
4. `git push -u origin {branch_name}`
5. `gh pr create` (`.claude/templates/pr-template.md` 사용)
6. `git checkout main` **(필수)**
7. `git pull origin main`

### 안전 장치

에러 발생 시에도 반드시 main으로 복귀합니다:
```bash
git checkout main || git checkout -f main
```

---

## 파일 구조

```
.
├── CLAUDE.md                          ← 이 파일 (프로젝트 규칙)
├── .gh-token                          ← GitHub 토큰 (gitignored, 슬랙으로 공유)
├── .user-identity                     ← 사용자 이름 (gitignored)
├── .gitignore
├── .claude/
│   ├── settings.json                  ← 권한 + hooks 설정
│   ├── .gitignore
│   ├── hooks/
│   │   └── startup.sh                 ← 세션 시작 자동 실행
│   ├── commands/                      ← 슬래시 명령어 (자동 실행됨)
│   │   ├── init-project.md
│   │   ├── sync-drive.md
│   │   ├── run-research.md
│   │   ├── verify.md
│   │   ├── auto-generate.md           ← 전체 파이프라인 자동 실행
│   │   └── create-issue.md            ← GitHub Issue 생성
│   ├── templates/                     ← PR/Issue 템플릿
│   │   ├── pr-template.md
│   │   └── issue-template.md
│   ├── manifests/                     ← 설정 (tracked)
│   │   ├── drive-sources.yaml
│   │   └── project-defaults.yaml
│   ├── spec/                          ← 사양서 (tracked)
│   │   ├── agent-team-spec.md
│   │   ├── citation-spec.md
│   │   ├── evidence-spec.md
│   │   └── document-types.yaml        ← 문서 유형 레지스트리
│   ├── state/                         ← 상태 (generated, gitignored)
│   ├── knowledge/                     ← 증거 (generated, gitignored)
│   └── artifacts/                     ← 출력물 (generated, gitignored)
└── .sisyphus/                         ← 기획 이력 (gitignored)
```

---

## README 동기화 규칙

README.md는 프로젝트의 context 문서이다. 다음 파일이 변경될 때 README.md도 반드시 함께 업데이트한다:

### 트리거 파일 → README 업데이트 영역

| 변경된 파일 | README 업데이트 대상 |
|------------|---------------------|
| `.claude/commands/*.md` (추가/삭제/변경) | "핵심 기능" 섹션 |
| `.claude/spec/document-types.yaml` | "지원 문서 유형" 표 |
| `.claude/spec/agent-team-spec.md` | "작동 방식" 에이전트 매핑 |
| `.claude/manifests/project-defaults.yaml` | "빠른 시작" 기본값 |
| `.claude/templates/*.md` (추가/삭제) | "핵심 기능" 섹션 |
| `CLAUDE.md` 파일 구조 섹션 | "파일 구조" 섹션 |

### Changelog 업데이트 규칙

- 위 트리거 파일이 변경될 때마다 Changelog에 새 항목을 추가한다.
- 형식: `<details><summary>v{X.Y.Z} — {요약} ({날짜})</summary>` 접기 형태.
- 기존 항목은 수정하지 않는다 (append-only).
- 버전 번호: 템플릿 수정/기능 추가 = patch (0.1.X). 메이저/마이너 변경은 배포 시에만.

---

## 참고 문서

- `.claude/spec/agent-team-spec.md` — 에이전트 팀 정의
- `.claude/spec/citation-spec.md` — 인용 규칙
- `.claude/spec/evidence-spec.md` — 증거 정규화 규칙
- `.claude/spec/document-types.yaml` — 문서 유형 레지스트리
- `.claude/manifests/project-defaults.yaml` — 기본 설정값
- `.claude/templates/pr-template.md` — PR 본문 템플릿
- `.claude/templates/issue-template.md` — Issue 본문 템플릿
