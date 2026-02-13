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

### Playwright MCP 제약사항

sync-drive에서 Playwright를 사용할 때 반드시 인지해야 하는 환경 제약입니다.
전략 선택의 근거이므로 숙지 후 Step 2를 실행합니다.

| # | 제약 | 설명 | 영향 |
|---|------|------|------|
| C1 | evaluate 응답 크기 제한 | `browser_evaluate`/`browser_run_code` 반환값이 ~50KB를 초과하면 MCP 서버가 토큰 초과 에러 반환 | 대용량 CSV/문서를 evaluate로 직접 반환 불가 |
| C2 | require() 불가 | `browser_run_code`는 브라우저 컨텍스트에서 실행. Node.js의 `require('fs')` 등 서버사이드 API 사용 불가 | 파일 I/O는 반드시 Bash tool 또는 Write tool 사용 |
| C3 | CORS cross-origin 차단 | Google export URL이 `*.googleusercontent.com`으로 리다이렉트되어 `fetch()` CORS 차단 | evaluate 내 fetch() 미사용. page.goto() 또는 gviz API 사용 |
| C4 | 클립보드 포커스 필요 | `navigator.clipboard.readText()`는 포커스된 문서에서만 동작. 포커스 없으면 stale data 반환 | 클립보드 전략 시 반드시 편집 영역 클릭 선행 |
| C5 | Google Docs 가상 렌더링 | Docs는 canvas/virtual DOM으로 렌더링. `.kix-*` 셀렉터로 본문 텍스트 추출 불가 | DOM 기반 추출 금지. export URL 또는 클립보드만 사용 |
| C6 | Download 이벤트 트리거 | export URL은 파일 다운로드를 트리거. `res.text()`로 내용을 읽을 수 없음 | `waitForEvent('download')` BEFORE `goto()` 패턴 필수 |

### Step 2: 파일 접근 & 내보내기 (전략 기반)

문서 유형별 전략 계층(Primary → Fallback)으로 수집합니다.

#### 2-0a. 입력 검증

URL 및 slug에서 파생되는 값의 안전성을 보장합니다.

| 대상 | 검증 규칙 | 실패 시 |
|------|----------|--------|
| Google Docs URL | `/document/d/[a-zA-Z0-9_-]+/` 패턴 매칭 | 해당 소스 스킵, 에러 로그 |
| Google Sheets URL | `/spreadsheets/d/[a-zA-Z0-9_-]+/` 패턴 매칭 | 해당 소스 스킵, 에러 로그 |
| Doc/Sheet ID | `[a-zA-Z0-9_-]+` 패턴만 허용 | 해당 소스 스킵, 에러 로그 |
| gid (시트 탭 ID) | `[0-9]+` 패턴만 허용 | 해당 탭 스킵, 에러 로그 |
| source_slug | `..`, `/`, `\`, null byte (`\0`) 제거 | 정제 후 진행 |

검증은 Step 2-0 전략 선택 전에 수행합니다. 검증 실패한 소스는 에러 로그에 기록하고 나머지 소스를 계속 진행합니다.

#### 2-0. 전략 선택 테이블

| 문서 유형 | Primary 전략 | Fallback 전략 |
|-----------|-------------|--------------|
| Google Docs | **Download Event Capture**: `waitForEvent('download')` → `download.path()` → Bash로 파일 읽기 | **Clipboard**: 편집 영역 포커스 → Cmd+A → Cmd+C → readText (2-pass) |
| Google Sheets | **gviz/tq CSV API**: `page.goto(gvizUrl)` → 페이지 텍스트 추출 | **Download Event Capture** |
| 대용량 (>30KB) | **Download Event** → Bash cp | **청크 분할 evaluate** (25KB 단위 루프) |

#### 2-1. Tab/Sheet Discovery

다중 탭이 있는 문서를 수집하기 위한 탭 발견 단계입니다.

**Google Sheets** (`type: sheet`):
1. `browser_navigate`로 스프레드시트 URL에 접속
2. `browser_snapshot`으로 시트 탭 바를 스캔하여 탭 이름 + gid 추출
3. manifest에 `sheets: []` (빈 배열)이면 → 발견된 **모든 시트**를 수집 대상으로 등록
4. manifest에 `sheets: ["시트1", "시트3"]`이면 → 해당 시트만 수집
5. 탭별로 순차 수집 진행 (Step 2-3)

**Google Docs** (`type: doc`):
1. URL에 `?tab=t.xxx` 파라미터가 있으면 → 해당 탭만 수집 (기본 동작)
2. manifest에 `tabs: all`이 명시되면 → `browser_snapshot`으로 전체 탭 발견 후 순차 수집
3. `tabs` 필드가 없거나 `tabs: single`이면 → URL의 탭만 수집 (하위호환)

#### 2-2. Google Docs — Download Event Capture (Primary)

> 제약 C1, C2, C3, C6 대응. export URL의 다운로드 트리거를 정상 경로로 처리합니다.

```
수집 절차:
1. Export URL 생성:
   DOC_ID = URL에서 /document/d/{DOC_ID}/ 추출
   exportUrl = https://docs.google.com/document/d/{DOC_ID}/export?format=txt

