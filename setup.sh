#!/bin/bash
#
# setup.sh
# QubesOS DNS Filtering - Main Setup Script
# Run from dom0
#

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source libraries
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/cleanup.sh"
source "$SCRIPT_DIR/lib/template.sh"

# ========================================
# HEADER
# ========================================

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}   QubesOS DNS Filtering Setup         ${NC}"
echo -e "${YELLOW}   v2.0 - Multi-profile Edition        ${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

check_dom0

# ========================================
# CLEANUP
# ========================================

interactive_cleanup

# ========================================
# TEMPLATE SELECTION
# ========================================

echo -e "${BLUE}=== Base Template Selection ===${NC}"
echo ""

select_template "Select base template" "\-(email|drive|banking|shopping|social|media|travel|admin|health|gov|ai|crypto|news|work|filtered)$"
BASE_TEMPLATE="$SELECTED_TEMPLATE"

echo ""

# ========================================
# PROFILE SELECTION
# ========================================

echo -e "${BLUE}=== Profile Selection ===${NC}"
echo ""
echo "  ${CYAN}--- Communication ---${NC}"
echo "  1) Email (Gmail, Outlook, ProtonMail)"
echo "  2) Social (Facebook, Instagram, Twitter, LinkedIn, Discord...)"
echo "  3) Work (Slack, Teams, Notion, Zoom, Figma...)"
echo ""
echo "  ${CYAN}--- Stockage ---${NC}"
echo "  4) Drive (Google Drive, OneDrive, Dropbox, Proton Drive)"
echo ""
echo "  ${CYAN}--- Finance ---${NC}"
echo "  5) Banking (Banques FR + paiements)"
echo "  6) Crypto (Exchanges + wallets)"
echo ""
echo "  ${CYAN}--- Services FR ---${NC}"
echo "  7) Gov (Services publics FR)"
echo "  8) Health (Santé: Doctolib, Ameli, mutuelles...)"
echo "  9) Shopping (Amazon, Fnac, Cdiscount, Leboncoin...)"
echo "  10) Travel (SNCF, Booking, Airbnb, compagnies aériennes...)"
echo ""
echo "  ${CYAN}--- Médias ---${NC}"
echo "  11) Media (Netflix, YouTube, Spotify, Twitch...)"
echo "  12) News (Presse FR et internationale)"
echo ""
echo "  ${CYAN}--- Tech ---${NC}"
echo "  13) Admin (GitHub, OVH, Cloudflare, AWS...)"
echo "  14) AI (ChatGPT, Claude, Mistral, Midjourney...)"
echo ""
echo -e "  ${YELLOW}a) All profiles${NC}"
echo ""
echo "Enter numbers separated by spaces (e.g., '1 4 5') or 'a' for all:"
read -p "> " PROFILE_SELECTION

# Initialize all profile flags
CREATE_EMAIL=false
CREATE_SOCIAL=false
CREATE_WORK=false
CREATE_DRIVE=false
CREATE_BANKING=false
CREATE_CRYPTO=false
CREATE_GOV=false
CREATE_HEALTH=false
CREATE_SHOPPING=false
CREATE_TRAVEL=false
CREATE_MEDIA=false
CREATE_NEWS=false
CREATE_ADMIN=false
CREATE_AI=false

if [[ "$PROFILE_SELECTION" == "a" ]]; then
    CREATE_EMAIL=true
    CREATE_SOCIAL=true
    CREATE_WORK=true
    CREATE_DRIVE=true
    CREATE_BANKING=true
    CREATE_CRYPTO=true
    CREATE_GOV=true
    CREATE_HEALTH=true
    CREATE_SHOPPING=true
    CREATE_TRAVEL=true
    CREATE_MEDIA=true
    CREATE_NEWS=true
    CREATE_ADMIN=true
    CREATE_AI=true
else
    for num in $PROFILE_SELECTION; do
        case "$num" in
            1) CREATE_EMAIL=true ;;
            2) CREATE_SOCIAL=true ;;
            3) CREATE_WORK=true ;;
            4) CREATE_DRIVE=true ;;
            5) CREATE_BANKING=true ;;
            6) CREATE_CRYPTO=true ;;
            7) CREATE_GOV=true ;;
            8) CREATE_HEALTH=true ;;
            9) CREATE_SHOPPING=true ;;
            10) CREATE_TRAVEL=true ;;
            11) CREATE_MEDIA=true ;;
            12) CREATE_NEWS=true ;;
            13) CREATE_ADMIN=true ;;
            14) CREATE_AI=true ;;
        esac
    done
