<#
.SYNOPSIS
    HolyConnect v1.0.4 - Pi-Star USB Tethering for Windows
.DESCRIPTION
    Automatically connects to a Pi-Star MMDVM hotspot via USB cable.
    Detects Pi, installs RNDIS driver if needed, configures networking,
    shares internet via NAT, and opens the Pi-Star dashboard.

    Designed for Windows 10/11 PCs. Run as Administrator.
.PARAMETER NoNAT
    Skip internet sharing (Pi-Star works but can't reach reflectors)
.PARAMETER NoBrowser
    Don't open browser at the end
.PARAMETER InternetAdapterName
    Optional adapter name override for unusual Windows networking setups
.PARAMETER ExportDiagnostics
    Generate an exportable diagnostics package at the end of the run
.PARAMETER DiagnosticsPath
    Optional diagnostics output directory. Defaults to windows\diagnostics with local fallbacks
.PARAMETER LogPath
    Optional log file path. Defaults to windows\logs with local fallbacks
.PARAMETER Lang
    Language: 'pt' for Portuguese, 'en' for English (auto-detected from system)
.LINK
    https://github.com/WoWHellgarve-HolyDeeW/holyconnect
#>

param(
    [switch]$NoNAT,
    [switch]$NoBrowser,
    [string]$InternetAdapterName,
    [switch]$ExportDiagnostics,
    [string]$DiagnosticsPath,
    [string]$LogPath,
    [ValidateSet('pt','en')][string]$Lang
)

$ErrorActionPreference = "Continue"
$Host.UI.RawUI.WindowTitle = "HolyConnect"
$HOLYCONNECT_VERSION = "1.0.4"
$HOLYCONNECT_HOST_IP = "192.168.7.1"
$HOLYCONNECT_PI_IP = "192.168.7.2"
$HOLYCONNECT_NAT_PREFIX = "192.168.7.0/24"
$PING = Join-Path $env:SystemRoot "System32\ping.exe"
$PNPUTIL = Join-Path $env:SystemRoot "System32\pnputil.exe"
$DEVMGMT = Join-Path $env:SystemRoot "System32\devmgmt.msc"

# ============================================
#  LANGUAGE
# ============================================
if (-not $Lang) {
    $sysLang = (Get-Culture).TwoLetterISOLanguageName
    $Lang = if ($sysLang -eq 'pt') { 'pt' } else { 'en' }
}

$T = @{}
if ($Lang -eq 'pt') {
    $T.AdminRequired     = "PRECISA CORRER COMO ADMINISTRADOR!"
    $T.AdminHint         = "Clica direito -> 'Executar como Administrador'"
    $T.LogEnabled        = "Logs guardados em {0}"
    $T.LogLabel          = "Log"
    $T.DiagnosticsLabel  = "Diagnostico"
    $T.DiagnosticsReady  = "Pacote de diagnostico guardado em {0}"
    $T.DiagnosticsFailed = "Nao foi possivel gerar o pacote de diagnostico exportavel."
    $T.Step1             = "A procurar dispositivo Pi USB..."
    $T.PlugIn            = "Liga o Pi ao PC pelo cabo USB (porta DATA, nao PWR)"
    $T.BootWait          = "O Pi demora ~60-90 seg a arrancar..."
    $T.Waiting           = "Aguardando"
    $T.NotDetected       = "Pi nao detetado apos {0} segundos."
    $T.CheckCable        = "Verifica cabo USB e porta (DATA, nao PWR)"
    $T.Detected          = "Detetado"
    $T.AlreadyConnected  = "Ja ligado"
    $T.Step2             = "A verificar driver de rede RNDIS..."
    $T.DriverOK          = "Driver OK"
    $T.DriverNotFound    = "O Windows nao reconheceu como placa de rede."
    $T.DriverAutoInstall = "A tentar instalar driver automaticamente..."
    $T.DriverInfMissing  = "Nenhum driver RNDIS built-in foi encontrado neste Windows."
    $T.DriverRestarting  = "A reiniciar dispositivo para forcar detecao..."
    $T.DriverManualTitle = "INSTALACAO MANUAL DO DRIVER (so precisa 1 vez)"
    $T.DriverManualOpen  = "O Gestor de Dispositivos vai abrir agora."
    $T.DriverManualStep1 = "PASSO 1: Encontra o dispositivo"
    $T.DriverManualFind  = "Procura em 'Portas (COM e LPT)' ou 'Outros dispositivos'"
    $T.DriverManualStep2 = "PASSO 2: Muda o driver"
    $T.DriverManualClick = "Clica direito -> 'Atualizar controlador'"
    $T.DriverManualBrowse= "-> 'Procurar software no computador'"
    $T.DriverManualList  = "-> 'Permitir escolha a partir de uma lista'"
    $T.DriverManualStep3 = "PASSO 3: Seleciona o driver"
    $T.DriverManualUncheck="Desmarca 'Mostrar hardware compativel'"
    $T.DriverManualMfr   = "Fabricante:  Microsoft"
    $T.DriverManualModel = "Modelo:      Remote NDIS Compatible Device"
    $T.DriverManualNext  = "-> Seguinte -> Sim (confirmar aviso)"
    $T.DriverManualDone  = "Prima ENTER depois de instalar o driver..."
    $T.DriverFailed      = "Adaptador RNDIS nao apareceu."
    $T.DriverRetry       = "Tenta desligar/religar o cabo USB e correr de novo."
    $T.DriverInstalled   = "Driver instalado"
    $T.Activating        = "A ativar adaptador..."
    $T.Step3             = "A configurar IP na interface USB..."
    $T.IPSet             = "IP configurado"
    $T.IPCurrent         = "IP actual"
    $T.IPError           = "Erro ao configurar IP"
    $T.PiReachable       = "Pi-Star ja acessivel em {0}"
    $T.Step4             = "A configurar partilha de internet (NAT)..."
    $T.NATDisabled       = "NAT desativado (parametro -NoNAT)"
    $T.NoInternet        = "Nenhuma ligacao a internet detetada."
    $T.NoInternetHint    = "O Pi-Star funciona sem internet, mas nao liga a reflectores."
    $T.InternetVia       = "Internet via"
    $T.NATActive         = "NAT ativado - Pi tera internet"
    $T.NATExists         = "NAT ja estava ativo"
    $T.NATUnavailable    = "Os cmdlets NetNat nao estao disponiveis neste Windows."
    $T.NATUnavailableHint= "O Pi-Star continua acessivel por USB, mas sem partilha de internet automatica."
    $T.NATReuseExisting  = "A reutilizar NAT existente: {0}"
    $T.NATConflict       = "Nao foi possivel criar NAT seguro"
    $T.NATConflictHint   = "O HolyConnect nao alterou outras regras NAT. O Pi-Star fica acessivel por USB; para internet, liberta a subnet 192.168.7.0/24 ou usa -NoNAT."
    $T.AdapterOverrideFailed = "Adaptador pedido nao encontrado ou sem rota default: {0}"
    $T.Step5             = "A procurar Pi-Star na rede..."
    $T.Attempt           = "Tentativa"
    $T.Step6             = "Resultado final"
    $T.Success           = "SUCESSO! Pi-Star esta operacional!"
    $T.PiIP              = "IP do Pi-Star"
    $T.Dashboard         = "Dashboard"
    $T.Password          = "Password"
    $T.Internet          = "Internet"
    $T.SharedViaNAT      = "Partilhada via NAT"
    $T.OpeningBrowser    = "A abrir browser..."
    $T.NotFound          = "Pi-Star nao encontrado na rede"
    $T.NotFoundCause1    = "Pi ainda a arrancar (espera 1-2 min)"
    $T.NotFoundCause2    = "Cabo USB na porta errada (usar DATA, nao PWR)"
    $T.NotFoundCause3    = "Pi nao arrancou (LED verde deve piscar)"
    $T.TryManually       = "Tenta manualmente no browser:"
    $T.PressKey          = "Prima qualquer tecla para sair..."
} else {
    $T.AdminRequired     = "MUST RUN AS ADMINISTRATOR!"
    $T.AdminHint         = "Right-click -> 'Run as Administrator'"
    $T.LogEnabled        = "Logs saved to {0}"
    $T.LogLabel          = "Log"
    $T.DiagnosticsLabel  = "Diagnostics"
    $T.DiagnosticsReady  = "Diagnostics package saved to {0}"
    $T.DiagnosticsFailed = "Could not generate an exportable diagnostics package."
    $T.Step1             = "Searching for Pi USB device..."
    $T.PlugIn            = "Connect Pi to PC via USB cable (DATA port, not PWR)"
    $T.BootWait          = "Pi takes ~60-90 sec to boot..."
    $T.Waiting           = "Waiting"
    $T.NotDetected       = "Pi not detected after {0} seconds."
    $T.CheckCable        = "Check USB cable and port (DATA, not PWR)"
    $T.Detected          = "Detected"
    $T.AlreadyConnected  = "Already connected"
    $T.Step2             = "Checking RNDIS network driver..."
    $T.DriverOK          = "Driver OK"
    $T.DriverNotFound    = "Windows didn't recognize it as a network adapter."
    $T.DriverAutoInstall = "Trying to install driver automatically..."
    $T.DriverInfMissing  = "No built-in RNDIS driver INF was found on this Windows install."
    $T.DriverRestarting  = "Restarting device to force detection..."
    $T.DriverManualTitle = "MANUAL DRIVER INSTALL (only needed once)"
    $T.DriverManualOpen  = "Device Manager will open now."
    $T.DriverManualStep1 = "STEP 1: Find the device"
    $T.DriverManualFind  = "Look under 'Ports (COM & LPT)' or 'Other devices'"
    $T.DriverManualStep2 = "STEP 2: Change the driver"
    $T.DriverManualClick = "Right-click -> 'Update driver'"
    $T.DriverManualBrowse= "-> 'Browse my computer for drivers'"
    $T.DriverManualList  = "-> 'Let me pick from a list'"
    $T.DriverManualStep3 = "STEP 3: Select the driver"
    $T.DriverManualUncheck="Uncheck 'Show compatible hardware'"
    $T.DriverManualMfr   = "Manufacturer:  Microsoft"
    $T.DriverManualModel = "Model:         Remote NDIS Compatible Device"
    $T.DriverManualNext  = "-> Next -> Yes (confirm warning)"
    $T.DriverManualDone  = "Press ENTER after installing the driver..."
    $T.DriverFailed      = "RNDIS adapter not found."
    $T.DriverRetry       = "Try unplugging/replugging the USB cable and run again."
    $T.DriverInstalled   = "Driver installed"
    $T.Activating        = "Activating adapter..."
    $T.Step3             = "Configuring IP on USB interface..."
    $T.IPSet             = "IP configured"
    $T.IPCurrent         = "Current IP"
    $T.IPError           = "Error configuring IP"
    $T.PiReachable       = "Pi-Star already reachable at {0}"
    $T.Step4             = "Configuring internet sharing (NAT)..."
    $T.NATDisabled       = "NAT disabled (-NoNAT parameter)"
    $T.NoInternet        = "No internet connection detected."
    $T.NoInternetHint    = "Pi-Star works without internet, but can't reach reflectors."
    $T.InternetVia       = "Internet via"
    $T.NATActive         = "NAT active - Pi will have internet"
    $T.NATExists         = "NAT was already active"
    $T.NATUnavailable    = "NetNat cmdlets are not available on this Windows version."
    $T.NATUnavailableHint= "Pi-Star will still work over USB, but automatic internet sharing is skipped."
    $T.NATReuseExisting  = "Reusing existing NAT: {0}"
    $T.NATConflict       = "Could not create a safe NAT rule"
    $T.NATConflictHint   = "HolyConnect did not change other NAT rules. Pi-Star stays reachable over USB; for internet, free subnet 192.168.7.0/24 or use -NoNAT."
    $T.AdapterOverrideFailed = "Requested adapter not found or has no default route: {0}"
    $T.Step5             = "Searching for Pi-Star on network..."
    $T.Attempt           = "Attempt"
    $T.Step6             = "Final result"
    $T.Success           = "SUCCESS! Pi-Star is operational!"
    $T.PiIP              = "Pi-Star IP"
    $T.Dashboard         = "Dashboard"
    $T.Password          = "Password"
    $T.Internet          = "Internet"
    $T.SharedViaNAT      = "Shared via NAT"
    $T.OpeningBrowser    = "Opening browser..."
    $T.NotFound          = "Pi-Star not found on network"
    $T.NotFoundCause1    = "Pi still booting (wait 1-2 min)"
    $T.NotFoundCause2    = "USB cable on wrong port (use DATA, not PWR)"
    $T.NotFoundCause3    = "Pi didn't boot (green LED should blink)"
    $T.TryManually       = "Try manually in browser:"
    $T.PressKey          = "Press any key to exit..."
}

# ============================================
#  HELPERS
# ============================================
$script:LogPath = $null
$script:DiagnosticsPackagePath = $null
$script:RunStartedAt = Get-Date
$script:LastOutcomeReason = $null

function Initialize-Log {
    param([string]$RequestedPath)

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $defaultName = "holyconnect_${timestamp}_$($env:COMPUTERNAME).log"
    $candidates = [System.Collections.Generic.List[string]]::new()

    if ($RequestedPath) {
        $candidates.Add($RequestedPath)
    } else {
        $candidates.Add((Join-Path (Join-Path $PSScriptRoot "logs") $defaultName))
        if ($env:ProgramData) {
            $candidates.Add((Join-Path (Join-Path $env:ProgramData "HolyConnect\logs") $defaultName))
        }
        if ($env:TEMP) {
            $candidates.Add((Join-Path (Join-Path $env:TEMP "HolyConnect") $defaultName))
        }
    }

    foreach ($candidate in $candidates) {
        try {
            $dir = Split-Path -Parent $candidate
            if ($dir -and -not (Test-Path $dir)) {
                New-Item -ItemType Directory -Path $dir -Force -ErrorAction Stop | Out-Null
            }
            Set-Content -Path $candidate -Value @("HolyConnect log", "") -Encoding UTF8 -ErrorAction Stop
            $script:LogPath = $candidate
            return $candidate
        } catch {}
    }

    return $null
}

function Initialize-DiagnosticsRoot {
    param([string]$RequestedPath)

    $candidates = [System.Collections.Generic.List[string]]::new()
    if ($RequestedPath) {
        $candidates.Add($RequestedPath)
    } else {
        $candidates.Add((Join-Path $PSScriptRoot "diagnostics"))
        if ($env:ProgramData) {
            $candidates.Add((Join-Path $env:ProgramData "HolyConnect\diagnostics"))
        }
        if ($env:TEMP) {
            $candidates.Add((Join-Path $env:TEMP "HolyConnect\diagnostics"))
        }
    }

    foreach ($candidate in $candidates) {
        try {
            if (-not (Test-Path $candidate)) {
                New-Item -ItemType Directory -Path $candidate -Force -ErrorAction Stop | Out-Null
            }
            $probe = Join-Path $candidate ".holyconnect_write_test"
            Set-Content -Path $probe -Value "ok" -Encoding UTF8 -ErrorAction Stop
            Remove-Item $probe -Force -ErrorAction SilentlyContinue
            return $candidate
        } catch {}
    }

    return $null
}

function Write-Log($level, $msg) {
    if (-not $script:LogPath -or [string]::IsNullOrWhiteSpace($msg)) { return }

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    foreach ($line in ($msg -replace "`r", "" -split "`n")) {
        if (-not [string]::IsNullOrWhiteSpace($line)) {
            Add-Content -Path $script:LogPath -Value "[$timestamp] [$level] $line" -Encoding UTF8 -ErrorAction SilentlyContinue
        }
    }
}

function Write-Step($n, $t, $msg) { Write-Log 'STEP' "[$n/$t] $msg"; Write-Host "`n[$n/$t] $msg" -ForegroundColor Yellow }
function Write-OK($msg)   { Write-Log 'OK' $msg; Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Info($msg)  { Write-Log 'INFO' $msg; Write-Host "  $msg" -ForegroundColor Gray }
function Write-Warn($msg)  { Write-Log 'WARN' $msg; Write-Host "  [!] $msg" -ForegroundColor DarkYellow }
function Write-Fail($msg)  { Write-Log 'FAIL' $msg; Write-Host "  [X] $msg" -ForegroundColor Red }

function Export-TextDiagnostic {
    param(
        [string]$PackageDir,
        [string]$FileName,
        [scriptblock]$ScriptBlock
    )

    $path = Join-Path $PackageDir $FileName
    try {
        $text = & $ScriptBlock | Out-String -Width 4096
        if (-not $text) { $text = "(no output)" }
        Set-Content -Path $path -Value $text -Encoding UTF8 -ErrorAction Stop
    } catch {
        Set-Content -Path $path -Value "ERROR: $($_.Exception.Message)" -Encoding UTF8 -ErrorAction SilentlyContinue
    }
}

function Export-DiagnosticsPackage {
    param(
        [int]$ExitCode,
        [string]$Reason
    )

    $root = Initialize-DiagnosticsRoot -RequestedPath $DiagnosticsPath
    if (-not $root) {
        Write-Log 'WARN' $T.DiagnosticsFailed
        return $null
    }

    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $packageName = "holyconnect_diagnostics_${timestamp}"
    $packageDir = Join-Path $root $packageName

    try {
        New-Item -ItemType Directory -Path $packageDir -Force -ErrorAction Stop | Out-Null
    } catch {
        Write-Log 'WARN' "Failed to create diagnostics directory: $($_.Exception.Message)"
        return $null
    }

    $result = if ($ExitCode -eq 0) { 'success' } elseif ($ExitCode -eq 2) { 'partial-failure' } else { 'failure' }
    $summaryLines = [System.Collections.Generic.List[string]]::new()
    $summaryLines.Add("HolyConnect Diagnostics Package")
    $summaryLines.Add("Version: $HOLYCONNECT_VERSION")
    $summaryLines.Add("Created: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')")
    $summaryLines.Add("Result: $result")
    $summaryLines.Add("ExitCode: $ExitCode")
    $summaryLines.Add("Language: $Lang")
    $summaryLines.Add("NoNAT: $([bool]$NoNAT)")
    if ($Reason) { $summaryLines.Add("Reason: $Reason") }
    if ($rndis) { $summaryLines.Add("UsbAdapter: $($rndis.Name) [$($rndis.InterfaceDescription)]") }
    if ($piIP) { $summaryLines.Add("PiAddress: $piIP") }
    if ($internetAdapter) { $summaryLines.Add("InternetAdapter: $($internetAdapter.Name) [$($internetAdapter.InterfaceDescription)]") }
    $summaryLines.Add("NatActive: $natActive")
    if ($script:LogPath) { $summaryLines.Add("LogFile: $(Split-Path $script:LogPath -Leaf)") }
    Set-Content -Path (Join-Path $packageDir 'summary.txt') -Value $summaryLines -Encoding UTF8 -ErrorAction SilentlyContinue

    $manifest = [ordered]@{
        holyConnectVersion = $HOLYCONNECT_VERSION
        createdAt = (Get-Date).ToString('o')
        exitCode = $ExitCode
        result = $result
        reason = $Reason
        language = $Lang
        parameters = [ordered]@{
            noNAT = [bool]$NoNAT
            noBrowser = [bool]$NoBrowser
            internetAdapterName = $InternetAdapterName
            exportDiagnostics = [bool]$ExportDiagnostics
            customLogPath = [bool](-not [string]::IsNullOrWhiteSpace($LogPath))
            customDiagnosticsPath = [bool](-not [string]::IsNullOrWhiteSpace($DiagnosticsPath))
        }
        observedState = [ordered]@{
            piAddress = $piIP
            natActive = $natActive
            usbAdapter = if ($rndis) { [ordered]@{ name = $rndis.Name; interfaceDescription = $rndis.InterfaceDescription; status = $rndis.Status } } else { $null }
            internetAdapter = if ($internetAdapter) { [ordered]@{ name = $internetAdapter.Name; interfaceDescription = $internetAdapter.InterfaceDescription; status = $internetAdapter.Status } } else { $null }
        }
    }
    $manifest | ConvertTo-Json -Depth 8 | Set-Content -Path (Join-Path $packageDir 'manifest.json') -Encoding UTF8 -ErrorAction SilentlyContinue

    if ($script:LogPath -and (Test-Path $script:LogPath)) {
        Copy-Item $script:LogPath (Join-Path $packageDir (Split-Path $script:LogPath -Leaf)) -Force -ErrorAction SilentlyContinue
    }

    Export-TextDiagnostic -PackageDir $packageDir -FileName 'os.txt' -ScriptBlock {
        Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue |
            Select-Object Caption, Version, BuildNumber, OSArchitecture, CSName, LastBootUpTime |
            Format-List *
    }

    Export-TextDiagnostic -PackageDir $packageDir -FileName 'adapters.txt' -ScriptBlock {
        Get-NetAdapter -ErrorAction SilentlyContinue |
            Sort-Object ifIndex |
            Select-Object Name, Status, ifIndex, MacAddress, HardwareInterface, InterfaceDescription |
            Format-Table -AutoSize
    }

    Export-TextDiagnostic -PackageDir $packageDir -FileName 'ip-addresses.txt' -ScriptBlock {
        Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Sort-Object InterfaceIndex |
            Select-Object InterfaceAlias, InterfaceIndex, IPAddress, PrefixLength, PrefixOrigin, AddressState, SkipAsSource |
            Format-Table -AutoSize
    }

    Export-TextDiagnostic -PackageDir $packageDir -FileName 'routes.txt' -ScriptBlock {
        Get-NetRoute -DestinationPrefix '0.0.0.0/0' -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Sort-Object RouteMetric |
            Select-Object ifIndex, InterfaceAlias, NextHop, RouteMetric, DestinationPrefix |
            Format-Table -AutoSize
    }

    Export-TextDiagnostic -PackageDir $packageDir -FileName 'pnp.txt' -ScriptBlock {
        Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
            Where-Object { $_.InstanceId -match 'VID_0525|RNDIS' } |
            Select-Object Status, Class, FriendlyName, Name, InstanceId, Problem |
            Format-List *
    }

    Export-TextDiagnostic -PackageDir $packageDir -FileName 'rndis-adapters.txt' -ScriptBlock {
        Get-RNDISAdapters |
            Select-Object Name, Status, ifIndex, InterfaceDescription |
            Format-Table -AutoSize
    }

    Export-TextDiagnostic -PackageDir $packageDir -FileName 'nat.txt' -ScriptBlock {
        if (Get-Command Get-NetNat -ErrorAction SilentlyContinue) {
            Get-NetNat -ErrorAction SilentlyContinue | Format-List *
        } else {
            'Get-NetNat is not available on this Windows version.'
        }
    }

    Export-TextDiagnostic -PackageDir $packageDir -FileName 'state.txt' -ScriptBlock {
        @(
            "RunStarted: $($script:RunStartedAt.ToString('o'))"
            "RunFinished: $((Get-Date).ToString('o'))"
            "Reason: $Reason"
            "PiIP: $piIP"
            "NatActive: $natActive"
            "UsbAdapter: $(if ($rndis) { $rndis.Name } else { '(none)' })"
            "InternetAdapter: $(if ($internetAdapter) { $internetAdapter.Name } else { '(none)' })"
        )
    }

    $archivePath = Join-Path $root "$packageName.zip"
    if (Get-Command Compress-Archive -ErrorAction SilentlyContinue) {
        try {
            Compress-Archive -Path (Join-Path $packageDir '*') -DestinationPath $archivePath -CompressionLevel Optimal -Force -ErrorAction Stop
            Remove-Item $packageDir -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log 'INFO' ("Diagnostics package written to {0}" -f $archivePath)
            return $archivePath
        } catch {
            Write-Log 'WARN' ("Failed to compress diagnostics package: {0}" -f $_.Exception.Message)
        }
    }

    Write-Log 'INFO' ("Diagnostics package directory created at {0}" -f $packageDir)
    return $packageDir
}

function Exit-HolyConnect {
    param(
        [int]$Code = 0,
        [string]$Reason
    )

    if ($Reason) {
        $script:LastOutcomeReason = $Reason
    }
    $effectiveReason = if ($script:LastOutcomeReason) { $script:LastOutcomeReason } else { if ($Code -eq 0) { 'Completed' } else { 'Failed' } }

    if ($script:LogPath) {
        Write-Log 'INFO' "Outcome: $effectiveReason"
        Write-Log 'INFO' "Exit code: $Code"
        Write-Host ""
        Write-Host "  $($T.LogLabel): $script:LogPath" -ForegroundColor DarkGray
    }

    if ($Code -ne 0 -or $ExportDiagnostics) {
        $script:DiagnosticsPackagePath = Export-DiagnosticsPackage -ExitCode $Code -Reason $effectiveReason
        if ($script:DiagnosticsPackagePath) {
            Write-Host "  $($T.DiagnosticsLabel): $script:DiagnosticsPackagePath" -ForegroundColor DarkGray
            Write-Log 'INFO' ($T.DiagnosticsReady -f $script:DiagnosticsPackagePath)
        } else {
            Write-Warn $T.DiagnosticsFailed
        }
    }

    Write-Host ""
    Write-Host "  $($T.PressKey)" -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit $Code
}

function Invoke-CapturedCommand {
    param(
        [string]$CommandPath,
        [string[]]$Arguments
    )

    $argText = if ($Arguments) { $Arguments -join ' ' } else { '' }
    Write-Log 'CMD' "Running: $CommandPath $argText"

    try {
        $output = & $CommandPath @Arguments 2>&1
        $exitCode = $LASTEXITCODE
    } catch {
        Write-Log 'ERROR' "$CommandPath failed: $($_.Exception.Message)"
        return [pscustomobject]@{ Output = @(); ExitCode = -1 }
    }

    foreach ($line in @($output)) {
        if ($null -ne $line) {
            $text = "$line".TrimEnd()
            if ($text) { Write-Log 'CMD' $text }
        }
    }

    Write-Log 'CMD' "ExitCode: $exitCode"
    return [pscustomobject]@{ Output = @($output); ExitCode = $exitCode }
}

function Write-DiagnosticSnapshot {
    param([string]$Reason)

    Write-Log 'DEBUG' "=== Diagnostic snapshot: $Reason ==="
    Write-Log 'DEBUG' "Version=$HOLYCONNECT_VERSION; Computer=$env:COMPUTERNAME; User=$env:USERNAME; PowerShell=$($PSVersionTable.PSVersion)"

    try {
        $os = Get-CimInstance Win32_OperatingSystem -ErrorAction Stop
        Write-Log 'DEBUG' "OS=$($os.Caption); Version=$($os.Version); Build=$($os.BuildNumber)"
    } catch {}

    if (Get-Command Get-PnpDevice -ErrorAction SilentlyContinue) {
        try {
            Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
                Where-Object { $_.InstanceId -match 'VID_0525|RNDIS' } |
                Select-Object -First 12 |
                ForEach-Object {
                    Write-Log 'DEBUG' ("PnP: Status={0}; Class={1}; Name={2}; Id={3}" -f $_.Status, $_.Class, (Get-PiUsbDeviceLabel $_), $_.InstanceId)
                }
        } catch {}
    }

    try {
        Get-NetAdapter -ErrorAction SilentlyContinue |
            Sort-Object ifIndex |
            ForEach-Object {
                $ipv4 = Get-NetIPAddress -InterfaceIndex $_.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                    Select-Object -ExpandProperty IPAddress
                $ipv4Text = if ($ipv4) { $ipv4 -join ',' } else { '-' }
                Write-Log 'DEBUG' ("Adapter: Name={0}; Status={1}; IfIndex={2}; IPv4={3}; Desc={4}" -f $_.Name, $_.Status, $_.ifIndex, $ipv4Text, $_.InterfaceDescription)
            }
    } catch {}

    try {
        Get-NetRoute -DestinationPrefix '0.0.0.0/0' -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Sort-Object RouteMetric |
            ForEach-Object {
                Write-Log 'DEBUG' ("Route: IfIndex={0}; Metric={1}; NextHop={2}; Prefix={3}" -f $_.ifIndex, $_.RouteMetric, $_.NextHop, $_.DestinationPrefix)
            }
    } catch {}

    if (Get-Command Get-NetNat -ErrorAction SilentlyContinue) {
        try {
            Get-NetNat -ErrorAction SilentlyContinue |
                ForEach-Object {
                    Write-Log 'DEBUG' ("NAT: Name={0}; Prefix={1}" -f $_.Name, $_.InternalIPInterfaceAddressPrefix)
                }
        } catch {}
    }
}

function Test-Port($ip, $port, $timeoutMs = 800) {
    try {
        $tcp = New-Object System.Net.Sockets.TcpClient
        $ar = $tcp.BeginConnect($ip, $port, $null, $null)
        $ok = $ar.AsyncWaitHandle.WaitOne($timeoutMs, $false)
        if ($ok -and $tcp.Connected) { $tcp.Close(); return $true }
        $tcp.Close()
    } catch {}
    return $false
}

function Find-PiStar {
    $candidates = [System.Collections.Generic.List[string]]::new()

    # Try last known IP first (from previous run)
    $lastIPFile = Join-Path $PSScriptRoot "holyconnect_last_ip.txt"
    if (Test-Path $lastIPFile) {
        $lastIP = Get-Content $lastIPFile -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($lastIP) {
            $lastIP = $lastIP.Trim()
            if ($lastIP -match '^\d+\.\d+\.\d+\.\d+$') { $candidates.Add($lastIP) }
        }
    }

    # Standard candidates
    if ($HOLYCONNECT_PI_IP -notin $candidates) { $candidates.Add($HOLYCONNECT_PI_IP) }
    $candidates.Add("192.168.137.2")

    $rndis = Get-RNDISAdapter
    if ($rndis) {
        $arpEntries = Get-NetNeighbor -InterfaceIndex $rndis.ifIndex -ErrorAction SilentlyContinue |
            Where-Object { $_.State -ne 'Unreachable' -and $_.IPAddress -match '^\d+\.\d+\.\d+\.\d+$' }
        foreach ($arp in $arpEntries) {
            if ($arp.IPAddress -notin $candidates) { $candidates.Insert(0, $arp.IPAddress) }
        }
        $adapterIP = Get-NetIPAddress -InterfaceIndex $rndis.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
        if ($adapterIP) {
            $subnet = $adapterIP.IPAddress -replace '\.\d+$', ''
            for ($i = 2; $i -le 10; $i++) {
                $ip = "$subnet.$i"
                if ($ip -notin $candidates) { $candidates.Add($ip) }
            }
        }
    }

    Write-Log 'DEBUG' ("Find-PiStar candidates: " + ($candidates -join ', '))

    foreach ($ip in $candidates) {
        $reachable = $false
        & $PING -n 1 -w 600 $ip 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) { $reachable = $true }

        if ($reachable -and (Test-Port $ip 22 800)) {
            Write-Log 'INFO' "Pi-Star found at $ip (ICMP + SSH)"
            return $ip
        }

        if (-not $reachable -and (Test-Port $ip 22 1200)) {
            Write-Log 'INFO' "Pi-Star found at $ip (SSH only)"
            return $ip
        }
    }
    return $null
}

function Get-RNDISAdapters {
    $adapters = @(Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.InterfaceDescription -match 'RNDIS|Remote NDIS' })
    if (-not $adapters) { return @() }

    $piAdapterNames = @{}
    try {
        Get-CimInstance Win32_NetworkAdapter -ErrorAction SilentlyContinue |
            Where-Object { $_.NetConnectionID -and $_.PNPDeviceID -match 'VID_0525' } |
            ForEach-Object { $piAdapterNames[$_.NetConnectionID] = $true }
    } catch {}

    $sorted = $adapters | Sort-Object @{ Expression = { $piAdapterNames.ContainsKey($_.Name) }; Descending = $true }, @{ Expression = { $_.Status -eq 'Up' }; Descending = $true }, Name
    if ($sorted.Count -gt 1) {
        Write-Log 'DEBUG' ("Multiple RNDIS adapters detected: " + (($sorted | ForEach-Object { $_.Name }) -join ', '))
    }

    return @($sorted)
}

