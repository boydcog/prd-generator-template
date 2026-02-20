# /verify — 출력물 검증

생성된 문서와 에이전트 출력물의 구조, 인용, 증거 정합성을 검증합니다.
문서 유형에 따라 검사 대상 에이전트와 필수 섹션이 동적으로 결정됩니다.

---

## 검증 항목

### 1. 구조 검사 (Structure Check)

다음 파일/디렉토리가 존재하는지 확인합니다:

**필수 설정 파일:**
- [ ] `.claude/state/project.json`
- [ ] `.claude/manifests/drive-sources.yaml`
- [ ] `.claude/spec/agent-team-spec.md`
- [ ] `.claude/spec/citation-spec.md`
- [ ] `.claude/spec/evidence-spec.md`
- [ ] `.claude/spec/document-types.yaml`

**증거 파일:**
- [ ] `.claude/knowledge/evidence/index/sources.jsonl` (비어있지 않음)
- [ ] `.claude/knowledge/evidence/chunks/` (최소 1개 청크 파일)

**에이전트 출력** (문서 유형의 `agent_roles.wave1`에 정의된 에이전트만 검사):
- `project.json`에서 `document_type`을 읽습니다 (없으면 기본값 `prd`).
- `document-types.yaml`에서 해당 유형의 `agent_roles.wave1` 목록을 로드합니다.
- 각 에이전트에 대해:
  - [ ] `.claude/artifacts/agents/{role}.json`
- 예시 (prd): biz.json, marketing.json, research.json, tech.json, pm.json
- 예시 (tech-spec): tech.json, research.json, pm.json

**최종 문서** (문서 유형에 따라 경로/파일명 결정):
- `document-types.yaml`에서 `output_dir_name`, `output_file_name`을 로드합니다.
- 우선: `.claude/artifacts/{output_dir_name}/v{N}/{output_file_name}` (버전 서브디렉토리)
  - 필요시 최신 `v{N}`을 자동 감지 (숫자 기반 정렬)
- 차선: `.claude/artifacts/{output_dir_name}/{output_file_name}` (flat path, 호환성)
- [ ] `.claude/artifacts/{output_dir_name}/v{N}/citations.json` 또는 flat path
- [ ] `.claude/artifacts/{output_dir_name}/v{N}/conflicts.json` 또는 flat path

누락된 파일이 있으면 경고를 출력하고 해당 검증을 스킵합니다.

---

### 2. JSON 스키마 검증 (Schema Validation)

각 에이전트 JSON 출력이 `agent-team-spec.md`의 계약을 준수하는지 확인합니다:

- [ ] `role` 필드가 유효한 역할 ID인지
- [ ] `claims[]` 배열이 존재하는지
- [ ] `open_questions[]` 배열이 존재하는지
- [ ] `risks[]` 배열이 존재하는지
- [ ] 각 claim에 `id`, `statement`, `citations[]`가 있는지

---

### 3. 인용 유효성 검증 (Citation Validation)

`citation-spec.md`의 규칙에 따라 모든 인용을 검증합니다:

#### 3.1 chunk_id 존재 확인
- `sources.jsonl`에서 해당 chunk_id를 검색
- 미존재 시: 오류 기록

#### 3.2 line_range 유효성
- `line_start <= line_end` 확인
- 해당 청크 파일의 실제 줄 수 범위 내인지 확인
- 범위 초과 시: 오류 기록

#### 3.3 quote_sha256 일치
- 해당 줄 범위의 텍스트를 추출하고 정규화
- SHA-256 해시를 계산하여 기록된 값과 비교
- 불일치 시: 오류 기록

#### 인용 정책 적용
- **strict** (기본값): 하나라도 오류가 있으면 검증 실패로 보고
- **warn**: 오류를 보고하되 검증은 통과

---

### 4. 증거 드리프트 검사 (Evidence Drift Check)

PRD 생성 시 기록된 증거 인덱스 해시와 현재 인덱스를 비교합니다:

1. `.claude/state/sync-ledger.json`의 `evidence_index_sha256`을 읽습니다.
2. 현재 `.claude/knowledge/evidence/index/sources.jsonl`의 SHA-256을 계산합니다.
3. 불일치하면: "증거가 PRD 생성 이후 변경되었습니다. `/run-research`를 다시 실행하세요."

---

### 5. 완전성 검사 (Completeness Check)

문서에 필수 섹션이 포함되어 있는지 확인합니다.
**섹션 목록은 `document-types.yaml`의 `output_sections`에서 동적으로 로드됩니다.**

1. `project.json`에서 `document_type`을 읽습니다 (없으면 기본값 `prd`).
2. `document-types.yaml`에서 해당 유형의 `output_sections[]`를 로드합니다.
3. 각 섹션이 최종 문서에 포함되어 있는지 확인합니다:
   - 섹션 제목을 문서 내 헤딩(#, ##)에서 검색합니다.
   - 누락된 섹션을 보고합니다.

예시 (prd):
- [ ] 개요 (Executive Summary)
- [ ] 문제 정의
- [ ] 목표 / 비목표
- [ ] 대상 사용자 / 페르소나
- [ ] 기능 요구사항
- [ ] 비기능 요구사항
- [ ] 리스크
- [ ] 마일스톤

예시 (tech-spec):
- [ ] 개요
- [ ] 기술 배경
- [ ] 아키텍처 설계
- [ ] API 설계
- [ ] 데이터 모델
- [ ] ...

---

## 출력 형식

검증 결과를 다음 형식으로 보고합니다:

```
=== 검증 결과 ===

1. 구조 검사: ✅ PASS (12/12 파일 확인)
2. 스키마 검증: ✅ PASS (5/5 에이전트 출력 유효)
3. 인용 유효성: ⚠️ WARN (2건 경고)
   - CLM-003 (biz): chunk_id SRC-xxx 미존재
   - CLM-007 (tech): quote_sha256 불일치
4. 증거 드리프트: ✅ PASS (인덱스 해시 일치)
5. 완전성: ✅ PASS (8/8 필수 섹션 확인)

전체 결과: ⚠️ WARN (인용 경고 2건)
```

---

## 옵션

- `--strict`: 경고도 실패로 처리 (기본값: project-defaults.yaml의 citation_policy)
- `--section <name>`: 특정 검증 항목만 실행 (예: `--section citations`)
