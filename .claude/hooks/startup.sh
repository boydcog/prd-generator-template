#!/bin/bash
# SessionStart hook: git 설정, 의존성 확인, 토큰 로드, 상태 보고
set -euo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
cd "$PROJECT_DIR"

STATUS=""

# ──────────────────────────────────────
# 0. 사용자 아이덴티티 로드
# ──────────────────────────────────────
USER_NAME=""
if [ -f ".user-identity" ]; then
  USER_NAME=$(cat .user-identity | tr -d '\n')
  STATUS="$STATUS\n✅ 사용자: $USER_NAME"
else
  STATUS="$STATUS\n⚠️ 사용자 미설정 — 처음 사용 시 이름을 입력해주세요"
fi

# ──────────────────────────────────────
# 1. git 설치 확인
# ──────────────────────────────────────
if ! command -v git &>/dev/null; then
  if [[ "$OSTYPE" == "darwin"* ]]; then
    xcode-select --install 2>/dev/null || true
    STATUS="$STATUS\n⚠️ git 설치 중 (xcode-select). 완료 후 재시작 필요."
  elif command -v apt-get &>/dev/null; then
    sudo apt-get install -y git 2>/dev/null || true
    STATUS="$STATUS\n✅ git 설치 완료 (apt)"
  elif command -v brew &>/dev/null; then
    brew install git 2>/dev/null || true
    STATUS="$STATUS\n✅ git 설치 완료 (brew)"
  else
    STATUS="$STATUS\n⚠️ git을 수동으로 설치해주세요"
  fi
fi

# ──────────────────────────────────────
# 2. git repo 확인 / 전환
# ──────────────────────────────────────
REMOTE_URL="https://github.com/boydcog/prd-generator-template.git"

if [ ! -d ".git" ]; then
  if command -v git &>/dev/null; then
    git init 2>/dev/null
    git remote add origin "$REMOTE_URL" 2>/dev/null || true
    git fetch origin main 2>/dev/null || true
    git checkout -b main 2>/dev/null || true
    STATUS="$STATUS\n✅ git 저장소 초기화 + remote 연결 완료"
  fi
else
  # remote 확인 및 업데이트
  CURRENT_REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
  if [ -z "$CURRENT_REMOTE" ]; then
    git remote add origin "$REMOTE_URL" 2>/dev/null || true
    STATUS="$STATUS\n✅ remote origin 추가됨"
  fi
fi

# ──────────────────────────────────────
# 2-1. main 브랜치 강제 복귀
# ──────────────────────────────────────
if command -v git &>/dev/null && [ -d ".git" ]; then
  CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
  if [ -n "$CURRENT_BRANCH" ] && [ "$CURRENT_BRANCH" != "main" ]; then
    git checkout main 2>/dev/null || git checkout -f main 2>/dev/null || true
    STATUS="$STATUS\n⚠️ $CURRENT_BRANCH에서 main으로 자동 전환됨"
  fi
fi

# ──────────────────────────────────────
# 3. git pull (최신 룰 반영)
# ──────────────────────────────────────
if command -v git &>/dev/null && [ -d ".git" ]; then
  PULL_RESULT=$(git pull origin main 2>&1 || echo "pull-failed")
  if echo "$PULL_RESULT" | grep -q "pull-failed"; then
    STATUS="$STATUS\n⚠️ git pull 실패 (오프라인이거나 remote 미설정)"
  else
    STATUS="$STATUS\n✅ git pull 완료"
  fi
fi

# ──────────────────────────────────────
# 3-1. manifests 템플릿 보호 (skip-worktree)
#   tracked 파일이지만 프로젝트별 변경은 commit하지 않음
# ──────────────────────────────────────
if command -v git &>/dev/null && [ -d ".git" ]; then
  for f in .claude/manifests/*.yaml; do
    [ -f "$f" ] && git update-index --skip-worktree "$f" 2>/dev/null || true
  done
fi

# ──────────────────────────────────────
# 4. GH_TOKEN 로드 (gitignored 파일)
# ──────────────────────────────────────
GH_TOKEN_LOADED="false"
if [ -f ".gh-token" ]; then
  export GH_TOKEN=$(cat .gh-token | tr -d '[:space:]')
  GH_TOKEN_LOADED="true"
  STATUS="$STATUS\n✅ GitHub 토큰 로드 완료"
elif [ -n "${GH_TOKEN:-}" ]; then
  GH_TOKEN_LOADED="true"
  STATUS="$STATUS\n✅ GitHub 토큰 (환경변수에서 감지)"
else
  STATUS="$STATUS\n⚠️ GitHub 토큰 없음 — Boyd에게 .gh-token 파일을 슬랙으로 요청하세요"
fi

# ──────────────────────────────────────
# 5. 프로젝트 상태 확인
# ──────────────────────────────────────
HAS_PROJECT="false"
HAS_SOURCES="false"
HAS_EVIDENCE="false"
HAS_PRD="false"

[ -f ".claude/state/project.json" ] && HAS_PROJECT="true"
# sources가 비어있지 않은지 확인
if [ -f ".claude/manifests/drive-sources.yaml" ]; then
  if grep -q "^  - name:" ".claude/manifests/drive-sources.yaml" 2>/dev/null; then
    HAS_SOURCES="true"
  fi
fi
[ -f ".claude/knowledge/evidence/index/sources.jsonl" ] && HAS_EVIDENCE="true"
ls .claude/artifacts/prd/v*/PRD.md &>/dev/null 2>&1 && HAS_PRD="true"

# 다음 추천 액션
NEXT_ACTION=""
if [ "$HAS_PROJECT" = "false" ]; then
  NEXT_ACTION="init-project"
elif [ "$HAS_SOURCES" = "true" ] && [ "$HAS_EVIDENCE" = "false" ] && [ "$HAS_PRD" = "false" ]; then
  NEXT_ACTION="auto-generate"
elif [ "$HAS_SOURCES" = "true" ] && [ "$HAS_EVIDENCE" = "false" ]; then
  NEXT_ACTION="sync-drive"
elif [ "$HAS_EVIDENCE" = "true" ] && [ "$HAS_PRD" = "false" ]; then
  NEXT_ACTION="run-research"
elif [ "$HAS_EVIDENCE" = "true" ] && [ "$HAS_PRD" = "true" ]; then
  NEXT_ACTION="sync-drive-or-update"
else
  NEXT_ACTION="init-project"
fi

# ──────────────────────────────────────
# 출력: Claude에게 컨텍스트 전달
# ──────────────────────────────────────
echo "=== PRD Generator 시작 ==="
echo -e "$STATUS"
echo ""
echo "프로젝트 상태:"
echo "  project.json: $HAS_PROJECT"
echo "  Drive 소스: $HAS_SOURCES"
echo "  증거(evidence): $HAS_EVIDENCE"
echo "  PRD 생성됨: $HAS_PRD"
echo "  GH 토큰: $GH_TOKEN_LOADED"
echo "  사용자: ${USER_NAME:-미설정}"
echo "  추천 액션: $NEXT_ACTION"
echo "==========================="

exit 0
