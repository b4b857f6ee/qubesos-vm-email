#!/bin/bash
#
# create-email-vm.sh
# Script pour créer une VM email webmail sur QubesOS 4.3
# Avec firewall restrictif par domaine (sans wildcards)
# À exécuter depuis dom0
#
# Usage: ./create-email-vm.sh
#

# Configuration
VM_NAME="email"
LABEL="yellow"
NETVM="sys-firewall"
MEMORY="2048"
MAXMEM="4096"
VCPUS="2"

# Couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Domaines essentiels pour chaque service (sans wildcards)
# Gmail / Google - domaines minimaux nécessaires
GMAIL_DOMAINS=(
    "mail.google.com"
    "accounts.google.com"
    "www.google.com"
    "ssl.gstatic.com"
    "www.gstatic.com"
    "fonts.gstatic.com"
    "fonts.googleapis.com"
    "apis.google.com"
    "www.googleapis.com"
    "lh3.googleusercontent.com"
    "play.google.com"
)

# Outlook / Microsoft - domaines minimaux nécessaires
OUTLOOK_DOMAINS=(
    "outlook.live.com"
    "login.live.com"
    "login.microsoftonline.com"
    "account.live.com"
    "outlook.office365.com"
    "outlook.office.com"
    "aadcdn.msauth.net"
    "aadcdn.msftauth.net"
    "logincdn.msauth.net"
    "res.cdn.office.net"
)

# ProtonMail - domaines minimaux nécessaires
PROTONMAIL_DOMAINS=(
    "mail.proton.me"
    "account.proton.me"
    "proton.me"
    "mail.protonmail.com"
    "account.protonmail.com"
    "api.protonmail.ch"
)

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}   Création de la VM Email Webmail     ${NC}"
echo -e "${YELLOW}   Firewall Restrictif par Domaine     ${NC}"
echo -e "${YELLOW}        QubesOS 4.3                    ${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# Vérifier que le script est exécuté depuis dom0
if [[ "$(hostname)" != "dom0" ]]; then
    echo -e "${RED}[ERREUR] Ce script doit être exécuté depuis dom0${NC}"
    exit 1
fi

# Fonction pour lister les templates disponibles
list_templates() {
    qvm-ls --raw-list --class TemplateVM 2>/dev/null | sort
}

# Fonction pour trouver le meilleur template Fedora
find_fedora_template() {
    local templates=$(list_templates)
    local fedora_template=""
    
    for version in 41 40 39 38; do
        if echo "$templates" | grep -qx "fedora-$version"; then
            fedora_template="fedora-$version"
            break
        elif echo "$templates" | grep -qx "fedora-$version-xfce"; then
            fedora_template="fedora-$version-xfce"
            break
        fi
    done
    
    echo "$fedora_template"
}

# Sélection des services de messagerie
echo -e "${CYAN}[CONFIGURATION] Sélection des services de messagerie${NC}"
echo ""
echo "Quels services de messagerie souhaitez-vous utiliser ?"
echo ""

ENABLE_GMAIL=false
ENABLE_OUTLOOK=false
ENABLE_PROTONMAIL=false

read -p "  Activer Gmail ? (o/N) : " -n 1 -r
echo
[[ $REPLY =~ ^[Oo]$ ]] && ENABLE_GMAIL=true

read -p "  Activer Outlook ? (o/N) : " -n 1 -r
echo
[[ $REPLY =~ ^[Oo]$ ]] && ENABLE_OUTLOOK=true

read -p "  Activer ProtonMail ? (o/N) : " -n 1 -r
echo
[[ $REPLY =~ ^[Oo]$ ]] && ENABLE_PROTONMAIL=true

# Vérifier qu'au moins un service est sélectionné
if ! $ENABLE_GMAIL && ! $ENABLE_OUTLOOK && ! $ENABLE_PROTONMAIL; then
    echo -e "${RED}[ERREUR] Aucun service sélectionné. Abandon.${NC}"
    exit 1
fi

echo ""
echo -e "${GREEN}Services sélectionnés :${NC}"
$ENABLE_GMAIL && echo "  ✓ Gmail"
$ENABLE_OUTLOOK && echo "  ✓ Outlook"
$ENABLE_PROTONMAIL && echo "  ✓ ProtonMail"
echo ""

# Détecter les templates disponibles
echo -e "${BLUE}[INFO] Détection des templates disponibles...${NC}"
echo ""

AVAILABLE_TEMPLATES=$(list_templates)
if [[ -z "$AVAILABLE_TEMPLATES" ]]; then
    echo -e "${RED}[ERREUR] Aucun template trouvé${NC}"
    exit 1
fi

echo "Templates disponibles :"
echo "$AVAILABLE_TEMPLATES" | while read -r t; do
    echo "  - $t"
