#!/bin/bash
#
# setup-messaging.sh
# QubesOS Messaging VM - Clients de messagerie instantanée
# Run from dom0
#

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/common.sh"
source "$SCRIPT_DIR/lib/template.sh"

# ========================================
# HEADER
# ========================================

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}   QubesOS Messaging VM Setup          ${NC}"
echo -e "${YELLOW}   Signal, WhatsApp, Telegram, etc.    ${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

check_dom0

# ========================================
# CONFIGURATION
# ========================================

VM_NAME="messaging"
TEMPLATE_NAME=""
CONFIG_DIR="$SCRIPT_DIR/lib/config"
SERVICES_DIR="$CONFIG_DIR/services"

# ========================================
# CHECK EXISTING VM
# ========================================

if qvm-check --quiet "$VM_NAME" 2>/dev/null; then
    echo -e "${YELLOW}VM '$VM_NAME' already exists.${NC}"
    echo ""
    echo "  1) Delete and recreate"
    echo "  2) Cancel"
    echo ""
    read -p "Select option [1-2]: " EXISTING_CHOICE
    
    case "$EXISTING_CHOICE" in
        1)
            msg_info "Removing existing VM and template..."
            qvm-kill "$VM_NAME" 2>/dev/null || true
            qvm-remove -f "$VM_NAME" 2>/dev/null || true
            # Find and remove template
            EXISTING_TEMPLATE=$(qvm-ls --raw-list --class TemplateVM 2>/dev/null | grep "\-messaging$" | head -1)
            if [[ -n "$EXISTING_TEMPLATE" ]]; then
                qvm-kill "$EXISTING_TEMPLATE" 2>/dev/null || true
                qvm-remove -f "$EXISTING_TEMPLATE" 2>/dev/null || true
            fi
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

echo -e "${BLUE}=== Base Template Selection ===${NC}"
echo ""

select_template "Select base template (Fedora recommended for best app support)" "\-(messaging|filtered)$"
BASE_TEMPLATE="$SELECTED_TEMPLATE"

detect_distro "$BASE_TEMPLATE"

echo ""

# ========================================
# MESSAGING APPS SELECTION
# ========================================

echo -e "${BLUE}=== Messaging Applications ===${NC}"
echo ""
echo "  ${CYAN}--- Privacy-focused (recommended) ---${NC}"
echo "  1) Signal (E2E encrypted, open source)"
echo "  2) Element/Matrix (Decentralized, E2E)"
echo "  3) Session (No phone number required)"
echo "  4) Olvid (French, certified ANSSI)"
echo "  5) Threema (Swiss, paid)"
echo "  6) Wire (E2E, open source)"
echo "  7) Briar (P2P, works offline)"
echo "  8) SimpleX (No user IDs)"
echo "  9) Jami (GNU, P2P)"
echo ""
echo "  ${CYAN}--- Popular ---${NC}"
echo "  10) Telegram"
echo "  11) WhatsApp (via web wrapper)"
echo "  12) Discord"
echo "  13) Slack"
echo "  14) Skype"
echo ""
echo -e "  ${YELLOW}a) All applications${NC}"
echo -e "  ${YELLOW}p) Privacy-focused only (1-9)${NC}"
echo ""
echo "Enter numbers separated by spaces (e.g., '1 2 10') or 'a'/'p':"
read -p "> " APP_SELECTION

# Initialize all app flags
INSTALL_SIGNAL=false
INSTALL_ELEMENT=false
INSTALL_SESSION=false
INSTALL_OLVID=false
INSTALL_THREEMA=false
INSTALL_WIRE=false
INSTALL_BRIAR=false
INSTALL_SIMPLEX=false
INSTALL_JAMI=false
INSTALL_TELEGRAM=false
INSTALL_WHATSAPP=false
INSTALL_DISCORD=false
INSTALL_SLACK=false
INSTALL_SKYPE=false

if [[ "$APP_SELECTION" == "a" ]]; then
    INSTALL_SIGNAL=true
    INSTALL_ELEMENT=true
    INSTALL_SESSION=true
    INSTALL_OLVID=true
    INSTALL_THREEMA=true
    INSTALL_WIRE=true
    INSTALL_BRIAR=true
    INSTALL_SIMPLEX=true
    INSTALL_JAMI=true
    INSTALL_TELEGRAM=true
    INSTALL_WHATSAPP=true
    INSTALL_DISCORD=true
    INSTALL_SLACK=true
    INSTALL_SKYPE=true