function Get-RNDISAdapter {
    Get-RNDISAdapters | Select-Object -First 1
}

function Get-PiUsbDevice {
    Get-PnpDevice -PresentOnly -ErrorAction SilentlyContinue |
        Where-Object { $_.InstanceId -match 'VID_0525' } |
        Sort-Object @{ Expression = { $_.Status -eq 'OK' }; Descending = $true }, @{ Expression = { $_.Class -eq 'Net' }; Descending = $true } |
        Select-Object -First 1
}

function Get-PiUsbDeviceLabel($device) {
    if (-not $device) { return $null }
    foreach ($label in @($device.FriendlyName, $device.Name, $device.InstanceId)) {
        if ($label) { return $label }
    }
    return "Pi USB device"
}

function Get-RndisInfCandidates {
    $candidates = [System.Collections.Generic.List[string]]::new()
    foreach ($path in @(
        (Join-Path $env:SystemRoot "INF\netrndis.inf"),
        (Join-Path $env:SystemRoot "INF\rndiscmp.inf")
    )) {
        if ($path -and (Test-Path $path) -and ($path -notin $candidates)) {
            $candidates.Add($path)
        }
    }

    Get-ChildItem (Join-Path $env:SystemRoot 'INF') -Filter '*rndis*.inf' -ErrorAction SilentlyContinue |
        Select-Object -ExpandProperty FullName |
        ForEach-Object {
            if ($_ -notin $candidates) { $candidates.Add($_) }
        }

    return @($candidates)
}

