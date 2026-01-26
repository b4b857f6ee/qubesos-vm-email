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
echo -e "${YELLOW}   v1.0                                ${NC}"
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

select_template "Select base template" "\-(email|drive|filtered)$"
BASE_TEMPLATE="$SELECTED_TEMPLATE"

echo ""

# ========================================
# PROFILE SELECTION
# ========================================

echo -e "${BLUE}=== Profile Selection ===${NC}"
echo ""
echo "  1) Email only"
echo "  2) Drive only"
echo "  3) Both Email and Drive"
echo ""
read -p "Select profiles [1-3]: " PROFILE_CHOICE

CREATE_EMAIL=false
CREATE_DRIVE=false

case "$PROFILE_CHOICE" in
    1) CREATE_EMAIL=true ;;
    2) CREATE_DRIVE=true ;;
    3) CREATE_EMAIL=true; CREATE_DRIVE=true ;;
    *) msg_error "Invalid selection"; exit 1 ;;
esac

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
    
    # Validate at least one selected
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
    
    # Validate at least one selected
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

echo ""

# ========================================
# VM TYPE SELECTION
# ========================================

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

echo ""

# ========================================
# CREATE TEMPLATES AND VMS
# ========================================

if $CREATE_EMAIL; then
    create_filtered_template "$BASE_TEMPLATE" "email"
    EMAIL_TEMPLATE="$CREATED_TEMPLATE"
    
    if $CREATE_DISPVM; then
        create_dispvm_template "$EMAIL_TEMPLATE" "yellow" "dvm-email"
        create_dom0_shortcuts "dvm-email" "email"
    fi
    
    if $CREATE_APPVM; then
        create_appvm "$EMAIL_TEMPLATE" "yellow" "email"
    fi
    echo ""
fi

if $CREATE_DRIVE; then
    create_filtered_template "$BASE_TEMPLATE" "drive"
    DRIVE_TEMPLATE="$CREATED_TEMPLATE"
    
    if $CREATE_DISPVM; then
        create_dispvm_template "$DRIVE_TEMPLATE" "blue" "dvm-drive"
        create_dom0_shortcuts "dvm-drive" "drive"
    fi
    
    if $CREATE_APPVM; then
        create_appvm "$DRIVE_TEMPLATE" "blue" "drive"
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

echo -e "${YELLOW}Created:${NC}"
$CREATE_EMAIL && echo "  ✓ Template: ${BASE_TEMPLATE}-email"
$CREATE_DRIVE && echo "  ✓ Template: ${BASE_TEMPLATE}-drive"
$CREATE_EMAIL && $CREATE_DISPVM && echo "  ✓ DispVM template: dvm-email"
$CREATE_DRIVE && $CREATE_DISPVM && echo "  ✓ DispVM template: dvm-drive"
$CREATE_EMAIL && $CREATE_APPVM && echo "  ✓ AppVM: email"
$CREATE_DRIVE && $CREATE_APPVM && echo "  ✓ AppVM: drive"
echo ""

echo -e "${YELLOW}Security:${NC}"
echo "  ✓ DNS filtering via local dnsmasq"
echo "  ✓ DoH blocked (Firefox + DNS)"
echo "  ✓ All configs immutable (chattr +i)"
echo ""

echo -e "${YELLOW}Usage:${NC}"
if $CREATE_DISPVM; then
    echo "  Launch from Qubes menu → dvm-email/dvm-drive → Firefox"
fi
if $CREATE_APPVM; then
    $CREATE_EMAIL && echo "  qvm-run email firefox"
    $CREATE_DRIVE && echo "  qvm-run drive firefox"
fi
echo ""

echo -e "${YELLOW}Test filtering:${NC}"
echo "  # Should be blocked (returns 0.0.0.0):"
echo "  qvm-run <vm> 'getent hosts wikipedia.org'"
echo ""
echo "  # Should work (returns real IPs):"
$CREATE_EMAIL && echo "  qvm-run <vm> 'getent hosts mail.google.com'"
$CREATE_DRIVE && echo "  qvm-run <vm> 'getent hosts drive.google.com'"
echo ""

echo -e "${YELLOW}Add domains:${NC}"
echo "  Edit: lib/config/email.conf or lib/config/drive.conf"
echo "  Then re-run: ./setup.sh"
echo ""
