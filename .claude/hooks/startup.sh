#!/bin/bash
# SessionStart hook: 환경 감지 + 가능한 자동 설정 + 상태 보고
# 원칙: 감지는 여기서, 설치/대화는 Claude가 처리
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
  STATUS="$STATUS\nOK 사용자: $USER_NAME"
else
  STATUS="$STATUS\nWARN 사용자 미설정"
fi

# ──────────────────────────────────────
# 1. 의존성 감지 (설치 시도하지 않음)
# ──────────────────────────────────────
HAS_GIT="false"
HAS_GH="false"
HAS_BREW="false"

command -v git &>/dev/null && HAS_GIT="true"
command -v gh &>/dev/null && HAS_GH="true"
command -v brew &>/dev/null && HAS_BREW="true"

if [ "$HAS_GIT" = "true" ]; then
  STATUS="$STATUS\nOK git 설치됨"
else
  STATUS="$STATUS\nFAIL git 미설치"
fi

if [ "$HAS_GH" = "true" ]; then
  STATUS="$STATUS\nOK gh CLI 설치됨"
else
  STATUS="$STATUS\nFAIL gh CLI 미설치"
fi

if [ "$HAS_BREW" = "true" ]; then
  STATUS="$STATUS\nOK Homebrew 설치됨"
else
  STATUS="$STATUS\nWARN Homebrew 미설치"
fi

# ──────────────────────────────────────
# 2. git repo 확인 / 자동 설정
#    (git이 있을 때만 실행)
# ──────────────────────────────────────
HTTPS_URL="https://github.com/boydcog/prd-generator-template.git"
SSH_URL="git@github.com:boydcog/prd-generator-template.git"
GIT_READY="false"

