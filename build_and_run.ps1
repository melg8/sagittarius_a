<#
================================================================================
 build_and_run.ps1 — EVEmu: пересборка + перезапуск сервера (Windows)
================================================================================
 НАЗНАЧЕНИЕ
   Быстрая пересборка eve-server из исходников и перезапуск: остановка
   работающего сервера, cmake build (Release, x64), cmake install в deploy\,
   запуск MariaDB (если не запущена), запуск eve-server и открытие ОТДЕЛЬНОЙ
   консоли с живым логом сервера. Полное развёртывание (VS Build Tools, CMake,
   MariaDB, схема БД, deploy\) должно быть уже выполнено deploy_windows.ps1.

 ЗАПУСК
   powershell -NoProfile -ExecutionPolicy Bypass -File .\build_and_run.ps1
   или двойной клик по build_and_run.bat (рядом со скриптом).

 ПАРАМЕТРЫ
   -Configure     принудительный cmake configure перед сборкой (после смены
                  ветки или файлов cmake\; обычно не нужен — cmake сам
                  перегенерирует проект при изменениях CMakeLists)
   -Clean         удалить .winbuild\build и пересобрать с нуля (включает
                  -Configure; сборка займёт 10-40 минут)
   -NoConsole     не открывать отдельное окно с логом сервера
   -NoStopWait    не ждать Ctrl+C в конце: собрать, запустить сервер и выйти,
                  НЕ останавливая сервер и БД (для автоматизации)

 УПРАВЛЕНИЕ ПОСЛЕ ЗАПУСКА СЕРВЕРА
   Ctrl+C в окне скрипта — аккуратно остановить eve-server и MariaDB
   (graceful shutdown БД) и закрыть окно. Крестик — сервер и БД продолжат
   работать. Живой лог сервера — в отдельной консоли "EVEmu server log".

 ЛОГИ
   .winbuild\logs\build_and_run.log      — журнал этого скрипта (все запуски)
   .winbuild\logs\build_out.log          — полный вывод компиляции
   .winbuild\logs\eve-server_out.log     — stdout/stderr сервера
   deploy\logs\*.log                     — собственные логи eve-server
================================================================================
#>

#requires -Version 5.1
[CmdletBinding()]
param(
    [switch]$Configure,
    [switch]$Clean,
    [switch]$NoConsole,
    [switch]$NoStopWait
)

#===============================================================================
# 0. ПУТИ И ГЛОБАЛЬНЫЕ УСТАНОВКИ
#===============================================================================
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }

$Script:RepoRoot         = (Get-Item -LiteralPath $PSScriptRoot).FullName
$Script:WinBuild         = Join-Path $Script:RepoRoot '.winbuild'
$Script:LogDir           = Join-Path $Script:WinBuild 'logs'
$Script:DownloadDir      = Join-Path $Script:WinBuild 'downloads'
$Script:ToolsDir         = Join-Path $Script:WinBuild 'tools'
$Script:BuildDir         = Join-Path $Script:WinBuild 'build'
$Script:MariaDir         = Join-Path $Script:ToolsDir 'mariadb'
$Script:DeployDir        = Join-Path $Script:RepoRoot 'deploy'
$Script:BarLog           = Join-Path $Script:LogDir 'build_and_run.log'
$Script:LogConsoleMarker = Join-Path $Script:LogDir 'log_console.pid'
$Script:RunStamp         = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$Script:VsGenerator      = 'Visual Studio 17 2022'

$Script:Cfg = @{
    MariaTopDir   = 'mariadb-11.4.5-winx64'
    MariaZipName  = 'mariadb-11.4.5-winx64.zip'
    MariaMd5      = '233dacfa80d594e40e21d086b1f0ba42'   # совпадает с cmake/BuildMySQL.cmake
    MariaPortFile = 'db.port'
    DbUser        = 'evemu'; DbPass = 'evemu'
    ServerPort    = 26000; ImagePort = 26001
}

# Зависимости cmake, которые тот качает одноразовым FILE(DOWNLOAD) без ретраёв
# (cmake\BuildPackage.cmake) — источник сбоев configure при нестабильной сети.
# Пре-загружаем их надёжным даунлоадером прямо в каталог сборки. Имена и MD5 —
# из cmake\Build{Boost,TinyXML,UTF8CPP,ZLIB}.cmake.
$Script:CmakeDeps = @(
    @{ Name = 'boost_1_67_0.tar.bz2'; Url = 'https://archives.boost.io/release/1.67.0/source/boost_1_67_0.tar.bz2';          Md5 = 'ced776cb19428ab8488774e1415535ab' },
    @{ Name = 'tinyxml_2_6_2.tar.gz'; Url = 'http://downloads.sourceforge.net/project/tinyxml/tinyxml/2.6.2/tinyxml_2_6_2.tar.gz'; Md5 = 'c1b864c96804a10526540c664ade67f0' },
    @{ Name = 'zlib-1.2.7.tar.gz';    Url = 'https://zlib.net/fossils/zlib-1.2.7.tar.gz';                                       Md5 = '60df6a37c56e7c1366cca812414f7b85' },
    @{ Name = 'v2.3.4';               Url = 'https://codeload.github.com/nemtrif/utfcpp/zip/refs/tags/v2.3.4';                  Md5 = '29959274827576ebecc504701928e865' }
)

