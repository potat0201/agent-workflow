<#
.SYNOPSIS
    Nhac truong cua day chuyen 4 agent: Planner -> Coder -> Tester -> Reviewer.

.DESCRIPTION
    - 4 agent khong noi chuyen truc tiep: ho ban giao qua thu muc .bangiao\ (so ban giao).
    - Moi buoc chay mot tien trinh moi (claude -p hoac agy -p) nen ngu canh luon sach.
    - Test rot hoac Reviewer yeu cau sua -> tu quay lai Coder, toi da -SoVong vong.
    - Sau moi buoc, script chup snapshot bang git commit tren nhanh ship/... .
    - Script tu chay lenh test THAT de doi chieu voi bao cao cua Tester.
    - KHONG BAO GIO tu merge hay push. Ban doc ket qua roi tu quyet.

    Ma thoat: 0 xong (CHOT) | 1 loi cai dat | 2 Planner co cau hoi | 3 Coder bi ket
              4 Reviewer CHAN | 5 het so vong | 6 loi may AI (quota, dang nhap...) | 7 sai dinh dang

.EXAMPLE
    .\ship.ps1
    Doc yeu cau tu file YEU-CAU.md va chay ca day chuyen.
.EXAMPLE
    .\ship.ps1 -YeuCau "Them lenh xoa buoi hoc theo so thu tu"
.EXAMPLE
    .\ship.ps1 -KiemTra
    Kiem tra cong cu, dang nhap va goi thu tung may AI (ton rat it quota).
.EXAMPLE
    .\ship.ps1 -ChayThu
    Gia lap ca day chuyen, khong goi AI, khong ton quota.
.EXAMPLE
    .\ship.ps1 -TiepTuc -Reviewer agy
    Chay tiep tu buoc bi dung (vd het quota Claude), doi may cho vai Reviewer.
.EXAMPLE
    .\ship.ps1 -DangNhapClaude -ClaudeConfig D:\claude-pro
    Dang nhap mot tai khoan Claude rieng cho day chuyen (vd Pro ca nhan), khong dung toi dang nhap Claude chinh.
#>
[CmdletBinding()]
param(
    # Yeu cau tinh nang. Bo trong thi doc tu YEU-CAU.md
    [string]$YeuCau = '',
    # So vong sua toi da (moi vong = Coder -> Tester -> Reviewer)
    [ValidateRange(1, 10)][int]$SoVong = 3,
    # May AI cho tung vai: claude | agy
    [ValidateSet('claude', 'agy')][string]$Planner = 'claude',
    [ValidateSet('claude', 'agy')][string]$Coder = 'agy',
    [ValidateSet('claude', 'agy')][string]$Tester = 'agy',
    [ValidateSet('claude', 'agy')][string]$Reviewer = 'claude',
    # Lenh test ma script tu chay de doi chieu. De '' neu du an chua co test.
    [string]$LenhTest = 'python -m pytest -q',
    # Thoi gian toi da cho moi lan goi agy
    [string]$AgyTimeout = '30m',
    # Khong tu duyet lenh cho agy (an toan hon, nhung agy co the khong chay duoc test)
    [switch]$AgyAnToan,
    # CACH 1: mac dinh, het quota mot may thi tu doi sang may con lai. -KhongTuChuyen de tat.
    [switch]$KhongTuChuyen,
    # CACH 2: mac dinh, ca hai may het quota thi cho roi thu lai. -KhongTuCho de tat.
    [switch]$KhongTuCho,
    # So phut cho moi lan, va so lan cho toi da (quota Pro thuong hoi sau moi ~5 tieng)
    [ValidateRange(1, 180)][int]$PhutCho = 20,
    [ValidateRange(0, 100)][int]$SoLanCho = 12,
    # Thu muc dang nhap RIENG cho tai khoan Claude cua day chuyen (vd D:\claude-pro).
    # Bo trong: lay tu bien moi truong SHIP_CLAUDE_CONFIG; neu cung trong thi dung dang nhap Claude binh thuong.
    [string]$ClaudeConfig = '',
    # Dang nhap tai khoan Claude cho day chuyen (mo trinh duyet), vd:
    #   .\ship.ps1 -DangNhapClaude -ClaudeConfig D:\claude-pro
    [switch]$DangNhapClaude,
    [switch]$TiepTuc,
    [switch]$KiemTra,
    [switch]$ChayThu
)

# =====================================================================================
#  CHUAN BI
# =====================================================================================
$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
$env:PYTHONUTF8 = '1'
$env:PYTHONIOENCODING = 'utf-8'

$Root = $PSScriptRoot
Set-Location -LiteralPath $Root
[Environment]::CurrentDirectory = $Root

$BG = Join-Path $Root '.bangiao'
if ($ChayThu) { $BG = Join-Path $Root '.bangiao-chaythu' }
$StateFile = Join-Path $BG 'trang-thai.json'
$TmpDir = Join-Path $Root '.tmp'
$Utf8 = New-Object System.Text.UTF8Encoding($false)
$Fence = ([string][char]96) * 3
$Roles = @('planner', 'coder', 'tester', 'reviewer')
$Engines = @{ planner = $Planner; coder = $Coder; tester = $Tester; reviewer = $Reviewer }
$TuDongChuyen = -not $KhongTuChuyen
$TuDongCho = -not $KhongTuCho
# Vai cua Claude: claude-agents\<vai>.md (dong model:/tools: o dau file + noi dung huong dan)
# Vai cua agy   : .agents\agents\<vai>\agent.md (agy tu doc)
$ClaudeAgentDir = Join-Path $Root 'claude-agents'
$ClaudeSettings = Join-Path $ClaudeAgentDir 'settings.json'
# Quyen cho Claude khi dong vai Coder/Tester: sua file + chay python/pytest
$ClaudeRunTools = 'Read,Write,Edit,Glob,Grep,Bash(python *),Bash(py *),Bash(pytest *),PowerShell(python *),PowerShell(py *),PowerShell(pytest *)'
$script:st = $null

# Tai khoan Claude rieng cho day chuyen: moi thu muc CLAUDE_CONFIG_DIR giu mot dang nhap rieng
$ClaudeConfigFromParam = [bool]$ClaudeConfig
if (-not $ClaudeConfig) { $ClaudeConfig = $env:SHIP_CLAUDE_CONFIG }
if (-not $ClaudeConfig) { $ClaudeConfig = [Environment]::GetEnvironmentVariable('SHIP_CLAUDE_CONFIG', 'User') }
if ($ClaudeConfig) {
    if (-not (Test-Path $ClaudeConfig)) { New-Item -ItemType Directory -Path $ClaudeConfig -Force | Out-Null }
    $env:CLAUDE_CONFIG_DIR = $ClaudeConfig
}

# Giu o C gon: file tam cua cac tien trinh con nam trong .tmp\ cua du an
if (-not (Test-Path $TmpDir)) { New-Item -ItemType Directory -Path $TmpDir -Force | Out-Null }
$env:TEMP = $TmpDir
$env:TMP = $TmpDir

