# MVP 프로세스 전체 다이어그램

> 이모코그 AI MVP 프로세스 v1.0 — 시스템 종합 시각화
> 생성일: 2026-03-03

---

## 다이어그램 1 — 전체 단계 흐름 (Stage Pipeline)

5단계 Kill Gate 기반 프로세스 전체 흐름. 각 단계에서 생성되는 문서와 게이트 기준을 보여줍니다.

```mermaid
flowchart LR
    START(["🚀 세션 시작\n상태 감지"])

    START --> S1

    subgraph S1 ["S1 — Brief (Discovery)"]
        direction TB
        S1A["📋 Product Brief\nmaster doc"]
        S1B["📊 Business Spec\nstage doc"]
    end

    S1 --> GATE1{"Kill Gate 1\n📌 5개 기준\nproduct-brief"}

    GATE1 -->|"Go ✅"| S2
    GATE1 -->|"Kill ❌"| TERM1(["종료"])
    GATE1 -->|"Pivot 🔄"| S1

    subgraph S2 ["S2 — Pretotype (Experiment)"]
        direction TB
        S2A["🧪 Pretotype Spec\nstage doc"]
        S2B["XYZ 가설 + 실험 계획"]
        S2C["실험 후: 결과 기록"]
        S2A --> S2B --> S2C
    end

    S2 --> GATE2{"Kill Gate 2\n📌 4개 기준\npretotype-spec"}

    GATE2 -->|"Go ✅"| S3
    GATE2 -->|"Kill ❌"| TERM2(["종료"])
    GATE2 -->|"Pivot 🔄"| S2

    subgraph S3 ["S3 — Prototype (Build)"]
        direction TB
        S3A["📱 Product Spec\nmaster doc"]
        S3B["기능·IA·플로우·EXT 명세"]
        S3A --> S3B
    end

    S3 --> GATE3{"Kill Gate 3\n📌 4개 기준\nproduct-spec"}

    GATE3 -->|"Go ✅"| S4
    GATE3 -->|"Kill ❌"| TERM3(["종료"])
    GATE3 -->|"Pivot 🔄"| S3

    subgraph S4 ["S4 — Freeze (Handoff)"]
        direction TB
        S4A["🎨 Design Spec\nhandoff doc"]
        S4B["⚙️ Tech Spec\nhandoff doc"]
    end

    S4 --> GATE4{"Kill Gate 4\n📌 5개 기준\ndesign-spec"}

    GATE4 -->|"Go ✅"| S5
    GATE4 -->|"Kill ❌"| TERM4(["종료"])
    GATE4 -->|"Pivot 🔄"| S4

    S5(["🚀 S5 — MVP 개발 시작"])
```

---

## 다이어그램 2 — 세션 시작 & 상태 감지

세션이 시작될 때 Claude가 자동으로 수행하는 상태 감지 및 액션 결정 흐름입니다.

```mermaid
flowchart TD
    BOOT(["세션 시작\nClaude Code 실행"]) --> HOOK

    subgraph HOOK ["startup.sh / startup.ps1 (Hook)"]
        H1["플랫폼 감지\nmacOS → bash\nWindows → PowerShell"]
        H2["의존성 체크\ngit / gh / brew"]
        H3["git pull --rebase origin main"]
        H4["활성 제품 로드\n_active_product.txt"]
        H5["스키마 버전 체크\n_schema_version.txt vs _target_version.txt"]
        H6["worktree 잔여물 정리"]
        H7["GH_TOKEN 로드\n.gh-token → 환경변수"]
        H1 --> H2 --> H3 --> H4 --> H5 --> H6 --> H7
    end

    HOOK --> DEPOK{"의존성\nOK?"}
    DEPOK -->|"FAIL"| INSTALL["자동 설치\nbrew install git/gh\n(5분 타임아웃)"]
    INSTALL --> DEPOK
    DEPOK -->|"OK"| MIGOK{"마이그레이션\n필요?"}

    MIGOK -->|"v1→v3 등"| MIG["순차 마이그레이션 실행\n.claude/migrations/v1_to_v2.md\n.claude/migrations/v2_to_v3.md\n_schema_version.txt 단계별 업데이트"]
    MIG --> PRODOK

    MIGOK -->|"최신"| PRODOK{"활성 제품\n설정됨?"}

    PRODOK -->|"없음"| SELECT["제품 선택 or 신규 생성\n기존: .claude/state/ 하위 열거\n신규: 이름 입력 → /init-project"]
    SELECT --> RECOM

    PRODOK -->|"있음"| RECOM{"추천 액션\n(startup hook 출력)"}

    RECOM -->|"auto-generate"| AG["/auto-generate 실행"]
    RECOM -->|"gate-review"| GR["/gate-review 실행"]
    RECOM -->|"sync-drive-or-update"| SDU["기존 문서 버전 안내\n→ /auto-generate 실행"]
    RECOM -->|"select-product"| SELECT
```