elif [[ "$APP_SELECTION" == "p" ]]; then
    INSTALL_SIGNAL=true
    INSTALL_ELEMENT=true
    INSTALL_SESSION=true
    INSTALL_OLVID=true
    INSTALL_THREEMA=true
    INSTALL_WIRE=true
    INSTALL_BRIAR=true
    INSTALL_SIMPLEX=true
    INSTALL_JAMI=true
else
    for num in $APP_SELECTION; do
        case "$num" in
            1) INSTALL_SIGNAL=true ;;
            2) INSTALL_ELEMENT=true ;;
            3) INSTALL_SESSION=true ;;
            4) INSTALL_OLVID=true ;;
            5) INSTALL_THREEMA=true ;;
            6) INSTALL_WIRE=true ;;
            7) INSTALL_BRIAR=true ;;
            8) INSTALL_SIMPLEX=true ;;
            9) INSTALL_JAMI=true ;;
            10) INSTALL_TELEGRAM=true ;;
            11) INSTALL_WHATSAPP=true ;;
            12) INSTALL_DISCORD=true ;;
            13) INSTALL_SLACK=true ;;
            14) INSTALL_SKYPE=true ;;
        esac
    done
fi

# Validate at least one selected
if ! $INSTALL_SIGNAL && ! $INSTALL_ELEMENT && ! $INSTALL_SESSION && \
   ! $INSTALL_OLVID && ! $INSTALL_THREEMA && ! $INSTALL_WIRE && \
   ! $INSTALL_BRIAR && ! $INSTALL_SIMPLEX && ! $INSTALL_JAMI && \
   ! $INSTALL_TELEGRAM && ! $INSTALL_WHATSAPP && ! $INSTALL_DISCORD && \
   ! $INSTALL_SLACK && ! $INSTALL_SKYPE; then
    msg_error "Select at least one application"
    exit 1
fi

echo ""

# ========================================
# CREATE TEMPLATE
# ========================================