#===============================================================================
# 1. ЛОГИРОВАНИЕ
#===============================================================================
function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO','WARN','ERROR','OK','STEP','DATA')][string]$Level = 'INFO'
    )
    $line = "{0} [{1,-5}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    try { Add-Content -LiteralPath $Script:BarLog -Value $line -Encoding UTF8 } catch { }
    $color = switch ($Level) {
        'ERROR' { 'Red' } ; 'WARN' { 'Yellow' } ; 'OK' { 'Green' }
        'STEP'  { 'Cyan' } ; 'DATA' { 'DarkGray' } ; default { 'Gray' }
    }
    Write-Host $line -ForegroundColor $color
}

function Write-Step {
    param([Parameter(Mandatory)][string]$Name)
    $banner = ("{0}`nЭТАП: {1}`n{0}" -f ('-' * 78), $Name)
    Write-Log $banner 'STEP'
}

function Exit-WithCode {
    param([int]$Code, [string]$Message = '')
    if ($Message) { Write-Log $Message 'ERROR' }
    Write-Host ''
    Write-Host ('!' * 78) -ForegroundColor Red
    Write-Host "  СБОЙ (код $Code). Журнал: $Script:BarLog" -ForegroundColor Red
    Write-Host ('!' * 78) -ForegroundColor Red
    if (-not $NoStopWait) {
        try { Read-Host 'Нажмите Enter, чтобы закрыть это окно' | Out-Null } catch { Start-Sleep -Seconds 15 }
    }
    exit $Code
}

#===============================================================================
# 2. БАЗОВЫЕ УТИЛИТЫ
#===============================================================================
function Test-TcpPort {
    param([int]$Port, [string]$HostName = '127.0.0.1', [int]$TimeoutMs = 1500)
    $client = New-Object Net.Sockets.TcpClient
    try {
        $iar = $client.BeginConnect($HostName, $Port, $null, $null)
        if ($iar.AsyncWaitHandle.WaitOne($TimeoutMs) -and $client.Connected) { return $true }
        return $false
    } catch { return $false }
    finally { try { $client.Close() } catch { } }
}

function Get-OurProcess {
    # Процессы, запущенные ИЗ папки проекта (чужие не трогаем никогда)
    param([string]$NamePattern = '%')
    $root = $Script:RepoRoot.TrimEnd('\') + '\'
    Get-CimInstance Win32_Process -Filter "Name LIKE '$NamePattern'" -ErrorAction SilentlyContinue |
        Where-Object { $_.ExecutablePath -and $_.ExecutablePath.StartsWith($root, [StringComparison]::OrdinalIgnoreCase) }
}

function ConvertTo-ArgumentString {
    param([string[]]$Arguments)
    $sb = New-Object System.Text.StringBuilder
    foreach ($a in $Arguments) {
        if ($sb.Length -gt 0) { [void]$sb.Append(' ') }
        if ($a -match '[\s"]') {
            $esc = $a -replace '(\\+)$', '$1$1'
            $esc = $esc -replace '"', '\"'
            [void]$sb.Append('"' + $esc + '"')
        } else {
            [void]$sb.Append($a)
        }
    }
    $sb.ToString()
}

function Get-Tail {
    param([string]$Path, [int]$Lines = 100)
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return "(файл не найден: $Path)" }
    $c = @(Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue)
    if ($c.Count -eq 0) { return "(пусто: $Path)" }
    if ($c.Count -le $Lines) { return ($c -join "`n") }
    return (($c | Select-Object -Last $Lines) -join "`n")
}

function Invoke-LongCommand {
    # Запуск внешней команды с записью stdout/stderr в файлы и "живым" хвостом
    # вывода в консоль и журнал (сборка занимает 10-40 минут — прогресс виден).
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string[]]$Arguments = @(),
        [string]$WorkingDirectory = $null,
        [string]$LogTag = 'longcmd',
        [int]$TimeoutSec = 0
    )
    $outLog = Join-Path $Script:LogDir ("{0}_out.log" -f $LogTag)
    $errLog = Join-Path $Script:LogDir ("{0}_err.log" -f $LogTag)
    foreach ($f in @($outLog, $errLog)) {
        if (Test-Path -LiteralPath $f) { Move-Item -LiteralPath $f -Destination "$f.prev" -Force -ErrorAction SilentlyContinue }
    }
    $argStr = ConvertTo-ArgumentString $Arguments
    Write-Log "ВЫПОЛНЕНИЕ: $FilePath $argStr" 'DATA'

    $p = Start-Process -FilePath $FilePath -ArgumentList $argStr -PassThru -WindowStyle Hidden `
            -RedirectStandardOutput $outLog -RedirectStandardError $errLog `
            -WorkingDirectory $(if ($WorkingDirectory) { $WorkingDirectory } else { $Script:RepoRoot })
    # ФИКС (баг PS 5.1): удерживаем дескриптор процесса, иначе .ExitCode = $null
    try { $null = $p.Handle } catch { }

    $offset = 0
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while (-not $p.HasExited) {
        Start-Sleep -Seconds 3
        try {
            if (Test-Path -LiteralPath $outLog) {
                $fs = [IO.File]::Open($outLog, 'Open', 'Read', 'ReadWrite')
                if ($fs.Length -gt $offset) {
                    $fs.Seek($offset, 'Begin') | Out-Null
                    $reader = New-Object IO.StreamReader($fs, [Text.Encoding]::UTF8)
                    $chunk = $reader.ReadToEnd()
                    $offset = $fs.Length
                    $reader.Close()
                    foreach ($line in ($chunk -split "`r?`n")) {
                        if ($line.Trim()) {
                            Write-Host "    $line" -ForegroundColor DarkGray
                            Add-Content -LiteralPath $Script:BarLog -Value "    $line" -Encoding UTF8
                        }
                    }
                } else { $fs.Close() }
            }
        } catch { }
        if ($TimeoutSec -gt 0 -and $sw.Elapsed.TotalSeconds -gt $TimeoutSec) {
            try { $p.Kill() } catch { }
            Write-Log "Таймаут ${TimeoutSec}s — процесс остановлен" 'WARN'
            break
        }
    }
    $p.WaitForExit()
    $code = $null
    try { $code = $p.ExitCode } catch { }
    if ($null -eq $code) { $code = -1 }
    Write-Log "Команда завершена, код возврата: $code. Полный журнал: $outLog" $(if ($code -eq 0) { 'OK' } else { 'ERROR' })
    return [pscustomobject]@{ Code = $code; OutLog = $outLog; ErrLog = $errLog }
}

