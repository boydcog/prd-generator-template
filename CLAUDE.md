# PRD Generator Template

이 프로젝트는 Google Drive 문서를 기반으로 에이전트 팀이 다양한 문서(PRD, 디자인 사양서, 마케팅 브리프 등)를 생성하는 자동화 도구입니다.
**사용자는 슬래시 명령어를 직접 입력하지 않습니다.** Claude가 상태를 감지하고 다음 단계를 자동으로 실행합니다.

---

## 세션 시작 시 반드시 따를 규칙

### 0. Hook 실패 감지 (Windows)

SessionStart hook은 bash 기반입니다. **Windows에서는 hook이 실패할 수 있습니다.**
Hook 출력이 없거나 에러가 발생하면:

1. Bash tool로 플랫폼을 감지합니다: `uname -s 2>/dev/null || echo Windows`
2. **Windows인 경우**: PowerShell로 startup.ps1을 직접 실행합니다:
   ```
   powershell -ExecutionPolicy Bypass -File .claude/hooks/startup.ps1
   ```
3. 출력을 파싱하여 이후 규칙(의존성 설치, 상태 감지 등)을 동일하게 적용합니다.

### 1. 의존성 자동 설치 (최우선)

SessionStart hook 출력에서 `FAIL` 표시된 의존성이 있으면 **추천 액션보다 먼저** 설치를 진행합니다.
사용자에게 설치 여부를 묻지 않습니다. "필요한 도구를 설치합니다..." 안내 후 즉시 실행합니다.

#### 설치 순서 (의존성 체인)

```
1. 패키지 매니저 (brew 또는 winget 미설치 시)
2. git (git 미설치 시)
3. gh CLI (gh 미설치 시)
```

#### 플랫폼별 설치 명령 (Bash tool로 실행)

| 도구 | macOS (brew) | Windows (winget) |
|------|-------------|------------------|
| 패키지 매니저 | `NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"` | winget은 Windows 10/11에 기본 내장 |
| git | `brew install git` | `winget install --id Git.Git -e --source winget --accept-package-agreements --accept-source-agreements` |
| gh CLI | `brew install gh` | `winget install --id GitHub.cli -e --source winget --accept-package-agreements --accept-source-agreements` |

> Windows에서 `winget`이 없는 경우 (Windows 10 1709 미만): "이 Windows 버전에서는 자동 설치가 지원되지 않습니다. git과 gh를 수동으로 설치해주세요." 안내.

#### 설치 규칙

- **Bash tool의 timeout을 300000ms (5분)으로 설정**합니다. 설치는 오래 걸릴 수 있습니다.
- 설치 실패 시 1회 재시도. 그래도 실패하면: "도구 설치에 실패했습니다. 수동 설치가 필요할 수 있습니다."
- **macOS**: brew로 설치하므로 sudo 불필요.
- **Windows**: winget은 관리자 권한 없이 사용자 범위로 설치 가능.
- 설치 완료 후 git repo 초기화가 안 된 상태면 (`git 연결: false`) git init + remote + reset 작업도 이어서 실행합니다.
- 모든 의존성 설치 후 결과만 보고합니다: "git, gh CLI 설치 완료. 프로젝트를 시작합니다."

### 2. 상태 감지 → 자동 실행

의존성이 모두 준비된 후 SessionStart hook의 추천 액션을 따릅니다.
**모든 플로우는 `/auto-generate`가 오케스트레이션합니다.** 개별 커맨드를 직접 호출하지 않고, auto-generate가 내부에서 init-project → sync-drive → run-research → verify를 체이닝합니다.

```
추천 액션이 "auto-generate"일 때:
  → "프로젝트를 시작합니다." 안내 후 /auto-generate 실행
  → auto-generate가 내부에서 init/sync/research/verify를 상태에 따라 자동 판단

추천 액션이 "sync-drive-or-update"일 때:
  → 기존 문서 버전을 알려주고 "문서를 다시 동기화할까요, 새 문서를 생성할까요?" 질문
  → 어느 쪽이든 /auto-generate 실행
```

### 3. 연속 실행 원칙

**사용자 입력이 필요하지 않은 작업은 끝까지 멈추지 않고 연속 실행합니다.**

- 중간에 "계속하시겠습니까?", "다음 단계를 진행할까요?" 같은 질문을 하지 않습니다.
- 각 단계 완료 시 로그만 남기고 즉시 다음 단계로 넘어갑니다.
- 모든 작업이 끝난 후 **한 번만** 결과를 보고합니다:
  1. 완료된 작업 요약
  2. 생성된 파일 경로
  3. 다음 추천 액션 (사용자가 선택할 수 있는 옵션)
