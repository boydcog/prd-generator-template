# [프로젝트명] Tech Spec

> **Disclaimer:** 이 문서는 LLM 코딩 도구가 최적 성능으로 개발할 수 있도록 최소한의 가드레일을 제공하는 것이 목적이다. 상세한 API 명세나 데이터 모델 설계는 LLM이 자율적으로 판단한다. 항목 2~3은 이모코그 표준으로 prefill됨. 항목 1과 4만 프로젝트별 작성.

버전: v[N] | 최종 업데이트: YYYY-MM-DD | 작성자: [이름]

---

## 1. Core Stack

후보군에서 프로젝트 성격에 맞게 선택한다. **[선택]** 표시된 셀을 채운다.

| 레이어 | 후보군 | 선택 |
|--------|--------|------|
| Mobile | React Native + Expo SDK 51+ | [선택 or 해당없음] |
| Frontend | Next.js App Router / SPA (React + Vite) | [선택] |
| UI | gluestack-ui v2 + Tailwind v4 / shadcn/ui + Tailwind v3 | [선택] |
| Backend | Next.js API Routes / Supabase Edge Functions / FastAPI | [선택] |
| Database | Supabase (PostgreSQL) / Neon / PlanetScale / SQLite | [선택] |
| Auth | Supabase Auth / Clerk / NextAuth.js / Firebase Auth | [선택] |
| Storage | Supabase Storage / Cloudflare R2 / AWS S3 | [선택] |
| AI / LLM | Anthropic Claude API / OpenAI API / Gemini API | [선택 or 해당없음] |
| Infra / Hosting | Vercel / Railway / Fly.io / AWS Amplify | [선택] |
| 패키지 매니저 | bun / pnpm / npm | [선택] |

선택 후 버전 명시: 예) Next.js 15.x, gluestack-ui 2.x, Supabase 2.x, bun 1.x

## 2. Data Modeling Rules

이모코그 표준 원칙. 변경 불필요. 필요시 항목 추가만 허용.

- **Timestamp 필수**: 모든 테이블에 `created_at`, `updated_at` 컬럼 포함
- **User 참조**: 사용자 식별은 JWT의 `sub` (subject) + `iss` (issuer) 조합으로 처리
- **네이밍 컨벤션**: DB 컬럼명은 `snake_case`. TypeScript 코드에서는 `camelCase`로 매핑
- **유연한 속성**: 선택적·확장 가능한 속성은 `JSONB` 타입으로 저장 (스키마 변경 최소화)
- **개인정보 암호화**: 이메일, 전화번호 등 PII는 저장 전 암호화 필수 (AES-256 또는 Supabase Vault)

## 3. Implementation Rules

이모코그 표준 가드레일. 변경 불필요. 필요시 항목 추가만 허용.

- **클라이언트 범위 최소화**: 렌더링 비용이 없는 컴포넌트는 서버 측 또는 정적으로 처리. Next.js: Server Components 기본, 인터랙션 필요 시에만 `"use client"`. Expo: 기본 함수형 컴포넌트, 불필요한 전역 상태 최소화
- **입력 검증**: 모든 API 입력에 Zod 스키마 검증 필수. `any` 타입으로 우회 금지
- **네이밍 컨벤션**: 컴포넌트/타입: `PascalCase`. 파일/폴더: `kebab-case`. DB 컬럼: `snake_case`
- **타입 안전성**: `any`, `unknown` 사용 금지. TypeScript strict 모드 활성화
- **환경 변수**: API 키·비밀값 코드 하드코딩 금지. `.env.local` + `.env.example` 관리

## 4. Key Integration

프로젝트별 필수 작성. 이 제품에 필요한 외부 연동만 작성하고 불필요한 항목은 삭제한다.

### Auth

| 항목 | 내용 |
|------|------|
| Provider | [선택한 Auth Provider] |
| 인증 방식 | [이메일/비밀번호 / 소셜 로그인(Google, Kakao 등) / Magic Link] |
| 세션 관리 | [JWT / Server Session] |
| 특이사항 | [예: 미성년자 보호 조항 적용, 기업 SSO 필요 등] |

### Storage

| 항목 | 내용 |
|------|------|
| Provider | [선택한 Storage Provider] |
| 저장 대상 | [예: 사용자 업로드 이미지, 음성 파일, 리포트 PDF] |
| 접근 정책 | [예: 본인만 접근 / 공개 / 서명된 URL] |

### External Device / Hardware *(해당 없으면 삭제)*

| 항목 | 내용 |
|------|------|
| 디바이스 유형 | [예: BLE 심박 센서, 웨어러블, 스마트 체중계] |
| 연동 SDK | [예: react-native-ble-plx, Polar SDK] |
| 데이터 포맷 | [예: BLE GATT Profile, 커스텀 프로토콜] |

### Payment *(해당 없으면 삭제)*

| 항목 | 내용 |
|------|------|
| Provider | [예: Stripe / 토스페이먼츠 / RevenueCat (In-App)] |
| 결제 방식 | [예: 구독 / 일회성 / In-App Purchase] |
| Webhook | [결제 이벤트 처리 방식] |

### 기타 외부 연동 *(필요한 경우 추가)*

| 서비스 | 용도 | SDK / API |
|--------|------|----------|
| [서비스명] | [용도] | [SDK 또는 REST API] |

---

## Gate 4 체크리스트

| # | 항목 | 확인 |
|---|------|------|
| 1 | 항목 1 Core Stack — 모든 레이어 선택 완료 및 버전 명시 | [ ] |
| 2 | 항목 4 Key Integration — 이 제품에 필요한 연동 작성 완료 | [ ] |
| 3 | Design Spec 항목 1 기술 스택과 항목 1 Core Stack 일치 확인 | [ ] |
| 4 | Product Spec §7-3 외부 연동 목록 → 항목 4에 누락 없이 반영 | [ ] |
| 5 | PM · 디자이너 · 엔지니어 3자 합의 완료 | [ ] |

**판정:** [Freeze 확정 / 수정 후 재검토]
**확정자:** [이름들] (날짜: YYYY-MM-DD)
