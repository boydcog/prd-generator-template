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
$HttpsUrl = "https://github.com/boydcog/prd-generator-template.git"
$SshUrl = "git@github.com:boydcog/prd-generator-template.git"
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
        git worktree prune 2>$null
        $Remaining = (Get-ChildItem -Directory $WorktreeDir -ErrorAction SilentlyContinue).Count
        if ($Remaining -gt 0) {
            Get-ChildItem -Directory $WorktreeDir | ForEach-Object {
                git worktree remove --force $_.FullName 2>$null
            }
            $Status += "WARN 잔여 worktree ${Remaining}개 정리됨"
        }
        if ((Get-ChildItem $WorktreeDir -ErrorAction SilentlyContinue).Count -eq 0) {
            Remove-Item $WorktreeDir -ErrorAction SilentlyContinue
        }
    }

    # git pull
    if ($GitReady) {
        $pullResult = git pull origin main 2>&1
        if ($LASTEXITCODE -eq 0) {
            $Status += "OK git pull 완료"
        } else {
            $Status += "WARN git pull 실패"
        }
    }

    # manifests 보호
    if ($GitReady) {
        Get-ChildItem ".claude/manifests/*.yaml" -ErrorAction SilentlyContinue | ForEach-Object {
            git update-index --skip-worktree $_.FullName 2>$null
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
# 4. 프로젝트 상태 확인
# ──────────────────────────────────────
$HasProject = Test-Path ".claude/state/project.json"
$HasSources = $false
if (Test-Path ".claude/manifests/drive-sources.yaml") {
    $content = Get-Content ".claude/manifests/drive-sources.yaml" -Raw
    if ($content -match "^\s+- name:") { $HasSources = $true }
}
$HasEvidence = Test-Path ".claude/knowledge/evidence/index/sources.jsonl"
$HasPrd = (Get-ChildItem ".claude/artifacts/prd/v*/PRD.md" -ErrorAction SilentlyContinue).Count -gt 0

# 추천 액션 (auto-generate 중심 — 내부에서 상태별 Phase 자동 판단)
$NextAction = "auto-generate"
if (-not $HasProject) {
    $NextAction = "auto-generate"
} elseif ($HasPrd) {
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
Write-Output "  project.json: $HasProject"
Write-Output "  Drive 소스: $HasSources"
Write-Output "  증거(evidence): $HasEvidence"
Write-Output "  PRD 생성됨: $HasPrd"
Write-Output "  GH 토큰: $GhTokenLoaded"
Write-Output "  git 연결: $GitReady"
Write-Output "  사용자: $(if ($UserName) { $UserName } else { '미설정' })"
Write-Output "  추천 액션: $NextAction"
Write-Output "==========================="

exit 0
