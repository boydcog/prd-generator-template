# SessionStart hook (Windows): 환경 감지 + 가능한 자동 설정 + 상태 보고
# 원칙: 감지는 여기서, 설치/대화는 Claude가 처리
$ErrorActionPreference = "SilentlyContinue"

$ProjectDir = if ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { Get-Location }
Set-Location $ProjectDir

$Status = @()

# ──────────────────────────────────────
# 0. 사용자 아이덴티티 로드
# ──────────────────────────────────────
$UserName = ""
if (Test-Path ".user-identity") {
    $UserName = (Get-Content ".user-identity" -Raw).Trim()
    $Status += "OK 사용자: $UserName"
} else {
    $Status += "WARN 사용자 미설정"
}

# ──────────────────────────────────────
# 1. 의존성 감지 (설치 시도하지 않음)
# ──────────────────────────────────────
$HasGit = $false
$HasGh = $false
$HasWinget = $false

if (Get-Command git -ErrorAction SilentlyContinue) { $HasGit = $true }
if (Get-Command gh -ErrorAction SilentlyContinue) { $HasGh = $true }
if (Get-Command winget -ErrorAction SilentlyContinue) { $HasWinget = $true }

# PATH 새로고침 — 최근 설치된 도구를 감지
if (-not $HasGit -or -not $HasGh) {
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" +
                [System.Environment]::GetEnvironmentVariable("Path","User")
    if (-not $HasGit -and (Get-Command git -ErrorAction SilentlyContinue)) { $HasGit = $true }
    if (-not $HasGh -and (Get-Command gh -ErrorAction SilentlyContinue)) { $HasGh = $true }
}

if ($HasGit) { $Status += "OK git 설치됨" } else { $Status += "FAIL git 미설치" }
if ($HasGh) { $Status += "OK gh CLI 설치됨" } else { $Status += "FAIL gh CLI 미설치" }
if ($HasWinget) { $Status += "OK winget 설치됨" } else { $Status += "WARN winget 미설치" }

# ──────────────────────────────────────
# 2. git repo 확인 / 자동 설정
# ──────────────────────────────────────
# env.yml에서 GitHub owner/repo 로드
$EnvFile = "env.yml"
if (Test-Path $EnvFile) {
    $GhOwner = (Select-String -Path $EnvFile -Pattern "^\s*owner:" | Select-Object -First 1).Line -replace '.*owner:\s*' -replace '\s*#.*'
    $GhRepo = (Select-String -Path $EnvFile -Pattern "^\s*repo:" | Select-Object -First 1).Line -replace '.*repo:\s*' -replace '\s*#.*'
} else {
    $GhOwner = "boydcog"
    $GhRepo = "prd-generator-template"
}
$HttpsUrl = "https://github.com/${GhOwner}/${GhRepo}.git"
$SshUrl = "git@github.com:${GhOwner}/${GhRepo}.git"
$GitReady = $false

