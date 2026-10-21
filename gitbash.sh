set -euo pipefail

API="https://api.github.com"
FICHIER_TOKEN="$HOME/.config/gitbash/token"
REPONSE=$(mktemp)
trap 'rm -f "$REPONSE"' EXIT

erreur() {
    dialog --title "Erreur" --msgbox "$1" 8 60
    clear
    exit 1
}

api() {
    local donnees=()
    if [ -n "${3:-}" ]; then
        donnees=(-d "$3")
    fi
    echo "header = \"Authorization: Bearer $TOKEN\"" | curl --config - \
        --silent --proto =https \
        -X "$1" \
        -H "Accept: application/vnd.github+json" \
        -o "$REPONSE" -w "%{http_code}" \
        "${donnees[@]}" \
        "$API$2"
}

for outil in git curl jq dialog; do
    if ! command -v "$outil" > /dev/null; then
        echo "Il manque $outil. Installe-le avec : sudo apt install $outil"
        exit 1
    fi
done

if [ ! -f "$FICHIER_TOKEN" ]; then
    echo "Token introuvable. Crée le fichier $FICHIER_TOKEN"
    exit 1
fi

if [ "$(stat -c %a "$FICHIER_TOKEN")" != "600" ]; then
    echo "Le fichier du token est mal protégé. Tape : chmod 600 $FICHIER_TOKEN"
    exit 1
fi

TOKEN=$(cat "$FICHIER_TOKEN")

code=$(api GET /user)
if [ "$code" != "200" ]; then
    erreur "Token refusé par GitHub (code $code). Vérifie ton token."
fi
LOGIN=$(jq -r .login "$REPONSE")


NOM=$(dialog --stdout --title "Nouveau dépôt" --inputbox "Nom du dépôt :" 8 50) || { clear; exit 0; }
if [[ ! "$NOM" =~ ^[A-Za-z0-9._-]+$ ]]; then
    erreur "Nom invalide. Utilise seulement des lettres, chiffres, . _ -"
fi
if [ -e "$NOM" ]; then
    erreur "Un dossier $NOM existe déjà ici."
fi


NB_JOBS=$(dialog --stdout --title "Nouveau dépôt" --inputbox "Nombre de jobs (1 à 20) :" 8 50 "1") || { clear; exit 0; }
if [[ ! "$NB_JOBS" =~ ^[0-9]+$ ]] || [ "$NB_JOBS" -lt 1 ] || [ "$NB_JOBS" -gt 20 ]; then
    erreur "Le nombre de jobs doit être entre 1 et 20."
fi


COLLABS=$(dialog --stdout --title "Nouveau dépôt" \
    --inputbox "Collaborateurs (logins GitHub séparés par des espaces) :" 8 60) || { clear; exit 0; }
for c in $COLLABS; do
    if [[ ! "$c" =~ ^[A-Za-z0-9-]+$ ]]; then
        erreur "Login GitHub invalide : $c"
    fi
done

DROITS="pull"
if [ -n "$COLLABS" ]; then
    DROITS=$(dialog --stdout --title "Droits des collaborateurs" --menu "Quels droits ?" 10 50 2 \
        pull "Lecture seule (enseignant)" \
        push "Lecture et écriture (binôme)") || { clear; exit 0; }
fi


dialog --title "Confirmation" --yesno "Dépôt : $LOGIN/$NOM (privé)\nJobs : $NB_JOBS\nCollaborateurs : ${COLLABS:-aucun} ($DROITS)\n\nOn y va ?" 11 60 \
    || { clear; exit 0; }
clear


json=$(jq -n --arg nom "$NOM" '{name: $nom, private: true}')
code=$(api POST /user/repos "$json")
if [ "$code" != "201" ]; then
    erreur "Création impossible (code $code) : $(jq -r .message "$REPONSE")"
fi
echo "✔ Dépôt créé : https://github.com/$LOGIN/$NOM"


for c in $COLLABS; do
    json=$(jq -n --arg d "$DROITS" '{permission: $d}')
    code=$(api PUT "/repos/$LOGIN/$NOM/collaborators/$c" "$json")
    if [ "$code" = "201" ] || [ "$code" = "204" ]; then
        echo "✔ $c invité ($DROITS)"
    else
        echo "✘ Impossible d'ajouter $c (code $code)"
    fi
done


mkdir "$NOM"
cd "$NOM"

echo "# $NOM" > README.md

for i in $(seq 1 "$NB_JOBS"); do
    job=$(printf "Job%02d" "$i")      # donne Job01, Job02...
    mkdir "$job"
    echo "# $job" > "$job/README.md"
done

printf '.env\n*.token\n*.key\ntoken\n' > .gitignore

echo "✔ Dossiers Job01 à $job créés"


git init -q -b main
git add .
git commit -q -m "Premier commit : création des jobs"
git remote add origin "https://github.com/$LOGIN/$NOM.git"

GIT_TOKEN="$TOKEN" git \
    -c credential.helper= \
    -c credential.helper='!f() { echo "username=x-access-token"; echo "password=$GIT_TOKEN"; }; f' \
    push -q -u origin main

echo "✔ Premier push effectué"
echo
echo "Terminé ! https://github.com/$LOGIN/$NOM"