---

## 다이어그램 3 — Auto-Generate 파이프라인 (상세)

`/auto-generate` 실행 시 내부적으로 이루어지는 전체 파이프라인입니다.

```mermaid
flowchart TD
    AG_START(["/auto-generate 실행"]) --> PRE

    subgraph PRE ["① 사전 검증 (verify — 구조 검사)"]
        PRE1["project.json 존재 확인"]
        PRE2["drive-sources-{product}.yaml 존재 확인"]
        PRE3["agent-team-spec / citation-spec / evidence-spec 존재 확인"]
        PRE1 --> PRE2 --> PRE3
    end

    PRE --> SYNC_DEC{"증거 최신?\n(sync-ledger 확인)"}
    SYNC_DEC -->|"오래됨/없음"| SYNC
    SYNC_DEC -->|"최신"| SKIP_SYNC["sync 스킵\n기존 evidence 재사용"]

    subgraph SYNC ["/sync-drive — Google Drive 증거 수집"]
        SD1["drive-sources-{product}.yaml 읽기\nsources[] 목록 로드"]
        SD2["Playwright 브라우저 실행\n(헤드리스)"]

        SD1 --> SD2

        subgraph DLSTRAT ["다운로드 전략 (C1~C6 제약 준수)"]
            DL_DOCS["Google Docs\n→ gviz/pub?output=txt\n+ Download Event Capture\n(a.click() 앵커 방식)"]
            DL_SHEETS["Google Sheets\n→ gviz/tq?tqx=out:csv\n(동일 origin, CORS 없음)"]
            DL_LARGE["대용량 >30KB\n→ Drive API Export\n+ Download Event"]
        end

        SD2 --> DLSTRAT
        DLSTRAT --> RAW["raw/ 폴더 저장\n.claude/knowledge/{product}/evidence/raw/"]
        RAW --> NORM["텍스트 정규화\nevidence-spec.md 규칙 적용"]
        NORM --> CHUNK["청킹\nmax_tokens 기반 분할\n→ chunks/{chunk_id}.txt"]
        CHUNK --> INDEX["인덱스 빌드\nindex/sources.jsonl\n{chunk_id, source_url, line_start, line_end}"]
        INDEX --> LEDGER["sync-ledger.json 업데이트\nevidence_index_sha256 기록\n.claude/state/{product}/sync-ledger.json"]
    end

    SYNC --> RES
    SKIP_SYNC --> RES

    subgraph RES ["/run-research — 에이전트 팀 오케스트레이션"]
        direction TB

        TC["TeamCreate: research-vN\n팀 생성"]
        TC --> TK["TaskCreate\nDiscussion / Judge / Critique / Synth\nblockedBy 의존성 체인 설정"]

        TK --> W1

        subgraph W1 ["Wave 1 — 도메인 에이전트 (병렬, claude-sonnet-4-6)"]
            BIZ["🏢 biz\n비즈니스·전략\nKPI·경쟁분석·수익모델"]
            MKT["📣 marketing\n마케팅·GTM\n포지셔닝·채널·메시지"]
            RS["🔬 research\n시장·경쟁·사용자\n리서치 인사이트"]
            TEC["⚙️ tech\n기술·아키텍처\n구현 가능성·리스크"]
            PM2["📊 pm\n제품관리\n우선순위·로드맵·트레이드오프"]
        end

        W1 --> PEER

        subgraph PEER ["Peer-to-Peer 토론 프로토콜 (SendMessage)"]
            PEER1["각 에이전트: critical_issue 정의"]
            PEER2["파트너와 1:1 토론\ntopic 설정 → 왕복 논증"]
            PEER3["outcome 기록\nresolved / unresolved / partial / limit_reached"]
            PEER1 --> PEER2 --> PEER3
        end

        PEER --> AGENT_OUT["에이전트 JSON 출력\n.claude/artifacts/{product}/agents/{role}.json\n\n{role, critical_issue, peer_discussions,\nclaims, open_questions, risks}"]

        AGENT_OUT --> JUDGE

        subgraph JUDGE ["Judge (claude-opus-4-6)"]
            J1["미해결 충돌 수집\noutcome: unresolved"]
            J2["충돌 판정\ntech_wins / pm_wins / draw\nadopted_for_synth 결정"]
            J3["출력: judgment.json + summary.md\n.claude/artifacts/{product}/agents/debate/"]
            J1 --> J2 --> J3
        end

        JUDGE --> CRIT

        subgraph CRIT ["Critique (claude-opus-4-6)"]
            C1["모든 에이전트 출력 종합 검토"]
            C2["논리 허점·가정·누락 분석\n건설적 피드백 생성"]
            C3["출력: critique.json + critique.md\n.claude/artifacts/{product}/agents/"]
            C1 --> C2 --> C3
        end

        CRIT --> SYNTH

        subgraph SYNTH ["Synth (claude-opus-4-6)"]
            SY1["로컬 템플릿 복사\n.claude/templates/{doc_type}/"]
            SY2["H2 구조 불변 원칙\n플레이스홀더만 교체"]
            SY3["claims 인용 처리\ncitation-spec.md 규칙\nchunk_id + line_range + quote_sha256"]
            SY4["최종 문서 출력\n.claude/artifacts/{product}/{output_dir}/v{N}/{output_file}"]
            SY5["citations.json + conflicts.json 생성"]
            SY6["부록 E 추가\n전문가 토론 요약 (문서 말미 Append)"]
            SY1 --> SY2 --> SY3 --> SY4
            SY4 --> SY5
            SY4 --> SY6
        end

        SYNTH --> TD["shutdown_request → TeamDelete"]
    end

    RES --> VER

    subgraph VER ["/verify — 출력물 검증"]
        V1["① 구조 검사\n15개 파일 존재 여부"]
        V2["② JSON 스키마 검증\nagent-team-spec 계약 준수\n(role, critical_issue, claims, peer_discussions)"]
        V3["③ 인용 유효성\nchunk_id 존재 / line_range 유효 / quote_sha256 일치"]
        V4["④ 증거 드리프트\nsync-ledger 해시 ↔ 현재 sources.jsonl 비교"]
        V5["⑤ 완전성 검사\nH2 헤더 = 로컬 템플릿 구조 (정규화 후 비교)"]
        V1 --> V2 --> V3 --> V4 --> V5
    end

    VER --> REPORT["📊 결과 보고\n✅ PASS / ⚠️ WARN / ❌ FAIL"]
    REPORT --> NEXT["→ /gate-review 권장"]
```