function Get-AvailableNatName {
    $preferredNames = @("HolyConnectNAT", "HolyConnectNAT-$($env:COMPUTERNAME)", "PiStarNAT")
    foreach ($name in $preferredNames) {
        if (-not (Get-NetNat -Name $name -ErrorAction SilentlyContinue)) { return $name }
    }
    return "HolyConnectNAT-$([Guid]::NewGuid().ToString('N').Substring(0, 6))"
}

function Get-SubnetNat {
    param([string]$Prefix)

    Get-NetNat -ErrorAction SilentlyContinue |
        Where-Object { $_.InternalIPInterfaceAddressPrefix -eq $Prefix } |
        Select-Object -First 1
}

function Get-InternetAdapter {
    param([string]$PreferredName)

    $routesByIfIndex = @{}
    Get-NetRoute -DestinationPrefix "0.0.0.0/0" -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.NextHop -and $_.NextHop -ne '0.0.0.0' } |
        ForEach-Object {
            $current = $routesByIfIndex[$_.ifIndex]
            if (-not $current -or $_.RouteMetric -lt $current.RouteMetric) {
                $routesByIfIndex[$_.ifIndex] = $_
            }
        }

    if ($PreferredName) {
        $preferred = Get-NetAdapter -Name $PreferredName -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $preferred -or $preferred.Status -ne 'Up') { return $null }
        $preferredRoute = $routesByIfIndex[$preferred.ifIndex]
        if (-not $preferredRoute) { return $null }

        Write-Log 'INFO' ("Using requested internet adapter: {0} ({1})" -f $preferred.Name, $preferred.InterfaceDescription)

        return [pscustomobject]@{
            Adapter = $preferred
            Route = $preferredRoute
            Source = 'preferred'
            Score = 1000
        }
    }

    $candidates = foreach ($route in $routesByIfIndex.Values) {
        $adapter = Get-NetAdapter -InterfaceIndex $route.ifIndex -ErrorAction SilentlyContinue
        if (-not $adapter -or $adapter.Status -ne 'Up') { continue }
        if ($adapter.InterfaceDescription -match 'RNDIS|Remote NDIS' -or $adapter.Name -match 'Loopback') { continue }

        $adapterText = "$($adapter.Name) $($adapter.InterfaceDescription)"
        $ipv4 = Get-NetIPAddress -InterfaceIndex $adapter.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
            Where-Object { $_.IPAddress -notmatch '^169\.254\.' } |
            Select-Object -First 1

        $score = 0
        if ($adapter.HardwareInterface) { $score += 40 } else { $score += 5 }
        if ($ipv4) { $score += 25 }
        if ($adapterText -match 'Ethernet|Wi-?Fi|Wireless|WLAN|WWAN|Mobile|LTE|5G|4G|USB') { $score += 20 }
        if ($adapterText -match 'Bluetooth') { $score -= 20 }
        if ($adapterText -match 'Hyper-V|vEthernet|VMware|VirtualBox|Loopback') { $score -= 25 }
        if ($adapterText -match 'VPN|WireGuard|AnyConnect|Fortinet|Tailscale|ZeroTier|TAP-Windows|Juniper|Zscaler') { $score -= 10 }
        $score -= [Math]::Min([int]$route.RouteMetric, 50)

        [pscustomobject]@{
            Adapter = $adapter
            Route = $route
            Source = 'auto'
            Score = $score
        }
    }

    foreach ($candidate in $candidates) {
        Write-Log 'DEBUG' ("Internet candidate: Name={0}; Score={1}; Metric={2}; Desc={3}" -f $candidate.Adapter.Name, $candidate.Score, $candidate.Route.RouteMetric, $candidate.Adapter.InterfaceDescription)
    }

    $selected = $candidates |
        Sort-Object @{ Expression = 'Score'; Descending = $true }, @{ Expression = { [int]$_.Route.RouteMetric }; Descending = $false } |
        Select-Object -First 1

    if ($selected) {
        Write-Log 'INFO' ("Selected internet adapter: {0} ({1}) score={2}" -f $selected.Adapter.Name, $selected.Adapter.InterfaceDescription, $selected.Score)
    }

    return $selected
}

