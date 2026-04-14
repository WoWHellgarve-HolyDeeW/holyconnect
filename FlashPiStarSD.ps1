<#
.SYNOPSIS
    HolyConnect - Flash an official Pi-Star image and prepare it for first boot
.DESCRIPTION
    Writes a Pi-Star .img file to an SD card, then patches the boot partition so
    the Pi can self-install HolyConnect on first boot.
.PARAMETER ImagePath
    Optional path to a Pi-Star .img file.
.PARAMETER DiskNumber
    Optional target disk number.
.PARAMETER NoPause
    Exit without waiting for a key press.
.PARAMETER Lang
    Language: 'pt' for Portuguese, 'en' for English.
#>

param(
    [string]$ImagePath,
    [Nullable[int]]$DiskNumber,
    [switch]$SkipWifiSetup,
    [string]$WifiCountry,
    [string]$WifiSSID,
    [string]$WifiPassword,
    [switch]$WifiHidden,
    [switch]$NoPause,
    [ValidateSet('pt','en')][string]$Lang
)

$ErrorActionPreference = 'Stop'
$Host.UI.RawUI.WindowTitle = 'HolyConnect SD Flasher'
$PrepareScriptPath = Join-Path $PSScriptRoot 'PreparePiStarSD.ps1'
$PreferredImageRoot = Join-Path $PSScriptRoot 'pistar-image'
$script:GeneratedWifiConfigPath = $null

try {
    Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;

public static class HolyConnectRawDiskNative {
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    public static extern SafeFileHandle CreateFile(
        string lpFileName,
        uint dwDesiredAccess,
        uint dwShareMode,
        IntPtr lpSecurityAttributes,
        uint dwCreationDisposition,
        uint dwFlagsAndAttributes,
        IntPtr hTemplateFile);

    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool DeviceIoControl(
        SafeFileHandle hDevice,
        uint dwIoControlCode,
        IntPtr lpInBuffer,
        uint nInBufferSize,
        IntPtr lpOutBuffer,
        uint nOutBufferSize,
        out uint lpBytesReturned,
        IntPtr lpOverlapped);
}
"@ -ErrorAction Stop
} catch {
    if (-not $_.Exception.Message.Contains('already exists')) {
        throw
    }
}

$RAW_DISK_GENERIC_READ = [uint32]2147483648
$RAW_DISK_GENERIC_WRITE = [uint32]1073741824
$RAW_DISK_FILE_SHARE_READ = [uint32]1
$RAW_DISK_FILE_SHARE_WRITE = [uint32]2
$RAW_DISK_OPEN_EXISTING = [uint32]3
$RAW_DISK_FILE_ATTRIBUTE_NORMAL = [uint32]128
$RAW_DISK_FSCTL_LOCK_VOLUME = [uint32]589848
$RAW_DISK_FSCTL_DISMOUNT_VOLUME = [uint32]589856

if (-not $Lang) {
    $sysLang = (Get-Culture).TwoLetterISOLanguageName
    $Lang = if ($sysLang -eq 'pt') { 'pt' } else { 'en' }
}

