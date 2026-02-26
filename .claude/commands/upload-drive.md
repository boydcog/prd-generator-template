# /upload-drive — Google Drive 문서 업로드

Google Drive에 생성된 문서를 업로드합니다. 독립 실행하거나, `/run-research` 및 `/auto-generate` 완료 후 자동 호출됩니다.

같은 프로젝트의 모든 문서(다른 형식 + 다른 버전)는 **하나의 Google Docs 문서** 내 탭으로 관리됩니다.
최초 업로드 시 마스터 문서(`{project_name}`)를 생성하고, 이후 업로드는 동일 문서에 탭을 추가합니다.

**탭 구조**: `{document_title}` (상위 탭) > `v{N}` (하위 탭)
- 파일명 = `project.json`의 `name` 필드 (예: `Maththera`)
- 상위 탭 = 마크다운 H1에서 프로젝트명 제거 (예: `# Maththera Business Spec` → `Business Spec`)
- 하위 탭 = 버전 번호만 (예: `v1`, `v2`, `v3`)

## 입력

- `$ARGUMENTS`: (선택) 업로드할 파일 경로. 없으면 최신 생성 문서를 자동 탐지.

## 사전 조건

- Google 로그인 (Playwright 세션)
- 업로드할 `.md` 파일 존재

---

## 실행 절차

### Step 1: 업로드 대상 결정

- `$ARGUMENTS`가 있으면 해당 파일 사용.
- 없으면 **최종 산출물**을 자동 탐지:

#### 탐색 범위
- 기준 경로: `project-defaults.yaml`의 `output_paths.documents_dir` (예: `.claude/artifacts/`)
- **문서 유형별 디렉토리의 버전 폴더만 탐색** (예: `prd/v3/`, `tech-spec/v1/`)
- `agents/`, `reports/` 등 중간 산출물 디렉토리는 제외

#### 최신 버전 판별 (우선순위)
1. 같은 문서 유형 내에서는 **버전 번호가 가장 높은 것**을 선택
2. 문서 유형이 여러 개 존재하면 사용자에게 질문:
   > "업로드 가능한 문서가 여러 개 있습니다: {목록}. 어떤 문서를 업로드할까요?"

#### 세션 내 최신 문서
- 현재 세션에서 `/run-research` 또는 `/auto-generate`로 방금 생성한 문서가 있으면, 해당 문서를 우선 제안:
  > "{document_type_name} v{N}을 업로드할까요?"
- 세션 내 생성 이력이 없으면 위 탐색 로직으로 폴백

### Step 2: 저장 위치 결정

1. `drive-sources-{product_id}.yaml`의 `upload_folder`가 이미 설정되어 있으면:
   - 저장된 폴더를 재사용합니다 (사용자에게 확인만).
2. 설정되어 있지 않으면:
   - `browser_navigate`로 `https://drive.google.com`을 엽니다.
   - 사용자에게 안내합니다:
     > "Google Drive가 열렸습니다. 문서를 저장할 폴더로 이동한 후 '확인'을 입력해주세요."
   - 사용자가 "확인" (또는 동의 의사)을 입력할 때까지 **이 단계에서만** 대기합니다.
   - 사용자 확인 후 `browser_evaluate`로 현재 URL에서 폴더 ID를 추출합니다:
     ```javascript
     const match = window.location.href.match(/drive\/folders\/([^/?]+)/);
     return match ? match[1] : "";
     ```
   - 추출한 폴더 URL을 `drive-sources-{product_id}.yaml`의 `upload_folder`에 저장합니다 (다음부터 재사용).

### Step 3: Google 로그인 확인

`sync-drive.md` Step 1과 동일한 로직:
1. `browser_navigate`로 `https://drive.google.com`을 엽니다.
2. `browser_snapshot`으로 로그인 상태를 확인합니다.
3. 로그인되어 있지 않으면 사용자에게 로그인을 안내합니다.

### Step 4: 문서 HTML 변환 (일괄)

**중요: 업로드는 중간에 멈추지 않고 한 번에 완료합니다. 섹션별로 끊지 않습니다.**