# ============================================
#  BANNER
# ============================================
Clear-Host
Write-Host ""
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host "   _  _     _        ___                     " -ForegroundColor Cyan
Write-Host "  | || |___| |_  _  / __|___ _ _  _ _  ___ __| |_" -ForegroundColor Cyan
Write-Host "  | __ / _ \ | || || (__/ _ \ ' \| ' \/ -_) _|  _|" -ForegroundColor Cyan
Write-Host "  |_||_\___/_|\_, | \___\___/_||_|_||_\___\__|\__|" -ForegroundColor Cyan
Write-Host "              |__/     Pi-Star USB Tethering" -ForegroundColor White
Write-Host "                        v${HOLYCONNECT_VERSION}" -ForegroundColor DarkGray
Write-Host "  ============================================" -ForegroundColor Cyan
Write-Host ""

$null = Initialize-Log -RequestedPath $LogPath
if ($script:LogPath) {
    Write-Info ($T.LogEnabled -f $script:LogPath)
    Write-Log 'INFO' "HolyConnect v$HOLYCONNECT_VERSION started"
    Write-DiagnosticSnapshot "Startup"
}

# ============================================
#  CHECK REQUIREMENTS
# ============================================
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Fail "PowerShell 5.0+ required (current: $($PSVersionTable.PSVersion))"
    Exit-HolyConnect 1 "PowerShell 5.0+ required"
}

