# Citation Object Specification

모든 에이전트 출력에서 증거를 참조할 때 사용하는 인용 객체의 정의입니다.

---

## 인용 객체 (Citation Object)

```json
{
  "chunk_id": "SRC-<source_name>@<content_hash>#chunk-0001",
  "source_name": "원본 문서명",
  "line_start": 12,
  "line_end": 18,
  "quote_sha256": "<sha256-of-exact-quoted-text>"
}
```

---

## 필드 정의

| 필드 | 타입 | 필수 | 설명 |
|------|------|------|------|
| `chunk_id` | string | Y | 증거 청크의 고유 식별자. `evidence-spec.md` 참조 |
| `source_name` | string | Y | 원본 문서의 표시명 (Drive 파일 제목 등) |
| `line_start` | integer | Y | 인용 시작 줄 번호 (1-based, 청크 내 상대) |
| `line_end` | integer | Y | 인용 끝 줄 번호 (inclusive) |
| `quote_sha256` | string | Y | 인용된 텍스트 원문의 SHA-256 해시 |

---

## chunk_id 형식

```
SRC-{source_name}@{content_hash}#chunk-{sequence}
```

- `source_name`: 파일 이름에서 파생 (공백→하이픈, 소문자, 특수문자 제거)
- `content_hash`: 원본 내용의 SHA-256 앞 8자리
- `sequence`: 4자리 0-패딩 순서 번호 (0001부터 시작)

### 예시

```
SRC-market-analysis@a3f2b1c9#chunk-0003
SRC-user-research-2024@7e8d4f21#chunk-0012
```

---

## quote_sha256 계산 규칙

1. 인용할 텍스트를 추출합니다 (`line_start`부터 `line_end`까지).
2. 정규화를 적용합니다:
   - Unicode NFC 정규화
   - 줄바꿈을 `\n`으로 통일
   - 각 줄의 후행 공백 제거
   - 전체 앞뒤 공백 제거 (trim)
3. 정규화된 텍스트의 SHA-256 해시를 계산합니다.
4. 소문자 16진수 문자열로 기록합니다.

---

## 검증 규칙

### 필수 검증 (verify 명령에서 수행)

1. **chunk_id 존재 확인**: `sources.jsonl` 인덱스에 해당 chunk_id가 존재해야 합니다.
2. **line_range 유효성**: `line_start <= line_end`, 둘 다 청크의 실제 줄 수 범위 내여야 합니다.
3. **quote_sha256 일치**: 해당 줄 범위의 텍스트를 정규화한 SHA-256이 기록된 값과 일치해야 합니다.

### 실패 정책

- **strict** (기본값): 하나라도 유효하지 않은 인용이 있으면 검증 실패.
- **warn**: `missing_citations.json`에 기록하되 검증은 통과.