#===============================================================================
# 3. CMAKE И VISUAL STUDIO (для -Configure / -Clean / первого запуска)
#===============================================================================
function Get-CmakeVersion {
    param([string]$CmakeExe)
    if (-not $CmakeExe -or -not (Test-Path -LiteralPath $CmakeExe)) { return $null }
    try {
        $out = @(& $CmakeExe --version 2>$null)
        if ("$out" -match 'cmake version (\d+)\.(\d+)(\.(\d+))?') {
            return [version]("{0}.{1}.{2}" -f $Matches[1], $Matches[2], $(if ($Matches[3]) { $Matches[4] } else { '0' }))
        }
    } catch { }
    return $null
}

function Test-CmakeSuitable {
    param([version]$V)
    # Проект несовместим с CMake 4.x (минимум 3.21 — для генератора VS 2022)
    return ($V -ge [version]'3.21' -and $V.Major -le 3)
}

function Resolve-CMake {
    # Порядок: системный PATH -> CMake из VS Build Tools -> портативный .winbuild
    $candidates = @()
    $sys = Get-Command cmake.exe -ErrorAction SilentlyContinue
    if ($sys) { $candidates += $sys.Source }

    # VS через vswhere (Build Tools тоже «продукт», нужен '-products *')
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path -LiteralPath $vswhere) {
        $r = & $vswhere -all -prerelease -products '*' `
                -requires Microsoft.VisualStudio.Workload.VCTools `
                -property installationPath 2>$null
        foreach ($vsPath in @($r)) {
            if (-not $vsPath -or $vsPath -notmatch '^[A-Za-z]:\\') { continue }
            if ($vsPath -notmatch '\\(2019|2022)\\') { continue }
            $cm = Join-Path $vsPath 'Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe'
            if (Test-Path -LiteralPath $cm) {
                $candidates += $cm
                $Script:VsGenerator = if ($vsPath -match '\\2022\\') { 'Visual Studio 17 2022' } else { 'Visual Studio 16 2019' }
            }
        }
    }

    $portable = Join-Path $Script:ToolsDir 'cmake-3.31.6-windows-x86_64\bin\cmake.exe'
    if (Test-Path -LiteralPath $portable) { $candidates += $portable }

    foreach ($c in $candidates) {
        $v = Get-CmakeVersion $c
        if ($v -and (Test-CmakeSuitable $v)) {
            Write-Log "Использую CMake ${v}: $c" 'OK'
            return $c
        }
        Write-Log "CMake $v по пути $c не подходит (нужен >= 3.21 и < 4.0)" 'WARN'
    }
    return $null
}

function Initialize-CmakeDepArchives {
    # Пре-загрузка архивов зависимостей в каталог сборки (см. $Script:CmakeDeps).
    # Неудача НЕ фатальна: cmake попробует скачать сам (без ретраёв).
    try {
        if (-not (Test-Path -LiteralPath $Script:BuildDir)) {
            New-Item -ItemType Directory -Path $Script:BuildDir -Force | Out-Null
        }
        foreach ($d in $Script:CmakeDeps) {
            $dst = Join-Path $Script:BuildDir $d.Name
            if (-not (Get-WebFile -Url $d.Url -OutFile $dst -ExpectedMd5 $d.Md5)) {
                Write-Log "Пре-загрузка зависимости $($d.Name) не удалась — cmake попробует скачать сам" 'WARN'
            }
        }
    } catch {
        Write-Log "Пре-загрузка зависимостей прервана: $($_.Exception.Message)" 'WARN'
    }
}