# ============================================
#  CHECK ADMIN
# ============================================
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    Write-Fail $T.AdminRequired
    Write-Host ""
    Write-Host "  $($T.AdminHint)" -ForegroundColor Yellow
    Exit-HolyConnect 1 $T.AdminRequired
}

$steps = 6

# ============================================
#  STEP 1: DETECT PI USB DEVICE
# ============================================
Write-Step 1 $steps $T.Step1

$rndis = Get-RNDISAdapter
$piPnp = Get-PiUsbDevice

if ($rndis -or $piPnp) {
    if ($rndis) { Write-OK "$($T.AlreadyConnected): $($rndis.InterfaceDescription)" }
    elseif ($piPnp) { Write-OK "$($T.Detected): $(Get-PiUsbDeviceLabel $piPnp)" }
} else {
    Write-Info $T.PlugIn
    Write-Info $T.BootWait

    $maxWait = 120; $t = 0
    while ($t -lt $maxWait) {
        Start-Sleep 5; $t += 5
        $rndis = Get-RNDISAdapter
        $piPnp = Get-PiUsbDevice
        if ($rndis -or $piPnp) { break }
        if ($t % 15 -eq 0) { Write-Info "$($T.Waiting)... ($t sec)" }
    }

    if (-not $rndis -and -not $piPnp) {
        Write-DiagnosticSnapshot "Step 1 failure: Pi USB device not detected"
        Write-Fail ($T.NotDetected -f $maxWait)
        Write-Info $T.CheckCable
        Exit-HolyConnect 1 "Pi USB device not detected"
    }
    if ($rndis) { Write-OK "$($T.Detected): $($rndis.InterfaceDescription)" }
    elseif ($piPnp) { Write-OK "$($T.Detected): $(Get-PiUsbDeviceLabel $piPnp)" }
}