---

## 다이어그램 4 — Gate Review 결정 흐름

각 단계별 게이트 기준과 Go/Pivot/Kill 결정 흐름입니다.

```mermaid
flowchart TD
    GR_START(["/gate-review 실행"]) --> LOAD

    LOAD["project.json 로드\nmvp_stage / document_type / stage_history"]
    LOAD --> STAGE{"현재 단계\n(mvp_stage)"}

    STAGE -->|"S1"| GC1["📋 product-brief gate_criteria\n① 시장규모 TAM·SAM 수치 근거\n② 단위 경제성 LTV/CAC 방향성\n③ 핵심 가정 3개 이상 명시\n④ 문제 실재성 인터뷰/관찰 5건\n⑤ PMF 시나리오 1개 이상"]

    STAGE -->|"S2"| GC2["🧪 pretotype-spec gate_criteria\n① XYZ 가설 명확히 도출\n② 90일 검증 목표 수치 결제/가입 N명\n③ 프리토타입 실험 방법 구체화\n④ Stop Signal 사전 정의"]

    STAGE -->|"S3"| GC3["📱 product-spec gate_criteria\n① 핵심 기능 P0 시연 동작 확인\n② PM·CEO·CTO 데모 승인\n③ §3 플로우·§4 AC 완성\n④ 미해결 기술 리스크 없음"]

    STAGE -->|"S4"| GC4["🎨 design-spec gate_criteria\n① P0 화면 콘텐츠 명세 AI 생성 가능\n② Tech Spec §1~Gate 전 섹션 완성\n③ EXT 목록 ↔ API 명세 1:1 매핑\n④ 비주얼 방향성·WCAG 2.1 AA 명시\n⑤ PM·디자이너·엔지니어 3자 합의"]

    GC1 & GC2 & GC3 & GC4 --> CHECKLIST["기준 항목별 체크리스트 표시\n사용자 확인 진행"]
    CHECKLIST --> DEC{"판정"}

    DEC -->|"Go ✅"| GO["project.json 업데이트\nmvp_stage: S{N+1}\nstage_history append\n{stage, decision: go, timestamp}"]
    DEC -->|"Pivot 🔄"| PIV["stage_status: pivot\nstage_history append\n{decision: pivot, reason}\n→ 수정 후 /auto-generate 재실행"]
    DEC -->|"Kill ❌"| KIL["stage_status: gate_stopped\nstage_history append\n{decision: kill, reason}\n→ 프로세스 종료"]

    GO -->|"S1 → S2"| NS2["document_type: pretotype-spec\n→ /auto-generate"]
    GO -->|"S2 → S3"| NS3["document_type: product-spec\n→ /auto-generate"]
    GO -->|"S3 → S4"| NS4["document_type: design-spec + tech-spec\n→ /auto-generate (두 문서 순차 생성)"]
    GO -->|"S4 → S5"| NS5["mvp_stage: S5\nstage_status: in_progress\n🚀 MVP 개발 시작"]
```

