#!/bin/bash
#
# lib/template.sh
# Functions for creating filtered templates
#

# Source common if not already loaded
[[ -z "$NC" ]] && source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="$SCRIPT_DIR/config"

# Profile configuration: services files and bookmarks
# Format: "service_file:bookmark_url:bookmark_name"
declare -A PROFILE_SERVICES=(
    ["email"]=""  # Handled separately due to selection
    ["drive"]=""  # Handled separately due to selection
    ["social"]="social.conf"
    ["work"]="work.conf"
    ["banking"]="banking-fr.conf payment.conf"
    ["crypto"]="crypto.conf"
    ["gov"]="gov-fr.conf"
    ["health"]="health-fr.conf"
    ["shopping"]="shopping-fr.conf payment.conf"
    ["travel"]="travel-fr.conf"
    ["media"]="media.conf"
    ["news"]="news-fr.conf"
    ["admin"]="admin.conf"
    ["ai"]="ai.conf"
)

declare -A PROFILE_BOOKMARKS=(
    ["social"]="https://facebook.com:Facebook|https://twitter.com:Twitter|https://instagram.com:Instagram|https://linkedin.com:LinkedIn|https://discord.com:Discord|https://reddit.com:Reddit"
    ["work"]="https://slack.com:Slack|https://teams.microsoft.com:Teams|https://notion.so:Notion|https://zoom.us:Zoom|https://figma.com:Figma|https://trello.com:Trello"
    ["banking"]="https://boursorama.com:Boursorama|https://mabanque.bnpparibas:BNP|https://particuliers.sg.fr:SG|https://paypal.com:PayPal|https://fortuneo.fr:Fortuneo|https://n26.com:N26"
    ["crypto"]="https://binance.com:Binance|https://kraken.com:Kraken|https://coinbase.com:Coinbase|https://ledger.com:Ledger"
    ["gov"]="https://impots.gouv.fr:Impôts|https://caf.fr:CAF|https://ameli.fr:Ameli|https://service-public.fr:Service Public|https://ants.gouv.fr:ANTS"
    ["health"]="https://doctolib.fr:Doctolib|https://ameli.fr:Ameli|https://monespacesante.fr:Mon Espace Santé|https://qare.fr:Qare"
    ["shopping"]="https://amazon.fr:Amazon|https://fnac.com:Fnac|https://cdiscount.com:Cdiscount|https://leboncoin.fr:Leboncoin|https://ldlc.com:LDLC|https://vinted.fr:Vinted"
    ["travel"]="https://sncf-connect.com:SNCF|https://booking.com:Booking|https://airbnb.fr:Airbnb|https://airfrance.fr:Air France|https://blablacar.fr:BlaBlaCar"
    ["media"]="https://youtube.com:YouTube|https://netflix.com:Netflix|https://spotify.com:Spotify|https://twitch.tv:Twitch|https://france.tv:France TV|https://mycanal.fr:Canal+"
    ["news"]="https://lemonde.fr:Le Monde|https://lefigaro.fr:Le Figaro|https://bfmtv.com:BFM|https://franceinfo.fr:France Info|https://numerama.com:Numerama"
    ["admin"]="https://github.com:GitHub|https://gitlab.com:GitLab|https://ovhcloud.com:OVH|https://cloudflare.com:Cloudflare|https://console.aws.amazon.com:AWS"
    ["ai"]="https://chat.openai.com:ChatGPT|https://claude.ai:Claude|https://chat.mistral.ai:Mistral|https://gemini.google.com:Gemini|https://perplexity.ai:Perplexity"
)