function Get-WebFile {
    # Скачивание с ретраями и кэшем по MD5 (аналог deploy_windows.ps1).
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$OutFile,
        [string]$ExpectedMd5 = $null,
        [int]$Attempts = 3
    )
    $dir = Split-Path -Parent $OutFile
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    if ($ExpectedMd5) {
        $have = $null
        if (Test-Path -LiteralPath $OutFile) {
            try { $have = (Get-FileHash -LiteralPath $OutFile -Algorithm MD5).Hash.ToLower() } catch { }
        }
        if ($have -eq $ExpectedMd5) { return $true }
        if ($have) { Remove-Item -LiteralPath $OutFile -Force -ErrorAction SilentlyContinue }
    } elseif (Test-Path -LiteralPath $OutFile) {
        return $true
    }

    for ($i = 1; $i -le $Attempts; $i++) {
        $part = "$OutFile.part"
        try {
            Write-Log "Скачивание (попытка $i/$Attempts): $Url" 'INFO'
            Invoke-WebRequest -Uri $Url -OutFile $part -UserAgent 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) EVEmuBuildRun/1.0' `
                -TimeoutSec 900 -UseBasicParsing -ErrorAction Stop
            if (-not (Test-Path -LiteralPath $part) -or (Get-Item -LiteralPath $part).Length -eq 0) { throw "файл пустой" }
            Move-Item -LiteralPath $part -Destination $OutFile -Force
            if ($ExpectedMd5) {
                $md5 = (Get-FileHash -LiteralPath $OutFile -Algorithm MD5).Hash.ToLower()
                if ($md5 -ne $ExpectedMd5) {
                    Write-Log "MD5 НЕ СОВПАЛ: $md5 != $ExpectedMd5" 'WARN'
                    Remove-Item -LiteralPath $OutFile -Force -ErrorAction SilentlyContinue
                    throw "контрольная сумма не совпала"
                }
            }
            Write-Log "Скачано: $OutFile" 'OK'
            return $true
        } catch {
            Write-Log "Ошибка скачивания (попытка $i/$Attempts): $($_.Exception.Message)" 'WARN'
            Remove-Item -LiteralPath $part -Force -ErrorAction SilentlyContinue
            if ($i -eq $Attempts) { return $false }
            Start-Sleep -Seconds (5 * $i)
        }
    }
    return $false
}

#===============================================================================
# 4. ОСТАНОВКА/ЗАПУСК СЕРВЕРА И БАЗЫ
#===============================================================================
function Stop-EveServer {
    # Останавливает eve-server, запущенный из папки проекта (чужие не трогаем).
    $ours = @(Get-OurProcess -NamePattern 'eve-server.exe')
    if ($ours.Count -eq 0) { Write-Log 'eve-server не запущен' 'INFO'; return $true }
    Write-Log "Найден работающий eve-server (PID: $($ours.ProcessId -join ',')) — останавливаю: файлы deploy\bin заняты" 'WARN'
    foreach ($pr in $ours) {
        try { Stop-Process -Id $pr.ProcessId -Force -ErrorAction Stop } catch { }
    }
    for ($i = 0; $i -lt 15; $i++) {
        if (@(Get-OurProcess -NamePattern 'eve-server.exe').Count -eq 0) {
            Start-Sleep -Seconds 1
            return $true
        }
        Start-Sleep -Seconds 1
    }
    Write-Log "eve-server не завершился за 15 секунд — закройте его вручную и повторите" 'ERROR'
    return $false
}

