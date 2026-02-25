# Changelog

## 2026-02-25

- improve: Google Docs 원본으로 4개 템플릿 전면 교체 — product-brief/business-spec/pretotype-spec/product-spec TEMPLATE.md를 Google Docs export 원본(.firecrawl/templates/*-raw.txt)에서 markdown으로 변환, 작성 가이드+섹션별 예시(Maththera)+AI 인터페이스 참조 포함, 기존 AI 생성 템플릿 대체

## 2026-02-23

- improve: 템플릿/인스턴스 아키텍처 도입 — drive-sources.yaml을 템플릿(tracked)으로 유지하고 제품별 인스턴스(gitignored)로 분리, skip-worktree 제거로 git pull 템플릿 업데이트 수신 가능, 마이그레이션 v1→v2에서 mv→cp 전환 및 템플릿 복원, 마이그레이션 후 상태 재평가 규칙 추가
- improve: v1_to_v2 마이그레이션 개선 — 기존/신규 워크스페이스 시나리오 분기, product_id 충돌 검사 및 해결 옵션(다른 이름/자동 접미사/덮어쓰기) 추가, 사용자 확인 루프 강화 ([`8e8402f`](https://github.com/boydcog/prd-generator-template/commit/8e8402f))
- fix: Qodo 리뷰 반영 — product_id 검증(경로 순회 방지), `shopt` 제거(sh 호환), 마이그레이션 로직 단순화(BEFORE/AFTER 비교 → 현재 vs 타겟 비교), v1_to_v2 신규 워크스페이스 처리, switch-product 인자 검증 추가 ([`cbf59c9`](https://github.com/boydcog/prd-generator-template/commit/cbf59c9))
- improve: 멀티 제품 지원 — `product_id` 네임스페이스로 하나의 워크스페이스에서 여러 제품 관리, `/switch-product` 커맨드 신규 추가, 스키마 v2 마이그레이션 시스템 도입 (MIGRATION_NEEDED 감지 → Claude가 `.claude/migrations/` 지침 실행) ([`e31bba9`](https://github.com/boydcog/prd-generator-template/commit/e31bba9))
- improve: Live Meeting Mode 도입 — Wave 넘버링 폐지, 회의/판정/비평/통합 4단계 구조로 전환, Peer Messaging Protocol 추가, judge 역할 신설, peer_discussions JSON 계약 추가, 전문가 토론 요약 섹션 추가 ([`099d5dd`](https://github.com/boydcog/prd-generator-template/commit/099d5dd))

## 2026-02-20

- improve: 에이전트 팀에 비판적 검토(critique) Wave 1.5 추가 — Wave 1 결과 교차 검토, 논리적 오류/모순/누락 식별, synth 입력 품질 향상 ([`617d0e8`](https://github.com/boydcog/prd-generator-template/commit/617d0e8))

## 2026-02-19

- improve: 템플릿 구조 감사 — 다중 문서 유형 지원, Windows 호환성 개선, gitignore 보완, 모델 선택 스펙 조정, PR 템플릿 통합 ([`a31ee67`](https://github.com/boydcog/prd-generator-template/commit/a31ee67))
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