# Convert service config to explicit block rules
# Input: service config file (server=/domain/9.9.9.9)
# Output: block rules (address=/domain/0.0.0.0)
generate_block_rules() {
    local config_file="$1"
    if [[ -f "$config_file" ]]; then
        # Extract domains from server= lines and convert to address= blocks
        grep "^server=/" "$config_file" | sed 's|^server=/\([^/]*\)/.*|address=/\1/0.0.0.0|'
    fi
}

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
    
    # Handle special profiles (email, drive) with user selection
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
    elif [[ "$profile" == "drive" ]]; then
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
            
            if [[ -n "$SYNOLOGY_QUICKCONNECT" ]]; then
                echo "server=/${SYNOLOGY_QUICKCONNECT}.quickconnect.to/9.9.9.9" | qvm-run -u root --pass-io "$new_template" "cat >> /etc/dnsmasq.d/${profile}-filter.conf"
                echo "server=/${SYNOLOGY_QUICKCONNECT}.quickconnect.cn/9.9.9.9" | qvm-run -u root --pass-io "$new_template" "cat >> /etc/dnsmasq.d/${profile}-filter.conf"
                bookmarks_entries+="        <DT><A HREF=\"https://${SYNOLOGY_QUICKCONNECT}.quickconnect.to\">Synology</A>\n"
            fi
            
            if [[ -n "$SYNOLOGY_DIRECT_IP" ]]; then
                if [[ "$SYNOLOGY_DIRECT_IP" =~ [a-zA-Z] ]]; then
                    echo "server=/${SYNOLOGY_DIRECT_IP}/9.9.9.9" | qvm-run -u root --pass-io "$new_template" "cat >> /etc/dnsmasq.d/${profile}-filter.conf"
                fi
                if [[ -z "$SYNOLOGY_QUICKCONNECT" ]]; then
                    bookmarks_entries+="        <DT><A HREF=\"https://${SYNOLOGY_DIRECT_IP}:5001\">Synology</A>\n"
                fi
            fi
        fi
    else
        # Handle other profiles with predefined services
        local services="${PROFILE_SERVICES[$profile]}"
        for service_file in $services; do
            if [[ -f "$services_dir/$service_file" ]]; then
                msg_info "Adding $service_file..."
                cat "$services_dir/$service_file" | qvm-run -u root --pass-io "$new_template" "cat >> /etc/dnsmasq.d/${profile}-filter.conf"
            fi
        done
        
        # Build bookmarks from PROFILE_BOOKMARKS
        local bookmarks="${PROFILE_BOOKMARKS[$profile]}"
        if [[ -n "$bookmarks" ]]; then
            IFS='|' read -ra bookmark_array <<< "$bookmarks"
            for bookmark in "${bookmark_array[@]}"; do
                local url="${bookmark%%:*}"
                local name="${bookmark#*:}"
                bookmarks_entries+="        <DT><A HREF=\"$url\">$name</A>\n"
            done
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
    
    # Create a generic desktop shortcut for the profile
    qvm-run -u root "$new_template" "cat > /etc/skel/Desktop/${profile}.desktop << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=${profile^} Browser
Comment=Open ${profile^} services in Firefox
Exec=firefox
Icon=firefox
Terminal=false
Categories=Network;WebBrowser;
StartupNotify=true
EOF
chmod +x /etc/skel/Desktop/${profile}.desktop"
    
    # Copy desktop shortcuts to existing user (handles FR/EN/other locales)
    qvm-run -u root "$new_template" 'if [ -d /home/user ]; then
        user_desktop=""
        if [ -f /home/user/.config/user-dirs.dirs ]; then
            user_desktop=$(grep "^XDG_DESKTOP_DIR" /home/user/.config/user-dirs.dirs 2>/dev/null | cut -d"\"" -f2 | sed "s|\$HOME|/home/user|g")
        fi
        if [ -z "$user_desktop" ] || [ ! -d "$user_desktop" ]; then
            for dir in Desktop Bureau Escritorio Schreibtisch; do
                if [ -d "/home/user/$dir" ]; then
                    user_desktop="/home/user/$dir"
                    break
                fi
            done
        fi
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
        
        local bookmarks_html='<!DOCTYPE NETSCAPE-Bookmark-file-1>
<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">
<TITLE>Bookmarks</TITLE>
<H1>Bookmarks Menu</H1>
<DL><p>
    <DT><H3 PERSONAL_TOOLBAR_FOLDER="true">Bookmarks Toolbar</H3>
    <DL><p>