2. browser_run_code로 실행:
   async (page) => {
     // download 이벤트 Promise를 BEFORE goto()에서 생성 (순서 중요!)
     const downloadPromise = page.waitForEvent('download', { timeout: 30000 });
     await page.goto(exportUrl);
     const download = await downloadPromise;
     const filePath = await download.path();   // 임시 파일 경로
     return filePath;
   }

3. Bash tool로 다운로드된 파일 읽기:
   cat "{filePath}"
   또는 대용량이면:
   cp "{filePath}" ".claude/knowledge/evidence/raw/{source_slug}.md"

4. 내용을 Markdown으로 저장
```

**핵심**: `waitForEvent('download')` Promise를 `page.goto()` **이전에** 생성해야 합니다.
`page.evaluate(() => location.href = ...)` 방식은 download 이벤트를 트리거하지 않으므로 사용하지 않습니다.

#### 2-2-F. Google Docs — Clipboard Fallback (폴링 방식)

> 제약 C4, C5 대응. Download Event가 실패할 때 사용합니다.

```
수집 절차:
1. browser_navigate로 Google Docs 편집 URL에 접속
2. 편집 영역 클릭 (포커스 확보):
   browser_click으로 문서 본문 영역 클릭
3. 클립보드 비우기:
   browser_evaluate:
     async () => { await navigator.clipboard.writeText(''); }
4. 전체 선택 + 복사:
   browser_press_key: Meta+a
   browser_press_key: Meta+c
5. 클립보드 폴링 읽기:
   browser_evaluate:
     async () => {
       const maxWait = 5000;   // 5초 타임아웃
       const interval = 200;   // 200ms 간격
       let elapsed = 0;
       while (elapsed < maxWait) {
         const text = await navigator.clipboard.readText();
         if (text && text.trim().length > 0) return text;
         await new Promise(r => setTimeout(r, interval));
         elapsed += interval;
       }
       throw new Error('clipboard polling timeout: 5s exceeded');
     }
6. 폴링 결과를 Markdown으로 저장
```

**폴링 방식 이유**: 기존 2-pass(1차 폐기 + 500ms 대기 + 2차 읽기)는 고정 딜레이에 의존하여 race condition이 발생할 수 있습니다.
클립보드를 먼저 비우고(`writeText('')`) 실제 내용이 들어올 때까지 폴링하면 타이밍에 관계없이 안정적으로 현재 문서 내용을 얻습니다.

#### 2-3. Google Sheets — gviz/tq CSV API (Primary)

> 제약 C3 대응. gviz URL은 same-origin이므로 CORS 문제 없이 접근 가능합니다.

```
수집 절차:
1. SHEET_ID 추출: URL에서 /spreadsheets/d/{SHEET_ID}/ 추출
2. 탭별 gviz URL 생성 (Step 2-1에서 발견한 탭 목록 사용):
   gvizUrl = https://docs.google.com/spreadsheets/d/{SHEET_ID}/gviz/tq?tqx=out:csv&gid={GID}
3. 탭별 순차 수집:
   각 탭에 대해:
   a. browser_navigate로 gviz URL 접속
   b. browser_evaluate로 페이지 텍스트 추출:
      () => document.body.innerText
   c. 응답 크기 확인:
      - 30KB 이하: 정상 저장
      - 30KB 초과: Step 2-4 대용량 처리로 전환
4. CSV 저장:
   - 단일 시트: .claude/knowledge/evidence/raw/{source_slug}.csv
   - 여러 시트: .claude/knowledge/evidence/raw/{source_slug}/{tab_slug}.csv