# =====================================================================================
#  TIEN ICH
# =====================================================================================
function Say([string]$Text, [string]$Color = 'Gray') { Write-Host $Text -ForegroundColor $Color }

function Write-Utf8([string]$Path, [string]$Text) {
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    [System.IO.File]::WriteAllText($Path, $Text, $Utf8)
}

function Read-Utf8([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { return '' }
    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Write-Log([string]$Line) {
    if (-not (Test-Path $BG)) { New-Item -ItemType Directory -Path $BG -Force | Out-Null }
    $t = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
    [System.IO.File]::AppendAllText((Join-Path $BG 'nhat-ky.md'), ('- ' + $t + ' | ' + $Line + "`r`n"), $Utf8)
}

function Format-Secs([double]$Seconds) {
    $m = [math]::Floor($Seconds / 60)
    $s = [math]::Round($Seconds - 60 * $m)
    return ('{0}m{1:00}s' -f [int]$m, [int]$s)
}

function Get-Tail([string]$Path, [int]$Count) {
    if (-not (Test-Path -LiteralPath $Path)) { return '' }
    $lines = [System.IO.File]::ReadAllLines($Path, [System.Text.Encoding]::UTF8)
    if ($lines.Length -eq 0) { return '' }
    $start = [math]::Max(0, $lines.Length - $Count)
    return ($lines[$start..($lines.Length - 1)] -join "`r`n")
}

function Remove-Diacritics([string]$Text) {
    # "PHAN_QUYET: CHOT" viet co dau (CHOT/CAN SUA...) van nhan dang duoc
    if (-not $Text) { return '' }
    $n = $Text.Normalize([System.Text.NormalizationForm]::FormD)
    $sb = New-Object System.Text.StringBuilder
    foreach ($ch in $n.ToCharArray()) {
        if ([System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($ch) -ne [System.Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$sb.Append($ch)
        }
    }
    return $sb.ToString().Replace([string][char]0x0111, 'd').Replace([string][char]0x0110, 'D')
}

function Get-Marker([string]$Text, [string]$Key, [string[]]$Values) {
    # Tim dong dau tien co dang  KEY: GIA_TRI  (chap nhan **dam**, `code`, dau cach thay cho _)
    $plain = Remove-Diacritics $Text
    $k = [regex]::Escape($Key).Replace('_', '[_ ]')
    $v = ($Values | ForEach-Object { [regex]::Escape($_).Replace('_', '[_ ]') }) -join '|'
    $pattern = '(?im)^[\s\*#>`_-]*' + $k + '[\s\*`_]*[:=][\s\*`_]*(' + $v + ')\b'
    $m = [regex]::Match($plain, $pattern)
    if ($m.Success) { return $m.Groups[1].Value.ToUpper().Replace(' ', '_') }
    return $null
}

function ConvertFrom-JsonLoose([string]$Raw) {
    if ([string]::IsNullOrWhiteSpace($Raw)) { return $null }
    $s = $Raw.IndexOf('{')
    $e = $Raw.LastIndexOf('}')
    if ($s -lt 0 -or $e -le $s) { return $null }
    try { return ($Raw.Substring($s, $e - $s + 1) | ConvertFrom-Json) } catch { return $null }
}

function Get-AgyAccount {
    # Chi doc email dang dang nhap (khong doc token)
    $f = Join-Path $env:USERPROFILE '.gemini\google_accounts.json'
    if (-not (Test-Path $f)) { return '' }
    try { return [string]((Get-Content $f -Raw | ConvertFrom-Json).active) } catch { return '' }
}

function Get-RoleParam([string]$Role) { return (Get-Culture).TextInfo.ToTitleCase($Role) }

function Read-AgentDef([string]$Path) {
    # Doc file agent dang:  ---  name/description/tools/model  ---  <noi dung huong dan>
    $t = Read-Utf8 $Path
    if (-not $t) { return $null }
    $def = @{ Model = ''; Tools = ''; Body = $t }
    $m = [regex]::Match($t, '(?s)\A\s*---\s*\r?\n(.*?)\r?\n---\s*\r?\n(.*)\z')
    if ($m.Success) {
        $def.Body = $m.Groups[2].Value
        foreach ($line in ($m.Groups[1].Value -split "`r?`n")) {
            $kv = [regex]::Match($line, '^\s*([A-Za-z_]+)\s*:\s*(.*?)\s*$')
            if (-not $kv.Success) { continue }
            $key = $kv.Groups[1].Value.ToLower()
            if ($key -eq 'model') { $def.Model = $kv.Groups[2].Value }
            if ($key -eq 'tools') { $def.Tools = ($kv.Groups[2].Value -replace '\s', '') }
        }
    }
    return $def
}

function Get-ClaudeArgs([string]$Role, [string]$Prompt) {
    # Tuong duong "claude --agent <vai>" nhung doc vai tu claude-agents\ (khong can thu muc .claude)
    $def = Read-AgentDef (Join-Path $ClaudeAgentDir ($Role + '.md'))
    if ($null -eq $def) { return $null }
    $sysFile = Join-Path $TmpDir ('vai-' + $Role + '.md')
    Write-Utf8 $sysFile $def.Body
    # --no-session-persistence: khong luu lich su phien vao o C (C:\Users\...\.claude)
    $a = @('-p', $Prompt, '--append-system-prompt-file', $sysFile, '--output-format', 'json', '--no-session-persistence')
    if (Test-Path $ClaudeSettings) { $a += @('--settings', $ClaudeSettings) }
    if ($def.Model) { $a += @('--model', $def.Model) }
    if ($def.Tools) { $a += @('--tools', $def.Tools) }
    return , $a
}

# ------------------------------------------------------------------- trang thai (de -TiepTuc)
function Save-State {
    $script:st.engines = $Engines
    $script:st.soVong = $SoVong
    $script:st.lenhTest = $LenhTest
    Write-Utf8 $StateFile ($script:st | ConvertTo-Json -Depth 5)
}

function Read-State {
    $t = Read-Utf8 $StateFile
    if (-not $t) { return $null }
    try { $o = $t | ConvertFrom-Json } catch { return $null }
    $h = @{}
    foreach ($p in $o.PSObject.Properties) { $h[$p.Name] = $p.Value }
    return $h
}

# ------------------------------------------------------------------- git
function Test-GitClean {
    $s = ((& git status --porcelain 2>$null) | Out-String).Trim()
    return [string]::IsNullOrEmpty($s)
}

function Save-Snapshot([string]$Message) {
    if ($ChayThu) { Say ('    [chay thu] bo qua git commit: ' + $Message) 'DarkGray'; return }
    & git add -A 2>&1 | Out-Null
    & git diff --cached --quiet 2>$null
    if ($LASTEXITCODE -eq 0) { Say '    (khong co thay doi nao de snapshot)' 'DarkGray'; return }
    & git commit -q -m $Message 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Say '    CANH BAO: git commit that bai - kiem tra: git config user.name / user.email' 'Yellow'
        return
    }
    $h = ((& git rev-parse --short HEAD 2>$null) | Out-String).Trim()
    Say ('    Snapshot ' + $h + ': ' + $Message) 'DarkGray'
}

function Protect-ReadOnly([string]$Role) {
    # Planner/Reviewer chi duoc doc. Neu lo tay sua file code -> cat vao git stash (van lay lai duoc)
    if ($ChayThu) { return }
    $s = ((& git status --porcelain -- . ':(exclude).bangiao' 2>$null) | Out-String).Trim()
    if ($s) {
        & git stash push -u -m ('ship: thay doi ngoai y muon cua ' + $Role) -- . ':(exclude).bangiao' 2>&1 | Out-Null
        Say ('    CANH BAO: ' + $Role + ' da sua file du khong duoc phep. Da cat vao git stash (xem: git stash list).') 'Yellow'
        Write-Log ('CANH BAO | ' + $Role + ' sua file ngoai y muon -> git stash')
    }
}

function Invoke-TestCommand {
    Say ('    Script tu chay lenh test that: ' + $LenhTest) 'DarkGray'
    $out = & cmd /c ($LenhTest + ' 2>&1')
    $code = $LASTEXITCODE
    $text = ($out | Out-String)
    Write-Utf8 (Join-Path $BG 'test-output.txt') ('> ' + $LenhTest + "`r`n(exit code: " + $code + ")`r`n`r`n" + $text)
    if ($code -eq 0) { Say '    Lenh test: QUA (exit 0)' 'Green' } else { Say ('    Lenh test: ROT (exit ' + $code + ')') 'Red' }
    return $code
}

# =====================================================================================
#  GOI MAY AI
# =====================================================================================
function Get-FakeReport([string]$Role, [int]$Vong) {
    # Kich ban gia lap cho -ChayThu: vong 1 test rot -> vong 2 bi yeu cau sua -> vong 3 CHOT
    switch ($Role) {
        'planner' { return "CAU_HOI_MO: KHONG`n# Ke hoach (GIA LAP)`n## Tieu chi hoan thanh`n- [ ] Vi du" }
        'coder' { return "TRANG_THAI: XONG`n## Da lam (GIA LAP)`nKhong sua file nao." }
        'tester' {
            if ($Vong -eq 1) { return "KET_QUA: FAIL`n## Loi can Coder sua (GIA LAP)`n1. test_vi_du rot." }
            return "KET_QUA: PASS`n## Ket qua (GIA LAP)`nTat ca test qua."
        }
        'reviewer' {
            if ($Vong -lt 3) { return "PHAN_QUYET: CAN_SUA`n## Viec can sua (GIA LAP)`n1. Dat ten bien ro hon." }
            return "PHAN_QUYET: CHOT`n## Tom tat (GIA LAP)`nDat yeu cau."
        }
    }
}

function Invoke-Engine([string]$Role, [string]$Engine, [string]$TaskRel, [int]$Vong) {
    $res = @{ Ok = $false; Text = ''; Err = ''; Secs = 0; Cost = $null; Tokens = $null }
    if ($ChayThu) {
        Start-Sleep -Milliseconds 300
        $res.Ok = $true; $res.Text = (Get-FakeReport $Role $Vong); $res.Secs = 0.3
        return $res
    }
    $prompt = 'Ban dang o thu muc goc cua du an. Doc file ' + $TaskRel + ' va lam dung theo huong dan vai tro cua ban. Cau tra loi cuoi cung phai theo dung DINH DANG BAO CAO.'
    $rawDir = Join-Path $BG 'raw'
    if (-not (Test-Path $rawDir)) { New-Item -ItemType Directory -Path $rawDir -Force | Out-Null }
    $tag = '{0}-v{1}-{2}' -f $Role, $Vong, $Engine
    $errFile = Join-Path $rawDir ($tag + '.stderr.txt')
    $sw = [System.Diagnostics.Stopwatch]::StartNew()

    if ($Engine -eq 'claude') {
        $a = Get-ClaudeArgs $Role $prompt
        if ($null -eq $a) { $res.Err = ('Khong tim thay file vai ' + (Join-Path $ClaudeAgentDir ($Role + '.md'))); return $res }
        $a += @('--max-turns', '150')
        if ($Role -eq 'planner' -or $Role -eq 'reviewer') {
            $a += @('--permission-mode', 'dontAsk', '--allowedTools', 'Read,Grep,Glob', '--fallback-model', 'sonnet')
        } else {
            $a += @('--permission-mode', 'acceptEdits', '--allowedTools', $ClaudeRunTools)
        }
        $out = & claude @a 2>> $errFile
    } else {
        $a = @('-p', $prompt, '--agent', $Role, '--output-format', 'json', '--print-timeout', $AgyTimeout)
        if (($Role -eq 'coder' -or $Role -eq 'tester') -and -not $AgyAnToan) { $a += '--dangerously-skip-permissions' }
        $out = & agy @a 2>> $errFile
    }
    $code = $LASTEXITCODE
    $sw.Stop()
    $res.Secs = $sw.Elapsed.TotalSeconds
    $raw = ($out | Out-String)
    Write-Utf8 (Join-Path $rawDir ($tag + '.stdout.json')) $raw

    $j = ConvertFrom-JsonLoose $raw
    if ($null -eq $j) {
        $tail = ''
        if (Test-Path $errFile) { $tail = ((Get-Content $errFile -Tail 6) -join ' ') }
        $res.Err = ('Khong doc duoc ket qua JSON (exit code ' + $code + '). ' + $tail)
        return $res
    }
    if ($Engine -eq 'claude') {
        $res.Cost = $j.total_cost_usd
        if ($j.usage) { $res.Tokens = [int64]$j.usage.input_tokens + [int64]$j.usage.output_tokens + [int64]$j.usage.cache_read_input_tokens + [int64]$j.usage.cache_creation_input_tokens }
        if ($j.is_error -or $code -ne 0) { $res.Err = ('Claude bao loi: ' + $j.subtype + ' ' + $j.result); return $res }
        $res.Text = [string]$j.result
    } else {
        if ($j.usage) { $res.Tokens = [int64]$j.usage.total_tokens }
        if ($j.status -ne 'SUCCESS') { $res.Err = ('agy bao loi: status=' + $j.status + ' ' + $j.error); return $res }
        $res.Text = [string]$j.response
        if ([string]::IsNullOrWhiteSpace($res.Text) -and $j.result) { $res.Text = [string]$j.result }
    }
    if ([string]::IsNullOrWhiteSpace($res.Text)) { $res.Err = 'Agent tra ve cau tra loi rong.'; return $res }
    $res.Ok = $true
    return $res
}

function Test-QuotaError([string]$Err) {
    # Loi lien quan het quota / gioi han luot dung / qua tai (co the thu lai sau)
    return ($Err -match 'limit|quota|resource_exhausted|429|rate|overloaded|529|exhausted|too many')
}

function Get-OtherEngine([string]$Engine) {
    if ($Engine -eq 'claude') { return 'agy' }
    return 'claude'
}

function Test-EngineReady([string]$Engine) {
    if ($ChayThu) { return $true }
    return [bool](Get-Command $Engine -ErrorAction SilentlyContinue)
}

function Show-ErrorHint([string]$Err, [string]$Role, [string]$Engine) {
    if (Test-QuotaError $Err) {
        Say '    => Co ve da het quota / gioi han luot dung cua may nay.' 'Yellow'
    } elseif ($Err -match 'auth|login|credential|401|403|sign in') {
        Say ('    => Co ve ' + $Engine + ' chua dang nhap. Mo PowerShell, go:  ' + $Engine + '  roi dang nhap.') 'Yellow'
    }
    Say '    Khi da khac phuc (hoac quota da hoi lai), chay tiep dung buoc nay:' 'Yellow'
    Say '        .\ship.ps1 -TiepTuc' 'White'
    Say ('    Hoac doi may cho vai nay:  .\ship.ps1 -TiepTuc -' + (Get-RoleParam $Role) + ' ' + (Get-OtherEngine $Engine)) 'White'
    Say ('    Chi tiet loi: ' + (Join-Path $BG 'raw')) 'DarkGray'
}

function Invoke-Step([string]$Role, [string]$TaskRel, [int]$Vong) {
    $daThu = @{}   # may da thu trong chu ky nay (reset sau moi lan cho)
    $soLanDaCho = 0
    while ($true) {
        $engine = $Engines[$Role]
        Say ''
        Say ('==> [{0}] Vong {1}/{2}  {3}  (may: {4})' -f (Get-Date).ToString('HH:mm:ss'), $Vong, $SoVong, $Role.ToUpper(), $engine) 'Cyan'
        $r = Invoke-Engine $Role $engine $TaskRel $Vong
        $daThu[$engine] = $true
        if ($r.Ok) {
            $cost = ''
            if ($r.Tokens) { $cost += (' | {0:N0} token' -f [double]$r.Tokens) }
            if ($r.Cost) { $cost += (' | uoc tinh neu tra theo API: ${0:N2}' -f [double]$r.Cost) }
            Say ('    Xong sau ' + (Format-Secs $r.Secs) + $cost) 'Green'
            Write-Log ('vong {0} | {1} ({2}) | xong sau {3}{4}' -f $Vong, $Role, $engine, (Format-Secs $r.Secs), $cost)
            return $r
        }
        Say ('    LOI: ' + $r.Err) 'Red'
        Write-Log ('vong {0} | {1} ({2}) | LOI | {3}' -f $Vong, $Role, $engine, $r.Err)
        $quota = Test-QuotaError $r.Err

        # CACH 1: tu doi sang may con lai (chi khi loi quota va may kia san sang, chua thu trong chu ky nay)
        if ($quota -and $TuDongChuyen) {
            $other = Get-OtherEngine $engine
            if (-not $daThu[$other] -and (Test-EngineReady $other)) {
                Say ('    => ' + $engine + ' het quota. Tu doi vai ' + $Role.ToUpper() + ' sang ' + $other + ' roi thu lai.') 'Yellow'
                Write-Log ('vong {0} | {1} tu doi {2} -> {3} (het quota)' -f $Vong, $Role, $engine, $other)
                $Engines[$Role] = $other
                Save-State
                continue
            }
        }

        # CACH 2: ca hai may deu het quota -> cho roi thu lai
        if ($quota -and $TuDongCho -and $soLanDaCho -lt $SoLanCho) {
            $soLanDaCho++
            $tiep = (Get-Date).AddMinutes($PhutCho).ToString('HH:mm')
            Say ('    => Ca hai may deu het quota. Cho ' + $PhutCho + ' phut (den ' + $tiep + ') roi thu lai — lan ' + $soLanDaCho + '/' + $SoLanCho + '.') 'Yellow'
            Say '       (Ban co the bam Ctrl+C; sau nay chay tiep bang:  .\ship.ps1 -TiepTuc)' 'DarkGray'
            Write-Log ('vong {0} | {1} | cho {2} phut roi thu lai (lan {3}/{4})' -f $Vong, $Role, $PhutCho, $soLanDaCho, $SoLanCho)
            Save-State
            Start-Sleep -Seconds ($PhutCho * 60)
            $daThu = @{}   # sau khi cho, cho phep thu lai ca hai may
            continue
        }

        # Khong khac phuc duoc: dung lai (van luu trang thai de -TiepTuc)
        Show-ErrorHint $r.Err $Role $engine
        Stop-Run 6 ('vong {0} | {1} ({2}) loi: {3}' -f $Vong, $Role, $engine, $r.Err)
    }
}

# =====================================================================================
#  NOI DUNG NHIEM VU GUI CHO TUNG VAI (huong dan chi tiet nam trong file agent)
# =====================================================================================
function New-TaskText([string]$Role, [int]$Vong, [string]$Extra = '') {
    $fb = ''
    if ($Vong -gt 1) { $fb = '- .bangiao/phan-hoi.md   (PHAN HOI tu vong truoc - PHAI sua het tung muc)' }
    switch ($Role) {
        'planner' {
            return @"
# NHIEM VU CHO PLANNER

Doc cac file sau:
- .bangiao/yeu-cau.md   (yeu cau cua nguoi dung)
- AGENTS.md             (quy uoc du an)
- codebase hien tai     (chi doc)

Viet BAN KE HOACH theo dung DINH DANG BAO CAO trong huong dan vai tro cua ban.
Khong ghi file nao: nguoi dieu phoi se tu luu cau tra loi cuoi cung cua ban thanh .bangiao/ke-hoach.md.
"@
        }
        'coder' {
            return @"
# NHIEM VU CHO CODER - VONG $Vong/$SoVong

Doc cac file sau:
- AGENTS.md
- .bangiao/ke-hoach.md   (ban ke hoach - lam dung theo)
$fb

Lenh test cua du an: $LenhTest
Khong git commit / push / stash: nguoi dieu phoi tu chup snapshot sau buoc nay.
Cau tra loi cuoi cung = bao cao theo DINH DANG BAO CAO (nguoi dieu phoi luu thanh .bangiao/thay-doi.md).
"@
        }
        'tester' {
            return @"
# NHIEM VU CHO TESTER - VONG $Vong/$SoVong

Doc cac file sau:
- AGENTS.md
- .bangiao/ke-hoach.md   (dac biet muc Tieu chi hoan thanh)
- .bangiao/thay-doi.md   (bao cao cua Coder o vong nay)

Lenh test cua du an: $LenhTest
Chi tao/sua file test. KHONG sua code san pham.
Sau khi ban xong, nguoi dieu phoi se tu chay lai lenh test de doi chieu.
Cau tra loi cuoi cung = bao cao theo DINH DANG BAO CAO (nguoi dieu phoi luu thanh .bangiao/ket-qua-test.md).
"@
        }
        'reviewer' {
            return @"
# NHIEM VU CHO REVIEWER - VONG $Vong/$SoVong

Doc cac file sau:
- .bangiao/yeu-cau.md
- .bangiao/ke-hoach.md
- .bangiao/thay-doi.md       (bao cao cua Coder)
- .bangiao/ket-qua-test.md   (bao cao cua Tester)
- .bangiao/test-output.txt   (output lenh test THAT do nguoi dieu phoi chay)
- .bangiao/diff.patch        (toan bo thay doi code so voi luc bat dau)

Cac file code da thay doi:
$Extra

Chi doc, KHONG sua file nao.
Cau tra loi cuoi cung = bao cao theo DINH DANG BAO CAO (nguoi dieu phoi luu thanh .bangiao/danh-gia.md).
"@
        }
    }
}

function Get-Request {
    if ($YeuCau) { return $YeuCau.Trim() }
    $t = Read-Utf8 (Join-Path $Root 'YEU-CAU.md')
    return ([regex]::Replace($t, '(?s)<!--.*?-->', '')).Trim()
}

function Move-NextRound([string]$Why) {
    $script:st.vong = [int]$script:st.vong + 1
    $script:st.buoc = 'coder'
    $script:st.lyDo = $Why
}

function Stop-Run([int]$Code, [string]$Why) {
    # Dung giua chung: ghi nhat ky, luu trang thai, chup snapshot (de -TiepTuc hoac quay lai duoc)
    Write-Log ('DUNG | ' + $Why)
    Save-State
    Save-Snapshot ('ship: tam dung - ' + $Why)
    exit $Code
}

function Assert-Engines {
    if ($ChayThu) { return }
    foreach ($eng in @($Engines.Values | Select-Object -Unique)) {
        if (-not (Get-Command $eng -ErrorAction SilentlyContinue)) {
            Say ('Chua cai "' + $eng + '" (hoac chua co trong PATH). Chay  .\ship.ps1 -KiemTra  de xem chi tiet.') 'Red'
            Say ('Hoac chuyen cac vai dang dung ' + $eng + ' sang may con lai, vd:  -Coder claude -Tester claude') 'DarkGray'
            exit 1
        }
    }
}

# =====================================================================================
#  KIEM TRA CAI DAT (-KiemTra)
# =====================================================================================
function Invoke-Doctor {
    $bad = 0
    Say ''
    Say '=== KIEM TRA CAI DAT ===' 'Cyan'
    Say '--- Cong cu' 'Cyan'
    foreach ($c in @('git', 'python', 'claude', 'agy')) {
        if (Get-Command $c -ErrorAction SilentlyContinue) {
            $ver = (((& $c --version 2>&1) | Out-String).Trim() -split "`n")[0].Trim()
            Say ('  [OK] {0,-7} {1}' -f $c, $ver) 'Green'
        } else {
            $bad++
            Say ('  [X]  {0,-7} chua cai hoac chua co trong PATH (thu mo cua so PowerShell moi)' -f $c) 'Red'
        }
    }
    $pt = ((& cmd /c 'python -m pytest --version 2>&1') | Out-String).Trim()
    if ($LASTEXITCODE -eq 0) { Say ('  [OK] pytest  ' + $pt) 'Green' }
    else { $bad++; Say '  [X]  pytest chua cai. Cai bang:  python -m pip install --user pytest' 'Red' }

    Say '--- Tai khoan Claude (Planner, Reviewer)' 'Cyan'
    if ($ClaudeConfig) { Say ('  Dang nhap rieng cua day chuyen: ' + $ClaudeConfig) 'Gray' } else { Say '  Dung dang nhap Claude chinh cua may' 'Gray' }
    if (Get-Command claude -ErrorAction SilentlyContinue) {
        $auth = ((& claude auth status --text 2>&1) | Out-String).Trim()
        if ($LASTEXITCODE -eq 0) {
            foreach ($line in ($auth -split "`n")) { if ($line.Trim()) { Say ('  ' + $line.Trim()) 'Gray' } }
        } else { $bad++; Say '  [X]  Claude chua dang nhap. Chay:  .\ship.ps1 -DangNhapClaude -ClaudeConfig D:\claude-pro' 'Red' }
    }
    Say '--- Tai khoan Google cua agy (Coder, Tester)' 'Cyan'
    $ga = Get-AgyAccount
    if ($ga) { Say ('  ' + $ga) 'Gray' } else { Say '  (khong doc duoc - chay  agy  mot lan de dang nhap)' 'Yellow' }

    Say '--- File agent' 'Cyan'
    foreach ($r in $Roles) {
        $f1 = Test-Path (Join-Path $ClaudeAgentDir ($r + '.md'))
        $f2 = Test-Path (Join-Path $Root ('.agents\agents\' + $r + '\agent.md'))
        if ($f1 -and $f2) { Say ('  [OK] {0,-8} claude-agents\{0}.md  +  .agents\agents\{0}\agent.md' -f $r) 'Green' }
        else { $bad++; Say ('  [X]  {0,-8} thieu file vai (claude-agents\{0}.md hoac .agents\agents\{0}\agent.md)' -f $r) 'Red' }
    }

    Say '--- Git' 'Cyan'
    & git rev-parse --is-inside-work-tree 2>$null | Out-Null
    if ($LASTEXITCODE -eq 0) {
        $br = ((& git rev-parse --abbrev-ref HEAD 2>$null) | Out-String).Trim()
        $cleanText = 'CO THAY DOI CHUA COMMIT'
        if (Test-GitClean) { $cleanText = 'sach' }
        Say ('  [OK] git repo | nhanh: {0} | trang thai: {1}' -f $br, $cleanText) 'Green'
        $name = ((& git config user.name 2>$null) | Out-String).Trim()
        if (-not $name) { $bad++; Say '  [X]  chua dat ten git:  git config --global user.name "Ten Ban"' 'Red' }
    } else { $bad++; Say '  [X]  chua phai git repo:  git init; git add -A; git commit -m "khoi tao"' 'Red' }

    Say '--- Goi thu tung may AI (ton rat it quota)' 'Cyan'
    # Hoi vai: neu file vai duoc nap dung, agent se tra loi dung ten vai (agy bo qua ten agent sai ma khong bao loi)
    $ping = 'Day chi la kiem tra ket noi. Khong doc, khong sua file nao. Theo huong dan he thong cua ban, ban dong vai gi trong day chuyen 4 agent? Chi tra loi dung 1 tu viet hoa.'
    $used = @($Engines.Values | Select-Object -Unique)
    if (($used -contains 'claude') -and (Get-Command claude -ErrorAction SilentlyContinue)) {
        $a = Get-ClaudeArgs 'planner' $ping
        $j = $null
        if ($a) {
            $a += @('--max-turns', '3', '--permission-mode', 'dontAsk')
            $o = & claude @a 2>$null
            $j = ConvertFrom-JsonLoose ($o | Out-String)
        }
        if ($j -and -not $j.is_error) {
            $ans = ([string]$j.result).Trim()
            if ((Remove-Diacritics $ans) -match 'PLANNER') { Say ('  [OK] claude nhan dung vai: ' + $ans) 'Green' }
            else { $bad++; Say ('  [!]  claude tra loi "' + $ans + '" - co the chua nap claude-agents\planner.md') 'Yellow' }
        }
        else {
            $bad++
            $msg = 'khong nhan duoc JSON'
            if ($j) { $msg = [string]$j.result }
            Say ('  [X]  claude loi: ' + $msg) 'Red'
        }
    }
    if (($used -contains 'agy') -and (Get-Command agy -ErrorAction SilentlyContinue)) {
        $o = & agy -p $ping --agent coder --output-format json --print-timeout 3m
        $j = ConvertFrom-JsonLoose ($o | Out-String)
        if ($j -and $j.status -eq 'SUCCESS') {
            $ans = ([string]$j.response).Trim()
            if ((Remove-Diacritics $ans) -match 'CODER') { Say ('  [OK] agy nhan dung vai: ' + $ans) 'Green' }
            else { $bad++; Say ('  [!]  agy tra loi "' + $ans + '" - co the chua nap .agents\agents\coder\agent.md') 'Yellow' }
        }
        else {
            $bad++
            $msg = 'khong nhan duoc JSON - co the chua dang nhap: go  agy  de dang nhap'
            if ($j) { $msg = ('status=' + $j.status + ' ' + $j.error) }
            Say ('  [X]  agy loi: ' + $msg) 'Red'
        }
    }
    Say ''
    if ($bad -eq 0) { Say 'MOI THU SAN SANG. Chay:  .\ship.ps1' 'Green'; exit 0 }
    Say ('Con {0} muc can xu ly (cac dong [X] o tren).' -f $bad) 'Yellow'
    exit 1
}

function Show-Summary {
    $v = $script:st.vong
    Say ''
    Say '=================================================================' 'Green'
    Say (' XONG! Reviewer da CHOT o vong {0}/{1}.' -f $v, $SoVong) 'Green'
    Say '=================================================================' 'Green'
    if ($ChayThu) {
        Say ' (Day la CHAY THU: khong goi AI, khong sua code, khong commit.)' 'Yellow'
        Say (' So ban giao gia lap nam o: ' + $BG) 'White'
        return
    }
    Say (' Nhanh lam viec : ' + $script:st.nhanh) 'White'
    Say ' Doc danh gia   : .bangiao\danh-gia.md' 'White'
    Say (' Xem thay doi   : git diff ' + $script:st.base.Substring(0, 7) + ' HEAD --stat') 'White'
    $log = ((& git log --oneline ($script:st.base + '..HEAD') 2>$null) | Out-String).Trim()
    if ($log) {
        Say ' Cac snapshot:' 'DarkGray'
        foreach ($line in ($log -split "`n")) { Say ('   ' + $line.Trim()) 'DarkGray' }
    }
    Say ''
    Say ' Khi da xem va hai long, tu gop vao nhanh chinh (script KHONG tu lam buoc nay):' 'Cyan'
    if ($script:st.nhanhGoc -and ($script:st.nhanhGoc -ne $script:st.nhanh)) {
        Say ('     git switch ' + $script:st.nhanhGoc) 'White'
        Say ('     git merge ' + $script:st.nhanh) 'White'
    } else {
        Say ('     (gop nhanh ' + $script:st.nhanh + ' vao nhanh chinh cua ban)') 'White'
    }
}

# =====================================================================================
#  CHUONG TRINH CHINH
# =====================================================================================
if ($DangNhapClaude) {
    if (-not $ClaudeConfig) { Say 'Hay chon noi luu dang nhap, vi du:  .\ship.ps1 -DangNhapClaude -ClaudeConfig D:\claude-pro' 'Red'; exit 1 }
    Say ('Dang nhap tai khoan Claude cho day chuyen (luu o ' + $ClaudeConfig + ')') 'Cyan'
    Say 'Trinh duyet se mo trang dang nhap claude.ai. Neu trang dang hien tai khoan khac (vd tai khoan cong ty),' 'Yellow'
    Say 'hay doi sang DUNG tai khoan ban muon dung cho day chuyen roi moi bam Authorize.' 'Yellow'
    & claude auth login
    $code = $LASTEXITCODE
    & claude auth status --text
    if ($code -eq 0 -and $ClaudeConfigFromParam) {
        # Nho thu muc nay cho cac lan chay sau (bien moi truong cua user, khong anh huong Claude chinh)
        [Environment]::SetEnvironmentVariable('SHIP_CLAUDE_CONFIG', $ClaudeConfig, 'User')
        Say ('Da nho: cac lan chay .\ship.ps1 sau se dung tai khoan nay (SHIP_CLAUDE_CONFIG=' + $ClaudeConfig + ')') 'Green'
    }
    exit $code
}

if ($KiemTra) { Invoke-Doctor }

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Say 'Chua cai git.' 'Red'; exit 1 }
& git rev-parse --is-inside-work-tree 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) {
    Say 'Thu muc nay chua phai git repo. Chay lan luot:' 'Red'
    Say '    git init' 'White'
    Say '    git add -A' 'White'
    Say '    git commit -m "khoi tao"' 'White'
    exit 1
}

if ($TiepTuc) {
    $script:st = Read-State
    if (-not $script:st) { Say ('Khong co gi de chay tiep (khong thay ' + $StateFile + '). Chay moi:  .\ship.ps1') 'Red'; exit 1 }
    if ($script:st.buoc -eq 'xong') { Say 'Lan chay truoc da XONG. Muon lam yeu cau moi thi chay:  .\ship.ps1' 'Green'; exit 0 }
    # Giu cau hinh cua lan chay truoc, tru khi ban truyen tham so moi
    foreach ($r in $Roles) {
        $pn = Get-RoleParam $r
        if (-not $PSBoundParameters.ContainsKey($pn) -and $script:st.engines -and $script:st.engines.$r) { $Engines[$r] = [string]$script:st.engines.$r }
    }
    if (-not $PSBoundParameters.ContainsKey('SoVong') -and $script:st.soVong) { $SoVong = [int]$script:st.soVong }
    if (-not $PSBoundParameters.ContainsKey('LenhTest') -and ($null -ne $script:st.lenhTest)) { $LenhTest = [string]$script:st.lenhTest }
    Assert-Engines
    $cur = ((& git rev-parse --abbrev-ref HEAD 2>$null) | Out-String).Trim()
    if (-not $ChayThu -and $cur -ne $script:st.nhanh) {
        Say ('Ban dang o nhanh "' + $cur + '", nhung lan chay do nam o nhanh "' + $script:st.nhanh + '". Chay:  git switch ' + $script:st.nhanh) 'Red'
        exit 1
    }
    Say ('Chay tiep tu buoc ' + ([string]$script:st.buoc).ToUpper() + ', vong ' + $script:st.vong) 'Cyan'
} else {
    $req = Get-Request
    if (-not $req) { Say 'Chua co yeu cau. Viet yeu cau vao YEU-CAU.md, hoac dung:  .\ship.ps1 -YeuCau "..."' 'Red'; exit 1 }
    Assert-Engines
    $branch = ((& git rev-parse --abbrev-ref HEAD 2>$null) | Out-String).Trim()
    $origBranch = $branch
    if (-not $ChayThu) {
        if (-not (Test-GitClean)) {
            Say 'Co thay doi chua commit. Commit truoc cho an toan roi chay lai:' 'Red'
            Say '    git add -A' 'White'
            Say '    git commit -m "wip"' 'White'
            Say '(Neu lan chay truoc bi dung giua chung, dung:  .\ship.ps1 -TiepTuc)' 'DarkGray'
            exit 1
        }
        if ($branch -eq 'main' -or $branch -eq 'master') {
            $branch = 'ship/' + (Get-Date).ToString('yyyyMMdd-HHmm')
            & git switch -c $branch 2>&1 | Out-Null
            if ($LASTEXITCODE -ne 0) { Say ('Khong tao duoc nhanh ' + $branch) 'Red'; exit 1 }
            Say ('Da tao nhanh lam viec: ' + $branch + '  (nhanh ' + $origBranch + ' khong bi dung toi)') 'Cyan'
        } elseif ($branch -like 'ship/*') {
            Say ('Ban dang o nhanh ' + $branch + ' cua lan truoc: lan nay se lam tiep tren nhanh nay.') 'Yellow'
            Say '(Muon bat dau tu nhanh chinh thi bam Ctrl+C, go  git switch main  roi chay lai.)' 'DarkGray'
        }
    }
    $base = ((& git rev-parse HEAD 2>$null) | Out-String).Trim()
    if (-not $base) { Say 'Repo chua co commit nao. Chay:  git add -A; git commit -m "khoi tao"' 'Red'; exit 1 }
    # Don so ban giao cu (lich su cu van nam trong git log)
    if (Test-Path $BG) { Remove-Item -LiteralPath $BG -Recurse -Force }
    New-Item -ItemType Directory -Path $BG -Force | Out-Null
    Write-Utf8 (Join-Path $BG 'yeu-cau.md') ("# Yeu cau`r`n`r`n" + $req + "`r`n")
    $nguon = 'file'
    if ($YeuCau) { $nguon = 'thamso' }
    $script:st = @{ buoc = 'planner'; vong = 1; nhanh = $branch; nhanhGoc = $origBranch; base = $base; nguon = $nguon; batDau = (Get-Date).ToString('s'); lyDo = '' }
    Save-State
    Write-Log ('BAT DAU | nhanh ' + $branch + ' | ' + (($Roles | ForEach-Object { $_ + '=' + $Engines[$_] }) -join ', ') + ' | toi da ' + $SoVong + ' vong')
}

Say ''
Say '=== DAY CHUYEN 4 AGENT ===' 'Cyan'
Say (' Planner: {0} | Coder: {1} | Tester: {2} | Reviewer: {3} | toi da {4} vong' -f $Engines.planner, $Engines.coder, $Engines.tester, $Engines.reviewer, $SoVong) 'White'
Say (' So ban giao: ' + $BG) 'DarkGray'
$ttChuyen = 'tat'; if ($TuDongChuyen) { $ttChuyen = 'bat' }
$ttCho = 'tat'; if ($TuDongCho) { $ttCho = ('bat, cho ' + $PhutCho + ' phut x ' + $SoLanCho + ' lan') }
Say (' Het quota: tu doi may = ' + $ttChuyen + ' | tu cho roi thu lai = ' + $ttCho) 'DarkGray'
if ($ClaudeConfig) { Say (' Claude dung dang nhap rieng: ' + $ClaudeConfig) 'DarkGray' }
$agyAcc = Get-AgyAccount
if ($agyAcc -and ($Engines.Values -contains 'agy')) { Say (' agy dung tai khoan Google: ' + $agyAcc) 'DarkGray' }
if ($ChayThu) { Say ' CHE DO CHAY THU: gia lap, khong goi AI, khong commit.' 'Yellow' }
$watch = [System.Diagnostics.Stopwatch]::StartNew()

while ($true) {
    $v = [int]$script:st.vong
    switch ($script:st.buoc) {
        'planner' {
            if ($TiepTuc -and ($YeuCau -or $script:st.nguon -eq 'file')) {
                # Lam lai ke hoach voi yeu cau moi nhat (vd sau khi ban da tra loi cau hoi trong YEU-CAU.md)
                $req = Get-Request
                if ($req) { Write-Utf8 (Join-Path $BG 'yeu-cau.md') ("# Yeu cau`r`n`r`n" + $req + "`r`n") }
            }
            $task = 'nhiem-vu/planner.md'
            Write-Utf8 (Join-Path $BG $task) (New-TaskText 'planner' $v)
            $r = Invoke-Step 'planner' ('.bangiao/' + $task) $v
            Write-Utf8 (Join-Path $BG 'ke-hoach.md') $r.Text
            Protect-ReadOnly 'planner'
            Save-Snapshot ('ship: ke hoach (' + $Engines.planner + ')')
            $q = Get-Marker $r.Text 'CAU_HOI_MO' @('CO', 'KHONG')
            if ($q -eq 'CO') {
                Say ''
                Say 'Planner can ban tra loi vai cau hoi truoc khi code (trich .bangiao\ke-hoach.md):' 'Yellow'
                foreach ($line in (($r.Text -split "`r?`n") | Select-Object -First 40)) { Say ('    ' + $line) 'White' }
                Say ''
                Say 'Viet cau tra loi xuong cuoi YEU-CAU.md, roi chay:  .\ship.ps1 -TiepTuc' 'Cyan'
                Stop-Run 2 'Planner co cau hoi mo'
            }
            if (-not $q) { Say '    (Planner khong ghi dong CAU_HOI_MO - coi nhu khong co cau hoi)' 'DarkGray' }
            $script:st.buoc = 'coder'
            $script:st.vong = 1
        }
        'coder' {
            if ($v -gt $SoVong) {
                Say ''
                Say ('Da het ' + $SoVong + ' vong ma chua dat (' + $script:st.lyDo + '). Dung lai de ban quyet dinh.') 'Yellow'
                Say '    Xem van de con lai:  .bangiao\phan-hoi.md' 'White'
                Say ('    Cho them vong:  .\ship.ps1 -TiepTuc -SoVong ' + $v) 'White'
                Stop-Run 5 ('het ' + $SoVong + ' vong - ' + $script:st.lyDo)
            }
            $task = 'nhiem-vu/coder-v' + $v + '.md'
            Write-Utf8 (Join-Path $BG $task) (New-TaskText 'coder' $v)
            $r = Invoke-Step 'coder' ('.bangiao/' + $task) $v
            Write-Utf8 (Join-Path $BG 'thay-doi.md') $r.Text
            Save-Snapshot ('ship v' + $v + ': coder (' + $Engines.coder + ')')
            $s = Get-Marker $r.Text 'TRANG_THAI' @('XONG', 'KET')
            if ($s -eq 'KET') {
                Say ''
                Say 'Coder bao BI KET, can ban xem:  .bangiao\thay-doi.md' 'Yellow'
                Say 'Sua .bangiao\ke-hoach.md (hoac bo sung YEU-CAU.md), roi chay:  .\ship.ps1 -TiepTuc' 'Cyan'
                Stop-Run 3 ('vong ' + $v + ' - Coder bi ket')
            }
            $script:st.buoc = 'tester'
        }
        'tester' {
            $task = 'nhiem-vu/tester-v' + $v + '.md'
            Write-Utf8 (Join-Path $BG $task) (New-TaskText 'tester' $v)
            $r = Invoke-Step 'tester' ('.bangiao/' + $task) $v
            Write-Utf8 (Join-Path $BG 'ket-qua-test.md') $r.Text
            $said = Get-Marker $r.Text 'KET_QUA' @('PASS', 'FAIL')
            $real = $null
            if ($LenhTest) {
                $real = 'FAIL'
                if ((Invoke-TestCommand) -eq 0) { $real = 'PASS' }
            }
            Save-Snapshot ('ship v' + $v + ': tester (' + $Engines.tester + ')')
            # Chi coi la QUA khi khong ben nao bao rot
            $pass = (($said -eq 'PASS') -and ($real -ne 'FAIL')) -or ((-not $said) -and ($real -eq 'PASS'))
            $note = ''
            if ($said -eq 'PASS' -and $real -eq 'FAIL') { $note = 'Tester bao PASS nhung lenh test that lai ROT.' }
            if ($said -eq 'FAIL' -and $real -eq 'PASS') { $note = 'Tester bao FAIL du lenh test van qua (xem muc Loi can Coder sua).' }
            if ($note) { Say ('    Luu y: ' + $note) 'Yellow' }
            Write-Log ('vong ' + $v + ' | ket qua test: tester=' + $said + ', lenh test that=' + $real)
            if ($pass) {
                Say '    => Test QUA, chuyen sang Reviewer.' 'Green'
                $script:st.buoc = 'reviewer'
            } else {
                Say '    => Test ROT, gui phan hoi ve Coder.' 'Yellow'
                $fb = '# PHAN HOI TU TESTER (vong ' + $v + ")`r`n`r`n"
                if ($note) { $fb += ('> Luu y tu nguoi dieu phoi: ' + $note + "`r`n`r`n") }
                $fb += ($r.Text + "`r`n`r`n## Output lenh test that (doan cuoi)`r`n" + $Fence + "`r`n" + (Get-Tail (Join-Path $BG 'test-output.txt') 60) + "`r`n" + $Fence + "`r`n")
                Write-Utf8 (Join-Path $BG 'phan-hoi.md') $fb
                Move-NextRound 'test rot'
            }
        }
        'reviewer' {
            $diffFile = Join-Path $BG 'diff.patch'
            & git diff ('--output=' + $diffFile) $script:st.base HEAD -- . ':(exclude).bangiao' 2>$null
            $stat = ((& git diff --stat $script:st.base HEAD -- . ':(exclude).bangiao' 2>$null) | Out-String).Trim()
            if (-not $stat) { $stat = '(khong co thay doi code nao)' }
            $task = 'nhiem-vu/reviewer-v' + $v + '.md'
            Write-Utf8 (Join-Path $BG $task) (New-TaskText 'reviewer' $v $stat)
            $r = Invoke-Step 'reviewer' ('.bangiao/' + $task) $v
            Write-Utf8 (Join-Path $BG 'danh-gia.md') $r.Text
            Protect-ReadOnly 'reviewer'
            $pq = Get-Marker $r.Text 'PHAN_QUYET' @('CHOT', 'CAN_SUA', 'CHAN')
            Write-Log ('vong ' + $v + ' | phan quyet: ' + $pq)
            Save-Snapshot ('ship v' + $v + ': review (' + $Engines.reviewer + ') ' + $pq)
            if ($pq -eq 'CHOT') {
                $script:st.buoc = 'xong'
            } elseif ($pq -eq 'CAN_SUA') {
                Say '    => Reviewer yeu cau SUA, gui phan hoi ve Coder.' 'Yellow'
                Write-Utf8 (Join-Path $BG 'phan-hoi.md') ('# PHAN HOI TU REVIEWER (vong ' + $v + ")`r`n`r`n" + $r.Text)
                Move-NextRound 'reviewer yeu cau sua'
            } elseif ($pq -eq 'CHAN') {
                Say ''
                Say 'Reviewer CHAN: co van de goc (thuong nam o ke hoach). Can ban quyet dinh.' 'Red'
                Say '    Doc:  .bangiao\danh-gia.md' 'White'
                Say '    Muon Coder thu sua theo danh gia:  .\ship.ps1 -TiepTuc' 'White'
                Say '    Hoac bo nhanh nay va lam lai voi yeu cau ro hon.' 'White'
                Write-Utf8 (Join-Path $BG 'phan-hoi.md') ('# PHAN HOI TU REVIEWER (vong ' + $v + ") - CHAN`r`n`r`n" + $r.Text)
                Move-NextRound 'reviewer chan'
                Stop-Run 4 ('vong ' + $v + ' - Reviewer CHAN')
            } else {
                Say '    Reviewer khong ghi dong PHAN_QUYET dung dinh dang. Xem .bangiao\danh-gia.md' 'Red'
                Say '    Chay lai buoc review:  .\ship.ps1 -TiepTuc' 'White'
                Stop-Run 7 ('vong ' + $v + ' - Reviewer sai dinh dang')
            }
        }
        'xong' {
            Write-Log ('XONG | Reviewer CHOT o vong ' + $v)
            Save-State
            Save-Snapshot 'ship: xong - Reviewer CHOT'
            Show-Summary
            Say (' Thoi gian lan chay nay: ' + (Format-Secs $watch.Elapsed.TotalSeconds)) 'DarkGray'
            exit 0
        }
        default {
            Say ('Trang thai la trong ' + $StateFile + ': ' + $script:st.buoc) 'Red'
            exit 1
        }
    }
    Save-State
}
