<#
================================================================================
 deploy_windows.ps1 — EVEmu (evemu_Crucible): сборка и развёртывание на Windows 11
================================================================================
 НАЗНАЧЕНИЕ
   Полностью автоматическая сборка и развёртывание сервера EVEmu на чистой
   Windows 11 (x64), БЕЗ Docker. Скрипт ставит инструменты, собирает проект,
   разворачивает портативную MariaDB, заливает схему БД, выполняет РАЗОВЫЙ
   сид рыночных ордеров (mktOrders, регион Derelik по умолчанию) и запускает
   сервер вплоть до рабочего состояния (порты 26000/26001).

 ЗАПУСК (от обычного пользователя, скрипт сам запросит UAC):
   powershell -NoProfile -ExecutionPolicy Bypass -File .\deploy_windows.ps1

 АВТОМАТИЧЕСКИЙ ЛОГ (важно!)
   Весь вывод КАЖДОГО запуска автоматически дописывается в файл
   deploy_install.log, который создаётся РЯДОМ СО СКРИПТОМ. Даже если окно
   PowerShell закрылось и вы не успели прочитать ошибку — весь вывод уже
   сохранён в этом файле: пришлите его для диагностики. Окно не закрывается,
   пока вы не нажмёте Enter в конце работы скрипта (или при ошибке).

 ПАРАМЕТРЫ
   -DbPort <int>    порт MariaDB (по умолчанию 0 = авто: 3306, если занят — 3307)
   -SeedRegionId <int>
                    регион, которым засеивается рынок на этапе 11 (по умолчанию
                    10000001 = Derelik, как в оригинальном seed_market.sql).
                    Пример другого региона: 10000002 (The Forge). Полный список
                    regionID — в таблице mapRegions (значения — в файле
                    sql\seed_and_clean\seed_data.sql).
   -SkipBuild       пропустить компиляцию (использовать готовый deploy\bin)
   -NoFirewall      не добавлять правило Windows Firewall для портов 26000-26001
   -NoElevate       НЕ запрашивать права администратора (часть шагов может не сработать)
   -NoPause         не ждать Enter перед закрытием окна (для автоматического запуска)

 ЧТО УСТАНАВЛИВАЕТСЯ В СИСТЕМУ (всё остальное — только внутри папки проекта!)
   1) VS Build Tools 2022 + рабочая нагрузка "C++ build tools" (MSVC + Windows SDK)
      -> C:\Program Files (x86)\Microsoft Visual Studio — единственный неизбежный
         системный компонент: официального портативного MSVC не существует.
   2) Реестр: HKLM\...\FileSystem\LongPathsEnabled=1 (стандартная настройка для
      сборки C++ проектов с длинными путями; поведение остальных программ не меняет).
   3) Правило Windows Firewall "EVEmu Server" (TCP 26000-26001, входящие).
   ВСЁ ПРОЧЕЕ — CMake (портативный), MariaDB (портативная), EVEDBTool, сборка,
   каталог данных БД, логи — живёт ТОЛЬКО в <корень проекта>\.winbuild и
   <корень проекта>\deploy и удаляется вместе с папкой проекта.

 ПЕРЕЗАПУСК
   Скрипт идемпотентен: его можно запускать повторно после ошибок, перезагрузки
   или частичной установки. Уже установленные/скачанные/собранные элементы
   обнаруживаются и пропускаются, доставляется только недостающее.
   Работающий на момент запуска eve-server автоматически останавливается
   (иначе exe/DLL в deploy\bin заняты процессом и не обновляются) и вновь
   стартует на последнем этапе.

 УПРАВЛЕНИЕ ПОСЛЕ РАЗВЁРТЫВАНИЯ (Ctrl+C)
   После успешного развёртывания окно скрипта остаётся открытым: сервер и БД
   продолжают работать, а живой вывод сервера открывается в ОТДЕЛЬНОЙ консоли
   ("EVEmu server log").
     Ctrl+C в окне скрипта   — аккуратно останавливает eve-server и MariaDB
                               (graceful shutdown БД), затем окно закрывается;
     крестик (закрыть окно)  — наоборот, оставляет сервер и БД работать;
     -NoPause                — скрипт завершается сразу, не трогая работающие
                               сервер и БД (режим автоматизации).

 БЫСТРАЯ ПЕРЕСБОРКА
   build_and_run.bat / build_and_run.ps1 — собрать изменённый код и перезапустить
   сервер БЕЗ полного цикла установки (окружение, БД и схема должны быть уже
   развёрнуты этим скриптом). Оба скрипта запускаются двойным кликом по своим
   .bat: deploy_windows.bat — полное развёртывание, build_and_run.bat — пересборка.

   СИД РЫНКА выполняется РОВНО ОДИН РАЗ и НИКОГДА не перезатирает данные:
   факт выполненного сида фиксируется МАРКЕРОМ в самой базе — таблицей
   evemu.deployMarketSeed (создаётся автоматически на этапе сида). Пока
   маркера нет, сид выполняется ДАЖЕ ЕСЛИ в mktOrders уже есть ордера —
   например, остатки от игры или ордера бота MarketBot: они НЕ удаляются,
   стартовые ордера добавляются поверх. Подсчёт ордеров в mktOrders для
   решения о пропуске НЕ используется (посторонние ордера — ещё не
   «засеянный рынок»). После успешного сида маркер записывается, и все
   последующие запуски этап пропускают — накопленные в игре данные не
   перезатираются. Сам seed_market.sql идемпотентностью не обладает
   (повторная заливка дублировала бы ордера), поэтому маркер обязателен.
   Повторный сид возможен только вручную: DELETE FROM deployMarketSeed;
   (сам скрипт ни маркер, ни mktOrders не чистит).

 ЛОГИ (при любой проблеме присылайте deploy_install.log — он РЯДОМ СО СКРИПТОМ)
   deploy_install.log                     — ПОЛНЫЙ лог установки: весь вывод всех
                                            запусков, пишется автоматически рядом со
                                            скриптом. ОТПРАВЛЯЙТЕ ЕГО ПЕРВЫМ ДЛЯ
                                            ДИАГНОСТИКИ.
   .winbuild\logs\deploy.log              — главный журнал (все шаги + ошибки)
   .winbuild\logs\transcript_*.log        — полная консольная сессия
   .winbuild\logs\cmake_configure.log     — вывод cmake configure
   .winbuild\logs\build.log               — вывод сборки (MSBuild)
   .winbuild\logs\mysqld.err              — журнал MariaDB
   .winbuild\logs\evedbtool.log           — установка схемы БД
   .winbuild\logs\eve-server_out.log      — stdout/stderr сервера
   deploy\logs\*.log                      — собственные логи eve-server

 ТРЕБОВАНИЯ: Windows 10 21H2+/11 x64, ~20 ГБ свободного места, интернет.
================================================================================
#>

#requires -Version 5.1
[CmdletBinding()]
param(
    [int]$DbPort = 0,
    [int]$SeedRegionId = 10000001,   # регион сида рынка: 10000001=Derelik (как в seed_market.sql)
    [switch]$SkipBuild,
    [switch]$NoFirewall,
    [switch]$NoElevate,
    [switch]$NoPause,   # не ждать Enter перед закрытием окна (для автоматизации)
    [switch]$Elevated   # внутренний параметр (используется после UAC-перезапуска)
)

#===============================================================================
# 0. ГЛОБАЛЬНЫЕ УСТАНОВКИ И ПУТИ
#===============================================================================
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'   # ускоряет Invoke-WebRequest в PS 5.1
try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12 } catch { }
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch { }

$Script:RepoRoot    = (Get-Item -LiteralPath $PSScriptRoot).FullName
$Script:WinBuild    = Join-Path $Script:RepoRoot '.winbuild'
$Script:LogDir      = Join-Path $Script:WinBuild 'logs'
$Script:DownloadDir = Join-Path $Script:WinBuild 'downloads'
$Script:ToolsDir    = Join-Path $Script:WinBuild 'tools'
$Script:BuildDir    = Join-Path $Script:WinBuild 'build'
$Script:MariaDir    = Join-Path $Script:ToolsDir 'mariadb'
$Script:MariaData   = Join-Path $Script:WinBuild 'mariadb-data'
$Script:DeployDir   = Join-Path $Script:RepoRoot 'deploy'
$Script:MasterLog   = Join-Path $Script:LogDir 'deploy.log'
$Script:RunStamp    = Get-Date -Format 'yyyy-MM-dd_HH-mm-ss'
$Script:StageOk     = New-Object System.Collections.ArrayList   # список пройденных этапов
$Script:UserAgent   = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) EVEmuDeploy/1.0'
$Script:VsGenerator = 'Visual Studio 17 2022'   # уточняется после обнаружения VS: для VS 2019 -> 'Visual Studio 16 2019'
$Script:LogConsoleMarker = Join-Path $Script:LogDir 'log_console.pid'   # маркер отдельного окна с логом сервера

#-------------------------------------------------------------------------------
# РАННИЙ СТАРТ ЛОГА УСТАНОВКИ — до всего остального, чтобы не потерять ничего.
# Полный вывод консоли каждого запуска автоматически дописывается в файл
# deploy_install.log РЯДОМ СО СКРИПТОМ. Это спасает, когда окно PowerShell
# (запущенное двойным кликом) закрывается сразу после ошибки: весь вывод уже
# есть в файле, его достаточно прислать для удалённой диагностики.
#-------------------------------------------------------------------------------
$Script:InstallLog     = Join-Path $Script:RepoRoot 'deploy_install.log'
$Script:TranscriptFile = $null
try {
    # Ротация: слишком разросшийся лог прячем в deploy_install.log.old
    if ((Test-Path -LiteralPath $Script:InstallLog) -and ((Get-Item -LiteralPath $Script:InstallLog).Length -gt 20MB)) {
        Remove-Item -LiteralPath ($Script:InstallLog + '.old') -Force -ErrorAction SilentlyContinue
        Move-Item   -LiteralPath $Script:InstallLog -Destination ($Script:InstallLog + '.old') -Force -ErrorAction SilentlyContinue
    }
    Start-Transcript -Path $Script:InstallLog -Append -ErrorAction Stop | Out-Null
    $Script:TranscriptFile = $Script:InstallLog
} catch {
    # Папка скрипта может быть недоступна для записи — тогда лог пишем в %TEMP%
    try {
        $Script:InstallLog = Join-Path ([IO.Path]::GetTempPath()) 'evemu_deploy_install.log'
        Start-Transcript -Path $Script:InstallLog -Append -ErrorAction Stop | Out-Null
        $Script:TranscriptFile = $Script:InstallLog
    } catch { $Script:InstallLog = $null }
}
Write-Host ''
Write-Host ('=' * 78) -ForegroundColor Cyan
Write-Host ("deploy_windows.ps1 — запуск {0}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')) -ForegroundColor Cyan
Write-Host "Папка проекта : $Script:RepoRoot"
Write-Host ("Права админа  : " + $(if ($Elevated.IsPresent) { 'уже запрошены (повторный запуск с UAC)' } else { 'исходный запуск' }))
if ($Script:InstallLog) {
    Write-Host "Лог установки : $Script:InstallLog" -ForegroundColor Yellow
    Write-Host '                (весь вывод этого запуска пишется в этот файл; при сбое пришлите его)' -ForegroundColor Yellow
} else {
    Write-Host 'Лог установки : НЕ УДАЛОСЬ СОЗДАТЬ (нет прав записи рядом со скриптом)' -ForegroundColor Red
}
Write-Host ('=' * 78) -ForegroundColor Cyan

# Коды возврата по этапам (для перезапуска и точечной диагностики)
$Script:ExitCode = @{
    Elevation = 10; Env = 20; VsBuildTools = 30; CMake = 40; Sources = 45
    MariaSetup = 50; MariaStart = 55; Schema = 60; MarketSeed = 65
    Configure = 70; Build = 71; Install = 72; Publish = 75
    ServerRun = 80; Unexpected = 100
}

# Фиксированные версии/URL всех компонентов. MD5 сверены с ожидаемыми
# значениями из cmake/Build*.cmake самого проекта evemu_Crucible.
$Script:Cfg = @{
    VsBootstrapper   = 'https://aka.ms/vs/17/release/vs_BuildTools.exe'
    VsSetupArgs      = @('--quiet','--norestart','--wait','--nocache',
                         '--add','Microsoft.VisualStudio.Workload.VCTools',
                         '--includeRecommended')
    CmakeZip         = 'https://github.com/Kitware/CMake/releases/download/v3.31.6/cmake-3.31.6-windows-x86_64.zip'
    CmakeTopDir      = 'cmake-3.31.6-windows-x86_64'     # корневой каталог внутри zip
    CmakeMinVer      = '3.21'                            # минимум для генератора "Visual Studio 17 2022"
    CmakeMaxMajor    = 3                                 # CMake >= 4.0 несовместим с этим проектом
    MariaZip         = 'https://archive.mariadb.org/mariadb-11.4.5/winx64-packages/mariadb-11.4.5-winx64.zip'
    MariaMd5         = '233dacfa80d594e40e21d086b1f0ba42' # совпадает с cmake/BuildMySQL.cmake
    MariaTopDir      = 'mariadb-11.4.5-winx64'
    MariaPortFile    = 'db.port'                          # выбранный порт сохраняется в .winbuild
    RepoZip          = 'https://github.com/EvEmu-Project/evemu_Crucible/archive/refs/heads/master.zip'
    EvedbRepo        = 'https://github.com/EvEmu-Project/EVEDBTool'
    EvedbFallbackTag = '0.0.6'
    DbName           = 'evemu'; DbUser = 'evemu'; DbPass = 'evemu'
    ServerPort       = 26000; ImagePort = 26001
    FirewallRuleName = 'EVEmu Server'
    SchemaStamp      = 'db.schema.stamp'                  # маркер установленной схемы
    MarketSeedStamp  = 'db.market.stamp'                  # информационный стемп (авторитетный маркер — таблица deployMarketSeed в БД)
}

# Зависимости, которые cmake качает сам на этапе configure ОДНИМ файловым
# DOWNLOAD без ретраёв и таймаутов (см. cmake\BuildPackage.cmake: FILE(DOWNLOAD)).
# Любой сетевой сбой на ~90 МБ Boost или медленном SourceForge валит configure
# ("Configuring incomplete, errors occurred!"). Поэтому скрипт ПРЕДВАРительно
# скачивает эти архивы НАДЁЖНЫМ даунлоадером (ретраи + MD5, см. Get-WebFile)
# прямо в каталог сборки: cmake находит готовый файл, сверяет MD5 и не качает.
# Имена файлов и MD5 — из cmake\Build{Boost,TinyXML,UTF8CPP,ZLIB}.cmake.
$Script:CmakeDeps = @(
    @{ Name = 'boost_1_67_0.tar.bz2'; Url = 'https://archives.boost.io/release/1.67.0/source/boost_1_67_0.tar.bz2';          Md5 = 'ced776cb19428ab8488774e1415535ab' },
    @{ Name = 'tinyxml_2_6_2.tar.gz'; Url = 'http://downloads.sourceforge.net/project/tinyxml/tinyxml/2.6.2/tinyxml_2_6_2.tar.gz'; Md5 = 'c1b864c96804a10526540c664ade67f0' },
    @{ Name = 'zlib-1.2.7.tar.gz';    Url = 'https://zlib.net/fossils/zlib-1.2.7.tar.gz';                                       Md5 = '60df6a37c56e7c1366cca812414f7b85' },
    @{ Name = 'v2.3.4';               Url = 'https://codeload.github.com/nemtrif/utfcpp/zip/refs/tags/v2.3.4';                  Md5 = '29959274827576ebecc504701928e865' }
)

#===============================================================================
# 1. ЛОГИРОВАНИЕ
#===============================================================================
function Initialize-Logging {
    foreach ($d in @($Script:LogDir, $Script:DownloadDir, $Script:ToolsDir)) {
        if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    }
    # Резервный транскрипт в .winbuild\logs — только если ранний общий лог
    # (deploy_install.log рядом со скриптом) по какой-то причине не запустился;
    # два транскрипта одновременно одна сессия вести не может.
    if (-not $Script:TranscriptFile) {
        $tr = Join-Path $Script:LogDir ("transcript_{0}.log" -f $Script:RunStamp)
        try { Start-Transcript -Path $tr -ErrorAction Stop | Out-Null; $Script:TranscriptFile = $tr } catch { }
    }
    # Ротация: храним последние 20 транскриптов
    Get-ChildItem -LiteralPath $Script:LogDir -Filter 'transcript_*.log' -ErrorAction SilentlyContinue |
        Sort-Object Name -Descending | Select-Object -Skip 20 | Remove-Item -Force -ErrorAction SilentlyContinue

    $sep = '=' * 78
    $header = ($sep, "ЗАПУСК deploy_windows.ps1  —  $Script:RunStamp",
        "Пользователь: $env:USERNAME  (запущено с правами администратора: $([bool]($Elevated.IsPresent)))",
        "Репозиторий:  $Script:RepoRoot",
        "PowerShell:   $($PSVersionTable.PSVersion)  ($([Environment]::OSVersion.VersionString))",
        "Лог установки (рядом со скриптом): $(if ($Script:InstallLog) { $Script:InstallLog } else { 'НЕ СОЗДАН — папка недоступна для записи' })",
        $sep) -join [Environment]::NewLine
    Add-Content -LiteralPath $Script:MasterLog -Value $header -Encoding UTF8
    Write-Host $header
}

function Write-Log {
    param(
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('INFO','WARN','ERROR','OK','STEP','DATA')][string]$Level = 'INFO'
    )
    $line = "{0} [{1,-5}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Add-Content -LiteralPath $Script:MasterLog -Value $line -Encoding UTF8
    $color = switch ($Level) {
        'ERROR' { 'Red' } ; 'WARN' { 'Yellow' } ; 'OK' { 'Green' }
        'STEP'  { 'Cyan' } ; 'DATA' { 'DarkGray' } ; default { 'Gray' }
    }
    Write-Host $line -ForegroundColor $color
}