fi

# Validate at least one selected
if ! $CREATE_EMAIL && ! $CREATE_SOCIAL && ! $CREATE_WORK && ! $CREATE_DRIVE && \
   ! $CREATE_BANKING && ! $CREATE_CRYPTO && ! $CREATE_GOV && ! $CREATE_HEALTH && \
   ! $CREATE_SHOPPING && ! $CREATE_TRAVEL && ! $CREATE_MEDIA && ! $CREATE_NEWS && \
   ! $CREATE_ADMIN && ! $CREATE_AI; then
    msg_error "Select at least one profile"
    exit 1
fi

# ========================================
# EMAIL SERVICES SELECTION
# ========================================

EMAIL_GMAIL=false
EMAIL_OUTLOOK=false
EMAIL_PROTON=false

if $CREATE_EMAIL; then
    echo ""
    echo -e "${BLUE}=== Email Services ===${NC}"
    echo ""
    echo "  1) Gmail"
    echo "  2) Outlook / Hotmail"
    echo "  3) ProtonMail"
    echo ""
    echo "Enter numbers separated by spaces (e.g., '1 2 3') or 'a' for all:"
    read -p "> " EMAIL_SELECTION
    
    if [[ "$EMAIL_SELECTION" == "a" ]]; then
        EMAIL_GMAIL=true
        EMAIL_OUTLOOK=true
        EMAIL_PROTON=true
    else
        for num in $EMAIL_SELECTION; do
            case "$num" in
                1) EMAIL_GMAIL=true ;;
                2) EMAIL_OUTLOOK=true ;;
                3) EMAIL_PROTON=true ;;
            esac
        done
    fi
    
    if ! $EMAIL_GMAIL && ! $EMAIL_OUTLOOK && ! $EMAIL_PROTON; then
        msg_error "Select at least one email service"
        exit 1
    fi
fi

export EMAIL_GMAIL EMAIL_OUTLOOK EMAIL_PROTON

# ========================================
# DRIVE SERVICES SELECTION
# ========================================

DRIVE_GOOGLE=false
DRIVE_ONEDRIVE=false
DRIVE_DROPBOX=false
DRIVE_PROTON=false
SYNOLOGY_ENABLED=false
SYNOLOGY_QUICKCONNECT=""
SYNOLOGY_DIRECT_IP=""

if $CREATE_DRIVE; then
    echo ""
    echo -e "${BLUE}=== Drive Services ===${NC}"
    echo ""
    echo "  1) Google Drive"
    echo "  2) OneDrive"
    echo "  3) Dropbox"
    echo "  4) Proton Drive"
    echo "  5) Synology"
    echo ""
    echo "Enter numbers separated by spaces (e.g., '1 2 4') or 'a' for all:"
    read -p "> " DRIVE_SELECTION
    
    if [[ "$DRIVE_SELECTION" == "a" ]]; then
        DRIVE_GOOGLE=true
        DRIVE_ONEDRIVE=true
        DRIVE_DROPBOX=true
        DRIVE_PROTON=true
        SYNOLOGY_ENABLED=true
    else
        for num in $DRIVE_SELECTION; do
            case "$num" in
                1) DRIVE_GOOGLE=true ;;
                2) DRIVE_ONEDRIVE=true ;;
                3) DRIVE_DROPBOX=true ;;
                4) DRIVE_PROTON=true ;;
                5) SYNOLOGY_ENABLED=true ;;
            esac
        done
    fi
    
    if ! $DRIVE_GOOGLE && ! $DRIVE_ONEDRIVE && ! $DRIVE_DROPBOX && ! $DRIVE_PROTON && ! $SYNOLOGY_ENABLED; then
        msg_error "Select at least one drive service"
        exit 1
    fi
    
    # Synology configuration
    if $SYNOLOGY_ENABLED; then
        echo ""
        echo -e "${BLUE}=== Synology Configuration ===${NC}"
        echo ""
        echo "  1) QuickConnect ID (e.g., mynas.quickconnect.to)"
        echo "  2) Direct IP/hostname (e.g., 192.168.1.100 or nas.local)"
        echo "  3) Both"
        echo ""
        read -p "Select connection type [1-3]: " SYNO_CHOICE
        
        case "$SYNO_CHOICE" in
            1)
                read -p "Enter QuickConnect ID (without .quickconnect.to): " SYNOLOGY_QUICKCONNECT
                ;;
            2)
                read -p "Enter IP or hostname: " SYNOLOGY_DIRECT_IP
                ;;
            3)
                read -p "Enter QuickConnect ID (without .quickconnect.to): " SYNOLOGY_QUICKCONNECT
                read -p "Enter IP or hostname: " SYNOLOGY_DIRECT_IP
                ;;
            *)
                msg_warn "Invalid selection, skipping Synology"
                SYNOLOGY_ENABLED=false
                ;;
        esac
    fi
