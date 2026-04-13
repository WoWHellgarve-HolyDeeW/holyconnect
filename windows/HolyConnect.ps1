<#
.SYNOPSIS
    HolyConnect v1.0.1 - Pi-Star USB Tethering for Windows
.DESCRIPTION
    Automatically connects to a Pi-Star MMDVM hotspot via USB cable.
    Detects Pi, installs RNDIS driver if needed, configures networking,
    shares internet via NAT, and opens the Pi-Star dashboard.

    Works on any Windows 10/11 PC. Run as Administrator.
.PARAMETER NoNAT
    Skip internet sharing (Pi-Star works but can't reach reflectors)
.PARAMETER NoBrowser
    Don't open browser at the end
.PARAMETER Lang
    Language: 'pt' for Portuguese, 'en' for English (auto-detected from system)
.LINK
    https://github.com/WoWHellgarve-HolyDeeW/holyconnect
#>

param(
    [switch]$NoNAT,
    [switch]$NoBrowser,
    [ValidateSet('pt','en')][string]$Lang
)

$ErrorActionPreference = "Continue"
$Host.UI.RawUI.WindowTitle = "HolyConnect"
$HOLYCONNECT_VERSION = "1.0.1"
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
    $T.NATFailed         = "NAT falhou"
    $T.NATFailHint       = "O Pi-Star funciona mas pode nao ter internet."
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
    $T.NATFailed         = "NAT failed"
    $T.NATFailHint       = "Pi-Star works but may not have internet."
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
function Write-Step($n, $t, $msg) { Write-Host "`n[$n/$t] $msg" -ForegroundColor Yellow }
function Write-OK($msg)   { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Info($msg)  { Write-Host "  $msg" -ForegroundColor Gray }
function Write-Warn($msg)  { Write-Host "  [!] $msg" -ForegroundColor DarkYellow }
function Write-Fail($msg)  { Write-Host "  [X] $msg" -ForegroundColor Red }

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
        $lastIP = (Get-Content $lastIPFile -ErrorAction SilentlyContinue | Select-Object -First 1).Trim()
        if ($lastIP -match '^\d+\.\d+\.\d+\.\d+$') { $candidates.Add($lastIP) }
    }

    # Standard candidates
    if ("192.168.7.2" -notin $candidates) { $candidates.Add("192.168.7.2") }
    $candidates.Add("192.168.137.2")

    $rndis = Get-NetAdapter | Where-Object { $_.InterfaceDescription -match 'RNDIS|Remote NDIS' -and $_.Status -eq 'Up' }
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

    foreach ($ip in $candidates) {
        # Try ping first (fast), fall back to TCP if ping blocked by firewall
        $reachable = $false
        $reply = & $PING -n 1 -w 600 $ip 2>$null | Select-String "Reply from"
        if ($reply) { $reachable = $true }
        if ($reachable -and (Test-Port $ip 22 800)) { return $ip }
        # Firewall may block ICMP but SSH still works
        if (-not $reachable -and (Test-Port $ip 22 1200)) { return $ip }
    }
    return $null
}

function Get-RNDISAdapter {
    Get-NetAdapter | Where-Object { $_.InterfaceDescription -match 'RNDIS|Remote NDIS' } | Select-Object -First 1
}

function Get-InternetAdapter {
    # Find the real internet adapter, excluding virtual/VPN adapters
    Get-NetAdapter | Where-Object {
        $_.Status -eq 'Up' -and
        $_.InterfaceDescription -notmatch 'RNDIS|Remote NDIS' -and
        $_.InterfaceDescription -notmatch 'Hyper-V|vEthernet|VirtualBox|VMware|TAP-Windows|WireGuard|Fortinet|Cisco AnyConnect' -and
        $_.Name -notmatch 'Loopback|vEthernet'
    } | ForEach-Object {
        $gw = Get-NetRoute -InterfaceIndex $_.ifIndex -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue
        if ($gw) { $_ }
    } | Sort-Object -Property { (Get-NetRoute -InterfaceIndex $_.ifIndex -DestinationPrefix "0.0.0.0/0" -ErrorAction SilentlyContinue).RouteMetric } |
    Select-Object -First 1
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

# ============================================
#  CHECK REQUIREMENTS
# ============================================
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Fail "PowerShell 5.0+ required (current: $($PSVersionTable.PSVersion))"
    Write-Host "  $($T.PressKey)" -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown"); exit 1
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
    Write-Host ""
    Write-Host "  $($T.PressKey)" -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

$steps = 6

# ============================================
#  STEP 1: DETECT PI USB DEVICE
# ============================================
Write-Step 1 $steps $T.Step1

$rndis = Get-RNDISAdapter
$piPnp = Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -match 'VID_0525' -and $_.Status -eq 'OK' } | Select-Object -First 1