function Write-Step {
    param([Parameter(Mandatory)][string]$Name)
    $banner = ("{0}`nЭТАП: {1}`n{0}" -f ('-' * 78), $Name)
    Add-Content -LiteralPath $Script:MasterLog -Value $banner -Encoding UTF8
    Write-Host $banner -ForegroundColor Cyan
}

function Complete-Step {
    param([Parameter(Mandatory)][string]$Name, [string]$Detail = '')
    [void]$Script:StageOk.Add($Name)
    $msg = "Этап '$Name' завершён успешно" + $(if ($Detail) { " — $Detail" } else { '' })
    Write-Log $msg 'OK'
}

function Wait-BeforeExit {
    # Держит окно открытым до нажатия Enter (кроме режима -NoPause): окно,
    # запущенное двойным кликом, не исчезает сразу после ошибки/завершения.
    param([string]$Reason = '')
    if ($NoPause) { return }
    if ($Reason) {
        Write-Host ''
        Write-Host $Reason -ForegroundColor Yellow
    }
    Write-Host ''
    if ($Script:InstallLog) {
        Write-Host ('=' * 78) -ForegroundColor Yellow
        Write-Host '  ПОЛНЫЙ ЛОГ УСТАНОВКИ СОХРАНЁН РЯДОМ СО СКРИПТОМ' -ForegroundColor Yellow
        Write-Host '  (пришлите его для диагностики, если что-то пошло не так):' -ForegroundColor Yellow
        Write-Host "  $Script:InstallLog" -ForegroundColor Yellow
        Write-Host ('=' * 78) -ForegroundColor Yellow
    }
    Write-Host ''
    try { Read-Host 'Нажмите Enter, чтобы закрыть это окно' | Out-Null } catch { Start-Sleep -Seconds 15 }
}

#===============================================================================
# 2. БАЗОВЫЕ УТИЛИТЫ
#===============================================================================
function Test-IsAdmin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    (New-Object Security.Principal.WindowsPrincipal($id)).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

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

function Get-Md5 {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return $null }
    try { return (Get-FileHash -LiteralPath $Path -Algorithm MD5).Hash.ToLower() } catch { return $null }
}

