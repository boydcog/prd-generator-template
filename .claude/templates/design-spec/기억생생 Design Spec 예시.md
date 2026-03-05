# Design Spec | 기억생생

Product Spec 작성 이후 프로토타입 직전 생성되는 서비스별 고유의 디자인 규칙 문서

- 총 11개의 항목으로 구성되어 있으며,
- Product Spec을 바탕으로 Design Spec의 토큰값, UX 전략이 커스터마이징되고 (AI 80%), 이후 디자이너는 문서를 검토하여 Design Spec을 최종 확정한다 (Human 20%).

- 1~8번 항목 | 디자인 시스템 규칙 (Static)
- 9~11번 항목 | Product Spec에 따라 가변성을 가지는 규칙 (Dynamic)

버전: v0.95 | 최종 업데이트: 2026-03-05 | 작성자: Soya

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

**기억생생 맥락**: '기억생생'의 주 타겟인 4060세대 주관적 인지저하(SCD) 집단의 특성과 '현금성 리워드'라는 서비스 맥락을 고려하여, 시니어 타겟의 접근성과 서비스 고유의 리워드 모델을 강화하는 방향으로 설계

---

## 9. CSS 변수

서비스 톤앤매너에 따라 gluestack에 적용할 커스텀 CSS 문서이다. 위에서 정의한 Static Layer 기준이 틀이 되고 CSS 변수값은 속성으로 매핑된다.

```css
@import "tailwindcss";

@custom-variant dark (&:is(.dark *));

:root {
  /* --- 폰트 및 기초 (시니어 가독성 확보) --- */
  --font-sans: "Pretendard Variable", "Pretendard", system-ui, sans-serif;
  --text-base: 1.125rem;        /* 18px 기본 크기 강제 */
  --leading-senior: 1.75;       /* 행간 1.7~1.8배 확보 */
  --radius: 1.3rem;             /* 브랜드 고정 곡률 */

  /* --- 브랜드 및 상태 컬러 (AAA 대비 확보를 위한 보정) --- */
  /* 배경(0.985) 대비 7:1 이상을 위해 Primary 명도(L)를 0.45로 하향 */
  --color-primary-500: oklch(0.450 0.243 264.376);
  --color-primary-600: oklch(0.380 0.210 264.376);
  --color-success-500: oklch(0.550 0.194 149.214);
  --color-error-500: oklch(0.500 0.245 27.325);
  --color-warning-500: oklch(0.700 0.188 70.08);
  --color-info-500: oklch(0.298 0.057 264.364);

  /* --- UI 배경 및 경계선 --- */
  --background: oklch(0.985 0.001 106.423);
  --foreground: oklch(0.150 0.042 265.755);
  --border: oklch(0.929 0.013 255.508);
  --surface: oklch(1 0 0);

  /* --- 그림자: 오브젝트 전용 --- */
  --shadow-color: oklch(0 0 0 / 0.1);
  --shadow-soft: 0 4px 12px -2px var(--shadow-color);

  /* --- 레이아웃 조작성 토큰 (오클릭 방지) --- */
  --btn-h-senior: 3.75rem;
}

@theme inline {
  /* Typography */
  --font-sans: var(--font-sans);
  --font-size-base: var(--text-base);
  --line-height-relaxed: var(--leading-senior);

  /* gluestack UI 컴포넌트 연동용 컬러 클래스 */
  --color-primary-500: var(--color-primary-500);
  --color-primary-600: var(--color-primary-600);
  --color-background: var(--background);
  --color-foreground: var(--foreground);
  --color-border: var(--border);

  /* Layout Tokens */
  --radius-lg: var(--radius);
  --spacing-btn-senior: var(--btn-h-senior);
  --shadow-md: 0 4px 12px -2px oklch(0 0 0 / 0.15); /* 입체감 강화 */
}

@layer base {
  body {
    @apply bg-background text-foreground font-sans antialiased;
    font-size: var(--text-base);
    line-height: var(--leading-senior);
    text-shadow: none !important;
  }
}
```

## 10. UX 전략

Product Spec 문서를 바탕으로 3단계 추론을 거쳐 작성되는 UX 전략이다.

