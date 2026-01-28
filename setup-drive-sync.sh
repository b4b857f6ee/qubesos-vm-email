#!/bin/bash
#
# setup-drive-sync.sh
# QubesOS Drive Sync VM - Client lourd avec stockage persistant
# Run from dom0
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"

# ========================================
# HEADER
# ========================================

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}   QubesOS Drive Sync Setup            ${NC}"
echo -e "${YELLOW}   Client lourd + Stockage persistant  ${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

check_dom0

# ========================================
# CONFIGURATION
# ========================================

VM_NAME="drive-sync"
CONFIG_DIR="$SCRIPT_DIR/lib/config"
SERVICES_DIR="$CONFIG_DIR/services"

# ========================================
# CHECK EXISTING VM
# ========================================

if qvm-check --quiet "$VM_NAME" 2>/dev/null; then
    echo -e "${YELLOW}VM '$VM_NAME' already exists.${NC}"
    echo ""
    echo "  1) Delete and recreate"
    echo "  2) Update configuration only"
    echo "  3) Cancel"
    echo ""
    read -p "Select option [1-3]: " EXISTING_CHOICE
    
    case "$EXISTING_CHOICE" in
        1)
            msg_info "Removing existing VM..."
            qvm-kill "$VM_NAME" 2>/dev/null || true
            qvm-remove -f "$VM_NAME" 2>/dev/null || true
            ;;
        2)
            msg_info "Will update configuration..."
            UPDATE_ONLY=true
            ;;
        *)
            msg_warn "Cancelled"
            exit 0
            ;;
    esac
fi

# ========================================
# TEMPLATE SELECTION
# ========================================

if [[ "$UPDATE_ONLY" != "true" ]]; then
    echo -e "${BLUE}=== Base Template Selection ===${NC}"
    echo ""
    
    select_template "Select base template" "\-(email|drive|banking|shopping|social|media|travel|admin|health|gov|ai|crypto|news|work|filtered|sync)$"
    BASE_TEMPLATE="$SELECTED_TEMPLATE"
    echo ""
fi

# ========================================
# STORAGE SIZE
# ========================================

echo -e "${BLUE}=== Storage Configuration ===${NC}"
echo ""
echo "Select storage size for synchronized files:"
echo ""
echo "  1) 50 GB"
echo "  2) 100 GB"
echo "  3) 200 GB"
echo "  4) 500 GB"
echo "  5) 1 TB (1000 GB)"
echo "  6) Custom size"
echo ""
read -p "Select size [1-6]: " SIZE_CHOICE

case "$SIZE_CHOICE" in
    1) STORAGE_SIZE=51200 ;;    # 50 GB in MB
    2) STORAGE_SIZE=102400 ;;   # 100 GB
    3) STORAGE_SIZE=204800 ;;   # 200 GB
    4) STORAGE_SIZE=512000 ;;   # 500 GB
    5) STORAGE_SIZE=1024000 ;;  # 1 TB
    6)
        read -p "Enter size in GB: " CUSTOM_SIZE
        STORAGE_SIZE=$((CUSTOM_SIZE * 1024))
        ;;
    *)
        msg_error "Invalid selection"
        exit 1
        ;;
esac

STORAGE_GB=$((STORAGE_SIZE / 1024))
msg_info "Storage size: ${STORAGE_GB} GB"
echo ""

# ========================================
# SERVICES SELECTION
# ========================================

echo -e "${BLUE}=== Drive Services ===${NC}"
echo ""
echo "Select services to configure:"
echo ""
echo "  1) Proton Drive (client officiel)"
echo "  2) Synology Drive Client"
echo "  3) Dropbox (client officiel)"
echo "  4) Google Drive (via rclone)"
echo "  5) OneDrive (via rclone)"
echo "  6) Nextcloud (client officiel)"
echo "  7) MEGA (client officiel)"
echo "  8) pCloud (client officiel)"
echo ""
echo "Enter numbers separated by spaces (e.g., '1 2 4') or 'a' for all:"
read -p "> " SERVICES_SELECTION