$T = @{}
if ($Lang -eq 'pt') {
    $T.Title                = 'HolyConnect - Gravar e preparar cartao Pi-Star'
    $T.Step1                = 'A procurar imagem Pi-Star...'
    $T.Step2                = 'A escolher disco de destino...'
    $T.Step3                = 'A gravar imagem no cartao SD...'
    $T.Step4                = 'A preparar a particao boot para o HolyConnect...'
    $T.Intro1               = 'Este helper grava o Pi-Star oficial no cartao SD e prepara logo o primeiro boot do HolyConnect.'
    $T.Intro2               = 'O ficheiro .zip ou .img do Pi-Star pode estar em qualquer pasta do PC.'
    $T.Intro3               = 'A pasta recomendada para o download e: {0}'
    $T.Intro4               = 'Se nao encontrar, abre um seletor de ficheiro ou pede o caminho manual.'
    $T.Intro5               = 'Opcional: o flasher pode tambem gerar a configuracao Wi-Fi durante este processo.'
    $T.AdminRequired        = 'PRECISA CORRER COMO ADMINISTRADOR!'
    $T.AdminHint            = 'Usa o ficheiro .bat por duplo-clique ou abre PowerShell como Administrador.'
    $T.PrepareMissing       = 'Nao encontrei PreparePiStarSD.ps1. Extrai o pacote completo do HolyConnect antes de usar este flasher.'
    $T.ImagePrompt          = 'Indica o caminho para o ficheiro .zip ou .img oficial do Pi-Star'
    $T.ImageInvalid         = 'Imagem Pi-Star invalida ou inexistente (.zip ou .img): {0}'
    $T.ImageFound           = 'Imagem selecionada: {0}'
    $T.ImageAutoSelected    = 'Foi encontrada a mesma imagem Pi-Star em varios formatos. Vai ser usada automaticamente: {0}'
    $T.MultipleImages       = 'Foram encontrados varios ficheiros Pi-Star (.zip/.img):'
    $T.ChooseImage          = 'Escolhe o numero da imagem a usar'
    $T.NoImages             = 'Nenhum ficheiro Pi-Star (.zip/.img) foi encontrado automaticamente ao lado do HolyConnect ou na pasta acima.'
    $T.ArchiveExtracting    = 'A extrair arquivo Pi-Star para {0}...'
    $T.ArchiveReady         = 'Imagem extraida pronta: {0}'
    $T.ArchiveReuse         = 'A reutilizar imagem ja extraida: {0}'
    $T.ArchiveNoImage       = 'O arquivo nao contem uma imagem Pi-Star utilizavel: {0}'
    $T.ArchiveUnsupported   = 'Este Windows nao tem Expand-Archive disponivel para extrair o .zip automaticamente.'
    $T.FilePickerTitle      = 'Escolhe o ficheiro Pi-Star (.zip ou .img)'
    $T.FilePickerFailed     = 'Nao foi possivel abrir o seletor de ficheiro neste Windows. Indica o caminho manualmente.'
    $T.ImageFolderReady     = 'Pasta recomendada pronta: {0}'
    $T.NoDisks              = 'Nao encontrei discos USB/SD seguros para gravar. Liga o leitor de cartoes e tenta de novo.'
    $T.MultipleDisks        = 'Discos candidatos:'
    $T.AutoSelectedDisk     = 'Foi encontrado um unico disco USB/SD seguro. Vai ser usado automaticamente.'
    $T.ChooseDisk           = 'Escolhe o numero do disco de destino'
    $T.DiskInvalid          = 'O disco escolhido nao e valido para esta operacao: {0}'
    $T.TargetDisk           = 'Disco de destino: {0} - {1} - {2} GB'
    $T.ConfirmErase         = 'ATENCAO: todo o conteudo desse disco vai ser apagado. Escreve YES para continuar'
    $T.Cancelled            = 'Operacao cancelada pelo utilizador.'
    $T.DiskPreparing        = 'A desmontar volumes do cartao SD para gravacao direta...'
    $T.RawWriteDenied       = 'O Windows ainda esta a usar o cartao SD. Fecha Explorador/Fotos/antivirus nesse cartao, remove a letra se aparecer montada, e tenta de novo.'
    $T.WritingProgress      = 'Gravado {0}% ({1} GB / {2} GB)'
    $T.WriteDone            = 'Imagem escrita com sucesso'
    $T.BootWait             = 'A aguardar que o Windows monte a particao boot do Pi-Star...'
    $T.BootReady            = 'Particao boot pronta: {0}'
    $T.WifiExisting         = 'Foi encontrado pistar-image\wpa_supplicant.conf. Essa configuracao Wi-Fi vai ser usada.'
    $T.WifiOffer            = 'Queres deixar o Wi-Fi preconfigurado no SD agora? [S/N]'
    $T.WifiCountryPrompt    = 'Pais Wi-Fi (Enter para {0})'
    $T.WifiSsidPrompt       = 'Nome da rede Wi-Fi (SSID)'
    $T.WifiPasswordPrompt   = 'Password Wi-Fi'
    $T.WifiHiddenPrompt     = 'Rede oculta? [s/N]'
    $T.WifiGenerated        = 'Configuracao Wi-Fi gerada automaticamente para este flash.'
    $T.WifiSkipped          = 'Wi-Fi nao configurado neste flash. O modo USB HolyConnect continua a funcionar.'
    $T.WifiInvalid          = 'SSID e password Wi-Fi nao podem ficar vazios.'
    $T.Prepared             = 'Cartao SD pronto para o primeiro arranque do HolyConnect.'
    $T.NextStep1            = 'Coloca o cartao no Pi e arranca uma vez.'
    $T.NextStep2            = 'Depois do reboot automatico, usa HolyConnect.bat normalmente.'
    $T.PressKey             = 'Prima qualquer tecla para sair...'
} else {
    $T.Title                = 'HolyConnect - Flash and prepare Pi-Star SD card'
    $T.Step1                = 'Searching for Pi-Star image...'
    $T.Step2                = 'Choosing target disk...'
    $T.Step3                = 'Writing image to the SD card...'
    $T.Step4                = 'Preparing the boot partition for HolyConnect...'
    $T.Intro1               = 'This helper writes the official Pi-Star image to the SD card and also prepares the first HolyConnect boot.'
    $T.Intro2               = 'The Pi-Star .zip or .img can live in any folder on the PC.'
    $T.Intro3               = 'The recommended download folder is: {0}'
    $T.Intro4               = 'If it is not found, the helper opens a file picker or asks for the path manually.'
    $T.Intro5               = 'Optional: the flasher can also generate Wi-Fi config during this process.'
    $T.AdminRequired        = 'MUST RUN AS ADMINISTRATOR!'
    $T.AdminHint            = 'Use the .bat launcher or open PowerShell as Administrator.'
    $T.PrepareMissing       = 'Could not find PreparePiStarSD.ps1. Extract the full HolyConnect package before using this flasher.'
    $T.ImagePrompt          = 'Enter the path to the official Pi-Star .zip or .img file'
    $T.ImageInvalid         = 'Invalid or missing Pi-Star image (.zip or .img): {0}'
    $T.ImageFound           = 'Selected image: {0}'
    $T.ImageAutoSelected    = 'The same Pi-Star image was found in multiple formats. It will be used automatically: {0}'
    $T.MultipleImages       = 'Multiple Pi-Star files (.zip/.img) were found:'
    $T.ChooseImage          = 'Choose the number of the image to use'
    $T.NoImages             = 'No Pi-Star file (.zip/.img) was found automatically next to HolyConnect or in the parent folder.'
    $T.ArchiveExtracting    = 'Extracting Pi-Star archive to {0}...'
    $T.ArchiveReady         = 'Extracted image ready: {0}'
    $T.ArchiveReuse         = 'Reusing already extracted image: {0}'
    $T.ArchiveNoImage       = 'The archive does not contain a usable Pi-Star image: {0}'
    $T.ArchiveUnsupported   = 'This Windows build does not have Expand-Archive available for automatic .zip extraction.'
    $T.FilePickerTitle      = 'Choose the Pi-Star file (.zip or .img)'
    $T.FilePickerFailed     = 'Could not open a file picker on this Windows build. Enter the path manually.'
    $T.ImageFolderReady     = 'Recommended image folder ready: {0}'
    $T.NoDisks              = 'No safe USB/SD target disks were found. Connect the card reader and try again.'
    $T.MultipleDisks        = 'Candidate disks:'
    $T.AutoSelectedDisk     = 'A single safe USB/SD target was found. It will be used automatically.'
    $T.ChooseDisk           = 'Choose the number of the target disk'
    $T.DiskInvalid          = 'The selected disk is not valid for this operation: {0}'
    $T.TargetDisk           = 'Target disk: {0} - {1} - {2} GB'
    $T.ConfirmErase         = 'WARNING: all content on that disk will be erased. Type YES to continue'
    $T.Cancelled            = 'Operation cancelled by user.'
    $T.DiskPreparing        = 'Dismounting SD card volumes for raw write...'
    $T.RawWriteDenied       = 'Windows is still using the SD card. Close Explorer/Photos/antivirus on that card, remove its drive letter if it stays mounted, and try again.'
    $T.WritingProgress      = 'Written {0}% ({1} GB / {2} GB)'
    $T.WriteDone            = 'Image written successfully'
    $T.BootWait             = 'Waiting for Windows to mount the Pi-Star boot partition...'
    $T.BootReady            = 'Boot partition ready: {0}'
    $T.WifiExisting         = 'Found pistar-image\wpa_supplicant.conf. That Wi-Fi config will be used.'
    $T.WifiOffer            = 'Do you want Wi-Fi preconfigured on the SD now? [Y/N]'
    $T.WifiCountryPrompt    = 'Wi-Fi country code (Enter for {0})'
    $T.WifiSsidPrompt       = 'Wi-Fi network name (SSID)'
    $T.WifiPasswordPrompt   = 'Wi-Fi password'
    $T.WifiHiddenPrompt     = 'Hidden network? [y/N]'
    $T.WifiGenerated        = 'Wi-Fi configuration generated automatically for this flash.'
    $T.WifiSkipped          = 'Wi-Fi was not configured in this flash. HolyConnect USB mode still works.'
    $T.WifiInvalid          = 'Wi-Fi SSID and password cannot be empty.'
    $T.Prepared             = 'SD card ready for HolyConnect first boot.'
    $T.NextStep1            = 'Put the card into the Pi and boot once.'
    $T.NextStep2            = 'After the automatic reboot, use HolyConnect.bat normally.'
    $T.PressKey             = 'Press any key to exit...'
}