# ============================================
#  STEP 2: RNDIS DRIVER
# ============================================
Write-Step 2 $steps $T.Step2

$rndis = Get-RNDISAdapter

if ($rndis) {
    Write-OK "$($T.DriverOK): $($rndis.Name) ($($rndis.InterfaceDescription))"
} else {
    Write-Warn $T.DriverNotFound
    Write-Info $T.DriverAutoInstall

    # Method 1: pnputil with built-in RNDIS INF
    $rndisInfs = @(Get-RndisInfCandidates)
    if ($rndisInfs.Count -gt 0) {
        foreach ($rndisInf in $rndisInfs) {
            Write-Log 'INFO' "Trying built-in RNDIS INF: $rndisInf"
            $null = Invoke-CapturedCommand -CommandPath $PNPUTIL -Arguments @('/add-driver', $rndisInf, '/install')
            Start-Sleep 5
            $null = Invoke-CapturedCommand -CommandPath $PNPUTIL -Arguments @('/scan-devices')
            Start-Sleep 5
            $rndis = Get-RNDISAdapter
            if ($rndis) { break }
        }
    } else {
        Write-Warn $T.DriverInfMissing
        Write-Log 'WARN' "No built-in RNDIS INF files were found in $env:SystemRoot\INF"
    }

    # Method 2: Restart misidentified device
    if (-not $rndis) {
        $piDev = Get-PiUsbDevice
        if ($piDev -and $piDev.Class -ne 'Net') {
            Write-Info $T.DriverRestarting
            $null = Invoke-CapturedCommand -CommandPath $PNPUTIL -Arguments @('/remove-device', $piDev.InstanceId)
            Start-Sleep 3
            $null = Invoke-CapturedCommand -CommandPath $PNPUTIL -Arguments @('/scan-devices')
            Start-Sleep 8
            $rndis = Get-RNDISAdapter
        }
    }

    # Method 3: Manual fallback with clear instructions
    if (-not $rndis) {
        Write-Host ""
        Write-Host "  ================================================" -ForegroundColor Yellow
        Write-Host "   $($T.DriverManualTitle)" -ForegroundColor Yellow
        Write-Host "  ================================================" -ForegroundColor Yellow
        Write-Host ""
        Write-Host "  $($T.DriverManualOpen)" -ForegroundColor White
        Write-Host ""
        Write-Host "  $($T.DriverManualStep1)" -ForegroundColor Cyan
        Write-Host "    $($T.DriverManualFind)" -ForegroundColor White
        Write-Host ""
        Write-Host "  $($T.DriverManualStep2)" -ForegroundColor Cyan
        Write-Host "    $($T.DriverManualClick)" -ForegroundColor White
        Write-Host "    $($T.DriverManualBrowse)" -ForegroundColor White
        Write-Host "    $($T.DriverManualList)" -ForegroundColor White
        Write-Host ""
        Write-Host "  $($T.DriverManualStep3)" -ForegroundColor Cyan
        Write-Host "    $($T.DriverManualUncheck)" -ForegroundColor White
        Write-Host "    $($T.DriverManualMfr)" -ForegroundColor Green
        Write-Host "    $($T.DriverManualModel)" -ForegroundColor Green
        Write-Host "    $($T.DriverManualNext)" -ForegroundColor White
        Write-Host ""

        Start-Process $DEVMGMT -ErrorAction SilentlyContinue
        Write-Host "  $($T.DriverManualDone)" -ForegroundColor Yellow
        Read-Host
    }

    # Final wait
    if (-not $rndis) {
        $w = 0
        while ($w -lt 30) {
            $rndis = Get-RNDISAdapter; if ($rndis) { break }
            Start-Sleep 2; $w += 2
        }
    }

    if (-not $rndis) {
        Write-DiagnosticSnapshot "Step 2 failure: RNDIS adapter missing after install attempts"
        Write-Fail $T.DriverFailed
        Write-Info $T.DriverRetry
        Exit-HolyConnect 1 "RNDIS adapter missing after install attempts"
    }
    Write-OK "$($T.DriverInstalled): $($rndis.Name) ($($rndis.InterfaceDescription))"
}