INSTALL_PROTON=false
INSTALL_SYNOLOGY=false
INSTALL_DROPBOX=false
INSTALL_GDRIVE=false
INSTALL_ONEDRIVE=false
INSTALL_NEXTCLOUD=false
INSTALL_MEGA=false
INSTALL_PCLOUD=false

if [[ "$SERVICES_SELECTION" == "a" ]]; then
    INSTALL_PROTON=true
    INSTALL_SYNOLOGY=true
    INSTALL_DROPBOX=true
    INSTALL_GDRIVE=true
    INSTALL_ONEDRIVE=true
    INSTALL_NEXTCLOUD=true
    INSTALL_MEGA=true
    INSTALL_PCLOUD=true
else
    for num in $SERVICES_SELECTION; do
        case "$num" in
            1) INSTALL_PROTON=true ;;
            2) INSTALL_SYNOLOGY=true ;;
            3) INSTALL_DROPBOX=true ;;
            4) INSTALL_GDRIVE=true ;;
            5) INSTALL_ONEDRIVE=true ;;
            6) INSTALL_NEXTCLOUD=true ;;
            7) INSTALL_MEGA=true ;;
            8) INSTALL_PCLOUD=true ;;
        esac
    done
fi

# Synology QuickConnect configuration
SYNOLOGY_QUICKCONNECT=""
SYNOLOGY_DIRECT_IP=""

if $INSTALL_SYNOLOGY; then
    echo ""
    echo -e "${BLUE}=== Synology Configuration ===${NC}"
    echo ""
    echo "  1) QuickConnect ID"
    echo "  2) Direct IP/hostname"
    echo "  3) Both"
    echo "  4) Configure later"
    echo ""
    read -p "Select connection type [1-4]: " SYNO_CHOICE
    
    case "$SYNO_CHOICE" in
        1)
            read -p "Enter QuickConnect ID (without .quickconnect.to): " SYNOLOGY_QUICKCONNECT
            ;;
        2)
            read -p "Enter IP or hostname: " SYNOLOGY_DIRECT_IP
            ;;
        3)
            read -p "Enter QuickConnect ID: " SYNOLOGY_QUICKCONNECT
            read -p "Enter IP or hostname: " SYNOLOGY_DIRECT_IP
            ;;
        4)
            msg_info "You can configure Synology Drive Client manually later"
            ;;
    esac
fi

echo ""

# ========================================
# CREATE TEMPLATE (if not update only)
# ========================================

