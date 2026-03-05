# /auto-generate — 전체 파이프라인 자동 실행

재료(소스) 입력 후 사용자 개입 없이 sync → research → verify까지 자동 실행합니다.
유일한 중단점: Google 로그인이 필요한 경우.

---

## 사전 조건 확인

### Step -1: 활성 제품 로드

`.claude/state/_active_product.txt`에서 활성 제품 ID를 읽어 `{active_product}` 변수에 저장합니다.
- 파일이 없거나 비어있으면 → `/init-project`를 실행하여 신규 제품을 초기화합니다.

실행 전 다음을 확인합니다:

1. **project.json 존재**: `.claude/state/{active_product}/project.json`이 없으면 → `/init-project` 실행.
2. **Drive 소스 존재**: `.claude/manifests/drive-sources-{active_product}.yaml`에 `sources[]`가 비어있으면 → `/init-project` 실행.
3. **사용자 아이덴티티**: `.user-identity` 확인. 없으면 이름 입력받아 저장.

사전 조건이 충족되면 자동 파이프라인을 시작합니다.

4. **MVP 단계 배너**: `project.json`에 `mvp_stage`가 있으면 파이프라인 시작 전 표시:
   ```
   === MVP 프로세스: S{N} {단계명} ===
   현재 단계: S{N} | 상태: {stage_status}
   문서 유형: {document_type_name}
   ================================
   ```
   단계명: S1=Brief, S2=Pretotype, S3=Prototype, S4=Freeze

---

## 실행 모드

이 명령은 두 가지 모드로 실행됩니다:

- **일반 모드** (기본): 전체 파이프라인 실행 (Phase 1~4)
- **재료 추가 모드** (`mode=material-update`): 새 자료 추가 후 현재 문서 + 이후 문서 업데이트

세션 시작 시 "[재료 추가]" 선택 또는 사용자가 "자료 추가해줘" / "재료 추가해줘" 요청 시 재료 추가 모드로 진입합니다.

---

## 재료 추가 모드 (mode=material-update)

### Step M-1: 새 Drive 소스 수집

1. `.claude/manifests/drive-sources-{active_product}.yaml`의 현재 소스 목록을 표시합니다.
2. 사용자에게 질문: "추가할 Google Drive URL이 있으면 알려주세요. 이미 YAML에 직접 추가하셨다면 건너뜁니다."
3. 새 URL이 제공되면 `drive-sources-{active_product}.yaml`의 `sources[]`에 항목 추가:
   ```yaml
   - title: "{제목 또는 URL에서 추출}"
     url: "{제공된 URL}"
     type: "gdoc"
   ```
4. URL이 없으면 기존 소스 목록으로 계속 진행합니다.

### Step M-2: 새 자료 동기화

`/sync-drive` 실행 (전체 소스 동기화 — 기존 + 새 소스).

완료 후 요약 보고:
- 총 동기화 문서 수
- 신규 수집된 청크 수
- 업데이트된 파일 경로

### Step M-3: 현재 단계 문서 업데이트

`/run-research` 실행:
- `called_from: auto-generate` 컨텍스트 유지
- synth 에이전트가 기존 + 신규 증거 전체를 기반으로 문서 재작성
- 현재 document_type의 새 버전(v{N+1}) 생성

완료 메시지: "현재 문서 {document_type} v{N+1} 생성 완료"

### Step M-4: 이후 단계 문서 캐스케이드 업데이트 확인

1. `document-types.yaml`에서 현재 `document_type`의 `mvp_stage` 확인
2. 이후 단계에 해당하는 문서들이 `artifacts/{active_product}/` 하위에 존재하는지 확인:

   | 현재 문서 (stage) | 확인할 이후 문서들 |
   |----------------|-----------------|
   | product-brief (S1) | product-spec, design-spec, tech-spec |
   | business-spec (S1) | product-spec, design-spec, tech-spec |
   | pretotype-spec (S2) | product-spec, design-spec, tech-spec |
   | product-spec (S3) | design-spec, tech-spec |
   | design-spec (S4), tech-spec (S4) | 없음 |

   탐지 방법: `artifacts/{active_product}/{output_dir_name}/` 디렉토리 존재 여부 확인
   (`output_dir_name`은 `document-types.yaml`의 `output_dir` 필드 참조)

