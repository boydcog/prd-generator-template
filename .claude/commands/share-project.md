# /share-project — 프로젝트 결과물을 PR로 공유

프로젝트의 생성물(문서, 메타데이터)을 새 브랜치에 올려 PR로 공유합니다.

---

## 실행 절차

### Step 1: 프로젝트 정보 로드

1. `.claude/state/project.json`에서 로드:
   - `name` → `{project_name}`
   - `document_type` → `{document_type}` (없으면 `prd`)
   - `current_version` → `{version}`
2. `.user-identity`에서 `{user_name}` 로드.
3. 파일이 없으면 에러: "프로젝트가 초기화되지 않았습니다. /auto-generate를 먼저 실행해주세요."

### Step 2: GH 토큰 확인

1. `.gh-token` 파일 또는 `GH_TOKEN` 환경변수 확인.
2. 없으면 CLAUDE.md 규칙 6의 토큰 세팅 플로우 실행.
3. 토큰 없이는 PR을 생성할 수 없으므로 "스킵" 시 중단:
   > "PR을 생성하려면 토큰이 필요합니다. 토큰 설정 후 다시 시도해주세요."

### Step 3: Worktree 생성

1. `git pull origin main`
2. 프로젝트 이름을 kebab-case로 변환: `{project_name}` → `{branch_slug}`
   - 예: "Maththera" → `maththera`, "My App 2.0" → `my-app-2-0`
3. Worktree로 브랜치 생성:
   ```bash
   SLUG="project-{branch_slug}"
   WORKTREE_DIR="../.worktrees/${SLUG}"
   git worktree add -b "project/{branch_slug}" "$WORKTREE_DIR" main
   ```
   - 이미 존재하면: `project/{branch_slug}-v{version}`
   - worktree 생성 실패 시 기존 worktree를 제거 후 재시도

### Step 4: 공유 대상 파일 추가

변경 파일을 worktree로 복사한 뒤 `git add -f`로 추가:

```bash
PROJECT_DIR="$(pwd)"
WORKTREE_DIR="../.worktrees/${SLUG}"

# 필요한 디렉토리 생성
mkdir -p "$WORKTREE_DIR/.claude/state"

# 프로젝트 메타데이터를 worktree로 복사
cp .claude/state/project.json "$WORKTREE_DIR/.claude/state/"
cp .claude/state/sync-ledger.json "$WORKTREE_DIR/.claude/state/" 2>/dev/null || true
cp .user-identity "$WORKTREE_DIR/"

# artifacts를 worktree로 복사
cp -r .claude/artifacts/ "$WORKTREE_DIR/.claude/artifacts/"

# worktree 안에서 git add (git -C로 디렉토리 이동 없이 실행)
git -C "$WORKTREE_DIR" add -f .claude/state/project.json
git -C "$WORKTREE_DIR" add -f .claude/state/sync-ledger.json
git -C "$WORKTREE_DIR" add -f .user-identity
git -C "$WORKTREE_DIR" add -f .claude/artifacts/
git -C "$WORKTREE_DIR" add CLAUDE.md README.md
git -C "$WORKTREE_DIR" add .claude/commands/ .claude/templates/ .claude/spec/ .claude/manifests/
```

**절대 추가하지 않는 파일:**
- `.gh-token` (민감 정보)
- `.claude/knowledge/evidence/chunks/` (대용량 청크)
- `.claude/state/pending-issues/` (이미 이슈로 등록됨)

### Step 5: CHANGELOG.md 업데이트

PR 생성 전에 `CHANGELOG.md`에 프로젝트 공유 항목을 추가/갱신합니다:

- 오늘 날짜 (`## YYYY-MM-DD`) 섹션이 이미 있으면 해당 날짜 아래에서:
  - 새 항목 → 새 bullet 추가.
  - 기존 항목과 내용이 겹치면 → 이전 bullet 삭제 후 갱신된 내용으로 교체.
