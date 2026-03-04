# **HeartBeat Sync Tech Spec**

버전: v1.0 | 업데이트: 2026-03-04 | 작성자: emocog engineering team

> **이 문서는 HeartBeat Sync(BLE 심박 모니터링 모바일 앱)의 Tech Spec 예시입니다.**
> 항목 2\~3은 이모코그 표준 그대로. 항목 1·4는 BLE 기반 헬스케어 앱 기준으로 작성됨.
> 항목 5(API Design Convention)는 예시에만 포함 — 복잡한 API 구조 시 추가.

---

## **1\. Core Stack**

| 레이어 | **선택** | 버전 |
| ----- | ----- | ----- |
| **Mobile** | React Native + Expo SDK | 51+ |
| **Frontend** | Expo Router (App Router 방식) | 3.x |
| **UI** | gluestack-ui v2 + Tailwind v4 (NativeWind) | 2.x / 4.x |
| **Backend** | Supabase Edge Functions | 2.x |
| **Database** | Supabase (PostgreSQL) | 2.x |
| **Auth** | Supabase Auth | 2.x |
| **Storage** | Supabase Storage | 2.x |
| **AI / LLM** | Anthropic Claude API (심박 패턴 분석) | claude-sonnet-4-6 |
| **Infra / Hosting** | Expo EAS Build + Supabase Cloud | — |
| **패키지 매니저** | bun | 1.x |

> **버전 요약:** Expo 51, gluestack-ui 2.x, NativeWind 4.x, Supabase 2.x, bun 1.x

---

## **2\. Data Modeling Rules**

> 이모코그 표준. HeartBeat Sync 추가 규칙 포함.

| \# | 규칙 | 세부 내용 |
| ----- | ----- | ----- |
| 1 | **Timestamp 필수** | 모든 테이블에 `created_at`, `updated_at` 컬럼 포함 |
| 2 | **User 참조** | 사용자 식별은 JWT의 `sub` + `iss` 조합으로 처리 |
| 3 | **네이밍 컨벤션** | DB 컬럼명은 `snake_case`. TypeScript 코드에서는 `camelCase`로 매핑 |
| 4 | **유연한 속성** | 선택적·확장 가능한 속성은 `JSONB` 타입으로 저장 |
| 5 | **개인정보 암호화** | 이메일, 전화번호 등 PII는 저장 전 암호화 (Supabase Vault 사용) |
| 6 | **심박 Raw 데이터** | BLE GATT 수신 raw bytes는 `heart_readings.raw_bytes BYTEA`로 저장. 앱에서 파싱하여 `bpm INTEGER` 컬럼에 기입 |
| 7 | **세션 단위 집계** | 개별 심박 측정이 아닌 세션 단위로 집계 (`heart_sessions` 테이블 별도 관리) |

### **핵심 엔티티**

| 엔티티 | 역할 | 관계 |
| ----- | ----- | ----- |
| `users` | 사용자 계정 (Supabase Auth 연동) | `heart_sessions` 1:N |
| `heart_sessions` | BLE 연결 세션 (시작\~종료) | `heart_readings` 1:N |
| `heart_readings` | 개별 심박 측정값 | `heart_sessions` N:1 |
| `device_profiles` | 등록된 BLE 기기 정보 | `users` N:1 |
| `ai_insights` | Claude API 분석 결과 | `heart_sessions` 1:1 |

---

## **3\. Implementation Rules**

> 이모코그 표준. HeartBeat Sync 추가 규칙 포함.

| \# | 규칙 | 세부 내용 |
| ----- | ----- | ----- |
| 1 | **클라이언트 범위 최소화** | Expo Router 기준 — 기본 함수형 컴포넌트 사용. 불필요한 전역 상태 최소화. 컴포넌트 트리를 가볍게 유지하여 BLE 이벤트 처리 성능 확보 |
| 2 | **입력 검증** | 모든 Edge Function 입력에 Zod 스키마 검증 필수 |
| 3 | **네이밍 컨벤션** | 컴포넌트/타입: `PascalCase`. 파일/폴더: `kebab-case`. DB: `snake_case` |
| 4 | **타입 안전성** | `any`, `unknown` 사용 금지. TypeScript strict 모드 활성화 |
| 5 | **환경 변수** | API 키 코드 하드코딩 금지. `.env.local` + `.env.example` 관리 |
| 6 | **DB 접근** | Supabase Client 경유만 허용. Raw SQL 직접 실행 금지 |
| 7 | **에러 처리** | Edge Function 응답은 `{ data, error }` 구조로 통일 |
| 8 | **BLE 권한** | `expo-location` + `expo-bluetooth` 권한은 첫 BLE 스캔 직전에만 요청 (OS 정책) |
| 9 | **백그라운드 측정** | iOS 백그라운드 심박 측정은 `UIBackgroundModes: bluetooth-central` 필수. Android Foreground Service로 처리 |
| 10 | **의료 데이터 면책** | 모든 심박 데이터 화면에 "의료적 진단 목적이 아님" 고지 텍스트 필수 |

