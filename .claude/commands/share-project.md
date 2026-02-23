# /share-project — 프로젝트 결과물을 PR로 공유

프로젝트의 생성물(문서, 메타데이터)을 새 브랜치에 올려 PR로 공유합니다.

---

## 실행 절차

### Step 0: 활성 제품 로드

`.claude/state/_active_product.txt`에서 활성 제품 ID를 읽어 `{active_product}` 변수에 저장합니다.
- 파일이 없거나 비어있으면: "활성 제품이 설정되지 않았습니다. /init-project 또는 /switch-product를 실행하세요." 안내 후 중단.

### Step 1: 프로젝트 정보 로드

1. `.claude/state/{active_product}/project.json`에서 로드:
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
2. `{active_product}`를 브랜치 슬러그로 사용합니다 (이미 케밥케이스 형식).
3. Worktree로 브랜치 생성:
   ```bash
   SLUG="project-{active_product}"
   WORKTREE_DIR="../.worktrees/${SLUG}"
   git worktree add -b "project/{active_product}" "$WORKTREE_DIR" main
   ```
   - 이미 존재하면: `project/{active_product}-v{version}`
   - worktree 생성 실패 시 기존 worktree를 제거 후 재시도

### Step 4: 공유 대상 파일 추가

변경 파일을 worktree로 복사한 뒤 `git add -f`로 추가:

```bash
PROJECT_DIR="$(pwd)"
WORKTREE_DIR="../.worktrees/${SLUG}"

# 필요한 디렉토리 생성
mkdir -p "$WORKTREE_DIR/.claude/state/{active_product}"

# 프로젝트 메타데이터를 worktree로 복사 (product 네임스페이스 유지)
cp ".claude/state/{active_product}/project.json" "$WORKTREE_DIR/.claude/state/{active_product}/"
cp ".claude/state/{active_product}/sync-ledger.json" "$WORKTREE_DIR/.claude/state/{active_product}/" 2>/dev/null || true
cp .user-identity "$WORKTREE_DIR/"

# artifacts를 worktree로 복사 (product 네임스페이스 유지)
mkdir -p "$WORKTREE_DIR/.claude/artifacts"
cp -r ".claude/artifacts/{active_product}/" "$WORKTREE_DIR/.claude/artifacts/{active_product}/"

# worktree 안에서 git add (git -C로 디렉토리 이동 없이 실행)
git -C "$WORKTREE_DIR" add -f ".claude/state/{active_product}/project.json"
git -C "$WORKTREE_DIR" add -f ".claude/state/{active_product}/sync-ledger.json"
git -C "$WORKTREE_DIR" add -f .user-identity
git -C "$WORKTREE_DIR" add -f ".claude/artifacts/{active_product}/"
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

**env.yml에서 변수를 로드합니다**: `github.owner`, `github.repo`, `github.default_reviewers`, `github.default_assignees`

```bash
# push URL로 직접 토큰 전달 (remote config에 토큰을 남기지 않음)
GH_TOKEN=$(cat "${PROJECT_DIR}/.gh-token" | tr -d '[:space:]')
git -C "$WORKTREE_DIR" push \
  "https://user:${GH_TOKEN}@github.com/{github.owner}/{github.repo}.git" \
  "HEAD:refs/heads/project/{active_product}"

# PR 생성 (PR 작성자는 --reviewer에서 자동 제외)
GH_TOKEN=$GH_TOKEN gh pr create --repo {github.owner}/{github.repo} \
  --head "project/{active_product}" \
  --label documentation \
  --reviewer "{default_reviewers}" \
  --assignee "{default_assignees}" \
  ...
```

1. push + PR 생성
2. PR 본문 구성 (`.claude/templates/pr-template.md` 준수):

**제목**: `project: {project_name} — {document_type} v{version}`

**본문**: `.claude/templates/pr-template.md`의 모든 필드를 다음과 같이 채웁니다:

| 템플릿 필드 | 값 |
|-----------|-----|
| `{user_name}` | `.user-identity`에서 로드 |
| `{timestamp}` | 현재 시각 (ISO 8601) |
| `{project_name}` | `project.json`의 `project_name` |
| `{document_type}` | `project.json`의 `document_type` |
| `{commit_short}` | 기준 커밋 (main HEAD) |
| `{branch_name}` | `project/{active_product}` |
| `{change_summary}` | `{document_type} v{version} 생성 및 공유` |
| `{detailed_changes}` | 생성된 파일 목록 (worktree의 신규/변경 파일) + 프로젝트 설명 (core_problem, target_users, domain) |
| `{reason}` | `프로젝트 공유 및 협업` |
| `{file_list}` | `git diff --name-only main...HEAD` 결과 |

**중요 주의사항**:
- 이 PR은 프로젝트 공유용입니다. **main에 머지하지 마세요.**
- 머지하면 gitignore된 파일이 tracked 상태가 되어 템플릿이 오염됩니다.

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
  - 브랜치: project/{active_product}
  - PR: {pr_url}
  - 포함된 파일: {file_count}개
```

---

## 주의사항

- 이 PR은 **main에 머지하지 않습니다**. 공유/리뷰 목적으로만 사용합니다.
- 머지하면 gitignore된 파일이 tracked 상태가 되어 템플릿이 오염됩니다.
- PR 설명에 "이 PR은 프로젝트 공유용입니다. main에 머지하지 마세요." 경고를 포함합니다.