- 사용자 입력이 **반드시** 필요한 경우만 예외: URL 입력, 선택지 결정 등

### 4. 모든 작업 전 verify

어떤 작업이든 시작하기 전에 `.claude/commands/verify.md`의 구조 검사를 먼저 수행합니다.
문제가 발견되면 자동으로 수정한 후 진행합니다.

### 5. 사용자 요청 감지

사용자가 자연어로 요청하면 적절한 명령을 자동 실행합니다:
- "PRD 만들어줘" / "기획서" / "문서 생성" / "자동으로 만들어줘" / "전체 실행" / "한번에" → /auto-generate
- "문서 추가해줘" / "새 링크" → Drive URL 입력받기 → manifest 추가 → /auto-generate
- "확인해줘" / "검증" → /verify
- "업로드" / "드라이브에 올려줘" → 업로드 실행
- "수정해줘" / "개선해줘" → 해당 내용 수정 후 /auto-generate (새 버전)
- "이슈 올려줘" / "기록해줘" → /create-issue
- "공유해줘" / "PR 올려줘" / "프로젝트 올려줘" / "팀에 공유" → /share-project
- "템플릿 수정" / "규칙 변경" / "명령어 추가" / "spec 수정" → /admin

### 5-1. 프로젝트 기능 안내 범위

사용자에게 "사용 가능한 기능", "무엇을 할 수 있는지" 등을 안내할 때:

- **반드시 `.claude/commands/` 디렉토리에 등록된 명령만** 안내합니다.
- system-reminder의 글로벌 스킬 목록(figma, firecrawl, ralph-loop 등)은 이 프로젝트의 기능이 아닙니다.
- 프로젝트 기능 = `.claude/commands/*.md` 파일에 정의된 것만 해당합니다.
- 현재 프로젝트 명령: init-project, sync-drive, run-research, verify, create-issue, auto-generate, share-project, admin

### 6. GH 토큰 자동 세팅

SessionStart hook에서 "GitHub 토큰 없음"이 감지되면 **다른 작업보다 먼저** 토큰 설정을 진행합니다:

1. 사용자에게 안내합니다:
   > "Issue/PR을 자동으로 관리하려면 GitHub 토큰이 필요합니다. Boyd에게 슬랙으로 토큰을 요청하거나, 이미 갖고 계시면 붙여넣어 주세요."
2. 사용자가 토큰을 제공하면:
   - `.gh-token` 파일에 저장합니다 (이 파일은 gitignored).
   - `gh auth status`로 유효성을 확인합니다.
   - 유효하면: "토큰 설정 완료!" 안내 후 다음 작업으로 진행.
   - 무효하면: "토큰이 유효하지 않습니다. 다시 확인해주세요." 안내.
3. 사용자가 "나중에" / "스킵"을 선택하면:
   - "토큰 없이 진행합니다. Issue/PR 생성은 로컬에만 저장됩니다." 안내 후 다음 작업으로 진행.
   - 로컬 pending-issues에 저장하는 폴백 모드로 동작합니다.

**토큰이 없으면 Issue/PR 관련 기능이 모두 로컬 폴백으로 동작합니다.** 토큰이 생기면 pending-issues를 일괄 업로드합니다.

### 7. 사용자 피드백 → Issue 자동 생성

사용자 메시지에서 다음 **신호**가 감지되면 `/create-issue`를 자동 실행합니다:

#### 즉시 이슈 생성 (무조건)
| 신호 | 라벨 | 예시 |
|------|------|------|
| 오동작/잘못된 결과 지적 | `bug` | "이거 틀렸어", "잘못 안내했어", "이상한데" |
| 기능 요청 | `feature-request` | "~하면 좋겠어", "~기능 추가해줘" |
| 반복되는 불편 | `bug` | "또 이러네", "매번 이래" |
| 명시적 이슈 요청 | (메시지 분석) | "이슈 올려줘", "기록해줘" |

#### 이슈 생성 + 즉시 수정
| 신호 | 라벨 | 후속 |
|------|------|------|
| 불만/지적 (수정 가능) | `bug` | 이슈 생성 후 해당 내용 즉시 수정 |
| 구조적 개선 제안 | `enhancement` | 이슈 생성 후 수정 PR |

#### 이슈 생성하지 않음
| 상황 | 이유 |
|------|------|
| 단순 질문 ("이건 뭐야?") | 답변으로 충분 |
| 확인 요청 ("맞아?") | 답변으로 충분 |
| 일반 대화 | 기록 불필요 |