function Write-Step($msg) { Write-Host "`n$msg" -ForegroundColor Yellow }
function Write-OK($msg) { Write-Host "  [OK] $msg" -ForegroundColor Green }
function Write-Info($msg) { Write-Host "  $msg" -ForegroundColor Gray }
function Write-Fail($msg) { Write-Host "  [X] $msg" -ForegroundColor Red }

function Test-YesAnswer {
    param([string]$Value)

    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    return $Value.Trim().ToLowerInvariant() -in @('y','yes','s','sim')
}

function Get-DefaultWifiCountry {
    try {
        $region = [System.Globalization.RegionInfo]::CurrentRegion.TwoLetterISORegionName
        if ($region -and $region.Length -eq 2) {
            return $region.ToUpperInvariant()
        }
    } catch {}

    return 'PT'
}

function ConvertTo-PlainText {
    param([Security.SecureString]$SecureString)

    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
    try {
        return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    }
    finally {
        if ($bstr -ne [IntPtr]::Zero) {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        }
    }
}

function New-WifiConfigFile {
    param(
        [string]$Country,
        [string]$SSID,
        [string]$Password,
        [bool]$Hidden
    )

    $tempDir = Join-Path $env:TEMP 'HolyConnect'
    if (-not (Test-Path -LiteralPath $tempDir)) {
        New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
    }

    $path = Join-Path $tempDir ('wpa_supplicant_{0}.conf' -f ([Guid]::NewGuid().ToString('N').Substring(0, 8)))
    $scanValue = if ($Hidden) { '1' } else { '0' }
    $content = @(
        "country=$Country"
        'ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev'
        'update_config=1'
        ''
        'network={'
        "    ssid=`"$SSID`""
        "    psk=`"$Password`""
        "    scan_ssid=$scanValue"
        '}'
    )

    Set-Content -Path $path -Value $content -Encoding ASCII
    $script:GeneratedWifiConfigPath = $path
    return $path
}

