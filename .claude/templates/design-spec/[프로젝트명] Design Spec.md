# **\[프로젝트명\] Design Spec**

버전: v\[N\] | 업데이트: YYYY-MM-DD | 작성자: \[이름\]

> **이 문서의 목적:** 이모코그 표준 디자인 시스템 규칙을 AI 코딩 도구에게 전달하고, 제품별 조정 포인트를 명시한다.
> 항목 1\~5는 이모코그 표준. 항목 6\~9는 타겟 사용자에 맞게 조정. 항목 10\~11은 이 제품 전용 작성.

---

## **1\. 기술 스택**

> 이모코그 표준. **변경 금지.** 변경 시 Tech Spec 담당자와 협의 후 명시적 사유 기재 필요.

| 레이어 | 기술 | 버전 | 비고 |
| ----- | ----- | ----- | ----- |
| **Frontend Framework** | React (Next.js App Router) | 15.x | Server Components 기본 |
| **UI Library** | gluestack-ui v2 (headless) | 2.x | Tailwind v4와 통합 |
| **Styling** | Tailwind CSS | v4.x | CSS 변수 기반 (§9 참조) |
| **Animation** | Framer Motion | 11.x | 인터랙션 §6 참조 |
| **State** | Zustand | 4.x | 전역 상태 최소화 |
| **Data Fetching** | TanStack Query | 5.x | 서버 상태 관리 |

---

## **2\. 토큰 기반 아키텍처**

> 이모코그 표준. 서비스별 추가 규칙만 하단에 작성.

### **2-1. 토큰 계층 구조**

```
Primitive Tokens (CSS 변수, §9 참조)
  └── Semantic Tokens (bg-background, text-foreground 등 Tailwind 유틸리티)
        └── Component Tokens (gluestack-ui 컴포넌트 props)
              └── Page Composition
```

### **2-2. 토큰 사용 규칙**

| 규칙 | 내용 |
| ----- | ----- |
| **색상** | 항상 semantic token 사용. `#hex` 또는 `oklch()` 직접 사용 금지 |
| **간격** | Tailwind 4px 단위(`gap-1`=4px, `gap-2`=8px…) 사용 |
| **오클릭 방지** | 인터랙티브 요소 최소 간격 `gap-2` (8px). \[시니어 타겟 시 `gap-3` 이상으로 조정\] |
| **폰트** | semantic class(`text-base`, `text-lg` 등) 사용, `text-[16px]` 직접 지정 금지 |
| **radius** | `rounded-sm`(4px) / `rounded-md`(8px) / `rounded-lg`(12px) / `rounded-xl`(16px) |

### **2-3. 서비스별 추가 토큰 규칙**

> \[이 제품에만 적용되는 추가 토큰 규칙. 없으면 삭제\]

---

## **3\. 컴포넌트 라이브러리**

> 이모코그 표준. gluestack-ui v2 헤드리스 컴포넌트를 기반으로 Tailwind v4로 스타일링.

### **3-1. 기본 컴포넌트 사용 규칙**

| UI 요소 | gluestack 컴포넌트 | Tailwind 스타일링 | 사용 규칙 |
| ----- | ----- | ----- | ----- |
| **버튼 (Primary)** | `<Button>` | `bg-primary text-primary-foreground` | P0 CTA, 주 액션 |
| **버튼 (Secondary)** | `<Button>` | `bg-secondary text-secondary-foreground` | 보조 액션 |
| **버튼 (Outline)** | `<Button>` | `border border-border bg-transparent` | 중립 액션 |
| **텍스트 입력** | `<Input>` | `border border-input bg-background` | 모든 텍스트 입력 |
| **텍스트 영역** | `<Textarea>` | `border border-input bg-background` | 여러 줄 입력 |
| **선택** | `<Select>` | gluestack 기본 | 3개 이상 선택지 |
| **모달** | `<Modal>` | `bg-background rounded-xl` | 확인 필요 액션에만 |
| **토스트** | `<Toast>` | 상태별 색상 적용 | 성공/에러 피드백 |
| **카드** | `<Card>` | `bg-card rounded-lg shadow-sm` | 콘텐츠 컨테이너 |
| **로딩** | `<Spinner>` / Skeleton | `text-muted-foreground` | 비동기 대기 |

### **3-2. 컴포넌트 Size 정책**

> **기본값 (일반 타겟):** sm, md, lg 모두 사용
> \[시니어 타겟 시 sm 제외, md·lg·xl만 사용\]