function ConvertTo-FileUrl {
    # file:/// URL для передачи локального архива в CMake (пробелы -> %20)
    param([Parameter(Mandatory)][string]$Path)
    $full = [IO.Path]::GetFullPath($Path)
    $fwd = $full.Replace('\', '/')
    $escaped = [Uri]::EscapeUriString($fwd)
    return "file:///$escaped"
}

function Get-OurProcess {
    # Процессы, запущенные ИЗ папки проекта (чужие процессы не трогаем никогда)
    param([string]$NamePattern = '%')   # WQL-LIKE: % = любое имя
    $root = $Script:RepoRoot.TrimEnd('\') + '\'
    Get-CimInstance Win32_Process -Filter "Name LIKE '$NamePattern'" -ErrorAction SilentlyContinue |
        Where-Object { $_.ExecutablePath -and $_.ExecutablePath.StartsWith($root, [StringComparison]::OrdinalIgnoreCase) }
}

function ConvertTo-ArgumentString {
    # Корректное экранирование аргументов для CreateProcess/Start-Process (PS 5.1)
    param([string[]]$Arguments)
    $sb = New-Object System.Text.StringBuilder
    foreach ($a in $Arguments) {
        if ($sb.Length -gt 0) { [void]$sb.Append(' ') }
        if ($a -match '[\s"]') {
            $esc = $a -replace '(\\+)$', '$1$1'      # хвостовые слэши удваиваем
            $esc = $esc -replace '"', '\"'
            [void]$sb.Append('"' + $esc + '"')
        } else {
            [void]$sb.Append($a)
        }
    }
    $sb.ToString()
}

function Invoke-External {
    # Запуск внешней программы с записью stdout/stderr в файлы (без дедлоков),
    # логированием команды и кода возврата. Возвращает [pscustomobject] Code/Output.
    # Опционально: -InputFile подаётся процессу на STDIN (эквивалент "cmd < файл";
    # используется для заливки SQL: mariadb ... < seed_market.sql).
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [string[]]$Arguments = @(),
        [string]$WorkingDirectory = $null,
        [string]$LogTag = 'cmd',      # имена файлов: <LogTag>_out.log / <LogTag>_err.log
        [int]$TimeoutSec = 0,         # 0 = без таймаута
        [string]$InputFile = $null    # файл, подаваемый на STDIN (аналог "cmd < файл")
    )
    $outLog = Join-Path $Script:LogDir ("{0}_out.log" -f $LogTag)
    $errLog = Join-Path $Script:LogDir ("{0}_err.log" -f $LogTag)
    foreach ($f in @($outLog, $errLog)) {
        if (Test-Path -LiteralPath $f) { Move-Item -LiteralPath $f -Destination "$f.prev" -Force }
    }
    $argStr = ConvertTo-ArgumentString $Arguments
    Write-Log "ВЫПОЛНЕНИЕ: $FilePath $argStr" 'DATA'
    if (-not (Test-Path -LiteralPath $FilePath)) {
        Write-Log "Исполняемый файл не найден: $FilePath" 'ERROR'
        return [pscustomobject]@{ Code = 127; Output = "not found: $FilePath" }
    }
    if ($InputFile -and -not (Test-Path -LiteralPath $InputFile)) {
        Write-Log "Файл ввода (STDIN) не найден: $InputFile" 'ERROR'
        return [pscustomobject]@{ Code = 127; Output = "input file not found: $InputFile" }
    }
    try {
        # Сплаттинг: позволяет добавить -RedirectStandardInput только когда нужен
        $startArgs = @{
            FilePath = $FilePath; ArgumentList = $argStr; PassThru = $true; WindowStyle = 'Hidden'
            RedirectStandardOutput = $outLog; RedirectStandardError = $errLog
            WorkingDirectory = $(if ($WorkingDirectory) { $WorkingDirectory } else { $Script:RepoRoot })
        }
        if ($InputFile) { $startArgs['RedirectStandardInput'] = $InputFile }
        $p = Start-Process @startArgs
        # ФИКС (баг Windows PowerShell 5.1): обращение к .Handle открывает и
        # удерживает дескриптор процесса; без этого после завершения процесса
        # .ExitCode возвращает $null — все проверки кодов возврата ломались
        # (это вызывало ложный сбой этапа 'БД/пользователь' на PS 5.1).
        try { $null = $p.Handle } catch { }
        if ($TimeoutSec -gt 0) {
            $sw = [Diagnostics.Stopwatch]::StartNew()
            while (-not $p.HasExited -and $sw.Elapsed.TotalSeconds -lt $TimeoutSec) { Start-Sleep -Milliseconds 500 }
            if (-not $p.HasExited) {
                try { $p.Kill() } catch { }
                Write-Log "Таймаут ${TimeoutSec}s — процесс остановлен: $FilePath" 'WARN'
            }
        } else {
            $p.WaitForExit()
        }
        $code = $null
        try { $code = $p.ExitCode } catch { }
        if ($null -eq $code) {
            $code = -1
            Write-Log "Код возврата процесса не удалось прочитать (баг PS 5.1) — считаю ошибкой (-1). Вывод: $errLog" 'WARN'
        }
    } catch {
        Write-Log "Не удалось запустить '$FilePath': $($_.Exception.Message)" 'ERROR'
        return [pscustomobject]@{ Code = 126; Output = $_.Exception.Message }
    }
    $out = ''; $err = ''
    if (Test-Path -LiteralPath $outLog) { $out = Get-Content -LiteralPath $outLog -Raw -ErrorAction SilentlyContinue }
    if (Test-Path -LiteralPath $errLog) { $err = Get-Content -LiteralPath $errLog -Raw -ErrorAction SilentlyContinue }
    if ($out) { Write-Log ("STDOUT ($LogTag): " + ($out.Trim() -replace "`r?`n", ' | ').Substring(0, [Math]::Min(4000, $out.Trim().Length))) 'DATA' }
    if ($err) { Write-Log ("STDERR ($LogTag): " + ($err.Trim() -replace "`r?`n", ' | ').Substring(0, [Math]::Min(4000, $err.Trim().Length))) 'DATA' }
    return [pscustomobject]@{ Code = $code; Output = ($out + "`n" + $err) }
}

function Get-WebFile {
    # Скачивание с ретраями, кэшем по MD5 и подробным логированием.
    param(
        [Parameter(Mandatory)][string]$Url,
        [Parameter(Mandatory)][string]$OutFile,
        [string]$ExpectedMd5 = $null,
        [int]$Attempts = 3
    )
    $dir = Split-Path -Parent $OutFile
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }

    if ($ExpectedMd5) {
        $have = Get-Md5 $OutFile
        if ($have -eq $ExpectedMd5) {
            Write-Log "Файл уже скачан, MD5 совпадает: $OutFile" 'OK'
            return $true
        } elseif ($have) {
            Write-Log "Файл существует, но MD5 не совпадает ($have != $ExpectedMd5) — перекачиваю" 'WARN'
            Remove-Item -LiteralPath $OutFile -Force -ErrorAction SilentlyContinue
        }
    } elseif (Test-Path -LiteralPath $OutFile) {
        Write-Log "Файл уже существует: $OutFile ($((Get-Item -LiteralPath $OutFile).Length) байт)" 'OK'
        return $true
    }

    for ($i = 1; $i -le $Attempts; $i++) {
        $t0 = Get-Date
        $part = "$OutFile.part"
        try {
            Write-Log "Скачивание (попытка $i/$Attempts): $Url" 'INFO'
            Invoke-WebRequest -Uri $Url -OutFile $part -UserAgent $Script:UserAgent `
                -TimeoutSec 900 -UseBasicParsing -ErrorAction Stop
            if (-not (Test-Path -LiteralPath $part) -or (Get-Item -LiteralPath $part).Length -eq 0) {
                throw "файл пустой или отсутствует после загрузки"
            }
            Move-Item -LiteralPath $part -Destination $OutFile -Force
            $size = [math]::Round((Get-Item -LiteralPath $OutFile).Length / 1MB, 1)
            $dur  = [math]::Round(((Get-Date) - $t0).TotalSeconds, 1)
            $spd  = if ($dur -gt 0) { [math]::Round($size / $dur, 1) } else { 0 }
            $md5  = Get-Md5 $OutFile
            Write-Log "Скачано: $OutFile (${size} МБ за ${dur}с, ~${spd} МБ/с, MD5=$md5)" 'OK'
            if ($ExpectedMd5 -and $md5 -ne $ExpectedMd5) {
                Write-Log "MD5 НЕ СОВПАЛ: получен $md5, ожидался $ExpectedMd5" 'WARN'
                Remove-Item -LiteralPath $OutFile -Force
                throw "контрольная сумма не совпала"
            }
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

function Expand-ArchiveSafe {
    # Распаковка архива (zip/tar.gz): сначала tar.exe (быстро), затем Expand-Archive
    param([Parameter(Mandatory)][string]$Archive, [Parameter(Mandatory)][string]$Destination)
    if (-not (Test-Path -LiteralPath $Destination)) {
        New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    }
    $tar = Join-Path $env:SystemRoot 'System32\tar.exe'
    if (Test-Path -LiteralPath $tar) {
        Write-Log "Распаковка (tar.exe): $Archive -> $Destination" 'INFO'
        $r = Invoke-External -FilePath $tar -Arguments @('-xf', $Archive, '-C', $Destination) -LogTag 'untar' -TimeoutSec 1800
        if ($r.Code -eq 0) { return $true }
        Write-Log "tar.exe завершился с кодом $($r.Code) — пробую Expand-Archive" 'WARN'
    }
    try {
        Write-Log "Распаковка (Expand-Archive): $Archive -> $Destination" 'INFO'
        Expand-Archive -LiteralPath $Archive -DestinationPath $Destination -Force -ErrorAction Stop
        return $true
    } catch {
        Write-Log "Распаковка не удалась: $($_.Exception.Message)" 'ERROR'
        return $false
    }
}

function Get-Tail {
    param([string]$Path, [int]$Lines = 100)
    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) { return "(файл не найден: $Path)" }
    $c = @(Get-Content -LiteralPath $Path -ErrorAction SilentlyContinue)
    if ($c.Count -eq 0) { return "(пусто: $Path)" }
    if ($c.Count -le $Lines) { return ($c -join "`n") }
    return (($c | Select-Object -Last $Lines) -join "`n")
}

function Fail-Stage {
    param([Parameter(Mandatory)][string]$Stage, [Parameter(Mandatory)][int]$Code,
          [Parameter(Mandatory)][string]$Message)
    Write-Log "ОШИБКА НА ЭТАПЕ '$Stage' (код возврата $Code): $Message" 'ERROR'
    Write-Diagnostics
    Write-Host ''
    Write-Host ('!' * 78) -ForegroundColor Red
    Write-Host "  СБОЙ: $Stage" -ForegroundColor Red
    Write-Host "  $Message" -ForegroundColor Red
    Write-Host "  Журнал этапов: $Script:MasterLog" -ForegroundColor Red
    Write-Host "  Диагностический архив: $Script:WinBuild\evemu_deploy_logs.zip" -ForegroundColor Red
    Write-Host ('!' * 78) -ForegroundColor Red
    Write-Host ''
    Write-Host 'Скрипт можно запустить ПОВТОРНО — он продолжит с прерванного места.' -ForegroundColor Yellow
    Wait-BeforeExit
    try { Stop-Transcript | Out-Null } catch { }
    exit $Code
}

#===============================================================================
# 3. СНИМОК ОКРУЖЕНИЯ И ПРОВЕРКА СЕТИ (для удалённой диагностики)
#===============================================================================
function Show-Environment {
    Write-Log "---- СНИМОК ОКРУЖЕНИЯ ----" 'DATA'
    $os = Get-CimInstance Win32_OperatingSystem
    $cs = Get-CimInstance Win32_ComputerSystem
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='$($Script:RepoRoot.Substring(0,2))'"
    $freeGb = if ($disk) { [math]::Round($disk.FreeSpace / 1GB, 1) } else { -1 }
    $envInfo = @(
        "OS:               $($os.Caption) $($os.Version) (build $($os.BuildNumber))"
        "Архитектура:      $($os.OSArchitecture)"
        "Процессор:        $($cs.Manufacturer) — $((Get-CimInstance Win32_Processor | Select-Object -First 1).Name), ядер: $env:NUMBER_OF_PROCESSORS"
        "ОЗУ всего:        $([math]::Round($cs.TotalPhysicalMemory / 1GB, 1)) ГБ, свободно: $([math]::Round($os.FreePhysicalMemory / 1MB, 1)) ГБ"
        "Свободно на диске $((Split-Path $Script:RepoRoot -Qualifier)): ${freeGb} ГБ"
        "Домен/рабгруппа:  $($cs.Domain)"
        "Исполнимый PS:    $($PSVersionTable.PSVersion), хост: $(($env:PSModulePath -split ';')[0])"
        "Время:            $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')  (таймзона: $((Get-TimeZone).Id))"
        "Путь проекта:     $Script:RepoRoot"
        "UAC-элевация:     $(Test-IsAdmin)"
        "Облачный/прокси:  HTTP_PROXY=$env:HTTP_PROXY HTTPS_PROXY=$env:HTTPS_PROXY NO_PROXY=$env:NO_PROXY"
    )
    foreach ($l in $envInfo) { Write-Log $l 'DATA' }

    if ($freeGb -lt 10) {
        Write-Log "КРИТИЧЕСКИ МАЛО МЕСТА (${freeGb} ГБ) — нужно минимум 10-15 ГБ, рекомендуется 20+" 'ERROR'
    } elseif ($freeGb -lt 20) {
        Write-Log "Мало свободного места (${freeGb} ГБ): может не хватить для VS Build Tools + сборки" 'WARN'
    }
    if ($Script:RepoRoot -match '[^\x00-\x7F]') {
        Write-Log "ВНИМАНИЕ: путь проекта содержит не-ASCII символы — некоторые инструменты сборки могут работать нестабильно. Рекомендуется путь только из латинских символов." 'WARN'
    }
    if ($Script:RepoRoot.Length -gt 60) {
        Write-Log "Путь проекта длинный ($($Script:RepoRoot.Length) симв.) — включаю LongPaths" 'WARN'
    }
    try {
        $mp = Get-MpComputerStatus -ErrorAction SilentlyContinue
        if ($mp) { Write-Log ("Защитник Windows: AM $($mp.AMServiceEnabled), RealTime $($mp.RealTimeProtectionEnabled)") 'DATA' }
    } catch { }
    return $freeGb
}

function Test-Network {
    Write-Log "---- ПРОВЕРКА ДОСТУПНОСТИ СЕРВЕРОВ ----" 'DATA'
    $hosts = @('github.com', 'codeload.github.com', 'objects.githubusercontent.com',
               'archive.mariadb.org', 'archives.boost.io', 'zlib.net',
               'downloads.sourceforge.net', 'aka.ms')
    $allOk = $true
    foreach ($h in $hosts) {
        $dns = $null; $tcp = $false
        try {
            $dns = (Resolve-DnsName -Name $h -Type A -ErrorAction Stop | Where-Object { $_.IPAddress } |
                     Select-Object -First 1).IPAddress
        } catch { }
        if ($dns) {
            $tcp = Test-TcpPort -Port 443 -HostName $dns -TimeoutMs 3000
        }
        $status = if ($dns -and $tcp) { 'OK' } elseif ($dns) { 'DNS OK, TCP:443 недоступен' } else { 'DNS НЕ РЕШАЕТСЯ' }
        if (-not ($dns -and $tcp)) { $allOk = $false }
        Write-Log ("  {0,-32} DNS={1}  TCP443={2}  [{3}]" -f $h, ($dns -join ','), $tcp, $status) 'DATA'
    }
    if (-not $allOk) {
        Write-Log "Часть серверов недоступна. Если есть прокси/фильтр — настройте и перезапустите скрипт." 'WARN'
    }
    return $allOk
}

#===============================================================================
# 4. ПРАВА АДМИНИСТРАТОРА / LONG PATHS
#===============================================================================
function Request-Elevation {
    if (Test-IsAdmin) { Write-Log "Скрипт уже выполняется с правами администратора" 'OK'; return $true }
    if ($NoElevate) {
        Write-Log "Запуск без прав администратора (-NoElevate): установка VS Build Tools, правило firewall и настройка LongPaths будут недоступны" 'WARN'
        return $false
    }
    # Перезапуск самих себя с UAC-элевацией, параметры передаются дальше
    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$($PSCommandPath)`"", '-Elevated')
    if ($DbPort -gt 0)    { $argList += @('-DbPort', "$DbPort") }
    if ($SkipBuild)       { $argList += '-SkipBuild' }
    if ($NoFirewall)      { $argList += '-NoFirewall' }
    if ($NoPause)         { $argList += '-NoPause' }
    Write-Log "Запрашиваю права администратора (подтвердите запрос UAC)..." 'INFO'
    # Транскрипт останавливаем ДО запуска повышенного процесса: тот продолжит
    # писать в тот же deploy_install.log, а два процесса не могут одновременно
    # вести транскрипт на одном файле.
    try { Stop-Transcript | Out-Null; $Script:TranscriptFile = $null } catch { }
    try {
        Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList ($argList -join ' ') -ErrorAction Stop
    } catch {
        Write-Log "Отказ в UAC / не удалось перезапуститься: $($_.Exception.Message)" 'ERROR'
        # Транскрипт был остановлен перед попыткой запуска — возобновляем, чтобы
        # сообщение об отказе тоже попало в deploy_install.log
        if ($Script:InstallLog -and -not $Script:TranscriptFile) {
            try { Start-Transcript -Path $Script:InstallLog -Append -ErrorAction Stop | Out-Null; $Script:TranscriptFile = $Script:InstallLog } catch { }
        }
        Write-Host ''
        Write-Host ('!' * 78) -ForegroundColor Red
        Write-Host '  Для установки VS Build Tools нужны права администратора.' -ForegroundColor Red
        Write-Host '  Запустите скрипт заново и подтвердите запрос UAC' -ForegroundColor Red
        Write-Host '  (или используйте -NoElevate для частичного запуска).' -ForegroundColor Red
        Write-Host ('!' * 78) -ForegroundColor Red
        Wait-BeforeExit 'Установка остановлена: не получены права администратора.'
        try { Stop-Transcript | Out-Null } catch { }
        exit $Script:ExitCode.Elevation
    }
    Write-Log "Скрипт перезапущен в повышенном процессе. Этот экземпляр завершается." 'INFO'
    Write-Host ''
    Write-Host 'Скрипт перезапущен с правами администратора в НОВОМ ОКНЕ.' -ForegroundColor Green
    Write-Host 'Продолжение установки смотрите в нём (его вывод тоже пишется в deploy_install.log).' -ForegroundColor Green
    Write-Host 'Это окно закроется автоматически.' -ForegroundColor Green
    return $null    # $null = родительский процесс завершается БЕЗ паузы (работает elevated-окно)
}

function Enable-LongPaths {
    try {
        $cur = (Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -ErrorAction Stop).LongPathsEnabled
        if ($cur -eq 1) { Write-Log "LongPaths уже включены" 'OK'; return }
        if (-not (Test-IsAdmin)) { Write-Log "Нет прав на включение LongPaths (пропускаю)" 'WARN'; return }
        Set-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' -Name 'LongPathsEnabled' -Value 1 -Type DWord
        Write-Log "Включён LongPathsEnabled=1 (HKLM\...\FileSystem) — требуется для длинных путей сборки" 'OK'
    } catch {
        Write-Log "Не удалось включить LongPaths: $($_.Exception.Message)" 'WARN'
    }
}

#===============================================================================
# 5. VISUAL STUDIO BUILD TOOLS 2022 (MSVC + Windows SDK)
#===============================================================================
function Get-VsWhere {
    $v = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path -LiteralPath $v) { return $v }
    return $null
}

function Test-VsDirHasVc {
    # Проверяет, что в каталоге VS реально есть инструменты сборки C++:
    # vcvarsall.bat (маркер рабочей нагрузки VCTools) и хотя бы один cl.exe x64.
    param([Parameter(Mandatory)][string]$Dir)
    if (-not (Test-Path -LiteralPath (Join-Path $Dir 'VC\Auxiliary\Build\vcvarsall.bat'))) { return $false }
    $msvcRoot = Join-Path $Dir 'VC\Tools\MSVC'
    if (-not (Test-Path -LiteralPath $msvcRoot)) { return $false }
    try {
        foreach ($ts in (Get-ChildItem -LiteralPath $msvcRoot -Directory -ErrorAction SilentlyContinue)) {
            if (Test-Path -LiteralPath (Join-Path $ts.FullName 'bin\Hostx64\x64\cl.exe')) { return $true }
        }
    } catch { }
    return $false
}

function Get-VsInfoFromDir {
    # Формирует объект VS по каталогу. Major берётся из параметра либо из пути
    # (\2022\ -> 17, \2019\ -> 16). Возвращает $null для неподходящих версий.
    param([Parameter(Mandatory)][string]$Dir, [int]$Major = 0, [bool]$HasVc = $false)
    if ($Major -le 0) {
        if ($Dir -match '\\(2019|2022)\\') {
            $Major = if ($Matches[1] -eq '2022') { 17 } else { 16 }
        }
    }
    if ($Major -ne 17 -and $Major -ne 16) { return $null }
    $gen = if ($Major -eq 17) { 'Visual Studio 17 2022' } else { 'Visual Studio 16 2019' }
    return [pscustomobject]@{ Path = $Dir; Major = $Major; Generator = $gen; HasVc = $HasVc }
}

function Get-ExistingVs {
    # Ищем ЛЮБОЕ издание VS (BuildTools/Community/Pro/Enterprise) с рабочей
    # нагрузкой VCTools. Возвращает $null или объект @{ Path; Major; Generator; HasVc }.
    # Приоритет: VS 2022 (17) > VS 2019 (16) — обе поддерживаются генераторами
    # CMake 3.x (который нужен этому проекту: CMake 4.x с ним несовместим).
    # VS 2026 (18) и новее ПРОПУСКАЮТСЯ: CMake 3.x не знает их генераторов.
    #
    # ФИКС (этап 'VS Build Tools', код возврата 30): предыдущая версия молча
    # пропускала подходящие экземпляры, если installationPath пуст или
    # Test-Path не находил каталог, — из-за этого скрипт падал с кодом 30
    # ДАЖЕ ПОСЛЕ успешной установки (код 0 в логе при найденном vswhere
    # экземпляре VS 2022). Теперь:
    #   1) каждый пропуск логируется С ПРИЧИНОЙ (удалённая диагностика);
    #   2) JSON вырезается из вывода устойчиво (срез от первого '[' до
    #      последнего ']'), чтобы мусор/потоки stderr не ломали парсер;
    #   3) добавлены резервные способы: plain-text vswhere и прямой осмотр
    #      стандартных каталогов VS с проверкой vcvarsall.bat + cl.exe;
    #   4) дамп-диагностика вызывает vswhere с -products '*' — без него
    #      Build Tools не видны и дамп всегда был '[]'.
    $found = @{}   # путь -> объект VS (дедупликация между способами)

    $vswhere = Get-VsWhere
    if ($vswhere) {
        # --- Способ 1: vswhere JSON. ВАЖНО: '-products *' обязателен, без него
        # vswhere не возвращает Build Tools (они не «product» по умолчанию). ---
        $r = Invoke-External -FilePath $vswhere `
            -Arguments @('-all', '-prerelease', '-products', '*',
                        '-requires', 'Microsoft.VisualStudio.Workload.VCTools', '-format', 'json') `
            -LogTag 'vswhere_check'
        # Для диагностики: полный дамп всех установленных продуктов (с Build Tools)
        $null = Invoke-External -FilePath $vswhere -Arguments @('-all', '-prerelease', '-products', '*', '-format', 'json') -LogTag 'vswhere_dump'

        $json = $null
        if ($r.Output) {
            # Ищем сбалансированный JSON-массив в смешанном выводе (stdout+stderr):
            # учитываем строки и экранированные кавычки, игнорируем мусор до/после.
            $s = "$($r.Output)"
            $start = $s.IndexOf('[')
            if ($start -ge 0) {
                $depth = 0; $inStr = $false; $esc = $false
                for ($i = $start; $i -lt $s.Length; $i++) {
                    $c = $s[$i]
                    if ($inStr) {
                        if ($esc) { $esc = $false }
                        elseif ($c -eq '\') { $esc = $true }
                        elseif ($c -eq '"') { $inStr = $false }
                    } else {
                        if ($c -eq '"') { $inStr = $true }
                        elseif ($c -eq '[') { $depth++ }
                        elseif ($c -eq ']') {
                            $depth--
                            if ($depth -eq 0) { $json = $s.Substring($start, $i - $start + 1); break }
                        }
                    }
                }
            }
        }
        $instances = @()
        if ($json) {
            try { $instances = @(ConvertFrom-Json $json) }
            catch {
                Write-Log ("Не удалось разобрать JSON vswhere (длина {0}): {1}" -f $json.Length, $_.Exception.Message) 'WARN'
            }
        } else {
            Write-Log "vswhere не вернул JSON (пустой вывод) — перехожу к резервным способам поиска" 'WARN'
        }
        foreach ($ins in $instances) {
            $major = 0
            if ("$($ins.installationVersion)" -match '^(\d+)\.') { $major = [int]$Matches[1] }
            $ipath = ("$($ins.installationPath)").Trim()
            if (-not $ipath) {
                Write-Log "vswhere: у экземпляра v$major (id=$($ins.instanceId)) нет installationPath — пропускаю" 'DATA'
                continue
            }
            if (-not (Test-Path -LiteralPath $ipath)) {
                Write-Log "vswhere: экземпляр v$major указывает на несуществующий путь (устаревшая запись установки): '$ipath' — пропускаю" 'DATA'
                continue
            }
            if ($major -ne 17 -and $major -ne 16) {
                Write-Log "vswhere: VS v$major не подходит (нужна 2019/2022): $ipath — пропускаю" 'DATA'
                continue
            }
            $hasVc = Test-VsDirHasVc $ipath
            Write-Log ("vswhere: найдена VS (v{0}): {1} — инструменты C++: {2}" -f $major, $ipath, $(if ($hasVc) { 'есть' } else { 'НЕ НАЙДЕНЫ (vcvarsall.bat/cl.exe)' })) 'DATA'
            if (-not $found.ContainsKey($ipath)) { $found[$ipath] = Get-VsInfoFromDir $ipath -Major $major -HasVc $hasVc }
        }

        # --- Способ 2: vswhere plain-text (не зависит от JSON и кодировок) ---
        if ($found.Count -eq 0) {
            $r2 = Invoke-External -FilePath $vswhere `
                -Arguments @('-all', '-prerelease', '-products', '*',
                            '-requires', 'Microsoft.VisualStudio.Workload.VCTools',
                            '-property', 'installationPath') `
                -LogTag 'vswhere_paths'
            foreach ($ln in (("$($r2.Output)") -split "`r?`n")) {
                $p = $ln.Trim()
                if (-not $p -or $p -notmatch '^[A-Za-z]:\\') { continue }
                if (-not (Test-Path -LiteralPath $p)) { continue }
                $info = Get-VsInfoFromDir $p -HasVc (Test-VsDirHasVc $p)
                if (-not $info) { continue }
                Write-Log "vswhere (plain): найдена VS (v$($info.Major)): $p" 'DATA'
                if (-not $found.ContainsKey($p)) { $found[$p] = $info }
            }
        }
    }

    # --- Способ 3: прямой осмотр стандартных каталогов (если vswhere
    #     отсутствует, сломан или его реестр содержит устаревшие записи) ---
    if ($found.Count -eq 0) {
        $roots = @(${env:ProgramFiles(x86)}, $env:ProgramFiles) | Where-Object { $_ }
        foreach ($root in $roots) {
            foreach ($y in @('2022', '2019')) {
                foreach ($ed in @('BuildTools', 'Community', 'Professional', 'Enterprise')) {
                    $dir = Join-Path $root ("Microsoft Visual Studio\{0}\{1}" -f $y, $ed)
                    if (-not (Test-Path -LiteralPath $dir)) { continue }
                    if (-not (Test-VsDirHasVc $dir)) {
                        Write-Log "Прямой поиск: каталог '$dir' есть, но инструменты C++ (vcvarsall.bat/cl.exe) не найдены" 'DATA'
                        continue
                    }
                    $info = Get-VsInfoFromDir $dir -HasVc $true
                    if ($info) {
                        Write-Log "Прямой поиск: найдена VS (v$($info.Major)): $dir" 'OK'
                        if (-not $found.ContainsKey($dir)) { $found[$dir] = $info }
                    }
                }
            }
        }
    }

    # --- Выбор лучшего кандидата: 2022 (17) > 2019 (16); при равенстве
    #     предпочтение экземпляру с реально найденным cl.exe ---
    $best = $null
    foreach ($info in $found.Values) {
        if (-not $info) { continue }
        if (-not $best) { $best = $info; continue }
        if ($info.Major -gt $best.Major) { $best = $info; continue }
        if ($info.Major -eq $best.Major -and $info.HasVc -and -not $best.HasVc) { $best = $info }
    }
    if ($best) {
        if (-not $best.HasVc) {
            Write-Log "ВНИМАНИЕ: в выбранной VS $($best.Major) не найден cl.exe — возможно, нагрузка VCTools установлена не полностью" 'WARN'
        }
        Write-Log "Выбрана VS $($best.Major): $($best.Path) — генератор CMake '$($best.Generator)'" 'OK'
        return $best
    }
    Write-Log "Не найдена VS 2019/2022 с нагрузкой VCTools (проверены vswhere JSON, plain-text и прямые каталоги). VS 2026+ несовместима с CMake 3.x этого проекта — требуется установка VS 2022 Build Tools" 'WARN'
    return $null
}

function Install-VsBuildTools {
    param([string]$VsPath)
    if ($VsPath) { return $VsPath }

    if (-not (Test-IsAdmin)) {
        Write-Log "НЕТ ПРАВ АДМИНИСТРАТОРА: установить VS Build Tools нельзя. Запустите скрипт от администратора." 'ERROR'
        return $null
    }
    $bt = Join-Path $Script:DownloadDir 'vs_BuildTools.exe'
    $ok = Get-WebFile -Url $Script:Cfg.VsBootstrapper -OutFile $bt
    if (-not $ok) {
        # Fallback: winget
        Write-Log "Прямое скачивание bootstrapper не удалось — пробую winget" 'WARN'
        $wg = Get-Command winget.exe -ErrorAction SilentlyContinue
        if ($wg) {
            $r = Invoke-External -FilePath $wg.Source `
                -Arguments @('install', '--id', 'Microsoft.VisualStudio.2022.BuildTools', '--source', 'winget',
                             '--accept-source-agreements', '--accept-package-agreements',
                             '--override', ($Script:Cfg.VsSetupArgs -join ' ')) `
                -LogTag 'winget_vsbt' -TimeoutSec 7200
            if ($r.Code -ne 0) {
                Write-Log "winget install VS BuildTools вернул код $($r.Code)" 'ERROR'
            }
        } else {
            Write-Log "winget недоступен — установка VS Build Tools невозможна" 'ERROR'
        }
        $path = Get-ExistingVs
        if ($path) { return $path }
        return $null
    }

    Write-Log "Устанавливаю VS Build Tools 2022 (VCTools + Windows SDK + CMake). Это занимает 10-30 минут..." 'INFO'
    $r = Invoke-External -FilePath $bt -Arguments $Script:Cfg.VsSetupArgs -LogTag 'vs_setup' -TimeoutSec 7200
    switch ($r.Code) {
        0     { Write-Log "VS Build Tools установлены (код 0)" 'OK' }
        3010  { Write-Log "VS Build Tools установлены, ТРЕБУЕТСЯ ПЕРЕЗАГРУЗКА (код 3010). Продолжаю, но при ошибках сборки — перезагрузитесь и запустите скрипт снова." 'WARN' }
        default {
            Write-Log "Установщик VS Build Tools вернул код $($r.Code) (1602=отмена, 1638=другая версия, 5100=блокировка политикой). Логи установщика: $env:TEMP\dd_*.log" 'ERROR'
            $path = Get-ExistingVs
            if ($path) {
                Write-Log "Несмотря на код — VS с VCTools найдена, продолжаю: $path" 'WARN'
                return $path
            }
            return $null
        }
    }
    # Сбор логов установщика для диагностики
    try {
        $dd = Get-ChildItem "$env:TEMP\dd_*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 4
        if ($dd) {
            $dst = Join-Path $Script:LogDir 'vs_installer'
            New-Item -ItemType Directory -Path $dst -Force | Out-Null
            foreach ($f in $dd) { Copy-Item $f.FullName $dst -Force }
            Write-Log "Логи установщика VS скопированы: $dst" 'DATA'
        }
    } catch { }

    # ФИКС: после успешной установки (код 0) детект мог не увидеть свежую
    # установку (лаг регистрации экземпляра / кэш установщика) — раньше это
    # сразу приводило к коду возврата 30, хотя VS 2022 была установлена.
    # Пробуем определить VS несколько раз с паузой.
    $vs = $null
    for ($try = 1; $try -le 3 -and -not $vs; $try++) {
        if ($try -gt 1) {
            Write-Log "VS установлена, но пока не определяется (попытка $try/3) — жду 10 секунд и повторяю проверку..." 'WARN'
            Start-Sleep -Seconds 10
        }
        $vs = Get-ExistingVs
    }
    if (-not $vs) {
        Write-Log "Установщик отработал с кодом 0, но VS 2022 с нагрузкой VCTools не найдена после 3 попыток. Смотрите .winbuild\logs\vswhere_check_out.log, vswhere_dump_out.log и $env:TEMP\dd_*.log" 'ERROR'
    }
    return $vs
}

#===============================================================================
# 6. РАЗРЕШЕНИЕ CMAKE (системный -> из VS -> портативный в .winbuild)
#===============================================================================
function Get-CmakeVersion {
    param([string]$CmakeExe)
    if (-not $CmakeExe -or -not (Test-Path -LiteralPath $CmakeExe)) { return $null }
    $r = Invoke-External -FilePath $CmakeExe -Arguments @('--version') -LogTag 'cmake_ver'
    if ($r.Output -match 'cmake version (\d+)\.(\d+)(\.(\d+))?') {
        return [version]("{0}.{1}.{2}" -f $Matches[1], $Matches[2], $(if ($Matches[3]) { $Matches[4] } else { '0' }))
    }
    return $null
}

function Test-CmakeSuitable {
    param([version]$V)
    $min = [version]$Script:Cfg.CmakeMinVer
    return ($V -ge $min -and $V.Major -le $Script:Cfg.CmakeMaxMajor)
}

function Resolve-CMake {
    param([string]$VsPath)
    $candidates = @()

    # 1) CMake в PATH (система)
    $sys = Get-Command cmake.exe -ErrorAction SilentlyContinue
    if ($sys) { $candidates += $sys.Source }

    # 2) CMake, входящий в VS Build Tools
    if ($VsPath) {
        $vsCmake = Join-Path $VsPath 'Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe'
        if (Test-Path -LiteralPath $vsCmake) { $candidates += $vsCmake }
    }

    foreach ($c in $candidates) {
        $v = Get-CmakeVersion $c
        if (-not $v) { Write-Log "CMake найден, но версия не определилась: $c" 'WARN'; continue }
        if (Test-CmakeSuitable $v) {
            Write-Log "Использую CMake ${v}: ${c}" 'OK'
            return $c
        }
        Write-Log "CMake $v по пути $c не подходит (нужен >= $($Script:Cfg.CmakeMinVer) и < $($Script:Cfg.CmakeMaxMajor+1).0: проект несовместим с CMake 4.x)" 'WARN'
    }

    # 3) Портативный CMake в .winbuild\tools\cmake
    $portable = Join-Path $Script:ToolsDir ($Script:Cfg.CmakeTopDir + '\bin\cmake.exe')
    if (Test-Path -LiteralPath $portable) {
        $v = Get-CmakeVersion $portable
        if ($v -and (Test-CmakeSuitable $v)) {
            Write-Log "Использую портативный CMake ${v}: ${portable}" 'OK'
            return $portable
        }
        Write-Log "Портативный CMake повреждён или не подходит — перекачиваю" 'WARN'
    }

    Write-Log "Подходящего CMake нет — скачиваю портативный $($Script:Cfg.CmakeTopDir) в .winbuild\tools" 'INFO'
    $zip = Join-Path $Script:DownloadDir (($Script:Cfg.CmakeTopDir) + '.zip')
    $ok = Get-WebFile -Url $Script:Cfg.CmakeZip -OutFile $zip
    if (-not $ok) { return $null }
    if (-not (Expand-ArchiveSafe -Archive $zip -Destination $Script:ToolsDir)) { return $null }
    if (-not (Test-Path -LiteralPath $portable)) {
        Write-Log "После распаковки не найден $portable" 'ERROR'
        return $null
    }
    $v = Get-CmakeVersion $portable
    if (-not $v -or -not (Test-CmakeSuitable $v)) {
        Write-Log "Скачанный CMake не проходит проверку версии" 'ERROR'
        return $null
    }
    Write-Log "Использую портативный CMake ${v}: ${portable}" 'OK'
    return $portable
}

#===============================================================================
# 7. ИСХОДНИКИ ПРОЕКТА
#===============================================================================
function Assert-Sources {
    # Скрипт лежит в корне проекта; проверяем что исходники на месте.
    # Если вдруг запущен из пустой папки — скачиваем master.zip с GitHub.
    param([switch]$NoFetch)
    $marker = Join-Path $Script:RepoRoot 'CMakeLists.txt'
    $srcDir = Join-Path $Script:RepoRoot 'src'
    if ((Test-Path -LiteralPath $marker) -and (Test-Path -LiteralPath $srcDir) -and
        (Test-Path -LiteralPath (Join-Path $Script:RepoRoot 'sql\base'))) {
        $gitDir = Join-Path $Script:RepoRoot '.git'
        if (Test-Path -LiteralPath $gitDir) {
            $git = Get-Command git.exe -ErrorAction SilentlyContinue
            if ($git) {
                $r = Invoke-External -FilePath $git.Source -Arguments @('rev-parse', 'HEAD') `
                        -WorkingDirectory $Script:RepoRoot -LogTag 'git_rev'
                if ($r.Code -eq 0) { Write-Log "Исходники на месте, git commit: $($r.Output.Trim())" 'OK' }
            } else {
                Write-Log "Исходники на месте, но git не установлен — версия сборки будет без git-информации (не критично)" 'WARN'
            }
        } else {
            Write-Log "Исходники на месте (без .git — информация о версии будет неполной, не критично)" 'OK'
        }
        return $true
    }

    if ($NoFetch) {
        Write-Log "Исходники не найдены даже после распаковки архива" 'ERROR'
        return $false
    }
    Write-Log "Исходники проекта не найдены в $Script:RepoRoot — скачиваю master.zip с GitHub" 'WARN'
    $zip = Join-Path $Script:DownloadDir 'evemu_Crucible_master.zip'
    if (-not (Get-WebFile -Url $Script:Cfg.RepoZip -OutFile $zip)) { return $false }
    $tmpExtract = Join-Path $Script:WinBuild 'src_extract'
    if (Test-Path -LiteralPath $tmpExtract) { Remove-Item -LiteralPath $tmpExtract -Recurse -Force }
    if (-not (Expand-ArchiveSafe -Archive $zip -Destination $tmpExtract)) { return $false }
    $inner = Get-ChildItem -LiteralPath $tmpExtract -Directory | Select-Object -First 1
    if (-not $inner) { Write-Log "В архиве исходников нет каталога" 'ERROR'; return $false }
    # Копируем содержимое в корень (кроме нашего скрипта и .winbuild)
    Get-ChildItem -LiteralPath $inner.FullName | ForEach-Object {
        $dest = Join-Path $Script:RepoRoot $_.Name
        if (-not (Test-Path -LiteralPath $dest)) {
            Move-Item -LiteralPath $_.FullName -Destination $dest
        }
    }
    Remove-Item -LiteralPath $tmpExtract -Recurse -Force -ErrorAction SilentlyContinue
    return (Assert-Sources -NoFetch)   # повторная проверка после распаковки
}