fi

export DRIVE_GOOGLE DRIVE_ONEDRIVE DRIVE_DROPBOX DRIVE_PROTON SYNOLOGY_ENABLED SYNOLOGY_QUICKCONNECT SYNOLOGY_DIRECT_IP

# ========================================
# VM TYPE SELECTION
# ========================================

echo ""
echo -e "${BLUE}=== VM Type Selection ===${NC}"
echo ""
echo "  1) DispVM only (disposable, reset on shutdown)"
echo "  2) AppVM only (persistent)"
echo "  3) Both DispVM and AppVM"
echo ""
read -p "Select VM types [1-3]: " VM_CHOICE

CREATE_DISPVM=false
CREATE_APPVM=false

case "$VM_CHOICE" in
    1) CREATE_DISPVM=true ;;
    2) CREATE_APPVM=true ;;
    3) CREATE_DISPVM=true; CREATE_APPVM=true ;;
    *) msg_error "Invalid selection"; exit 1 ;;
esac

export CREATE_DISPVM CREATE_APPVM

echo ""

# ========================================
# BUILD BLOCK LIST FOR EXISTING VMS
# ========================================

# Build list of service config files that should be blocked in existing VMs
# This list will be used later to offer blocking in VMs like 'work', 'personal', etc.
BLOCK_IN_GENERIC=""

# Email services
if $CREATE_EMAIL; then
    $EMAIL_GMAIL && BLOCK_IN_GENERIC="$BLOCK_IN_GENERIC gmail.conf"
    $EMAIL_OUTLOOK && BLOCK_IN_GENERIC="$BLOCK_IN_GENERIC outlook.conf"
    $EMAIL_PROTON && BLOCK_IN_GENERIC="$BLOCK_IN_GENERIC protonmail.conf"
fi

# Drive services
if $CREATE_DRIVE; then
    $DRIVE_GOOGLE && BLOCK_IN_GENERIC="$BLOCK_IN_GENERIC gdrive.conf"
    $DRIVE_ONEDRIVE && BLOCK_IN_GENERIC="$BLOCK_IN_GENERIC onedrive.conf"
    $DRIVE_DROPBOX && BLOCK_IN_GENERIC="$BLOCK_IN_GENERIC dropbox.conf"
    $DRIVE_PROTON && BLOCK_IN_GENERIC="$BLOCK_IN_GENERIC protondrive.conf"
    $SYNOLOGY_ENABLED && BLOCK_IN_GENERIC="$BLOCK_IN_GENERIC synology.conf"
fi

# Banking
$CREATE_BANKING && BLOCK_IN_GENERIC="$BLOCK_IN_GENERIC banking-fr.conf payment.conf"

# Crypto
$CREATE_CRYPTO && BLOCK_IN_GENERIC="$BLOCK_IN_GENERIC crypto.conf"

# Government
$CREATE_GOV && BLOCK_IN_GENERIC="$BLOCK_IN_GENERIC gov-fr.conf"

# Health
$CREATE_HEALTH && BLOCK_IN_GENERIC="$BLOCK_IN_GENERIC health-fr.conf"

export BLOCK_IN_GENERIC

# ========================================
# CREATE TEMPLATES AND VMS
# ========================================

# Create selected profiles
$CREATE_EMAIL && create_filtered_template "$BASE_TEMPLATE" "email" && {
    $CREATE_DISPVM && create_dispvm_template "$CREATED_TEMPLATE" "yellow" "dvm-email" && create_dom0_shortcuts "dvm-email" "email"
    $CREATE_APPVM && create_appvm "$CREATED_TEMPLATE" "yellow" "email"
    echo ""
}

