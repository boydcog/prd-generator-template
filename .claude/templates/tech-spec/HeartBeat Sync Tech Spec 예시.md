# Tech Spec | HeartBeat Sync

> **Disclaimer:** 이 문서는 LLM 코딩 도구가 최적 성능으로 개발할 수 있도록 최소한의 가드레일을 제공하는 것이 목적이다. 상세한 API 명세나 데이터 모델 설계는 LLM이 자율적으로 판단한다. 항목 2~3은 이모코그 표준으로 prefill됨. 항목 1과 4만 프로젝트별 작성.

버전: v1.0 | 최종 업데이트: 2026-03-04 | 작성자: emocog engineering team

---

## 1. Core Stack

| 레이어 | 후보군 | 선택 |
|--------|--------|------|
| Mobile | React Native + Expo SDK 51+ | React Native + Expo SDK 52 |
| Frontend | Next.js App Router / SPA (React + Vite) | 해당없음 (모바일 전용) |
| UI | gluestack-ui v2 + Tailwind v4 / shadcn/ui + Tailwind v3 | gluestack-ui v2 + Tailwind v4 |
| Backend | Next.js API Routes / Supabase Edge Functions / FastAPI | Supabase Edge Functions |
| Database | Supabase (PostgreSQL) / Neon / PlanetScale / SQLite | Supabase (PostgreSQL) |
| Auth | Supabase Auth / Clerk / NextAuth.js / Firebase Auth | Supabase Auth |
| Storage | Supabase Storage / Cloudflare R2 / AWS S3 | Supabase Storage |
| AI / LLM | Anthropic Claude API / OpenAI API / Gemini API | 해당없음 |
| Infra / Hosting | Vercel / Railway / Fly.io / AWS Amplify | Vercel (Edge Functions) |
| 패키지 매니저 | bun / pnpm / npm | bun 1.x |

버전 명시: Expo SDK 52, gluestack-ui 2.x, Supabase 2.x, bun 1.x

## 2. Data Modeling Rules

이모코그 표준 원칙. 변경 불필요. 필요시 항목 추가만 허용.

- **Timestamp 필수**: 모든 테이블에 `created_at`, `updated_at` 컬럼 포함
- **User 참조**: 사용자 식별은 JWT의 `sub` (subject) + `iss` (issuer) 조합으로 처리
- **네이밍 컨벤션**: DB 컬럼명은 `snake_case`. TypeScript 코드에서는 `camelCase`로 매핑
- **유연한 속성**: 선택적·확장 가능한 속성은 `JSONB` 타입으로 저장 (스키마 변경 최소화)
- **개인정보 암호화**: 이메일, 전화번호 등 PII는 저장 전 암호화 필수 (AES-256 또는 Supabase Vault)
- **심박 데이터 보안**: BLE로 수신된 생체 데이터(heart_rate, rr_interval)는 전송 즉시 암호화하여 저장. 원시 바이트 데이터는 DB에 저장하지 않음

## 3. Implementation Rules

이모코그 표준 가드레일. 변경 불필요. 필요시 항목 추가만 허용.

- **클라이언트 범위 최소화**: Expo Router 기준 — 기본 함수형 컴포넌트 사용. 불필요한 전역 상태 최소화. 컴포넌트 트리를 가볍게 유지하여 BLE 이벤트 처리 성능 확보
- **입력 검증**: 모든 API 입력에 Zod 스키마 검증 필수. `any` 타입으로 우회 금지
- **네이밍 컨벤션**: 컴포넌트/타입: `PascalCase`. 파일/폴더: `kebab-case`. DB 컬럼: `snake_case`
- **타입 안전성**: `any`, `unknown` 사용 금지. TypeScript strict 모드 활성화
- **환경 변수**: API 키·비밀값 코드 하드코딩 금지. `.env.local` + `.env.example` 관리

## 4. Key Integration

### Auth

| 항목 | 내용 |
|------|------|
| Provider | Supabase Auth |
| 인증 방식 | 소셜 로그인 (Google, Apple) + 이메일/비밀번호 |
| 세션 관리 | JWT (Supabase 자동 갱신) |
| 특이사항 | Apple 로그인 필수 (iOS App Store 정책) |

### Storage

| 항목 | 내용 |
|------|------|
| Provider | Supabase Storage |
| 저장 대상 | 사용자 프로필 이미지, 측정 리포트 PDF |
| 접근 정책 | 본인만 접근 (RLS 정책 적용) |

### External Device / Hardware

| 항목 | 내용 |
|------|------|
| 디바이스 유형 | BLE 심박 센서 (Polar H10 / 범용 BLE HR Profile) |
| 연동 SDK | react-native-ble-plx 3.x |
| 데이터 포맷 | BLE GATT Heart Rate Profile (UUID: 0x180D) — heart_rate(uint8), rr_interval(uint16[]) |

### Payment

| 항목 | 내용 |
|------|------|
| Provider | RevenueCat (In-App Purchase) |
| 결제 방식 | 월간/연간 구독 |
| Webhook | RevenueCat → Supabase Edge Function → 구독 상태 업데이트 |

---

## 5. API Design Convention *(선택 섹션 — 복잡한 API 구조 시 추가)*

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | /api/sessions | 측정 세션 시작 |
| PATCH | /api/sessions/:id | 측정 데이터 업데이트 (실시간) |
| POST | /api/sessions/:id/complete | 세션 완료 및 리포트 생성 |
| GET | /api/users/:id/history | 사용자 측정 이력 조회 |
| GET | /api/users/:id/report/:sessionId | 특정 세션 리포트 조회 |

---

## Gate 4 체크리스트

| # | 항목 | 확인 |
|---|------|------|
| 1 | 항목 1 Core Stack — 모든 레이어 선택 완료 및 버전 명시 | [x] |
| 2 | 항목 4 Key Integration — 이 제품에 필요한 연동 작성 완료 | [x] |
| 3 | Design Spec 항목 1 기술 스택과 항목 1 Core Stack 일치 확인 | [x] |
| 4 | Product Spec §7-3 외부 연동 목록 → 항목 4에 누락 없이 반영 | [x] |
| 5 | PM · 디자이너 · 엔지니어 3자 합의 완료 | [ ] |

**판정:** Freeze 확정
**확정자:** [이름들] (날짜: 2026-03-04)