if ($HasGit) {
    if (-not (Test-Path ".git")) {
        # ZIP 배포 → git 초기화 (HTTPS 우선, SSH 폴백)
        git init 2>$null
        git remote add origin $HttpsUrl 2>$null
        $fetchResult = git fetch origin 2>&1
        if ($LASTEXITCODE -eq 0) {
            git reset origin/main 2>$null
            git checkout -b main 2>$null
            git branch -u origin/main main 2>$null
            $GitReady = $true
            $Status += "OK git 저장소 초기화 + remote 연결 완료 (HTTPS)"
        } else {
            # HTTPS 실패 → SSH 폴백
            git remote set-url origin $SshUrl 2>$null
            $fetchResult = git fetch origin 2>&1
            if ($LASTEXITCODE -eq 0) {
                git reset origin/main 2>$null
                git checkout -b main 2>$null
                git branch -u origin/main main 2>$null
                $GitReady = $true
                $Status += "OK git 저장소 초기화 + remote 연결 완료 (SSH)"
            } else {
                $Status += "WARN git fetch 실패 (네트워크 또는 인증 문제)"
            }
        }
    } else {
        $GitReady = $true
        # remote URL 확인 — HTTPS 우선으로 교정
        $currentRemote = git remote get-url origin 2>$null
        if (-not $currentRemote) {
            git remote add origin $HttpsUrl 2>$null
            $Status += "OK remote origin 추가됨 (HTTPS)"
        } elseif ($currentRemote -eq $SshUrl) {
            git remote set-url origin $HttpsUrl 2>$null
            $Status += "OK remote URL → HTTPS 전환"
        } elseif ($currentRemote -ne $HttpsUrl) {
            git remote set-url origin $HttpsUrl 2>$null
            $Status += "OK remote URL 업데이트됨"
        }
    }

    # main 브랜치 강제 복귀
    if ($GitReady) {
        $currentBranch = git branch --show-current 2>$null
        if ($currentBranch -and $currentBranch -ne "main") {
            git checkout main 2>$null
            if ($LASTEXITCODE -ne 0) { git checkout -f main 2>$null }
            $Status += "WARN ${currentBranch} -> main 자동 전환"
        }
    }

    # ──────────────────────────────────────
    # 2-2. 잔여 worktree 정리
    # ──────────────────────────────────────
    $WorktreeDir = Join-Path (Split-Path $ProjectDir) ".worktrees"
    if (Test-Path $WorktreeDir) {
        git -C $ProjectDir worktree prune 2>$null
        $Cleaned = 0
        $Failed = 0
        Get-ChildItem -Directory $WorktreeDir -ErrorAction SilentlyContinue | ForEach-Object {
            $result = git -C $ProjectDir worktree remove --force $_.FullName 2>&1
            if ($LASTEXITCODE -eq 0) { $Cleaned++ } else { $Failed++ }
        }
        if ($Cleaned -gt 0) {
            $Status += "WARN 잔여 worktree ${Cleaned}개 정리됨"
        }
        if ($Failed -gt 0) {
            $Status += "WARN worktree ${Failed}개 정리 실패"
        }
        if ((Get-ChildItem $WorktreeDir -ErrorAction SilentlyContinue | Measure-Object).Count -eq 0) {
            Remove-Item $WorktreeDir -ErrorAction SilentlyContinue
        }
    }

    # git pull (rebase 방식, 실패 시 stash + rebase + pop)
    if ($GitReady) {
        $pullResult = git pull --rebase origin main 2>&1
        if ($LASTEXITCODE -eq 0) {
            $Status += "OK git pull 완료"
            # 마이그레이션: 현재 적용 버전 vs 템플릿 요구 버전 비교
            $CurrentSchema = if (Test-Path ".claude/state/_schema_version.txt") { (Get-Content ".claude/state/_schema_version.txt" -Raw).Trim() } else { "v1" }
            $TargetSchema = if (Test-Path ".claude/migrations/_target_version.txt") { (Get-Content ".claude/migrations/_target_version.txt" -Raw).Trim() } else { "v1" }
            if ($CurrentSchema -ne $TargetSchema) {
                $MigrationNeeded = "${CurrentSchema}_to_${TargetSchema}"
                $Status += "WARN MIGRATION_NEEDED=$MigrationNeeded"
            }
        } else {
            # rebase 진행 중이면 abort
            git rebase --abort 2>$null
            # stash → rebase → pop
            $stashResult = git stash 2>&1
            $stashed = $stashResult -match "Saved working directory"
            $pullResult2 = git pull --rebase origin main 2>&1
            if ($LASTEXITCODE -eq 0) {
                if ($stashed) {
                    $popResult = git stash pop 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        $Status += "OK git pull 완료 (stash+rebase 복구)"
                    } else {
                        $Status += "WARN git pull 완료, stash pop 충돌 발생"
                    }
                } else {
                    $Status += "OK git pull 완료 (rebase)"
                }
            } else {
                git rebase --abort 2>$null
                if ($stashed) {
                    $restoreResult = git stash pop 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        $Status += "WARN git pull 실패 (stash+rebase 복구 실패, 로컬 변경 복원됨)"
                    } else {
                        $Status += "WARN git pull 실패 (stash+rebase 복구 실패, stash 복원도 실패)"
                    }
                } else {
                    $Status += "WARN git pull 실패 (stash+rebase 복구 실패)"
                }
            }
        }
    }

    # manifests 보호
    if ($GitReady) {
        Get-ChildItem ".claude/manifests/*.yaml" -ErrorAction SilentlyContinue | ForEach-Object {
            $relPath = Resolve-Path -Relative $_.FullName -ErrorAction SilentlyContinue
            if ($relPath) {
                git update-index --skip-worktree "$relPath" 2>$null
            }
        }
    }
}