function Stop-MariaDb {
    # Graceful shutdown НАШЕЙ портативной MariaDB (буферы InnoDB сбрасываются),
    # при зависании — принудительно. Чужие mysqld не трогаются.
    $ours = @(Get-OurProcess -NamePattern 'mysqld.exe' | Where-Object { $_.ExecutablePath -like "$Script:MariaDir*" })
    if ($ours.Count -eq 0) { Write-Log 'MariaDB: процессов из папки проекта нет — останавливать нечего' 'INFO'; return $true }
    $portFile = Join-Path $Script:WinBuild $Script:Cfg.MariaPortFile
    $port = 0
    if (Test-Path -LiteralPath $portFile) {
        $sv = ("$(Get-Content -LiteralPath $portFile -Raw -ErrorAction SilentlyContinue)").Trim()
        if ($sv -match '^\d+$') { $port = [int]$sv }
    }
    $admin = Join-Path $Script:MariaDir "$($Script:Cfg.MariaTopDir)\bin\mariadb-admin.exe"
    if ((Test-Path -LiteralPath $admin) -and $port -gt 0) {
        Write-Log "MariaDB: graceful shutdown через mariadb-admin (порт $port)..." 'INFO'
        $null = Invoke-LongCommand -FilePath $admin `
            -Arguments @('-h','127.0.0.1','-P',"$port",'-u','root','shutdown') -LogTag 'db_shutdown' -TimeoutSec 60
    }
    for ($i = 0; $i -lt 30; $i++) {
        if (@(Get-OurProcess -NamePattern 'mysqld.exe' | Where-Object { $_.ExecutablePath -like "$Script:MariaDir*" }).Count -eq 0) {
            Write-Log 'MariaDB остановлена' 'OK'
            return $true
        }
        Start-Sleep -Seconds 1
    }
    Write-Log 'MariaDB не завершилась за 30 секунд — останавливаю принудительно' 'WARN'
    foreach ($p in $ours) { try { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue } catch { } }
    Start-Sleep -Seconds 2
    return $true
}

function Resolve-DbPort {
    # Порт БД из .winbuild\db.port (записывается deploy_windows.ps1), иначе 3306
    $portFile = Join-Path $Script:WinBuild $Script:Cfg.MariaPortFile
    if (Test-Path -LiteralPath $portFile) {
        $sv = ("$(Get-Content -LiteralPath $portFile -Raw -ErrorAction SilentlyContinue)").Trim()
        if ($sv -match '^\d+$') { return [int]$sv }
    }
    return 3306
}

function Start-MariaDb {
    param([Parameter(Mandatory)][int]$Port)
    $mysqld = Join-Path $Script:MariaDir "$($Script:Cfg.MariaTopDir)\bin\mysqld.exe"
    $ini    = Join-Path $Script:WinBuild 'my.ini'
    if (-not (Test-Path -LiteralPath $mysqld) -or -not (Test-Path -LiteralPath $ini)) {
        Write-Log "MariaDB не найдена ($mysqld) — сначала выполните полное развёртывание (deploy_windows.bat)" 'ERROR'
        return $false
    }
    # Уже запущена и отвечает?
    $ours = @(Get-OurProcess -NamePattern 'mysqld.exe' | Where-Object { $_.ExecutablePath -like "$Script:MariaDir*" })
    if ($ours.Count -gt 0) {
        if (Test-TcpPort -Port $Port) {
            Write-Log "MariaDB уже запущена (PID $($ours[0].ProcessId)), порт $Port отвечает" 'OK'
            return $true
        }
        Write-Log "Наш mysqld завис (порт $Port не отвечает) — перезапускаю" 'WARN'
        foreach ($p in $ours) { try { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue } catch { } }
        Start-Sleep -Seconds 2
    } elseif (Test-TcpPort -Port $Port) {
        Write-Log "Порт $Port занят СТОРОННИМ MySQL/MariaDB — она и будет использована (запускать свою не нужно)" 'WARN'
        return $true
    }

    Write-Log "Запускаю mysqld (порт $Port)..." 'INFO'
    try {
        $proc = Start-Process -FilePath $mysqld -ArgumentList ('"--defaults-file=' + $ini + '"') `
                 -WindowStyle Hidden -PassThru
        try { $null = $proc.Handle } catch { }
    } catch {
        Write-Log "Не удалось запустить mysqld: $($_.Exception.Message)" 'ERROR'
        return $false
    }
    for ($i = 1; $i -le 60; $i++) {
        if (Test-TcpPort -Port $Port) {
            Write-Log "MariaDB запущена и отвечает на порту $Port" 'OK'
            return $true
        }
        if ($proc.HasExited) {
            Write-Log "mysqld завершился с кодом $($proc.ExitCode). Журнал: $Script:LogDir\mysqld.err" 'ERROR'
            Write-Log (Get-Tail (Join-Path $Script:LogDir 'mysqld.err') 30) 'DATA'
            return $false
        }
        Start-Sleep -Seconds 2
    }
    Write-Log "MariaDB не поднялась за 120 секунд. Журнал: $Script:LogDir\mysqld.err" 'ERROR'
    return $false
}

function Start-EveServer {
    param([Parameter(Mandatory)][int]$Port)
    $binDir = Join-Path $Script:DeployDir 'bin'
    $exe    = Join-Path $binDir 'eve-server.exe'
    if (-not (Test-Path -LiteralPath $exe)) {
        Write-Log "Не найден $exe — сначала выполните полное развёртывание (deploy_windows.bat)" 'ERROR'
        return $false
    }
    if (Test-TcpPort -Port $Port) {
        Write-Log "Порт $Port уже занят — сервер не запускаю (остановите занявший процесс)" 'ERROR'
        return $false
    }

    $outLog = Join-Path $Script:LogDir 'eve-server_out.log'
    $errLog = Join-Path $Script:LogDir 'eve-server_err.log'
    foreach ($f in @($outLog, $errLog)) {
        if (Test-Path -LiteralPath $f) { Move-Item -LiteralPath $f -Destination "$f.prev" -Force -ErrorAction SilentlyContinue }
    }
    # stdin сервера — пустой файл: полностью отвязываем его от консоли этого
    # окна (иначе консольные команды сервера ловят наши нажатия, а после
    # закрытия окна поток чтения ввода уходит в бесконечный EOF-цикл)
    $nullStdin = Join-Path $Script:LogDir 'stdin.null'
    if (-not (Test-Path -LiteralPath $nullStdin)) { New-Item -ItemType File -Path $nullStdin -Force | Out-Null }

    Write-Log "Запускаю eve-server..." 'INFO'
    try {
        $proc = Start-Process -FilePath $exe -WorkingDirectory $binDir -WindowStyle Hidden `
                 -RedirectStandardInput $nullStdin `
                 -RedirectStandardOutput $outLog -RedirectStandardError $errLog -PassThru
        try { $null = $proc.Handle } catch { }
        Write-Log "eve-server запущен, PID $($proc.Id)" 'DATA'
    } catch {
        Write-Log "Не удалось запустить eve-server: $($_.Exception.Message)" 'ERROR'
        return $false
    }

    Write-Log "Ожидаю привязку порта $Port (до 300 секунд)..." 'INFO'
    $up = $false
    for ($i = 1; $i -le 100; $i++) {
        if (Test-TcpPort -Port $Port) { $up = $true; break }
        if ($proc.HasExited) {
            Write-Log "eve-server аварийно завершился с кодом $($proc.ExitCode)" 'ERROR'
            Write-Log (Get-Tail $outLog 40) 'DATA'
            return $false
        }
        Start-Sleep -Seconds 3
    }
    if (-not $up) {
        Write-Log "Сервер не поднялся на порту $Port. Последние строки:" 'ERROR'
        Write-Log (Get-Tail $outLog 40) 'DATA'
        return $false
    }
    Write-Log "Порт $Port ПРИСЛУШИВАЕТСЯ" 'OK'
    if (Test-TcpPort -Port $Script:Cfg.ImagePort) {
        Write-Log "Image-сервер на порту $($Script:Cfg.ImagePort) тоже работает" 'OK'
    }
    return $true
}

