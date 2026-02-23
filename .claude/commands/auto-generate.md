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

---

## 실행 절차

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
