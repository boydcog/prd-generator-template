# Changelog

## 2026-02-19

- improve: 템플릿 구조 감사 — 다중 문서 유형 지원, Windows 호환성 개선, gitignore 보완, 모델 선택 스펙 조정, PR 템플릿 통합 ([`{commit_short}`](https://github.com/boydcog/prd-generator-template/commit/{commit_short}))
- improve: 에이전트 모델 선택 사양서 추가 — Wave 1 기본 sonnet, Wave 2 기본 opus, 프로젝트/문서유형별 오버라이드 지원 ([`6cdccb5`](https://github.com/boydcog/prd-generator-template/commit/6cdccb5))
- feat: 하드코딩된 조직/배포 변수를 `env.yml`로 추출 + label/reviewer/assignee 필수 규칙 + 다중 reviewer/assignee 지원 ([`840f247`](https://github.com/boydcog/prd-generator-template/commit/840f247))
- fix: worktree 정리 시 untracked 신규 파일 삭제(path traversal 방지 포함) + PR 절차에 CHANGELOG 단계 추가 + CHANGELOG shortlink 형식 도입 ([`605b0ac`](https://github.com/boydcog/prd-generator-template/commit/605b0ac))
- docs: README "빠른 시작"에 env.yml 설정 단계 추가 ([`1667d3d`](https://github.com/boydcog/prd-generator-template/commit/1667d3d))

## 2026-02-13

- fix: sync-drive Step 2 전략 기반 재작성 — Download Event / Clipboard(폴링) / gviz 계층 도입, 다중 탭 지원, 입력 검증, 감사 로그, 에러 유형별 처리 ([`b2989ea`](https://github.com/boydcog/prd-generator-template/commit/b2989ea))
- feat: `/upload-drive` 독립 커맨드 분리 — 업로드 로직 Single Source of Truth 확립 ([`6e86eac`](https://github.com/boydcog/prd-generator-template/commit/6e86eac))
- improve: Changelog 분리 + git pull rebase 복구 + sisyphus 제거 + worktree 후 main 복원 추가 ([`7be9cc3`](https://github.com/boydcog/prd-generator-template/commit/7be9cc3))
- `/admin` 워크플로우에 Changelog 업데이트 단계 추가 ([`f182191`](https://github.com/boydcog/prd-generator-template/commit/f182191))
- PR 리뷰 피드백 답글 규칙 추가 ([`4ab4d33`](https://github.com/boydcog/prd-generator-template/commit/4ab4d33))
- 에이전트 역할 자동 제안 + 보안 개선 ([`b88f39c`](https://github.com/boydcog/prd-generator-template/commit/b88f39c))
- Admin 커맨드 + Worktree 브랜치 격리 ([`105343a`](https://github.com/boydcog/prd-generator-template/commit/105343a))
- 프로젝트 공유 명령 추가 ([`3f4e98b`](https://github.com/boydcog/prd-generator-template/commit/3f4e98b))

## 2026-02-12

- 초기 버전 — 6역할 에이전트 팀, 전체 파이프라인 등 ([`9bb838d`](https://github.com/boydcog/prd-generator-template/commit/9bb838d))