#===============================================================================
# 8. ПОРТАТИВНАЯ MARIADB (скачивание + распаковка, всё внутри проекта)
#===============================================================================
function Initialize-MariaDbFiles {
    # РаспаковкаMariaDB, если ещё не распакована
    $mysqld = Join-Path $Script:MariaDir "$($Script:Cfg.MariaTopDir)\bin\mysqld.exe"
    if (Test-Path -LiteralPath $mysqld) {
        Write-Log "MariaDB уже распакована: $mysqld" 'OK'
        return $true
    }
    $zip = Join-Path $Script:DownloadDir 'mariadb-11.4.5-winx64.zip'
    if (-not (Get-WebFile -Url $Script:Cfg.MariaZip -OutFile $zip -ExpectedMd5 $Script:Cfg.MariaMd5)) {
        return $false
    }
    Write-Log "Распаковываю MariaDB в $Script:MariaDir (1-2 минуты)..." 'INFO'
    if (-not (Expand-ArchiveSafe -Archive $zip -Destination $Script:MariaDir)) { return $false }
    if (-not (Test-Path -LiteralPath $mysqld)) {
        Write-Log "После распаковки mysqld.exe не найден: $mysqld" 'ERROR'
        return $false
    }
    Write-Log "MariaDB распакована: $mysqld" 'OK'
    return $true
}

#===============================================================================
# 9. ВЫБОР ПОРТА БД И КОНФИГ MY.INI
#===============================================================================
function Resolve-DbPort {
    # Порт хранится в .winbuild\db.port. Приоритет: параметр > файл > 3306.
    $portFile = Join-Path $Script:WinBuild $Script:Cfg.MariaPortFile
    $chosen = 0

    if ($DbPort -gt 0) {
        $chosen = $DbPort
        Write-Log "Порт БД задан параметром: $chosen" 'INFO'
    } elseif (Test-Path -LiteralPath $portFile) {
        $saved = (Get-Content -LiteralPath $portFile -Raw -ErrorAction SilentlyContinue)
        $saved = "$saved".Trim()
        if ($saved -match '^\d+$') {
            $chosen = [int]$saved
            Write-Log "Порт БД из прошлых запусков: $chosen" 'INFO'
        }
    }

    if ($chosen -eq 0) {
        $chosen = 3306
        if (Test-TcpPort -Port 3306) {
            # 3306 кем-то занят. Наш ли это mysqld?
            $ours = Get-OurProcess -NamePattern 'mysqld.exe'
            if (-not ($ours | Where-Object { $_.ExecutablePath -like "$Script:MariaDir*" })) {
                Write-Log "Порт 3306 занят сторонним сервисом — использую 3307" 'WARN'
                $chosen = 3307
                if (Test-TcpPort -Port 3307) {
                    Write-Log "И 3307 занят — использую 3308" 'WARN'
                    $chosen = 3308
                }
            }
        }
    }
    Set-Content -LiteralPath $portFile -Value $chosen -Encoding ASCII
    Write-Log "Выбран порт БД: $chosen (сохранён в $portFile)" 'INFO'
    return $chosen
}

function Write-MariaIni {
    param([Parameter(Mandatory)][int]$Port)
    # my.ini кладём внутрь проекта; пути — прямые слэши (mysqld их понимает)
    $ini = Join-Path $Script:WinBuild 'my.ini'
    $toFwd = { param($p) ($p -replace '\\','/') }
    $content = @"
# Конфигурация MariaDB для EVEmu (создан deploy_windows.ps1)
[mysqld]
datadir=$(&$toFwd $Script:MariaData)
port=$Port
bind-address=127.0.0.1
character-set-server=utf8mb4
collation-server=utf8mb4_general_ci
innodb_buffer_pool_size=512M
max_allowed_packet=64M
max_connections=200
# ВАЖНО: skip-name-resolve НЕ включать — иначе root@localhost не будет
# матчиться на TCP-подключения с 127.0.0.1 (обратный DNS нужен для matching'а)
explicit_defaults_for_timestamp=ON
log-error=$(&$toFwd (Join-Path $Script:LogDir 'mysqld.err'))
pid-file=$(&$toFwd (Join-Path $Script:WinBuild 'mysqld.pid'))

[client]
port=$Port
"@
    Set-Content -LiteralPath $ini -Value $content -Encoding ASCII
    Write-Log "my.ini записан: $ini (порт $Port)" 'DATA'
    return $ini
}

#===============================================================================
# 10. ИНИЦИАЛИЗАЦИЯ КАТАЛОГА ДАННЫХ MARIADB
#===============================================================================
function Initialize-MariaData {
    param([Parameter(Mandatory)][string]$IniPath)
    # Каталог данных инициализируется ОДИН раз и переживает перезапуски
    $mysqlSysDb = Join-Path $Script:MariaData 'mysql'
    if (Test-Path -LiteralPath $mysqlSysDb) {
        Write-Log "Каталог данных БД уже инициализирован: $Script:MariaData" 'OK'
        return $true
    }
    if (-not (Test-Path -LiteralPath $Script:MariaData)) {
        New-Item -ItemType Directory -Path $Script:MariaData -Force | Out-Null
    }
    $installDb = Join-Path $Script:MariaDir "$($Script:Cfg.MariaTopDir)\bin\mysql_install_db.exe"
    if (-not (Test-Path -LiteralPath $installDb)) {
        Write-Log "Не найден mysql_install_db.exe: $installDb" 'ERROR'
        return $false
    }
    Write-Log "Инициализирую каталог данных MariaDB (первый запуск, 1-3 минуты)..." 'INFO'
    # Пробуем с defaults-file; если инструмент его не принимает — только с datadir
    $r = Invoke-External -FilePath $installDb -Arguments @("--defaults-file=$IniPath", '--datadir', $Script:MariaData) `
            -LogTag 'mysql_install_db' -TimeoutSec 900
    if ($r.Code -ne 0) {
        Write-Log "mysql_install_db с --defaults-file вернул $($r.Code) — пробую только --datadir" 'WARN'
        $r = Invoke-External -FilePath $installDb -Arguments @('--datadir', $Script:MariaData) `
                -LogTag 'mysql_install_db2' -TimeoutSec 900
    }
    if ($r.Code -ne 0 -or -not (Test-Path -LiteralPath $mysqlSysDb)) {
        Write-Log "Инициализация БД не удалась (код $($r.Code)). Журнал: $Script:LogDir\mysql_install_db_out.log / mysqld.err" 'ERROR'
        return $false
    }
    Write-Log "Каталог данных инициализирован: $Script:MariaData" 'OK'
    return $true
}