#===============================================================================
# 5. ОТДЕЛЬНАЯ КОНСОЛЬ ЛОГА СЕРВЕРА
#===============================================================================
function Close-LogConsole {
    # Закрывает окно с логом сервера (по маркеру PID|StartTime — без риска
    # убить чужой процесс с переиспользованным PID).
    try {
        if (-not (Test-Path -LiteralPath $Script:LogConsoleMarker)) { return }
        $m = (Get-Content -LiteralPath $Script:LogConsoleMarker -Raw -ErrorAction SilentlyContinue)
        if ($m -match '^(\d+)\|(.+?)\s*$') {
            $pp = Get-Process -Id ([int]$Matches[1]) -ErrorAction SilentlyContinue
            if ($pp -and $pp.ProcessName -eq 'powershell' -and $pp.StartTime.ToString('o') -eq $Matches[2]) {
                try { Stop-Process -Id $pp.Id -Force -ErrorAction SilentlyContinue } catch { }
                Write-Log 'Консоль лога сервера закрыта' 'INFO'
            }
        }
        Remove-Item -LiteralPath $Script:LogConsoleMarker -Force -ErrorAction SilentlyContinue
    } catch { }
}

function Start-LogConsole {
    # Открывает отдельное окно PowerShell с живым хвостом лога сервера.
    param([Parameter(Mandatory)][string]$Title, [Parameter(Mandatory)][string]$LogFile)
    try {
        if (-not (Test-Path -LiteralPath $LogFile)) { New-Item -ItemType File -Path $LogFile -Force | Out-Null }
        Close-LogConsole
        $tail = @"
`$Host.UI.RawUI.WindowTitle = '$Title'
Clear-Host
Write-Host ('=' * 70)
Write-Host '  $Title — живой лог сервера'
Write-Host '  Файл: $LogFile'
Write-Host '  Окно можно закрыть в любой момент — на сервер это не влияет.'
Write-Host ('=' * 70)
Write-Host ''
Get-Content -LiteralPath '$LogFile' -Wait -Tail 200
"@
        $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($tail))
        $p = Start-Process -FilePath 'powershell.exe' `
                -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-NoExit','-EncodedCommand', $enc) -PassThru
        Set-Content -LiteralPath $Script:LogConsoleMarker -Value ("{0}|{1}" -f $p.Id, $p.StartTime.ToString('o')) -Encoding ASCII
        Write-Log "Открыта отдельная консоль с логом сервера (PID $($p.Id)): $LogFile" 'OK'
        return $p.Id
    } catch {
        Write-Log "Не удалось открыть отдельную консоль лога: $($_.Exception.Message)" 'WARN'
        return $null
    }
}

function Invoke-DeployCleanup {
    # Остановка запущенного: окно лога, eve-server, MariaDB (Ctrl+C в конце).
    param([int]$DbPort = 0)
    Write-Host ''
    Write-Log 'Ctrl+C: останавливаю консоль лога, eve-server и MariaDB...' 'INFO'
    Close-LogConsole
    if (-not (Stop-EveServer)) {
        Write-Log 'eve-server не удалось остановить штатно — проверьте процессы вручную (Get-Process eve-server)' 'WARN'
    }
    Stop-MariaDb | Out-Null
    Write-Log 'Остановка завершена' 'OK'
}

function Wait-Running {
    # Сервер и БД работают; окно ждёт Ctrl+C, в finally — остановка сервисов.
    param([int]$Port)
    Write-Host ''
    Write-Host ('=' * 78) -ForegroundColor Green
    Write-Host '  Сервер и БД РАБОТАЮТ (это окно можно свернуть).' -ForegroundColor Green
    Write-Host '  Живой лог сервера — в отдельной консоли "EVEmu server log".' -ForegroundColor Green
    Write-Host '  Ctrl+C  — остановить eve-server и MariaDB и закрыть это окно.' -ForegroundColor Yellow
    Write-Host '  Крестик — сервер и БД ОСТАНУТСЯ работать (закроется только это окно).' -ForegroundColor Yellow
    Write-Host ('=' * 78) -ForegroundColor Green
    try {
        while ($true) { Start-Sleep -Seconds 3600 }
    } finally {
        Invoke-DeployCleanup -DbPort $Port
    }
}

