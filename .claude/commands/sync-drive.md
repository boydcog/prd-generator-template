# /sync-drive — Google Drive 문서 수집

Playwright 브라우저를 통해 Google Drive 문서를 수집하고 로컬 knowledge 저장소에 저장합니다.
**GCP 프로젝트나 OAuth 키가 필요 없습니다.** 브라우저에서 Google 로그인만 하면 됩니다.

---

## 사전 조건: 없음

- Playwright MCP가 이미 설정되어 있으므로 추가 설정이 필요 없습니다.
- 최초 실행 시 Google 로그인 화면이 나타나면 로그인하면 됩니다.

---

## 입력

- `$ARGUMENTS`: (선택) 수집할 Drive URL을 직접 전달. 없으면 manifest에서 읽음.
- manifest: `.claude/manifests/drive-sources.yaml`

---

## 실행 절차

### Step 0: 소스 확인

1. `.claude/manifests/drive-sources.yaml`의 `sources[]`를 읽습니다.
2. `$ARGUMENTS`로 URL이 전달되었으면 해당 URL을 대상 목록에 추가합니다.
3. 대상이 없으면:
   - 사용자에게 Drive URL을 입력받습니다.
   - 입력받은 URL을 manifest에도 추가할지 물어봅니다.
4. 대상이 있으면:
   - 현재 등록된 소스 목록을 보여주고, 추가할 소스가 있는지 물어봅니다.

### Step 1: Google 로그인 확인

1. Playwright `browser_navigate`로 Google Drive 페이지에 접속합니다.
2. `browser_snapshot`으로 로그인 상태를 확인합니다.
3. **로그인 안 됨**: 사용자에게 안내합니다:
   - "Google 로그인이 필요합니다. 브라우저에서 로그인해주세요."
   - `browser_snapshot` → `browser_click`/`browser_type`으로 로그인 화면을 보여줍니다.
   - 사용자가 직접 이메일/비밀번호를 입력하도록 안내합니다.
   - 로그인 완료를 `browser_snapshot`으로 확인합니다.
4. **로그인 됨**: 다음 단계로 진행합니다.

### Step 2: 파일 접근 & 내보내기 (5탭 배치 병렬)

소스 목록을 최대 5개씩 배치로 나누어 병렬 다운로드합니다.

#### 2-1. Export URL 생성

각 소스에서 export URL을 생성합니다:

- **Google Docs** (`type: doc`):
  - URL에서 `DOC_ID` 추출: `https://docs.google.com/document/d/{DOC_ID}/edit` → `DOC_ID`
  - Export URL: `https://docs.google.com/document/d/{DOC_ID}/export?format=txt`

- **Google Sheets** (`type: sheet`):
  - URL에서 `SHEET_ID` 추출: `https://docs.google.com/spreadsheets/d/{SHEET_ID}/edit` → `SHEET_ID`
  - Export URL: `https://docs.google.com/spreadsheets/d/{SHEET_ID}/export?format=csv`
  - gid가 있으면: `&gid={GID}` 추가
  - 시트 목록이 필요하면 먼저 `browser_evaluate`로 탭 이름과 gid를 추출합니다.

#### 2-2. 배치 병렬 다운로드

5개씩 묶어 `browser_run_code` 1회 호출로 동시 fetch합니다:

```
browser_run_code로 실행:
async (page) => {
  const context = page.context();
  const urls = [/* 배치 내 export URL 배열 */];
  const results = await Promise.all(urls.map(async (item) => {
    const p = await context.newPage();
    try {
      const res = await p.goto(item.url, { timeout: 30000 });
      const content = await res.text();
      return { name: item.name, content, success: true };
    } catch (e) {
      return { name: item.name, content: null, success: false, error: e.message };
    } finally { await p.close(); }
  }));
  return JSON.stringify(results);
}
```

#### 2-3. 실패 재시도 + 저장

1. 실패한 소스는 순차적으로 1회 재시도합니다 (개별 `browser_run_code` 호출).
2. Docs 반환 텍스트 → Markdown 변환 후 저장: `.claude/knowledge/evidence/raw/{source_slug}.md`
3. Sheets 반환 CSV → 저장:
   - 단일 시트: `.claude/knowledge/evidence/raw/{source_slug}.csv`
   - 여러 시트: `.claude/knowledge/evidence/raw/{source_slug}/{sheet_name}.csv`

### Step 3: 정규화 & 청킹

`.claude/spec/evidence-spec.md`의 규칙에 따라:

1. 텍스트 정규화 (NFC, 줄바꿈 통일, 후행 공백 제거 등)
2. Heading 기반 청킹 (Docs) 또는 줄 기반 청킹 (Sheets/CSV)
3. 청크 파일 생성: `.claude/knowledge/evidence/chunks/{source_slug}/chunk-{NNNN}.md`
4. 각 청크 파일에 메타데이터 헤더 포함

### Step 4: 인덱스 빌드

`.claude/knowledge/evidence/index/sources.jsonl` 생성:
- 기존 인덱스가 있으면 삭제 후 재생성
- 각 청크에 대해 chunk_id, source_name, content_sha256, line_count, path 기록
- JSONL 항목은 chunk_id 기준 알파벳순 정렬

### Step 5: 동기화 원장 업데이트

`.claude/state/sync-ledger.json` 업데이트:
- `last_sync_time`: 현재 ISO 타임스탬프
- `evidence_index_sha256`: sources.jsonl의 SHA-256
- 소스별 `scraped_at`, `content_sha256`, `chunk_count`, `materialized_paths`

---

## 옵션

- `--refresh`: 캐시 무시하고 모든 소스를 강제 재수집
  - 기본 동작: content_sha256이 동일하면 스킵
  - `--refresh` 시: 무조건 재수집

---

## 변경 감지

- 새로 가져온 내용의 SHA-256과 동기화 원장의 `content_sha256` 비교
- 불일치하면 해당 소스를 재처리 (raw 저장 → 청킹 → 인덱스 갱신)
- 일치하면 "변경 없음" 출력 후 스킵

---

## 출력

- `.claude/knowledge/evidence/raw/` — 내보내기 원본 (md, csv)
- `.claude/knowledge/evidence/chunks/` — 정규화된 청크
- `.claude/knowledge/evidence/index/sources.jsonl` — 청크 인덱스
- `.claude/state/sync-ledger.json` — 동기화 원장