#===============================================================================
# 11. ЗАПУСК MARIADB (фоновый процесс из папки проекта)
#===============================================================================
function Start-MariaDb {
    param([Parameter(Mandatory)][string]$IniPath, [Parameter(Mandatory)][int]$Port)
    # Если наш mysqld уже работает и порт отвечает — ничего не делаем
    $ours = @(Get-OurProcess -NamePattern 'mysqld.exe' | Where-Object { $_.ExecutablePath -like "$Script:MariaDir*" })
    if ($ours.Count -gt 0) {
        if (Test-TcpPort -Port $Port) {
            Write-Log "Наш mysqld уже запущен (PID: $(($ours | Select-Object -First 1).ProcessId)) и порт $Port отвечает" 'OK'
            return $true
        }
        Write-Log "Наш mysqld завис (порт $Port не отвечает) — перезапускаю" 'WARN'
        foreach ($p in $ours) {
            try { Stop-Process -Id $p.ProcessId -Force -ErrorAction SilentlyContinue } catch { }
        }
        Start-Sleep -Seconds 2
    } elseif (Test-TcpPort -Port $Port) {
        # Порт занят чужим процессом — fatal (выбранный порт конфликтует)
        Write-Log "Порт $Port занят сторонним процессом. Перезапустите скрипт с -DbPort <другой порт>" 'ERROR'
        return $false
    }

    $mysqld = Join-Path $Script:MariaDir "$($Script:Cfg.MariaTopDir)\bin\mysqld.exe"
    Write-Log "Запускаю mysqld (порт $Port)..." 'INFO'
    try {
        $proc = Start-Process -FilePath $mysqld -ArgumentList ('"--defaults-file=' + $IniPath + '"') `
                 -WindowStyle Hidden -PassThru
        try { $null = $proc.Handle } catch { }   # фикс PS 5.1: иначе .ExitCode при падении = $null
        Write-Log "mysqld запущен, PID $($proc.Id)" 'DATA'
    } catch {
        Write-Log "Не удалось запустить mysqld: $($_.Exception.Message)" 'ERROR'
        return $false
    }

    # Ожидание готовности (до 120 секунд)
    for ($i = 1; $i -le 60; $i++) {
        if (Test-TcpPort -Port $Port) { break }
        if ($proc.HasExited) {
            Write-Log "mysqld завершился с кодом $($proc.ExitCode) при старте. Журнал: $Script:LogDir\mysqld.err" 'ERROR'
            Write-Log ("Последние строки mysqld.err:`n" + (Get-Tail (Join-Path $Script:LogDir 'mysqld.err') 40)) 'DATA'
            return $false
        }
        Start-Sleep -Seconds 2
    }
    if (-not (Test-TcpPort -Port $Port)) {
        Write-Log "MariaDB не поднялась за 120 секунд. Журнал: $Script:LogDir\mysqld.err" 'ERROR'
        return $false
    }
    # Дополнительная проверка: отвечает ли протокол MySQL (mysqladmin ping)
    $admin = Join-Path $Script:MariaDir "$($Script:Cfg.MariaTopDir)\bin\mariadb-admin.exe"
    if (Test-Path -LiteralPath $admin) {
        $r = Invoke-External -FilePath $admin -Arguments @("--defaults-file=$IniPath", '-u', 'root', 'ping') -LogTag 'db_ping'
        Write-Log "mariadb-admin ping -> код $($r.Code), вывод: $($r.Output.Trim())" 'DATA'
    }
    Write-Log "MariaDB запущена и отвечает на порту $Port" 'OK'
    return $true
}

#===============================================================================
# 12. БАЗА/ПОЛЬЗОВАТЕЛЬ EVEMU + СХЕМА ЧЕРЕЗ EVEDBTOOL
#===============================================================================
function Invoke-Sql {
    # Выполнение SQL через портативный клиент mysql. Возвращает $true/false.
    param([Parameter(Mandatory)][string]$Sql, [string]$User = 'root', [string]$Password = '',
          [Parameter(Mandatory)][int]$Port)
    $client = Join-Path $Script:MariaDir "$($Script:Cfg.MariaTopDir)\bin\mariadb.exe"
    if (-not (Test-Path -LiteralPath $client)) { $client = Join-Path $Script:MariaDir "$($Script:Cfg.MariaTopDir)\bin\mysql.exe" }
    $clientArgs = @('-h', '127.0.0.1', '-P', "$Port", '-u', $User)
    if ($Password) { $clientArgs += @("-p$Password") }
    $clientArgs += @('-e', $Sql)
    $r = Invoke-External -FilePath $client -Arguments $clientArgs -LogTag 'sql_exec'
    if ($r.Code -eq 0) { return $true }
    if ($r.Code -eq -1) {
        # Код возврата не удалось прочитать (баг PS 5.1) — судим по выводу клиента:
        # успех = в выводе нет признаков ошибки SQL
        $bad = ($r.Output -match 'ERROR \d+|Access denied|denied for user|Can''t connect|Unknown database|Unknown error')
        if (-not $bad) {
            Write-Log "Код возврата mariadb-клиента не читается, но ошибок SQL в выводе нет — считаю успехом" 'WARN'
            return $true
        }
    }
    return $false
}

function Initialize-DbUser {
    param([Parameter(Mandatory)][int]$Port)
    # Идемпотентно: CREATE IF NOT EXISTS. Сначала пробуем root без пароля
    # (так создаёт mysql_install_db), затем известные пароли прошлых запусков.
    $sql = @"
CREATE DATABASE IF NOT EXISTS $($Script:Cfg.DbName) CHARACTER SET utf8mb4;
CREATE USER IF NOT EXISTS '$($Script:Cfg.DbUser)'@'localhost' IDENTIFIED BY '$($Script:Cfg.DbPass)';
CREATE USER IF NOT EXISTS '$($Script:Cfg.DbUser)'@'127.0.0.1' IDENTIFIED BY '$($Script:Cfg.DbPass)';
CREATE USER IF NOT EXISTS '$($Script:Cfg.DbUser)'@'%' IDENTIFIED BY '$($Script:Cfg.DbPass)';
GRANT ALL PRIVILEGES ON $($Script:Cfg.DbName).* TO '$($Script:Cfg.DbUser)'@'localhost';
GRANT ALL PRIVILEGES ON $($Script:Cfg.DbName).* TO '$($Script:Cfg.DbUser)'@'127.0.0.1';
GRANT ALL PRIVILEGES ON $($Script:Cfg.DbName).* TO '$($Script:Cfg.DbUser)'@'%';
FLUSH PRIVILEGES;
"@
    $rootOk = Invoke-Sql -Sql $sql -User 'root' -Port $Port
    if (-not $rootOk) {
        Write-Log "root без пароля не подошёл — проверяю, что БД уже настроена (вход как evemu)" 'WARN'
        $check = Invoke-Sql -Sql "USE $($Script:Cfg.DbName); SELECT 1;" -User $Script:Cfg.DbUser -Password $Script:Cfg.DbPass -Port $Port
        if ($check) {
            Write-Log "БД evemu уже существует и пользователь evemu работает — пропускаю создание" 'OK'
            return $true
        }
        Write-Log "Не удалось создать БД/пользователя: и root, и evemu не проходят. Журнал: $Script:LogDir\sql_exec_out.log" 'ERROR'
        return $false
    }
    # Проверка входа под evemu
    $ok = Invoke-Sql -Sql "SELECT VERSION();" -User $Script:Cfg.DbUser -Password $Script:Cfg.DbPass -Port $Port
    if (-not $ok) {
        Write-Log "Пользователь evemu создан, но вход не удался — смотрю журнал" 'ERROR'
        return $false
    }
    Write-Log "БД '$($Script:Cfg.DbName)' и пользователь '$($Script:Cfg.DbUser)' готовы" 'OK'
    return $true
}

function Get-EveDbTool {
    $exe = Join-Path $Script:RepoRoot 'sql\evedbtool.exe'
    if (Test-Path -LiteralPath $exe) {
        # Проверка что это PE-файл (не HTML-страница ошибки)
        try {
            $fs = [IO.File]::OpenRead($exe)
            $b = New-Object byte[] 2; [void]$fs.Read($b, 0, 2); $fs.Close()
            if ($b[0] -eq 0x4D -and $b[1] -eq 0x5A) {
                Write-Log "evedbtool.exe уже скачан: $exe" 'OK'
                return $exe
            }
            Write-Log "evedbtool.exe повреждён (не PE) — перекачиваю" 'WARN'
            Remove-Item -LiteralPath $exe -Force
        } catch { }
    }
    # Определяем тег последнего релиза через редирект (API может быть rate-limited)
    $tag = $null
    try {
        $req = [Net.HttpWebRequest]::Create($Script:Cfg.EvedbRepo + '/releases/latest')
        $req.AllowAutoRedirect = $false
        $req.UserAgent = $Script:UserAgent
        $req.Timeout = 15000
        $resp = $req.GetResponse()
        $loc = $resp.Headers['Location']
        $resp.Close()
        if ($loc -match '/tag/(.+)$') { $tag = $Matches[1] }
    } catch { }
    if (-not $tag) {
        $tag = $Script:Cfg.EvedbFallbackTag
        Write-Log "Не удалось определить последний релиз EVEDBTool — использую фиксированный $tag" 'WARN'
    }
    Write-Log "Скачиваю EVEDBTool $tag..." 'INFO'
    $url = "$($Script:Cfg.EvedbRepo)/releases/download/$tag/evedbtool.exe"
    if (-not (Get-WebFile -Url $url -OutFile $exe)) { return $null }
    # Проверка PE-заголовка
    try {
        $fs = [IO.File]::OpenRead($exe)
        $b = New-Object byte[] 2; [void]$fs.Read($b, 0, 2); $fs.Close()
        if (-not ($b[0] -eq 0x4D -and $b[1] -eq 0x5A)) {
            Write-Log "Скачанный evedbtool.exe не является PE-файлом (проблема с GitHub?)" 'ERROR'
            return $null
        }
    } catch { }
    $r = Invoke-External -FilePath $exe -Arguments @('--version') -LogTag 'evedb_ver'
    Write-Log "evedbtool.exe готов: $exe ($($r.Output.Trim()))" 'OK'
    return $exe
}

