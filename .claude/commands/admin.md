# /admin — 템플릿 관리자 워크플로우

관리자(maintainer)가 템플릿 자체를 수정할 때 사용하는 워크플로우입니다.
요구사항 수집 → 플랜 → 구현 → 검증 → PR 자동 생성까지 실행합니다.

---

## 실행 절차

### Step 1: 권한 확인

1. `.user-identity` 파일에서 사용자 이름을 로드합니다.
2. `.claude/manifests/admins.yaml`의 `admins[].name`과 대조합니다.
3. 일치하는 항목이 없으면:
   > "관리자 권한이 없습니다. 이 명령은 템플릿 maintainer만 사용할 수 있습니다."
   — 안내 후 종료합니다.

### Step 2: 요구사항 수집

1. 사용자의 자연어 요청을 분석합니다.
2. 변경 범위를 파악합니다: 어떤 파일이 영향받는지 목록화.
3. "다음을 수정합니다: {파일 목록}. 플랜을 작성할까요?" 확인합니다.

### Step 3: 플랜 작성

1. `EnterPlanMode`로 진입합니다.
2. 영향받는 파일을 모두 읽고 변경 플랜을 작성합니다.
3. `ExitPlanMode`로 사용자 승인을 요청합니다.

### Step 4: 구현

1. 승인된 플랜에 따라 파일을 수정합니다.
2. 각 파일 수정 후 변경 내역을 로그합니다.

### Step 5: 검증

1. `/verify`를 실행합니다 (구조/스키마 검사).
2. FAIL 시 자동 수정 후 재검증합니다.
3. README 동기화 규칙을 적용합니다:
   - `.claude/commands/*.md` 변경 → "핵심 기능" 섹션 업데이트
   - `.claude/spec/document-types.yaml` 변경 → "지원 문서 유형" 표 업데이트
   - `CLAUDE.md` 구조 섹션 변경 → "파일 구조" 섹션 업데이트

### Step 6: CHANGELOG.md 업데이트

Worktree에 커밋하기 전에 `CHANGELOG.md`에 항목을 추가/갱신합니다:

- 오늘 날짜 (`## YYYY-MM-DD`) 섹션이 이미 있으면 해당 날짜 아래에서:
  - 새 기능 → 새 bullet 추가.
  - 기존 항목과 내용이 겹치면 → 이전 bullet 삭제 후 갱신된 내용으로 교체.
- 없으면 `# Changelog` 바로 아래에 새 날짜 헤더 + bullet 생성.
- 항목 형식: ``- {변경 요약} ([`{commit_short}`](https://github.com/{github.owner}/{github.repo}/commit/{commit_short}))``

### Step 7: Worktree PR 생성

1. 브랜치명을 결정합니다:
   - 수정: `fix/{요약}`
   - 개선: `improve/{요약}`
   - 기능: `feat/{요약}`
2. Worktree 방식으로 PR을 생성합니다:

```bash
PROJECT_DIR="$(pwd)"

# 1. worktree 생성
SLUG="{branch_name에서 / → -}"
WORKTREE_DIR="../.worktrees/${SLUG}"
git worktree add -b {branch_name} "$WORKTREE_DIR" main

# 2. 변경된 파일을 worktree로 복사 (디렉토리 구조 유지)
cp --parents {modified_files} "$WORKTREE_DIR/"

# 3. worktree 안에서 commit + push (git -C로 디렉토리 이동 없이)
# env.yml에서 {github.owner}, {github.repo}, {default_reviewer} 로드
git -C "$WORKTREE_DIR" add .
git -C "$WORKTREE_DIR" commit -m "{type}: {요약}"
GH_TOKEN=$(cat "${PROJECT_DIR}/.gh-token" | tr -d '[:space:]')
git -C "$WORKTREE_DIR" push \
  "https://user:${GH_TOKEN}@github.com/{github.owner}/{github.repo}.git" \
  "HEAD:refs/heads/{branch_name}"

# 4. PR 생성 (label은 브랜치 type에 따라: fix→fix, improve→enhancement, feat→feature)
GH_TOKEN=$GH_TOKEN gh pr create --repo {github.owner}/{github.repo} \
  --title "{type}: {요약}" --body "..." --head "{branch_name}" \
  --label "{type_label}" \
  --reviewer "{default_reviewer}"

# 5. worktree 정리
git worktree remove "$WORKTREE_DIR"

# 6. main 작업 디렉토리 복원
git -C "$PROJECT_DIR" checkout -- {modified_files}
# 새로 생성한 untracked 파일이 있으면 삭제
```

3. PR 본문은 `.claude/templates/pr-template.md` 템플릿을 사용합니다.

### Step 8: 결과 보고

1. PR URL을 표시합니다.
2. 변경 요약을 보고합니다.
3. "main 브랜치에서 계속 작업할 수 있습니다." 안내합니다.

---

## 주의사항

- main 작업 디렉토리의 브랜치는 절대 변경하지 않습니다 (worktree 방식).
- worktree 생성 실패 시 (동일 브랜치 존재 등) 기존 worktree를 제거 후 재시도합니다.
- PR 생성 후 worktree는 즉시 정리합니다.
- GH_TOKEN은 원본 프로젝트 디렉토리의 `.gh-token`에서 절대경로로 읽습니다.