done
echo ""

# Trouver automatiquement un template Fedora
AUTO_TEMPLATE=$(find_fedora_template)

if [[ -n "$AUTO_TEMPLATE" ]]; then
    echo -e "${GREEN}[INFO] Template Fedora détecté : $AUTO_TEMPLATE${NC}"
    echo ""
    read -p "Utiliser '$AUTO_TEMPLATE' ? (O/n) : " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        AUTO_TEMPLATE=""
    fi
fi

if [[ -z "$AUTO_TEMPLATE" ]]; then
    echo ""
    read -p "Entrez le nom du template à utiliser : " TEMPLATE
    
    if ! qvm-check --quiet "$TEMPLATE" 2>/dev/null; then
        echo -e "${RED}[ERREUR] Le template '$TEMPLATE' n'existe pas${NC}"
        exit 1
    fi
else
    TEMPLATE="$AUTO_TEMPLATE"
fi

echo ""
echo -e "${GREEN}[INFO] Utilisation du template : $TEMPLATE${NC}"
echo ""

# Vérifier si la VM existe déjà
if qvm-check --quiet "$VM_NAME" 2>/dev/null; then
    echo -e "${YELLOW}[ATTENTION] La VM '$VM_NAME' existe déjà${NC}"
    read -p "Voulez-vous la supprimer et la recréer ? (o/N) : " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Oo]$ ]]; then
        echo "[INFO] Suppression de la VM existante..."
        qvm-kill "$VM_NAME" 2>/dev/null || true
        qvm-remove -f "$VM_NAME"
    else
        echo "[INFO] Abandon de l'opération"
        exit 0
    fi
fi

# Créer la VM
echo -e "${GREEN}[1/7] Création de l'AppVM '$VM_NAME' (template: $TEMPLATE)...${NC}"
if ! qvm-create --class AppVM --template "$TEMPLATE" --label "$LABEL" "$VM_NAME"; then
    echo -e "${RED}[ERREUR] Impossible de créer la VM${NC}"
    exit 1
fi

# Configurer la connexion réseau
echo -e "${GREEN}[2/7] Configuration du réseau (NetVM: $NETVM)...${NC}"
qvm-prefs "$VM_NAME" netvm "$NETVM"

# Configurer la mémoire
echo -e "${GREEN}[3/7] Configuration de la mémoire (RAM: ${MEMORY}MB, Max: ${MAXMEM}MB)...${NC}"
qvm-prefs "$VM_NAME" memory "$MEMORY"
qvm-prefs "$VM_NAME" maxmem "$MAXMEM"

# Configurer les vCPUs
echo -e "${GREEN}[4/7] Configuration des vCPUs ($VCPUS)...${NC}"
qvm-prefs "$VM_NAME" vcpus "$VCPUS"

# Configurer le firewall restrictif
echo -e "${GREEN}[5/7] Configuration du firewall restrictif par domaine...${NC}"
echo ""
echo -e "${YELLOW}[NOTE] La résolution DNS de chaque domaine peut prendre quelques secondes...${NC}"
echo ""

# Supprimer toutes les règles existantes et la règle par défaut "accept all"
# On supprime la règle 0 en boucle jusqu'à ce qu'il n'y en ait plus
echo -e "${CYAN}  Suppression des règles existantes...${NC}"
while qvm-firewall "$VM_NAME" del --rule-no 0 2>/dev/null; do
    echo -n "."
done
echo " OK"

# Compteur de règles
RULE_COUNT=0
RULE_ERRORS=0

# Fonction pour ajouter une règle avec retry
add_rule_with_retry() {
    local domain="$1"
    local max_retries=3
    local retry=0
    
    while [ $retry -lt $max_retries ]; do
        if qvm-firewall "$VM_NAME" add accept dsthost="$domain" dstports=443 proto=tcp 2>/dev/null; then
            return 0
        fi
        retry=$((retry + 1))
        sleep 2
    done
    return 1
}

# Ajouter les règles pour Gmail
if $ENABLE_GMAIL; then
    echo -e "${CYAN}  Ajout des règles Gmail (${#GMAIL_DOMAINS[@]} domaines)...${NC}"
    for domain in "${GMAIL_DOMAINS[@]}"; do
        echo -n "    $domain ... "
        if add_rule_with_retry "$domain"; then
            echo -e "${GREEN}✓${NC}"
            RULE_COUNT=$((RULE_COUNT + 1))
        else
            echo -e "${RED}✗${NC}"
            RULE_ERRORS=$((RULE_ERRORS + 1))
        fi
        sleep 1
    done
    echo ""
fi