TEMPLATE_NAME="${BASE_TEMPLATE}-messaging"

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}   Creating Messaging Template         ${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

# Clone template
msg_step "1/6" "Cloning template..."
qvm-clone "$BASE_TEMPLATE" "$TEMPLATE_NAME"

# Start template
msg_step "2/6" "Starting template..."
qvm-start "$TEMPLATE_NAME" 2>/dev/null || true
sleep 5

# Install dnsmasq and base packages
msg_step "3/6" "Installing base packages..."
qvm-run -u root "$TEMPLATE_NAME" "$PKG_INSTALL dnsmasq" 2>/dev/null

# Configure DNS filtering
msg_step "4/6" "Configuring DNS filtering..."
cat "$CONFIG_DIR/base.conf" | qvm-run -u root --pass-io "$TEMPLATE_NAME" "cat > /etc/dnsmasq.d/messaging-filter.conf"
cat "$SERVICES_DIR/messaging.conf" | qvm-run -u root --pass-io "$TEMPLATE_NAME" "cat >> /etc/dnsmasq.d/messaging-filter.conf"

qvm-run -u root "$TEMPLATE_NAME" "chmod 644 /etc/dnsmasq.d/messaging-filter.conf"
qvm-run -u root "$TEMPLATE_NAME" 'systemctl stop systemd-resolved 2>/dev/null; systemctl disable systemd-resolved 2>/dev/null; systemctl mask systemd-resolved 2>/dev/null; true'
qvm-run -u root "$TEMPLATE_NAME" 'sed -i "s/hosts:.*/hosts:      files dns myhostname/" /etc/nsswitch.conf'
qvm-run -u root "$TEMPLATE_NAME" 'systemctl enable dnsmasq'
qvm-run -u root "$TEMPLATE_NAME" 'rm -f /etc/resolv.conf; echo "nameserver 127.0.0.1" > /etc/resolv.conf'
qvm-run -u root "$TEMPLATE_NAME" "chattr +i /etc/dnsmasq.d/messaging-filter.conf /etc/resolv.conf"

# Install messaging applications
msg_step "5/6" "Installing messaging applications..."

# Determine if Fedora or Debian
IS_FEDORA=false
IS_DEBIAN=false
if [[ "$BASE_TEMPLATE" == *"fedora"* ]]; then
    IS_FEDORA=true
elif [[ "$BASE_TEMPLATE" == *"debian"* ]] || [[ "$BASE_TEMPLATE" == *"ubuntu"* ]]; then
    IS_DEBIAN=true
fi

# Signal
if $INSTALL_SIGNAL; then
    msg_info "Installing Signal..."
    if $IS_FEDORA; then
        qvm-run -u root "$TEMPLATE_NAME" 'cat > /etc/yum.repos.d/signal.repo << EOF
[signal]
name=Signal Desktop
baseurl=https://updates.signal.org/desktop/yum/
enabled=1
gpgcheck=1
gpgkey=https://updates.signal.org/desktop/yum/RPM-GPG-KEY-signal-desktop
EOF
dnf install -y signal-desktop' 2>/dev/null || msg_warn "Signal installation may require manual setup"
    else
        qvm-run -u root "$TEMPLATE_NAME" 'wget -qO- https://updates.signal.org/desktop/apt/keys.asc | gpg --dearmor > /usr/share/keyrings/signal-desktop-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/signal-desktop-keyring.gpg] https://updates.signal.org/desktop/apt xenial main" > /etc/apt/sources.list.d/signal.list
apt-get update && apt-get install -y signal-desktop' 2>/dev/null || msg_warn "Signal installation may require manual setup"
    fi
fi

# Element
if $INSTALL_ELEMENT; then
    msg_info "Installing Element..."
    if $IS_FEDORA; then
        qvm-run -u root "$TEMPLATE_NAME" 'dnf install -y https://packages.element.io/fedora/element-release-latest.rpm && dnf install -y element-desktop' 2>/dev/null || msg_warn "Element installation may require manual setup"
    else
        qvm-run -u root "$TEMPLATE_NAME" 'wget -qO- https://packages.element.io/debian/element-io-archive-keyring.gpg > /usr/share/keyrings/element-io-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/element-io-archive-keyring.gpg] https://packages.element.io/debian/ default main" > /etc/apt/sources.list.d/element.list
apt-get update && apt-get install -y element-desktop' 2>/dev/null || msg_warn "Element installation may require manual setup"
    fi
fi

# Session
if $INSTALL_SESSION; then
    msg_info "Installing Session..."
    # Session provides AppImage
    qvm-run -u root "$TEMPLATE_NAME" 'mkdir -p /opt/session
wget -q "https://github.com/oxen-io/session-desktop/releases/latest/download/session-desktop-linux-x86_64-1.14.3.AppImage" -O /opt/session/session.AppImage 2>/dev/null || wget -q "https://getsession.org/linux" -O /opt/session/session.AppImage
chmod +x /opt/session/session.AppImage
ln -sf /opt/session/session.AppImage /usr/local/bin/session' 2>/dev/null || msg_warn "Session installation may require manual setup"
    
    # Create desktop entry
    qvm-run -u root "$TEMPLATE_NAME" 'cat > /usr/share/applications/session.desktop << EOF
[Desktop Entry]
Name=Session
Comment=Private Messenger
Exec=/opt/session/session.AppImage --no-sandbox
Icon=session
Terminal=false
Type=Application
Categories=Network;InstantMessaging;
EOF' 2>/dev/null
fi

# Olvid
if $INSTALL_OLVID; then
    msg_info "Installing Olvid..."
    # Olvid has a Linux client available
    if $IS_DEBIAN; then
        qvm-run -u root "$TEMPLATE_NAME" 'wget -q "https://download.olvid.io/linux/olvid.deb" -O /tmp/olvid.deb && apt-get install -y /tmp/olvid.deb' 2>/dev/null || msg_warn "Olvid may require manual installation from olvid.io"
    else
        msg_warn "Olvid: Please download from https://olvid.io for Fedora"
    fi
fi

# Threema
if $INSTALL_THREEMA; then
    msg_info "Threema: Web-based only on Linux"
    # Threema doesn't have a native Linux client, create web shortcut
    qvm-run -u root "$TEMPLATE_NAME" 'cat > /usr/share/applications/threema.desktop << EOF
[Desktop Entry]
Name=Threema
Comment=Threema Web
Exec=firefox --new-window https://web.threema.ch
Icon=web-browser
Terminal=false
Type=Application
Categories=Network;InstantMessaging;
EOF' 2>/dev/null
fi

# Wire
if $INSTALL_WIRE; then
    msg_info "Installing Wire..."
    if $IS_FEDORA; then
        qvm-run -u root "$TEMPLATE_NAME" 'cat > /etc/yum.repos.d/wire.repo << EOF
[wire]
name=Wire Desktop
baseurl=https://wire-app.wire.com/linux/rpm/x86_64/
enabled=1
gpgcheck=0
EOF
dnf install -y wire-desktop' 2>/dev/null || msg_warn "Wire installation may require manual setup"
    else
        qvm-run -u root "$TEMPLATE_NAME" 'wget -qO- https://wire-app.wire.com/linux/releases.key | gpg --dearmor > /usr/share/keyrings/wire-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/wire-archive-keyring.gpg] https://wire-app.wire.com/linux/debian stable main" > /etc/apt/sources.list.d/wire.list
apt-get update && apt-get install -y wire-desktop' 2>/dev/null || msg_warn "Wire installation may require manual setup"
    fi
fi

# Briar
if $INSTALL_BRIAR; then
    msg_info "Briar: Desktop version is in beta"
    # Briar desktop is available as Flatpak
    if $IS_FEDORA; then
        qvm-run -u root "$TEMPLATE_NAME" 'dnf install -y flatpak && flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo && flatpak install -y flathub org.briarproject.Briar' 2>/dev/null || msg_warn "Briar requires Flatpak"
    else
        qvm-run -u root "$TEMPLATE_NAME" 'apt-get install -y flatpak && flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo && flatpak install -y flathub org.briarproject.Briar' 2>/dev/null || msg_warn "Briar requires Flatpak"
    fi
fi

# SimpleX
if $INSTALL_SIMPLEX; then
    msg_info "Installing SimpleX..."
    # SimpleX provides AppImage
    qvm-run -u root "$TEMPLATE_NAME" 'mkdir -p /opt/simplex
wget -q "https://github.com/simplex-chat/simplex-chat/releases/latest/download/simplex-desktop-x86_64.AppImage" -O /opt/simplex/simplex.AppImage
chmod +x /opt/simplex/simplex.AppImage
ln -sf /opt/simplex/simplex.AppImage /usr/local/bin/simplex' 2>/dev/null || msg_warn "SimpleX installation may require manual setup"
    
    qvm-run -u root "$TEMPLATE_NAME" 'cat > /usr/share/applications/simplex.desktop << EOF
[Desktop Entry]
Name=SimpleX
Comment=Private Messenger - No User IDs
Exec=/opt/simplex/simplex.AppImage --no-sandbox
Icon=simplex
Terminal=false
Type=Application
Categories=Network;InstantMessaging;
EOF' 2>/dev/null
fi

# Jami
if $INSTALL_JAMI; then
    msg_info "Installing Jami..."
    if $IS_FEDORA; then
        qvm-run -u root "$TEMPLATE_NAME" 'dnf install -y jami' 2>/dev/null || msg_warn "Jami may not be in repos"
    else
        qvm-run -u root "$TEMPLATE_NAME" 'apt-get install -y jami' 2>/dev/null || msg_warn "Jami may require manual setup"
    fi
fi

# Telegram
if $INSTALL_TELEGRAM; then
    msg_info "Installing Telegram..."
    if $IS_FEDORA; then
        qvm-run -u root "$TEMPLATE_NAME" 'dnf install -y telegram-desktop' 2>/dev/null || msg_warn "Telegram installation may require manual setup"
    else
        qvm-run -u root "$TEMPLATE_NAME" 'apt-get install -y telegram-desktop' 2>/dev/null || msg_warn "Telegram installation may require manual setup"
    fi
fi

# WhatsApp (web wrapper)
if $INSTALL_WHATSAPP; then
    msg_info "WhatsApp: Creating web launcher..."
    # WhatsApp doesn't have official Linux client, create web shortcut
    qvm-run -u root "$TEMPLATE_NAME" 'cat > /usr/share/applications/whatsapp.desktop << EOF
[Desktop Entry]
Name=WhatsApp
Comment=WhatsApp Web
Exec=firefox --new-window https://web.whatsapp.com
Icon=web-browser
Terminal=false
Type=Application
Categories=Network;InstantMessaging;
EOF' 2>/dev/null
fi

# Discord
if $INSTALL_DISCORD; then
    msg_info "Installing Discord..."
    if $IS_FEDORA; then
        qvm-run -u root "$TEMPLATE_NAME" 'dnf install -y discord' 2>/dev/null || {
            qvm-run -u root "$TEMPLATE_NAME" 'wget -q "https://discord.com/api/download?platform=linux&format=rpm" -O /tmp/discord.rpm && dnf install -y /tmp/discord.rpm' 2>/dev/null || msg_warn "Discord installation may require manual setup"
        }
    else
        qvm-run -u root "$TEMPLATE_NAME" 'wget -q "https://discord.com/api/download?platform=linux&format=deb" -O /tmp/discord.deb && apt-get install -y /tmp/discord.deb' 2>/dev/null || msg_warn "Discord installation may require manual setup"
    fi
fi

# Slack
if $INSTALL_SLACK; then
    msg_info "Installing Slack..."
    if $IS_FEDORA; then
        qvm-run -u root "$TEMPLATE_NAME" 'wget -q "https://downloads.slack-edge.com/releases/linux/4.35.126/prod/x64/slack-4.35.126-0.1.el8.x86_64.rpm" -O /tmp/slack.rpm && dnf install -y /tmp/slack.rpm' 2>/dev/null || msg_warn "Slack installation may require manual setup"
    else
        qvm-run -u root "$TEMPLATE_NAME" 'wget -q "https://downloads.slack-edge.com/releases/linux/4.35.126/prod/x64/slack-desktop-4.35.126-amd64.deb" -O /tmp/slack.deb && apt-get install -y /tmp/slack.deb' 2>/dev/null || msg_warn "Slack installation may require manual setup"
    fi
fi

# Skype
if $INSTALL_SKYPE; then
    msg_info "Installing Skype..."
    if $IS_FEDORA; then
        qvm-run -u root "$TEMPLATE_NAME" 'wget -q "https://repo.skype.com/latest/skypeforlinux-64.rpm" -O /tmp/skype.rpm && dnf install -y /tmp/skype.rpm' 2>/dev/null || msg_warn "Skype installation may require manual setup"
    else
        qvm-run -u root "$TEMPLATE_NAME" 'wget -q "https://repo.skype.com/latest/skypeforlinux-64.deb" -O /tmp/skype.deb && apt-get install -y /tmp/skype.deb' 2>/dev/null || msg_warn "Skype installation may require manual setup"
    fi
fi

# Configure Firefox DoH blocking
msg_step "6/6" "Finalizing configuration..."
qvm-run -u root "$TEMPLATE_NAME" "mkdir -p $FF_ETC $FF_LIB"
cat "$CONFIG_DIR/firefox.json" | qvm-run -u root --pass-io "$TEMPLATE_NAME" "cat > $FF_ETC/policies.json"
cat "$CONFIG_DIR/firefox.json" | qvm-run -u root --pass-io "$TEMPLATE_NAME" "cat > $FF_LIB/policies.json"
qvm-run -u root "$TEMPLATE_NAME" "chmod 644 $FF_ETC/policies.json $FF_LIB/policies.json"
qvm-run -u root "$TEMPLATE_NAME" "chattr +i $FF_ETC/policies.json $FF_LIB/policies.json"

# Shutdown template
msg_info "Shutting down template..."
wait_for_shutdown "$TEMPLATE_NAME"

msg_ok "Template created: $TEMPLATE_NAME"
echo ""

# ========================================
# CREATE APPVM
# ========================================

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}   Creating Messaging AppVM            ${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""

msg_step "1/2" "Creating AppVM..."
qvm-create --template "$TEMPLATE_NAME" --label purple "$VM_NAME"

msg_step "2/2" "Configuring VM properties..."
qvm-prefs "$VM_NAME" memory 1024
qvm-prefs "$VM_NAME" maxmem 4096
qvm-prefs "$VM_NAME" vcpus 2

# Update app menu
msg_info "Updating application menu..."
qvm-appmenus --update "$VM_NAME" 2>/dev/null || true

# Build whitelist for app menu
WHITELIST=""
$INSTALL_SIGNAL && WHITELIST="$WHITELIST signal-desktop.desktop"
$INSTALL_ELEMENT && WHITELIST="$WHITELIST element-desktop.desktop"
$INSTALL_SESSION && WHITELIST="$WHITELIST session.desktop"
$INSTALL_OLVID && WHITELIST="$WHITELIST olvid.desktop"
$INSTALL_THREEMA && WHITELIST="$WHITELIST threema.desktop"
$INSTALL_WIRE && WHITELIST="$WHITELIST wire-desktop.desktop"
$INSTALL_BRIAR && WHITELIST="$WHITELIST org.briarproject.Briar.desktop"
$INSTALL_SIMPLEX && WHITELIST="$WHITELIST simplex.desktop"
$INSTALL_JAMI && WHITELIST="$WHITELIST jami.desktop jami-gnome.desktop"
$INSTALL_TELEGRAM && WHITELIST="$WHITELIST telegramdesktop.desktop org.telegram.desktop.desktop"
$INSTALL_WHATSAPP && WHITELIST="$WHITELIST whatsapp.desktop"
$INSTALL_DISCORD && WHITELIST="$WHITELIST discord.desktop"
$INSTALL_SLACK && WHITELIST="$WHITELIST slack.desktop"
$INSTALL_SKYPE && WHITELIST="$WHITELIST skypeforlinux.desktop"
WHITELIST="$WHITELIST firefox.desktop"

if [[ -n "$WHITELIST" ]]; then
    echo "$WHITELIST" | tr ' ' '\n' | qvm-appmenus --set-whitelist - "$VM_NAME" 2>/dev/null || true
fi

msg_ok "AppVM created: $VM_NAME"
echo ""

# ========================================
# SUMMARY
# ========================================

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   Installation Complete!              ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

echo -e "${YELLOW}Created:${NC}"
echo "  ✓ Template: $TEMPLATE_NAME"
echo "  ✓ AppVM: $VM_NAME"
echo ""

echo -e "${YELLOW}Installed applications:${NC}"
$INSTALL_SIGNAL && echo "  ✓ Signal"
$INSTALL_ELEMENT && echo "  ✓ Element (Matrix)"
$INSTALL_SESSION && echo "  ✓ Session"
$INSTALL_OLVID && echo "  ✓ Olvid"
$INSTALL_THREEMA && echo "  ✓ Threema (web)"
$INSTALL_WIRE && echo "  ✓ Wire"
$INSTALL_BRIAR && echo "  ✓ Briar (Flatpak)"
$INSTALL_SIMPLEX && echo "  ✓ SimpleX"
$INSTALL_JAMI && echo "  ✓ Jami"
$INSTALL_TELEGRAM && echo "  ✓ Telegram"
$INSTALL_WHATSAPP && echo "  ✓ WhatsApp (web)"
$INSTALL_DISCORD && echo "  ✓ Discord"
$INSTALL_SLACK && echo "  ✓ Slack"
$INSTALL_SKYPE && echo "  ✓ Skype"
echo ""

echo -e "${YELLOW}Usage:${NC}"
echo "  Applications are available in the Qubes menu under '$VM_NAME'"
echo ""
echo "  Or launch directly:"
$INSTALL_SIGNAL && echo "  qvm-run $VM_NAME signal-desktop"
$INSTALL_ELEMENT && echo "  qvm-run $VM_NAME element-desktop"
$INSTALL_TELEGRAM && echo "  qvm-run $VM_NAME telegram-desktop"
$INSTALL_DISCORD && echo "  qvm-run $VM_NAME discord"
echo ""

echo -e "${YELLOW}Security notes:${NC}"
echo "  ✓ DNS filtering: Only messaging domains allowed"
echo "  ✓ All other websites are blocked"
echo "  ✓ DoH bypass prevention enabled"
echo ""

echo -e "${YELLOW}Privacy recommendations:${NC}"
echo "  - Signal, Session, SimpleX: Best for privacy"
echo "  - Olvid: ANSSI certified (French government)"
echo "  - Element: Self-hostable, decentralized"
echo "  - Avoid: WhatsApp, Skype, Discord for sensitive comms"
echo ""