function Initialize-DbSchema {
    param([Parameter(Mandatory)][string]$EveDbTool, [Parameter(Mandatory)][int]$Port)
    $sqlDir = Join-Path $Script:RepoRoot 'sql'
    $stampFile = Join-Path $Script:WinBuild $Script:Cfg.SchemaStamp
    $toFwd = { param($p) ($p -replace '\\','/') }

    # evedb.yaml — конфиг инструмента (в CWD запуска), пути с прямыми слэшами
    $yaml = @"
base-dir: $(&$toFwd (Join-Path $sqlDir 'base'))
db-database: $($Script:Cfg.DbName)
db-host: 127.0.0.1
db-pass: $($Script:Cfg.DbPass)
db-port: $Port
db-user: $($Script:Cfg.DbUser)
log-level: Info
migrations-dir: $(&$toFwd (Join-Path $sqlDir 'migrations'))
dungeons-dir: $(&$toFwd (Join-Path $sqlDir 'dungeons'))
"@
    Set-Content -LiteralPath (Join-Path $sqlDir 'evedb.yaml') -Value $yaml -Encoding ASCII
    Write-Log "evedb.yaml записан (sql\evedb.yaml)" 'DATA'

    if (Test-Path -LiteralPath $stampFile) {
        Write-Log "Схема БД уже устанавливалась ($(Get-Content $stampFile -Raw)) — догоняю миграции (no-op если актуально)" 'INFO'
        $r = Invoke-External -FilePath $EveDbTool -Arguments @('up') -WorkingDirectory $sqlDir -LogTag 'evedb_up'
        if ($r.Code -ne 0) {
            Write-Log "evedbtool up вернул $($r.Code) — возможна рассинхронизация миграций" 'WARN'
        }
    } else {
        Write-Log "Устанавливаю базу данных EVEmu через evedbtool install (5-15 минут, ~300 таблиц)..." 'INFO'
        $r = Invoke-External -FilePath $EveDbTool -Arguments @('install') -WorkingDirectory $sqlDir `
                -LogTag 'evedbtool' -TimeoutSec 3600
        if ($r.Code -ne 0) {
            Write-Log "evedbtool install не удался (код $($r.Code)). Журнал: $Script:LogDir\evedbtool_out.log" 'ERROR'
            return $false
        }
        Set-Content -LiteralPath $stampFile -Value (Get-Date -Format 'yyyy-MM-dd HH:mm:ss') -Encoding ASCII
    }

    # Подсчёт таблиц — проверка успеха
    $client = Join-Path $Script:MariaDir "$($Script:Cfg.MariaTopDir)\bin\mariadb.exe"
    if (-not (Test-Path -LiteralPath $client)) { $client = Join-Path $Script:MariaDir "$($Script:Cfg.MariaTopDir)\bin\mysql.exe" }
    $r = Invoke-External -FilePath $client `
        -Arguments @('-h','127.0.0.1','-P',"$Port",'-u', $Script:Cfg.DbUser, "-p$($Script:Cfg.DbPass)", '-N', '-B', '-e',
                     "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$($Script:Cfg.DbName)'") `
        -LogTag 'db_tables'
    $tableCount = 0
    if ($r.Output -match '(\d+)') { $tableCount = [int]$Matches[1] }
    Write-Log "Таблиц в БД '$($Script:Cfg.DbName)': $tableCount" 'DATA'
    if ($tableCount -lt 50) {
        Write-Log "Слишком мало таблиц ($tableCount < 50) — схема не установилась" 'ERROR'
        return $false
    }

    # Загрузка данженов (идемпотентна)
    $r = Invoke-External -FilePath $EveDbTool -Arguments @('dungeon', 'apply') -WorkingDirectory $sqlDir `
            -LogTag 'evedb_dungeon' -TimeoutSec 1800
    if ($r.Code -ne 0) { Write-Log "dungeon apply вернул $($r.Code) — продолжаю (не критично)" 'WARN' }

    Complete-Step 'Схема БД EVEmu' "$tableCount таблиц, миграции актуальны"
    return $true
}

#-------------------------------------------------------------------------------
# 12.1. СИД РЫНКА (адаптация официальной инструкции EVEmu "Source Seeding"):
#         mysql -u evemu -p -h 127.0.0.1 < sql/seed_and_clean/seed_market.sql
#       Отличия от инструкции, необходимые для автоматического деплоя:
#         1) пароль НЕ запрашивается интерактивно — используется учётная запись
#            evemu из конфигурации скрипта (Cfg.DbUser / Cfg.DbPass);
#         2) regionID берётся из параметра -SeedRegionId (по умолчанию 10000001,
#            Derelik — как в оригинальном seed_market.sql) и подставляется в SQL;
#         3) ГЛАВНОЕ: сид выполняется РОВНО ОДИН РАЗ и никогда не перезатирает
#            данные. Решение принимается по МАРКЕРУ в самой БД (таблица
#            evemu.deployMarketSeed), а НЕ по количеству строк в mktOrders:
#            ордера в mktOrders появляются и без сида (бот MarketBot
#            "Trader Joe", игра игроков) — такие остатки сидом НЕ считаются,
#            и при их наличии сид всё равно выполняется, добавляя стартовые
#            ордера поверх (существующие не удаляются). После успешного сида
#            маркер записывается в БД — все дальнейшие запуски этап
#            пропускают. Сам seed_market.sql идемпотентностью НЕ обладает
#            (повторный прогон дублирует ордера — проверено на MariaDB
#            11.4.5), поэтому маркер обязателен. Стемп .winbuild\db.market.stamp
#            ведётся только для журнала/сводки.
#-------------------------------------------------------------------------------
function Get-DbScalar {
    # Скалярный запрос к БД через портативный клиент mariadb (первое непустое
    # значение вывода). Возвращает строку или $null при ошибке выполнения.
    param([Parameter(Mandatory)][string]$Sql, [Parameter(Mandatory)][int]$Port)
    $client = Join-Path $Script:MariaDir "$($Script:Cfg.MariaTopDir)\bin\mariadb.exe"
    if (-not (Test-Path -LiteralPath $client)) { $client = Join-Path $Script:MariaDir "$($Script:Cfg.MariaTopDir)\bin\mysql.exe" }
    $r = Invoke-External -FilePath $client `
        -Arguments @('-h','127.0.0.1','-P',"$Port",'-u', $Script:Cfg.DbUser, "-p$($Script:Cfg.DbPass)",
                     '-N', '-B', '-e', $Sql) `
        -LogTag 'db_scalar'
    if ($r.Code -ne 0) { return $null }
    # Первая непустая строка вывода (предупреждение mariadb о пароле в командной
    # строке попадает в STDERR и оказывается в конце $r.Output — не мешает)
    $line = @($r.Output -split "`r?`n" | Where-Object { $null -ne $_ -and $_.Trim() -ne '' } | Select-Object -First 1)
    if ($line.Count -eq 0) { return $null }
    return $line[0].Trim()
}

function Initialize-MarketSeed {
    # СИД РЫНКА EVEmu: разовая заливка стартовых рыночных ордеров из
    # sql\seed_and_clean\seed_market.sql. Идемпотентность обеспечивает
    # МАРКЕР в самой БД — таблица deployMarketSeed (см. 12.1 выше):
    # пока маркера нет, сид выполняется ДАЖЕ при посторонних ордерах в
    # mktOrders (остатки игры / бота MarketBot — они не удаляются, стартовые
    # ордера добавляются поверх); после успешного сида маркер записывается,
    # и дальнейшие запуски этап пропускают. Данные никогда не удаляются.
    param([Parameter(Mandatory)][int]$Port)

    $seedSql      = Join-Path $Script:RepoRoot 'sql\seed_and_clean\seed_market.sql'
    $stampFile    = Join-Path $Script:WinBuild $Script:Cfg.MarketSeedStamp
    $adaptedSql   = Join-Path $Script:WinBuild 'seed_market_adapted.sql'
    $markerTable  = 'deployMarketSeed'   # маркерная таблица в базе evemu
    $markerRow    = 'market'

    # --- 1. Файл сида должен быть в исходниках репозитория ---
    if (-not (Test-Path -LiteralPath $seedSql)) {
        Write-Log "Файл сида рынка не найден: $seedSql (исходники неполные?)" 'ERROR'
        return $false
    }

    # --- 2. Таблица mktOrders должна существовать (схема залита этапом 10) ---
    $tExists = Get-DbScalar -Sql ("SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$($Script:Cfg.DbName)' AND table_name='mktOrders';") -Port $Port
    if ("$tExists" -ne '1') {
        Write-Log "Таблица '$($Script:Cfg.DbName).mktOrders' не найдена (получено: '$tExists') — схема БД неполна, сид невозможен" 'ERROR'
        return $false
    }

    # --- 3. ЗАЩИТА ОТ ПОВТОРА: МАРКЕР в самой БД, а не подсчёт ордеров ---
    # Ордера в mktOrders могли появиться БЕЗ сида (бот MarketBot "Trader
    # Joe", игра игроков) — такие остатки «засеянным рынком» не считаются
    # (кейс: 42 посторонних ордера), поэтому решение только по маркеру.
    $mkCreate = "CREATE TABLE IF NOT EXISTS $($Script:Cfg.DbName).$markerTable (marker VARCHAR(32) NOT NULL PRIMARY KEY, regionID INT NOT NULL, orders INT NOT NULL DEFAULT 0, seededAt TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;"
    if (-not (Invoke-Sql -Sql $mkCreate -User $Script:Cfg.DbUser -Password $Script:Cfg.DbPass -Port $Port)) {
        Write-Log "Не удалось создать маркерную таблицу $($Script:Cfg.DbName).$markerTable (см. sql_exec_*.log)" 'ERROR'
        return $false
    }
    $seeded = Get-DbScalar -Sql "SELECT COUNT(*) FROM $($Script:Cfg.DbName).$markerTable WHERE marker='$markerRow';" -Port $Port
    if ($null -eq $seeded -or $seeded -notmatch '^\d+$') {
        Write-Log "Не удалось прочитать маркер сида из $($Script:Cfg.DbName).$markerTable (см. db_scalar_out.log)" 'ERROR'
        return $false
    }
    if ([int]$seeded -gt 0) {
        $details   = Get-DbScalar -Sql "SELECT CONCAT('regionID=', regionID, ', orders=', orders, ', дата=', seededAt) FROM $($Script:Cfg.DbName).$markerTable WHERE marker='$markerRow';" -Port $Port
        $ordersNow = Get-DbScalar -Sql "SELECT COUNT(*) FROM $($Script:Cfg.DbName).mktOrders;" -Port $Port
        Write-Log "Рынок засеян ранее (маркер в БД: $details) — данные НЕ перезатираю, этап пропущен (сейчас в mktOrders: $ordersNow ордеров)" 'OK'
        Complete-Step 'Сид рынка' "пропущено: маркер в БД ($details); mktOrders не тронут ($ordersNow ордеров)"
        return $true
    }

    # --- 4. Маркера нет — сид выполняется (посторонние ордера НЕ мешают) ---
    $ordersBefore = Get-DbScalar -Sql "SELECT COUNT(*) FROM $($Script:Cfg.DbName).mktOrders;" -Port $Port
    if ($null -eq $ordersBefore -or $ordersBefore -notmatch '^\d+$') {
        Write-Log "Не удалось прочитать количество ордеров в mktOrders (см. db_scalar_out.log)" 'ERROR'
        return $false
    }
    $beforeRegion = Get-DbScalar -Sql "SELECT COUNT(*) FROM $($Script:Cfg.DbName).mktOrders WHERE regionID=$SeedRegionId;" -Port $Port
    if ($null -eq $beforeRegion -or $beforeRegion -notmatch '^\d+$') {
        Write-Log "Не удалось посчитать ордера в регионе $SeedRegionId (см. db_scalar_out.log)" 'ERROR'
        return $false
    }
    if ([int]$ordersBefore -gt 0) {
        Write-Log "В mktOrders уже есть $ordersBefore ордеров, но маркер сида в БД отсутствует — это остатки игры/бота MarketBot, а НЕ засеянный рынок" 'WARN'
        Write-Log "Выполняю РАЗОВЫЙ сид: sql\seed_and_clean\seed_market.sql, regionID=$SeedRegionId — стартовые ордера добавляются ПОВЕРХ, существующие ($ordersBefore шт.) не удаляются" 'INFO'
    } else {
        Write-Log "mktOrders пуста — выполняю РАЗОВЫЙ сид рынка: sql\seed_and_clean\seed_market.sql, regionID=$SeedRegionId (это займёт несколько минут)" 'INFO'
    }

    # Готовим адаптированный SQL (имя БД + регион)
    $sql = Get-Content -LiteralPath $seedSql -Raw
    # подставляем актуальное имя БД (в файле жёстко прописано 'use evemu;')
    $sql = $sql -replace '(?im)^(\s*use\s+)[A-Za-z0-9_]+(\s*;.*)$', ('${1}' + $Script:Cfg.DbName + '${2}')
    # подставляем регион из параметра -SeedRegionId
    $regionPattern = '(?im)^(\s*set\s+@regionid\s*=\s*)\d+(\s*;.*)$'
    if ($sql -match $regionPattern) {
        $sql = $sql -replace $regionPattern, ('${1}' + $SeedRegionId + '${2}')
        Write-Log "regionID подставлен из параметра: $SeedRegionId" 'DATA'
    } else {
        Write-Log "Строка 'set @regionid=...' в seed_market.sql не найдена — используется регион, заданный в самом файле" 'WARN'
    }
    Set-Content -LiteralPath $adaptedSql -Value $sql -Encoding ASCII

    # --- 5. Заливка (аналог: mysql -u evemu -p -h 127.0.0.1 < seed_market.sql) ---
    $client = Join-Path $Script:MariaDir "$($Script:Cfg.MariaTopDir)\bin\mariadb.exe"
    if (-not (Test-Path -LiteralPath $client)) { $client = Join-Path $Script:MariaDir "$($Script:Cfg.MariaTopDir)\bin\mysql.exe" }
    $r = Invoke-External -FilePath $client `
        -Arguments @('-h','127.0.0.1','-P',"$Port",'-u', $Script:Cfg.DbUser, "-p$($Script:Cfg.DbPass)", '-D', $Script:Cfg.DbName) `
        -InputFile $adaptedSql -LogTag 'seed_market' -TimeoutSec 3600
    if ($r.Code -ne 0) {
        Write-Log "Сид рынка не удался (код $($r.Code)). Журналы: $Script:LogDir\seed_market_out.log / seed_market_err.log" 'ERROR'
        return $false
    }

    # --- 6. Проверка успеха: прирост ордеров ИМЕННО в целевом регионе ---
    # (посторонние ордера могли лежать в mktOrders ещё до сида — общий
    # COUNT их бы маскировал; сверяем регион сида)
    $afterRegion = Get-DbScalar -Sql "SELECT COUNT(*) FROM $($Script:Cfg.DbName).mktOrders WHERE regionID=$SeedRegionId;" -Port $Port
    $ordersAfter = Get-DbScalar -Sql "SELECT COUNT(*) FROM $($Script:Cfg.DbName).mktOrders;" -Port $Port
    if ($null -eq $afterRegion -or $afterRegion -notmatch '^\d+$' -or $null -eq $ordersAfter -or $ordersAfter -notmatch '^\d+$') {
        Write-Log "Не удалось прочитать результат сида (см. db_scalar_out.log)" 'ERROR'
        return $false
    }
    $grown = [int]$afterRegion - [int]$beforeRegion
    if ($grown -lt 10) {
        Write-Log "Сид не состоялся: в регионе $SeedRegionId добавилось всего $grown ордеров (было $beforeRegion, стало $afterRegion). Верный ли regionID=$SeedRegionId ?" 'ERROR'
        return $false
    }

    # --- 7. Маркер в БД: с этого момента повторные запуски этап пропускают ---
    $mkInsert = "INSERT INTO $($Script:Cfg.DbName).$markerTable (marker, regionID, orders) VALUES ('$markerRow', $SeedRegionId, $afterRegion) ON DUPLICATE KEY UPDATE regionID=VALUES(regionID), orders=VALUES(orders), seededAt=CURRENT_TIMESTAMP;"
    if (-not (Invoke-Sql -Sql $mkInsert -User $Script:Cfg.DbUser -Password $Script:Cfg.DbPass -Port $Port)) {
        Write-Log "Сид выполнен (+$grown ордеров в регионе $SeedRegionId), но маркер в БД записать не удалось — при следующем запуске сид повторится! (см. sql_exec_*.log)" 'ERROR'
        return $false
    }
    Set-Content -LiteralPath $stampFile -Value ("{0}  regionID={1}  ordersInRegion={2}  total={3}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $SeedRegionId, $afterRegion, $ordersAfter) -Encoding ASCII
    Write-Log "Рынок засеян успешно: +$grown ордеров в регионе $SeedRegionId (всего в mktOrders: $ordersAfter; посторонние ордера не тронуты). Маркер записан в БД — повторные запуски данные не перезатрут" 'OK'
    Complete-Step 'Сид рынка' "+$grown ордеров в регионе $SeedRegionId (всего $ordersAfter)"
    return $true
}

#===============================================================================
# 13. ДЛИННЫЕ КОМАНДЫ С ЖИВЫМ ВЫВОДОМ (cmake configure/build/install)
#===============================================================================
function Invoke-LongCommand {
    # Запуск с перенаправлением в файл + "живым" хвостом вывода в консоль/лог,
    # чтобы было видно прогресс долгих операций (сборка занимает 10-40 минут).
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
        if (Test-Path -LiteralPath $f) { Move-Item -LiteralPath $f -Destination "$f.prev" -Force }
    }
    $argStr = ConvertTo-ArgumentString $Arguments
    Write-Log "ВЫПОЛНЕНИЕ: $FilePath $argStr" 'INFO'

    $p = Start-Process -FilePath $FilePath -ArgumentList $argStr -PassThru -WindowStyle Hidden `
            -RedirectStandardOutput $outLog -RedirectStandardError $errLog `
            -WorkingDirectory $(if ($WorkingDirectory) { $WorkingDirectory } else { $Script:RepoRoot })
    # ФИКС (баг PS 5.1): удерживаем дескриптор процесса, иначе после завершения
    # .ExitCode возвращает $null и все проверки кодов ломаются
    try { $null = $p.Handle } catch { }

    # Живой хвост stdout: читаем приращение файла каждые 3 секунды
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
                            Add-Content -LiteralPath $Script:MasterLog -Value "    $line" -Encoding UTF8
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
    # финальное чтение остатка
    try {
        $tail = Get-Content -LiteralPath $outLog -Tail 15 -ErrorAction SilentlyContinue
        foreach ($line in $tail) { if ($line.Trim()) { Write-Host "    $line" -ForegroundColor DarkGray } }
    } catch { }
    $err = ''
    if (Test-Path -LiteralPath $errLog) { $err = (Get-Content -LiteralPath $errLog -Raw -ErrorAction SilentlyContinue) }
    $code = $null
    try { $code = $p.ExitCode } catch { }
    if ($null -eq $code) { $code = -1 }
    Write-Log "Команда завершена, код возврата: $code. Полный журнал: $outLog" $(if ($code -eq 0) { 'OK' } else { 'ERROR' })
    return [pscustomobject]@{ Code = $code; OutLog = $outLog; ErrLog = $errLog; Stderr = $err }
}

#===============================================================================
# 14. СБОРКА: CONFIGURE / BUILD / INSTALL
#===============================================================================
function Invoke-CMakeConfigure {
    param(
        [Parameter(Mandatory)][string]$CMakeExe,
        [string]$MysqlUrl = $null     # file:/// или https:// URL архива MariaDB
    )
    $cmArgs = @('-S', $Script:RepoRoot, '-B', $Script:BuildDir,
              '-G', $Script:VsGenerator, '-A', 'x64',
              "-DCMAKE_INSTALL_PREFIX=$Script:DeployDir")
    if ($MysqlUrl) { $cmArgs += @("-DMYSQL_URL=$MysqlUrl") }
    Write-Log "Конфигурирую проект (первый раз CMake скачает Boost 1.67, TinyXML, UTF8CPP, ZLIB — ~150 МБ)..." 'INFO'
    $r = Invoke-LongCommand -FilePath $CMakeExe -Arguments $cmArgs -LogTag 'cmake_configure' -TimeoutSec 3600
    return $r
}

function Invoke-CMakeBuild {
    param([Parameter(Mandatory)][string]$CMakeExe)
    Write-Log "Собираю проект (MSVC, Release, x64). Это занимает 10-40 минут..." 'INFO'
    $r = Invoke-LongCommand -FilePath $CMakeExe `
        -Arguments @('--build', $Script:BuildDir, '--config', 'Release',
                     '--', '/m', '/v:m', '/nodeReuse:false') `
        -LogTag 'build' -TimeoutSec 0
    return $r
}

function Invoke-CMakeInstall {
    param([Parameter(Mandatory)][string]$CMakeExe)
    Write-Log "Устанавливаю собранные бинарники в $($Script:DeployDir)..." 'INFO'
    $r = Invoke-LongCommand -FilePath $CMakeExe `
        -Arguments @('--install', $Script:BuildDir, '--config', 'Release') `
        -LogTag 'cmake_install' -TimeoutSec 600
    return $r
}

#===============================================================================
# 14.1. ОСТАНОВКА РАБОТАЮЩЕГО EVE-SERVER И НАДЁЖНОЕ КОПИРОВАНИЕ
#      При повторном запуске деплой-скрипта работающий eve-server держит
#      занятыми deploy\bin\eve-server.exe и libmariadb.dll — сборка/установка/
#      публикация падают с «файл используется другим процессом». Поэтому перед
#      обновлением deploy\bin сервер останавливается (и вновь стартует на
#      этапе 14), а копирование файлов ведётся с ретраями (антивирус/медленное
#      освобождение дескрипторов могут кратко держать файл занятым).
#===============================================================================
function Stop-EveServer {
    # Останавливает eve-server, запущенный из папки проекта (чужие процессы
    # не трогаем — как и везде в скрипте, см. Get-OurProcess).
    # Возвращает $true, если процессов eve-server из папки проекта больше нет.
    $ours = @(Get-OurProcess -NamePattern 'eve-server.exe')
    if ($ours.Count -eq 0) { return $true }
    Write-Log "Найден работающий eve-server (PID: $($ours.ProcessId -join ',')) — останавливаю: он держит занятыми файлы deploy\bin, без этого обновление невозможно" 'WARN'
    foreach ($pr in $ours) {
        try { Stop-Process -Id $pr.ProcessId -Force -ErrorAction Stop } catch { }
    }
    # Даём процессу время фактически завершиться и освободить exe/DLL
    for ($i = 0; $i -lt 15; $i++) {
        if (@(Get-OurProcess -NamePattern 'eve-server.exe').Count -eq 0) {
            Start-Sleep -Seconds 1   # дескрипторы освобождаются не мгновенно
            return $true
        }
        Start-Sleep -Seconds 1
    }
    Write-Log "eve-server не завершился за 15 секунд — закройте его вручную и запустите скрипт снова" 'ERROR'
    return $false
}

function Copy-FileRetry {
    # Copy-Item с ретраями: цель в deploy\bin может быть кратковременно занята
    # (антивирус, дозакрывающийся процесс). Возвращает $true при успехе.
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Destination,
          [int]$Attempts = 3, [int]$DelaySec = 3)
    $leaf = Split-Path $Path -Leaf
    for ($try = 1; $try -le $Attempts; $try++) {
        try {
            Copy-Item -LiteralPath $Path -Destination $Destination -Force -ErrorAction Stop
            return $true
        } catch {
            if ($try -ge $Attempts) {
                Write-Log "Копирование $leaf не удалось (попытка $try/$Attempts): $($_.Exception.Message)" 'ERROR'
                return $false
            }
            Write-Log "Копирование $leaf не удалось (попытка $try/$Attempts), повтор через ${DelaySec}с: $($_.Exception.Message)" 'WARN'
            Start-Sleep -Seconds $DelaySec
        }
    }
    return $false
}