if ($rndis -or $piPnp) {
    if ($rndis) { Write-OK "$($T.AlreadyConnected): $($rndis.InterfaceDescription)" }
    elseif ($piPnp) { Write-OK "$($T.Detected): $($piPnp.FriendlyName)" }
} else {
    Write-Info $T.PlugIn
    Write-Info $T.BootWait

    $maxWait = 120; $t = 0
    while ($t -lt $maxWait) {
        Start-Sleep 5; $t += 5
        $rndis = Get-RNDISAdapter
        $piPnp = Get-PnpDevice -ErrorAction SilentlyContinue | Where-Object { $_.InstanceId -match 'VID_0525' -and $_.Status -eq 'OK' } | Select-Object -First 1
        if ($rndis -or $piPnp) { break }
        if ($t % 15 -eq 0) { Write-Info "$($T.Waiting)... ($t sec)" }
    }

    if (-not $rndis -and -not $piPnp) {
        Write-Fail ($T.NotDetected -f $maxWait)
        Write-Info $T.CheckCable
        Write-Host ""; Write-Host "  $($T.PressKey)" -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown"); exit 1
    }
    if ($rndis) { Write-OK "$($T.Detected): $($rndis.InterfaceDescription)" }
    elseif ($piPnp) { Write-OK "$($T.Detected): $($piPnp.FriendlyName)" }
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
    $rndisInf = Join-Path $env:SystemRoot "INF\rndiscmp.inf"
    if (Test-Path $rndisInf) {
        & $PNPUTIL /add-driver $rndisInf /install 2>&1 | Out-Null
        Start-Sleep 5
        & $PNPUTIL /scan-devices 2>&1 | Out-Null
        Start-Sleep 5
        $rndis = Get-RNDISAdapter
    }

    # Method 2: Restart misidentified device
    if (-not $rndis) {
        $piDev = Get-PnpDevice | Where-Object { $_.InstanceId -match 'VID_0525&PID_A4A2' -and $_.Class -ne 'Net' } | Select-Object -First 1
        if ($piDev) {
            Write-Info $T.DriverRestarting
            & $PNPUTIL /remove-device "$($piDev.InstanceId)" 2>&1 | Out-Null
            Start-Sleep 3
            & $PNPUTIL /scan-devices 2>&1 | Out-Null
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
        Write-Fail $T.DriverFailed
        Write-Info $T.DriverRetry
        Write-Host ""; Write-Host "  $($T.PressKey)" -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown"); exit 1
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

# Remove existing IP config (handles DHCP, multiple IPs, etc.)
Set-NetIPInterface -InterfaceIndex $rndis.ifIndex -Dhcp Disabled -ErrorAction SilentlyContinue
$rndis | Remove-NetIPAddress -Confirm:$false -ErrorAction SilentlyContinue
$rndis | Remove-NetRoute -Confirm:$false -ErrorAction SilentlyContinue
Start-Sleep 2

try {
    New-NetIPAddress -InterfaceIndex $rndis.ifIndex -IPAddress "192.168.7.1" -PrefixLength 24 -ErrorAction Stop | Out-Null
    Write-OK "$($T.IPSet): 192.168.7.1/24"
} catch {
    $existing = Get-NetIPAddress -InterfaceIndex $rndis.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue
    if ($existing -and $existing.IPAddress -eq "192.168.7.1") {
        Write-OK "$($T.IPSet): 192.168.7.1/24"
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
$internetAdapter = Get-InternetAdapter

if ($NoNAT) {
    Write-Info $T.NATDisabled
} elseif (-not $internetAdapter) {
    Write-Warn $T.NoInternet
    Write-Info $T.NoInternetHint
} else {
    Write-Info "$($T.InternetVia): $($internetAdapter.Name)"
    try {
        # Remove any existing NAT for our subnet (handles old names like PiStarNAT too)
        Get-NetNat -ErrorAction SilentlyContinue | Where-Object {
            $_.Name -match 'HolyConnect|PiStar' -or $_.InternalIPInterfaceAddressPrefix -eq '192.168.7.0/24'
        } | Remove-NetNat -Confirm:$false -ErrorAction SilentlyContinue

        New-NetNat -Name "HolyConnectNAT" -InternalIPInterfaceAddressPrefix "192.168.7.0/24" -ErrorAction Stop | Out-Null
        $natActive = $true
        Write-OK $T.NATActive
    } catch {
        if ($_.Exception.Message -match "already exists|overlaps|duplica") {
            # Try to use the existing one
            $existingNat = Get-NetNat -ErrorAction SilentlyContinue | Where-Object {
                $_.InternalIPInterfaceAddressPrefix -eq '192.168.7.0/24'
            }
            if ($existingNat) {
                $natActive = $true
                Write-OK $T.NATExists
            } else {
                # Conflict with another NAT (e.g. Hyper-V Default Switch)
                # Remove ALL NetNat and recreate ours
                try {
                    Get-NetNat -ErrorAction SilentlyContinue | Remove-NetNat -Confirm:$false -ErrorAction SilentlyContinue
                    New-NetNat -Name "HolyConnectNAT" -InternalIPInterfaceAddressPrefix "192.168.7.0/24" -ErrorAction Stop | Out-Null
                    $natActive = $true
                    Write-OK $T.NATActive
                } catch {
                    Write-Warn "$($T.NATFailed): $($_.Exception.Message)"
                    Write-Info $T.NATFailHint
                }
            }
        } else {
            Write-Warn "$($T.NATFailed): $($_.Exception.Message)"
            Write-Info $T.NATFailHint
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
    Write-Host "    http://192.168.7.2/" -ForegroundColor Cyan
}

Write-Host ""
Write-Host "  $($T.PressKey)" -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