#### 판단 원칙
- **사용자가 "시스템이 잘못했다"는 뉘앙스를 표현하면 → 무조건 이슈**
- 톤의 강도(경미한 지적 ~ 강한 불만)에 관계없이 생성
- "이슈를 올릴까요?"라고 묻지 않음. 감지 즉시 처리
- 이슈 생성 후 사용자에게 간단히 보고: "피드백을 이슈로 기록했습니다."

### 8. 시스템 자체 감지 → 자동 Issue/PR

**사용자가 요청하지 않아도** 시스템이 다음 상황을 감지하면 자동으로 Issue 또는 PR을 생성합니다:

| 감지 상황 | 자동 액션 |
|----------|----------|
| `/verify`에서 구조적 문제 발견 | 자동 수정 → `fix/` 브랜치 + PR |
| 에이전트 실행 중 spec 파일의 모순/누락 발견 | `improve/` 브랜치 + PR |
| startup.sh에서 예상치 못한 상태 감지 | Issue 생성 (라벨: `bug`) |
| 명령어 실행 중 반복적으로 실패하는 패턴 | Issue 생성 (라벨: `bug`) |
| 템플릿 구조 개선이 필요한 부분 발견 | Issue 생성 (라벨: `enhancement`) |

**원칙**:
- 사용자에게 "이슈를 올릴까요?"라고 묻지 않습니다. 감지 즉시 자동으로 처리합니다.
- 사용자에게는 결과만 알려줍니다: "구조 문제를 발견하여 자동 수정 PR을 생성했습니다."
- GH 토큰이 없으면 `.claude/state/pending-issues/`에 로컬 저장합니다.

### 9. Admin 모드

사용자가 템플릿 자체의 수정을 요청하면 `/admin` 커맨드를 실행합니다.
- `.claude/manifests/admins.yaml`에 등록된 사용자만 실행 가능합니다.
- EnterPlanMode → 승인 → 구현 → 검증 → worktree PR 생성까지 자동 실행합니다.
- 일반 사용자의 `/auto-generate` 워크플로우와 완전히 분리됩니다.

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
- 필요한 의존성(Homebrew, git, gh 등)은 **사용자에게 묻지 않고** 자동 설치합니다.
- Bash 명령은 이 프로젝트의 작업에 필요하면 자유롭게 실행합니다.
- 사용자에게 기술적인 명령어를 보여주지 않습니다. 결과만 알려줍니다.
- **사용자는 개발 도구가 전혀 없는 환경일 수 있습니다.** Claude가 모든 환경 세팅을 자동으로 처리합니다.

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

- `.gh-token` 파일이 프로젝트 루트에 있으면 SessionStart hook에서 자동으로 `GH_TOKEN` 환경변수에 로드합니다.
- 이 파일은 gitignored입니다. 슬랙으로 Boyd에게 공유받습니다.
- **토큰이 없으면 세션 시작 시 토큰 세팅 플로우를 먼저 실행합니다** (세션 시작 규칙 5번 참조).
- 토큰 없이도 동작하지만, Issue/PR 생성은 `.claude/state/pending-issues/`에 로컬 저장됩니다.
- 토큰이 설정되면 pending-issues를 자동으로 일괄 업로드합니다.

### git repo 초기화 (ZIP 배포)

`.git/` 디렉토리가 없으면 startup hook(macOS: `.sh`, Windows: `.ps1`)이 자동 처리합니다:
1. `git init`
2. `git remote add origin https://github.com/boydcog/prd-generator-template.git` (HTTPS 우선, 실패 시 SSH 폴백)
3. `git fetch origin`
4. `git reset origin/main` — ZIP 파일은 유지하면서 HEAD를 remote에 맞춤
5. `git checkout -b main` + upstream 설정
6. 이후 `git pull origin main`으로 최신 템플릿 규칙 반영
7. 기존 repo의 SSH URL(`git@github.com:...`)은 자동으로 HTTPS로 교정됩니다.

**사용자는 이 과정을 인지하지 못합니다.** 실패 시에만 간단히 안내합니다.

### 플랫폼별 스크립트

| 플랫폼 | Hook 스크립트 | 패키지 매니저 | 실행 환경 |
|--------|-------------|-------------|----------|
| macOS | `.claude/hooks/startup.sh` | Homebrew (brew) | bash |
| Windows | `.claude/hooks/startup.ps1` | winget (기본 내장) | PowerShell |

- settings.json의 hook은 bash 기반 (macOS에서 자동 실행).
- **Windows에서 hook이 실패하면** Claude가 플랫폼을 감지하고 startup.ps1을 수동 실행합니다 (세션 시작 규칙 0번).
- 두 스크립트는 **동일한 출력 형식**을 사용하므로 Claude의 후속 처리 로직은 플랫폼 무관합니다.

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
  - `{commit_short}`: `git rev-parse --short HEAD` (기준 커밋)
  - `{branch_name}`: 현재 브랜치명
  - `{change_summary}`, `{detailed_changes}`, `{reason}`, `{file_list}`: 변경 내용 기반