#===============================================================================
# 6. ГЛАВНЫЙ ПОТОК
#===============================================================================
function Main {
    if (-not (Test-Path -LiteralPath $Script:LogDir)) { New-Item -ItemType Directory -Path $Script:LogDir -Force | Out-Null }
    $sep = '=' * 78
    Write-Log (($sep, "ЗАПУСК build_and_run.ps1 — $Script:RunStamp", "Репозиторий: $Script:RepoRoot", $sep) -join [Environment]::NewLine) 'STEP'

    # --- 1. Предусловия: развёртывание уже выполнено? ---
    $ini = Join-Path $Script:WinBuild 'my.ini'
    if (-not (Test-Path -LiteralPath $ini)) {
        Exit-WithCode 2 "Развёртывание не найдено ($ini отсутствует). Сначала выполните ПОЛНОЕ развёртывание: deploy_windows.bat"
    }

    # --- 2. Останавливаем сервер: exe/DLL в deploy\bin заняты процессом ---
    if (-not (Stop-EveServer)) {
        Exit-WithCode 3 "Не удалось остановить работающий eve-server — обновление deploy\bin невозможно."
    }

    # --- 3. CMake ---
    $cmakeExe = Resolve-CMake
    if (-not $cmakeExe) {
        Exit-WithCode 4 "CMake не найден (PATH / VS Build Tools / .winbuild\tools). Выполните полное развёртывание: deploy_windows.bat"
    }

    # --- 4. Configure (только при необходимости/по флагам) ---
    $needConfigure = $Configure -or $Clean -or -not (Test-Path -LiteralPath (Join-Path $Script:BuildDir 'CMakeCache.txt'))
    if ($Clean -and (Test-Path -LiteralPath $Script:BuildDir)) {
        Write-Log "Удаляю каталог сборки (-Clean): $Script:BuildDir" 'WARN'
        Remove-Item -LiteralPath $Script:BuildDir -Recurse -Force
    }
    if ($needConfigure) {
        Write-Step 'Configure (CMake)'
        Initialize-CmakeDepArchives
        $mzip = Join-Path $Script:DownloadDir $Script:Cfg.MariaZipName
        $mysqlUrl = $null
        if (Test-Path -LiteralPath $mzip) {
            try { if ((Get-FileHash -LiteralPath $mzip -Algorithm MD5).Hash.ToLower() -eq $Script:Cfg.MariaMd5) {
                $fwd = ([IO.Path]::GetFullPath($mzip)).Replace('\','/')
                $mysqlUrl = "file:///$([Uri]::EscapeUriString($fwd))"
            } } catch { }
        }
        $cmArgs = @('-S', $Script:RepoRoot, '-B', $Script:BuildDir,
                    '-G', $Script:VsGenerator, '-A', 'x64',
                    "-DCMAKE_INSTALL_PREFIX=$Script:DeployDir")
        if ($mysqlUrl) { $cmArgs += @("-DMYSQL_URL=$mysqlUrl") }
        $r = Invoke-LongCommand -FilePath $cmakeExe -Arguments $cmArgs -LogTag 'cmake_configure' -TimeoutSec 3600
        $cfgTry = 1
        while ($r.Code -ne 0 -and $cfgTry -lt 3) {
            $cfgTry++
            if ($cfgTry -ge 3) { $cmArgs = @($cmArgs | Where-Object { $_ -notmatch 'MYSQL_URL' }) }
            Write-Log "Configure не удался (код $($r.Code)) — попытка $cfgTry/3" 'WARN'
            $r = Invoke-LongCommand -FilePath $cmakeExe -Arguments $cmArgs -LogTag 'cmake_configure' -TimeoutSec 3600
        }
        if ($r.Code -ne 0) {
            Write-Log (Get-Tail (Join-Path $Script:LogDir 'cmake_configure_out.log') 60) 'DATA'
            Exit-WithCode 70 "cmake configure вернул код $($r.Code). Полный лог: cmake_configure_out.log"
        }
    } else {
        Write-Log "Configure пропущен (каталог сборки готов; -Configure/-Clean — принудительно)" 'INFO'
    }

    # --- 5. Сборка ---
    Write-Step 'Сборка (Release, x64)'
    $r = Invoke-LongCommand -FilePath $cmakeExe `
        -Arguments @('--build', $Script:BuildDir, '--config', 'Release',
                     '--', '/m', '/v:m', '/nodeReuse:false') `
        -LogTag 'build' -TimeoutSec 0
    if ($r.Code -ne 0) {
        Write-Log (Get-Tail (Join-Path $Script:LogDir 'build_out.log') 60) 'DATA'
        Exit-WithCode 71 "Сборка не удалась (код $($r.Code)). Полный лог: build_out.log"
    }

    # --- 6. Установка в deploy\ ---
    Write-Step 'Установка в deploy\'
    $r = Invoke-LongCommand -FilePath $cmakeExe `
        -Arguments @('--install', $Script:BuildDir, '--config', 'Release') `
        -LogTag 'cmake_install' -TimeoutSec 600
    if ($r.Code -ne 0) {
        Write-Log (Get-Tail (Join-Path $Script:LogDir 'cmake_install_out.log') 40) 'DATA'
        Exit-WithCode 72 "cmake --install вернул код $($r.Code)"
    }
    $dll = Join-Path (Join-Path $Script:DeployDir 'bin') 'libmariadb.dll'
    if (-not (Test-Path -LiteralPath $dll)) {
        $dllSrc = Join-Path $Script:MariaDir "$($Script:Cfg.MariaTopDir)\lib\libmariadb.dll"
        if (Test-Path -LiteralPath $dllSrc) {
            Copy-Item -LiteralPath $dllSrc -Destination (Join-Path $Script:DeployDir 'bin') -Force
            Write-Log "libmariadb.dll скопирована в deploy\bin" 'OK'
        } else {
            Write-Log "libmariadb.dll не найдена ни в deploy\bin, ни в MariaDB — сервер может не запуститься" 'WARN'
        }
    }

    # --- 7. Конфиги сервера (если отсутствуют) ---
    $etcDir = Join-Path $Script:DeployDir 'etc'
    if (-not (Test-Path -LiteralPath $etcDir)) { New-Item -ItemType Directory -Path $etcDir -Force | Out-Null }
    foreach ($f in @('log.ini', 'MarketBot.xml', 'devtools.raw')) {
        $dst = Join-Path $etcDir $f
        if (-not (Test-Path -LiteralPath $dst) -and (Test-Path -LiteralPath (Join-Path $Script:RepoRoot "utils\config\$f"))) {
            Copy-Item -LiteralPath (Join-Path $Script:RepoRoot "utils\config\$f") -Destination $dst -Force
            Write-Log "Установлен конфиг: etc\$f" 'OK'
        }
    }
    $dbPort = Resolve-DbPort
    $xmlDst = Join-Path $etcDir 'eve-server.xml'
    $needGen = $true
    if (Test-Path -LiteralPath $xmlDst) {
        $cur = Get-Content -LiteralPath $xmlDst -Raw
        if ($cur -notmatch 'database_(host|username|password|name|port)') { $needGen = $false }
    }
    if ($needGen) {
        $tpl = Get-Content -LiteralPath (Join-Path $Script:RepoRoot 'utils\config\eve-server.xml') -Raw
        $tpl = $tpl -replace 'database_host', '127.0.0.1'
        $tpl = $tpl -replace 'database_username', $Script:Cfg.DbUser
        $tpl = $tpl -replace 'database_password', $Script:Cfg.DbPass
        $tpl = $tpl -replace 'database_name', 'evemu'
        $tpl = $tpl -replace 'database_port', "$dbPort"
        Set-Content -LiteralPath $xmlDst -Value $tpl -Encoding UTF8
        Write-Log "etc\eve-server.xml сгенерирован (БД 127.0.0.1:$dbPort)" 'OK'
    }
    foreach ($d in @((Join-Path $Script:DeployDir 'logs'), (Join-Path $Script:DeployDir 'server_cache'), (Join-Path $Script:DeployDir 'image_cache'))) {
        if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    }

    # --- 8. База данных ---
    Write-Step "MariaDB (порт $dbPort)"
    if (-not (Start-MariaDb -Port $dbPort)) {
        Exit-WithCode 55 "MariaDB не запустилась. Журнал: $Script:LogDir\mysqld.err"
    }

    # --- 9. Запуск сервера ---
    Write-Step 'Запуск eve-server'
    if (-not (Start-EveServer -Port $Script:Cfg.ServerPort)) {
        Exit-WithCode 80 "Сервер не запустился или не слушает порт $($Script:Cfg.ServerPort). Смотрите eve-server_out.log и deploy\logs\."
    }

    Write-Host ''
    Write-Host ('=' * 78) -ForegroundColor Green
    Write-Host "  ПЕРЕСОБРАНО И ЗАПУЩЕНО: eve-server на порту $($Script:Cfg.ServerPort), БД на 127.0.0.1:$dbPort" -ForegroundColor Green
    Write-Host "  Исполняемый файл: $Script:DeployDir\bin\eve-server.exe" -ForegroundColor Green
    Write-Host ('=' * 78) -ForegroundColor Green

    # --- 10. Отдельная консоль лога + ожидание Ctrl+C ---
    if (-not $NoConsole) {
        Start-LogConsole -Title 'EVEmu server log' -LogFile (Join-Path $Script:LogDir 'eve-server_out.log')
    }
    if ($NoStopWait) {
        Write-Log '-NoStopWait: выхожу, сервер и БД продолжают работать' 'INFO'
        return
    }
    Wait-Running -Port $dbPort
}

#===============================================================================
# ТОЧКА ВХОДА
#===============================================================================
try {
    Main
} catch {
    $msg = "НЕПРЕДВИДЕННАЯ ОШИБКА: $($_.Exception.Message)`n$($_.ScriptStackTrace)"
    try { Write-Log $msg 'ERROR' } catch { Write-Host $msg -ForegroundColor Red }
    if (-not $NoStopWait) {
        try { Read-Host 'Нажмите Enter, чтобы закрыть это окно' | Out-Null } catch { Start-Sleep -Seconds 15 }
    }
    exit 100
}
