#!/bin/bash
# Garde-fou : la version de pubspec.yaml ne doit jamais être celle d'une
# version déjà approuvée (Apple la ferme à tout nouveau build : ITMS-90186 et
# ITMS-90062). Référence : version-approuvee.txt.
#
#   garde-version.sh --corriger   monte pubspec.yaml si besoin (patch +1, build +1)
#   garde-version.sh --verifier   échoue (code 1) si la version est périmée
#
# Le numéro de build (après le +) sert de versionCode sur Google Play, qui
# refuse un numéro déjà utilisé : il doit lui aussi dépasser celui approuvé.
set -eu

RACINE="$(git rev-parse --show-toplevel)"
PUBSPEC="${GARDE_PUBSPEC:-$RACINE/pubspec.yaml}"
APPROUVEE="${GARDE_APPROUVEE:-$RACINE/version-approuvee.txt}"
MODE="${1:---verifier}"

[ -f "$PUBSPEC" ] && [ -f "$APPROUVEE" ] || { echo "garde-version : fichiers de version introuvables" >&2; exit 2; }

ligne="$(grep -E '^version: [0-9]+\.[0-9]+\.[0-9]+\+[0-9]+' "$PUBSPEC" | head -1)"
[ -n "$ligne" ] || { echo "garde-version : ligne « version: » illisible dans pubspec.yaml" >&2; exit 2; }
actuelle="$(echo "$ligne" | sed -E 's/^version: ([0-9.]+)\+([0-9]+).*/\1/')"
build="$(echo "$ligne" | sed -E 's/^version: ([0-9.]+)\+([0-9]+).*/\2/')"
appr_v="$(grep -E '^version=' "$APPROUVEE" | head -1 | cut -d= -f2)"
appr_b="$(grep -E '^build=' "$APPROUVEE" | head -1 | cut -d= -f2)"
[ -n "$appr_v" ] && [ -n "$appr_b" ] || { echo "garde-version : version-approuvee.txt illisible" >&2; exit 2; }

# 1 si $1 > $2 (comparaison numérique des trois nombres)
plus_recente() {
  local IFS=.; set -- $1 $2
  [ "$1" -gt "$4" ] && return 0; [ "$1" -lt "$4" ] && return 1
  [ "$2" -gt "$5" ] && return 0; [ "$2" -lt "$5" ] && return 1
  [ "$3" -gt "$6" ]
}

ok=1
plus_recente "$actuelle" "$appr_v" || ok=0
[ "$build" -gt "$appr_b" ] || ok=0

if [ "$ok" = 1 ]; then
  exit 0
fi

# Nouvelle version : le patch suivant la plus récente des deux, build au-dessus des deux.
base="$actuelle"
plus_recente "$appr_v" "$actuelle" && base="$appr_v"
nouveau_v="${base%.*}.$(( ${base##*.} + 1 ))"
nouveau_b=$(( (build > appr_b ? build : appr_b) + 1 ))

if [ "$MODE" = "--corriger" ]; then
  sed -E -i.bak "s/^version: [0-9]+\.[0-9]+\.[0-9]+\+[0-9]+/version: $nouveau_v+$nouveau_b/" "$PUBSPEC" && rm -f "$PUBSPEC.bak"
  echo "garde-version : $actuelle+$build est une version déjà approuvée (ou plus ancienne) → montée à $nouveau_v+$nouveau_b" >&2
  echo "  (pense à saisir $nouveau_v dans App Store Connect avant de soumettre)" >&2
  exit 0
fi

echo "garde-version : pubspec.yaml porte $actuelle+$build, mais $appr_v+$appr_b est déjà approuvée." >&2
echo "  Apple refuserait le build (ITMS-90186). Corrige avec :  scripts/garde-version.sh --corriger" >&2
exit 1
