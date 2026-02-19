# Changelog

## 2026-02-19

- feat: 하드코딩된 조직/배포 변수를 `env.yml`로 추출 + label/reviewer 필수 규칙 추가 (`840f247`)
- fix: worktree 정리 시 untracked 신규 파일 삭제 명령 추가 + PR 생성 절차에 CHANGELOG 단계 명시 (`605b0ac`)

## 2026-02-13

- fix: sync-drive Step 2 전략 기반 재작성 — Download Event / Clipboard(폴링) / gviz 계층 도입, 다중 탭 지원, 입력 검증, 감사 로그, 에러 유형별 처리 (#16)
- feat: `/upload-drive` 독립 커맨드 분리 — 업로드 로직 Single Source of Truth 확립
- Changelog 분리 + git pull rebase 복구 + sisyphus 제거 + worktree 후 main 복원 추가
- `/admin` 워크플로우에 Changelog 업데이트 단계 추가 (`f182191`)
- PR 리뷰 피드백 답글 규칙 추가 (`4ab4d33`)
- 에이전트 역할 자동 제안 + 보안 개선 (`b88f39c`)
- Admin 커맨드 + Worktree 브랜치 격리 (`105343a`)
- 프로젝트 공유 명령 추가 (`3f4e98b`)

## 2026-02-12

- 초기 버전 — 6역할 에이전트 팀, 전체 파이프라인 등 (`9bb838d`)