if [[ "$UPDATE_ONLY" != "true" ]]; then
    TEMPLATE_NAME="${BASE_TEMPLATE}-drive-sync"
    
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}   Creating Drive Sync Template        ${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo ""
    
    detect_distro "$BASE_TEMPLATE"
    
    # Clone template
    msg_step "1/6" "Cloning template..."
    if qvm-check --quiet "$TEMPLATE_NAME" 2>/dev/null; then
        msg_warn "Template $TEMPLATE_NAME exists, removing..."
        qvm-kill "$TEMPLATE_NAME" 2>/dev/null || true
        qvm-remove -f "$TEMPLATE_NAME" 2>/dev/null || true
    fi
    qvm-clone "$BASE_TEMPLATE" "$TEMPLATE_NAME"
    
    # Start template
    msg_step "2/6" "Starting template..."
    qvm-start "$TEMPLATE_NAME" 2>/dev/null || true
    sleep 5
    
    # Install base packages
    msg_step "3/6" "Installing base packages..."
    
    # Install rclone from official source (repo versions are too old for Proton Drive support)
    msg_info "Installing rclone (latest version from rclone.org)..."
    qvm-run -u root "$TEMPLATE_NAME" 'curl -fsSL https://rclone.org/install.sh | bash' 2>/dev/null
    
    # Install fuse for rclone mount
    if [[ "$BASE_TEMPLATE" == *"fedora"* ]]; then
        qvm-run -u root "$TEMPLATE_NAME" "dnf install -y dnsmasq fuse3" 2>/dev/null
    else
        qvm-run -u root "$TEMPLATE_NAME" "apt-get update && apt-get install -y dnsmasq fuse3" 2>/dev/null
    fi
    
    # Install Proton Drive (via rclone - NO official Linux client exists)
    if $INSTALL_PROTON; then
        msg_info "Proton Drive: Using rclone (no official Linux client available)"
        msg_info "  → Configure with: rclone config (select 'protondrive')"
        msg_info "  → Mount with: rclone mount protondrive: ~/Sync/ProtonDrive"
        # rclone already installed above, nothing more to do
    fi
    
    # Install Synology Drive Client (version 4.0.1-17885 - January 2025)
    if $INSTALL_SYNOLOGY; then
        msg_info "Installing Synology Drive Client 4.0.1..."
        if [[ "$BASE_TEMPLATE" == *"fedora"* ]]; then
            # For Fedora: download DEB and convert with alien, or use community RPM
            qvm-run -u root "$TEMPLATE_NAME" "dnf install -y alien" 2>/dev/null
            qvm-run -u root "$TEMPLATE_NAME" "cd /tmp && wget -q 'https://global.synologydownload.com/download/Utility/SynologyDriveClient/4.0.1-17885/Ubuntu/Installer/synology-drive-client-17885.x86_64.deb' -O synology-drive.deb && alien -r synology-drive.deb && dnf install -y ./synology-drive-client*.rpm" 2>/dev/null || msg_warn "Synology Drive may require manual installation"
        else
            # For Debian/Ubuntu
            qvm-run -u root "$TEMPLATE_NAME" "cd /tmp && wget -q 'https://global.synologydownload.com/download/Utility/SynologyDriveClient/4.0.1-17885/Ubuntu/Installer/synology-drive-client-17885.x86_64.deb' -O synology-drive.deb && apt-get install -y ./synology-drive.deb" 2>/dev/null || msg_warn "Synology Drive may require manual installation"
        fi
    fi
    
    # Install Dropbox
    if $INSTALL_DROPBOX; then
        msg_info "Installing Dropbox..."
        if [[ "$BASE_TEMPLATE" == *"fedora"* ]]; then
            qvm-run -u root "$TEMPLATE_NAME" "dnf install -y nautilus-dropbox" 2>/dev/null || {
                # Fallback: install from Dropbox directly
                qvm-run -u root "$TEMPLATE_NAME" "cd /tmp && wget -q 'https://www.dropbox.com/download?dl=packages/fedora/nautilus-dropbox-2024.04.17-1.fc39.x86_64.rpm' -O dropbox.rpm && dnf install -y ./dropbox.rpm" 2>/dev/null || msg_warn "Dropbox may require manual installation"
            }
        else
            qvm-run -u root "$TEMPLATE_NAME" "cd /tmp && wget -q 'https://www.dropbox.com/download?dl=packages/ubuntu/dropbox_2024.04.17_amd64.deb' -O dropbox.deb && apt-get install -y ./dropbox.deb" 2>/dev/null || msg_warn "Dropbox may require manual installation"
        fi
    fi
    
    # Install Nextcloud client
    if $INSTALL_NEXTCLOUD; then
        msg_info "Installing Nextcloud client..."
        if [[ "$BASE_TEMPLATE" == *"fedora"* ]]; then
            qvm-run -u root "$TEMPLATE_NAME" "dnf install -y nextcloud-client" 2>/dev/null
        else
            qvm-run -u root "$TEMPLATE_NAME" "apt-get install -y nextcloud-desktop" 2>/dev/null
        fi
    fi
    
    # Install MEGA client
    if $INSTALL_MEGA; then
        msg_info "Installing MEGA client..."
        if [[ "$BASE_TEMPLATE" == *"fedora"* ]]; then
            qvm-run -u root "$TEMPLATE_NAME" "dnf install -y https://mega.nz/linux/repo/Fedora_40/x86_64/megasync-Fedora_40.x86_64.rpm" 2>/dev/null || msg_warn "MEGA may require manual installation"
        else
            qvm-run -u root "$TEMPLATE_NAME" "cd /tmp && wget -q 'https://mega.nz/linux/repo/Debian_12/amd64/megasync-Debian_12_amd64.deb' -O megasync.deb && apt-get install -y ./megasync.deb" 2>/dev/null || msg_warn "MEGA may require manual installation"
        fi
    fi
    
    # Google Drive and OneDrive use rclone (already installed)
    if $INSTALL_GDRIVE; then
        msg_info "Google Drive: Using rclone"
        msg_info "  → Configure with: rclone config (select 'drive')"
    fi
    
    if $INSTALL_ONEDRIVE; then
        msg_info "OneDrive: Using rclone"
        msg_info "  → Configure with: rclone config (select 'onedrive')"
    fi
    
    # Install pCloud
    if $INSTALL_PCLOUD; then
        msg_info "Installing pCloud..."
        qvm-run -u root "$TEMPLATE_NAME" "cd /tmp && wget -q 'https://www.pcloud.com/how-to-install-pcloud-drive-linux.html?download=electron-64' -O pcloud && chmod +x pcloud && mv pcloud /usr/local/bin/" 2>/dev/null || msg_warn "pCloud may require manual installation from pcloud.com"
    fi
    
    # Configure DNS filtering
    msg_step "4/6" "Configuring DNS filtering..."
    cat "$CONFIG_DIR/base.conf" | qvm-run -u root --pass-io "$TEMPLATE_NAME" "cat > /etc/dnsmasq.d/drive-sync-filter.conf"
    cat "$SERVICES_DIR/drive-sync.conf" | qvm-run -u root --pass-io "$TEMPLATE_NAME" "cat >> /etc/dnsmasq.d/drive-sync-filter.conf"
    
    # Add Synology QuickConnect if configured
    if [[ -n "$SYNOLOGY_QUICKCONNECT" ]]; then
        echo "server=/${SYNOLOGY_QUICKCONNECT}.quickconnect.to/9.9.9.9" | qvm-run -u root --pass-io "$TEMPLATE_NAME" "cat >> /etc/dnsmasq.d/drive-sync-filter.conf"
        echo "server=/${SYNOLOGY_QUICKCONNECT}.quickconnect.cn/9.9.9.9" | qvm-run -u root --pass-io "$TEMPLATE_NAME" "cat >> /etc/dnsmasq.d/drive-sync-filter.conf"
    fi
    if [[ -n "$SYNOLOGY_DIRECT_IP" ]] && [[ "$SYNOLOGY_DIRECT_IP" =~ [a-zA-Z] ]]; then
        echo "server=/${SYNOLOGY_DIRECT_IP}/9.9.9.9" | qvm-run -u root --pass-io "$TEMPLATE_NAME" "cat >> /etc/dnsmasq.d/drive-sync-filter.conf"
    fi
    
    qvm-run -u root "$TEMPLATE_NAME" "chmod 644 /etc/dnsmasq.d/drive-sync-filter.conf"
    
    # Configure system DNS
    qvm-run -u root "$TEMPLATE_NAME" 'systemctl stop systemd-resolved 2>/dev/null; systemctl disable systemd-resolved 2>/dev/null; systemctl mask systemd-resolved 2>/dev/null; true'
    qvm-run -u root "$TEMPLATE_NAME" 'sed -i "s/hosts:.*/hosts:      files dns myhostname/" /etc/nsswitch.conf'
    qvm-run -u root "$TEMPLATE_NAME" 'systemctl enable dnsmasq'
    qvm-run -u root "$TEMPLATE_NAME" 'rm -f /etc/resolv.conf; echo "nameserver 127.0.0.1" > /etc/resolv.conf'
    qvm-run -u root "$TEMPLATE_NAME" "chattr +i /etc/dnsmasq.d/drive-sync-filter.conf /etc/resolv.conf"
    
    # Configure Firefox DoH blocking
    msg_step "5/6" "Configuring Firefox..."
    qvm-run -u root "$TEMPLATE_NAME" "mkdir -p $FF_ETC $FF_LIB"
    cat "$CONFIG_DIR/firefox.json" | qvm-run -u root --pass-io "$TEMPLATE_NAME" "cat > $FF_ETC/policies.json"
    cat "$CONFIG_DIR/firefox.json" | qvm-run -u root --pass-io "$TEMPLATE_NAME" "cat > $FF_LIB/policies.json"
    qvm-run -u root "$TEMPLATE_NAME" "chmod 644 $FF_ETC/policies.json $FF_LIB/policies.json"
    qvm-run -u root "$TEMPLATE_NAME" "chattr +i $FF_ETC/policies.json $FF_LIB/policies.json"
    
    # Create Sync directory structure
    msg_step "6/6" "Creating directory structure..."
    qvm-run -u root "$TEMPLATE_NAME" 'mkdir -p /etc/skel/Sync/{ProtonDrive,Synology,Dropbox,GoogleDrive,OneDrive,Nextcloud,MEGA,pCloud}'
    qvm-run -u root "$TEMPLATE_NAME" 'mkdir -p /etc/skel/Desktop'
    
    # Create desktop shortcuts
    qvm-run -u root "$TEMPLATE_NAME" 'cat > /etc/skel/Desktop/sync-folder.desktop << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Sync Folder
Comment=Open synchronized files folder
Exec=xdg-open /home/user/Sync
Icon=folder-sync
Terminal=false
Categories=Utility;FileManager;
StartupNotify=true
EOF
chmod +x /etc/skel/Desktop/sync-folder.desktop'

    # Create rclone mount script for Google Drive / OneDrive
    qvm-run -u root "$TEMPLATE_NAME" 'cat > /usr/local/bin/mount-rclone << "SCRIPT"
#!/bin/bash
# Mount rclone remotes
# Usage: mount-rclone <remote-name> <mount-point>

REMOTE="$1"
MOUNT_POINT="$2"

if [[ -z "$REMOTE" || -z "$MOUNT_POINT" ]]; then
    echo "Usage: mount-rclone <remote-name> <mount-point>"
    echo "Example: mount-rclone gdrive: /home/user/Sync/GoogleDrive"
    exit 1
fi

mkdir -p "$MOUNT_POINT"
rclone mount "$REMOTE" "$MOUNT_POINT" \
    --vfs-cache-mode writes \
    --vfs-cache-max-size 1G \
    --dir-cache-time 72h \
    --poll-interval 15s \
    --daemon

echo "Mounted $REMOTE at $MOUNT_POINT"
SCRIPT
chmod +x /usr/local/bin/mount-rclone'

    # Create autostart script
    qvm-run -u root "$TEMPLATE_NAME" 'cat > /etc/skel/.config/autostart/drive-sync.desktop << EOF
[Desktop Entry]
Type=Application
Name=Drive Sync Services
Comment=Start drive synchronization services
Exec=/home/user/.local/bin/start-sync.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
EOF
mkdir -p /etc/skel/.config/autostart
mkdir -p /etc/skel/.local/bin'

    qvm-run -u root "$TEMPLATE_NAME" 'cat > /etc/skel/.local/bin/start-sync.sh << "SCRIPT"
#!/bin/bash
# Auto-start sync services
# Edit this script to configure which services to start

# Uncomment and configure the services you use:

# Proton Drive (starts automatically via systemd/flatpak)
# Nothing to do here

# Synology Drive Client (starts automatically)
# synology-drive &

# Dropbox (starts automatically after initial setup)
# dropbox start

# Google Drive via rclone (configure first with: rclone config)
# mount-rclone gdrive: /home/user/Sync/GoogleDrive

# OneDrive via rclone (configure first with: rclone config)
# mount-rclone onedrive: /home/user/Sync/OneDrive

echo "Sync services started. Check individual service status."
SCRIPT
chmod +x /etc/skel/.local/bin/start-sync.sh'

    # Copy to existing user
    qvm-run -u root "$TEMPLATE_NAME" 'if [ -d /home/user ]; then
        mkdir -p /home/user/Sync/{ProtonDrive,Synology,Dropbox,GoogleDrive,OneDrive,Nextcloud,MEGA,pCloud}
        mkdir -p /home/user/.config/autostart
        mkdir -p /home/user/.local/bin
        cp /etc/skel/Desktop/*.desktop /home/user/Desktop/ 2>/dev/null || true
        cp /etc/skel/.config/autostart/*.desktop /home/user/.config/autostart/ 2>/dev/null || true
        cp /etc/skel/.local/bin/*.sh /home/user/.local/bin/ 2>/dev/null || true
        chown -R user:user /home/user/Sync /home/user/.config /home/user/.local /home/user/Desktop
    fi'
    
    # Shutdown template
    msg_info "Shutting down template..."
    wait_for_shutdown "$TEMPLATE_NAME"
    
    msg_ok "Template created: $TEMPLATE_NAME"
    echo ""
fi

# ========================================
# CREATE APPVM
# ========================================

if [[ "$UPDATE_ONLY" != "true" ]]; then
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}   Creating Drive Sync AppVM           ${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo ""
    
    msg_step "1/3" "Creating AppVM..."
    qvm-create --template "$TEMPLATE_NAME" --label blue "$VM_NAME"
    
    msg_step "2/3" "Configuring storage (${STORAGE_GB} GB)..."
    qvm-volume resize "${VM_NAME}:private" "${STORAGE_SIZE}MB"
    
    msg_step "3/3" "Setting VM properties..."
    qvm-prefs "$VM_NAME" memory 2048
    qvm-prefs "$VM_NAME" maxmem 4096
    qvm-prefs "$VM_NAME" vcpus 2
    
    msg_ok "AppVM created: $VM_NAME"
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
echo "  ✓ Template: ${TEMPLATE_NAME:-$BASE_TEMPLATE-drive-sync}"
echo "  ✓ AppVM: $VM_NAME"
echo "  ✓ Storage: ${STORAGE_GB} GB"
echo ""

echo -e "${YELLOW}Installed services:${NC}"
$INSTALL_PROTON && echo "  ✓ Proton Drive (via rclone - no official Linux client)"
$INSTALL_SYNOLOGY && echo "  ✓ Synology Drive Client 4.0.1"
$INSTALL_DROPBOX && echo "  ✓ Dropbox"
$INSTALL_GDRIVE && echo "  ✓ Google Drive (via rclone)"
$INSTALL_ONEDRIVE && echo "  ✓ OneDrive (via rclone)"
$INSTALL_NEXTCLOUD && echo "  ✓ Nextcloud"
$INSTALL_MEGA && echo "  ✓ MEGA"
$INSTALL_PCLOUD && echo "  ✓ pCloud"
echo ""

echo -e "${YELLOW}Usage:${NC}"
echo "  # Start the VM"
echo "  qvm-start $VM_NAME"
echo ""
echo "  # Open file manager"
echo "  qvm-run $VM_NAME 'xdg-open /home/user/Sync'"
echo ""

echo -e "${YELLOW}rclone Configuration (for Proton/Google/OneDrive):${NC}"
echo "  # Configure a new remote"
echo "  qvm-run $VM_NAME 'rclone config'"
echo ""
echo "  # Available backends:"
$INSTALL_PROTON && echo "    - protondrive (Proton Drive)"
$INSTALL_GDRIVE && echo "    - drive (Google Drive)"
$INSTALL_ONEDRIVE && echo "    - onedrive (OneDrive)"
echo ""
echo "  # Mount example (Proton Drive)"
echo "  qvm-run $VM_NAME 'mkdir -p ~/Sync/ProtonDrive && rclone mount protondrive: ~/Sync/ProtonDrive --vfs-cache-mode writes &'"
echo ""

if $INSTALL_SYNOLOGY; then
    echo -e "${YELLOW}Synology:${NC}"
    if [[ -n "$SYNOLOGY_QUICKCONNECT" ]]; then
        echo "  QuickConnect: ${SYNOLOGY_QUICKCONNECT}.quickconnect.to"
    fi
    if [[ -n "$SYNOLOGY_DIRECT_IP" ]]; then
        echo "  Direct: ${SYNOLOGY_DIRECT_IP}"
    fi
    echo "  # Start Synology Drive Client GUI"
    echo "  qvm-run $VM_NAME 'synology-drive'"
    echo ""
fi

echo -e "${YELLOW}Sync folders:${NC}"
echo "  /home/user/Sync/ProtonDrive"
echo "  /home/user/Sync/Synology"
echo "  /home/user/Sync/Dropbox"
echo "  /home/user/Sync/GoogleDrive"
echo "  /home/user/Sync/OneDrive"
echo "  /home/user/Sync/Nextcloud"
echo "  /home/user/Sync/MEGA"
echo "  /home/user/Sync/pCloud"
echo ""
