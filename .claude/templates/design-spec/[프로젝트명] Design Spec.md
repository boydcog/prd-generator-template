# [프로젝트명] Design Spec

Product Spec 작성 이후 프로토타입 직전 생성되는 서비스별 고유의 디자인 규칙 문서

- 총 11개의 항목으로 구성되어 있으며,
- Product Spec을 바탕으로 Design Spec의 토큰값, UX 전략이 커스터마이징되고 (AI 80%), 이후 디자이너는 문서를 검토하여 Design Spec을 최종 확정한다 (Human 20%).

- 1~8번 항목 | 디자인 시스템 규칙 (Static)
- 9~11번 항목 | Product Spec에 따라 가변성을 가지는 규칙 (Dynamic)

버전: v[N] | 최종 업데이트: YYYY-MM-DD | 작성자: [이름]

---

## Static Layer: Immutable Infrastructure

이 계층은 기술적 안정성을 보장하는 디자인 헌법으로, 모든 프로덕트에 공통으로 사용한다. AI는 이 영역의 값을 수정할 수 없으며, 반드시 준수해야 하는 제약 조건으로 인식한다.

> Dynamic 규칙과 충돌하는 값이 있을 경우, Dynamic에 정의된 값을 기준으로 한다.

| # | 항목 | 상세 사양 | 참고 |
|---|------|----------|------|
| 1 | 기술 스택 | React + gluestack-ui v2 + Tailwind v4 + Framer Motion 조합을 강제함. | [gluestack-ui v2](https://v2.gluestack.io/ui/docs/home/overview/introduction) |
| 2 | 토큰 아키텍처 | `@theme`에 매핑된 CSS variables 기반의 시맨틱 클래스만 사용하며, 임의의 매직 넘버(Hex, px 등) 사용을 엄격히 금지함.<br><br>• Color: oklch 기반 색상 체계를 유지하며, 다크모드 대응이 가능한 시맨틱 클래스만 사용한다.<br>&nbsp;&nbsp;- 사용 예시: `bg-primary-500`, `text-surface-900`, `border-outline-200`<br>&nbsp;&nbsp;- 불가 예시: `bg-[#2e6aff]`, `text-black`<br>• Radius: lg를 기본으로 하되, 맥락에 따라 가변성을 가진다.<br>• Spacing: 1unit = 0.25rem 공식을 준수하며 임의의 px값 사용을 금지한다. | [Tailwind CSS](https://tailwindcss.com/docs/installation/using-vite) |
| 3 | 컴포넌트 | 원시 HTML 태그를 지양하고 Box, HStack, VStack 등 gluestack의 추상화된 레이아웃 컴포넌트 사용을 원칙으로 한다.<br><br>• action: primary, success, error, warning, info<br>• variant: solid, outline, link<br>• size: sm, md, lg, xl | |
| 4 | 타이포그래피 | 아래 기준을 전역 적용하되, 서비스 특성에 따라 가변성을 가진다.<br><br>• Font Family: font-sans (Pretendard)<br>• Font Weight: Bold, Semibold, Medium, Regular 위계를 기본으로 하되, 맥락에 따라 가변성을 가진다.<br>• Policy:<br>&nbsp;&nbsp;- 텍스트 그림자는 어떠한 경우에도 금지한다. (`text-shadow: none`)<br>&nbsp;&nbsp;- 가독성 확보가 필요할 경우 명도 대비나 font-weight 조정을 통해 해결한다.<br>&nbsp;&nbsp;- 웹 접근성 및 시스템 확장성을 위해 rem을 사용한다. | [Pretendard](https://github.com/orioncactus/pretendard) |
| 5 | 아이콘 | `@phosphor-icons/react` 라이브러리를 사용한다.<br><br>• Pattern: `<Icon as={PhosphorIconName} />` 패턴을 엄격히 준수한다.<br>• Weight: 별도 명시가 없다면 모든 아이콘은 `weight="regular"`를 기본값으로 한다. | [Phosphor Icons](https://github.com/phosphor-icons/homepage) |
| 6 | 접근성 | WCAG 2.1 AA 기준을 기반으로 하며, Product Spec에 정의된 타겟의 취약도에 따라 AAA 기준의 수치로 변경하여 사용한다.<br><br>• Contrast: 텍스트와 배경의 명도 대비는 최소 4.5:1 이상을 유지한다.<br>• Color Blindness: 에러나 경고 상태는 색상만으로 표현하지 않고, 반드시 아이콘 + 텍스트를 함께 제공한다.<br>• Dark Mode: oklch의 L(Luminance) 값을 엄격히 관리하여 저조도 환경에서도 텍스트 번짐이 없도록 설계한다. | |
| 7 | 레이아웃 | 사용 환경에 따라 아래 가이드를 참고하여 사용한다.<br><br>• 모바일뷰 (Mobile/Handheld)<br>&nbsp;&nbsp;- Bottom-First Action: CTA 버튼은 화면 하단에 고정(Fixed Bottom Bar) 배치한다.<br>&nbsp;&nbsp;- Vertical Single Stack: 단일 열(VStack)을 강제하여 시선 분산을 방지하고 스크롤을 단순화한다.<br>&nbsp;&nbsp;- Safe Area: 하단 시스템 바와의 충돌 방지를 위해 최소 spacing-5 이상의 여백을 확보한다.<br>• 웹 및 대시보드뷰 (Web/Dashboard)<br>&nbsp;&nbsp;- Focus Center: 핵심 콘텐츠의 영역은 최대 너비 45rem~50rem으로 제한하여 화면 중앙에 정렬한다.<br>&nbsp;&nbsp;- Density: 데이터 테이블이나 대시보드의 정보 밀도를 높이되, 행(Row) 높이는 최소 3rem으로 한다.<br>&nbsp;&nbsp;- Sticky Header: 스크롤 중 맥락을 인지하도록 상단 헤더를 고정한다. | |
| 8 | 인터랙션 | Framer Motion을 활용하며, 모든 모션은 아래의 표준 수치를 적용하여 0.4초 이내에 완료한다.<br><br>• 일반 UI: `duration: 0.3, ease: "easeOut"`<br>• 물리적 피드백 (Spring): `type: "spring", stiffness: 300, damping: 20`<br>• 페이지 전환: `duration: 0.4, ease: [0.22, 1, 0.36, 1]`<br>• 요소 등장/퇴장: `initial: { opacity: 0, y: 10 }, animate: { opacity: 1, y: 0 }` | [Framer Motion](https://motion.dev/docs/react) |

---

## Dynamic Layer: Target & Service Customized

Product Spec의 서비스 타겟(고령층, 아동, 일반 사용자 등) 및 서비스 특수 맥락에 따라 AI가 최적의 값을 도출하는 계층으로, 1차 산출물을 디자이너가 반드시 검수하여 최종 확정한다.

---

## 9. CSS 변수

서비스 톤앤매너에 따라 gluestack에 적용할 커스텀 CSS 문서이다. 위에서 정의한 Static Layer 기준이 틀이 되고 CSS 변수값은 속성으로 매핑된다.

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
  --foreground: oklch(0.208 0.042 265.755);
  --border: oklch(0.929 0.013 255.508);

  /* --- 그림자: 오브젝트 전용 --- */
  --shadow-color: oklch(0 0 0 / 0.1);
  --shadow-soft: 0 4px 12px -2px var(--shadow-color);
}

@theme inline {
  --font-sans: var(--font-sans);

  --color-primary-500: var(--color-primary-500);
  --color-primary-600: var(--color-primary-600);
  --color-success-500: var(--color-success-500);
  --color-error-500: var(--color-error-500);
  --color-warning-500: var(--color-warning-500);
  --color-info-500: var(--color-info-500);

  --color-background: var(--background);
  --color-foreground: var(--foreground);
  --color-border: var(--border);

  --radius-lg: var(--radius);
  --shadow-md: var(--shadow-soft);
}

@layer base {
  body {
    @apply bg-background text-foreground font-sans;
    text-shadow: none !important;
  }
}
```

## 10. UX 전략

Product Spec 문서를 바탕으로 3단계 추론을 거쳐 작성되는 UX 전략이다.

1. **컨텍스트 추출**: Product Spec에서 '타겟 연령/인지 수준'과 '서비스의 핵심 가치'를 분석한다.
2. **파라미터 매핑**: 추출된 컨텍스트를 1~8번의 가변 요소(폰트 크기, 대비 수준 등)와 연결한다.
3. **전략적 합성**: 서비스 고유의 아이덴티티를 유지하면서 사용자가 겪을 수 있는 페인포인트를 해결하는 UX 원칙을 기술한다.

[작성 내용]

## 11. Human Touch 체크리스트

Product Spec 문서를 바탕으로 생성되는 체크리스트로, 감각 등 비정형적 맥락은 디자이너가 직접 체감하며 서비스의 정서적 완성도와 사용자의 존엄성을 최종 확정한다.

[작성 내용]

---

## Freeze 체크리스트

| # | 항목 | 확인 |
|---|------|------|
| 1 | 항목 1~8 Static Layer — 변경 없이 그대로 사용 (변경 시 사유 명시됨) | [ ] |
| 2 | 항목 9 CSS 변수 — 브랜드 컬러(primary) + foreground 값 확정 | [ ] |
| 3 | 항목 10 UX 전략 — 3단계 추론 완료, 빈칸 없이 작성 완료 | [ ] |
| 4 | 항목 11 Human Touch 체크리스트 — 빈칸 없이 작성 완료 | [ ] |
| 5 | PM · 디자이너 · 엔지니어 3자 합의 완료 | [ ] |

**판정:** [Freeze 확정 / 수정 후 재검토]
**확정자:** [이름들] (날짜: YYYY-MM-DD)