3. 존재하는 이후 문서가 있으면 목록 표시 후 선택 요청:
   ```
   이전 버전 자료 기반으로 생성된 이후 단계 문서들이 있습니다:
   - product-spec v1 (S3)
   - design-spec v1 (S4)
   - tech-spec v1 (S4)

   어떻게 할까요?
   [모두 업데이트] [선택하여 업데이트] [건너뛰기]
   ```

4. 선택에 따라 해당 문서들을 순차적으로 `/run-research` 실행하여 재생성
   (각 문서: `document_type`을 해당 타입으로 임시 전환하여 실행, 완료 후 원래 `document_type`으로 복원)

5. 이후 문서가 없으면 Step M-5로 바로 이동합니다.

### Step M-5: 재료 추가 완료 보고

```
=== 재료 추가 완료 ===

업데이트된 문서:
  📄 {document_type} v{N+1} — .claude/artifacts/{active_product}/{output_dir}/v{N+1}/
  📄 {downstream_doc_type} v{M+1} — .claude/artifacts/{active_product}/{output_dir}/v{M+1}/

=== 완료 ===
```

gate-review 진행 여부 질문: "S{N} 킬 게이트를 검토하시겠습니까?"
- 예 → `/gate-review` 실행
- 아니요 → 종료

---

## 실행 절차

### Phase 0: 사전 대화 (템플릿 기반)

> **적용 범위**: `document_type`이 S1~S4 문서 유형(product-brief, business-spec, pretotype-spec, product-spec, design-spec, tech-spec)인 경우에만 실행합니다.
> - S5는 빌드 단계로 문서 생성 없음 → Phase 0 건너뜀.
> - `custom` 유형: 항상 모드 B(전체 인터뷰)로 진행.

문서 생성 전 **해당 문서의 템플릿 항목을 기반으로** 사용자와 대화하여 각 섹션의 방향과 내용을 확정합니다.

#### Step 0-1: 현황 공유

`project.json`에서 `mvp_stage`, `document_type`, `document_type_name` 로드 후 표시:
```
=== {document_type_name} 생성 준비 ===
현재 단계: {mvp_stage} | 문서 유형: {document_type_name}

등록된 자료 ({N}개):
  - {source.title} ({source.type})
```

#### Step 0-2: 추가 자료 확인

```
추가할 Drive URL이 있으신가요? (없으면 Enter)
```
- URL 입력 시: `drive-sources-{active_product}.yaml`에 추가.
- 없으면: 그대로 진행.

#### Step 0-3: 템플릿 기반 섹션 인터뷰

1. `.claude/templates/{output_dir_name}/` 에서 현재 문서 유형의 템플릿 파일을 로드합니다.
2. 템플릿의 H2 섹션(주요 항목) 목록을 추출합니다.
3. **이전 단계 문서 존재 여부**에 따라 두 가지 모드로 진행합니다:

   모드 판단 기준:
   - `mvp_stage`가 S2~S4이고 `.claude/artifacts/{active_product}/` 하위에 이전 단계 문서가 존재 → **모드 A**
   - S1(첫 실행)이거나 이전 단계 artifacts가 없거나 `custom` 유형 → **모드 B**

   ##### 모드 A: 이전 단계 문서 있음 (S2~S4, 이전 artifacts 존재)

   `run-research.md` Step 0.65와 동일한 기준으로 이전 단계 문서를 로드합니다.
   각 템플릿 섹션에 대해 이전 문서에서 관련 내용을 추출하여 표시합니다:
   ```
   {document_type_name} 항목을 확인합니다.
   이전 단계 문서에서 가져온 내용입니다. 수정하거나 추가할 내용이 있으면 알려주세요.

   1. {섹션 1 제목}
      → "{이전 문서에서 추출한 관련 내용 요약}"

   2. {섹션 2 제목}
      → "{이전 문서에서 추출한 관련 내용 요약}" / "이전 문서에 관련 내용 없음"

   ...

   수정/추가할 항목 번호와 내용을 알려주세요. 없으면 Enter로 그대로 진행합니다.
   ```
   - 이전 문서에서 내용을 가져온 섹션 → `prior` 출처로 분류 (사용자가 수정하지 않는 한 유지).
   - 사용자가 수정/추가한 섹션 → `user` 출처로 갱신.
   - 이전 문서에 내용이 없고 사용자도 입력하지 않은 섹션 → `research` 출처로 분류.

   ##### 모드 B: 이전 단계 문서 없음 (S1 또는 첫 실행)

   템플릿 섹션 전체를 제시하며 인터뷰를 진행합니다:
   ```
   {document_type_name}은(는) 아래 항목으로 구성됩니다:
     1. {섹션 1 제목} — {섹션의 핵심 질문}
     2. {섹션 2 제목} — {섹션의 핵심 질문}
     ...

   직접 알려주실 내용이 있으면 항목 번호와 함께 입력해주세요.
   없는 항목은 등록된 자료를 기반으로 Claude가 작성합니다.
   전부 맡기시려면 "알아서 해줘"를 입력하세요.
   ```
   - 섹션의 핵심 질문은 섹션 제목·맥락에서 추론합니다.
     - 예: "핵심 문제 정의" → "이 제품이 해결하려는 핵심 문제는?"
     - 예: "타겟 사용자" → "주요 사용자와 그들의 특성은?"
     - 예: "프리토타입 방법" → "어떤 방식으로 빠르게 검증할 계획인가요?"