#===============================================================================
# 14.2. ОТДЕЛЬНАЯ КОНСОЛЬ ЛОГА СЕРВЕРА И ОСТАНОВКА ПО Ctrl+C
#       После успешного развёртывания сервер работает в фоне, а его живой
#       вывод показывается в отдельном окне консоли (Start-LogConsole).
#       Ctrl+C в окне скрипта останавливает сервер и БД: wait-цикл обёрнут в
#       try/finally (PowerShell выполняет finally при прерывании по Ctrl+C),
#       очистка — Invoke-DeployCleanup. Окно лога можно закрыть в любой момент,
#       на сервер это не влияет; маркер PID не даёт окнам-хвостам плодиться.
#===============================================================================
function Close-LogConsole {
    # Закрывает окно с логом сервера, если оно открыто (по маркеру PID|StartTime,
    # чтобы случайно не убить чужой процесс с переиспользованным PID).
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
    # Открывает отдельное окно PowerShell с живым хвостом лога сервера
    # (аналог tail -f: Get-Content -Wait). Предыдущее окно лога закрывается.
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
        # -EncodedCommand: устойчиво к кавычкам/кириллице (base64 UTF-16LE)
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

function Stop-MariaDb {
    # Останавливает НАШУ портативную MariaDB: сначала graceful shutdown через
    # mariadb-admin (корректный сброс буферов InnoDB), при зависании — kill.
    # Чужие mysqld не трогаются никогда (только процессы из папки проекта).
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
        $null = Invoke-External -FilePath $admin `
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

function Invoke-DeployCleanup {
    # Полная остановка всего, что было запущено развёртыванием: окно лога,
    # eve-server, MariaDB. Вызывается из finally при Ctrl+C (Wait-DeployRunning).
    param([int]$DbPort = 0)
    Write-Host ''
    Write-Log 'Ctrl+C: останавливаю консоль лога, eve-server и MariaDB...' 'INFO'
    Close-LogConsole
    if (-not (Stop-EveServer)) {
        Write-Log 'eve-server не удалось остановить штатно — проверьте процессы вручную (Get-Process eve-server)' 'WARN'
    }
    Stop-MariaDb -Port $DbPort | Out-Null
    Write-Log 'Остановка завершена' 'OK'
}

function Wait-DeployRunning {
    # Финальное ожидание после успешного развёртывания: сервер и БД работают,
    # окно ждёт Ctrl+C. finally срабатывает и на Ctrl+C, и на принудительный
    # останов конвейера — в нём и выполняется остановка сервисов.
    param([int]$DbPort)
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
        Invoke-DeployCleanup -DbPort $DbPort
    }
}

function Initialize-CmakeDepArchives {
    # Пре-загрузка архивов зависимостей cmake в каталог сборки (см. комментарий
    # у $Script:CmakeDeps). Неудача НЕ фатальна: cmake попробует скачать сам.
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

#===============================================================================
# 15. ПУБЛИКАЦИЯ РАБОЧЕГО ОКРУЖЕНИЯ СЕРВЕРА (DLL, конфиги, каталоги)
#===============================================================================
function Publish-Server {
    param([Parameter(Mandatory)][string]$VsPath, [Parameter(Mandatory)][int]$DbPort)

    $binDir  = Join-Path $Script:DeployDir 'bin'
    $etcDir  = Join-Path $Script:DeployDir 'etc'
    $exe     = Join-Path $binDir 'eve-server.exe'
    if (-not (Test-Path -LiteralPath $exe)) {
        Write-Log "Не найден $exe — сборка не выполнялась/не удалась" 'ERROR'
        return $false
    }
    Write-Log "eve-server.exe на месте: $exe ($([math]::Round((Get-Item -LiteralPath $exe).Length/1MB,1)) МБ)" 'OK'

    foreach ($d in @($etcDir, (Join-Path $Script:DeployDir 'logs'),
                     (Join-Path $Script:DeployDir 'server_cache'),
                     (Join-Path $Script:DeployDir 'image_cache'))) {
        if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    }

    # --- libmariadb.dll (обязательна для eve-server.exe) ---
    $dllSrc = Join-Path $Script:MariaDir "$($Script:Cfg.MariaTopDir)\lib\libmariadb.dll"
    if (Test-Path -LiteralPath $dllSrc) {
        if (Copy-FileRetry -Path $dllSrc -Destination $binDir) {
            Write-Log "libmariadb.dll скопирована в deploy\bin" 'OK'
        } else {
            return $false    # без этой DLL сервер не запустится
        }
    } elseif (-not (Test-Path -LiteralPath (Join-Path $binDir 'libmariadb.dll'))) {
        Write-Log "libmariadb.dll не найдена ни в MariaDB, ни в deploy\bin — сервер не запустится" 'ERROR'
        return $false
    }

    # --- Среда выполнения VC++ (vcruntime140.dll и пр.) ---
    $copied = 0
    if ($VsPath) {
        $crt = Get-ChildItem -Path (Join-Path $VsPath 'VC\Redist\MSVC') -Directory -ErrorAction SilentlyContinue |
               Sort-Object Name -Descending | Select-Object -First 1
        if ($crt) {
            $crtDir = Join-Path $crt.FullName 'x64'
            $dlls = Get-ChildItem -Path $crtDir -Filter '*.dll' -Recurse -ErrorAction SilentlyContinue |
                    Where-Object { $_.Directory.Name -match 'CRT' }
            $crtFailed = 0
            foreach ($d in $dlls) {
                if (Copy-FileRetry -Path $d.FullName -Destination $binDir) { $copied++ } else { $crtFailed++ }
            }
            if ($crtFailed -gt 0) {
                Write-Log "Не удалось скопировать $crtFailed DLL среды VC++ (файл занят?) — если сервер не запустится, закройте eve-server и повторите" 'WARN'
            }
        }
    }
    if ($copied -gt 0) {
        Write-Log "Среда выполнения VC++ скопирована в deploy\bin ($copied файлов)" 'OK'
    } else {
        $sysOk = Test-Path (Join-Path $env:SystemRoot 'System32\vcruntime140.dll')
        if ($sysOk) { Write-Log "VC redist не найден в VS, но vcruntime140.dll есть в System32 — ок" 'WARN' }
        else { Write-Log "VC redist не найден: при ошибке запуска сервера поставьте vc_redist.x64.exe" 'WARN' }
    }

    # --- Конфигурационные файлы ---
    $tplDir = Join-Path $Script:RepoRoot 'utils\config'
    foreach ($f in @('log.ini', 'MarketBot.xml', 'devtools.raw')) {
        $dst = Join-Path $etcDir $f
        if (-not (Test-Path -LiteralPath $dst)) {
            Copy-Item -LiteralPath (Join-Path $tplDir $f) -Destination $dst -Force
            Write-Log "Установлен конфиг: etc\$f" 'OK'
        }
    }
    # eve-server.xml: создаём/пересоздаём, если отсутствует или содержит плейсхолдеры
    $xmlDst = Join-Path $etcDir 'eve-server.xml'
    $needGen = $true
    if (Test-Path -LiteralPath $xmlDst) {
        $cur = Get-Content -LiteralPath $xmlDst -Raw
        if ($cur -notmatch 'database_(host|username|password|name|port)') { $needGen = $false }
    }
    if ($needGen) {
        $tpl = Get-Content -LiteralPath (Join-Path $tplDir 'eve-server.xml') -Raw
        $tpl = $tpl -replace 'database_host', '127.0.0.1'
        $tpl = $tpl -replace 'database_username', $Script:Cfg.DbUser
        $tpl = $tpl -replace 'database_password', $Script:Cfg.DbPass
        $tpl = $tpl -replace 'database_name', $Script:Cfg.DbName
        $tpl = $tpl -replace 'database_port', "$DbPort"
        Set-Content -LiteralPath $xmlDst -Value $tpl -Encoding UTF8
        Write-Log "etc\eve-server.xml сгенерирован (БД 127.0.0.1:$DbPort)" 'OK'
    } else {
        Write-Log "etc\eve-server.xml уже настроен — не трогаю" 'OK'
    }

    # devtools.raw ставится также через cmake install в etc — двойная копия не страшна
    Complete-Step 'Публикация сервера' 'bin, etc, dll, каталоги логов/кэшей'
    return $true
}

#===============================================================================
# 16. FIREWALL
#===============================================================================
function Set-FirewallRule {
    if ($NoFirewall) { Write-Log "Правило firewall пропущено (-NoFirewall)" 'WARN'; return }
    if (-not (Test-IsAdmin)) { Write-Log "Нет прав администратора — правило firewall не добавить" 'WARN'; return }
    $name = $Script:Cfg.FirewallRuleName
    $existing = (netsh advfirewall firewall show rule name="$name" 2>$null | Out-String)
    if ($existing -and ($existing -match '\S') -and ($existing -notmatch 'No rules match')) {
        Write-Log "Правило firewall '$name' уже существует" 'OK'
        return
    }
    $r = Invoke-External -FilePath 'netsh.exe' `
        -Arguments @('advfirewall', 'firewall', 'add', 'rule', "name=$name",
                     'dir=in', 'action=allow', 'protocol=TCP', "localport=$($Script:Cfg.ServerPort)-$($Script:Cfg.ImagePort)") `
        -LogTag 'firewall'
    if ($r.Code -eq 0) {
        Write-Log "Добавлено правило firewall: TCP $($Script:Cfg.ServerPort)-$($Script:Cfg.ImagePort) входящие" 'OK'
    } else {
        Write-Log "Не удалось добавить правило firewall (код $($r.Code)) — сервер будет доступен только локально" 'WARN'
    }
}

#===============================================================================
# 17. ЗАПУСК EVE-SERVER + ПРОВЕРКА ЗДОРОВЬЯ
#===============================================================================
function Start-EveServer {
    $binDir = Join-Path $Script:DeployDir 'bin'
    $exe    = Join-Path $binDir 'eve-server.exe'
    $port   = $Script:Cfg.ServerPort

    # Уже запущен и здоров?
    if (Test-TcpPort -Port $port) {
        $ours = @(Get-OurProcess -NamePattern 'eve-server.exe')
        if ($ours.Count -gt 0) {
            Write-Log "eve-server уже запущен (PID: $($ours[0].ProcessId)) и порт $port отвечает" 'OK'
            return $true
        }
        Write-Log "Порт $port занят СТОРОННИМ процессом (eve-server не запущен). Освободите порт или поменяйте <net><port> в deploy\etc\eve-server.xml" 'ERROR'
        return $false
    }
    # Зависший процесс без слушающего порта — убираем
    $stale = @(Get-OurProcess -NamePattern 'eve-server.exe')
    if ($stale.Count -gt 0) {
        Write-Log "Найден зависший eve-server (PID: $($stale.ProcessId -join ',')) — перезапускаю" 'WARN'
        foreach ($pr in $stale) { try { Stop-Process -Id $pr.ProcessId -Force -ErrorAction SilentlyContinue } catch { } }
        Start-Sleep -Seconds 2
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
        try { $null = $proc.Handle } catch { }   # фикс PS 5.1: иначе .ExitCode/.HasExited ненадёжны
        Write-Log "eve-server запущен, PID $($proc.Id)" 'DATA'
    } catch {
        Write-Log "Не удалось запустить eve-server: $($_.Exception.Message)" 'ERROR'
        Write-Log ("stderr:`n" + (Get-Tail $errLog 30)) 'DATA'
        return $false
    }

    # Ожидание порта (первый запуск загружает данные — до 5 минут)
    Write-Log "Ожидаю привязку порта $port (до 300 секунд)..." 'INFO'
    $up = $false
    for ($i = 1; $i -le 100; $i++) {
        if (Test-TcpPort -Port $port) { $up = $true; break }
        if ($proc.HasExited) {
            Write-Log "eve-server аварийно завершился с кодом $($proc.ExitCode)" 'ERROR'
            break
        }
        Start-Sleep -Seconds 3
    }
    if (-not $up) {
        Write-Log "Сервер не поднялся на порту $port. Вывод сервера (последние строки):" 'ERROR'
        Write-Log (Get-Tail $outLog 60) 'DATA'
        Write-Log (Get-Tail $errLog 20) 'DATA'
        return $false
    }
    Write-Log "Порт $port ПРИСЛУШИВАЕТСЯ (ожидал ${i} циклов)" 'OK'

    # Image-сервер (26001)
    $imgUp = $false
    for ($i = 1; $i -le 10; $i++) {
        if (Test-TcpPort -Port $Script:Cfg.ImagePort) { $imgUp = $true; break }
        if ($proc.HasExited) { break }
        Start-Sleep -Seconds 2
    }
    if ($imgUp) { Write-Log "Image-сервер на порту $($Script:Cfg.ImagePort) тоже работает" 'OK' }
    else { Write-Log "Порт $($Script:Cfg.ImagePort) не отвечает (сервер мог не успеть; см. логи)" 'WARN' }

    # Дать серверу 5 секунд и показать хвост его вывода
    Start-Sleep -Seconds 5
    Write-Log "---- Вывод eve-server (последние строки) ----" 'DATA'
    Write-Log (Get-Tail $outLog 25) 'DATA'
    return $true
}

#===============================================================================
# 18. ДИАГНОСТИЧЕСКИЙ СБОР (вызывается при сбое)
#===============================================================================
function Write-Diagnostics {
    try {
        Write-Log "==================== ДИАГНОСТИЧЕСКИЙ СБОР ====================" 'WARN'
        Write-Log ("Свободно места на диске проекта: " +
            "$(try { [math]::Round((Get-PSDrive (Split-Path $Script:RepoRoot -Qualifier).TrimEnd(':')).Free/1GB,1) } catch { '?' }) ГБ") 'DATA'
        Write-Log "Состояние портов: 3306=$(Test-TcpPort 3306) 3307=$(Test-TcpPort 3307) 26000=$(Test-TcpPort 26000) 26001=$(Test-TcpPort 26001)" 'DATA'
        $ours = @(Get-OurProcess)
        if ($ours.Count -gt 0) {
            foreach ($p in $ours) { Write-Log "Наш процесс: PID $($p.ProcessId) — $($p.Name) — $($p.ExecutablePath)" 'DATA' }
        } else { Write-Log "Процессов из папки проекта не запущено" 'DATA' }

        foreach ($lg in @('cmake_configure_out.log', 'build_out.log', 'cmake_install_out.log',
                          'mysql_install_db_out.log', 'evedbtool_out.log', 'evedb_up_out.log',
                          'seed_market_out.log', 'seed_market_err.log', 'db_scalar_out.log',
                          'eve-server_out.log', 'eve-server_err.log', 'vs_setup_out.log')) {
            $p2 = Join-Path $Script:LogDir $lg
            if (Test-Path -LiteralPath $p2) {
                Write-Log "---- ХВОСТ: $lg ----" 'DATA'
                Write-Log (Get-Tail $p2 40) 'DATA'
            }
        }
        $myErr = Join-Path $Script:LogDir 'mysqld.err'
        if (Test-Path -LiteralPath $myErr) {
            Write-Log "---- ХВОСТ: mysqld.err ----" 'DATA'
            Write-Log (Get-Tail $myErr 30) 'DATA'
        }
        $vswhere = Get-VsWhere
        if ($vswhere) {
            $null = Invoke-External -FilePath $vswhere -Arguments @('-all', '-prerelease', '-products', '*') -LogTag 'vswhere_diag'
        }
        Write-Log ("winget: " + $(if (Get-Command winget.exe -ErrorAction SilentlyContinue) { 'доступен' } else { 'недоступен' })) 'DATA'
        Write-Log "Логи установщика VS (если есть): $env:TEMP\dd_*.log; копия: $Script:LogDir\vs_installer\" 'DATA'

        # Архив для отправки разработчику. ВАЖНО: сначала копируем логи во
        # временную папку — часть файлов (mysqld.err, eve-server_out.log) открыта
        # работающими процессами, и Compress-Archive не может читать их напрямую;
        # для совсем заблокированных снимаем текстовую копию через Get-Content.
        $zip = Join-Path $Script:WinBuild 'evemu_deploy_logs.zip'
        $stage = Join-Path $Script:LogDir 'zip_stage'
        try {
            if (Test-Path -LiteralPath $stage) { Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue }
            New-Item -ItemType Directory -Path $stage -Force | Out-Null
            $srcFiles = @(Get-ChildItem -LiteralPath $Script:LogDir -File -ErrorAction SilentlyContinue |
                          Select-Object -First 60)
            $srvLogs = Join-Path $Script:DeployDir 'logs'
            if (Test-Path -LiteralPath $srvLogs) {
                $srcFiles += @(Get-ChildItem -LiteralPath $srvLogs -File -ErrorAction SilentlyContinue |
                               Sort-Object LastWriteTime -Descending | Select-Object -First 5)
            }
            foreach ($f in $srcFiles) {
                if (-not $f -or -not (Test-Path -LiteralPath $f.FullName)) { continue }
                $dst = Join-Path $stage $f.Name
                try {
                    Copy-Item -LiteralPath $f.FullName -Destination $dst -Force -ErrorAction Stop
                } catch {
                    try {
                        $text = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction Stop
                        Set-Content -LiteralPath $dst -Value $text -Encoding UTF8
                    } catch { Write-Log "Не удалось включить в архив $($f.Name): $($_.Exception.Message)" 'WARN' }
                }
            }
            # Снимок полного лога установки, лежащего рядом со скриптом
            if ($Script:InstallLog -and (Test-Path -LiteralPath $Script:InstallLog)) {
                try {
                    $dst = Join-Path $stage 'deploy_install_snapshot.log'
                    Copy-Item -LiteralPath $Script:InstallLog -Destination $dst -Force -ErrorAction Stop
                } catch {
                    try { Set-Content -LiteralPath $dst -Value (Get-Content -LiteralPath $Script:InstallLog -Raw) -Encoding UTF8 } catch { }
                }
            }
            $stageItems = @(Get-ChildItem -LiteralPath $stage -File -ErrorAction SilentlyContinue)
            if ($stageItems.Count -gt 0) {
                Compress-Archive -Path $stageItems.FullName -DestinationPath $zip -Force -ErrorAction Stop
                Write-Log "Диагностический архив создан: $zip ($([math]::Round((Get-Item -LiteralPath $zip).Length/1KB,0)) КБ, файлов: $($stageItems.Count))" 'OK'
            } else {
                Write-Log "Нет файлов для диагностического архива" 'WARN'
            }
        } catch {
            Write-Log "Не удалось собрать архив логов: $($_.Exception.Message)" 'WARN'
        } finally {
            Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue
        }
        Write-Log "ЧТО ОТПРАВИТЬ ДЛЯ ДИАГНОСТИКИ: 1) $(if ($Script:InstallLog) { $Script:InstallLog } else { 'deploy_install.log (не создан)' }) — полный лог рядом со скриптом; 2) $zip — архив с деталями" 'WARN'
        Write-Log "==================== КОНЕЦ ДИАГНОСТИКИ ====================" 'WARN'
    } catch {
        Write-Log "Сбой внутри сбор диагностики: $($_.Exception.Message)" 'WARN'
    }
}

