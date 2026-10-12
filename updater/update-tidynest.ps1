<#
  afkbird mod updater: Tidy Nest.

  Checks the newest release of each mod listed in $Mods below on GitHub and, if the jar in your mods
  folder is older (or missing), downloads the new jar, checks it, and swaps it in. The old jar is kept
  in a "<mod>-backup" folder next to the mods folder, not deleted.

  Every official jar is signed by afkbird. The updater only installs a jar whose signature matches the
  key below, so a jar that didn't come from afkbird is refused, even if it was uploaded to the
  official page.

  The same script updates any number of afkbird mods: this copy lists Tidy Nest. An all-in-one
  updater is this script with every mod in $Mods.

  Which mods folder:
    * -ModsDir "<path>"                     if given (e.g. a server's mods folder)
    * the "mods" folder next to this script  if there is one (put the updater in a server folder)
    * otherwise %APPDATA%\.minecraft\mods    (the normal Minecraft launcher)

  Close Minecraft (and stop the server) before running it: Windows won't replace a jar that's in use.

  Usable as a launcher pre-launch command (e.g. Prism Launcher):
    powershell -NoProfile -ExecutionPolicy Bypass -File "<path>\update-tidynest.ps1" -NoPause -ModsDir "$INST_MC_DIR\mods"
#>
param(
    [string]$ModsDir,
    [switch]$NoPause,
    [switch]$CheckOnly,
    # for testing only: where the release information comes from
    [string]$ApiBase = "https://api.github.com"
)

# --------------------------------------------------------------------------- settings
# The mods this updater looks after: mod id (from fabric.mod.json), name, GitHub repository "owner/name".
# Install = $true installs the mod if it isn't there yet; $false only updates a copy that is.
$Mods = @(
    @{ Id = "tidynest"; Name = "Tidy Nest"; Repo = "afkbirdgames/tidy-nest"; Install = $true }
)
# afkbird's public signing key (RSA, SHA-256). Releases are signed with the matching private key.
$SigningKeyModulus = "q1Cd+setSeeR3RC8iNKtueJjb/ReYoNqW5+7D5MTrHJJn54XH//XnPo27/jcb1Wp54vT9kKinHdxjfN4+tXzVLiQ6/82J2ICfu6NSD6LI4+XnstkMIp85YNNUUkhwj7jkJ6JgbOR5QDGcPXjLtJNC++8RqnQC0WarvHq2ozpNBmPuD6hFgDA0yRCxSTJLE0wocFI6K7byIc6eIVAlFoeUGcpSOA6HqL/Sr7MRuItYHU2Ws9Uc78bzltR7cBBGsLJLktHT2IRbexpfHaQ5SBHyPi8iCsCBu/Q6yCiVwEoK/qpIBYeE6+ijKU3xO7GjYogYM0qAKvvzMgSj5AWpc9UME22S7tAmu44YgSFz4mAvCjVy4uUFkZ/TpDkO165Qs2QCrqUNuZMfWGFCY7tBxwSBSqYChh0VlDijA+7a3BOgp/Sjv9Cu6X8etsM75V18+J7OngrE8h3NG6NMk640K8DZ8R5uIWXP5jyifcQ2VfKAZpfyZYIjNnVgdXtlP5A01EJ"
$SigningKeyExponent = "AQAB"
# --------------------------------------------------------------------------- end of settings

$ErrorActionPreference = "Stop"

function Say([string]$text, [string]$color = "Gray") { Write-Host $text -ForegroundColor $color }

function Finish([int]$code) {
    if (-not $NoPause) {
        Write-Host ""
        Read-Host "Press Enter to close" | Out-Null
    }
    exit $code
}

# Windows PowerShell 5.1 defaults to old TLS versions that GitHub refuses.
try { [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12 } catch { }
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

# Reads fabric.mod.json out of a jar. Returns $null if the file isn't a readable Fabric mod.
function Read-ModInfo([string]$jar) {
    try {
        $zip = [System.IO.Compression.ZipFile]::OpenRead($jar)
        try {
            $entry = $zip.GetEntry("fabric.mod.json")
            if ($null -eq $entry) { return $null }
            $reader = New-Object System.IO.StreamReader($entry.Open())
            try { return ($reader.ReadToEnd() | ConvertFrom-Json) } finally { $reader.Dispose() }
        } finally { $zip.Dispose() }
    } catch { return $null }
}

# True if $sigText is afkbird's signature of the file $file.
function Test-Signature([string]$file, [string]$sigText) {
    try {
        $sig = [Convert]::FromBase64String(($sigText -replace '\s', ''))
        $key = New-Object System.Security.Cryptography.RSAParameters
        $key.Modulus = [Convert]::FromBase64String($SigningKeyModulus)
        $key.Exponent = [Convert]::FromBase64String($SigningKeyExponent)
        $rsa = [System.Security.Cryptography.RSA]::Create()
        try {
            $rsa.ImportParameters($key)
            return $rsa.VerifyData([System.IO.File]::ReadAllBytes($file), $sig,
                [System.Security.Cryptography.HashAlgorithmName]::SHA256, [System.Security.Cryptography.RSASignaturePadding]::Pkcs1)
        } finally { $rsa.Dispose() }
    } catch { return $false }
}

function To-Version([string]$text) {
    $clean = ($text -replace '^[vV]', '') -replace '[-+].*$', ''
    $v = $null
    if ([version]::TryParse($clean, [ref]$v)) { return $v }
    return $null
}

# Updates one mod. Returns 0 (up to date or updated), 1 (failed, nothing changed) or 2 (skipped).
function Update-Mod($mod) {
    $id = $mod.Id
    $name = $mod.Name
    Say ""
    Say "== $name ==" "Cyan"
    if ($mod.Repo -notmatch '^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$') {
        Say "This updater is damaged: the GitHub repository for $name is missing. Download the updater again from the official Releases page." "Red"
        return 1
    }

    # ---- what's installed (by reading each jar, so a renamed jar is still recognised)
    $installed = @()
    foreach ($jar in Get-ChildItem -LiteralPath $ModsDir -Filter *.jar -File) {
        $info = Read-ModInfo $jar.FullName
        if ($null -ne $info -and $info.id -eq $id) {
            $installed += [pscustomobject]@{ File = $jar; Version = (To-Version $info.version); Text = $info.version }
        }
    }
    if ($installed.Count -eq 0) { Say "Installed: none" }
    foreach ($m in $installed) { Say ("Installed: {0} ({1})" -f $m.Text, $m.File.Name) }
    if ($installed.Count -gt 1) { Say "More than one copy of $name is installed; Minecraft won't start like that. The update will leave just one." "Yellow" }
    if ($installed.Count -eq 0 -and -not $mod.Install) { Say "Not installed here, so nothing to update."; return 2 }

    # ---- the newest release on GitHub
    try {
        $release = Invoke-RestMethod -UseBasicParsing -Uri "$ApiBase/repos/$($mod.Repo)/releases/latest" `
            -Headers @{ "User-Agent" = "afkbird-mod-updater"; "Accept" = "application/vnd.github+json" }
    } catch {
        Say "Couldn't reach GitHub to check for updates: $($_.Exception.Message)" "Red"
        Say "Check your internet connection and try again. Nothing was changed." "Red"
        return 1
    }
    $latest = To-Version $release.tag_name
    $asset = $release.assets | Where-Object { $_.name -match "^$id-[0-9][^/\\]*\.jar$" -and $_.name -notmatch "-sources\.jar$" } | Select-Object -First 1
    if ($null -eq $latest -or $null -eq $asset) {
        Say "The latest GitHub release ($($release.tag_name)) has no $name jar attached. Nothing was changed." "Red"
        return 1
    }
    $sigAsset = $release.assets | Where-Object { $_.name -eq "$($asset.name).sig" } | Select-Object -First 1
    Say ("Latest:    {0} (released {1})" -f $latest, ([datetime]$release.published_at).ToString("yyyy-MM-dd"))

    $newest = $installed | Where-Object { $null -ne $_.Version } | Sort-Object Version -Descending | Select-Object -First 1
    if ($installed.Count -eq 1 -and $null -ne $newest -and $newest.Version -ge $latest) {
        Say "You're up to date." "Green"
        return 0
    }
    if ($CheckOnly) {
        Say "An update is available. Run without -CheckOnly to install it." "Yellow"
        return 0
    }

    # ---- download to a temporary file and check it before touching the mods folder
    $temp = Join-Path ([System.IO.Path]::GetTempPath()) ("$id-update-" + [guid]::NewGuid().ToString("N") + ".jar")
    $tempSig = "$temp.sig"
    try {
        if ($null -eq $sigAsset -or $sigAsset.size -gt 4096) { throw "this release has no signature from afkbird, so it can't be trusted" }
        Say "Downloading $($asset.name)..."
        Invoke-WebRequest -UseBasicParsing -Uri $asset.browser_download_url -OutFile $temp -Headers @{ "User-Agent" = "afkbird-mod-updater" }
        if ($asset.size -and (Get-Item -LiteralPath $temp).Length -ne [long]$asset.size) { throw "the download is incomplete" }
        if ($asset.digest -and $asset.digest -match '^sha256:(?<hash>[0-9a-fA-F]{64})$') {
            $hash = (Get-FileHash -LiteralPath $temp -Algorithm SHA256).Hash
            if ($hash -ne $Matches.hash.ToUpper()) { throw "the download's checksum doesn't match GitHub's" }
        }
        Invoke-WebRequest -UseBasicParsing -Uri $sigAsset.browser_download_url -OutFile $tempSig -Headers @{ "User-Agent" = "afkbird-mod-updater" }
        if ((Get-Item -LiteralPath $tempSig).Length -gt 4096 -or -not (Test-Signature $temp ([System.IO.File]::ReadAllText($tempSig)))) {
            throw "the download isn't signed by afkbird, so it wasn't installed. Please report this on the official page"
        }
        $newInfo = Read-ModInfo $temp
        if ($null -eq $newInfo -or $newInfo.id -ne $id) { throw "the downloaded file isn't $name" }
        if ((To-Version $newInfo.version) -ne $latest) { throw "the downloaded jar is version $($newInfo.version), not $latest" }
        Remove-Item -LiteralPath $tempSig -ErrorAction SilentlyContinue
    } catch {
        Remove-Item -LiteralPath $temp -ErrorAction SilentlyContinue
        Remove-Item -LiteralPath $tempSig -ErrorAction SilentlyContinue
        Say "Update stopped: $($_.Exception.Message). Nothing was changed." "Red"
        return 1
    }

    # ---- swap: old jars to the backup folder, new jar in
    $backup = Join-Path (Split-Path -Parent $ModsDir) "$id-backup"
    try {
        if ($installed.Count -gt 0) {
            New-Item -ItemType Directory -Force -Path $backup | Out-Null
            Get-ChildItem -LiteralPath $backup -Filter *.jar -File | Remove-Item -Force    # keep only the last version
            foreach ($m in $installed) { Move-Item -LiteralPath $m.File.FullName -Destination (Join-Path $backup $m.File.Name) -Force }
        }
        Move-Item -LiteralPath $temp -Destination (Join-Path $ModsDir $asset.name) -Force
    } catch {
        Remove-Item -LiteralPath $temp -ErrorAction SilentlyContinue
        Say "Couldn't replace $($name): $($_.Exception.Message)" "Red"
        Say "Close Minecraft (and stop the server if it runs from this folder), then run the updater again." "Red"
        # put back anything already moved
        foreach ($m in $installed) {
            $moved = Join-Path $backup $m.File.Name
            if (-not (Test-Path -LiteralPath $m.File.FullName) -and (Test-Path -LiteralPath $moved)) {
                Move-Item -LiteralPath $moved -Destination $m.File.FullName -ErrorAction SilentlyContinue
            }
        }
        return 1
    }

    if ($installed.Count -gt 0) { Say ("Updated to {0}. The old jar is in {1}." -f $latest, $backup) "Green" }
    else { Say ("Installed {0} {1}." -f $name, $latest) "Green" }
    if ($release.html_url) { Say "What's new: $($release.html_url)" }
    return 0
}

Say "afkbird mod updater" "Green"

# ---- the mods folder
if (-not $ModsDir) {
    $beside = Join-Path $PSScriptRoot "mods"
    if (Test-Path -LiteralPath $beside -PathType Container) { $ModsDir = $beside }
    elseif ($env:APPDATA) { $ModsDir = Join-Path $env:APPDATA ".minecraft\mods" }
}
if (-not $ModsDir -or -not (Test-Path -LiteralPath $ModsDir -PathType Container)) {
    Say "Can't find a mods folder ($ModsDir). Install Fabric first, or run with -ModsDir ""<path to mods>""." "Red"
    Finish 2
}
$ModsDir = (Resolve-Path -LiteralPath $ModsDir).Path
Say "Mods folder: $ModsDir"
$hasFabricApi = @(Get-ChildItem -LiteralPath $ModsDir -Filter "fabric-api*.jar" -File).Count -gt 0
if (-not $hasFabricApi) { Say "Note: no fabric-api jar found in this folder. afkbird mods need Fabric API." "Yellow" }

$worst = 0
foreach ($mod in $Mods) {
    $result = Update-Mod $mod
    if ($result -eq 1) { $worst = 1 }
}
Say ""
if ($worst -eq 0) { Say "All done." "Green" } else { Say "Some updates didn't finish (see above). Anything that failed was left as it was." "Yellow" }
Finish $worst
