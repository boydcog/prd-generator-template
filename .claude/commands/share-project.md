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

### Step 3: 브랜치 생성

1. `git pull origin main`
2. 프로젝트 이름을 kebab-case로 변환: `{project_name}` → `{branch_slug}`
   - 예: "Maththera" → `maththera`, "My App 2.0" → `my-app-2-0`
3. `git checkout -b project/{branch_slug}`
   - 이미 존재하면: `project/{branch_slug}-v{version}`

### Step 4: 공유 대상 파일 추가

`git add -f`로 gitignore된 파일을 강제 추가:

```bash
# 프로젝트 메타데이터
git add -f .claude/state/project.json
git add -f .claude/state/sync-ledger.json
git add -f .user-identity

# 생성된 문서 (artifacts 전체)
git add -f .claude/artifacts/

# tracked 파일 중 변경된 템플릿만 포함 (구체적 경로 지정)
git add CLAUDE.md README.md
git add .claude/commands/ .claude/templates/ .claude/spec/ .claude/manifests/
```

**절대 추가하지 않는 파일:**
- `.gh-token` (민감 정보)
- `.claude/knowledge/evidence/chunks/` (대용량 청크)
- `.sisyphus/` (내부 이력)
- `.claude/state/pending-issues/` (이미 이슈로 등록됨)

### Step 5: README Changelog 업데이트

PR 생성 전에 `README.md`의 Changelog 섹션에 프로젝트 공유 항목을 추가합니다:

```markdown
<details>
<summary>project: {project_name} — {document_type} v{version} ({날짜})</summary>

- 프로젝트 공유: {project_name}
- 문서 유형: {document_type}
- 문서 버전: v{version}
- 작성자: {user_name}
- 포함 파일: {file_count}개

</details>
```

- 기존 Changelog 항목 위에 prepend합니다 (최신이 위).
- 이 항목은 `project/` 브랜치에만 포함됩니다 (main에 머지하지 않으므로 main의 Changelog에는 영향 없음).

### Step 6: 커밋

```bash
git commit -m "project: {project_name} — {document_type} v{version}"
```

### Step 7: PR 생성

**중요: `gh auth setup-git`으로 git credential을 설정한 뒤 push/PR을 실행합니다.**
브라우저 인증이나 `gh auth login` 등 interactive 플로우를 사용하지 않습니다.

```bash
# gh를 git credential helper로 설정 (GH_TOKEN으로 인증)
GH_TOKEN=$(cat .gh-token) gh auth setup-git

# push 및 PR 생성
git push -u origin project/{branch_slug}
GH_TOKEN=$(cat .gh-token) gh pr create ...
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

### Step 8: main 복귀 (필수)

PR 생성 성공/실패와 관계없이 **반드시** main으로 복귀합니다:

```bash
git checkout main || git checkout -f main
git pull origin main
```

에러 발생 시에도 이 단계는 반드시 실행합니다 (CLAUDE.md 브랜치 워크플로우 안전 장치와 동일).

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