---

## 다이어그램 5 — 파일 시스템 & 데이터 흐름

각 명령이 읽고 쓰는 파일 경로와 데이터 흐름을 보여줍니다.

```mermaid
flowchart LR
    subgraph TRACKED ["📁 Tracked (git 관리)"]
        direction TB
        T1[".claude/commands/*.md\n명령어 정의"]
        T2[".claude/spec/\nagent-team-spec.md\ncitation-spec.md\nevidence-spec.md\ndocument-types.yaml\nmvp-process-spec.md"]
        T3[".claude/templates/{doc_type}/\n로컬 마크다운 템플릿"]
        T4[".claude/manifests/drive-sources.yaml\n템플릿 (tracked)"]
        T5[".claude/migrations/\nv1_to_v2.md / v2_to_v3.md"]
        T6["CLAUDE.md / env.yml\nREADME.md / CHANGELOG.md"]
    end

    subgraph GITIGNORED ["📁 Gitignored (사용자 데이터)"]
        direction TB
        subgraph STATE [".claude/state/"]
            ST1["_active_product.txt\n현재 활성 제품 포인터"]
            ST2["_schema_version.txt\n현재 스키마 버전"]
            ST3["{product}/project.json\nmvp_stage / document_type\nstage_history[]"]
            ST4["{product}/sync-ledger.json\nevidence_index_sha256\nlast_sync_at"]
        end

        subgraph MANIFEST_I [".claude/manifests/"]
            MI1["drive-sources-{product}.yaml\n제품별 Drive URL 목록"]
        end

        subgraph KNOWLEDGE [".claude/knowledge/{product}/evidence/"]
            K1["raw/\n원본 다운로드 텍스트"]
            K2["chunks/{chunk_id}.txt\n청킹된 증거 조각"]
            K3["index/sources.jsonl\n{chunk_id, url, line_start, line_end}"]
        end

        subgraph ARTIFACTS [".claude/artifacts/{product}/"]
            A1["agents/{role}.json\n에이전트 JSON 출력"]
            A2["agents/debate/\ndiscussions.json\njudgment.json / summary.md"]
            A3["agents/critique.json\nagents/critique.md"]
            A4["{output_dir}/v{N}/{output_file}\n최종 문서 (버전별)"]
            A5["{output_dir}/v{N}/citations.json\nconflicts.json"]
        end
    end

    subgraph COMMANDS ["명령어 데이터 흐름"]
        CMD1["/init-project"] -->|"생성"| ST3
        CMD1 -->|"생성"| MI1
        CMD2["/sync-drive"] -->|"읽기"| MI1
        CMD2 -->|"쓰기"| K1
        CMD2 -->|"쓰기"| K2
        CMD2 -->|"쓰기"| K3
        CMD2 -->|"업데이트"| ST4
        CMD3["/run-research"] -->|"읽기"| K3
        CMD3 -->|"읽기"| T2
        CMD3 -->|"읽기"| T3
        CMD3 -->|"쓰기"| A1
        CMD3 -->|"쓰기"| A2
        CMD3 -->|"쓰기"| A3
        CMD3 -->|"쓰기"| A4
        CMD3 -->|"쓰기"| A5
        CMD4["/verify"] -->|"읽기"| A1
        CMD4 -->|"읽기"| A2
        CMD4 -->|"읽기"| A3
        CMD4 -->|"읽기"| A4
        CMD4 -->|"읽기"| K3
        CMD5["/gate-review"] -->|"읽기"| ST3
        CMD5 -->|"읽기"| T2
        CMD5 -->|"업데이트"| ST3
    end
```