'"$(echo -e "$bookmarks_entries")"'    </DL><p>
</DL><p>'
        
        echo "$bookmarks_html" | qvm-run -u root --pass-io "$new_template" "cat > /usr/share/firefox-bookmarks.html"
        qvm-run -u root "$new_template" "chmod 644 /usr/share/firefox-bookmarks.html"
        
        # Create autoconfig files for Firefox
        qvm-run -u root "$new_template" "mkdir -p $FF_LIB/../defaults/pref"
        qvm-run -u root "$new_template" "echo 'pref(\"general.config.filename\", \"firefox.cfg\");' > $FF_LIB/../defaults/pref/autoconfig.js"
        qvm-run -u root "$new_template" "echo 'pref(\"general.config.obscure_value\", 0);' >> $FF_LIB/../defaults/pref/autoconfig.js"
        
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
    
    # Get bookmarks for this profile
    local bookmarks=""
    
    # Handle email and drive separately
    if [[ "$profile" == "email" ]]; then
        $EMAIL_GMAIL && bookmarks+="https://mail.google.com:Gmail|"
        $EMAIL_OUTLOOK && bookmarks+="https://outlook.live.com:Outlook|"
        $EMAIL_PROTON && bookmarks+="https://mail.proton.me:ProtonMail|"
    elif [[ "$profile" == "drive" ]]; then
        $DRIVE_GOOGLE && bookmarks+="https://drive.google.com:Google Drive|"
        $DRIVE_ONEDRIVE && bookmarks+="https://onedrive.live.com:OneDrive|"
        $DRIVE_DROPBOX && bookmarks+="https://www.dropbox.com:Dropbox|"
        $DRIVE_PROTON && bookmarks+="https://drive.proton.me:Proton Drive|"
        if $SYNOLOGY_ENABLED; then
            if [[ -n "$SYNOLOGY_QUICKCONNECT" ]]; then
                bookmarks+="https://${SYNOLOGY_QUICKCONNECT}.quickconnect.to:Synology|"
            elif [[ -n "$SYNOLOGY_DIRECT_IP" ]]; then
                bookmarks+="https://${SYNOLOGY_DIRECT_IP}:5001:Synology|"
            fi
        fi
    else
        bookmarks="${PROFILE_BOOKMARKS[$profile]}"
    fi
    
    # Create shortcuts from bookmarks
    if [[ -n "$bookmarks" ]]; then
        IFS='|' read -ra bookmark_array <<< "$bookmarks"
        for bookmark in "${bookmark_array[@]}"; do
            [[ -z "$bookmark" ]] && continue
            local url="${bookmark%%:*}"
            local name="${bookmark#*:}"
            local safe_name=$(echo "$name" | tr ' ' '-' | tr '[:upper:]' '[:lower:]')
            
            cat > "$desktop_dir/${dvm_name}-${safe_name}.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Application
Name=$name (${dvm_name})
Comment=Open $name in disposable VM
Exec=qvm-run --dispvm=${dvm_name} firefox ${url}
Icon=firefox
Terminal=false
Categories=Network;WebBrowser;
StartupNotify=true
EOF
            chmod +x "$desktop_dir/${dvm_name}-${safe_name}.desktop"
            cp "$desktop_dir/${dvm_name}-${safe_name}.desktop" "$applications_dir/"
        done
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