| Size | 버튼 높이 | 패딩 | 텍스트 | 적용 대상 |
| ----- | ----- | ----- | ----- | ----- |
| **sm** | 32px | px-3 py-1 | text-sm | 인라인 액션, 뱃지 \[시니어: 사용 안 함\] |
| **md** | 40px | px-4 py-2 | text-base | **기본** |
| **lg** | 48px | px-6 py-3 | text-lg | 주요 CTA |
| **xl** | 56px | px-8 py-4 | text-xl | \[시니어 타겟 주요 CTA\] |

### **3-3. 상태별 비주얼**

| 상태 | 시각 표현 | Tailwind 클래스 |
| ----- | ----- | ----- |
| **Default** | 기본 | — |
| **Hover** | 배경 10% 어둡게 | `hover:opacity-90` |
| **Active/Pressed** | 배경 20% 어둡게 | `active:opacity-80 active:scale-[0.98]` |
| **Focus** | 포커스 링 | `focus-visible:ring-2 focus-visible:ring-ring` |
| **Loading** | Spinner (인라인 액션) / Skeleton (콘텐츠 영역) | `opacity-70 cursor-not-allowed` |
| **Disabled** | 반투명 | `opacity-50 cursor-not-allowed pointer-events-none` |
| **Error** | 파괴적 색상 | `border-destructive text-destructive` |
| **Success** | 성공 색상 | `border-success text-success` |

---

## **4\. 타이포그래피**

> 이모코그 표준. 최소 크기 규칙은 타겟 사용자에 따라 조정 가능.

### **4-1. 폰트 패밀리**

| 역할 | 폰트 | Tailwind 클래스 | 적용 범위 |
| ----- | ----- | ----- | ----- |
| **본문 (sans)** | Pretendard | `font-sans` | 기본 텍스트 |
| **제목 (heading)** | Pretendard | `font-sans font-bold` | H1\~H3 |
| **코드 (mono)** | JetBrains Mono | `font-mono` | 코드 블록 |

### **4-2. 타입 스케일**

| 클래스 | 크기 | 행간 | 자간 | 용도 |
| ----- | ----- | ----- | ----- | ----- |
| `text-xs` | 12px | 1.5 | — | 캡션, 보조 정보 |
| `text-sm` | 14px | 1.5 | — | 레이블, 설명 텍스트 |
| `text-base` | 16px | 1.6 | — | 기본 본문 |
| `text-lg` | 18px | 1.5 | — | 서브타이틀 |
| `text-xl` | 20px | 1.4 | \-0.01em | 섹션 제목 |
| `text-2xl` | 24px | 1.3 | \-0.02em | 페이지 제목 |
| `text-3xl` | 30px | 1.2 | \-0.02em | 히어로 제목 |

### **4-3. 최소 크기 규칙 (선택 적용)**

> \[시니어/저시력 타겟 시: 본문 최소 `text-lg`(18px), 설명 최소 `text-base`(16px)\]
> \[일반 타겟: 최소 `text-sm`(14px)\]

| 요소 | 기본 최소 | 시니어 최소 |
| ----- | ----- | ----- |
| 본문 텍스트 | `text-sm` (14px) | `text-lg` (18px) |
| 설명/캡션 | `text-xs` (12px) | `text-base` (16px) |
| 버튼 레이블 | `text-sm` (14px) | `text-base` (16px) |

---

## **5\. 아이콘 시스템**

> 이모코그 표준. **변경 금지.**

| 항목 | 규칙 |
| ----- | ----- |
| **라이브러리** | `lucide-react` |
| **기본 크기** | 20px (`size-5`) |
| **Small** | 16px (`size-4`) — 레이블 인라인 |
| **Large** | 24px (`size-6`) — 독립 아이콘, 네비게이션 |
| **XL** | 32px (`size-8`) — 빈 상태(Empty State) 일러스트 대용 |
| **색상** | `text-current` (부모 색상 상속) |
| **텍스트 없는 아이콘** | `aria-label` 필수 |
| **장식용 아이콘** | `aria-hidden="true"` |

---

## **6\. 인터랙션**

> 기본값 제공. 타겟 사용자에 따라 조정 가능.

### **6-1. Framer Motion 트랜지션**

