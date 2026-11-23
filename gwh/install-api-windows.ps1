# GWHSUPPORT: address book, login and online status (lejianwen/rustdesk-api).
# Run in PowerShell as Administrator on the RustDesk server (after install-windows.ps1).
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Public = '178.134.167.254'
$Dir    = 'C:\RustDesk-Server\api'
$Tmp    = Join-Path $env:TEMP 'rustdesk-api-setup'
$nssm   = 'C:\RustDesk-Server\nssm.exe'
New-Item -ItemType Directory -Force -Path $Dir, $Tmp | Out-Null

# 1. Download latest Windows release
Write-Host '>> Downloading rustdesk-api...'
$rel   = Invoke-RestMethod 'https://api.github.com/repos/lejianwen/rustdesk-api/releases/latest' -Headers @{ 'User-Agent' = 'ps' }
$asset = $rel.assets | Where-Object { $_.name -match 'windows' -and $_.name -match '(amd64|x86_64|x64)' -and $_.name -match '\.(zip|tar\.gz)$' } | Select-Object -First 1
if (-not $asset) { $rel.assets.name; throw 'Windows asset not found, send the list above to Claude' }
$pkg = Join-Path $Tmp $asset.name
Invoke-WebRequest $asset.browser_download_url -OutFile $pkg
$ex = Join-Path $Tmp 'x'; Remove-Item $ex -Recurse -Force -ErrorAction SilentlyContinue
if ($pkg -like '*.zip') { Expand-Archive $pkg -DestinationPath $ex -Force } else { New-Item -ItemType Directory $ex | Out-Null; tar -xzf $pkg -C $ex }
$exe  = Get-ChildItem $ex -Recurse -Filter '*.exe' | Where-Object { $_.Name -match 'apimain' } | Select-Object -First 1
if (-not $exe) { $exe = Get-ChildItem $ex -Recurse -Filter '*.exe' | Select-Object -First 1 }
if (Get-Service RustDeskApi -ErrorAction SilentlyContinue) { & $nssm stop RustDeskApi | Out-Null }
Copy-Item (Join-Path $exe.DirectoryName '*') $Dir -Recurse -Force

# 2. Config
$cfg = Join-Path $Dir 'conf\config.yaml'
$c = Get-Content $cfg -Raw
$c = $c -replace 'lang: ".*?"', 'lang: "en"'
$c = $c -replace 'id-server: ".*?"', "id-server: `"${Public}:21116`""
$c = $c -replace 'relay-server: ".*?"', "relay-server: `"${Public}:21117`""
$c = $c -replace 'api-server: ".*?"', "api-server: `"http://${Public}:21114`""
$c = $c -replace 'key-file: ".*?"', 'key-file: "C:/RustDesk-Server/id_ed25519.pub"'
Set-Content $cfg $c -Encoding UTF8

# 3. Windows service + firewall
if (Get-Service RustDeskApi -ErrorAction SilentlyContinue) { & $nssm remove RustDeskApi confirm | Out-Null }
& $nssm install RustDeskApi (Join-Path $Dir $exe.Name) | Out-Null
& $nssm set RustDeskApi AppDirectory $Dir | Out-Null
& $nssm set RustDeskApi Start SERVICE_AUTO_START | Out-Null
& $nssm set RustDeskApi AppStdout (Join-Path $Dir 'service.log') | Out-Null
& $nssm set RustDeskApi AppStderr (Join-Path $Dir 'service.log') | Out-Null
& $nssm start RustDeskApi | Out-Null
Get-NetFirewallRule -DisplayName 'RustDesk API' -ErrorAction SilentlyContinue | Remove-NetFirewallRule
New-NetFirewallRule -DisplayName 'RustDesk API' -Direction Inbound -Protocol TCP -LocalPort 21114 -Action Allow | Out-Null
Start-Sleep 8

# 4. Admin password
$AdminPass = -join ((48..57 + 65..90 + 97..122) | Get-Random -Count 12 | ForEach-Object { [char]$_ })
Push-Location $Dir; & (Join-Path $Dir $exe.Name) reset-admin-pwd $AdminPass | Out-Null; Pop-Location

Write-Host ''
Write-Host '============== DONE ==============' -ForegroundColor Green
Write-Host "Admin panel: http://192.168.0.193:21114/_admin/"
Write-Host "User:        admin"
Write-Host "Password:    $AdminPass"
Write-Host '=================================='
Write-Host 'Keep this password, do not send it to anyone.'