function Resolve-WifiConfigPath {
    if (Test-Path -LiteralPath (Join-Path $PreferredImageRoot 'wpa_supplicant.conf')) {
        Write-Info $T.WifiExisting
        return (Join-Path $PreferredImageRoot 'wpa_supplicant.conf')
    }

    if ($WifiSSID -and $WifiPassword) {
        $country = if ($WifiCountry) { $WifiCountry.ToUpperInvariant() } else { Get-DefaultWifiCountry }
        $path = New-WifiConfigFile -Country $country -SSID $WifiSSID -Password $WifiPassword -Hidden ([bool]$WifiHidden)
        Write-OK $T.WifiGenerated
        return $path
    }

    if ($SkipWifiSetup -or $NoPause) {
        Write-Info $T.WifiSkipped
        return $null
    }

    $answer = Read-Host "$($T.WifiOffer)"
    if (-not (Test-YesAnswer $answer)) {
        Write-Info $T.WifiSkipped
        return $null
    }

    $defaultCountry = if ($WifiCountry) { $WifiCountry.ToUpperInvariant() } else { Get-DefaultWifiCountry }
    $enteredCountry = Read-Host ($T.WifiCountryPrompt -f $defaultCountry)
    $country = if ([string]::IsNullOrWhiteSpace($enteredCountry)) { $defaultCountry } else { $enteredCountry.Trim().ToUpperInvariant() }
    $ssid = Read-Host "$($T.WifiSsidPrompt)"
    $securePassword = Read-Host "$($T.WifiPasswordPrompt)" -AsSecureString
    $password = ConvertTo-PlainText -SecureString $securePassword
    if ([string]::IsNullOrWhiteSpace($ssid) -or [string]::IsNullOrWhiteSpace($password)) {
        throw $T.WifiInvalid
    }

    $hiddenAnswer = Read-Host "$($T.WifiHiddenPrompt)"
    $hidden = Test-YesAnswer $hiddenAnswer
    $path = New-WifiConfigFile -Country $country -SSID $ssid.Trim() -Password $password -Hidden $hidden
    Write-OK $T.WifiGenerated
    return $path
}

function Test-IsAdministrator {
    $principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Ensure-PreferredImageRoot {
    if (-not (Test-Path -LiteralPath $PreferredImageRoot)) {
        New-Item -ItemType Directory -Path $PreferredImageRoot -Force | Out-Null
    }
    Write-Info ($T.ImageFolderReady -f $PreferredImageRoot)
}

function Select-ImageFile {
    try {
        Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
        $dialog = New-Object System.Windows.Forms.OpenFileDialog
        $dialog.Title = $T.FilePickerTitle
        $dialog.Filter = 'Pi-Star files (*.zip;*.img)|*.zip;*.img|Zip files (*.zip)|*.zip|Image files (*.img)|*.img|All files (*.*)|*.*'
        $dialog.Multiselect = $false
        $dialog.CheckFileExists = $true

        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            return $dialog.FileName
        }
    } catch {
        Write-Info $T.FilePickerFailed
    }

    return $null
}

function Add-UniquePath {
    param(
        [System.Collections.Generic.List[string]]$List,
        [string]$Path
    )

    if ($Path -and $Path -notin $List) {
        $List.Add($Path)
    }
}

function Normalize-SearchRoot {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }

    $candidate = $Path.Trim()
    if ($candidate -match '^[A-Za-z]$') {
        $candidate = '{0}:\' -f $candidate
    } elseif ($candidate -match '^[A-Za-z]:$') {
        $candidate = '{0}\' -f $candidate
    }

    return $candidate
}

function Get-SafeSearchRoots {
    $roots = [System.Collections.Generic.List[string]]::new()
    $rawRoots = @($PreferredImageRoot, $PSScriptRoot, (Split-Path $PSScriptRoot -Parent)) | Where-Object { $_ }

    foreach ($rawRoot in $rawRoots) {
        $candidate = Normalize-SearchRoot -Path $rawRoot
        if (-not $candidate) { continue }

        try {
            if (-not (Test-Path -LiteralPath $candidate)) {
                continue
            }

            $resolved = (Resolve-Path -LiteralPath $candidate -ErrorAction Stop).Path
            Add-UniquePath -List $roots -Path $resolved
        } catch {
            continue
        }
    }

    return @($roots)
}

function Get-ImageCandidates {
    $paths = [System.Collections.Generic.List[string]]::new()

    $searchRoots = Get-SafeSearchRoots
    foreach ($root in $searchRoots) {
        foreach ($pattern in @('Pi-Star*.img', 'Pi-Star*.zip')) {
            Get-ChildItem -LiteralPath $root -Filter $pattern -File -ErrorAction SilentlyContinue |
                ForEach-Object { Add-UniquePath -List $paths -Path $_.FullName }
        }

        Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -like 'Pi-Star*' } |
            ForEach-Object {
                foreach ($pattern in @('Pi-Star*.img', 'Pi-Star*.zip')) {
                    Get-ChildItem -LiteralPath $_.FullName -Filter $pattern -File -ErrorAction SilentlyContinue |
                        ForEach-Object { Add-UniquePath -List $paths -Path $_.FullName }
                }
            }
    }

    return @($paths)
}

function Get-ImageReleaseKey {
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $null
    }

    return [System.IO.Path]::GetFileNameWithoutExtension($Path).ToLowerInvariant()
}

