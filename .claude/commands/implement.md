# /implement — S3 프로토타입 구현

S3 단계에서 완성된 스펙 3종을 읽어 프로토타입 구현을 시작하거나, 스펙이 업데이트된 경우 변경 사항을 반영하여 재구현합니다.

---

## 실행 절차

### Step 0: 전제 조건 확인

1. `.claude/state/_active_product.txt` → `{active_product}` 로드
2. `.claude/state/{active_product}/project.json` → `mvp_stage`, `implementation` 필드 로드
3. `mvp_stage`가 `S3`가 아니면 안내:
   > "이 커맨드는 S3 Prototype 단계에서 실행합니다. 현재 단계: {mvp_stage}"
   → 중단

---

### Step 1: 스펙 최신 버전 탐지

`.claude/artifacts/{active_product}/` 하위에서 각 스펙 문서의 최신 버전 경로를 탐지합니다.

canonical 파일명은 `.claude/spec/document-types.yaml`의 `output_file_name` 기준:
```
스펙 3종 탐지 대상:
  product-spec  → product-spec/v{N}/PRODUCT-SPEC.md
  design-spec   → design-spec/v{N}/DESIGN-SPEC.md
  tech-spec     → tech-spec/v{N}/TECH-SPEC.md
```

탐지 방법:
- `v{숫자}` 형식 폴더 중 가장 큰 숫자 선택
- 해당 폴더 내에서 canonical 파일명(`PRODUCT-SPEC.md` 등) 우선 탐색, 없으면 `output.md` 폴백
- 파일이 없으면 해당 스펙을 "누락"으로 표시

탐지 결과 표시 (모든 경우):
```
스펙 탐지 결과:
  product-spec: v{N} → .claude/artifacts/{active_product}/product-spec/v{N}/PRODUCT-SPEC.md ✓
  design-spec:  v{N} → .claude/artifacts/{active_product}/design-spec/v{N}/DESIGN-SPEC.md ✓
  tech-spec:    v{N} → .claude/artifacts/{active_product}/tech-spec/v{N}/TECH-SPEC.md ✓
```

누락된 스펙이 있으면:
> "다음 스펙이 아직 생성되지 않았습니다: {누락 목록}
> `/auto-generate`로 먼저 스펙을 완성하세요."
→ 중단

---

### Step 2: 구현 모드 판단

`project.json`의 `implementation.spec_refs` 필드를 확인합니다.

**최초 구현** (spec_refs 없거나 빈 객체):
```
모드: 최초 구현
스펙: product-spec v{N}, design-spec v{N}, tech-spec v{N}
```

**re-implement** (spec_refs 있고 현재 최신 버전과 다름):

변경된 스펙을 비교하여 표시:
```
모드: re-implement (스펙 업데이트 감지)
변경된 스펙:
  design-spec: v1 → v2 (이전 구현 기준: v1)
  tech-spec:   변경 없음 (v1)
```

변경된 스펙 파일의 주요 차이를 요약하기 위해 두 버전 파일을 모두 읽고
"변경 요약" 섹션을 작성합니다 (섹션 헤더 수준에서 diff).

**최신 버전과 동일** (spec_refs가 모두 최신):
> "모든 스펙이 최신 버전입니다. 이미 최신 스펙 기준으로 구현이 진행 중입니다."
> "재구현을 강제하려면 `/implement --force`를 사용하세요."
→ 중단 (--force 플래그가 있으면 최초 구현 모드로 진행)

---

### Step 3: project.json spec_refs 업데이트

탐지된 최신 버전으로 `project.json`의 `implementation` 필드를 업데이트합니다.

```json
{
  "implementation": {
    "spec_refs": {
      "product-spec": "v{N}",
      "design-spec": "v{N}",
      "tech-spec": "v{N}"
    },
    "started_at": "{ISO8601 timestamp}",
    "status": "in_progress"
  }
}
```

`started_at`은 최초 구현 시에만 기록합니다. re-implement 시에는 `updated_at`으로 현재 시각을 기록합니다.

---

### Step 4: bkit 감지 및 분기

다음 경로 중 하나라도 존재하면 bkit 환경으로 판단합니다:
- `.claude-plugin` 디렉토리
- `bkit.config.json` 파일
- `.claude/bkit/` 디렉토리

**[bkit 있음] bkit 9-phase 연동 프롬프트 구성:**

```
=== S3 프로토타입 구현 시작 ===

bkit 환경이 감지되었습니다. bkit 9-phase + PDCA 사이클을 사용하여 구현합니다.

참조 스펙:
  - Product Spec: {product_spec_path}
  - Design Spec:  {design_spec_path}
  - Tech Spec:    {tech_spec_path}

구현 지시:
1. 위 스펙 3종을 모두 읽고 구현 요구사항을 파악합니다.
2. bkit의 9-phase 사이클에 따라 구현을 진행합니다.
3. Design Spec의 Static/Dynamic 계층 구조를 준수합니다.
4. Tech Spec의 Core Stack 선택을 그대로 따릅니다.
5. 구현 완료 후 `/gate-review` 실행 전에 내부 시연을 준비합니다.

[re-implement인 경우 추가]
변경된 스펙 요약:
  {변경 요약 내용}
  → 이 변경사항을 기존 구현에 반영합니다.
```

**[bkit 없음] 직접 스펙 전달 프롬프트 구성:**

```
=== S3 프로토타입 구현 시작 ===

참조 스펙:
  - Product Spec: {product_spec_path}
  - Design Spec:  {design_spec_path}
  - Tech Spec:    {tech_spec_path}

구현 지시:
1. 위 스펙 3종을 순서대로 읽어 구현 요구사항을 전체 파악합니다.
2. Tech Spec의 Core Stack 기준으로 프로젝트를 초기화합니다.
3. Design Spec의 화면 정의 순서대로 컴포넌트를 구현합니다.
4. Product Spec의 기능 요구사항을 하나씩 구현하고 확인합니다.
5. 구현 완료 후 내부 시연 준비 → `/gate-review` 실행.

[re-implement인 경우 추가]
변경된 스펙 요약:
  {변경 요약 내용}
  → 이 변경사항을 기존 구현에 반영합니다.
```

---

### Step 5: 구현 시작

위 프롬프트를 출력하고, 각 스펙 파일을 즉시 읽어 구현에 착수합니다.

구현 진행 중 다음 원칙을 준수합니다:
- 스펙에 명시되지 않은 기능은 추가하지 않습니다.
- 스펙 간 충돌이 발견되면 사용자에게 보고하고 결정을 요청합니다.
- 구현 완료 기준은 Design Spec의 체크리스트 항목 전부 통과입니다.

---

## 완료 후

구현이 완료되면:
1. `project.json`의 `implementation.status`를 `"complete"`로 업데이트합니다.
2. 사용자에게 안내:
   > "프로토타입 구현이 완료되었습니다.
   > 내부 시연 후 `/gate-review`로 S3 킬 게이트를 검토하세요."
