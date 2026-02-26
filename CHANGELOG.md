# Changelog

## 2026-02-26

- docs: README에 MVP Kill Gate 프로세스(S1~S5 단계 흐름, Kill Gate 조건, 단계별 산출 문서 표) 및 `/gate-review` 기능 추가 — 핵심 기능 섹션에 항목 14 추가, "MVP 프로세스" 신규 섹션 삽입 (closes #34)

## 2026-02-26

- improve: Drive 소스 안내 추가 + 탭 이름에 MVP 단계 접두사 추가 — `init-project.md` 질문 7 직전에 mvp_stage별 추천 소스 유형 안내 블록 삽입(S1~S4 각 단계 추천 문서 유형, custom 제외); `upload-drive.md` 상위 탭 이름에 `{mvp_stage}` 접두사 추가(예: `S1 Business Spec`), 하위 탭도 연동하여 `S1 Business Spec - v1` 형식으로 변경, 버전 파싱 로직을 prefix 제거 후 숫자만 추출하도록 업데이트, 탭 snapshot 예시 및 naming_pattern 설명 갱신
- improve: Google Drive 업로드 탭 구조 개선 — 파일명을 `{project}-docs`에서 프로젝트명(`project.json`의 `name`)으로 변경, 탭 구조를 평탄한 단일 레벨에서 상위 탭(문서 타이틀) > 하위 탭(v1, v2, v3...) 계층 구조로 전환, Step 5-A에 상위 탭 이름 결정 로직(H1에서 프로젝트명 제거) 및 하위 탭 생성 절차 추가, Step 5-B에 상위 탭 존재 여부에 따른 분기 로직(신규/기존) 추가, 탭 UI 가이드에 하위 탭 추가 방법 및 snapshot 예시 보완, `project-defaults.yaml`의 `naming_pattern` 주석 업데이트
- improve: Synth 에이전트 로컬 템플릿 연결 수정 + mvp-process-spec.md 신규 추가 — `run-research.md` Synth 팀원 절차에 "템플릿 구조 로드" 스텝(Step 3) 삽입, 폴백을 `output_sections`로 통일(작성 가이드 폴백 제거), Synth 프롬프트 입력 파일 섹션에 `로컬 문서 템플릿` 항목 추가, 통합 규칙 #4를 로컬 템플릿 H2/H3 우선 사용으로 수정; `.claude/spec/mvp-process-spec.md` 신규 생성 — S1~S5 Kill Gate 프로세스, S2 Kill Gate 조건 명확화(AND/OR 논리 분리로 상호 배타적 조건 확립), 문서 의존 관계, project.json 상태 필드, 시스템 연동 섹션 포함
- improve: Google Docs 탭 기반 문서 통합 — 프로젝트 내 모든 문서를 하나의 마스터 문서(`{project}-docs`) 탭으로 관리, `drive-sources.yaml`에 `shared_drive_folder`·`docs_url` 필드 추가, `/upload-drive` Step 5를 최초/추가 분기 로직으로 재작성, 탭 UI 가이드 섹션 신설; Qodo 리뷰 반영 — `http.server` loopback 바인딩(`--bind 127.0.0.1`) 보안 강화, 서버 시작 후 `sleep 1` race condition 방지, 버전 충돌 방지를 위한 최고 버전 스캔(M+1) 로직, 덮어쓰기 절차 단순화(전체선택+붙여넣기로 원자적 교체)

## 2026-02-25

- improve: MVP 프로세스 단계 추적 + Kill Gate 시스템 도입 — `mvp_stage`/`stage_status`/`stage_history` 필드 추가, document-types.yaml을 S1~S4 5종+custom으로 전면 교체, `/gate-review` 신규 커맨드(기준별 Go/Stop 판정), startup.sh에 MVP 단계 상태 출력 + gate-review 추천 로직, v2→v3 마이그레이션(legacy 타입→custom 변환)
- improve: S1~S4 전 단계 작성 가이드 + 빈 템플릿 신규 추가 — Business Spec, Pretotype Spec, Product Brief(예시 포함), Product Spec, Design Spec, Tech Spec 총 6종. Zero-Design-Handoff 철학 기반 Design Spec, AI Rules 가드레일 기반 Tech Spec 포함. 이모코그 AI MVP 개발 프로세스 v1.0 인계 패키지 완성

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