1. 생성된 `.md` 파일 전체를 읽습니다.
2. Markdown → HTML로 한 번에 변환합니다 (heading, bold, table, list 등 서식 포함).
3. **반드시 UTF-8 인코딩 선언을 포함한 완전한 HTML 문서로 래핑합니다**:
   ```html
   <!DOCTYPE html>
   <html lang="ko">
   <head>
   <meta charset="UTF-8">
   <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
   </head>
   <body>
   {변환된 HTML 본문}
   </body>
   </html>
   ```
   - 한글 등 비ASCII 문자의 mojibake를 방지합니다.
   - 로컬 HTTP 서버로 서빙할 때 Content-Type 헤더에 charset이 빠져도 브라우저가 메타태그로 인코딩을 올바르게 인식합니다.
4. 래핑된 HTML을 임시 디렉토리에 저장합니다:
   ```bash
   SERVE_DIR=$(mktemp -d)
   # 래핑된 HTML을 ${SERVE_DIR}/index.html에 저장
   ```

### Step 5: Google Docs 마스터 문서에 탭 삽입

`drive-sources-{product_id}.yaml`의 `docs_url` 값을 확인하여 분기합니다.

---

#### Step 5-A: 최초 업로드 (`docs_url`이 비어 있음)

1. `browser_navigate`로 `https://docs.google.com/document/create`에 접속하여 새 빈 문서를 만듭니다.
2. `browser_evaluate`로 문서 제목을 `{project_name}`으로 설정합니다.
   - `{project_name}`은 `project.json`의 `name` 필드를 사용합니다 (예: `Maththera`).
3. `browser_evaluate`로 현재 문서 URL을 읽어 `drive-sources-{product_id}.yaml`의 `docs_url`에 저장합니다:
   ```javascript
   return window.location.href;
   ```
4. 상위 탭 이름을 결정합니다:
   - 업로드 `.md` 파일의 첫 번째 H1(`# ...`)을 읽습니다.
   - H1에서 `{project_name}` 접두어와 앞뒤 공백을 제거하여 상위 탭 이름을 만듭니다.
   - 예: `# Maththera Business Spec` → `Business Spec`
   - **(Fallback)** 결과가 빈 문자열이면 문서 유형(`doc_type`)을 상위 탭 이름으로 사용합니다.
5. 기본 탭 "Tab 1"을 상위 탭 이름으로 변경합니다:
   ```
   browser_snapshot → 왼쪽 사이드바 "문서 탭" 패널에서 "Tab 1" 확인
   (패널이 닫혀 있으면: View > Show tabs 클릭 후 재시도)
   "Tab 1"의 "탭 옵션" 버튼 클릭 → "탭 이름 바꾸기" 클릭
   새 이름 입력: {parent_tab_name}  (예: Business Spec)
   Enter 키 눌러 확정
   ```
6. 상위 탭 아래 "v1" 하위 탭을 생성합니다:
   ```
   상위 탭("{parent_tab_name}")의 "탭 옵션" 버튼 클릭
   → 드롭다운 메뉴에서 "하위 탭 추가" 클릭
   → "제목 없는 탭"이 상위 탭 아래 들여쓰기로 생성됨
   새 하위 탭의 "탭 옵션" 버튼 클릭 → "탭 이름 바꾸기"
   이름 입력: v1
   Enter 키 눌러 확정
   ```
7. "v1" 하위 탭을 클릭하여 활성화합니다.
8. **로컬 서빙 → 브라우저 복사 → Google Docs 붙여넣기**로 탭 내용을 삽입합니다 (아래 공통 삽입 절차 참조).
9. 삽입 완료 확인 (스크린샷 1회).
10. 문서가 `upload_folder`에 없으면 Drive로 이동:
    - 파일 메뉴 → "이동" 클릭 → `upload_folder`로 이동.

---

#### Step 5-B: 탭 추가 (`docs_url`이 설정되어 있음)

1. `browser_navigate`로 저장된 `docs_url`을 엽니다.
2. `browser_snapshot`으로 탭 패널을 스캔하여 현재 탭 구조(상위 탭 + 하위 탭)를 파악합니다.
   - 탭 패널이 보이지 않으면: View > Show tabs 클릭.
3. 상위 탭 이름을 결정합니다 (Step 5-A와 동일 로직):
   - 업로드 `.md` 파일의 첫 번째 H1에서 `{project_name}` 접두어 제거.
   - 예: `# Maththera Pretotype Spec` → `Pretotype Spec`
   - **(Fallback)** 결과가 빈 문자열이면 `doc_type`을 상위 탭 이름으로 사용합니다.
