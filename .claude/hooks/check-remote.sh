#!/bin/bash
# check-remote.sh — 매 메시지마다 원격 업데이트 확인 (UserPromptSubmit hook)

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"
STATE_DIR="${PROJECT_DIR}/.claude/state"
RATE_LIMIT_FILE="${STATE_DIR}/_last_remote_check.txt"
DISMISSED_FILE="${STATE_DIR}/_dismissed_update.txt"

# 1. Rate limiting: 5분(300초) 간격으로만 실행
if [ -f "$RATE_LIMIT_FILE" ]; then
  LAST_CHECK=$(cat "$RATE_LIMIT_FILE" 2>/dev/null || echo 0)
  ELAPSED=$(( $(date +%s) - LAST_CHECK ))
  [ "$ELAPSED" -lt 300 ] && exit 0
fi

# 2. git fetch (조용히)
cd "$PROJECT_DIR" || exit 0
git fetch origin main --quiet 2>/dev/null || exit 0

# 타임스탬프 업데이트
echo "$(date +%s)" > "$RATE_LIMIT_FILE"

# 3. 업데이트 여부 확인
BEHIND=$(git rev-list HEAD..origin/main --count 2>/dev/null)
[ -z "$BEHIND" ] || [ "$BEHIND" -eq 0 ] && exit 0

# 4. 이미 dismissed된 커밋인지 확인
LATEST_HASH=$(git rev-parse origin/main 2>/dev/null)
DISMISSED=$(cat "$DISMISSED_FILE" 2>/dev/null || echo "")
[ "$LATEST_HASH" = "$DISMISSED" ] && exit 0

# 5. 알림 출력 (Claude가 사용자에게 전달)
COMMIT_DATE=$(git log origin/main -1 --format="%cd" --date=format:'%Y-%m-%d %H:%M' 2>/dev/null)
COMMIT_MSG=$(git log origin/main -1 --format="%s" 2>/dev/null)
echo "=== REMOTE_UPDATE ==="
echo "STATUS: update_available"
echo "HASH: ${LATEST_HASH}"
echo "DATE: ${COMMIT_DATE}"
echo "MSG: ${COMMIT_MSG}"
echo "BEHIND: ${BEHIND}"
echo "=== END_REMOTE_UPDATE ==="