---

## 다이어그램 6 — 문서 유형별 에이전트 & 템플릿 매핑

각 문서 유형마다 어떤 에이전트가 참여하고 어떤 템플릿을 사용하는지 보여줍니다.

```mermaid
flowchart TD
    subgraph TYPES ["6가지 문서 유형"]
        direction LR

        subgraph PB ["product-brief (S1 Master)"]
            PB_A["Wave1: biz · marketing\nresearch · tech · pm"]
            PB_T["템플릿: §0 Context Dump\n§1 프로젝트 개요 · §2 문제 정의\n§3 타이밍 · §4 솔루션 가설\n§5 검증 계획 · §6 스코프\n§7 일정 · §8 성공 기준\n§9 Business Context"]
        end

        subgraph BS ["business-spec (S1 Stage)"]
            BS_A["Wave1: biz · research · pm"]
            BS_T["템플릿: §1 제품 개요\n§2 시장 분석 · §3 사업성 검토\nNPQ + Skin in the Game\n§4 수익 모델 · §5 경쟁 분석\n§6 실행 계획 · §7 리스크\n§8 성공 기준"]
        end

        subgraph PS2 ["pretotype-spec (S2 Stage)"]
            PS2_A["Wave1: biz · research\ntech · pm"]
            PS2_T["템플릿: §1 XYZ 가설\n§2 실험 계획\n--- 실험 후 ---\n§3 실험 결과\n§4 학습 및 인사이트\n§5 Go/Kill 판정"]
        end

        subgraph PS3 ["product-spec (S3 Master)"]
            PS3_A["Wave1: research · tech · pm"]
            PS3_T["템플릿: §0 Context Dump\n§1 기능 개요·우선순위\n§2 사용자 스토리·Task\n§3 정보 구조 IA\n§4 서비스 플로우\n§5 완료 기준\n§6 엣지 케이스\n§7 데이터·외부 연동 EXT"]
        end

        subgraph DS ["design-spec (S4 Handoff)"]
            DS_A["Wave1: research · tech · pm"]
            DS_T["템플릿: §1 비주얼 방향성\n§2 콘텐츠 명세\n§3 인터랙션\n§4 접근성·반응형\n§5 이미지·미디어\n§6 Gate 4 자가점검"]
        end

        subgraph TS ["tech-spec (S4 Handoff)"]
            TS_A["Wave1: tech · research · pm"]
            TS_T["템플릿: §1 전제 정보\n§2 최소 연동 구조\n§3 API 명세 + EXT 매핑\n§4 데이터 모델\n§5 인프라\n§6 보안\n§7 성능\n§8 Gate 4 자가점검"]
        end
    end

    GATE_SHARE_1["⚠️ business-spec\ngate_criteria = []\n→ product-brief 게이트 공유"]
    GATE_SHARE_2["⚠️ tech-spec\ngate_criteria = []\n→ design-spec 게이트 공유"]

    BS --> GATE_SHARE_1
    TS --> GATE_SHARE_2
```