---

## **4\. Key Integration**

### **Auth**

| 항목 | 내용 |
| ----- | ----- |
| **Provider** | Supabase Auth |
| **인증 방식** | 이메일/비밀번호 + 소셜 로그인 (Google, Apple) |
| **세션 관리** | JWT (Supabase 기본), 자동 갱신 |
| **특이사항** | 미성년자 가입 차단 (생년월일 입력 후 서버에서 나이 검증) |

### **Storage**

| 항목 | 내용 |
| ----- | ----- |
| **Provider** | Supabase Storage |
| **저장 대상** | 프로필 이미지, 세션 내보내기 CSV/PDF |
| **접근 정책** | 본인만 접근 (Row Level Security 적용) |

### **External Device — BLE 심박 센서**

| 항목 | 내용 |
| ----- | ----- |
| **디바이스 유형** | BLE 심박 모니터 (Polar H10, Wahoo TICKR 등 ANT+/BLE 겸용) |
| **연동 SDK** | `react-native-ble-plx` (Expo Config Plugin으로 설치) |
| **데이터 포맷** | BLE GATT Heart Rate Measurement (0x2A37) 표준 프로파일 |
| **연결 흐름** | 스캔 → 기기 선택 → GATT 연결 → Notify Subscribe → 데이터 수신 |
| **오프라인 처리** | BLE 연결 끊길 시 로컬 SQLite에 임시 저장 → 네트워크 복구 시 Supabase 동기화 |

### **AI / LLM — 심박 패턴 분석**

| 항목 | 내용 |
| ----- | ----- |
| **Provider** | Anthropic Claude API (claude-sonnet-4-6) |
| **용도** | 세션 완료 후 심박 패턴 분석 + 개인화 인사이트 생성 |
| **호출 시점** | 세션 종료 후 Supabase Edge Function에서 비동기 호출 |
| **비용 관리** | 세션당 1회 호출. 무료 플랜 사용자는 주 3회 제한 |

---

## **5\. API Design Convention** *(선택 섹션 — 복잡한 API 구조 시 추가)*

> HeartBeat Sync는 Supabase Edge Functions 기반. 주요 엔드포인트 목록.

| Method | Endpoint | 설명 |
| ----- | ----- | ----- |
| POST | `/functions/v1/session/start` | BLE 세션 시작 — `device_id`, `user_id` |
| POST | `/functions/v1/session/end` | BLE 세션 종료 + 집계 저장 |
| POST | `/functions/v1/readings/batch` | 심박 배치 업로드 (오프라인 → 동기화) |
| GET | `/functions/v1/sessions` | 사용자 세션 목록 (최근 30일) |
| GET | `/functions/v1/sessions/:id` | 세션 상세 + AI 인사이트 |
| POST | `/functions/v1/ai/analyze` | Claude API 심박 패턴 분석 요청 |
| GET | `/functions/v1/devices` | 등록된 BLE 기기 목록 |
| POST | `/functions/v1/devices` | BLE 기기 등록 |

---

## **Gate 4 체크리스트**

| \# | 항목 | 확인 |
| ----- | ----- | ----- |
| 1 | 항목 1 Core Stack — 모든 레이어 선택 완료 및 버전 명시 | ✅ |
| 2 | 항목 4 Key Integration — BLE, Supabase Auth, Claude API 연동 작성 완료 | ✅ |
| 3 | Design Spec §1 기술 스택 (gluestack v2 + NativeWind)과 항목 1 일치 확인 | ✅ |
| 4 | Product Spec §7-3 외부 연동 목록 → 항목 4에 누락 없이 반영 | ✅ |
| 5 | PM · 디자이너 · 엔지니어 3자 합의 완료 | \[ \] |

**판정:** Freeze 확정 예정 (3자 합의 후)
**확정자:** \[이름들\] (날짜: YYYY-MM-DD)