```

**gviz/tq API 장점**: same-origin이므로 CORS 차단 없음. CSV 형식으로 직접 반환. 인증 쿠키 자동 전달.

#### 2-3-F. Google Sheets — Download Event Fallback

gviz API가 실패하면 export URL + download event 방식으로 전환합니다:

```
exportUrl = https://docs.google.com/spreadsheets/d/{SHEET_ID}/export?format=csv&gid={GID}
→ Step 2-2와 동일한 Download Event Capture 패턴 적용
```

#### 2-4. 대용량 데이터 처리 (>30KB)

> 제약 C1 대응. evaluate 반환값이 MCP 크기 제한을 초과하는 경우.
>
> **evaluate_safe_limit = 30KB**: C1 제약의 하드 리밋은 ~50KB이지만, 인코딩 오버헤드(JSON 직렬화, UTF-8 멀티바이트)와 MCP 응답 메타데이터를 고려하여 60% 수준(30KB)에서 download event로 전환합니다. 이 값은 의도적 안전 마진이며, `project-defaults.yaml`의 `playwright_constraints.evaluate_safe_limit`에서 관리합니다.

**Option A — Download Event (권장)**:

```
browser_run_code:
  async (page) => {
    const downloadPromise = page.waitForEvent('download', { timeout: 30000 });
    await page.goto(exportUrl);
    const download = await downloadPromise;
    return await download.path();
  }
→ Bash tool: cp "{tempPath}" "{targetPath}"
```

**Option B — 청크 분할 evaluate (폴백)**:

```
총 길이를 먼저 측정:
  () => document.body.innerText.length

25KB 단위로 슬라이싱 루프:
  (offset) => document.body.innerText.slice(offset, offset + 25000)

모든 청크를 연결하여 저장
```

#### 2-5. 배치 실행 전략

1. 소스 목록을 문서 유형별로 그룹화 (Docs / Sheets)
2. **순차 처리**: Google 요청 제한(rate limit) 방지를 위해 소스별 순차 수집
3. 소스당 최대 2회 시도: Primary 전략 실패 → Fallback 전략 1회
4. 개별 소스 실패 시 에러 유형별 처리:
   - **Timeout** (download event 30s 초과): Fallback 전략으로 전환
   - **CORS/Network 에러**: Fallback 전략으로 전환
   - **인증 만료** (Google 로그인 필요 페이지 감지): 수집 중단, 사용자에게 재로그인 안내
   - **빈 콘텐츠 반환**: 경고 로그 기록, 해당 소스 스킵
   - **Fallback도 실패**: 에러 로그 기록 후 다음 소스로 진행
   모든 에러는 감사 로그(Step 2-5a)에 구조화 형식으로 기록
5. 모든 소스 수집 완료 후 결과 요약 (성공/실패/스킵 수)

#### 2-5a. 에러 로그 및 감사 기록

수집 과정의 감사 추적을 위해 구조화된 로그를 기록합니다.

**저장 경로**: `.claude/state/sync-log.jsonl`

**형식**: JSONL (소스별 1줄)

```jsonl
{"timestamp":"2024-01-15T09:30:00Z","source_slug":"market-analysis","doc_type":"doc","strategy":"download_event","result":"success","error_type":null,"error_message":null,"duration_ms":2450,"fallback_used":false}
{"timestamp":"2024-01-15T09:30:05Z","source_slug":"competitor-data","doc_type":"sheet","strategy":"gviz_csv","result":"failure","error_type":"timeout","error_message":"download event 30s timeout exceeded","duration_ms":30000,"fallback_used":true}
```

**필드 정의**:

| 필드 | 타입 | 설명 |
|------|------|------|
| `timestamp` | string | ISO 8601 형식 |
| `source_slug` | string | 소스 식별자 (full URL 아님 — 민감정보 방지) |
| `doc_type` | string | `doc` 또는 `sheet` |
| `strategy` | string | 사용한 전략: `download_event`, `clipboard`, `gviz_csv`, `chunk_evaluate` |
| `result` | string | `success`, `failure`, `skipped` |
| `error_type` | string\|null | `timeout`, `cors`, `auth_expired`, `empty_content`, `unknown` |
| `error_message` | string\|null | 사람이 읽을 수 있는 에러 설명 |
| `duration_ms` | integer | 수집 소요 시간 (밀리초) |
| `fallback_used` | boolean | Fallback 전략 사용 여부 |

**민감정보 제한**:
- full URL 대신 `source_slug`만 기록합니다.
- 토큰, 쿠키, 인증 헤더 등 민감정보는 절대 기록하지 않습니다.
- 에러 메시지에 포함된 URL은 slug로 치환합니다.

#### 2-6. 저장

1. Docs 텍스트 → Markdown 변환 후 저장: `.claude/knowledge/evidence/raw/{source_slug}.md`
2. Sheets CSV → 저장:
   - 단일 시트: `.claude/knowledge/evidence/raw/{source_slug}.csv`
   - 여러 시트: `.claude/knowledge/evidence/raw/{source_slug}/{tab_slug}.csv`

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
- `.claude/state/sync-log.jsonl` — 수집 감사 로그
