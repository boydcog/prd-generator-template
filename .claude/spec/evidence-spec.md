# Evidence Normalization & Chunking Specification

수집된 원본 문서를 정규화하고 청킹하는 규칙을 정의합니다.

---

## 1. 텍스트 정규화 규칙

원본 문서를 청킹하기 전에 다음 정규화를 순서대로 적용합니다.

| 순서 | 규칙 | 설명 |
|------|------|------|
| 1 | Unicode NFC | 모든 텍스트를 NFC 형식으로 정규화 |
| 2 | 줄바꿈 통일 | `\r\n` 및 `\r`을 `\n`으로 변환 |
| 3 | 후행 공백 제거 | 각 줄 끝의 공백/탭 제거 |
| 4 | 연속 빈 줄 축소 | 3개 이상 연속 빈 줄을 2개로 축소 |
| 5 | 파일 끝 줄바꿈 | 파일이 단일 `\n`으로 끝나도록 보장 |
| 6 | BOM 제거 | UTF-8 BOM (0xEF 0xBB 0xBF) 제거 |

---

## 2. 청킹 전략 (Heading 기반)

### 기본 전략: Heading 분할

마크다운 헤딩(`#`, `##`, `###` 등)을 기준으로 문서를 청크로 분할합니다.

#### 규칙

1. **H1/H2 경계**: `#` 또는 `##` 헤딩이 나오면 새 청크를 시작합니다.
2. **H3 이하**: 상위 헤딩의 청크에 포함됩니다 (별도 분할하지 않음).
3. **헤딩 없는 문서**: 전체를 하나의 청크로 처리합니다.
4. **빈 청크**: 헤딩만 있고 본문이 없으면 다음 청크에 병합합니다.
5. **최대 청크 크기**: 200줄을 초과하면 줄 기준으로 강제 분할합니다.
6. **최소 청크 크기**: 5줄 미만이면 다음 청크에 병합합니다 (마지막 청크 제외).

### 대체 전략: 줄 기반 분할 (Fallback)

헤딩이 전혀 없는 문서 (예: 스프레드시트 변환)에는 고정 줄 수(100줄) 기반으로 분할합니다.

---

## 3. 청크 ID 생성

### 형식

```
SRC-{source_slug}@{content_hash}#chunk-{sequence}
```

### 구성요소

| 요소 | 생성 규칙 |
|------|----------|
| `source_slug` | 파일명에서 파생: 소문자 변환, 공백→하이픈, 비영숫자/비한글 제거, `..` 시퀀스 제거, 선행/후행 하이픈 제거, 빈 결과는 `unnamed-source`로 대체, 최대 50자 |
| `content_hash` | 정규화된 **전체 문서** 내용의 SHA-256 앞 8자리 |
| `sequence` | 4자리 0-패딩 (0001부터 시작) |

### 안정성 보장

- 동일 문서 + 동일 내용 → 동일 chunk_id 생성
- 문서 내용이 변경되면 `content_hash`가 바뀌므로 모든 chunk_id가 변경됨

---

## 3.1. Multi-Tab Chunk ID (다중 탭 문서)

Google Docs/Sheets에서 탭이 여러 개인 문서를 수집할 때 탭별로 독립된 청크 ID를 생성합니다.

### 형식

```
SRC-{source_slug}/{tab_slug}@{content_hash}#chunk-{sequence}
```

### 구성요소

| 요소 | 생성 규칙 |
|------|----------|
| `source_slug` | Section 3과 동일 (파일명 기반, 보안 검증 포함, 최대 50자) |
| `tab_slug` | 탭 이름에서 파생: 소문자 변환, 공백→하이픈, 비영숫자/비한글 제거, `..` 시퀀스 제거, 선행/후행 하이픈 제거, 빈 결과는 `unnamed-tab`으로 대체, 최대 30자 |
| `content_hash` | 해당 **탭**의 정규화된 내용의 SHA-256 앞 8자리 (탭 단위) |
| `sequence` | 4자리 0-패딩 (0001부터 시작, 탭 내 순서) |

### 파일 경로 패턴

```
.claude/knowledge/evidence/chunks/{source_slug}/{tab_slug}/chunk-{NNNN}.md
```

### 하위호환

- 단일 탭 소스 (대부분의 경우): 기존 Section 3의 형식을 그대로 사용
  - `SRC-{source_slug}@{content_hash}#chunk-{sequence}`
  - 경로: `chunks/{source_slug}/chunk-{NNNN}.md`
- `tab_slug`가 포함된 형식은 **실제로 다중 탭을 수집한 경우에만** 적용
- 기존 인덱스와 청크 파일은 변경 없이 유지

---

## 4. 인덱스 파일 형식

### 경로: `.claude/knowledge/evidence/index/sources.jsonl`

한 줄에 하나의 JSON 객체 (JSONL 형식).

```jsonl
{"chunk_id":"SRC-market-analysis@a3f2b1c9#chunk-0001","source_name":"Market Analysis","source_url":"https://docs.google.com/...","content_sha256":"full_sha256_of_chunk","line_count":45,"path":".claude/knowledge/evidence/chunks/market-analysis/chunk-0001.md"}
{"chunk_id":"SRC-market-analysis@a3f2b1c9#chunk-0002","source_name":"Market Analysis","source_url":"https://docs.google.com/...","content_sha256":"full_sha256_of_chunk","line_count":38,"path":".claude/knowledge/evidence/chunks/market-analysis/chunk-0002.md"}
```

### 인덱스 필드

| 필드 | 타입 | 설명 |
|------|------|------|
| `chunk_id` | string | 청크 고유 식별자 |
| `source_name` | string | 원본 문서 표시명 |
| `source_url` | string | 원본 Drive URL |
| `content_sha256` | string | 청크 내용의 SHA-256 전체 해시 |
| `line_count` | integer | 청크의 줄 수 |
| `path` | string | 청크 파일의 상대 경로 |

---

## 5. 청크 파일 구조

### 경로 패턴

```
.claude/knowledge/evidence/chunks/{source_slug}/chunk-{sequence}.md
```

### 청크 파일 헤더

각 청크 파일의 첫 줄에 메타데이터 주석을 포함합니다:

```markdown
<!-- chunk_id: SRC-market-analysis@a3f2b1c9#chunk-0001 | lines: 1-45 | source: Market Analysis -->

(본문 내용)
```

---

## 6. 동기화 원장 (Sync Ledger)

### 경로: `.claude/state/sync-ledger.json`

```json
{
  "last_sync_time": "2024-01-15T09:30:00Z",
  "evidence_index_sha256": "<sha256 of sources.jsonl>",
  "sources": [
    {
      "name": "Market Analysis",
      "url": "https://docs.google.com/document/d/...",
      "scraped_at": "2024-01-15T09:30:00Z",
      "content_sha256": "<sha256 of raw scraped content>",
      "chunk_count": 5,
      "materialized_paths": [
        ".claude/knowledge/evidence/chunks/market-analysis/chunk-0001.md",
        ".claude/knowledge/evidence/chunks/market-analysis/chunk-0002.md"
      ]
    }
  ]
}
```

---

## 7. 결정론 보장

다음 조건이 동일하면 출력은 바이트 동일해야 합니다:
- 동일한 원본 내용
- 동일한 청킹 규칙 (이 문서의 버전)

이를 위해:
- JSON 직렬화 시 키를 알파벳순 정렬
- 모든 파일은 `\n`으로 줄바꿈하고 후행 줄바꿈 1개로 끝남
- JSONL 항목은 chunk_id 기준 알파벳순 정렬