$CREATE_SOCIAL && create_filtered_template "$BASE_TEMPLATE" "social" && {
    $CREATE_DISPVM && create_dispvm_template "$CREATED_TEMPLATE" "orange" "dvm-social" && create_dom0_shortcuts "dvm-social" "social"
    $CREATE_APPVM && create_appvm "$CREATED_TEMPLATE" "orange" "social"
    echo ""
}

$CREATE_WORK && create_filtered_template "$BASE_TEMPLATE" "work" && {
    $CREATE_DISPVM && create_dispvm_template "$CREATED_TEMPLATE" "purple" "dvm-work" && create_dom0_shortcuts "dvm-work" "work"
    $CREATE_APPVM && create_appvm "$CREATED_TEMPLATE" "purple" "work"
    echo ""
}

$CREATE_DRIVE && create_filtered_template "$BASE_TEMPLATE" "drive" && {
    $CREATE_DISPVM && create_dispvm_template "$CREATED_TEMPLATE" "blue" "dvm-drive" && create_dom0_shortcuts "dvm-drive" "drive"
    $CREATE_APPVM && create_appvm "$CREATED_TEMPLATE" "blue" "drive"
    echo ""
}

$CREATE_BANKING && create_filtered_template "$BASE_TEMPLATE" "banking" && {
    $CREATE_DISPVM && create_dispvm_template "$CREATED_TEMPLATE" "red" "dvm-banking" && create_dom0_shortcuts "dvm-banking" "banking"
    $CREATE_APPVM && create_appvm "$CREATED_TEMPLATE" "red" "banking"
    echo ""
}

$CREATE_CRYPTO && create_filtered_template "$BASE_TEMPLATE" "crypto" && {
    $CREATE_DISPVM && create_dispvm_template "$CREATED_TEMPLATE" "red" "dvm-crypto" && create_dom0_shortcuts "dvm-crypto" "crypto"
    $CREATE_APPVM && create_appvm "$CREATED_TEMPLATE" "red" "crypto"
    echo ""
}

$CREATE_GOV && create_filtered_template "$BASE_TEMPLATE" "gov" && {
    $CREATE_DISPVM && create_dispvm_template "$CREATED_TEMPLATE" "gray" "dvm-gov" && create_dom0_shortcuts "dvm-gov" "gov"
    $CREATE_APPVM && create_appvm "$CREATED_TEMPLATE" "gray" "gov"
    echo ""
}

$CREATE_HEALTH && create_filtered_template "$BASE_TEMPLATE" "health" && {
    $CREATE_DISPVM && create_dispvm_template "$CREATED_TEMPLATE" "red" "dvm-health" && create_dom0_shortcuts "dvm-health" "health"
    $CREATE_APPVM && create_appvm "$CREATED_TEMPLATE" "red" "health"
    echo ""
}

$CREATE_SHOPPING && create_filtered_template "$BASE_TEMPLATE" "shopping" && {
    $CREATE_DISPVM && create_dispvm_template "$CREATED_TEMPLATE" "orange" "dvm-shopping" && create_dom0_shortcuts "dvm-shopping" "shopping"
    $CREATE_APPVM && create_appvm "$CREATED_TEMPLATE" "orange" "shopping"
    echo ""
}

$CREATE_TRAVEL && create_filtered_template "$BASE_TEMPLATE" "travel" && {
    $CREATE_DISPVM && create_dispvm_template "$CREATED_TEMPLATE" "green" "dvm-travel" && create_dom0_shortcuts "dvm-travel" "travel"
    $CREATE_APPVM && create_appvm "$CREATED_TEMPLATE" "green" "travel"
    echo ""
}

$CREATE_MEDIA && create_filtered_template "$BASE_TEMPLATE" "media" && {
    $CREATE_DISPVM && create_dispvm_template "$CREATED_TEMPLATE" "green" "dvm-media" && create_dom0_shortcuts "dvm-media" "media"
    $CREATE_APPVM && create_appvm "$CREATED_TEMPLATE" "green" "media"
    echo ""
}

$CREATE_NEWS && create_filtered_template "$BASE_TEMPLATE" "news" && {
    $CREATE_DISPVM && create_dispvm_template "$CREATED_TEMPLATE" "yellow" "dvm-news" && create_dom0_shortcuts "dvm-news" "news"
    $CREATE_APPVM && create_appvm "$CREATED_TEMPLATE" "yellow" "news"
    echo ""
}