| 트랜지션 | 기본값 | \[시니어: 느린 UX\] | 적용 대상 |
| ----- | ----- | ----- | ----- |
| **빠른 피드백** | duration: 0.15s, ease: \[0.4,0,0.2,1\] | duration: 0.2s | 버튼 hover/press |
| **화면 전환** | duration: 0.3s, ease: \[0.4,0,0.2,1\] | duration: 0.4s | 페이지/모달 진입 |
| **콘텐츠 표시** | duration: 0.4s, ease: \[0,0,0.2,1\] | duration: 0.5s | 리스트 항목, 카드 |
| **종료** | duration: 0.2s, ease: \[0.4,0,1,1\] | duration: 0.3s | 모달 닫기, 페이지 이탈 |

> **현재 설정:** 기본값 / \[시니어 조정값\] — 하나를 선택하여 §9 CSS 변수에 반영

### **6-2. 마이크로인터랙션 규칙**

| 패턴 | 트리거 | 피드백 | 지속 시간 |
| ----- | ----- | ----- | ----- |
| **버튼 클릭** | 클릭 | 즉시 Loading, 재클릭 차단 | 응답까지 |
| **폼 유효성** | Submit + blur | 필드별 에러 메시지 | 수정 전까지 |
| **토스트 알림** | 성공/에러 | Toast 팝업 | 3초 후 자동 소멸 |
| **모달 닫기** | ESC / 배경 / X버튼 | 즉시 닫힘 | — |
| **페이지 전환** | 링크/버튼 | 즉시 (느릴 경우 Skeleton) | — |

---

## **7\. 접근성 및 가독성**

> 기본값: WCAG AA. 타겟 사용자에 따라 AAA로 상향 가능.

| 항목 | 기준 (기본) | \[시니어/저시력 조정\] | 구현 방법 |
| ----- | ----- | ----- | ----- |
| **텍스트 대비** | WCAG AA 4.5:1 | WCAG AAA 7:1 | Contrast Checker 검증 |
| **UI 컴포넌트 대비** | 3:1 | 4.5:1 | 버튼 테두리, 입력 테두리 |
| **터치 타겟** | 44×44px (`min-h-11 min-w-11`) | 64×64px (`min-h-16 min-w-16`) | Tailwind min-h/w |
| **포커스 링** | `ring-2 ring-ring` | `ring-4 ring-ring` | focus-visible |
| **텍스트 크기** | `text-sm` 이상 | `text-base` 이상 | §4-3 참조 |
| **Touch Guard** | — | 인터랙티브 요소 간 최소 `gap-3` | 오클릭 방지 |
| **스크린리더** | P0 화면 핵심 기능 | 전체 화면 | aria-label, role |
| **키보드** | Tab 순서 논리적 | Tab + Enter 전체 대체 가능 | tabIndex |

> **현재 설정:** \[AA 기본 / AAA 시니어\] — 선택 후 아래 적용 기준 명시

**적용 기준:** \[예: WCAG AA 기준 적용 — 일반 성인 타겟\]

---

## **8\. 레이아웃**

> Mobile 섹션 필수. Web/Dashboard 섹션은 해당 제품에 필요한 경우에만 작성.

### **8-1. Mobile 레이아웃 (필수)**

| 항목 | 값 | 비고 |
| ----- | ----- | ----- |
| **기준 뷰포트** | 390px (iPhone 15) | |
| **콘텐츠 최대 폭** | 100% (full-width) | |
| **페이지 패딩** | `px-4` (16px) | |
| **섹션 간격** | `space-y-6` (24px) | |
| **하단 안전 영역** | `pb-safe` (iOS safe area) | |
| **네비게이션** | Bottom Tab Bar (고정) | |
| **브레이크포인트** | sm: 640px, md: 768px | |

### **8-2. Web / Dashboard 레이아웃 (선택)**

> \[이 제품에 Web/Dashboard 화면이 있을 경우만 작성. 없으면 이 섹션 전체 삭제\]

| 항목 | 값 | 비고 |
| ----- | ----- | ----- |
| **콘텐츠 최대 폭** | `max-w-5xl mx-auto` (1024px) | |
| **페이지 패딩** | `px-6` (24px) | |
| **사이드바 폭** | 240px (`w-60`) | 대시보드 전용 |
| **그리드** | 12컬럼 | `grid-cols-12` |

---

## **9\. CSS 변수 정의**

> emocog 코드블록. 브랜드 컬러 + 접근성 요구에 맞게 `# [변경 포인트]` 주석 부분만 조정.