### 사용자 피드백 감지

사용자가 "이 부분 좀 고쳐줘", "여기가 이상해" 등의 피드백을 주면:
1. 해당 내용을 즉시 수정합니다.
2. 수정 후 새 문서 버전을 생성할지 물어봅니다.
3. 구조적 문제라면 issue 브랜치 + PR로 처리합니다.
4. `/create-issue`를 자동 실행하여 피드백을 GitHub Issue로 기록합니다.

### 시스템 자체 감지 → 자동 Issue/PR

사용자 요청 없이도 다음을 감지하면 **자동으로** Issue 또는 PR을 생성합니다:
- `/verify` 실행 중 구조적 문제 → 자동 수정 후 `fix/` PR
- spec 파일 간 모순/누락 → `improve/` PR
- 에이전트 실행 실패 패턴 → Issue (라벨: `bug`)
- 템플릿 개선 필요 → Issue (라벨: `enhancement`)

사용자에게 묻지 않고 즉시 처리합니다. 결과만 간단히 보고합니다.
GH 토큰이 없으면 `.claude/state/pending-issues/`에 로컬 저장 후 토큰 설정 시 일괄 업로드합니다.

---

## 브랜치 워크플로우

### 원칙

- **작업 브랜치는 항상 main**입니다.
- **main 작업 디렉토리의 브랜치를 절대 변경하지 않습니다** (`git checkout` 금지).
- PR 생성 시 `git worktree`로 독립 디렉토리를 생성하여 작업합니다.
- SessionStart hook에서 main이 아닌 브랜치에 있으면 자동 전환합니다.
- SessionStart hook에서 잔여 worktree를 자동 정리합니다.

### PR 생성 절차 (Worktree 방식)

1. `git pull origin main`
2. Worktree 생성:
   ```
   SLUG="{branch_name에서 / → -}"
   git worktree add -b {branch_name} ../.worktrees/${SLUG} main
   ```
   - 문서: `doc/{type}-v{N}` (예: `doc/prd-v3`)
   - 수정: `fix/{요약}`
   - 개선: `improve/{요약}`
   - 기능: `feat/{요약}`
   - 이슈: `issue/{이슈번호}-{요약}`
   - 프로젝트: `project/{slug}`
3. 변경된 파일을 worktree로 복사
4. worktree 안에서 `git add` + `git commit`
5. push URL로 직접 토큰 전달 (remote config에 토큰을 남기지 않음):
   ```
   GH_TOKEN=$(cat "${PROJECT_DIR}/.gh-token" | tr -d '[:space:]')
   git -C ../.worktrees/${SLUG} push \
     "https://user:${GH_TOKEN}@github.com/boydcog/prd-generator-template.git" \
     "HEAD:refs/heads/{branch_name}"
   ```
6. PR 생성 (`pr-template.md` 사용)
7. Worktree 정리: `git worktree remove ../.worktrees/${SLUG}`

### 안전 장치

- startup hook에서 잔여 worktree를 자동 정리합니다.
- worktree 생성 실패 시 (동일 브랜치 존재 등) 기존 worktree를 제거 후 재시도합니다.
- worktree 위치는 프로젝트 루트의 형제 디렉토리 `../.worktrees/` (프로젝트 밖이므로 gitignore 불필요).
- GH_TOKEN은 원본 프로젝트 디렉토리의 `.gh-token`에서 절대경로로 읽습니다.

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
│   │   ├── startup.sh                 ← 세션 시작 자동 실행 (macOS)
│   │   └── startup.ps1                ← 세션 시작 자동 실행 (Windows)
│   ├── commands/                      ← 슬래시 명령어 (자동 실행됨)
│   │   ├── init-project.md
│   │   ├── sync-drive.md
│   │   ├── run-research.md
│   │   ├── verify.md
│   │   ├── auto-generate.md           ← 전체 파이프라인 자동 실행
│   │   ├── create-issue.md            ← GitHub Issue 생성
│   │   ├── share-project.md           ← 프로젝트 결과물 PR 공유
│   │   └── admin.md                   ← 관리자 워크플로우
│   ├── templates/                     ← PR/Issue 템플릿
│   │   ├── pr-template.md
│   │   └── issue-template.md
│   ├── manifests/                     ← 설정 (tracked)
│   │   ├── drive-sources.yaml
│   │   ├── project-defaults.yaml
│   │   └── admins.yaml                ← 관리자 목록
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