# Ensure adapter is up
if ($rndis.Status -ne 'Up') {
    Write-Info $T.Activating
    Enable-NetAdapter -Name $rndis.Name -Confirm:$false -ErrorAction SilentlyContinue
    Start-Sleep 3
    $rndis = Get-RNDISAdapter
}

# ============================================
#  STEP 3: CONFIGURE STATIC IP
# ============================================
Write-Step 3 $steps $T.Step3
Write-Log 'INFO' ("Configuring USB adapter {0} (ifIndex={1})" -f $rndis.Name, $rndis.ifIndex)

# Remove existing IP config (handles DHCP, multiple IPs, etc.)
Set-NetIPInterface -InterfaceIndex $rndis.ifIndex -Dhcp Disabled -ErrorAction SilentlyContinue
$rndis | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
$rndis | Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue
Start-Sleep 2

try {
    New-NetIPAddress -InterfaceIndex $rndis.ifIndex -IPAddress $HOLYCONNECT_HOST_IP -PrefixLength 24 -ErrorAction Stop | Out-Null
    Write-OK "$($T.IPSet): $HOLYCONNECT_HOST_IP/24"
} catch {
    $existing = Get-NetIPAddress -InterfaceIndex $rndis.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
    if ($existing -and $existing.IPAddress -eq $HOLYCONNECT_HOST_IP) {
        Write-OK "$($T.IPSet): $HOLYCONNECT_HOST_IP/24"
    } elseif ($existing) {
        Write-OK "$($T.IPCurrent): $($existing.IPAddress)/$($existing.PrefixLength)"
    } else {
        Write-Warn "$($T.IPError): $($_.Exception.Message)"
    }
}

