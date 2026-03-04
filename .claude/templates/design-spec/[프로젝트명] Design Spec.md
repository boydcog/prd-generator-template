# [프로젝트명] Design Spec

- 1~9번 기술 사양, 디자인 시스템 관련 항목이다.
- Product Spec과 1~9번 초안으로, 각 서비스별 Design Spec 최종 문서가 만들어지는데 이미 작성된 1~9번은 기존 틀에서 서비스별 값이 조정되고, 10~11번 항목은 신규 작성된다.

버전: v[N] | 최종 업데이트: YYYY-MM-DD | 작성자: [이름]

---

## 1. 기술 스택

React + gluestack-ui v2 + Tailwind CSS v4 + Framer Motion

## 2. 토큰 기반 아키텍처

모든 스타일은 임의의 값(Magic Values)을 배제하고, @theme에 매핑된 CSS Variables를 통해서만 제어한다.

Color System: oklch 기반의 색상 체계를 유지하며, 다크/라이트 모드 대응이 가능한 시멘틱 클래스만 사용한다.
- 사용 예시: bg-primary-500, text-surface-900, border-outline-200
- 불가 예시: bg-[#2e6aff], text-black

Radius: 모든 컨테이너(Card, Modal 등)는 고정된 수치(1.3rem)가 담긴 rounded-lg를 강제한다.

Spacing: Tailwind v4 기본 스케일을 준수하되, 임의의 수치(p-[13px]) 사용을 엄격히 금지한다.
> **[조정 포인트]** 시니어/저시력 타겟 시: 버튼 및 인터랙티브 요소 간격은 오클릭 방지를 위해 최소 12px(gap-3) 이상으로 추가 명시한다.

## 3. 컴포넌트 라이브러리 활용

원시 HTML 태그를 지양하고 gluestack-ui v2의 추상화된 레이아웃 컴포넌트를 사용한다.

Layout First: div 대신 Box, HStack, VStack, Center를 사용하여 레이아웃의 의도를 명확히 한다.

Property Mapping: 컴포넌트 스타일링 시 라이브러리 제공 속성을 최우선 적용한다.
- action: primary, success, error, warning, info
- variant: solid, outline, link
- size: sm, md, lg
  > **[조정 포인트]** 시니어 타겟 시: md, lg, xl — sm 사이즈 사용 지양

## 4. 타이포그래피

일관된 브랜드 인상을 위해 가독성을 해치는 시각 효과를 차단한다.

Font: font-sans (Pretendard)를 전역 강제 적용한다.

> **[조정 포인트]** 시니어/저시력 타겟 시: Minimum Size — 본문 텍스트는 최소 18pt(text-lg), 설명문은 15pt(text-md) 이상을 유지한다.

Shadow Policy: 텍스트 그림자(text-shadow)는 어떠한 경우에도 금지한다.
- 가독성 확보가 필요할 경우 명도 대비(Contrast)나 font-weight 조정을 통해 해결한다.
- 요소 그림자(shadow-md)는 오직 Floating 요소(Popovers, Modals, Floating Action Button 등)와 Card에만 허용한다.

## 5. 아이콘 시스템

아이콘은 @phosphor-icons/react 라이브러리를 사용하며 gluestack과 통합한다.

Pattern: `<Icon as={PhosphorIconName} />` 패턴을 엄격히 준수한다.

Weight: 별도 명시가 없다면 모든 아이콘은 weight="regular"를 기본값으로 한다.

Accessibility: 아이콘은 단독으로 사용하지 않으며, 상태 전달 시 반드시 텍스트 라벨과 병기한다.

## 6. 인터랙션

Framer Motion을 활용하며, 모든 모션은 아래의 표준 수치를 적용하여 0.4초 이내에 완료한다.

| 구분 | 전환 속성 | 필수/선택 |
|------|----------|---------|
| 일반 UI (버튼, 카드) | duration: 0.3, ease: "easeOut" | 부드러운 반응성 |
| 물리적 피드백 (Spring) | type: "spring", stiffness: 300, damping: 20 | 자연스러운 반동 |
| 페이지 전환 | duration: 0.4, ease: [0.22, 1, 0.36, 1] | 베지에 곡선 적용 |
| 요소 등장/퇴장 | initial: { opacity: 0, y: 10 }, animate: { opacity: 1, y: 0 } | 0.25초 이내 신속 처리 |

> **[조정 포인트]** 시니어 타겟 시: 일반 UI duration 0.4, Spring stiffness: 200/damping: 25, 페이지 전환 duration 0.5/ease: "easyInOut", 요소 등장 y축 이동 배제(opacity만)

## 7. 접근성 및 가독성

WCAG 2.1 AA 기준을 충족하는 디자인을 구현한다.

Contrast: 텍스트와 배경의 명도 대비는 최소 4.5:1 이상을 유지한다.

Color Blindness: 에러나 경고 상태는 색상만으로 표현하지 않고, 반드시 아이콘 + 텍스트를 함께 제공한다.

Dark Mode 가독성: oklch의 L(Luminance) 값을 엄격히 관리하여 저조도 환경에서도 텍스트 번짐이 없도록 설계한다.

> **[조정 포인트]** 시니어/저시력 타겟 시: WCAG 2.1 AAA 기준 적용. Contrast 최소 7:1. Touch Target — 모든 터치 영역은 최소 48px x 48px 이상, 연속 터치 가드(0.5초) 적용.

## 8. (해상도별 선택) 레이아웃

사용자의 기기 환경에 따라 유동적으로 대응하되, 조작의 일관성을 최우선으로 한다.

### 8-1. 모바일뷰 (Mobile / Handheld)

Bottom-First Action: 모든 핵심 버튼(CTA)은 사용자의 엄지손가락이 닿기 쉬운 화면 하단 고정(Fixed Bottom Bar) 영역에 배치한다.

Vertical Single Stack: 복잡한 그리드(Grid)를 지양하고, 정보는 위에서 아래로 흐르는 단일 열(Single Column) 구조로 배치하여 스크롤 방향을 단순화한다.

Safe Interaction: 하단 시스템 바와 겹치지 않도록 Safe Area(최소 20px 이상)를 강제하고, 오클릭 방지를 위해 버튼 높이를 최소 54px 이상으로 설정한다.

### 8-2. 웹 및 대시보드 뷰 (Web / Desktop / Dashboard)

> **[조정 포인트]** 웹/대시보드 화면이 없는 서비스는 이 섹션 전체 삭제.

- Focus Center Layout: 화면이 넓어지더라도 시선이 분산되지 않도록 핵심 콘텐츠 영역은 최대 너비(720~800px)로 제한하여 화면 중앙에 정렬한다.
- Predictable End-Point: 대시보드나 상세 페이지의 조작 버튼은 콘텐츠가 끝나는 지점의 우측 하단(Visual End-Point)에 배치하여 작업 완료 의도를 명확히 한다.
- Information Density Control: 데이터 테이블이나 대시보드에서는 정보 밀도를 높이되, 행(Row) 높이는 최소 48px 이상을 유지하여 마우스 조작의 정확도를 보장한다.
- Sticky Context Header: 스크롤이 긴 대시보드 환경에서는 상단 헤더를 고정(Sticky)하여 사용자가 현재 어떤 맥락에 있는지 상시 인지할 수 있게 한다.

## 9. CSS 변수 정의

브랜드 톤앤매너가 필요할 경우 아래 CSS 변수를 수정하여 정의한다.

```css
@import "tailwindcss";

@custom-variant dark (&:is(.dark *));

:root {
  /* --- 폰트 및 기초 (Pretendard) --- */
  --font-sans: "Pretendard Variable", "Pretendard", system-ui, sans-serif;
  --radius: 1.3rem;

  /* --- 브랜드 및 상태 컬러 (oklch) --- */
  --color-primary-500: oklch(0.488 0.243 264.376); /* 핵심 브랜드 컬러 */
  --color-primary-600: oklch(0.420 0.210 264.376); /* Hover/Active용 */
  --color-success-500: oklch(0.627 0.194 149.214);
  --color-error-500: oklch(0.577 0.245 27.325);
  --color-warning-500: oklch(0.769 0.188 70.08);
  --color-info-500: oklch(0.298 0.057 264.364);

  /* --- UI 배경 및 경계선 --- */
  --background: oklch(0.985 0.001 106.423);
  --foreground: oklch(0.208 0.042 265.755); /* [변경 포인트] 고대비 시: 0.15 */
  --border: oklch(0.929 0.013 255.508);      /* [변경 포인트] 구분 강화 시: 0.85 */

  /* --- 그림자: 오브젝트 전용 --- */
  --shadow-color: oklch(0 0 0 / 0.1);       /* [변경 포인트] 입체감 강화 시: 0.2 */
  --shadow-soft: 0 4px 12px -2px var(--shadow-color);
}

@theme inline {
  /* Typography */
  --font-sans: var(--font-sans);

  /* gluestack UI 컴포넌트 연동용 컬러 클래스 */
  --color-primary-500: var(--color-primary-500);
  --color-primary-600: var(--color-primary-600);
  --color-success-500: var(--color-success-500);
  --color-error-500: var(--color-error-500);
  --color-warning-500: var(--color-warning-500);
  --color-info-500: var(--color-info-500);

  --color-background: var(--background);
  --color-foreground: var(--foreground);
  --color-border: var(--border);

  /* Layout Tokens */
  --radius-lg: var(--radius);
  --shadow-md: var(--shadow-soft);
}

@layer base {
  body {
    @apply bg-background text-foreground font-sans;
    text-shadow: none !important; /* 헌법 준수: 텍스트 그림자 금지 */
  }
}
```

## 10. 타겟 맞춤 UX 전략

Product Spec 문서를 바탕으로 UX 전략을 구체화하여 정의한다.

[작성 내용]

## 11. 최종 품질 검수 항목

Product Spec 문서를 바탕으로 제품 출시 및 배포 전 반드시 검수해야 하는 필수 요건이다.

[작성 내용]

---

## Freeze 체크리스트

| # | 항목 | 확인 |
|---|------|------|
| 1 | 항목 1~5 이모코그 표준 그대로 사용 (변경 시 사유 명시됨) | [ ] |
| 2 | 항목 6 인터랙션 타이밍 — 기본값/시니어값 중 하나 선택 확정 | [ ] |
| 3 | 항목 7 접근성 — WCAG AA/AAA 중 하나 선택 + 대비율 확정 | [ ] |
| 4 | 항목 9 CSS 변수 — 브랜드 컬러(primary) + foreground 값 확정 | [ ] |
| 5 | 항목 10 타겟 UX 전략 — 빈칸 없이 작성 완료 | [ ] |
| 6 | 항목 11 품질 검수 항목 — 빈칸 없이 작성 완료 | [ ] |
| 7 | PM · 디자이너 · 엔지니어 3자 합의 완료 | [ ] |

**판정:** [Freeze 확정 / 수정 후 재검토]
**확정자:** [이름들] (날짜: YYYY-MM-DD)