- 없으면 `# Changelog` 바로 아래에 새 날짜 헤더 + bullet 생성.
- 항목 형식: ``- 프로젝트 공유: {project_name} — {document_type} v{version} ([`{commit_short}`](https://github.com/{github.owner}/{github.repo}/commit/{commit_short}))``
- 이 항목은 `project/` 브랜치에만 포함됩니다 (main에 머지하지 않으므로 main의 Changelog에는 영향 없음).

### Step 6: 커밋

```bash
git -C "$WORKTREE_DIR" commit -m "project: {project_name} — {document_type} v{version}"
```

### Step 7: PR 생성

**중요: 인증된 URL로 push한 뒤 PR을 생성합니다.**
브라우저 인증이나 `gh auth login` 등 interactive 플로우를 사용하지 않습니다.

**env.yml에서 변수를 로드합니다**: `github.owner`, `github.repo`, `github.default_reviewer`

```bash
# push URL로 직접 토큰 전달 (remote config에 토큰을 남기지 않음)
GH_TOKEN=$(cat "${PROJECT_DIR}/.gh-token" | tr -d '[:space:]')
git -C "$WORKTREE_DIR" push \
  "https://user:${GH_TOKEN}@github.com/{github.owner}/{github.repo}.git" \
  "HEAD:refs/heads/project/{branch_slug}"

# PR 생성
GH_TOKEN=$GH_TOKEN gh pr create --repo {github.owner}/{github.repo} \
  --head "project/{branch_slug}" \
  --label documentation \
  --reviewer "{default_reviewer}" \
  ...
```

1. push + PR 생성
2. PR 본문 구성:

**제목**: `project: {project_name} — {document_type} v{version}`

**본문**:
```markdown
## 프로젝트 공유

| 항목 | 내용 |
|------|------|
| 작성자 | {user_name} |
| 생성 시각 | {timestamp} |
| 프로젝트 | {project_name} |
| 문서 유형 | {document_type} |
| 문서 버전 | v{version} |
| 브랜치 | project/{branch_slug} |

## 프로젝트 설명
{project.json의 core_problem + target_users + domain을 기반으로 2-3문장 요약}

## 포함된 파일
{git diff --name-only main...HEAD 결과를 마크다운 리스트로}

## 관련 이슈
{세션 중 생성된 이슈 목록 — gh issue list --state open --json number,title로 조회}

---
⚠️ **이 PR은 프로젝트 공유용입니다. main에 머지하지 마세요.**
머지하면 gitignore된 파일이 tracked 상태가 되어 템플릿이 오염됩니다.

---
*PRD Generator 프로젝트 공유 | 작성자: {user_name} | {timestamp}*
```

3. `gh pr create` 실행.

**중요**: Step 7의 `gh pr create` 명령 실행 시 `GH_TOKEN` 환경 변수를 사용하여 인증합니다. `gh auth login` 등 interactive 인증은 절대 사용하지 않으며, PR 본문에 토큰을 포함해서는 안 됩니다.

### Step 8: Worktree 정리 (필수)

PR 생성 성공/실패와 관계없이 **반드시** worktree를 정리합니다:

```bash
# PROJECT_DIR은 Step 4에서 설정됨
WORKTREE_PATH="${PROJECT_DIR}/../.worktrees/${SLUG}"

# worktree 제거 전에 새로 추가된 파일 목록 확보
NEW_FILES=$(git -C "$WORKTREE_PATH" diff --name-only --diff-filter=A main...HEAD 2>/dev/null)

# worktree 제거
git worktree remove "$WORKTREE_PATH" 2>/dev/null || git worktree remove --force "$WORKTREE_PATH" 2>/dev/null || true

# main 작업 디렉토리 복원 (수정된 tracked 파일 되돌리기)
git -C "$PROJECT_DIR" checkout -- .

# 새로 생성된 untracked 파일 삭제 (merge 후 pull 시 충돌 방지)
if [ -n "$NEW_FILES" ]; then
  echo "$NEW_FILES" | while read -r f; do
    [[ "$f" == *".."* ]] && continue
    [ -f "${PROJECT_DIR}/$f" ] && rm "${PROJECT_DIR}/$f"
  done
fi
```

에러 발생 시에도 이 단계는 반드시 실행합니다.

### Step 9: 결과 보고

```
프로젝트를 공유했습니다:
  - 브랜치: project/{branch_slug}
  - PR: {pr_url}
  - 포함된 파일: {file_count}개
```

---

## 주의사항

- 이 PR은 **main에 머지하지 않습니다**. 공유/리뷰 목적으로만 사용합니다.
- 머지하면 gitignore된 파일이 tracked 상태가 되어 템플릿이 오염됩니다.
- PR 설명에 "이 PR은 프로젝트 공유용입니다. main에 머지하지 마세요." 경고를 포함합니다.
