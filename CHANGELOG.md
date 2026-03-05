# Changelog

## 2026-03-05

- improve: Issue #48/#50 — 사전 대화(Phase 0) + 킬게이트 플로우 개선 — `auto-generate.md`에 Phase 0(템플릿 기반 섹션 인터뷰) 신설: 모드 A(이전 단계 문서 존재 시 확인만)/모드 B(첫 실행 전체 인터뷰), draft-inputs.json으로 출처 분류(user/prior/research) 후 synth 에이전트 우선순위 반영; Phase 3.5(Master Doc Cascade + S4 Design/Tech Spec→Product Spec 화면별 선택 추출) 신설; `gate-review.md`에 단계 전환 전 담당자 확인 단계 추가, 킬게이트 로그 파일(`.claude/artifacts/{product}/gate-review/S{N}-{timestamp}.md`) 저장, S4 완료 후 3개 문서 핸드오프 안내, S5 기준 처리 + 아니요 케이스 Step 7 분리; `run-research.md` synth에 draft-inputs 3단계 출처 처리 추가; `CLAUDE.md` 에러핸들링 섹션 Issue 자동/PR 확인 후 규칙 §8과 통일; Product Spec 템플릿 §3-2에 화면별 Design Spec 참조 원칙 컬럼 추가 (closes [#48](https://github.com/boydcog/prd-generator-template/issues/48), [#50](https://github.com/boydcog/prd-generator-template/issues/50))
- fix: agents/ 출력 경로 버전화 — 단일 공유 디렉토리에서 버전별 독립 경로(`{doc_type}/v{N}/agents/`)로 변경하여 다수 문서 생성 시 덮어쓰기 방지; run-research.md·agent-team-spec.md·verify.md 에이전트 출력 경로 전체 교체, project-defaults.yaml agents_dir DEPRECATED 표기, CLAUDE.md 파일 구조 섹션 업데이트, v3_to_v4.md 마이그레이션 지침 신규 작성, _target_version.txt v4로 갱신 (issues [#49](https://github.com/boydcog/prd-generator-template/issues/49), [#50](https://github.com/boydcog/prd-generator-template/issues/50)) ([`e9fecb5`](https://github.com/boydcog/prd-generator-template/commit/e9fecb5))
- fix: PR 자동 생성 방지 — CLAUDE.md 연속 실행 원칙에 "PR 생성 항상 예외" 명시 추가; 섹션 8 자동 Issue/PR 규칙에서 Issue 자동 생성은 유지하되 PR은 사용자 확인 후 생성으로 분리 ([`e9fecb5`](https://github.com/boydcog/prd-generator-template/commit/e9fecb5))
- fix: Qodo 리뷰 2차 반영 — run-research.md 에이전트 목록 테이블 경로 `{doc_type}/v{N}/agents/` → 전체 경로 `.claude/artifacts/{active_product}/{output_dir_name}/v{N}/agents/`로 교체(bug #2); 출력 섹션 플레이스홀더 `{output_dir}` → `{output_dir_name}`, `{output_file}` → `{output_file_name}` 통일(bug #3); verify.md 기본 document_type `prd` → `project-defaults.yaml`의 `default_document_type` 참조(현재: `product-brief`) + 예시 경로 수정(bug #5); v3_to_v4.md Step 2 `agents/` → `agents/_legacy/` 직접 이동 불가 버그 → 임시명 4단계 방식으로 수정(bug #4); Step 3 경로 `.claude/` prefix 추가 + `prd` 기본값 → `product-brief` 수정(bug #6); README 핵심 기능 #16 에이전트 산출물 경로 구 경로 → `{doc_type}/v{N}/agents/` 형식으로 수정(bug #1) ([`f895ad8`](https://github.com/boydcog/prd-generator-template/commit/f895ad8))
- fix: Qodo 리뷰 반영 — agent-team-spec.md 출력 파일 경로 테이블 전체에 `{active_product}` 추가(biz/marketing/research/tech/pm/critique/debate 모두), synth 경로 `{output_dir}` → `{active_product}/{output_dir_name}` 정합성 수정, README 핵심 기능 #16에 `/verify` 항목 신설 ([`ff1330b`](https://github.com/boydcog/prd-generator-template/commit/ff1330b))
- fix: verify.md debate/critique 경로 `{active_product}` 누락 수정 — `.claude/artifacts/agents/debate/...` → `.claude/artifacts/{active_product}/agents/debate/...` (이전 경로로는 파일을 찾지 못해 검증이 항상 스킵됨), critique.json/md 동일 수정 ([`d3909ce`](https://github.com/boydcog/prd-generator-template/commit/d3909ce))
- fix: run-research.md synth 전문가 토론 요약(부록 E) 위치 명확화 — 템플릿 원본 섹션 사이가 아닌 문서 말미(Append)에 배치하도록 Step 7 설명 보강, 불변 규칙의 적용 범위(템플릿 원본 섹션 구간만) 명시 ([`d3909ce`](https://github.com/boydcog/prd-generator-template/commit/d3909ce))

## 2026-03-04

- fix: PR 리뷰 피드백 자동 반영 방지 — CLAUDE.md `PR 검증 및 적용 규칙` 2단계를 "즉시 적용 필수" → "수정 계획 보고 후 사용자 승인 대기"로 변경; `PR 리뷰 피드백 반영 규칙`에 승인 단계(Step 2-3) 추가, 사용자 승인 없이 push 금지 원칙 명시 ([`6cda706`](https://github.com/boydcog/prd-generator-template/commit/6cda706))
- improve: Design Spec·Tech Spec 템플릿 내용 Drive 원본 형식으로 정렬 — Design Spec 복잡한 마크다운 테이블 구조 → Drive 통합버전 단순 문단+불릿 형식으로 교체, [조정 포인트] 인라인 주석으로 타겟별 조정값 안내; Tech Spec 테이블 과잉 → 불릿 기반 간결 구조로 교체; 예시 파일명 하이픈 구분 → 공백 구분으로 통일(`기억생생 Design Spec 예시.md`, `HeartBeat Sync Tech Spec 예시.md`); 가이드 파일 11항목/4항목 구조 기반으로 전면 교체
- improve: Design Spec 템플릿 §1-§6 구조 → 항목 1-11 emocog 표준 구조로 완전 교체 — gluestack-ui v2 + Tailwind v4 + Framer Motion 기술 스택 고정, 항목 1-5 prefill(변경 금지), 항목 6-9 타겟별 조정 변수 제공, 항목 10-11 완전 빈칸 프롬프트; Tech Spec §1-§8 상세 명세 → 항목 1-4 최소 가드레일 구조로 교체 — LLM 자율 설계 철학 적용, Data Modeling Rules·Implementation Rules 이모코그 표준 prefill; 기억생생 Design Spec 예시(시니어 WCAG AAA 조정) + HeartBeat Sync Tech Spec 예시(BLE 심박 모니터링) 신규 추가 ([`3f49248`](https://github.com/boydcog/prd-generator-template/commit/3f49248))
- improve: 반복적 재료 추가 + 이후 단계 캐스케이드 업데이트 플로우 구현 — CLAUDE.md `sync-drive-or-update`를 3-way 선택지(이어서 진행/재료 추가/전체 재생성)로 확장, `메시지 수신 시 규칙` 신규 섹션 추가(UserPromptSubmit hook 원격 업데이트 알림 처리); `auto-generate.md`에 재료 추가 모드(M-1~M-5) 신설(새 소스 추가→동기화→현재 문서 업데이트→이후 단계 캐스케이드 제안→완료 보고); `UserPromptSubmit` hook 등록(`settings.json`), `check-remote.sh` 신규 생성(5분 rate limit + dismissed 추적); README.md 명령어 개수 표기 수정

- fix: Qodo 리뷰 반영 — README 스펙 템플릿 v2.0 설명 추가, S4 Gate 기준 콘텐츠 명세·EXT 매핑으로 갱신, Product Spec §0 Stage 3 경량 섹션 누락 수정, Tech Spec '전재→전제' 오탈자 수정, Design/Tech Spec Gate 번호체계 정합성 수정, CHANGELOG 커밋 링크 추가 ([`c60f61a`](https://github.com/boydcog/prd-generator-template/commit/c60f61a))
- improve: Product Spec·Design Spec·Tech Spec 세 템플릿 책임 분리 재편 — Product Spec에 §0 Context Dump·§3 IA·§4 서비스 플로우 신설 및 §2 Task 분해 확장, §7을 디자인 프롬프트에서 데이터&외부연동(EXT 목록 포함)으로 재편; Design Spec을 ASCII 와이어프레임에서 실제 콘텐츠 명세 중심으로 전환(비주얼 방향성·이미지 DB 연결·마이크로인터랙션·접근성 기준 고도화); Tech Spec §1을 "전제 정보"로 재명칭, §2를 "최소 연동 구조"로 간소화, §3 API 명세에 Product Spec §7-3 외부 연동 매핑 열 추가 ([`a0c081e`](https://github.com/boydcog/prd-generator-template/commit/a0c081e2328a5c13d2dd995cffe5cadd2dbc8dd6))

## 2026-03-03

- fix: Qodo 리뷰 반영 — README MVP 기간 동기화(S3 4W→1W, S4 2W→0.5W, S5 3.5W), `mvp-process-spec.md` 존재하지 않는 docs 링크 제거, CHANGELOG 커밋 링크 누락 수정 ([`b8d2387`](https://github.com/boydcog/prd-generator-template/commit/b8d2387))
- improve: Apps Script 기준으로 MVP 프로세스 기간 동기화 — S3 Prototype 4W→1W, S4 Freeze 2W→0.5W, S5 MVP 3.5W 명시, Discovery(4W)/Delivery(4W) 페이즈 구조 추가, AI Agent 활동 맵(Research/Experiment/Build/Verify/Ship) 및 핵심 원칙(Kill First / 가설>문서 / AI 80%) 섹션 신설 (`mvp-process-spec.md`, `gate-review.md`) ([`380f0dd`](https://github.com/boydcog/prd-generator-template/commit/380f0dd956e99ec8e4bad959c8edfab553aadd7f))
- fix: Qodo 리뷰 반영 — 동적 역할 출력 경로 v1→`{active_product}` 수정, verify.md H2 매칭 정규화 로직 추가, CLAUDE.md에 런타임 플레이스홀더(`{active_product}`, `{product_id}`) 섹션 신설로 env.yml 키와 명확 구분, admin.md 구현 후 PR 즉시 올리던 방식을 로컬 검증 완료 후 사용자 확인 요청 방식으로 변경 + 비개발자 친화 언어 추가
- fix: `sync-drive.md` Download Event Capture 트리거 방식 수정 — `page.goto(exportUrl)` 사용 시 "Download is starting" 오류 발생 확인, Section 2-2(Google Docs) 및 2-4(대용량 데이터) 두 곳에서 `page.goto()` 대신 `page.evaluate()` 앵커 클릭 방식(`document.createElement('a') + a.click()`)으로 교체, `page.evaluate(() => location.href = ...)` 방식도 동작하지 않음을 명시적으로 주석으로 문서화 ([`9f758cf`](https://github.com/boydcog/prd-generator-template/commit/9f758cf))
- fix: Qodo 리뷰 반영 — README 핵심 기능에 `/sync-drive` 명시, CHANGELOG 커밋 링크 형식, sync-drive C6 제약표 앵커 클릭 정렬, Option A tempPath 변수 연결 ([`c6bf532`](https://github.com/boydcog/prd-generator-template/commit/c6bf532))

## 2026-02-27

- improve: Synth 에이전트 템플릿 적용 방식 개선 — `run-research.md` Synth 팀원 절차 Step 3를 "템플릿 구조 로드"에서 "템플릿 배치(선행 작업)"로 교체(템플릿을 출력 경로에 먼저 복사 후 편집), Step 8을 "통합 문서 작성"에서 "통합 문서 채우기(섹션별 순차 작성)"으로 교체(헤더·표 구조 불변 규칙, Edit 도구로 플레이스홀더만 교체, 전체 재작성 금지), Synth 프롬프트 통합 규칙 4번을 출력 경로에 복사된 파일을 직접 편집하는 방식으로 변경, 입력 파일 섹션 로컬 템플릿 주석 갱신

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