function Get-ImageCandidateScore {
    param([string]$Path)

    $score = 0
    $extension = [System.IO.Path]::GetExtension($Path)
    if ($extension -ieq '.img') {
        $score += 100
    } elseif ($extension -ieq '.zip') {
        $score += 10
    }

    if ($Path.StartsWith((Join-Path $PreferredImageRoot 'extracted'), [System.StringComparison]::OrdinalIgnoreCase)) {
        $score += 300
    } elseif ($Path.StartsWith($PreferredImageRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        $score += 200
    }

    return $score
}

function Resolve-AutoImageCandidate {
    param([string[]]$Candidates)

    if (-not $Candidates -or $Candidates.Count -lt 2) {
        return $null
    }

    $groups = @($Candidates | Group-Object { Get-ImageReleaseKey -Path $_ })
    if ($groups.Count -ne 1) {
        return $null
    }

    return ($groups[0].Group |
        Sort-Object @{ Expression = { Get-ImageCandidateScore -Path $_ }; Descending = $true }, @{ Expression = { $_ } } |
        Select-Object -First 1)
}

function Resolve-ImageFile {
    param([string]$SourcePath)

    $resolvedSourcePath = (Resolve-Path -LiteralPath $SourcePath).Path
    $extension = [System.IO.Path]::GetExtension($resolvedSourcePath)
    if ($extension -ieq '.img') {
        return $resolvedSourcePath
    }

    if ($extension -ieq '.zip') {
        if (-not (Get-Command Expand-Archive -ErrorAction SilentlyContinue)) {
            throw $T.ArchiveUnsupported
        }

        Ensure-PreferredImageRoot
        $extractRoot = Join-Path (Join-Path $PreferredImageRoot 'extracted') ([System.IO.Path]::GetFileNameWithoutExtension($resolvedSourcePath))
        $existingImage = Get-ChildItem -LiteralPath $extractRoot -Filter 'Pi-Star*.img' -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($existingImage) {
            Write-Info ($T.ArchiveReuse -f $existingImage.FullName)
            return $existingImage.FullName
        }

        if (-not (Test-Path -LiteralPath $extractRoot)) {
            New-Item -ItemType Directory -Path $extractRoot -Force | Out-Null
        }

        Write-Info ($T.ArchiveExtracting -f $extractRoot)
        Expand-Archive -LiteralPath $resolvedSourcePath -DestinationPath $extractRoot -Force

        $extractedImage = Get-ChildItem -LiteralPath $extractRoot -Filter 'Pi-Star*.img' -File -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
        if (-not $extractedImage) {
            throw ($T.ArchiveNoImage -f $resolvedSourcePath)
        }

        Write-OK ($T.ArchiveReady -f $extractedImage.FullName)
        return $extractedImage.FullName
    }

    throw ($T.ImageInvalid -f $resolvedSourcePath)
}

function Resolve-ImagePath {
    param([string]$RequestedPath)

    if ($RequestedPath) {
        if (-not (Test-Path -LiteralPath $RequestedPath)) {
            throw ($T.ImageInvalid -f $RequestedPath)
        }
        return Resolve-ImageFile -SourcePath $RequestedPath
    }

    $candidates = Get-ImageCandidates
    if ($candidates.Count -eq 1) {
        return Resolve-ImageFile -SourcePath $candidates[0]
    }

    $autoCandidate = Resolve-AutoImageCandidate -Candidates $candidates
    if ($autoCandidate) {
        Write-Info ($T.ImageAutoSelected -f $autoCandidate)
        return Resolve-ImageFile -SourcePath $autoCandidate
    }

    if ($candidates.Count -gt 1) {
        Write-Info $T.MultipleImages
        for ($i = 0; $i -lt $candidates.Count; $i++) {
            Write-Host ("  {0}. {1}" -f ($i + 1), $candidates[$i]) -ForegroundColor White
        }

        while ($true) {
            $choice = Read-Host "$($T.ChooseImage)"
            $parsed = 0
            if ([int]::TryParse($choice, [ref]$parsed) -and $parsed -ge 1 -and $parsed -le $candidates.Count) {
                return Resolve-ImageFile -SourcePath $candidates[$parsed - 1]
            }
        }
    }

    Write-Info $T.NoImages
    $selectedPath = Select-ImageFile
    if ($selectedPath) {
        return Resolve-ImageFile -SourcePath $selectedPath
    }

    $manualPath = Read-Host "$($T.ImagePrompt)"
    if ([string]::IsNullOrWhiteSpace($manualPath)) {
        throw $T.Cancelled
    }

    if (-not (Test-Path -LiteralPath $manualPath)) {
        throw ($T.ImageInvalid -f $manualPath)
    }

    return Resolve-ImageFile -SourcePath $manualPath
}

function Get-TargetDiskCandidates {
    param([long]$ImageSize)

    $safeBusTypes = @('USB', 'SD', 'MMC', 'Unknown')
    return @(Get-Disk -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Number -ne 0 -and
            -not $_.IsBoot -and
            -not $_.IsSystem -and
            $_.Size -ge $ImageSize -and
            ($safeBusTypes -contains [string]$_.BusType)
        } |
        Sort-Object Number)
}

function Resolve-TargetDisk {
    param(
        [Nullable[int]]$RequestedDiskNumber,
        [long]$ImageSize
    )

    $candidates = Get-TargetDiskCandidates -ImageSize $ImageSize
    if (-not $candidates) {
        throw $T.NoDisks
    }

    if ($candidates.Count -eq 1 -and -not $RequestedDiskNumber.HasValue) {
        Write-Info $T.AutoSelectedDisk
        return $candidates[0]
    }

    if ($RequestedDiskNumber.HasValue) {
        $selected = $candidates | Where-Object { $_.Number -eq $RequestedDiskNumber.Value } | Select-Object -First 1
        if (-not $selected) {
            throw ($T.DiskInvalid -f $RequestedDiskNumber.Value)
        }
        return $selected
    }

    Write-Info $T.MultipleDisks
    foreach ($disk in $candidates) {
        Write-Host ("  {0}. {1} | {2} | {3} GB" -f $disk.Number, $disk.FriendlyName, $disk.BusType, [math]::Round($disk.Size / 1GB, 2)) -ForegroundColor White
    }

    while ($true) {
        $choice = Read-Host "$($T.ChooseDisk)"
        $parsed = 0
        if ([int]::TryParse($choice, [ref]$parsed)) {
            $selected = $candidates | Where-Object { $_.Number -eq $parsed } | Select-Object -First 1
            if ($selected) { return $selected }
        }
    }
}