#===============================================================================
# 19. ИТОГОВАЯ СВОДКА
#===============================================================================
function Write-FinalSummary {
    param([Parameter(Mandatory)][int]$DbPort)
    $info = @()
    $info += "+--------------------------------------------------------------------------+"
    $info += "|                     EVEMU РАЗВЁРНУТ И РАБОТАЕТ                          |"
    $info += "+--------------------------------------------------------------------------+"
    $tcpMain = if (Test-TcpPort 26000) { 'ОТКРЫТ' } else { 'ЗАКРЫТ' }
    $tcpImg  = if (Test-TcpPort $Script:Cfg.ImagePort) { 'ОТКРЫТ' } else { 'ЗАКРЫТ' }
    $info += "  Сервер (MachoNet) : порт 26000 — $tcpMain"
    $info += "  Image-сервер      : порт $($Script:Cfg.ImagePort) — $tcpImg"
    $info += "  База данных       : MariaDB на 127.0.0.1:$DbPort, база '$($Script:Cfg.DbName)'"
    $info += ("  Учётные данные БД : пользователь '$($Script:Cfg.DbUser)', пароль '$($Script:Cfg.DbPass)'")
    $mkt = Get-DbScalar -Sql "SELECT COUNT(*) FROM $($Script:Cfg.DbName).mktOrders;" -Port $DbPort
    if ($null -ne $mkt -and $mkt -match '^\d+$') {
        # Маркер сида живёт в БД (deployMarketSeed) — по нему и показываем статус
        $mktSeeded = $null
        $mkExists = Get-DbScalar -Sql "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='$($Script:Cfg.DbName)' AND table_name='deployMarketSeed';" -Port $DbPort
        if ("$mkExists" -eq '1') {
            $mktSeeded = Get-DbScalar -Sql "SELECT CONCAT(regionID, '|', orders) FROM $($Script:Cfg.DbName).deployMarketSeed WHERE marker='market';" -Port $DbPort
        }
        $seedNote = "сид ещё НЕ выполнялся — при следующем запуске скрипта будет выполнен"
        if ($mktSeeded -and $mktSeeded -match '^(\d+)\|(\d+)$') {
            $seedNote = "засеян regionID=$($Matches[1]), стартовых ордеров: $($Matches[2]); данные не перезатираются"
        }
        $info += ("  Рынок            : $mkt ордеров в mktOrders ($seedNote)")
    } else {
        $info += ("  Рынок            : состояние mktOrders не определено (проверьте вручную: SELECT COUNT(*) FROM mktOrders;)")
    }
    $info += ("  Исполняемый файл  : $Script:DeployDir\bin\eve-server.exe")
    $info += ("  Конфигурация      : $Script:DeployDir\etc\eve-server.xml")
    $info += ("  Логи сервера      : $Script:DeployDir\logs\ и $Script:LogDir\eve-server_out.log")
    $info += ("  Аккаунты          : создаются автоматически при входе клиента")
    $info += ""
    $info += "  УПРАВЛЕНИЕ:"
    $pids = (Get-OurProcess | ForEach-Object { $_.ProcessId }) -join ', '
    $info += "   • Остановить всё :  Ctrl+C в этом окне (аварийно: Stop-Process -Id $pids -Force)"
    $info += "   • Запустить снова:  повторно запустите этот скрипт или build_and_run.bat (пересборка)"
    $info += "   • Клиент с другого ПК: поменяйте <imageServer> в eve-server.xml на IP машины"
    $info += ""
    $info += ("  Пройденные этапы ($($Script:StageOk.Count)): " + ($Script:StageOk -join ' -> '))
    $banner = $info -join [Environment]::NewLine
    Write-Host $banner -ForegroundColor Green
    Add-Content -LiteralPath $Script:MasterLog -Value $banner -Encoding UTF8
    # Сохраняем памятку
    Set-Content -LiteralPath (Join-Path $Script:WinBuild 'SERVER_INFO.txt') -Value $banner -Encoding UTF8
}

#===============================================================================
# 20. ГЛАВНЫЙ ПОТОК
#===============================================================================
function Main {
    Initialize-Logging

    # --- Права администратора ---
    $elev = Request-Elevation
    if ($null -eq $elev) { exit 0 }        # перезапущены с UAC, этот экземпляр завершаем
    $isAdmin = [bool]$elev

    Write-Step '1/14. Окружение'
    $freeGb = Show-Environment
    if ($freeGb -lt 10) {
        Fail-Stage 'Окружение' $Script:ExitCode.Env "Недостаточно места на диске (${freeGb} ГБ). Освободите минимум 15 ГБ."
    }
    $null = Test-Network
    Enable-LongPaths
    Complete-Step 'Окружение' "место ${freeGb} ГБ, сеть проверена"

    Write-Step '2/14. Исходные коды проекта'
    if (-not (Assert-Sources)) {
        Fail-Stage 'Исходники' $Script:ExitCode.Sources "Исходники evemu_Crucible не найдены и не скачались. Проверьте доступ к github.com."
    }
    Complete-Step 'Исходники'

    Write-Step '3/14. VS Build Tools (компилятор MSVC)'
    $vs = Get-ExistingVs
    if (-not $vs) { $vs = Install-VsBuildTools $null }
    if (-not $vs) {
        Fail-Stage 'VS Build Tools' $Script:ExitCode.VsBuildTools "Не удалось установить VS Build Tools 2022. Подробности в логе и $env:TEMP\dd_*.log"
    }
    $vsPath = $vs.Path
    $Script:VsGenerator = $vs.Generator
    Write-Log "Компилятор: $vsPath — генератор CMake '$($vs.Generator)'" 'DATA'
    Complete-Step 'VS Build Tools' "$vsPath [генератор: $($vs.Generator)]"

    Write-Step '4/14. CMake'
    $cmakeExe = Resolve-CMake -VsPath $vsPath
    if (-not $cmakeExe) {
        Fail-Stage 'CMake' $Script:ExitCode.CMake "Не удалось найти/скачать подходящий CMake ($($Script:Cfg.CmakeMinVer) <= версия < 4.0)."
    }
    Complete-Step 'CMake' $cmakeExe

    Write-Step '5/14. MariaDB (портативная, внутри проекта)'
    if (-not (Initialize-MariaDbFiles)) {
        Fail-Stage 'MariaDB' $Script:ExitCode.MariaSetup "Не удалось скачать/распаковать MariaDB. Проверьте доступ к archive.mariadb.org."
    }
    Complete-Step 'MariaDB (файлы)'

    Write-Step '6/14. Порт и конфиг БД'
    $dbPort = Resolve-DbPort
    $ini = Write-MariaIni -Port $dbPort
    Complete-Step 'Порт БД' "$dbPort"

    Write-Step '7/14. Каталог данных БД'
    if (-not (Initialize-MariaData -IniPath $ini)) {
        Fail-Stage 'Каталог данных БД' $Script:ExitCode.MariaSetup "Инициализация данных MariaDB не удалась (см. mysql_install_db_out.log, mysqld.err)."
    }
    Complete-Step 'Каталог данных БД'

    Write-Step '8/14. Запуск MariaDB'
    if (-not (Start-MariaDb -IniPath $ini -Port $dbPort)) {
        Fail-Stage 'Запуск MariaDB' $Script:ExitCode.MariaStart "MariaDB не запустилась. Журнал: .winbuild\logs\mysqld.err"
    }
    Complete-Step 'MariaDB запущена' "порт $dbPort"

    Write-Step '9/14. База и пользователь evemu'
    if (-not (Initialize-DbUser -Port $dbPort)) {
        Fail-Stage 'БД/пользователь' $Script:ExitCode.MariaStart "Не удалось создать базу/пользователя evemu (см. sql_exec_*.log)."
    }
    Complete-Step 'БД и пользователь'

    Write-Step '10/14. Схема БД EVEmu (EVEDBTool)'
    $evedbtool = Get-EveDbTool
    if (-not $evedbtool) {
        Fail-Stage 'EVEDBTool' $Script:ExitCode.Schema "Не удалось скачать evedbtool.exe с GitHub."
    }
    if (-not (Initialize-DbSchema -EveDbTool $evedbtool -Port $dbPort)) {
        Fail-Stage 'Схема БД' $Script:ExitCode.Schema "Установка схемы БД не удалась (см. evedbtool_out.log)."
    }

    Write-Step '11/14. Сид рынка EVEmu (seed_market.sql)'
    if (-not (Initialize-MarketSeed -Port $dbPort)) {
        Fail-Stage 'Сид рынка' $Script:ExitCode.MarketSeed "Не удалось засеять рынок ордерами (см. seed_market_out.log, db_scalar_out.log)."
    }

    # Работающий eve-server держит exe/DLL в deploy\bin занятыми — без
    # остановки обновление (сборка/установка/публикация) падает с ошибкой
    # «файл используется другим процессом». Сервер вновь стартует на этапе 14.
    if (-not (Stop-EveServer)) {
        Fail-Stage 'Остановка сервера' $Script:ExitCode.Publish "Не удалось остановить работающий eve-server — файлы deploy\bin недоступны для обновления."
    }

    if (-not $SkipBuild) {
        Write-Step '12/14. Сборка (CMake + MSVC)'
        # Локальный zip MariaDB передаём CMake как file:// чтобы не качать повторно;
        # при сбое — ретрай с прямым URL.
        $mzip = Join-Path $Script:DownloadDir 'mariadb-11.4.5-winx64.zip'
        $mysqlUrl = $null
        if ((Get-Md5 $mzip) -eq $Script:Cfg.MariaMd5) { $mysqlUrl = ConvertTo-FileUrl $mzip }

        # Архивы зависимостей (Boost/TinyXML/zlib/utf8cpp) пре-загружаем надёжным
        # даунлоадером: собственный DOWNLOAD у cmake не имеет ретраёв, и именно
        # на нём configure падал при сетевых сбоях ("Configuring incomplete").
        Initialize-CmakeDepArchives

        # До 3 попыток configure: сбои почти всегда связаны с разовой загрузкой
        # зависимостей и проходят при повторе. Третья попытка — без file://-URL
        # MariaDB (на случай повреждённого локального архива).
        $r = Invoke-CMakeConfigure -CMakeExe $cmakeExe -MysqlUrl $mysqlUrl
        $cfgTry = 1
        while ($r.Code -ne 0 -and $cfgTry -lt 3) {
            $cfgTry++
            $retryUrl = $mysqlUrl
            if ($cfgTry -ge 3) { $retryUrl = $null }
            Write-Log "Configure не удался (код $($r.Code)) — попытка $cfgTry/3" 'WARN'
            $r = Invoke-CMakeConfigure -CMakeExe $cmakeExe -MysqlUrl $retryUrl
        }
        if ($r.Code -ne 0) {
            Write-Log (Get-Tail (Join-Path $Script:LogDir 'cmake_configure_out.log') 60) 'DATA'
            Fail-Stage 'CMake configure' $Script:ExitCode.Configure "cmake configure вернул код $($r.Code). Полный лог: cmake_configure_out.log"
        }
        Complete-Step 'CMake configure'

        $r = Invoke-CMakeBuild -CMakeExe $cmakeExe
        if ($r.Code -ne 0) {
            Write-Log (Get-Tail (Join-Path $Script:LogDir 'build_out.log') 60) 'DATA'
            Fail-Stage 'Сборка' $Script:ExitCode.Build "Сборка не удалась (код $($r.Code)). Полный лог: build_out.log"
        }
        Complete-Step 'Сборка (MSVC)'

        $r = Invoke-CMakeInstall -CMakeExe $cmakeExe
        if ($r.Code -ne 0) {
            Write-Log (Get-Tail (Join-Path $Script:LogDir 'cmake_install_out.log') 40) 'DATA'
            Fail-Stage 'Установка' $Script:ExitCode.Install "cmake --install вернул код $($r.Code)"
        }
        Complete-Step 'Установка в deploy\'
    } else {
        Write-Log 'Сборка пропущена (-SkipBuild)' 'WARN'
    }

    Write-Step '13/14. Публикация окружения сервера'
    if (-not (Publish-Server -VsPath $vsPath -DbPort $dbPort)) {
        Fail-Stage 'Публикация' $Script:ExitCode.Publish "Не удалось подготовить deploy\\ (DLL/конфиги)."
    }

    Set-FirewallRule

    Write-Step '14/14. Запуск eve-server'
    if (-not (Start-EveServer)) {
        Fail-Stage 'Запуск сервера' $Script:ExitCode.ServerRun "Сервер не запустился или не слушает порт 26000. Смотрите eve-server_out.log и deploy\logs\."
    }
    Complete-Step 'eve-server работает'

    Write-FinalSummary -DbPort $dbPort
    if ($NoPause) {
        # Режим автоматизации: выходим сразу, сервер и БД продолжают работать
        try { Stop-Transcript | Out-Null } catch { }
        exit 0
    }
    # Живой лог сервера в отдельной консоли + ожидание Ctrl+C (остановка всего)
    Start-LogConsole -Title 'EVEmu server log' -LogFile (Join-Path $Script:LogDir 'eve-server_out.log')
    Wait-DeployRunning -DbPort $dbPort
    try { Stop-Transcript | Out-Null } catch { }
    exit 0
}

#===============================================================================
# ТОЧКА ВХОДА
#===============================================================================
try {
    Main
} catch {
    $msg = "НЕПРЕДВИДЕННАЯ ОШИБКА: $($_.Exception.Message)`n$($_.ScriptStackTrace)"
    try { Write-Log $msg 'ERROR' } catch { Write-Host $msg -ForegroundColor Red }
    try { Write-Diagnostics } catch { }
    Write-Host ''
    Write-Host ('!' * 78) -ForegroundColor Red
    Write-Host '  НЕПРЕДВИДЕННАЯ ОШИБКА — весь вывод сохранён в лог установки' -ForegroundColor Red
    Write-Host ('!' * 78) -ForegroundColor Red
    Wait-BeforeExit 'Скрипт аварийно остановился. Лог сохранён — пришлите его для диагностики.'
    try { Stop-Transcript | Out-Null } catch { }
    exit $Script:ExitCode.Unexpected
}