$CREATE_ADMIN && create_filtered_template "$BASE_TEMPLATE" "admin" && {
    $CREATE_DISPVM && create_dispvm_template "$CREATED_TEMPLATE" "purple" "dvm-admin" && create_dom0_shortcuts "dvm-admin" "admin"
    $CREATE_APPVM && create_appvm "$CREATED_TEMPLATE" "purple" "admin"
    echo ""
}

$CREATE_AI && create_filtered_template "$BASE_TEMPLATE" "ai" && {
    $CREATE_DISPVM && create_dispvm_template "$CREATED_TEMPLATE" "blue" "dvm-ai" && create_dom0_shortcuts "dvm-ai" "ai"
    $CREATE_APPVM && create_appvm "$CREATED_TEMPLATE" "blue" "ai"
    echo ""
}

# ========================================
# APPLY BLOCKS TO EXISTING VMS
# ========================================

# Only offer this if we have something to block
if [[ -n "$BLOCK_IN_GENERIC" ]]; then
    echo -e "${BLUE}=== Block Domains in Existing VMs ===${NC}"
    echo ""
    echo -e "  ${YELLOW}Apply blocking rules to your existing QubesOS VMs?${NC}"
    echo ""
    echo "  This will block the domains from your specialized VMs"
    echo "  (email, banking, etc.) in your existing VMs like 'work',"
    echo "  'personal', 'untrusted', etc."
    echo ""
    echo "  The existing VMs will keep full internet access,"
    echo "  but won't be able to access your specialized services."
    echo ""
    read -p "Configure existing VMs? (y/N): " CONFIGURE_EXISTING
    
    if [[ "$CONFIGURE_EXISTING" =~ ^[Yy]$ ]]; then
        echo ""
        
        # List existing AppVMs (exclude system VMs and VMs we just created)
        SYSTEM_VMS="dom0|sys-net|sys-firewall|sys-usb|sys-whonix|default-mgmt-dvm"
        CREATED_VMS="email|drive|banking|crypto|gov|health|shopping|travel|media|news|admin|ai|social|work"
        DVM_PATTERN="^dvm-|^disp"
        TEMPLATE_PATTERN="-email$|-drive$|-banking$|-crypto$|-gov$|-health$|-shopping$|-travel$|-media$|-news$|-admin$|-ai$|-social$|-work$|-filtered$"
        
        # Get list of AppVMs
        EXISTING_VMS=$(qvm-ls --raw-list --fields=name,class 2>/dev/null | grep "AppVM" | cut -d'|' -f1 | grep -vE "^($SYSTEM_VMS)$" | grep -vE "^($CREATED_VMS)$" | grep -vE "$DVM_PATTERN" | grep -vE "$TEMPLATE_PATTERN" | sort)
        
        if [[ -z "$EXISTING_VMS" ]]; then
            msg_warn "No existing AppVMs found to configure"
        else
            echo "Found existing AppVMs:"
            echo ""
            
            declare -a VM_ARRAY
            i=1
            while IFS= read -r vm; do
                VM_ARRAY+=("$vm")
                local vm_template=$(qvm-prefs "$vm" template 2>/dev/null)
                echo "  $i) $vm (template: $vm_template)"
                ((i++))
            done <<< "$EXISTING_VMS"
            
            echo ""
            echo -e "  ${YELLOW}a) Select all${NC}"
            echo -e "  ${YELLOW}n) Select none (skip)${NC}"
            echo ""
            echo "Enter numbers separated by spaces (e.g., '1 2 3') or 'a' for all:"
            read -p "> " VM_SELECTION
            
            declare -a SELECTED_VMS
            
            if [[ "$VM_SELECTION" == "a" ]]; then
                SELECTED_VMS=("${VM_ARRAY[@]}")
            elif [[ "$VM_SELECTION" != "n" && -n "$VM_SELECTION" ]]; then
                for num in $VM_SELECTION; do
                    if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le ${#VM_ARRAY[@]} ]; then
                        SELECTED_VMS+=("${VM_ARRAY[$((num-1))]}")
                    fi
                done
            fi
            
            if [ ${#SELECTED_VMS[@]} -gt 0 ]; then
                echo ""
                echo "Will apply blocks to:"
                for vm in "${SELECTED_VMS[@]}"; do
                    echo "  - $vm"
                done
                echo ""
                echo "Blocked domains:"
                for conf in $BLOCK_IN_GENERIC; do
                    echo "  - ${conf%.conf}"
                done
                echo ""
                read -p "Confirm? (y/N): " CONFIRM_BLOCKS
                
                if [[ "$CONFIRM_BLOCKS" =~ ^[Yy]$ ]]; then
                    echo ""
                    
                    # Group VMs by template to avoid modifying the same template multiple times
                    declare -A TEMPLATES_TO_MODIFY
                    for vm in "${SELECTED_VMS[@]}"; do
                        local vm_template=$(qvm-prefs "$vm" template 2>/dev/null)
                        if [[ -n "$vm_template" ]]; then
                            TEMPLATES_TO_MODIFY["$vm_template"]+="$vm "
                        fi
                    done
                    
                    # Apply blocks to each template once
                    for template in "${!TEMPLATES_TO_MODIFY[@]}"; do
                        local vms="${TEMPLATES_TO_MODIFY[$template]}"
                        msg_info "Configuring template $template (used by: $vms)..."
                        
                        # Use the first VM to apply blocks (they all share the template)
                        local first_vm=$(echo "$vms" | awk '{print $1}')
                        apply_blocks_to_existing_vm "$first_vm" "$BLOCK_IN_GENERIC"
                        echo ""
                    done
                    
                    BLOCKS_APPLIED=true
                else
                    msg_warn "Skipped"
                fi
            else
                msg_warn "No VMs selected"
            fi
        fi
    else
        msg_info "Skipping existing VMs configuration"
    fi
    echo ""
fi

# ========================================
# SUMMARY
# ========================================

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   Installation Complete!              ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

echo -e "${YELLOW}Created profiles:${NC}"
$CREATE_EMAIL && echo "  ✓ email (Gmail, Outlook, ProtonMail)"
$CREATE_SOCIAL && echo "  ✓ social (Facebook, Instagram, Twitter, Discord...)"
$CREATE_WORK && echo "  ✓ work (Slack, Teams, Notion, Zoom...)"
$CREATE_DRIVE && echo "  ✓ drive (Google Drive, OneDrive, Dropbox...)"
$CREATE_BANKING && echo "  ✓ banking (Banques FR + PayPal, Lydia...)"
$CREATE_CRYPTO && echo "  ✓ crypto (Binance, Kraken, Ledger...)"
$CREATE_GOV && echo "  ✓ gov (Impôts, CAF, Ameli, ANTS...)"
$CREATE_HEALTH && echo "  ✓ health (Doctolib, mutuelles, pharmacies...)"
$CREATE_SHOPPING && echo "  ✓ shopping (Amazon, Fnac, Leboncoin...)"
$CREATE_TRAVEL && echo "  ✓ travel (SNCF, Booking, Airbnb...)"
$CREATE_MEDIA && echo "  ✓ media (Netflix, YouTube, Spotify...)"
$CREATE_NEWS && echo "  ✓ news (Le Monde, BFM, tech sites...)"
$CREATE_ADMIN && echo "  ✓ admin (GitHub, OVH, Cloudflare...)"
$CREATE_AI && echo "  ✓ ai (ChatGPT, Claude, Mistral...)"
echo ""

echo -e "${YELLOW}Security:${NC}"
echo "  ✓ DNS filtering via local dnsmasq"
echo "  ✓ DoH blocked (Firefox + DNS)"
echo "  ✓ All configs immutable (chattr +i)"
if [[ "$BLOCKS_APPLIED" == "true" ]]; then
    echo "  ✓ Specialized domains blocked in existing VMs"
fi
echo ""

echo -e "${YELLOW}Usage:${NC}"
if $CREATE_DISPVM; then
    echo "  Launch from Qubes menu → dvm-<profile> → Firefox"
    echo "  Or: qvm-run --dispvm=dvm-<profile> firefox"
fi
if $CREATE_APPVM; then
    echo "  qvm-run <profile> firefox"
fi
echo ""

echo -e "${YELLOW}Test filtering:${NC}"
echo "  # Should be blocked (returns 0.0.0.0):"
echo "  qvm-run <vm> 'getent hosts wikipedia.org'"
echo ""
echo "  # Should work (returns real IPs):"
$CREATE_EMAIL && echo "  qvm-run email 'getent hosts mail.google.com'"
$CREATE_BANKING && echo "  qvm-run banking 'getent hosts boursorama.com'"
$CREATE_GOV && echo "  qvm-run gov 'getent hosts impots.gouv.fr'"
echo ""

echo -e "${YELLOW}Customize:${NC}"
echo "  Edit: lib/config/services/<service>.conf"
echo "  Then re-run: ./setup.sh"
echo ""
