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
  USER_NAME=$(cat .user-identity | tr -d '
')
  STATUS="$STATUS
OK 사용자: $USER_NAME"
else
  STATUS="$STATUS
WARN 사용자 미설정"
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
  STATUS="$STATUS
OK git 설치됨"
else
  STATUS="$STATUS
FAIL git 미설치"
fi

if [ "$HAS_GH" = "true" ]; then
  STATUS="$STATUS
OK gh CLI 설치됨"
else
  STATUS="$STATUS
FAIL gh CLI 미설치"
fi

if [ "$HAS_BREW" = "true" ]; then
  STATUS="$STATUS
OK Homebrew 설치됨"
else
  STATUS="$STATUS
WARN Homebrew 미설치"
fi

# ──────────────────────────────────────
# 2. git repo 확인 / 자동 설정
#    (git이 있을 때만 실행)
# ──────────────────────────────────────
# env.yml에서 GitHub owner/repo 로드
ENV_FILE="env.yml"
if [ -f "$ENV_FILE" ]; then
  GH_OWNER=$(grep -E '^[[:space:]]*owner:' "$ENV_FILE" | head -1 | sed 's/.*owner:[[:space:]]*//' | sed 's/[[:space:]]*#.*//')
  GH_REPO=$(grep -E '^[[:space:]]*repo:' "$ENV_FILE" | head -1 | sed 's/.*repo:[[:space:]]*//' | sed 's/[[:space:]]*#.*//')
else
  GH_OWNER="boydcog"
  GH_REPO="prd-generator-template"
fi
HTTPS_URL="https://github.com/${GH_OWNER}/${GH_REPO}.git"
SSH_URL="git@github.com:${GH_OWNER}/${GH_REPO}.git"
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
      STATUS="$STATUS
OK git 저장소 초기화 + remote 연결 완료 (HTTPS)"
    else
      # HTTPS 실패 → SSH 폴백
      git remote set-url origin "$SSH_URL" 2>/dev/null || true
      if git fetch origin 2>/dev/null; then
        git reset origin/main 2>/dev/null || true
        git checkout -b main 2>/dev/null || true
        git branch -u origin/main main 2>/dev/null || true
        GIT_READY="true"
        STATUS="$STATUS
OK git 저장소 초기화 + remote 연결 완료 (SSH)"
      else
        STATUS="$STATUS
WARN git fetch 실패 (네트워크 또는 인증 문제)"
      fi
    fi
  else
    GIT_READY="true"
    # remote URL 확인 — HTTPS 우선으로 교정
    CURRENT_REMOTE=$(git remote get-url origin 2>/dev/null || echo "")
    if [ -z "$CURRENT_REMOTE" ]; then
      git remote add origin "$HTTPS_URL" 2>/dev/null || true
      STATUS="$STATUS
OK remote origin 추가됨 (HTTPS)"
    elif [ "$CURRENT_REMOTE" = "$SSH_URL" ]; then
      git remote set-url origin "$HTTPS_URL" 2>/dev/null || true
      STATUS="$STATUS
OK remote URL → HTTPS 전환"
    elif [ "$CURRENT_REMOTE" != "$HTTPS_URL" ]; then
      git remote set-url origin "$HTTPS_URL" 2>/dev/null || true
      STATUS="$STATUS
OK remote URL 업데이트됨"
    fi
  fi

  # main 브랜치 강제 복귀
  if [ "$GIT_READY" = "true" ]; then
    CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
    if [ -n "$CURRENT_BRANCH" ] && [ "$CURRENT_BRANCH" != "main" ]; then
      git checkout main 2>/dev/null || git checkout -f main 2>/dev/null || true
      STATUS="$STATUS
WARN $CURRENT_BRANCH → main 자동 전환"
    fi
  fi

  # ──────────────────────────────────────
  # 2-2. 잔여 worktree 정리
  # ──────────────────────────────────────
  WORKTREE_DIR="${PROJECT_DIR}/../.worktrees"
  if [ -d "$WORKTREE_DIR" ]; then
    git worktree prune 2>/dev/null || true
    CLEANED=0
    FAILED=0
    for wt in "$WORKTREE_DIR"/*/; do
      if [ -d "$wt" ]; then
        WT_NAME=$(basename "$wt")
        if git worktree remove --force "$wt" 2>/dev/null; then
          CLEANED=$((CLEANED + 1))
        else
          FAILED=$((FAILED + 1))
        fi
      fi
    done
    if [ "$CLEANED" -gt 0 ]; then
      STATUS="$STATUS
WARN 잔여 worktree ${CLEANED}개 정리됨"
    fi
    if [ "$FAILED" -gt 0 ]; then
      STATUS="$STATUS
WARN worktree ${FAILED}개 정리 실패"
    fi
    # 빈 디렉토리 삭제
    rmdir "$WORKTREE_DIR" 2>/dev/null || true
  fi

  # git pull (rebase 방식, 실패 시 stash + rebase + pop)
  if [ "$GIT_READY" = "true" ]; then
    PULL_RESULT=$(git pull --rebase origin main 2>&1 || echo "pull-failed")
    if echo "$PULL_RESULT" | grep -q "pull-failed"; then
      # rebase 진행 중이면 abort
      git rebase --abort 2>/dev/null || true
      # stash → rebase → pop
      STASHED="false"
      STASH_RESULT=$(git stash 2>&1)
      if echo "$STASH_RESULT" | grep -q "Saved working directory"; then
        STASHED="true"
      fi
      PULL_RESULT2=$(git pull --rebase origin main 2>&1 || echo "pull-failed")
      if echo "$PULL_RESULT2" | grep -q "pull-failed"; then
        git rebase --abort 2>/dev/null || true
        if [ "$STASHED" = "true" ]; then
          RESTORE_RESULT=$(git stash pop 2>&1 || echo "restore-failed")
          if echo "$RESTORE_RESULT" | grep -q "restore-failed"; then
            STATUS="$STATUS
WARN git pull 실패 (stash+rebase 복구 실패, stash 복원도 실패)"
          else
            STATUS="$STATUS
WARN git pull 실패 (stash+rebase 복구 실패, 로컬 변경 복원됨)"
          fi
        else
          STATUS="$STATUS
WARN git pull 실패 (stash+rebase 복구 실패)"
        fi
      else
        if [ "$STASHED" = "true" ]; then
          POP_RESULT=$(git stash pop 2>&1 || echo "pop-failed")
          if echo "$POP_RESULT" | grep -q "pop-failed\|CONFLICT"; then
            STATUS="$STATUS
WARN git pull 완료, stash pop 충돌 발생"
          else
            STATUS="$STATUS
OK git pull 완료 (stash+rebase 복구)"
          fi
        else
          STATUS="$STATUS
OK git pull 완료 (rebase)"
        fi
      fi
    else
      STATUS="$STATUS
OK git pull 완료"
    fi
    # 마이그레이션: 현재 적용 버전 vs 템플릿 요구 버전 비교
    CURRENT_SCHEMA=$(cat ".claude/state/_schema_version.txt" 2>/dev/null || echo "v1")
    TARGET_SCHEMA=$(cat ".claude/migrations/_target_version.txt" 2>/dev/null || echo "v1")
    if [ "$CURRENT_SCHEMA" != "$TARGET_SCHEMA" ]; then
      MIGRATION_NEEDED="${CURRENT_SCHEMA}_to_${TARGET_SCHEMA}"
      STATUS="$STATUS
WARN MIGRATION_NEEDED=$MIGRATION_NEEDED"
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
    STATUS="$STATUS
OK GitHub 토큰 로드 완료"
  else
    STATUS="$STATUS
WARN .gh-token 파일이 비어있음"
  fi
elif [ -n "${GH_TOKEN:-}" ]; then
  GH_TOKEN_LOADED="true"
  STATUS="$STATUS
OK GitHub 토큰 (환경변수)"
else
  STATUS="$STATUS
FAIL GitHub 토큰 없음"
fi

# ──────────────────────────────────────
# 4. 활성 제품 + 프로젝트 상태 확인
# ──────────────────────────────────────
ACTIVE_PRODUCT=""
if [ -f ".claude/state/_active_product.txt" ]; then
  ACTIVE_PRODUCT=$(cat ".claude/state/_active_product.txt" | tr -d '[:space:]')
  # product_id 검증: 영문자, 숫자, 하이픈, 언더스코어만 허용 (경로 순회 방지)
  if ! echo "$ACTIVE_PRODUCT" | grep -qE '^[a-zA-Z0-9_-]+$'; then
    STATUS="$STATUS
WARN 활성 제품 ID가 유효하지 않습니다 (허용: 영문자, 숫자, -, _)"
    ACTIVE_PRODUCT=""
  fi
fi

HAS_PROJECT="false"
HAS_SOURCES="false"
HAS_EVIDENCE="false"
HAS_DOCUMENT="false"
MIGRATION_NEEDED="${MIGRATION_NEEDED:-}"

if [ -n "$ACTIVE_PRODUCT" ]; then
  [ -f ".claude/state/${ACTIVE_PRODUCT}/project.json" ] && HAS_PROJECT="true"
  if [ -f ".claude/manifests/drive-sources-${ACTIVE_PRODUCT}.yaml" ]; then
    grep -q "^  - name:" ".claude/manifests/drive-sources-${ACTIVE_PRODUCT}.yaml" 2>/dev/null && HAS_SOURCES="true"
  fi
  [ -f ".claude/knowledge/${ACTIVE_PRODUCT}/evidence/index/sources.jsonl" ] && HAS_EVIDENCE="true"
  # 다중 문서 유형 감지 (find 사용 — bash/sh 모두 호환)
  if find ".claude/artifacts/${ACTIVE_PRODUCT}/" -path "*/v*/*.md" -maxdepth 4 2>/dev/null | grep -q .; then
    HAS_DOCUMENT="true"
  fi
fi

# 추천 액션 (auto-generate 중심 — 내부에서 상태별 Phase 자동 판단)
NEXT_ACTION=""
if [ -z "$ACTIVE_PRODUCT" ]; then
  NEXT_ACTION="select-product"
elif [ "$HAS_PROJECT" = "false" ]; then
  NEXT_ACTION="auto-generate"
elif [ "$HAS_DOCUMENT" = "true" ]; then
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
echo "  활성 제품: ${ACTIVE_PRODUCT:-미설정}"
echo "  project.json: $HAS_PROJECT"
echo "  Drive 소스: $HAS_SOURCES"
echo "  증거(evidence): $HAS_EVIDENCE"
echo "  문서 생성됨: $HAS_DOCUMENT"
echo "  GH 토큰: $GH_TOKEN_LOADED"
echo "  git 연결: $GIT_READY"
echo "  사용자: ${USER_NAME:-미설정}"
if [ -n "${MIGRATION_NEEDED:-}" ]; then
  echo "  RECOMMENDED_ACTION=migration"
  echo "  MIGRATION_NEEDED=$MIGRATION_NEEDED"
else
  echo "  추천 액션: $NEXT_ACTION"
fi
echo "==========================="

exit 0