4. 사용자 답변 처리 (모드 A/B 공통):
   - **구체적 내용 제공**: `user` 출처로 분류 — synth agent에 해당 섹션 우선 반영 지시.
   - **내용 없음 (항목 미언급)**: 모드 A면 `prior`, 모드 B면 `research` 출처로 분류.
   - **모호한 답변**: 해당 섹션에 대해 1회 추가 질문 후 재분류.
   - **"알아서 해줘" / "그대로 진행"**: 전체 미답변 섹션을 모드별 기본 출처로 분류하고 즉시 Step 0-4로 진행.

#### Step 0-4: 반영 예정 요약 및 확인

수집된 내용을 섹션별로 정리하여 표시합니다:
```
=== 반영 예정 내용 ===

| 섹션 | 출처 | 내용 |
|------|------|------|
| {섹션명} | 사용자 입력 | {입력 내용 요약} |
| {섹션명} | 자료 기반   | (Drive 자료에서 생성) |
...

이대로 시작할까요?
```
- "예" / Enter: Step 0-5로 진행.
- 수정 요청: 해당 섹션 재입력 후 요약 재제시.

#### Step 0-5: draft-inputs 저장

모든 섹션의 분류 결과를 `.claude/state/{active_product}/draft-inputs.json`에 저장합니다:
```json
{
  "document_type": "{document_type}",
  "created_at": "{ISO 타임스탬프}",
  "mode": "prior_exists" | "fresh",
  "sections": {
    "{섹션명}": {
      "source": "user" | "prior" | "research",
      "content": "{내용 (user/prior인 경우 실제 내용, research이면 빈 문자열)}"
    }
  }
}
```

출처별 synth 처리 기준:
- `user`: 사용자가 직접 제공한 내용 → 최우선 반영, 덮어쓰기 금지
- `prior`: 이전 단계 문서에서 가져온 내용 → 연구 결과로 보강 가능하나 구조 유지
- `research`: 자료 기반 생성 → Drive 증거 + 에이전트 연구로 작성

저장 완료 후 Phase 1 진행.

---

### Phase 1: Drive 동기화

```
"Drive 문서를 동기화합니다..."
```

1. `/sync-drive` 실행.
2. Google 로그인이 필요하면:
   - 사용자에게 로그인 안내 → 로그인 완료 후 자동 재개.
   - 이것이 유일한 사용자 개입 지점입니다.
3. 동기화 완료 확인:
   - `.claude/knowledge/{active_product}/evidence/index/sources.jsonl`이 비어있지 않은지 확인.
   - 비어있으면: 오류 보고 후 중단.

### Phase 2: 에이전트 리서치

```
"에이전트 팀이 문서를 생성합니다..."
```

1. `/run-research` 실행.
   - **컨텍스트**: `called_from: auto-generate` 표시를 명시하여 중복 업로드 프롬프트 방지.
   - **draft-inputs 전달**: `.claude/state/{active_product}/draft-inputs.json`이 존재하면 synth agent에 전달합니다. synth agent는 `source: "user"` 섹션을 연구 결과보다 우선 반영합니다.
   - TeamCreate로 리서치 팀 구성.
   - 회의(Discussion): 도메인 에이전트 병렬 실행 + peer-to-peer 실시간 토론.
   - 판정(Judge) → 비평(Critique) → 통합(Synth): 순차 실행.
   - 완료 후 팀 자동 정리.
   - 완료 시: 업로드 프롬프트 **스킵** (auto-generate가 Phase 4에서 별도 처리).