```css
/* globals.css — Tailwind v4 CSS 변수 */
@layer base {
  :root {
    /* ─── Background / Surface ─── */
    --background: oklch(1 0 0);                  /* 흰 배경 */
    --card: oklch(0.98 0 0);                     /* 카드 배경 */
    --popover: oklch(1 0 0);

    /* ─── Foreground / Text ─── */
    --foreground: oklch(0.208 0 0);              /* # [변경 포인트] 고대비: 0.15 */
    --card-foreground: oklch(0.208 0 0);
    --muted: oklch(0.96 0 0);
    --muted-foreground: oklch(0.48 0 0);

    /* ─── Brand / Primary ─── */
    --primary: oklch(0.55 0.18 250);             /* # [변경 포인트] 브랜드 컬러 */
    --primary-foreground: oklch(1 0 0);
    --secondary: oklch(0.92 0.01 250);
    --secondary-foreground: oklch(0.25 0 0);

    /* ─── Feedback ─── */
    --destructive: oklch(0.55 0.22 25);          /* 에러/삭제 */
    --destructive-foreground: oklch(1 0 0);
    --success: oklch(0.55 0.16 145);             /* 성공 */
    --warning: oklch(0.65 0.18 85);              /* 경고 */

    /* ─── Border / Input ─── */
    --border: oklch(0.88 0 0);
    --input: oklch(0.88 0 0);
    --ring: oklch(0.55 0.18 250);                /* 포커스 링 (= primary) */

    /* ─── Radius ─── */
    --radius: 0.5rem;                            /* base = 8px */
  }

  .dark {
    --background: oklch(0.13 0 0);
    --card: oklch(0.18 0 0);
    --foreground: oklch(0.95 0 0);               /* # [변경 포인트] 다크모드 텍스트 */
    --primary: oklch(0.65 0.18 250);             /* # [변경 포인트] 다크모드 브랜드 */
    --border: oklch(0.28 0 0);
    --input: oklch(0.28 0 0);
  }
}
```

> **주요 변경 포인트:**
> - `--foreground`: 기본 `0.208` → 고대비 필요 시 `0.15`로 낮춤 \[시니어 타겟\]
> - `--primary`: 브랜드 색상으로 교체. OKLCH hue(250=파랑, 145=초록, 25=빨강)
> - 다크모드 불필요 시 `.dark` 블록 삭제

---

## **10\. 타겟 맞춤 UX 전략**

> **완전 신규 작성 섹션.** Product Spec §7(타겟 사용자 인사이트)를 기반으로 작성.
>
> 작성 프롬프트:
> - 이 제품의 타겟 사용자는 어떤 맥락에서 사용하는가? (장소, 시간, 기기 상태)
> - 사용자가 가장 자주 겪는 UX 장벽은 무엇인가?
> - 이 장벽을 해소하기 위해 이 제품이 채택하는 UX 전략은?
> - 경쟁 제품 대비 이 제품의 UX 차별점은?

\[작성 내용\]

---

## **11\. 최종 품질 검수 항목**

> **완전 신규 작성 섹션.** 이 제품의 타겟과 핵심 기능에 맞는 QA 체크리스트를 작성.
>
> 작성 프롬프트:
> - P0 기능에서 반드시 통과해야 하는 UX 시나리오는?
> - 타겟 사용자가 실수하기 쉬운 인터랙션은?
> - 접근성 기준(§7)이 실제 UI에 적용되었는지 어떻게 검증하는가?
> - AI 생성 UI에서 자주 발생하는 오류 패턴은?

\[작성 내용\]

---

## **Freeze 체크리스트**

| \# | 항목 | 확인 |
| ----- | ----- | ----- |
| 1 | 항목 1\~5 이모코그 표준 그대로 사용 (변경 시 사유 명시됨) | \[ \] |
| 2 | 항목 6 인터랙션 타이밍 — 기본값/시니어값 중 하나 선택 확정 | \[ \] |
| 3 | 항목 7 접근성 — WCAG AA/AAA 중 하나 선택 + 대비율 확정 | \[ \] |
| 4 | 항목 9 CSS 변수 — `--primary` 브랜드 색상 + `--foreground` 값 확정 | \[ \] |
| 5 | 항목 10 타겟 UX 전략 — 빈칸 없이 작성 완료 | \[ \] |
| 6 | 항목 11 품질 검수 항목 — 빈칸 없이 작성 완료 | \[ \] |
| 7 | PM · 디자이너 · 엔지니어 3자 합의 완료 | \[ \] |

**판정:** \[Freeze 확정 / 수정 후 재검토\]
**확정자:** \[이름들\] (날짜: YYYY-MM-DD)