# Apply blocking rules to an existing VM (not whitelist, just blocks)
# This keeps full internet access but blocks specific domains
# Usage: apply_blocks_to_existing_vm vm_name block_configs_list
apply_blocks_to_existing_vm() {
    local vm_name="$1"
    local block_configs="$2"
    local services_dir="$CONFIG_DIR/services"
    
    echo -e "${CYAN}Applying blocks to $vm_name...${NC}"
    
    # Get the template of this VM
    local vm_template=$(qvm-prefs "$vm_name" template 2>/dev/null)
    if [[ -z "$vm_template" ]]; then
        msg_error "Cannot get template for $vm_name"
        return 1
    fi
    
    # Detect distro from template
    detect_distro "$vm_template"
    
    # Start the template to install dnsmasq
    msg_info "Starting template $vm_template..."
    qvm-start "$vm_template" 2>/dev/null || true
    sleep 3
    
    # Check if dnsmasq is already installed
    local dnsmasq_installed=$(qvm-run -u root --pass-io "$vm_template" "command -v dnsmasq" 2>/dev/null)
    
    if [[ -z "$dnsmasq_installed" ]]; then
        msg_info "Installing dnsmasq in template..."
        qvm-run -u root "$vm_template" "$PKG_INSTALL dnsmasq" 2>/dev/null
    fi
    
    # Create block-only config (no base config with address=/#/0.0.0.0)
    # This allows all domains EXCEPT the blocked ones
    msg_info "Creating block rules..."
    
    # Header
    local block_header="# Qubes DNS Filter - Block rules for $vm_name
# This config blocks specific domains while allowing everything else
# Generated by qubes-dns-filter

# Upstream DNS (Quad9)
server=9.9.9.9
server=149.112.112.112

# Block DoH providers
address=/mozilla.cloudflare-dns.com/0.0.0.0
address=/dns.google/0.0.0.0
address=/cloudflare-dns.com/0.0.0.0
address=/dns.quad9.net/0.0.0.0
address=/doh.opendns.com/0.0.0.0

# ====== BLOCKED DOMAINS ======
# Domains from specialized VMs are blocked here
"
    
    echo "$block_header" | qvm-run -u root --pass-io "$vm_template" "cat > /etc/dnsmasq.d/qubes-blocks.conf"
    
    # Add block rules from each config file
    for block_conf in $block_configs; do
        if [[ -f "$services_dir/$block_conf" ]]; then
            msg_info "  Blocking domains from $block_conf..."
            echo "" | qvm-run -u root --pass-io "$vm_template" "cat >> /etc/dnsmasq.d/qubes-blocks.conf"
            echo "# Blocked: $block_conf" | qvm-run -u root --pass-io "$vm_template" "cat >> /etc/dnsmasq.d/qubes-blocks.conf"
            generate_block_rules "$services_dir/$block_conf" | qvm-run -u root --pass-io "$vm_template" "cat >> /etc/dnsmasq.d/qubes-blocks.conf"
        fi
    done
    
    # Configure system to use local DNS
    qvm-run -u root "$vm_template" 'systemctl stop systemd-resolved 2>/dev/null; systemctl disable systemd-resolved 2>/dev/null; systemctl mask systemd-resolved 2>/dev/null; true'
    qvm-run -u root "$vm_template" 'sed -i "s/hosts:.*/hosts:      files dns myhostname/" /etc/nsswitch.conf'
    qvm-run -u root "$vm_template" 'systemctl enable dnsmasq'
    qvm-run -u root "$vm_template" 'rm -f /etc/resolv.conf; echo "nameserver 127.0.0.1" > /etc/resolv.conf'
    
    # Make config immutable
    qvm-run -u root "$vm_template" "chmod 644 /etc/dnsmasq.d/qubes-blocks.conf"
    qvm-run -u root "$vm_template" "chattr +i /etc/dnsmasq.d/qubes-blocks.conf /etc/resolv.conf"
    
    # Shutdown template
    msg_info "Shutting down template..."
    qvm-shutdown --wait "$vm_template" 2>/dev/null || true
    
    msg_ok "Blocks applied to $vm_name (via template $vm_template)"
}

# Remove blocking rules from a VM's template
# Usage: remove_blocks_from_vm vm_name
remove_blocks_from_vm() {
    local vm_name="$1"
    
    local vm_template=$(qvm-prefs "$vm_name" template 2>/dev/null)
    if [[ -z "$vm_template" ]]; then
        msg_error "Cannot get template for $vm_name"
        return 1
    fi
    
    msg_info "Removing blocks from $vm_name (template: $vm_template)..."
    
    qvm-start "$vm_template" 2>/dev/null || true
    sleep 2
    
    # Remove immutable flag and delete config
    qvm-run -u root "$vm_template" "chattr -i /etc/dnsmasq.d/qubes-blocks.conf 2>/dev/null; rm -f /etc/dnsmasq.d/qubes-blocks.conf" 2>/dev/null
    qvm-run -u root "$vm_template" "chattr -i /etc/resolv.conf 2>/dev/null" 2>/dev/null
    
    # Restore systemd-resolved if it exists
    qvm-run -u root "$vm_template" "systemctl unmask systemd-resolved 2>/dev/null; systemctl enable systemd-resolved 2>/dev/null; true"
    
    qvm-shutdown --wait "$vm_template" 2>/dev/null || true
    
    msg_ok "Blocks removed from $vm_name"
}