# ──────────────────────────────────────
# 3. GH_TOKEN 로드
# ──────────────────────────────────────
$GhTokenLoaded = $false
if (Test-Path ".gh-token") {
    $tokenContent = (Get-Content ".gh-token" -Raw).Trim()
    if ($tokenContent) {
        $env:GH_TOKEN = $tokenContent
        $GhTokenLoaded = $true
        $Status += "OK GitHub 토큰 로드 완료"
    } else {
        $Status += "WARN .gh-token 파일이 비어있음"
    }
} elseif ($env:GH_TOKEN) {
    $GhTokenLoaded = $true
    $Status += "OK GitHub 토큰 (환경변수)"
} else {
    $Status += "FAIL GitHub 토큰 없음"
}

# ──────────────────────────────────────
# 4. 활성 제품 + 프로젝트 상태 확인
# ──────────────────────────────────────
$ActiveProduct = ""
if (Test-Path ".claude/state/_active_product.txt") {
    $ActiveProduct = (Get-Content ".claude/state/_active_product.txt" -Raw).Trim()
    # product_id 검증: 영문자, 숫자, 하이픈, 언더스코어만 허용 (경로 순회 방지)
    if ($ActiveProduct -and $ActiveProduct -notmatch '^[a-zA-Z0-9_-]+$') {
        $Status += "WARN 활성 제품 ID가 유효하지 않습니다 (허용: 영문자, 숫자, -, _)"
        $ActiveProduct = ""
    }
}

$HasProject = $false
$HasSources = $false
$HasEvidence = $false
$HasDocument = $false
if (-not (Get-Variable -Name "MigrationNeeded" -ErrorAction SilentlyContinue)) { $MigrationNeeded = "" }

if ($ActiveProduct) {
    $HasProject = Test-Path ".claude/state/${ActiveProduct}/project.json"
    if (Test-Path ".claude/manifests/drive-sources-${ActiveProduct}.yaml") {
        $content = Get-Content ".claude/manifests/drive-sources-${ActiveProduct}.yaml" -Raw
        if ($content -match "^\s+- name:") { $HasSources = $true }
    }
    $HasEvidence = Test-Path ".claude/knowledge/${ActiveProduct}/evidence/index/sources.jsonl"
    $docFiles = Get-ChildItem ".claude/artifacts/${ActiveProduct}/*/v*/*.md" -ErrorAction SilentlyContinue
    $HasDocument = $docFiles.Count -gt 0
}

# 추천 액션 (auto-generate 중심 — 내부에서 상태별 Phase 자동 판단)
$NextAction = "auto-generate"
if (-not $ActiveProduct) {
    $NextAction = "select-product"
} elseif (-not $HasProject) {
    $NextAction = "auto-generate"
} elseif ($HasDocument) {
    $NextAction = "sync-drive-or-update"
} else {
    $NextAction = "auto-generate"
}

# ──────────────────────────────────────
# 출력: Claude에게 컨텍스트 전달
# ──────────────────────────────────────
Write-Output "=== PRD Generator 시작 ==="
Write-Output "플랫폼: Windows"
$Status | ForEach-Object { Write-Output "  $_" }
Write-Output ""
Write-Output "의존성:"
Write-Output "  git: $HasGit"
Write-Output "  gh: $HasGh"
Write-Output "  winget: $HasWinget"
Write-Output ""
Write-Output "프로젝트 상태:"
Write-Output "  활성 제품: $(if ($ActiveProduct) { $ActiveProduct } else { '미설정' })"
Write-Output "  project.json: $HasProject"
Write-Output "  Drive 소스: $HasSources"
Write-Output "  증거(evidence): $HasEvidence"
Write-Output "  문서 생성됨: $HasDocument"
Write-Output "  GH 토큰: $GhTokenLoaded"
Write-Output "  git 연결: $GitReady"
Write-Output "  사용자: $(if ($UserName) { $UserName } else { '미설정' })"
if ($MigrationNeeded) {
    Write-Output "  RECOMMENDED_ACTION=migration"
    Write-Output "  MIGRATION_NEEDED=$MigrationNeeded"
} else {
    Write-Output "  추천 액션: $NextAction"
}
Write-Output "==========================="

exit 0
