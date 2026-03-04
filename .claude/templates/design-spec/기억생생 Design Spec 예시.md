# Design Spec | 기억생생

- 1~9번 기술 사양, 디자인 시스템 관련 항목이다.
- Product Spec과 1~9번 초안으로, 각 서비스별 Design Spec 최종 문서가 만들어지는데 이미 작성된 1~9번은 기존 틀에서 서비스별 값이 조정되고, 10~11번 항목은 신규 작성된다.

버전: v0.9 | 최종 업데이트: 2026-03-04 | 작성자: Soya

---

## 1. 기술 스택

React + gluestack-ui v2 + Tailwind CSS v4 + Framer Motion

## 2. 토큰 기반 아키텍처

모든 스타일은 임의의 값(Magic Values)을 배제하고, @theme에 매핑된 CSS Variables를 통해서만 제어한다.

Color System: oklch 기반의 색상 체계를 유지하며, 다크/라이트 모드 대응이 가능한 시멘틱 클래스만 사용한다.
- 사용 예시: bg-primary-500, text-surface-900, border-outline-200
- 불가 예시: bg-[#2e6aff], text-black

Radius: 모든 컨테이너(Card, Modal 등)는 고정된 수치(1.3rem)가 담긴 rounded-lg를 강제한다.

Spacing: Tailwind v4 기본 스케일을 준수하되, 임의의 수치(p-[13px]) 사용을 엄격히 금지한다. 또한, 버튼 및 인터랙티브 요소 간격은 오클릭 방지를 위해 최소 12px(gap-3) 이상을 유지한다.

## 3. 컴포넌트 라이브러리 활용

원시 HTML 태그를 지양하고 gluestack-ui v2의 추상화된 레이아웃 컴포넌트를 사용한다.

Layout First: div 대신 Box, HStack, VStack, Center를 사용하여 레이아웃의 의도를 명확히 한다.

Property Mapping: 컴포넌트 스타일링 시 라이브러리 제공 속성을 최우선 적용한다.
- action: primary, success, error, warning, info
- variant: solid, outline, link
- size: md, lg, xl (시니어 가독성을 위해 sm 사이즈 사용을 지양한다)

## 4. 타이포그래피

일관된 브랜드 인상을 위해 가독성을 해치는 시각 효과를 차단한다.

Font: font-sans (Pretendard)를 전역 강제 적용한다.

Minimum Size: 본문 텍스트는 최소 18pt(text-lg), 설명문은 15pt(text-md) 이상을 유지한다.

Shadow Policy: 텍스트 그림자(text-shadow)는 어떠한 경우에도 금지한다.
- 가독성 확보가 필요할 경우 명도 대비(Contrast)나 font-weight 조정을 통해 해결한다.
- 요소 그림자(shadow-md)는 오직 Floating 요소(Popovers, Modals, Floating Action Button 등)와 Card에만 허용한다.
- 단, 버튼의 경우 '클릭 가능함'을 인지시키기 위해 미세한 그림자나 테두리(Border)를 권장한다.

## 5. 아이콘 시스템

아이콘은 @phosphor-icons/react 라이브러리를 사용하며 gluestack과 통합한다.

Pattern: `<Icon as={PhosphorIconName} />` 패턴을 엄격히 준수한다.

Weight: 별도 명시가 없다면 모든 아이콘은 weight="regular"를 기본값으로 한다.

Accessibility: 아이콘은 단독으로 사용하지 않으며, 상태 전달 시 반드시 텍스트 라벨과 병기한다.

## 6. 인터랙션

Framer Motion을 활용하며, 모든 모션은 아래의 표준 수치를 적용하여 0.4초 이내에 완료한다.

| 구분 | 전환 속성 | 필수/선택 |
|------|----------|---------|
| 일반 UI (버튼, 카드) | duration: 0.4, ease: "easeOut" | 부드러운 반응성, 변화 인지 시간 확보 |
| 물리적 피드백 (Spring) | type: "spring", stiffness: 200, damping: 25 | 자연스러운 반동 |
| 페이지 전환 | duration: 0.5, ease: "easyInOut" | 공간 이동의 연속성 유지 |
| 요소 등장/퇴장 | initial: { opacity: 0 }, animate: { opacity: 1 } | 시각적 자극 최소화(y축 이동 배제) |

## 7. 접근성 및 가독성

WCAG 2.1 AAA 기준을 충족하는 디자인을 구현한다.

Contrast: 텍스트와 배경의 명도 대비는 최소 7:1 이상을 유지한다.

Color Blindness: 에러나 경고 상태는 색상만으로 표현하지 않고, 반드시 아이콘 + 텍스트를 함께 제공한다.

Touch Target: 모든 터치 영역은 최소 48px x 48px 이상을 확보하며, 연속 터치 가드(0.5초)를 적용한다.

Dark Mode 가독성: oklch의 L(Luminance) 값을 엄격히 관리하여 저조도 환경에서도 텍스트 번짐이 없도록 설계한다.

## 8. 레이아웃

사용자의 기기 환경에 따라 유동적으로 대응하되, 조작의 일관성을 최우선으로 한다.

### 8-1. 모바일뷰 (Mobile / Handheld)

Bottom-First Action: 모든 핵심 버튼(CTA)은 사용자의 엄지손가락이 닿기 쉬운 화면 하단 고정(Fixed Bottom Bar) 영역에 배치한다.

Vertical Single Stack: 복잡한 그리드(Grid)를 지양하고, 정보는 위에서 아래로 흐르는 단일 열(Single Column) 구조로 배치하여 스크롤 방향을 단순화한다.

Safe Interaction: 하단 시스템 바와 겹치지 않도록 Safe Area(최소 20px 이상)를 강제하고, 오클릭 방지를 위해 버튼 높이를 최소 54px 이상으로 설정한다.

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
  --color-warning-500: oklch(0.769 0.188 70.08); /* [변경] 인지하기 쉬운 호박색 계열 */
  --color-info-500: oklch(0.298 0.057 264.364);

  /* --- UI 배경 및 경계선 --- */
  --background: oklch(0.985 0.001 106.423); /* [변경] 시각 피로도가 적은 미색 */
  --foreground: oklch(0.15 0.01 265);        /* [변경] 고대비 확보를 위한 짙은 컬러 */
  --border: oklch(0.85 0.01 255);            /* [변경] 구분 명확화를 위한 보더 강화 */

  /* --- 그림자: 오브젝트 전용 --- */
  --shadow-color: oklch(0 0 0 / 0.2);       /* [변경] 입체감 인지를 위해 농도 강화 */
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
    /* [변경] 시니어 가독성 최적화: 행간 및 자간 조절 */
    line-height: 1.6;
    letter-spacing: -0.01em;
    text-shadow: none !important;
  }
}
```

## 10. 타겟 맞춤 UX 전략

기억력 저하에 대한 불안을 해소하고, '성공 경험'을 설계하는 핵심 전략이다.

### 10-1. 인지·신체 최적화 (Usability & Accessibility)

- 기억 보조 UI: 인지 저하 시니어는 현재 화면의 목적을 금방 잊을 수 있다. 화면 상단에 항상 "지금은 ~를 하는 중입니다"라는 맥락 정보를 고정 노출하여 인지적 연속성을 부여한다.
- 고대비 및 시각 보정: 황변 현상과 수정체 혼탁을 고려하여 배경과 텍스트의 명도 대비를 7:1(WCAG AAA) 이상으로 확보한다.
- 신체 제어 최적화: 손떨림이나 느린 반응을 고려하여 모든 터치 타겟은 48px 이상으로 설정하고, 실수로 인한 중복 터치를 방지하기 위해 한 번 클릭 후 짧은 시간 동안 재입력을 무시하는 '터치 가드'를 적용한다.
- Step-by-Step Navigation: 한 화면에 하나의 정보만 제공하는 '싱글 태스크' 원칙을 준수하며, 다음 단계로 넘어갈 때 이전 단계의 핵심 요약을 툴팁으로 제공한다.

### 10-2. 감각적 몰입과 피드백 (Sensory Immersion)

- 다감각적 실재감: 시각적 피드백뿐만 아니라 묵직한 진동(Haptic)을 동반하여, 사용자가 본인의 조작이 성공했음을 체감하게 한다. (필요시 음성, 사운드 제공)
- 점진적 속도 제어: 정보가 사라지는 속도를 일반 성인 대비 1.5배 느리게 설정하거나, 사용자가 "다 외웠어요" 버튼을 누르기 전까지 충분히 기다려주는 사용자 주도형 속도 시스템을 적용한다.
- 맥락 유지 애니메이션: 화면 전환 시 갑작스러운 컷(Cut) 이동은 위치 감각을 상실하게 한다. 반드시 부드러운 페이드 인/아웃을 사용하여 공간이 연결되어 있다는 느낌을 준다.

### 10-3. 정서적 안전과 자존감 (Emotional Safety & Self-Esteem)

- 실패 피드백: 오답 시 부정적인 '땡' 소리나 빨간색 X를 절대 사용하지 않는다. 대신 "다시 한번 천천히 살펴볼까요?"라는 공감적 어조와 따뜻한 주황색 계열을 사용하여 심리적 위축을 방지한다.
- 불안 해소 인터벤션: 일정 시간 반응이 없으면 시스템이 "어려우신가요?"라고 먼저 묻는 대신, 캐릭터가 등장해 "저도 이 문제는 조금 어렵네요, 같이 해봐요"라며 동질감을 형성하고 힌트를 제공한다.
- 성취의 가시화: 단순한 점수가 아닌 '모인 현금'과 '오늘의 뇌 건강 출석'을 강조하여, 자신의 행동이 실질적인 가치(돈)와 건강으로 연결됨을 시각화하여 자존감을 높인다.

### 10-4. 자율성과 신뢰 (Autonomy & Trust)

- 존중받는 제안: "훈련을 시작하세요"라는 명령조 대신 "오늘도 뇌 건강을 위해 10분만 투자해보시겠어요?"와 같이 사용자의 자율적인 선택을 존중하는 정중한 어법을 사용한다.
- 기술적 투명성: 현금 포인트가 쌓이는 과정과 데이터 저장 상태를 "안전하게 지갑에 담았습니다"와 같이 이해하기 쉬운 비유와 명확한 상태 메시지로 전달하여 기술에 대한 불신을 제거한다.
- 윤리적 동의: AI의 분석 결과를 전달할 때 의학적 진단이 아닌 '건강한 생활 습관을 위한 코칭'임을 명확히 인지시켜 시스템에 대한 과도한 의존이나 오해를 방지한다.

## 11. 최종 품질 검수 항목

품질 검수 핵심 항목으로, 제품 출시 및 배포 전 반드시 충족해야 하는 필수 요건이다.

### 시각 및 가독성

- [AAA 대비] 모든 핵심 텍스트와 중요 버튼(Primary Action)은 배경과 7:1 이상의 명도 대비를 유지하는가?
- [최소 크기] 일반 본문은 18pt, 부가 설명은 15pt 미만의 텍스트가 단 하나라도 포함되어 있지 않은가?
- [입체적 버튼] 모든 클릭 가능한 요소는 그림자(shadow-md)나 테두리(border)가 있어 평면 이미지와 명확히 구분되는가?
- [텍스트 청결] 가독성을 방해하는 텍스트 그림자(text-shadow)가 완전히 제거되었는가?

### 조작 및 접근성

- [터치 영역] 모든 버튼과 클릭 타겟은 최소 48px x 48px 이상의 크기를 확보하고 있으며, 인접 요소와 12px 이상 떨어져 있는가?
- [단일 조작] 드래그, 스와이프, 더블 탭 없이 단일 탭(Tap)만으로 모든 서비스 이용이 가능한가?
- [연타 가드] 모든 주요 버튼에 0.5초(500ms) 중복 클릭 방지(Throttle) 로직이 적용되어 의도치 않은 연타를 막는가?
- [라벨 병기] 아이콘만 단독으로 노출되는 곳 없이, 반드시 직관적인 한글 텍스트 라벨이 함께 표시되는가?

### 인지 및 정서적 경험

- [맥락 유지] 화면 상단에 현재 어떤 단계(훈련/보상 등)에 있는지 알려주는 맥락 헤더가 상시 노출되는가?
- [사용자 주도 속도] 광고 퀴즈나 학습 콘텐츠가 사용자 확인 없이 자동으로 넘어가지 않고, 사용자가 '확인'을 누를 때까지 기다려주는가?
- [부정 피드백 제거] 오답이나 에러 발생 시 날카로운 소리나 빨간색 'X' 대신, 공감형 문구와 중립적인 알림음이 출력되는가?
- [다감각 보상] 포인트 적립 시 시각(애니메이션) + 청각(효과음) + 촉각(진동) 피드백이 동시에 발생하여 보상감을 극대화하는가?

---

## Freeze 체크리스트

| # | 항목 | 확인 |
|---|------|------|
| 1 | 항목 1~5 이모코그 표준 그대로 사용 (변경 시 사유 명시됨) | [x] |
| 2 | 항목 6 인터랙션 타이밍 — 시니어값 선택 확정 | [x] |
| 3 | 항목 7 접근성 — WCAG AAA 선택 + 대비율 7:1 확정 | [x] |
| 4 | 항목 9 CSS 변수 — foreground 0.15(고대비) + 브랜드 컬러 확정 | [x] |
| 5 | 항목 10 타겟 UX 전략 — 빈칸 없이 작성 완료 | [x] |
| 6 | 항목 11 품질 검수 항목 — 빈칸 없이 작성 완료 | [x] |
| 7 | PM · 디자이너 · 엔지니어 3자 합의 완료 | [ ] |

**판정:** Freeze 확정
**확정자:** [이름들] (날짜: 2026-03-04)
