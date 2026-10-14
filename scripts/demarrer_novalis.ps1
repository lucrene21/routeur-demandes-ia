# Demarrage complet de l'environnement Novalis : Docker, tunnel, n8n.
# Lancez-le par double-clic sur demarrer_novalis.bat

$ErrorActionPreference = "Stop"
$dossier  = Split-Path -Parent $MyInvocation.MyCommand.Path
$envFile  = Join-Path $dossier "n8n.env"
$logTunnel = Join-Path $dossier "tunnel.log"
$cheminWebhook = "webhook/VOTRE-CHEMIN-WEBHOOK"

function Etape($texte) { Write-Host ""; Write-Host ">> $texte" -ForegroundColor Cyan }

# --- Verification du fichier de secrets ---
if (-not (Test-Path $envFile)) {
    Write-Host "Fichier n8n.env introuvable dans $dossier" -ForegroundColor Red
    exit 1
}
if ((Get-Content $envFile -Raw) -match "COLLEZ_ICI") {
    Write-Host "Ouvrez n8n.env et collez votre cle Gemini avant de lancer ce script." -ForegroundColor Red
    exit 1
}

# --- 1. Docker Desktop ---
Etape "Demarrage de Docker Desktop"
$dockerOk = $false
try { docker info *> $null; if ($LASTEXITCODE -eq 0) { $dockerOk = $true } } catch {}
if (-not $dockerOk) {
    $exe = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
    if (Test-Path $exe) { Start-Process $exe }
    Write-Host "   En attente du moteur Docker (jusqu'a 3 minutes)..."
    for ($i = 0; $i -lt 90; $i++) {
        Start-Sleep -Seconds 2
        try { docker info *> $null; if ($LASTEXITCODE -eq 0) { $dockerOk = $true; break } } catch {}
    }
}
if (-not $dockerOk) { Write-Host "Docker ne repond pas. Lancez Docker Desktop a la main puis relancez." -ForegroundColor Red; exit 1 }
Write-Host "   Docker pret." -ForegroundColor Green

# --- 2. Tunnel Cloudflare ---
Etape "Demarrage du tunnel"
Get-Process cloudflared -ErrorAction SilentlyContinue | Stop-Process -Force
if (Test-Path $logTunnel) { Remove-Item $logTunnel -Force }
Start-Process cloudflared -ArgumentList "tunnel --url http://localhost:5678 --logfile `"$logTunnel`"" -WindowStyle Hidden

$url = $null
for ($i = 0; $i -lt 30; $i++) {
    Start-Sleep -Seconds 2
    if (Test-Path $logTunnel) {
        $m = Select-String -Path $logTunnel -Pattern "https://[a-z0-9-]+\.trycloudflare\.com" | Select-Object -First 1
        if ($m) { $url = $m.Matches[0].Value; break }
    }
}
if (-not $url) { Write-Host "Le tunnel n'a pas fourni d'URL. Voir tunnel.log" -ForegroundColor Red; exit 1 }
Write-Host "   Tunnel : $url" -ForegroundColor Green

# --- 3. n8n ---
Etape "Demarrage de n8n"
docker rm -f n8n *> $null
docker run -d --name n8n --restart unless-stopped -p 5678:5678 `
  -v n8n_data:/home/node/.n8n `
  --env-file "$envFile" `
  -e GENERIC_TIMEZONE=Europe/Paris -e TZ=Europe/Paris `
  -e WEBHOOK_URL=$url/ `
  -e N8N_EDITOR_BASE_URL=http://localhost:5678/ `
  -e N8N_PROXY_HOPS=1 `
  -e N8N_BLOCK_ENV_ACCESS_IN_NODE=false `
  docker.n8n.io/n8nio/n8n | Out-Null
Write-Host "   n8n demarre." -ForegroundColor Green

# --- 4. URL a coller dans Apps Script ---
$prod = "$url/$cheminWebhook"
Set-Clipboard -Value $prod

Write-Host ""
Write-Host "==================================================" -ForegroundColor Yellow
Write-Host " Tout est lance. Derniere etape, a la main :" -ForegroundColor Yellow
Write-Host ""
Write-Host " Collez cette URL dans Apps Script (ligne const url = ...)"
Write-Host " Elle est deja copiee dans le presse-papiers : Ctrl+V"
Write-Host ""
Write-Host " $prod" -ForegroundColor White
Write-Host ""
Write-Host " Editeur n8n : http://localhost:5678 (pret dans ~20 s)"
Write-Host "==================================================" -ForegroundColor Yellow
