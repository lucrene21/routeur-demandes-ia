# Extraction des resultats du jeu de test depuis n8n
# Produit resultats_ia.csv (a ouvrir dans Excel) dans le dossier courant.

$apiKey = $env:N8N_API_KEY   # a definir avant le lancement : $env:N8N_API_KEY = "..."
$base   = "http://localhost:5678/api/v1"
if (-not $apiKey) { Write-Host "Definissez d abord la variable N8N_API_KEY" -ForegroundColor Red; exit 1 }
$headers = @{ "X-N8N-API-KEY" = $apiKey }

# Ordre des sorties du Switch (regles 1 a 5, puis fallback)
$branches = @("Escalade", "Commercial", "Reclamation", "Candidature", "Partenariat", "Support")

$parId = @{}
$cursor = $null

do {
    $url = "$base/executions?includeData=true&limit=100"
    if ($cursor) { $url += "&cursor=$cursor" }
    $rep = Invoke-RestMethod -Uri $url -Headers $headers

    foreach ($ex in $rep.data) {
        $run = $ex.data.resultData.runData
        if (-not $run) { continue }

        $j = $null
        $gem = $run.'Analyse Gemini'
        if (-not $gem) { continue }
        # Executions ou Gemini a echoue : pas de sortie, on les ignore
        if (-not $gem[0].data) { continue }
        $main = $gem[0].data.main
        if (-not $main -or -not $main[0] -or $main[0].Count -eq 0) { continue }
        $j = $main[0][0].json
        if (-not $j) { continue }

        # On ne garde que les demandes du jeu de test (alias +nvlXX)
        if ($j.email -notmatch '\+nvl(\d+)@') { continue }
        $id = [int]$Matches[1]

        # Branche reellement empruntee par le Switch
        $branche = ""
        $sw = $run.'Switch'
        if ($sw -and $sw[0].data -and $sw[0].data.main) {
            $sorties = $sw[0].data.main
            for ($i = 0; $i -lt $sorties.Count; $i++) {
                if ($sorties[$i] -and $sorties[$i].Count -gt 0) { $branche = $branches[$i]; break }
            }
        }

        $debut = [datetime]$ex.startedAt
        $duree = ""
        if ($ex.stoppedAt) {
            $fin   = [datetime]$ex.stoppedAt
            $duree = [math]::Round(($fin - $debut).TotalSeconds, 2)
        }

        $ligne = [pscustomobject]@{
            id               = $id
            categorie_ia     = $j.categorie
            urgence_ia       = $j.urgence
            sentiment_ia     = $j.sentiment
            confiance_ia     = $j.confiance
            branche          = $branche
            resume_ia        = $j.resume
            statut           = $ex.status
            duree_totale_s   = $duree
            duree_gemini_ms  = $j.duree_analyse_ms
            execution_id     = $ex.id
            date             = $debut
        }

        # Si une demande a ete envoyee plusieurs fois, on garde la plus recente
        if (-not $parId.ContainsKey($id) -or $parId[$id].date -lt $debut) {
            $parId[$id] = $ligne
        }
    }
    $cursor = $rep.nextCursor
} while ($cursor)

$resultats = $parId.Values | Sort-Object id
$resultats | Export-Csv -Path ".\resultats_ia.csv" -NoTypeInformation -Encoding UTF8 -Delimiter ";"

Write-Host ""
Write-Host "$($resultats.Count) demandes extraites sur 40 -> resultats_ia.csv" -ForegroundColor Green
$manquants = 1..40 | Where-Object { -not $parId.ContainsKey($_) }
if ($manquants) { Write-Host "Ids manquants : $($manquants -join ', ')" -ForegroundColor Yellow }
