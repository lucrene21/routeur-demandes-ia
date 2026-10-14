# ============================================================
# Envoi du jeu de test au webhook n8n
# Projet : Routeur intelligent de demandes clients
# ============================================================
#
# MODE D'EMPLOI
# 1. Placez ce script et demandes_40.csv dans le meme dossier
# 2. Remplacez l'URL ci-dessous par votre Production URL n8n du jour
# 3. Dans PowerShell, placez-vous dans le dossier puis lancez :
#      .\envoi_jeu_de_test.ps1
#
# Le script envoie les demandes par lots de 10, avec une pause entre
# chaque lot, pour ne pas saturer le quota gratuit de l'API Gemini.
# ============================================================

$webhookUrl = "https://REMPLACEZ-MOI.trycloudflare.com/webhook/VOTRE-CHEMIN"

$fichierCsv   = "..\jeu-de-test\demandes_40.csv"
$tailleLot    = 10      # nombre de demandes par lot
$pauseEntreLots = 90    # secondes de pause entre deux lots
$pauseEntreEnvois = 4   # secondes entre deux demandes d'un meme lot

# ------------------------------------------------------------

if (-not (Test-Path $fichierCsv)) {
    Write-Host "Fichier introuvable : $fichierCsv" -ForegroundColor Red
    exit
}

if ($webhookUrl -like "*REMPLACEZ-MOI*") {
    Write-Host "Vous devez d'abord renseigner votre URL de webhook dans le script." -ForegroundColor Red
    exit
}

$demandes = Import-Csv -Path $fichierCsv -Encoding UTF8
$total = $demandes.Count
$succes = 0
$echecs = 0
$journal = @()

Write-Host ""
Write-Host "Envoi de $total demandes vers n8n" -ForegroundColor Cyan
Write-Host "Lots de $tailleLot, pause de $pauseEntreLots s entre les lots" -ForegroundColor Cyan
Write-Host ""

$compteur = 0

foreach ($d in $demandes) {

    $compteur++

    # Les cles doivent correspondre EXACTEMENT aux intitules du formulaire Google
    $corps = @{
        "Nom et prénom"  = $d.nom
        "Email"          = $d.email
        "Entreprise"     = $d.entreprise
        "Téléphone"      = $d.telephone
        "Votre message"  = $d.message
        "horodatage"     = (Get-Date).ToString("o")
    } | ConvertTo-Json -Depth 3

    $debut = Get-Date

    try {
        Invoke-RestMethod -Uri $webhookUrl `
                          -Method Post `
                          -ContentType "application/json; charset=utf-8" `
                          -Body ([System.Text.Encoding]::UTF8.GetBytes($corps)) `
                          -ErrorAction Stop | Out-Null

        $duree = ((Get-Date) - $debut).TotalMilliseconds
        $succes++
        Write-Host ("  [{0,2}/{1}] OK    {2} ({3:N0} ms)" -f $compteur, $total, $d.nom, $duree) -ForegroundColor Green
        $statut = "OK"
        $erreur = ""
    }
    catch {
        $duree = ((Get-Date) - $debut).TotalMilliseconds
        $echecs++
        Write-Host ("  [{0,2}/{1}] ECHEC {2} : {3}" -f $compteur, $total, $d.nom, $_.Exception.Message) -ForegroundColor Red
        $statut = "ECHEC"
        $erreur = $_.Exception.Message
    }

    $journal += [PSCustomObject]@{
        id             = $d.id
        nom            = $d.nom
        statut         = $statut
        duree_envoi_ms = [math]::Round($duree)
        horodatage     = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
        erreur         = $erreur
    }

    # Pause entre deux lots
    if (($compteur % $tailleLot -eq 0) -and ($compteur -lt $total)) {
        Write-Host ""
        Write-Host "  --- Lot termine. Pause de $pauseEntreLots secondes ---" -ForegroundColor Yellow
        Write-Host ""
        Start-Sleep -Seconds $pauseEntreLots
    }
    elseif ($compteur -lt $total) {
        Start-Sleep -Seconds $pauseEntreEnvois
    }
}

$journal | Export-Csv -Path ".\journal_envoi.csv" -NoTypeInformation -Encoding UTF8

Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "  Termine : $succes envoyees, $echecs en echec" -ForegroundColor Cyan
Write-Host "  Journal ecrit dans journal_envoi.csv" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""