---

## 다이어그램 7 — 에이전트 간 토론 프로토콜 (Peer Messaging)

`/run-research` Wave 1에서 에이전트들이 서로 토론하는 방식입니다.

```mermaid
sequenceDiagram
    participant L as 팀 리더 (pm)
    participant BIZ as biz
    participant TECH as tech
    participant RES as research
    participant MKT as marketing
    participant J as Judge
    participant C as Critique
    participant S as Synth

    Note over L,MKT: Wave 1 — 병렬 실행 시작

    L->>BIZ: 분석 태스크 할당 (evidence 청크 제공)
    L->>TECH: 분석 태스크 할당
    L->>RES: 분석 태스크 할당
    L->>MKT: 분석 태스크 할당

    Note over BIZ,TECH: Peer-to-Peer 토론 (SendMessage)

    BIZ->>TECH: topic: "MVP 범위 vs 기술 복잡도"
    TECH-->>BIZ: 반박 및 근거 제시
    BIZ->>TECH: 수정된 입장
    TECH-->>BIZ: outcome: resolved / unresolved

    RES->>MKT: topic: "시장 규모 추정 방법론"
    MKT-->>RES: 대안 접근 제안
    RES-->>MKT: outcome: partial

    Note over L,MKT: 각 에이전트 JSON 출력 (role.json)

    L->>J: 미해결 충돌 목록 전달\n(outcome: unresolved)
    J->>J: 충돌 판정\nadopted_for_synth 결정
    J->>L: judgment.json 출력

    L->>C: 전체 에이전트 출력 전달
    C->>C: 논리 허점·가정·누락 분석
    C->>L: critique.json + critique.md

    L->>S: 모든 출력 + 로컬 템플릿 전달
    S->>S: 템플릿 H2 구조 유지\n플레이스홀더 채우기\n인용 처리 (chunk_id + sha256)
    S->>L: 최종 문서 + citations.json

    Note over L,S: TeamDelete — 팀 해산
```

---

## 다이어그램 8 — 인용 처리 흐름 (Citation Spec)

에이전트의 claim이 인용을 통해 검증되는 흐름입니다.

```mermaid
flowchart LR
    subgraph EVIDENCE ["증거 계층"]
        E1["Google Drive 문서\n(원본)"]
        E2["raw/{file}.txt\n(다운로드)"]
        E3["chunks/{chunk_id}.txt\n(청킹)"]
        E4["index/sources.jsonl\n{chunk_id, url, line_start, line_end}"]
        E1 --> E2 --> E3 --> E4
    end

    subgraph AGENT_CLAIM ["에이전트 Claim 생성"]
        C1["claim.statement\n주장 내용"]
        C2["claim.citations[]\n인용 목록"]
        C3["citation.chunk_id\ncitation.line_range\ncitation.quote_sha256\ncitation.quote_text"]
        C1 --> C2 --> C3
    end

    subgraph VERIFY_CIT ["인용 검증 (/verify §3)"]
        V1["chunk_id → sources.jsonl 검색\n미존재 시: ERROR"]
        V2["line_start <= line_end 확인\n실제 파일 줄 수 범위 내인지 확인\n범위 초과 시: ERROR"]
        V3["해당 줄 범위 텍스트 추출\nSHA-256 해시 계산\n기록된 quote_sha256과 비교\n불일치 시: ERROR"]
        V1 --> V2 --> V3
    end

    subgraph POLICY ["인용 정책"]
        P1["strict (기본값)\n오류 1건이라도 → 검증 실패"]
        P2["warn\n오류 보고 후 통과"]
    end

    E4 -->|"chunk_id 조회"| V1
    C3 -->|"인용 제출"| V1
    V3 --> POLICY
```