if [ "$HAS_GIT" = "true" ]; then
  if [ ! -d ".git" ]; then
    # ZIP 배포 → git 초기화 (HTTPS 우선, SSH 폴백)
    git init 2>/dev/null
    git remote add origin "$HTTPS_URL" 2>/dev/null || true
    if git fetch origin 2>/dev/null; then
      git reset origin/main 2>/dev/null || true
      git checkout -b main 2>/dev/null || true
      git branch -u origin/main main 2>/dev/null || true
      GIT_READY="true"
      STATUS="$STATUS\nOK git 저장소 초기화 + remote 연결 완료 (HTTPS)"
    else
      # HTTPS 실패 → SSH 폴백
      git remote set-url origin "$SSH_URL" 2>/dev/null || true
      if git fetch origin 2>/dev/null; then
        git reset origin/main 2>/dev/null || true
        git checkout -b main 2>/dev/null || true
        git branch -u origin/main main 2>/dev/null || true
        GIT_READY="true"
        STATUS="$STATUS\nOK git 저장소 초기화 + remote 연결 완료 (SSH)"
      else
        STATUS="$STATUS\nWARN git fetch 실패 (네트워크 또는 인증 문제)"
      fi
    fi
  else
    GIT_READY="true"
    # remote URL 확인 — HTTPS 우선으로 교정
    CURRENT_REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
    if [ -z "$CURRENT_REMOTE" ]; then
      git remote add origin "$HTTPS_URL" 2>/dev/null || true
      STATUS="$STATUS\nOK remote origin 추가됨 (HTTPS)"
    elif [ "$CURRENT_REMOTE" = "$SSH_URL" ]; then
      git remote set-url origin "$HTTPS_URL" 2>/dev/null || true
      STATUS="$STATUS\nOK remote URL → HTTPS 전환"
    elif [ "$CURRENT_REMOTE" != "$HTTPS_URL" ]; then
      git remote set-url origin "$HTTPS_URL" 2>/dev/null || true
      STATUS="$STATUS\nOK remote URL 업데이트됨"
    fi
  fi

  # main 브랜치 강제 복귀
  if [ "$GIT_READY" = "true" ]; then
    CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
    if [ -n "$CURRENT_BRANCH" ] && [ "$CURRENT_BRANCH" != "main" ]; then
      git checkout main 2>/dev/null || git checkout -f main 2>/dev/null || true
      STATUS="$STATUS\nWARN $CURRENT_BRANCH → main 자동 전환"
    fi
  fi

  # ──────────────────────────────────────
  # 2-2. 잔여 worktree 정리
  # ──────────────────────────────────────
  WORKTREE_DIR="${PROJECT_DIR}/../.worktrees"
  if [ -d "$WORKTREE_DIR" ]; then
    # 잔여 worktree 자동 정리 (이전 세션에서 정리 안 된 것)
    git worktree prune 2>/dev/null || true
    REMAINING=$(ls -d "$WORKTREE_DIR"/*/ 2>/dev/null | wc -l | tr -d ' ')
    if [ "$REMAINING" -gt 0 ]; then
      for wt in "$WORKTREE_DIR"/*/; do
        [ -d "$wt" ] && git worktree remove --force "$wt" 2>/dev/null || true
      done
      STATUS="$STATUS\nWARN 잔여 worktree ${REMAINING}개 정리됨"
    fi
    # 빈 디렉토리 삭제
    rmdir "$WORKTREE_DIR" 2>/dev/null || true
  fi

  # git pull
  if [ "$GIT_READY" = "true" ]; then
    PULL_RESULT=$(git pull origin main 2>&1 || echo "pull-failed")
    if echo "$PULL_RESULT" | grep -q "pull-failed"; then
      STATUS="$STATUS\nWARN git pull 실패"
    else
      STATUS="$STATUS\nOK git pull 완료"
    fi
  fi

  # manifests 보호
  if [ "$GIT_READY" = "true" ]; then
    for f in .claude/manifests/*.yaml; do
      [ -f "$f" ] && git update-index --skip-worktree "$f" 2>/dev/null || true
    done
  fi
fi

# ──────────────────────────────────────
# 3. GH_TOKEN 로드
# ──────────────────────────────────────
GH_TOKEN_LOADED="false"
if [ -f ".gh-token" ]; then
  TOKEN_CONTENT=$(cat .gh-token | tr -d '[:space:]')
  if [ -n "$TOKEN_CONTENT" ]; then
    chmod 600 .gh-token
    export GH_TOKEN="$TOKEN_CONTENT"
    GH_TOKEN_LOADED="true"
    STATUS="$STATUS\nOK GitHub 토큰 로드 완료"
  else
    STATUS="$STATUS\nWARN .gh-token 파일이 비어있음"
  fi
elif [ -n "${GH_TOKEN:-}" ]; then
  GH_TOKEN_LOADED="true"
  STATUS="$STATUS\nOK GitHub 토큰 (환경변수)"
else
  STATUS="$STATUS\nFAIL GitHub 토큰 없음"
fi

# ──────────────────────────────────────
# 4. 프로젝트 상태 확인
# ──────────────────────────────────────
HAS_PROJECT="false"
HAS_SOURCES="false"
HAS_EVIDENCE="false"
HAS_PRD="false"

[ -f ".claude/state/project.json" ] && HAS_PROJECT="true"
if [ -f ".claude/manifests/drive-sources.yaml" ]; then
  grep -q "^  - name:" ".claude/manifests/drive-sources.yaml" 2>/dev/null && HAS_SOURCES="true"
fi
[ -f ".claude/knowledge/evidence/index/sources.jsonl" ] && HAS_EVIDENCE="true"
ls .claude/artifacts/prd/v*/PRD.md &>/dev/null 2>&1 && HAS_PRD="true"

# 추천 액션 (auto-generate 중심 — 내부에서 상태별 Phase 자동 판단)
NEXT_ACTION=""
if [ "$HAS_PROJECT" = "false" ]; then
  NEXT_ACTION="auto-generate"
elif [ "$HAS_PRD" = "true" ]; then
  NEXT_ACTION="sync-drive-or-update"
else
  NEXT_ACTION="auto-generate"
fi

# ──────────────────────────────────────
# 출력: Claude에게 컨텍스트 전달
# ──────────────────────────────────────
echo "=== PRD Generator 시작 ==="
echo "플랫폼: macOS/Linux"
echo -e "$STATUS"
echo ""
echo "의존성:"
echo "  git: $HAS_GIT"
echo "  gh: $HAS_GH"
echo "  brew: $HAS_BREW"
echo ""
echo "프로젝트 상태:"
echo "  project.json: $HAS_PROJECT"
echo "  Drive 소스: $HAS_SOURCES"
echo "  증거(evidence): $HAS_EVIDENCE"
echo "  PRD 생성됨: $HAS_PRD"
echo "  GH 토큰: $GH_TOKEN_LOADED"
echo "  git 연결: $GIT_READY"
echo "  사용자: ${USER_NAME:-미설정}"
echo "  추천 액션: $NEXT_ACTION"
echo "==========================="

exit 0