function Confirm-DestructiveWrite {
    $confirmation = Read-Host "$($T.ConfirmErase)"
    if ([string]::IsNullOrWhiteSpace($confirmation)) {
        throw $T.Cancelled
    }

    if (-not (Test-YesAnswer $confirmation) -and $confirmation.Trim().ToUpperInvariant() -ne 'YES') {
        throw $T.Cancelled
    }
}

function Prepare-TargetDiskForRawWrite {
    param([int]$TargetDiskNumber)

    Write-Info $T.DiskPreparing

    $partitions = @(Get-Partition -DiskNumber $TargetDiskNumber -ErrorAction SilentlyContinue | Sort-Object PartitionNumber)
    foreach ($partition in $partitions) {
        $accessPaths = @($partition.AccessPaths | Where-Object { $_ -and $_ -match '^[A-Z]:\\$' })
        foreach ($accessPath in $accessPaths) {
            $driveLetter = $accessPath.Substring(0, 1)

            if (Get-Command Dismount-Volume -ErrorAction SilentlyContinue) {
                try {
                    Dismount-Volume -DriveLetter $driveLetter -Force -ErrorAction Stop | Out-Null
                } catch {}
            }

            try {
                Remove-PartitionAccessPath -DiskNumber $TargetDiskNumber -PartitionNumber $partition.PartitionNumber -AccessPath $accessPath -ErrorAction Stop
            } catch {}
        }
    }

    try {
        Update-HostStorageCache
    } catch {}
}

function Open-TargetVolumeHandle {
    param([string]$VolumePath)

    $handle = [HolyConnectRawDiskNative]::CreateFile(
        $VolumePath,
        ($RAW_DISK_GENERIC_READ -bor $RAW_DISK_GENERIC_WRITE),
        ($RAW_DISK_FILE_SHARE_READ -bor $RAW_DISK_FILE_SHARE_WRITE),
        [IntPtr]::Zero,
        $RAW_DISK_OPEN_EXISTING,
        $RAW_DISK_FILE_ATTRIBUTE_NORMAL,
        [IntPtr]::Zero)

    if ($handle.IsInvalid) {
        $win32Error = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        throw "CreateFile failed for $VolumePath (Win32 error $win32Error)"
    }

    return $handle
}

function Invoke-TargetVolumeControl {
    param(
        [Microsoft.Win32.SafeHandles.SafeFileHandle]$Handle,
        [uint32]$ControlCode,
        [string]$Label
    )

    $bytesReturned = [uint32]0
    $ok = [HolyConnectRawDiskNative]::DeviceIoControl($Handle, $ControlCode, [IntPtr]::Zero, 0, [IntPtr]::Zero, 0, [ref]$bytesReturned, [IntPtr]::Zero)
    if (-not $ok) {
        $win32Error = [Runtime.InteropServices.Marshal]::GetLastWin32Error()
        throw "$Label failed (Win32 error $win32Error)"
    }
}

function Acquire-TargetVolumeLocks {
    param([int]$TargetDiskNumber)

    $handles = [System.Collections.Generic.List[Microsoft.Win32.SafeHandles.SafeFileHandle]]::new()
    $partitions = @(Get-Partition -DiskNumber $TargetDiskNumber -ErrorAction SilentlyContinue | Sort-Object PartitionNumber)

    foreach ($partition in $partitions) {
        if ([string]$partition.Type -match '^Unknown$|Reserved') {
            continue
        }

        $driveLetter = $partition.DriveLetter
        if (-not $driveLetter) {
            try {
                Add-PartitionAccessPath -DiskNumber $TargetDiskNumber -PartitionNumber $partition.PartitionNumber -AssignDriveLetter -ErrorAction Stop
            } catch {}

            try {
                $partition = Get-Partition -DiskNumber $TargetDiskNumber -PartitionNumber $partition.PartitionNumber -ErrorAction Stop
                $driveLetter = $partition.DriveLetter
            } catch {}
        }

        if (-not $driveLetter) {
            continue
        }

        $volume = $null
        try { $volume = Get-Volume -DriveLetter $driveLetter -ErrorAction Stop } catch {}
        if (-not $volume -or [string]::IsNullOrWhiteSpace($volume.FileSystem)) {
            continue
        }

        $volumePath = '\\.\{0}:' -f $driveLetter
        $handle = $null
        try {
            $handle = Open-TargetVolumeHandle -VolumePath $volumePath
            Invoke-TargetVolumeControl -Handle $handle -ControlCode $RAW_DISK_FSCTL_LOCK_VOLUME -Label 'FSCTL_LOCK_VOLUME'
            Invoke-TargetVolumeControl -Handle $handle -ControlCode $RAW_DISK_FSCTL_DISMOUNT_VOLUME -Label 'FSCTL_DISMOUNT_VOLUME'
            $handles.Add($handle)
        } catch {
            if ($handle) {
                $handle.Dispose()
            }
        }
    }

    return @($handles)
}

function Release-TargetVolumeLocks {
    param([object[]]$Handles)

    foreach ($handle in @($Handles)) {
        if ($handle -and -not $handle.IsClosed) {
            $handle.Dispose()
        }
    }
}