2. 완료 확인:
   - 최종 문서 파일이 생성되었는지 확인.
   - 생성되지 않았으면: 재시도 1회.
   - 재시도에도 실패하면: 오류 보고 후 중단.

### Phase 3: 검증

```
"출력물을 검증합니다..."
```

1. `/verify` 실행.
2. 결과 처리:
   - **PASS**: Phase 4로 진행.
   - **WARN**: 경고 내용을 보고하고 Phase 4로 진행.
   - **FAIL**: 자동 수정 시도.

### Phase 3-1: 자동 수정 (FAIL일 때)

1. 실패 항목을 분석합니다.
2. 수정 가능한 항목 (구조, 누락 섹션 등):
   - 자동으로 수정합니다.
   - `/verify` 재실행.
3. 수정 불가능한 항목 (증거 부족, 인용 오류 등):
   - 문제 내용을 보고하고 중단.
4. 재검증 통과: Phase 4로 진행.
5. 재검증 실패: 중단 + 상세 보고.

### Phase 3.5: Master Doc Cascade 업데이트

> `mvp_stage`가 S1~S4이고 현재 `document_type`이 Stage Doc 또는 Handoff Doc인 경우에만 실행합니다.
> `mvp_stage`가 null이거나 `document_type`이 `product-brief`인 경우 이 단계를 건너뜁니다.

#### S1~S3: Stage Doc → Product Brief 업데이트

단계별 cascade 매핑:

| 현재 문서 | cascade 대상 | 작업 |
|---------|------------|------|
| business-spec (S1) | product-brief | 없으면 신규 생성 / 있으면 business-spec 내용 merge → 새 버전 |
| pretotype-spec (S2) | product-brief | pretotype 결과 merge → 새 버전 |
| product-spec (S3) | product-brief | 핵심 내용 merge → 새 버전 |

1. 현재 `document_type`이 위 매핑에 포함되는지 확인합니다.
2. 포함되면:
   ```
   {document_type_name} 생성 완료. Product Brief를 업데이트합니다...
   ```
3. `document_type`을 임시로 `product-brief`로 전환하여 `/run-research` 실행.
   - 방금 생성된 Stage Doc 경로(`.claude/artifacts/{active_product}/{original_document_type}/v{N}/{output_file_name}`)를 synth 에이전트 프롬프트에 직접 주입합니다. (Step 0.65의 mvp_stage 기반 이전 문서 로드 로직과 무관하게, cascade 전용으로 경로를 명시 지정)
   - 기존 product-brief가 있으면 해당 최신 버전도 컨텍스트에 포함.
4. 완료 후 `document_type`을 원래 값으로 복원.
5. 포함되지 않으면 이 단계를 건너뜁니다.

#### S4 전용: Design/Tech Spec → Product Spec 선택 추출 반영

> **추출 원칙**: Design/Tech Spec은 조직 전체 컨벤션과 제품 디자인/기술 철학을 모두 담습니다. Product Spec 화면 정의(§3, §7)에는 그 중 **특정 화면(SCR-N)에서만 작동하는 규칙**과 **해당 화면의 외부 연동 절차**만 간략히 가져옵니다. 전역 디자인 토큰·색상 시스템·타이포그래피·공통 아키텍처 등 글로벌 컨벤션은 포함하지 않습니다.

`mvp_stage: S4`이고 `document_type`이 `design-spec` 또는 `tech-spec`인 경우:

1. 두 문서의 최신 버전 존재 여부 확인:
   - `.claude/artifacts/{active_product}/design-spec/` 에 v{N}/ 존재 여부
   - `.claude/artifacts/{active_product}/tech-spec/` 에 v{N}/ 존재 여부