Start-Sleep 3
$piIP = Find-PiStar
if ($piIP) { Write-OK ($T.PiReachable -f $piIP) }

# ============================================
#  STEP 4: INTERNET SHARING (NAT)
# ============================================
Write-Step 4 $steps $T.Step4

$natActive = $false
$internetAdapter = $null
$internetSelection = $null

if ($NoNAT) {
    Write-Info $T.NATDisabled
} else {
    if (-not (Get-Command New-NetNat -ErrorAction SilentlyContinue)) {
        Write-Warn $T.NATUnavailable
        Write-Info $T.NATUnavailableHint
    } else {
        if ($InternetAdapterName) {
            $internetSelection = Get-InternetAdapter -PreferredName $InternetAdapterName
            if (-not $internetSelection) {
                Write-Warn ($T.AdapterOverrideFailed -f $InternetAdapterName)
            }
        }

        if (-not $internetSelection) {
            $internetSelection = Get-InternetAdapter
        }

        $internetAdapter = if ($internetSelection) { $internetSelection.Adapter } else { $null }

        if (-not $internetAdapter) {
            Write-Warn $T.NoInternet
            Write-Info $T.NoInternetHint
        } else {
            Write-Info "$($T.InternetVia): $($internetAdapter.Name) ($($internetAdapter.InterfaceDescription))"

            $existingNat = Get-SubnetNat -Prefix $HOLYCONNECT_NAT_PREFIX
            if ($existingNat) {
                $natActive = $true
                if ($existingNat.Name -match '^(HolyConnectNAT|PiStarNAT)') {
                    Write-OK $T.NATExists
                } else {
                    Write-Info ($T.NATReuseExisting -f $existingNat.Name)
                    Write-OK $T.NATActive
                }
            } else {
                try {
                    New-NetNat -Name (Get-AvailableNatName) -InternalIPInterfaceAddressPrefix $HOLYCONNECT_NAT_PREFIX -ErrorAction Stop | Out-Null
                    $natActive = $true
                    Write-OK $T.NATActive
                } catch {
                    $existingNat = Get-SubnetNat -Prefix $HOLYCONNECT_NAT_PREFIX
                    if ($existingNat) {
                        $natActive = $true
                        Write-Info ($T.NATReuseExisting -f $existingNat.Name)
                        Write-OK $T.NATActive
                    } else {
                        Write-Warn "$($T.NATConflict): $($_.Exception.Message)"
                        Write-Info $T.NATConflictHint
                    }
                }
            }
        }
    }
}

# ============================================
#  STEP 5: FIND PI-STAR
# ============================================
Write-Step 5 $steps $T.Step5

# Skip long search if Pi was already found in Step 3
if (-not $piIP) {
    $maxRetries = 8
    for ($r = 1; $r -le $maxRetries; $r++) {
        $piIP = Find-PiStar
        if ($piIP) { break }
        Write-Info "$($T.Attempt) $r/$maxRetries..."
        Start-Sleep 5
    }
} else {
    # Verify it's still reachable
    $verify = Find-PiStar
    if ($verify) { $piIP = $verify }
}

# ============================================
#  STEP 6: RESULTS
# ============================================
Write-Step 6 $steps $T.Step6
Write-Host ""

if ($piIP) {
    $httpOK = $false
    try {
        $resp = Invoke-WebRequest -Uri "http://$piIP/" -TimeoutSec 5 -UseBasicParsing -ErrorAction Stop
        $httpOK = ($resp.StatusCode -eq 200)
    } catch {
        if ($_.Exception.Response.StatusCode.value__ -eq 401) { $httpOK = $true }
    }
    $sshOK = Test-Port $piIP 22

    Write-Host "  ======================================================" -ForegroundColor Green
    Write-Host "         $($T.Success)" -ForegroundColor Green
    Write-Host "  ======================================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "  $($T.PiIP):     $piIP" -ForegroundColor White
    Write-Host ""
    if ($httpOK) {
        Write-Host "  $($T.Dashboard):       " -ForegroundColor White -NoNewline
        Write-Host "http://$piIP/" -ForegroundColor Cyan
    } else {
        Write-Host "  $($T.Dashboard):       http://$piIP/" -ForegroundColor DarkGray
    }
    if ($sshOK) {
        Write-Host "  SSH:              pi-star@$piIP" -ForegroundColor White
    }
    Write-Host "  $($T.Password):        raspberry" -ForegroundColor White
    if ($natActive) {
        Write-Host "  $($T.Internet):       $($T.SharedViaNAT) ($($internetAdapter.Name))" -ForegroundColor White
    }
    Write-Host ""

    $piIP | Set-Content (Join-Path $PSScriptRoot "holyconnect_last_ip.txt") -Force -ErrorAction SilentlyContinue

    if (-not $NoBrowser) {
        Write-Info $T.OpeningBrowser
        Start-Process "http://$piIP/"
    }
} else {
    Write-DiagnosticSnapshot "Step 5 failure: Pi-Star not reachable on USB network"
    Write-Host "  ======================================================" -ForegroundColor Yellow
    Write-Host "     $($T.NotFound)" -ForegroundColor Yellow
    Write-Host "  ======================================================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "    - $($T.NotFoundCause1)" -ForegroundColor Gray
    Write-Host "    - $($T.NotFoundCause2)" -ForegroundColor Gray
    Write-Host "    - $($T.NotFoundCause3)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  $($T.TryManually)" -ForegroundColor White

    $adapterIP = Get-NetIPAddress -InterfaceIndex $rndis.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
    if ($adapterIP) {
        $sub = $adapterIP.IPAddress -replace '\.\d+$', ''
        Write-Host "    http://${sub}.2/" -ForegroundColor Cyan
    }
    Write-Host "    http://$HOLYCONNECT_PI_IP/" -ForegroundColor Cyan
    Exit-HolyConnect 2 "Pi-Star not reachable on USB network"
}

Exit-HolyConnect 0