function Set-TargetDiskOfflineState {
    param(
        [int]$TargetDiskNumber,
        [bool]$IsOffline
    )

    $diskPartExe = Join-Path $env:SystemRoot 'System32\diskpart.exe'
    $diskPartScriptPath = $null

    try {
        Set-Disk -Number $TargetDiskNumber -IsOffline $IsOffline -ErrorAction Stop
        try {
            Update-HostStorageCache
        } catch {}
        return $true
    } catch {
        if (-not (Test-Path -LiteralPath $diskPartExe)) {
            return $false
        }

        $diskPartScriptPath = Join-Path $env:TEMP ('holyconnect_diskpart_{0}.txt' -f ([Guid]::NewGuid().ToString('N')))
        $diskPartAction = if ($IsOffline) { 'offline disk' } else { 'online disk' }

        try {
            Set-Content -Path $diskPartScriptPath -Value @(
                ('select disk {0}' -f $TargetDiskNumber),
                $diskPartAction
            ) -Encoding ASCII

            & $diskPartExe /s $diskPartScriptPath | Out-Null
            if ($LASTEXITCODE -ne 0) {
                return $false
            }

            try {
                Update-HostStorageCache
            } catch {}
            return $true
        } catch {
            return $false
        } finally {
            if ($diskPartScriptPath -and (Test-Path -LiteralPath $diskPartScriptPath)) {
                Remove-Item -LiteralPath $diskPartScriptPath -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

function Clear-TargetDiskReadOnly {
    param([int]$TargetDiskNumber)

    $diskPartExe = Join-Path $env:SystemRoot 'System32\diskpart.exe'
    $diskPartScriptPath = $null

    try {
        Set-Disk -Number $TargetDiskNumber -IsReadOnly $false -ErrorAction Stop
        return $true
    } catch {
        if (-not (Test-Path -LiteralPath $diskPartExe)) {
            return $false
        }

        $diskPartScriptPath = Join-Path $env:TEMP ('holyconnect_diskpart_{0}.txt' -f ([Guid]::NewGuid().ToString('N')))
        try {
            Set-Content -Path $diskPartScriptPath -Value @(
                ('select disk {0}' -f $TargetDiskNumber),
                'attributes disk clear readonly'
            ) -Encoding ASCII

            & $diskPartExe /s $diskPartScriptPath | Out-Null
            return ($LASTEXITCODE -eq 0)
        } catch {
            return $false
        } finally {
            if ($diskPartScriptPath -and (Test-Path -LiteralPath $diskPartScriptPath)) {
                Remove-Item -LiteralPath $diskPartScriptPath -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

function Write-ImageToDisk {
    param(
        [string]$ResolvedImagePath,
        [int]$TargetDiskNumber
    )

    $disk = Get-Disk -Number $TargetDiskNumber -ErrorAction Stop
    if ($disk.IsReadOnly) {
        $null = Clear-TargetDiskReadOnly -TargetDiskNumber $TargetDiskNumber
    }

    Prepare-TargetDiskForRawWrite -TargetDiskNumber $TargetDiskNumber

    $diskWasOffline = [bool]$disk.IsOffline
    $diskOfflinedForWrite = $false
    $volumeLocks = @()
    $source = $null
    $target = $null
    $writeDenied = $false

    try {
        if (-not $diskWasOffline) {
            $diskOfflinedForWrite = Set-TargetDiskOfflineState -TargetDiskNumber $TargetDiskNumber -IsOffline $true
        }

        $source = [System.IO.File]::Open($ResolvedImagePath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::Read)
        $openTargetError = $null
        foreach ($attempt in 1..3) {
            Release-TargetVolumeLocks -Handles $volumeLocks
            $volumeLocks = Acquire-TargetVolumeLocks -TargetDiskNumber $TargetDiskNumber

            try {
                $target = New-Object System.IO.FileStream("\\.\PhysicalDrive$TargetDiskNumber", [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite, [System.IO.FileShare]::None)
                $openTargetError = $null
                $writeDenied = $false
                break
            }
            catch [System.UnauthorizedAccessException] {
                $writeDenied = $true
                $openTargetError = $_
            }
            catch [System.IO.IOException] {
                if ($_.Exception.Message -match 'access|denied|acesso negado|sharing violation') {
                    $writeDenied = $true
                    $openTargetError = $_
                } else {
                    throw
                }
            }

            if ($attempt -lt 3) {
                Release-TargetVolumeLocks -Handles $volumeLocks
                $volumeLocks = @()
                Prepare-TargetDiskForRawWrite -TargetDiskNumber $TargetDiskNumber
                if (-not $diskWasOffline -and -not $diskOfflinedForWrite) {
                    $diskOfflinedForWrite = Set-TargetDiskOfflineState -TargetDiskNumber $TargetDiskNumber -IsOffline $true
                }
                Start-Sleep -Seconds 2
                continue
            }
        }

        if (-not $target) {
            if ($openTargetError) {
                throw $openTargetError.Exception
            }
            throw $T.RawWriteDenied
        }

        $buffer = New-Object byte[] (4MB)
        $written = 0L
        $nextReport = 256MB

        while (($read = $source.Read($buffer, 0, $buffer.Length)) -gt 0) {
            $target.Write($buffer, 0, $read)
            $written += $read

            if ($written -ge $nextReport) {
                $pct = [math]::Round(($written / $source.Length) * 100, 1)
                Write-Info ($T.WritingProgress -f $pct, [math]::Round($written / 1GB, 2), [math]::Round($source.Length / 1GB, 2))
                $nextReport += 256MB
            }
        }

        $target.Flush()
    }
    catch [System.UnauthorizedAccessException] {
        $writeDenied = $true
        throw
    }
    catch [System.IO.IOException] {
        if ($_.Exception.Message -match 'access|denied|acesso negado') {
            $writeDenied = $true
        }
        throw
    }
    finally {
        if ($target) { $target.Dispose() }
        if ($source) { $source.Dispose() }
        Release-TargetVolumeLocks -Handles $volumeLocks

        if ($diskOfflinedForWrite) {
            $null = Set-TargetDiskOfflineState -TargetDiskNumber $TargetDiskNumber -IsOffline $false
        }

        try {
            Update-HostStorageCache
        } catch {}

        if ($writeDenied) {
            throw $T.RawWriteDenied
        }
    }
}

function Test-PiStarBootRoot {
    param([string]$Root)

    if ([string]::IsNullOrWhiteSpace($Root)) { return $false }
    foreach ($name in @('cmdline.txt', 'config.txt', 'start.elf')) {
        if (-not (Test-Path -LiteralPath (Join-Path $Root $name))) { return $false }
    }
    return (Test-Path -LiteralPath (Join-Path $Root 'overlays'))
}

function Wait-BootPartitionRoot {
    param([int]$TargetDiskNumber)

    Write-Info $T.BootWait
    $deadline = (Get-Date).AddMinutes(2)
    while ((Get-Date) -lt $deadline) {
        try {
            Update-HostStorageCache
        } catch {}

        $bootPartition = Get-Partition -DiskNumber $TargetDiskNumber -ErrorAction SilentlyContinue |
            Sort-Object PartitionNumber |
            ForEach-Object {
                $volume = $null
                try { $volume = $_ | Get-Volume -ErrorAction Stop } catch {}
                [pscustomobject]@{ Partition = $_; Volume = $volume }
            } |
            Where-Object { $_.Volume -and $_.Volume.FileSystem -match '^FAT' } |
            Select-Object -First 1

        if ($bootPartition) {
            if (-not $bootPartition.Partition.DriveLetter) {
                try {
                    Add-PartitionAccessPath -DiskNumber $TargetDiskNumber -PartitionNumber $bootPartition.Partition.PartitionNumber -AssignDriveLetter -ErrorAction Stop
                } catch {}
                Start-Sleep -Seconds 2
                continue
            }

            $root = "$($bootPartition.Partition.DriveLetter):\"
            if (Test-PiStarBootRoot -Root $root) {
                return $root
            }
        }

        Start-Sleep -Seconds 3
    }

    throw 'Timed out waiting for the Pi-Star boot partition to become available.'
}

Clear-Host
Write-Host ''
Write-Host '  ============================================' -ForegroundColor Cyan
Write-Host '   HolyConnect - Pi-Star SD Flash Helper     ' -ForegroundColor Cyan
Write-Host '  ============================================' -ForegroundColor Cyan
Write-Host ''
Ensure-PreferredImageRoot

if (-not (Test-IsAdministrator)) {
    Write-Fail $T.AdminRequired
    Write-Info $T.AdminHint
    if (-not $NoPause) {
        Write-Host ''
        Write-Host "  $($T.PressKey)" -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
    exit 1
}

Write-Info $T.Intro1
Write-Info $T.Intro2
Write-Info ($T.Intro3 -f $PreferredImageRoot)
Write-Info $T.Intro4
Write-Info $T.Intro5
Write-Host ''

try {
    if (-not (Test-Path -LiteralPath $PrepareScriptPath)) {
        throw $T.PrepareMissing
    }

    Write-Step $T.Step1
    $resolvedImagePath = Resolve-ImagePath -RequestedPath $ImagePath
    Write-OK ($T.ImageFound -f $resolvedImagePath)

    Write-Step $T.Step2
    $imageSize = (Get-Item -LiteralPath $resolvedImagePath).Length
    $selectedDisk = Resolve-TargetDisk -RequestedDiskNumber $DiskNumber -ImageSize $imageSize
    Write-OK ($T.TargetDisk -f $selectedDisk.Number, $selectedDisk.FriendlyName, [math]::Round($selectedDisk.Size / 1GB, 2))
    Confirm-DestructiveWrite

    Write-Step $T.Step3
    Write-ImageToDisk -ResolvedImagePath $resolvedImagePath -TargetDiskNumber $selectedDisk.Number
    Write-OK $T.WriteDone

    Write-Step $T.Step4
    $bootRoot = Wait-BootPartitionRoot -TargetDiskNumber $selectedDisk.Number
    Write-OK ($T.BootReady -f $bootRoot)
    $resolvedWifiConfigPath = Resolve-WifiConfigPath
    & $PrepareScriptPath -BootPath $bootRoot -WifiConfigPath $resolvedWifiConfigPath -NoPause -Lang $Lang

    Write-Host ''
    Write-Host "  $($T.Prepared)" -ForegroundColor Green
    Write-Host "  $($T.NextStep1)" -ForegroundColor White
    Write-Host "  $($T.NextStep2)" -ForegroundColor White
} catch {
    Write-Fail $_.Exception.Message
    if (-not $NoPause) {
        Write-Host ''
        Write-Host "  $($T.PressKey)" -ForegroundColor Gray
        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
    exit 1
} finally {
    if ($script:GeneratedWifiConfigPath -and (Test-Path -LiteralPath $script:GeneratedWifiConfigPath)) {
        Remove-Item -LiteralPath $script:GeneratedWifiConfigPath -Force -ErrorAction SilentlyContinue
    }
}

if (-not $NoPause) {
    Write-Host ''
    Write-Host "  $($T.PressKey)" -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}