| # | 분류 | 항목 | 상세 |
|---|------|------|------|
| 1-1 | 인지·신체 최적화 (Usability & Accessibility) | 기억 보조 UI (Cognitive Continuity) | Sticky Context Header를 활용하여 화면 상단에 현재 단계 (예: 지금은 단어를 외우는 중입니다)를 상시 노출하여 인지적 연속성을 부여함. |
| 1-2 | | 고대비 및 시각 보정 (Visual AAA) | 황변 및 수정체 혼탁을 고려하여 배경과 텍스트의 명도 대비를 7:1 이상으로 확보하고, 파란색 계열의 채도를 보정하여 가시성을 극대화함. |
| 1-3 | | 신체 제어 최적화 (Touch Guard) | 모든 터치 타겟은 최소 3.75rem 이상으로 설정하며, 중복 터치 방지를 위해 클릭 후 500ms 동안 재입력을 무시하는 '터치 가드'를 적용함. |
| 1-4 | | Step-by-Step Navigation | 한 화면에 하나의 정보만 제공하는 '싱글 태스크' 원칙을 준수하며, 다음 단계 이동 시 이전 단계의 핵심 요약을 제공함. |
| 2-1 | 감각적 몰입과 피드백 (Sensory Immersion) | 다감각적 실재감 (Multisensory) | 버튼 클릭 및 성공 시 시각적 피드백과 함께 묵직한 진동(Haptic) 및 효과음을 병행하여 조작 성공 여부를 체감하게 함. |
| 2-2 | | 점진적 속도 제어 (User-Led Pace) | 정보 노출 속도를 일반인 대비 1.5배 느리게 설정하고, 사용자가 직접 '다 외웠어요' 버튼을 누르기 전까지 시스템이 임의로 화면을 넘기지 않음. |
| 2-3 | | 맥락 유지 애니메이션 | 화면 전환 시 갑작스러운 컷 이동 대신 부드러운 Fade In/Out 또는 Slide 모션을 사용하여 공간의 연결성을 인지하도록 유도함. |
| 3-1 | 정서적 안전과 자존감 (Emotional Safety & Self-Esteem) | 실패 피드백 (Empathetic Tone) | 오답 시 자극적인 빨간색 'X'나 '땡' 소리 대신, 따뜻한 주황색 계열과 "다시 한번 천천히 살펴볼까요?"라는 공감적 어조를 사용함. |
| 3-2 | | 불안 해소 인터벤션 (AI Companion) | 일정 시간 무반응 시 AI 캐릭터가 등장하여 "저도 이 문제는 조금 어렵네요, 같이 해봐요"라며 동질감을 형성하고 힌트를 제공함. |
| 3-3 | | 성취의 가시화 (Value Visualization) | 단순 점수보다 '모인 현금 리워드'와 '오늘의 뇌 건강 출석'을 강조하여 훈련이 실질적인 가치와 건강으로 이어짐을 시각화함. |

## 11. Human Touch 체크리스트

Product Spec 문서를 바탕으로 생성되는 체크리스트로, 감각 등 비정형적 맥락은 디자이너가 직접 체감하며 서비스의 정서적 완성도와 사용자의 존엄성을 최종 확정한다.

| # | 분류 | 항목 | 상세 |
|---|------|------|------|
| 1-1 | 정서적 공명 및 언어적 뉘앙스 (Emotional Resonance) | 동반자적 어법 | AI가 수정한 문구들이 단순히 공손함을 넘어, 유저에게 '존중받고 있다'는 느낌을 주는 따뜻한 온도를 가졌는가? |
| 1-2 | | 부정적 낙인 제거 | 오답 처리나 가이드 과정에서 유저가 자신의 인지 상태를 비하하거나 위축되게 만드는 표현이 단 하나라도 섞여 있지 않은가? |
| 1-3 | | 자존감 인터벤션 | AI 캐릭터의 개입이 유저의 실수를 지적하는 느낌이 아니라, 함께 문제를 해결해 나가는 '든든한 조력자'로 느껴지는가? |
| 2-1 | 맥락적 유효성 및 흐름 (Contextual Flow) | 3초 컷 직관성 | AI가 설계한 레이아웃이 실제 시니어 유저의 시선 흐름에서 '무엇을 먼저 눌러야 할지'를 본능적으로 알 수 있게 배치되었는가? |
| 2-2 | | 힌트의 실질적 가치 | AI가 생성한 메타기억 힌트가 유저에게 지적 유희를 제공하는가, 아니면 오히려 또 다른 인지 부하를 주는 숙제처럼 느껴지는가? |
| 2-3 | | 속도 제어의 리듬 | 화면 전환과 정보 노출의 속도가 유저의 '인지 호흡'과 일치하여, 조급함이나 지루함을 유발하지 않는가? |
| 3-1 | 감각적 완성도 및 보상의 실재감 (Sensory Quality) | 보상의 쾌감 | '꽃'과 '현금' 리워드가 지급될 때의 시각·청각·촉각 피드백이 시니어 유저에게 '진짜 가치 있는 것을 얻었다'는 실재감을 전달하는가? |
| 3-2 | | 시각적 품격 | 고대비(AAA) 규칙을 지키면서도 색 조합이 지나치게 원색적이거나 경직되어 '병원용 도구'처럼 느껴지지는 않는가? |
| 3-3 | | 햅틱 적절성 | 조작 성공 시의 진동 세기와 리듬이 유저에게 '확신'을 주는 묵직한 피드백으로 전달되는가? |

---

## Freeze 체크리스트

| # | 항목 | 확인 |
|---|------|------|
| 1 | 항목 1~8 Static Layer — 변경 없이 그대로 사용 (변경 시 사유 명시됨) | [x] |
| 2 | 항목 9 CSS 변수 — AAA 대비 보정 컬러 + 시니어 타이포 토큰 확정 | [x] |
| 3 | 항목 10 UX 전략 — 3단계 추론 완료, 빈칸 없이 작성 완료 | [x] |
| 4 | 항목 11 Human Touch 체크리스트 — 빈칸 없이 작성 완료 | [x] |
| 5 | PM · 디자이너 · 엔지니어 3자 합의 완료 | [ ] |

**판정:** Freeze 확정
**확정자:** [이름들] (날짜: 2026-03-05)
