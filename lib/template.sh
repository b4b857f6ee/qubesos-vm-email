#!/bin/bash
#
# lib/template.sh
# Functions for creating filtered templates
#

# Source common if not already loaded
[[ -z "$NC" ]] && source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config"

# Create a filtered template
# Usage: create_filtered_template base_template profile_name
create_filtered_template() {
    local base_template="$1"
    local profile="$2"
    local new_template="${base_template}-${profile}"
    local base_config="$CONFIG_DIR/base.conf"
    local services_dir="$CONFIG_DIR/services"
    local firefox_config="$CONFIG_DIR/firefox.json"
    
    detect_distro "$base_template"
    
    echo -e "${YELLOW}========================================${NC}"
    echo -e "${YELLOW}   Creating ${profile^} Template        ${NC}"
    echo -e "${YELLOW}========================================${NC}"
    echo ""
    
    # Clone
    msg_step "1/5" "Cloning template..."
    qvm-clone "$base_template" "$new_template"
    
    # Start
    msg_step "2/5" "Starting template..."
    qvm-start "$new_template" 2>/dev/null || true
    sleep 5
    
    # Install dnsmasq
    msg_step "3/5" "Installing dnsmasq..."
    qvm-run -u root "$new_template" "$PKG_INSTALL dnsmasq" 2>/dev/null
    
    # Configure DNS filtering
    msg_step "4/5" "Configuring DNS filtering..."
    
    # Start with base config
    cat "$base_config" | qvm-run -u root --pass-io "$new_template" "cat > /etc/dnsmasq.d/${profile}-filter.conf"
    
    # Build list of services and bookmarks based on profile
    local bookmarks_entries=""
    
    if [[ "$profile" == "email" ]]; then
        if $EMAIL_GMAIL; then
            msg_info "Adding Gmail..."
            cat "$services_dir/gmail.conf" | qvm-run -u root --pass-io "$new_template" "cat >> /etc/dnsmasq.d/${profile}-filter.conf"
            bookmarks_entries+='        <DT><A HREF="https://mail.google.com">Gmail</A>\n'
        fi
        if $EMAIL_OUTLOOK; then
            msg_info "Adding Outlook..."
            cat "$services_dir/outlook.conf" | qvm-run -u root --pass-io "$new_template" "cat >> /etc/dnsmasq.d/${profile}-filter.conf"
            bookmarks_entries+='        <DT><A HREF="https://outlook.live.com">Outlook</A>\n'
        fi
        if $EMAIL_PROTON; then
            msg_info "Adding ProtonMail..."
            cat "$services_dir/protonmail.conf" | qvm-run -u root --pass-io "$new_template" "cat >> /etc/dnsmasq.d/${profile}-filter.conf"
            bookmarks_entries+='        <DT><A HREF="https://mail.proton.me">ProtonMail</A>\n'
        fi
    fi
    
    if [[ "$profile" == "drive" ]]; then
        if $DRIVE_GOOGLE; then
            msg_info "Adding Google Drive..."
            cat "$services_dir/gdrive.conf" | qvm-run -u root --pass-io "$new_template" "cat >> /etc/dnsmasq.d/${profile}-filter.conf"
            bookmarks_entries+='        <DT><A HREF="https://drive.google.com">Google Drive</A>\n'
        fi
        if $DRIVE_ONEDRIVE; then
            msg_info "Adding OneDrive..."
            cat "$services_dir/onedrive.conf" | qvm-run -u root --pass-io "$new_template" "cat >> /etc/dnsmasq.d/${profile}-filter.conf"
            bookmarks_entries+='        <DT><A HREF="https://onedrive.live.com">OneDrive</A>\n'
        fi
        if $DRIVE_DROPBOX; then
            msg_info "Adding Dropbox..."
            cat "$services_dir/dropbox.conf" | qvm-run -u root --pass-io "$new_template" "cat >> /etc/dnsmasq.d/${profile}-filter.conf"
            bookmarks_entries+='        <DT><A HREF="https://www.dropbox.com">Dropbox</A>\n'
        fi
        if $DRIVE_PROTON; then
            msg_info "Adding Proton Drive..."
            cat "$services_dir/protondrive.conf" | qvm-run -u root --pass-io "$new_template" "cat >> /etc/dnsmasq.d/${profile}-filter.conf"
            bookmarks_entries+='        <DT><A HREF="https://drive.proton.me">Proton Drive</A>\n'
        fi
        if $SYNOLOGY_ENABLED; then
            msg_info "Adding Synology..."
            cat "$services_dir/synology.conf" | qvm-run -u root --pass-io "$new_template" "cat >> /etc/dnsmasq.d/${profile}-filter.conf"
            
            # Add specific QuickConnect ID
            if [[ -n "$SYNOLOGY_QUICKCONNECT" ]]; then
                echo "server=/${SYNOLOGY_QUICKCONNECT}.quickconnect.to/9.9.9.9" | qvm-run -u root --pass-io "$new_template" "cat >> /etc/dnsmasq.d/${profile}-filter.conf"
                echo "server=/${SYNOLOGY_QUICKCONNECT}.quickconnect.cn/9.9.9.9" | qvm-run -u root --pass-io "$new_template" "cat >> /etc/dnsmasq.d/${profile}-filter.conf"
                bookmarks_entries+="        <DT><A HREF=\"https://${SYNOLOGY_QUICKCONNECT}.quickconnect.to\">Synology</A>\n"
            fi
            
            # Add direct IP/hostname
            if [[ -n "$SYNOLOGY_DIRECT_IP" ]]; then
                if [[ "$SYNOLOGY_DIRECT_IP" =~ [a-zA-Z] ]]; then
                    echo "server=/${SYNOLOGY_DIRECT_IP}/9.9.9.9" | qvm-run -u root --pass-io "$new_template" "cat >> /etc/dnsmasq.d/${profile}-filter.conf"
                fi
                if [[ -z "$SYNOLOGY_QUICKCONNECT" ]]; then
                    bookmarks_entries+="        <DT><A HREF=\"https://${SYNOLOGY_DIRECT_IP}:5001\">Synology</A>\n"
                fi
            fi
        fi
    fi
    
    qvm-run -u root "$new_template" "chmod 644 /etc/dnsmasq.d/${profile}-filter.conf"
    
    # System configuration
    qvm-run -u root "$new_template" 'systemctl stop systemd-resolved 2>/dev/null; systemctl disable systemd-resolved 2>/dev/null; systemctl mask systemd-resolved 2>/dev/null; true'
    qvm-run -u root "$new_template" 'sed -i "s/hosts:.*/hosts:      files dns myhostname/" /etc/nsswitch.conf'
    qvm-run -u root "$new_template" 'systemctl enable dnsmasq'
    qvm-run -u root "$new_template" 'rm -f /etc/resolv.conf; echo "nameserver 127.0.0.1" > /etc/resolv.conf'
    
    # Make immutable
    qvm-run -u root "$new_template" "chattr +i /etc/dnsmasq.d/${profile}-filter.conf /etc/resolv.conf"
    
    # Configure Firefox
    msg_step "5/5" "Configuring Firefox & Desktop shortcuts..."
    qvm-run -u root "$new_template" "mkdir -p $FF_ETC $FF_LIB"
    cat "$firefox_config" | qvm-run -u root --pass-io "$new_template" "cat > $FF_ETC/policies.json"
    cat "$firefox_config" | qvm-run -u root --pass-io "$new_template" "cat > $FF_LIB/policies.json"
    qvm-run -u root "$new_template" "chmod 644 $FF_ETC/policies.json $FF_LIB/policies.json"
    qvm-run -u root "$new_template" "chattr +i $FF_ETC/policies.json $FF_LIB/policies.json"
    
    # Create desktop shortcuts directory
    qvm-run -u root "$new_template" "mkdir -p /etc/skel/Desktop"
    
    # Create desktop shortcuts based on selected services
    if [[ "$profile" == "email" ]]; then
        if $EMAIL_GMAIL; then
            qvm-run -u root "$new_template" 'cat > /etc/skel/Desktop/gmail.desktop << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Gmail
Comment=Open Gmail in Firefox
Exec=firefox https://mail.google.com
Icon=mail-send
Terminal=false
Categories=Network;Email;
StartupNotify=true
EOF
chmod +x /etc/skel/Desktop/gmail.desktop'
        fi
        
        if $EMAIL_OUTLOOK; then
            qvm-run -u root "$new_template" 'cat > /etc/skel/Desktop/outlook.desktop << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Outlook
Comment=Open Outlook in Firefox
Exec=firefox https://outlook.live.com
Icon=mail-send
Terminal=false
Categories=Network;Email;
StartupNotify=true
EOF
chmod +x /etc/skel/Desktop/outlook.desktop'
        fi
        
        if $EMAIL_PROTON; then
            qvm-run -u root "$new_template" 'cat > /etc/skel/Desktop/protonmail.desktop << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=ProtonMail
Comment=Open ProtonMail in Firefox
Exec=firefox https://mail.proton.me
Icon=mail-send
Terminal=false
Categories=Network;Email;
StartupNotify=true
EOF
chmod +x /etc/skel/Desktop/protonmail.desktop'
        fi
    fi
    
    if [[ "$profile" == "drive" ]]; then
        if $DRIVE_GOOGLE; then
            qvm-run -u root "$new_template" 'cat > /etc/skel/Desktop/gdrive.desktop << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Google Drive
Comment=Open Google Drive in Firefox
Exec=firefox https://drive.google.com
Icon=folder-remote
Terminal=false
Categories=Network;FileTransfer;
StartupNotify=true
EOF
chmod +x /etc/skel/Desktop/gdrive.desktop'
        fi
        
        if $DRIVE_ONEDRIVE; then
            qvm-run -u root "$new_template" 'cat > /etc/skel/Desktop/onedrive.desktop << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=OneDrive
Comment=Open OneDrive in Firefox
Exec=firefox https://onedrive.live.com
Icon=folder-remote
Terminal=false
Categories=Network;FileTransfer;
StartupNotify=true
EOF
chmod +x /etc/skel/Desktop/onedrive.desktop'
        fi
        
        if $DRIVE_DROPBOX; then
            qvm-run -u root "$new_template" 'cat > /etc/skel/Desktop/dropbox.desktop << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Dropbox
Comment=Open Dropbox in Firefox
Exec=firefox https://www.dropbox.com
Icon=folder-remote
Terminal=false
Categories=Network;FileTransfer;
StartupNotify=true
EOF
chmod +x /etc/skel/Desktop/dropbox.desktop'
        fi
        
        if $DRIVE_PROTON; then
            qvm-run -u root "$new_template" 'cat > /etc/skel/Desktop/protondrive.desktop << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Proton Drive
Comment=Open Proton Drive in Firefox
Exec=firefox https://drive.proton.me
Icon=folder-remote
Terminal=false
Categories=Network;FileTransfer;
StartupNotify=true
EOF
chmod +x /etc/skel/Desktop/protondrive.desktop'
        fi
        
        if $SYNOLOGY_ENABLED; then
            local syno_url=""
            if [[ -n "$SYNOLOGY_QUICKCONNECT" ]]; then
                syno_url="https://${SYNOLOGY_QUICKCONNECT}.quickconnect.to"
            elif [[ -n "$SYNOLOGY_DIRECT_IP" ]]; then
                syno_url="https://${SYNOLOGY_DIRECT_IP}:5001"
            fi
            
            if [[ -n "$syno_url" ]]; then
                qvm-run -u root "$new_template" "cat > /etc/skel/Desktop/synology.desktop << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Synology
Comment=Open Synology DSM in Firefox
Exec=firefox ${syno_url}
Icon=folder-remote
Terminal=false
Categories=Network;FileTransfer;
StartupNotify=true
EOF
chmod +x /etc/skel/Desktop/synology.desktop"
            fi
        fi
    fi
    
    # Copy desktop shortcuts to existing user if exists (handles FR/EN/other locales)
    qvm-run -u root "$new_template" 'if [ -d /home/user ]; then
        # Detect user desktop directory
        user_desktop=""
        if [ -f /home/user/.config/user-dirs.dirs ]; then
            user_desktop=$(grep "^XDG_DESKTOP_DIR" /home/user/.config/user-dirs.dirs 2>/dev/null | cut -d"\"" -f2 | sed "s|\$HOME|/home/user|g")
        fi
        # Fallback: try common directory names
        if [ -z "$user_desktop" ] || [ ! -d "$user_desktop" ]; then
            for dir in Desktop Bureau Escritorio Schreibtisch; do
                if [ -d "/home/user/$dir" ]; then
                    user_desktop="/home/user/$dir"
                    break
                fi
            done
        fi
        # Final fallback
        if [ -z "$user_desktop" ]; then
            user_desktop="/home/user/Desktop"
        fi
        mkdir -p "$user_desktop"
        cp /etc/skel/Desktop/*.desktop "$user_desktop/" 2>/dev/null
        chown -R user:user "$user_desktop"
    fi'
    
    # Configure Firefox bookmarks dynamically
    if [[ -n "$bookmarks_entries" ]]; then
        msg_info "Setting up Firefox bookmarks..."
        
        # Build bookmarks HTML
        local bookmarks_html='<!DOCTYPE NETSCAPE-Bookmark-file-1>
<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">
<TITLE>Bookmarks</TITLE>
<H1>Bookmarks Menu</H1>
<DL><p>
    <DT><H3 PERSONAL_TOOLBAR_FOLDER="true">Bookmarks Toolbar</H3>
    <DL><p>
'"$(echo -e "$bookmarks_entries")"'    </DL><p>
</DL><p>'
        
        # Copy bookmarks file to a system location
        echo "$bookmarks_html" | qvm-run -u root --pass-io "$new_template" "cat > /usr/share/firefox-bookmarks.html"
        qvm-run -u root "$new_template" "chmod 644 /usr/share/firefox-bookmarks.html"
        
        # Create autoconfig files for Firefox
        qvm-run -u root "$new_template" "mkdir -p $FF_LIB/../defaults/pref"
        qvm-run -u root "$new_template" "echo 'pref(\"general.config.filename\", \"firefox.cfg\");' > $FF_LIB/../defaults/pref/autoconfig.js"
        qvm-run -u root "$new_template" "echo 'pref(\"general.config.obscure_value\", 0);' >> $FF_LIB/../defaults/pref/autoconfig.js"
        
        # firefox.cfg contains the actual preferences
        qvm-run -u root "$new_template" 'cat > '"$FF_LIB"'/../firefox.cfg << "FIREFOXCFG"
// Firefox autoconfig
// Show bookmarks toolbar always
defaultPref("browser.toolbars.bookmarks.visibility", "always");

// Import bookmarks on first run
defaultPref("browser.places.importBookmarksHTML", true);
defaultPref("browser.bookmarks.file", "/usr/share/firefox-bookmarks.html");

// Homepage
defaultPref("browser.startup.homepage", "about:blank");
defaultPref("browser.startup.page", 1);

// New tab page
defaultPref("browser.newtabpage.enabled", true);
FIREFOXCFG'
    fi
    
    # Shutdown and wait
    msg_info "Shutting down template..."
    wait_for_shutdown "$new_template"
    
    msg_ok "${profile^} template created: $new_template"
    echo ""
    
    # Return template name via global variable instead of echo
    CREATED_TEMPLATE="$new_template"
}

# Create DispVM template
# Usage: create_dispvm_template template_name label dvm_name
create_dispvm_template() {
    local template="$1"
    local label="$2"
    local dvm_name="$3"
    
    echo -e "${CYAN}Creating DispVM template $dvm_name...${NC}"
    qvm-create --template "$template" --label "$label" --class AppVM "$dvm_name"
    qvm-prefs "$dvm_name" template_for_dispvms True
    qvm-features "$dvm_name" appmenus-dispvm 1
    
    # Sync appmenus so it appears in Qubes menu
    qvm-appmenus --update "$dvm_name" 2>/dev/null || true
    qvm-appmenus --set-whitelist - "$dvm_name" <<< "firefox.desktop" 2>/dev/null || true
    
    msg_ok "$dvm_name created (available in Qubes menu)"
}

# Create dom0 desktop shortcuts for DispVM services
# Usage: create_dom0_shortcuts dvm_name profile
create_dom0_shortcuts() {
    local dvm_name="$1"
    local profile="$2"
    local desktop_dir
    desktop_dir="$(get_desktop_dir)"
    local applications_dir="$HOME/.local/share/applications"
    
    mkdir -p "$desktop_dir" "$applications_dir"
    
    msg_info "Creating dom0 shortcuts for $dvm_name..."
    
    if [[ "$profile" == "email" ]]; then
        if $EMAIL_GMAIL; then
            cat > "$desktop_dir/${dvm_name}-gmail.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Gmail (${dvm_name})
Comment=Open Gmail in disposable VM
Exec=qvm-run --dispvm=${dvm_name} firefox https://mail.google.com
Icon=mail-send
Terminal=false
Categories=Network;Email;
StartupNotify=true
EOF
            chmod +x "$desktop_dir/${dvm_name}-gmail.desktop"
            cp "$desktop_dir/${dvm_name}-gmail.desktop" "$applications_dir/"
        fi
        
        if $EMAIL_OUTLOOK; then
            cat > "$desktop_dir/${dvm_name}-outlook.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Outlook (${dvm_name})
Comment=Open Outlook in disposable VM
Exec=qvm-run --dispvm=${dvm_name} firefox https://outlook.live.com
Icon=mail-send
Terminal=false
Categories=Network;Email;
StartupNotify=true
EOF
            chmod +x "$desktop_dir/${dvm_name}-outlook.desktop"
            cp "$desktop_dir/${dvm_name}-outlook.desktop" "$applications_dir/"
        fi
        
        if $EMAIL_PROTON; then
            cat > "$desktop_dir/${dvm_name}-protonmail.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=ProtonMail (${dvm_name})
Comment=Open ProtonMail in disposable VM
Exec=qvm-run --dispvm=${dvm_name} firefox https://mail.proton.me
Icon=mail-send
Terminal=false
Categories=Network;Email;
StartupNotify=true
EOF
            chmod +x "$desktop_dir/${dvm_name}-protonmail.desktop"
            cp "$desktop_dir/${dvm_name}-protonmail.desktop" "$applications_dir/"
        fi
    fi
    
    if [[ "$profile" == "drive" ]]; then
        if $DRIVE_GOOGLE; then
            cat > "$desktop_dir/${dvm_name}-gdrive.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Google Drive (${dvm_name})
Comment=Open Google Drive in disposable VM
Exec=qvm-run --dispvm=${dvm_name} firefox https://drive.google.com
Icon=folder-remote
Terminal=false
Categories=Network;FileTransfer;
StartupNotify=true
EOF
            chmod +x "$desktop_dir/${dvm_name}-gdrive.desktop"
            cp "$desktop_dir/${dvm_name}-gdrive.desktop" "$applications_dir/"
        fi
        
        if $DRIVE_ONEDRIVE; then
            cat > "$desktop_dir/${dvm_name}-onedrive.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=OneDrive (${dvm_name})
Comment=Open OneDrive in disposable VM
Exec=qvm-run --dispvm=${dvm_name} firefox https://onedrive.live.com
Icon=folder-remote
Terminal=false
Categories=Network;FileTransfer;
StartupNotify=true
EOF
            chmod +x "$desktop_dir/${dvm_name}-onedrive.desktop"
            cp "$desktop_dir/${dvm_name}-onedrive.desktop" "$applications_dir/"
        fi
        
        if $DRIVE_DROPBOX; then
            cat > "$desktop_dir/${dvm_name}-dropbox.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Dropbox (${dvm_name})
Comment=Open Dropbox in disposable VM
Exec=qvm-run --dispvm=${dvm_name} firefox https://www.dropbox.com
Icon=folder-remote
Terminal=false
Categories=Network;FileTransfer;
StartupNotify=true
EOF
            chmod +x "$desktop_dir/${dvm_name}-dropbox.desktop"
            cp "$desktop_dir/${dvm_name}-dropbox.desktop" "$applications_dir/"
        fi
        
        if $DRIVE_PROTON; then
            cat > "$desktop_dir/${dvm_name}-protondrive.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Proton Drive (${dvm_name})
Comment=Open Proton Drive in disposable VM
Exec=qvm-run --dispvm=${dvm_name} firefox https://drive.proton.me
Icon=folder-remote
Terminal=false
Categories=Network;FileTransfer;
StartupNotify=true
EOF
            chmod +x "$desktop_dir/${dvm_name}-protondrive.desktop"
            cp "$desktop_dir/${dvm_name}-protondrive.desktop" "$applications_dir/"
        fi
        
        if $SYNOLOGY_ENABLED; then
            local syno_url=""
            if [[ -n "$SYNOLOGY_QUICKCONNECT" ]]; then
                syno_url="https://${SYNOLOGY_QUICKCONNECT}.quickconnect.to"
            elif [[ -n "$SYNOLOGY_DIRECT_IP" ]]; then
                syno_url="https://${SYNOLOGY_DIRECT_IP}:5001"
            fi
            
            if [[ -n "$syno_url" ]]; then
                cat > "$desktop_dir/${dvm_name}-synology.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=Synology (${dvm_name})
Comment=Open Synology in disposable VM
Exec=qvm-run --dispvm=${dvm_name} firefox ${syno_url}
Icon=folder-remote
Terminal=false
Categories=Network;FileTransfer;
StartupNotify=true
EOF
                chmod +x "$desktop_dir/${dvm_name}-synology.desktop"
                cp "$desktop_dir/${dvm_name}-synology.desktop" "$applications_dir/"
            fi
        fi
    fi
    
    msg_ok "Dom0 shortcuts created in $desktop_dir"
}

# Create AppVM
# Usage: create_appvm template_name label vm_name
create_appvm() {
    local template="$1"
    local label="$2"
    local vm_name="$3"
    
    echo -e "${CYAN}Creating AppVM $vm_name...${NC}"
    qvm-create --template "$template" --label "$label" "$vm_name"
    msg_ok "$vm_name created"
}