2. **두 문서 모두 있는 경우**: 사용자 확인 후 Product Spec 역반영:
   ```
   Design Spec과 Tech Spec이 모두 완성되었습니다.
   Product Spec 화면 정의 섹션에 화면별 규칙과 외부 연동 절차를 반영할까요?
   ```
   - **예**: Product Spec 최신 버전을 로드합니다.
     - Product Spec이 `.claude/artifacts/{active_product}/product-spec/`에 존재하지 않으면:
       ```
       Product Spec이 아직 생성되지 않았습니다.
       S3 단계에서 /auto-generate로 Product Spec을 먼저 생성한 후 이 단계를 다시 실행하세요.
       ```
       → 이 단계를 건너뜁니다.
     - Product Spec이 존재하면 최신 버전 로드 → 아래 기준으로 선택 추출 → 새 버전 저장.

     **Design Spec 추출 대상** (화면별 인터랙션 규칙만):
     - 각 화면(SCR-N)에 특화된 컴포넌트 동작·상태 전환 규칙
     - 해당 화면 진입/이탈에만 적용되는 전환 애니메이션
     - **포함하지 않음**: 전역 디자인 토큰, 색상 시스템, 타이포그래피, 공통 레이아웃 그리드, 조직 컨벤션

     **Tech Spec 추출 대상** (화면별 외부 연동 절차만):
     - 특정 화면(SCR-N)에서 발생하는 외부 API/서비스 연동 요청 흐름 및 에러 핸들링
     - 화면 단위로 연관된 인증/인가 처리 절차
     - **포함하지 않음**: 전역 아키텍처, 스택 결정, 공통 인프라 설정, 조직 기술 컨벤션

     **Product Spec 반영 위치**:
     - §3-2 화면 목록 각 SCR 항목 비고란: 해당 화면 고유 인터랙션 규칙 1-2줄 참조 (Design Spec 발췌)
     - §7-3 외부 API/서비스 연동 목록: 화면별 연동 절차 간략 기재 (상세는 Tech Spec 참조)

   - **아니요**: 건너뜁니다.
3. **한 문서만 있는 경우**: 다음 안내 후 건너뜁니다:
   ```
   Design Spec과 Tech Spec이 모두 완성되면 Product Spec 역반영이 가능합니다.
   나머지 문서 생성 후 /auto-generate를 실행하면 자동 확인됩니다.
   ```

---

### Phase 4: 완료 보고

```
"파이프라인 완료!"
```

1. 생성된 문서 요약:
   - 문서 유형, 버전, 경로
   - 섹션 수, 인용 수, 경고 사항
2. Drive 업로드 확인:
   - `project-defaults.yaml`의 `upload.ask_after_generation`이 true면:
     "Google Drive에 업로드하시겠습니까?" 질문.
   - `upload.auto_upload`이 true면 질문 없이 자동 실행.
   - 수락 시: `/upload-drive` 실행.
   - 거부 시: 로컬에만 보관.
3. **킬 게이트 안내** (MVP 단계 문서인 경우):
   - `mvp_stage`가 null이 아니고 `stage_status`가 `in_progress`이면:
     ```
     ─────────────────────────────────────
     다음 단계: S{N} 킬 게이트 검토
     이 단계의 완료 기준을 확인하려면 /gate-review를 실행하세요.
     ─────────────────────────────────────
     ```

---

## 에러 핸들링

| 단계 | 에러 | 처리 |
|------|------|------|
| Phase 1 | Drive 접근 불가 | 로그인 안내, 1회 재시도 후 중단 |
| Phase 1 | 증거 0건 | "소스에서 추출된 내용이 없습니다" 보고 후 중단 |
| Phase 2 | 팀원 응답 없음 | 해당 팀원 shutdown → 새 팀원 생성으로 재시도 |
| Phase 2 | 에이전트 실패 | 실패한 에이전트만 1회 재시도 |
| Phase 2 | 문서 미생성 | 전체 1회 재시도 후 중단 |
| Phase 3 | 검증 FAIL | 자동 수정 → 재검증 → 그래도 실패 시 중단 |

---

## 진행 상황 보고 형식

```
=== 자동 파이프라인 실행 ===

Phase 1/4: Drive 동기화
  ✅ 3개 문서 동기화 완료 (12개 청크 생성)

Phase 2/4: 에이전트 리서치 (research-v{N} 팀)
  ✅ biz 분석 완료 — claims: {N}건, risks: {N}건
  ✅ marketing 분석 완료 — claims: {N}건, risks: {N}건
  ✅ research 분석 완료 — claims: {N}건, risks: {N}건
  ✅ tech 분석 완료 — claims: {N}건, risks: {N}건
  ✅ pm 분석 완료 — claims: {N}건, risks: {N}건
  ✅ 통합 문서 생성 완료 — 섹션: {N}개, 인용: {N}건

Phase 3/4: 검증
  ✅ 구조 검사 통과
  ✅ 스키마 검증 통과
  ✅ 인용 유효성 통과
  ✅ 완전성 통과

Phase 4/4: 완료
  📄 {document_type_name} v{N} 생성
  📁 경로: .claude/artifacts/{active_product}/{output_dir}/v{N}/{output_file}
  📊 섹션: {N}개 | 인용: {N}건

=== 파이프라인 완료 ===
```