4. 상위 탭 존재 여부로 분기합니다:

   **[상위 탭 없음]**: 해당 `{parent_tab_name}` 탭이 존재하지 않는 경우
   ```
   a. 탭 패널 하단 "+" 아이콘 클릭 → "제목 없는 탭" 생성
   b. 새 탭 "탭 옵션" 버튼 클릭 → "탭 이름 바꾸기" → {parent_tab_name} → Enter
   c. 상위 탭 "탭 옵션" 버튼 클릭 → "하위 탭 추가"
   d. 새 하위 탭 "탭 옵션" → "탭 이름 바꾸기" → "v1" → Enter
   e. "v1" 하위 탭 클릭 → 활성화 → 공통 삽입 절차 실행
   ```

   **[상위 탭 있음]**: 해당 `{parent_tab_name}` 탭이 이미 존재하는 경우
   ```
   a. 상위 탭의 하위 탭 목록을 스캔하여 최대 버전 번호 M을 찾습니다 (하위 탭 없으면 M=0).
   b. [하위 탭 없음 (M=0)]:
      - 상위 탭 "탭 옵션" → "하위 탭 추가"
      - 새 하위 탭 "탭 옵션" → "탭 이름 바꾸기" → "v1" → Enter
      - "v1" 하위 탭 클릭 → 활성화 → 공통 삽입 절차 실행
   c. [하위 탭 있음 (M>0)]:
      - 사용자에게 확인:
        > "`{parent_tab_name}` 탭의 최신 버전은 v{M}입니다.
        >  새 v{M+1}을 추가할까요, 아니면 v{M}을 덮어쓸까요?"
      - [새 버전 추가]:
        - 상위 탭 "탭 옵션" → "하위 탭 추가"
        - 새 하위 탭 "탭 옵션" → "탭 이름 바꾸기" → "v{M+1}" → Enter
        - "v{M+1}" 하위 탭 클릭 → 활성화 → 공통 삽입 절차 실행
      - [덮어쓰기]:
        - "v{M}" 하위 탭 클릭 → Cmd+A(전체 선택) → 공통 삽입 절차 실행
   ```

5. 삽입 완료 확인 (스크린샷 1회).

---

#### 공통 삽입 절차 (Step 5-A / 5-B 공유)

```
// a. 로컬 HTTP 서버로 래핑된 HTML 서빙 + PID 기록 (loopback 전용 바인딩)
PORT={사용 가능한 포트}
python3 -m http.server $PORT --bind 127.0.0.1 -d $SERVE_DIR &
HTTP_PID=$!
sleep 1  # 서버가 시작될 때까지 대기 (race condition 방지)

// b. 새 브라우저 탭에서 로컬 HTML 열기
browser_tabs → new
browser_navigate → http://localhost:$PORT/index.html

// c. 전체 선택 + 복사 (서식 포함 클립보드)
// macOS: Meta, Windows/Linux: Control
browser_press_key → "Meta+a" 또는 "Control+a"  (전체 선택)
browser_press_key → "Meta+c" 또는 "Control+c"  (복사)

// d. Google Docs 탭으로 전환
browser_tabs → select (Docs 탭)

// e. 탭 내 콘텐츠 영역 클릭 후 붙여넣기
browser_click → 문서 본문 영역 클릭 (포커스)
browser_press_key → "Meta+v" 또는 "Control+v"  (붙여넣기)

// f. 로컬 서버 정리 + 임시 탭 닫기
kill $HTTP_PID
rm -rf $SERVE_DIR
browser_tabs → close (로컬 HTML 탭)
```

- 브라우저가 렌더링한 HTML을 복사하므로 heading, bold, table, list 서식이 보존됩니다.
- `<meta charset="UTF-8">` 덕분에 한글이 정확히 인코딩됩니다.
- `execCommand('insertHTML')`은 사용하지 않습니다 (deprecated + Google Docs Canvas 렌더링과 비호환).
- `navigator.clipboard.write()`도 사용하지 않습니다 (CORS 제약으로 Google Docs에서 실패할 수 있음).

**(Fallback) 자동 붙여넣기 실패 시:**
- "자동 붙여넣기에 실패했습니다." 메시지 표시.
- 사용자에게 안내:
  > "브라우저에서 `http://localhost:{port}` 탭으로 이동하여 내용을 수동으로 복사(Cmd+A, Cmd+C)한 후, Google Docs 탭에 붙여넣어(Cmd+V) 주세요."
