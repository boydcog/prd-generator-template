# /create-issue — GitHub Issue 자동 생성

사용자의 질문, 피드백, 기능 요청을 GitHub Issue로 등록합니다.

---

## 실행 절차

### Step 1: 사용자 아이덴티티 로드

1. `.user-identity` 파일에서 사용자 이름을 읽습니다.
2. 파일이 없으면: "이름을 입력해주세요." 요청 후 `.user-identity`에 저장.

### Step 2: 프로젝트 컨텍스트 로드

1. `.claude/state/project.json`에서 프로젝트 정보를 읽습니다:
   - `name` → `{project_name}`
   - `document_type` → `{document_type}` (없으면 `prd`)
2. `git rev-parse --short HEAD`로 현재 커밋 해시를 가져옵니다 → `{commit_short}`
3. 파일이 없으면 기본값 사용:
   - `project_name`: "미설정"
   - `document_type`: "prd"
   - `commit_short`: "unknown"

### Step 3: Issue 내용 준비

1. 사용자의 메시지/피드백을 `{user_message}`로 설정합니다.
2. 현재 대화 컨텍스트를 요약하여 `{context_summary}`로 설정합니다:
   - 최근 실행한 명령
   - 현재 작업 중인 내용
   - 관련 파일 경로
3. `.claude/templates/issue-template.md`를 읽고 변수를 치환합니다:
   - `{user_name}` ← `.user-identity`
   - `{timestamp}` ← 현재 시각 (ISO 8601)
   - `{project_name}` ← project.json
   - `{document_type}` ← project.json (기본값: prd)
   - `{commit_short}` ← `git rev-parse --short HEAD`
   - `{user_message}` ← 사용자 메시지
   - `{context_summary}` ← 컨텍스트 요약

### Step 4: 라벨 자동 분류

사용자 메시지를 분석하여 라벨을 결정합니다:

| 키워드 패턴 | 라벨 |
|-------------|------|
| "질문", "어떻게", "왜", "?" | `question` |
| "피드백", "의견", "느낌" | `feedback` |
| "기능", "추가해줘", "새로운" | `feature-request` |
| "버그", "오류", "에러", "이상" | `bug` |

여러 라벨이 해당되면 모두 적용합니다. 기본 라벨: `question`.

### Step 4.5: GH 토큰 확인

1. `.gh-token` 파일이 존재하면 → `GH_TOKEN` 환경변수에 로드 후 Step 5로.
2. `GH_TOKEN` 환경변수가 이미 설정되어 있으면 → Step 5로.
3. 둘 다 없으면:
   a. 사용자에게 안내:
      > "Issue를 GitHub에 등록하려면 토큰이 필요합니다. {contact.name}에게 {contact.channel}으로 요청하거나, 이미 갖고 계시면 붙여넣어 주세요."
   b. 사용자가 토큰을 제공하면 → `.gh-token`에 저장 → `gh auth status`로 검증 → Step 5.
   c. 사용자가 "나중에" / "스킵"을 선택하면 → "토큰 없이 로컬에 저장합니다." → Step 6(로컬 저장).

### Step 5: Issue 생성

**env.yml에서 변수를 로드합니다**: `github.owner`, `github.repo`, `github.default_assignee`

```bash
GH_TOKEN=$GH_TOKEN gh issue create \
  --repo {github.owner}/{github.repo} \
  --title "{issue_title}" \
  --body "{issue_body}" \
  --label "{labels}" \
  --assignee {default_assignee}
```

- `{issue_title}`: 사용자 메시지에서 핵심 내용을 추출하여 50자 이내로 작성
- `{issue_body}`: Step 3에서 생성한 템플릿 본문
- `{labels}`: Step 4에서 결정한 라벨 (쉼표 구분)

### Step 6: 결과 보고

```
Issue가 등록되었습니다:
  - 제목: {issue_title}
  - 라벨: {labels}
  - URL: {issue_url}
```

---

## GH 토큰 없을 때

토큰이 없으면 Issue를 로컬 파일로 저장합니다:

1. `.claude/state/pending-issues/` 디렉토리에 `issue-{timestamp}.md`로 저장.
2. "GitHub 토큰이 없어서 로컬에 저장했습니다. 토큰 설정 후 자동으로 업로드됩니다." 안내.

---

## 출력

| 파일 | 설명 |
|------|------|
| GitHub Issue | 원격 저장소에 생성된 이슈 |
| `.claude/state/pending-issues/issue-{timestamp}.md` | (토큰 없을 때) 로컬 저장 |
