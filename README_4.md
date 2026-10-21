# GitBash — GitHub automatisé

Script Bash qui crée automatiquement un dépôt GitHub pour un TP :

1. crée le dépôt sur GitHub (privé) grâce à l'API GitHub ;
2. ajoute les collaborateurs ;
3. crée les dossiers `Job01`, `Job02`… en local ;
4. fait le premier commit et le premier push.

## Installation

```bash
sudo apt install git curl jq dialog
git config --global user.name "Prénom Nom"
git config --global user.email "ton@email.fr"
```

## Le token GitHub

Créer un token sur GitHub : Settings → Developer settings → Fine-grained tokens.
Droits nécessaires : **Administration** (lecture/écriture) et **Contents** (lecture/écriture).

L'enregistrer dans un fichier protégé :

```bash
mkdir -p ~/.config/gitbash
( umask 077; read -rsp "Token : " t; printf '%s\n' "$t" > ~/.config/gitbash/token )
```

## Utilisation

```bash
chmod +x gitbash.sh
./gitbash.sh
```

Le script pose les questions dans des fenêtres (`dialog`) : nom du dépôt, nombre de jobs, collaborateurs, droits.

## Sécurité

| Risque | Ce que fait le script |
|---|---|
| Token volé | Stocké dans un fichier en `chmod 600`, vérifié au lancement |
| Token visible avec `ps` | Donné à `curl` par l'entrée standard, pas dans la commande |
| Token enregistré dans `.git/config` | Jamais mis dans l'adresse du dépôt ; git le lit seulement pendant le push |
| Secret envoyé sur GitHub | `.gitignore` bloque `.env`, `*.token`, `*.key` |
| Saisie dangereuse (injection) | Nom, logins et nombre vérifiés par des expressions régulières ; JSON créé avec `jq` |
| Trop de droits | Dépôt privé ; collaborateurs en lecture seule (`pull`) ou écriture (`push`) seulement |
| Erreur silencieuse | `set -euo pipefail` arrête le script à la première erreur ; codes HTTP vérifiés |
