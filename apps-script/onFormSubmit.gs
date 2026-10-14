// Script lie au formulaire Google "Contactez Novalis Conseil".
// Declencheur : onFormSubmit, source "A partir du formulaire", evenement "Lors de l'envoi".
// Envoie chaque reponse au webhook n8n (Google Forms ne sait pas appeler un webhook seul).

function onFormSubmit(e) {
  const url = "https://VOTRE-TUNNEL.trycloudflare.com/webhook/VOTRE-CHEMIN"; // Production URL du noeud Webhook

  const donnees = {};
  const reponses = e.response.getItemResponses();

  for (let i = 0; i < reponses.length; i++) {
    const titre = reponses[i].getItem().getTitle();
    donnees[titre] = reponses[i].getResponse();
  }

  donnees["horodatage"] = e.response.getTimestamp().toISOString();

  UrlFetchApp.fetch(url, {
    method: "post",
    contentType: "application/json",
    payload: JSON.stringify(donnees),
    muteHttpExceptions: true
  });
}