# Ajouter les règles pour Outlook
if $ENABLE_OUTLOOK; then
    echo -e "${CYAN}  Ajout des règles Outlook (${#OUTLOOK_DOMAINS[@]} domaines)...${NC}"
    for domain in "${OUTLOOK_DOMAINS[@]}"; do
        echo -n "    $domain ... "
        if add_rule_with_retry "$domain"; then
            echo -e "${GREEN}✓${NC}"
            RULE_COUNT=$((RULE_COUNT + 1))
        else
            echo -e "${RED}✗${NC}"
            RULE_ERRORS=$((RULE_ERRORS + 1))
        fi
        sleep 1
    done
    echo ""
fi

# Ajouter les règles pour ProtonMail
if $ENABLE_PROTONMAIL; then
    echo -e "${CYAN}  Ajout des règles ProtonMail (${#PROTONMAIL_DOMAINS[@]} domaines)...${NC}"
    for domain in "${PROTONMAIL_DOMAINS[@]}"; do
        echo -n "    $domain ... "
        if add_rule_with_retry "$domain"; then
            echo -e "${GREEN}✓${NC}"
            RULE_COUNT=$((RULE_COUNT + 1))
        else
            echo -e "${RED}✗${NC}"
            RULE_ERRORS=$((RULE_ERRORS + 1))
        fi
        sleep 1
    done
    echo ""
fi

# Règle finale : bloquer tout le reste
echo -e "${CYAN}  Ajout de la règle de blocage finale...${NC}"
echo -n "    drop ... "
if qvm-firewall "$VM_NAME" add drop 2>/dev/null; then
    echo -e "${GREEN}✓${NC}"
    RULE_COUNT=$((RULE_COUNT + 1))
else
    echo -e "${RED}✗${NC}"
fi

echo ""
echo -e "${GREEN}  Total : $RULE_COUNT règles configurées${NC}"
if [[ $RULE_ERRORS -gt 0 ]]; then
    echo -e "${YELLOW}  Attention : $RULE_ERRORS règles en erreur (domaines non résolus)${NC}"
    echo -e "${YELLOW}  Ces domaines pourront être ajoutés manuellement plus tard si nécessaire${NC}"
fi

# Afficher les règles configurées
echo ""
echo -e "${BLUE}[INFO] Règles firewall actuelles :${NC}"
qvm-firewall "$VM_NAME" list

# Ajouter Firefox aux applications visibles dans le menu
echo ""
echo -e "${GREEN}[6/7] Ajout de Firefox au menu des applications...${NC}"
qvm-appmenus --set-whitelist=firefox.desktop "$VM_NAME" 2>/dev/null || \
    echo -e "${YELLOW}[NOTE] Ajout manuel des applications peut être nécessaire via les paramètres de la VM${NC}"

# Synchroniser les menus d'applications
echo -e "${GREEN}[7/7] Synchronisation des menus...${NC}"
qvm-appmenus --update "$VM_NAME" 2>/dev/null || true

# Afficher le résumé
echo ""
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}          Résumé de la VM              ${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
echo "Nom          : $VM_NAME"
echo "Template     : $TEMPLATE"
echo "Label        : $LABEL"
echo "NetVM        : $NETVM"
echo "Mémoire      : ${MEMORY}MB (max: ${MAXMEM}MB)"
echo "vCPUs        : $VCPUS"
echo ""
echo -e "${YELLOW}Services activés :${NC}"
$ENABLE_GMAIL && echo "  ✓ Gmail (${#GMAIL_DOMAINS[@]} domaines)"
$ENABLE_OUTLOOK && echo "  ✓ Outlook (${#OUTLOOK_DOMAINS[@]} domaines)"
$ENABLE_PROTONMAIL && echo "  ✓ ProtonMail (${#PROTONMAIL_DOMAINS[@]} domaines)"
echo ""
echo -e "${YELLOW}Firewall :${NC}"
echo "  - Seuls les domaines listés sont autorisés (port 443)"
echo "  - Tout le reste est bloqué"
echo ""
echo -e "${RED}IMPORTANT :${NC}"
echo "  Si un service ne fonctionne pas complètement, il peut manquer"
echo "  des domaines. Utilisez les outils de développement du navigateur"
echo "  (F12 > Network) pour identifier les domaines bloqués, puis ajoutez-les :"
echo ""
echo "  qvm-firewall $VM_NAME add accept dsthost=DOMAINE dstports=443 proto=tcp"
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   La VM '$VM_NAME' a été créée !       ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Pour lancer Firefox dans la VM :"
echo "  qvm-run $VM_NAME firefox"
echo ""
echo "URLs des services :"
$ENABLE_GMAIL && echo "  - Gmail      : https://mail.google.com"
$ENABLE_OUTLOOK && echo "  - Outlook    : https://outlook.live.com"
$ENABLE_PROTONMAIL && echo "  - ProtonMail : https://mail.proton.me"
echo ""