- 사용자가 확인하면 절차를 계속 진행합니다.

---

### Step 6: 공유 드라이브 이동 (선택)

업로드 완료 후 사용자에게 질문합니다 (env.yml의 `organization.name` 참조):

> "{organization.name} 공유 드라이브로 이동하시겠습니까?"

- **수락 시**:
  1. `drive-sources-{product_id}.yaml`의 `shared_drive_folder` 확인.
  2. **없으면**: 공유 드라이브 폴더 URL 입력 안내 → 입력받은 URL을 `shared_drive_folder`에 저장 (재사용).
  3. **있으면**: 저장된 폴더로 문서 이동.
  4. Playwright `browser_navigate`로 마스터 문서 페이지 이동 → `browser_snapshot` → 파일 메뉴 또는 우클릭 → "이동" 클릭 → 공유 드라이브 폴더로 이동 실행.
- **거부 시**: 개인 Drive에 보관.

### Step 7: 결과 보고 + 브라우저 종료

1. 업로드 파일:
   - `{output_file_name}` (문서 본문 — HTML 서식 유지)
   - `citations.json` (인용 보고서, `project-defaults.yaml`의 `upload.include_citations`이 true일 때)
2. 업로드 완료 후 결과를 사용자에게 공유합니다:
   ```
   업로드 완료: {project_name}
   탭 추가됨: {parent_tab_name} > v{N}
   링크: {docs_url}
   ```
3. `browser_close`를 호출하여 브라우저를 종료합니다.

---

## Google Docs 탭 UI 가이드

```
# 탭 목록 확인
browser_snapshot → 왼쪽 사이드바 "문서 탭" 패널 확인
(패널이 닫혀 있으면: View > Show tabs 클릭)

# 상위 탭 추가
탭 패널 하단 "+" 아이콘 클릭
→ 새 "제목 없는 탭" 생성됨

# 탭 이름 변경
탭의 "탭 옵션" 버튼 클릭 → "탭 이름 바꾸기"
→ 이름 입력 후 Enter

# 하위 탭 추가
상위 탭의 "탭 옵션" 버튼 클릭 → 드롭다운 → "하위 탭 추가"
→ "제목 없는 탭"이 상위 탭 아래 들여쓰기로 생성됨
→ 새 하위 탭 "탭 옵션" → "탭 이름 바꾸기" → 이름 입력 → Enter

# 탭 내 콘텐츠 작업
탭 클릭으로 전환 → 해당 탭 내용 편집 가능
```

**탭 구조 snapshot 예시** (접근성 트리):
```
treeitem "Business Spec":
  button "탭 옵션"
  treeitem "v1":
    button "탭 옵션"
  treeitem "v2":
    button "탭 옵션"
treeitem "Pretotype Spec":
  button "탭 옵션"
  treeitem "v1":
    button "탭 옵션"
```

---

## 설정 참조

| 설정 파일 | 필드 | 용도 |
|----------|------|------|
| `project-defaults.yaml` | `upload.ask_after_generation` | 생성 후 업로드 여부 확인 |
| `project-defaults.yaml` | `upload.auto_upload` | true면 확인 없이 자동 업로드 |
| `project-defaults.yaml` | `upload.include_citations` | 인용 보고서 함께 업로드 여부 |
| `project-defaults.yaml` | `upload.naming_pattern` | Google Docs 파일명 패턴 (파일명=프로젝트명, 탭 구조: `{document_title}` > `v{N}`) |
| `drive-sources-{product_id}.yaml` | `upload_folder` | 개인 Drive 업로드 폴더 URL |
| `drive-sources-{product_id}.yaml` | `shared_drive_folder` | 공유 드라이브 폴더 URL |
| `drive-sources-{product_id}.yaml` | `docs_url` | 프로젝트 마스터 문서 URL (최초 업로드 시 자동 저장) |

---

## 금지사항

- 개인 Drive 루트에 무단 생성 (반드시 사용자가 지정한 폴더에 저장)
- plain text 붙여넣기 (서식 사라짐)
- 섹션별 분할 삽입 (중간에 끊기고 사용자 입력 대기 발생)
- 삽입 중 사용자에게 "계속하시겠습니까?" 같은 질문 (위치 확인은 Step 2에서만)
- 업로드마다 새 Google Docs 문서 생성 (같은 프로젝트는 반드시 마스터 문서에 탭으로 추가)
