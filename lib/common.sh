#!/bin/bash
#
# lib/common.sh
# Common functions and variables
#

# Colors
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export CYAN='\033[0;36m'
export NC='\033[0m'

# Print functions
msg_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
msg_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
msg_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
msg_error() { echo -e "${RED}[ERROR]${NC} $1"; }
msg_step() { echo -e "${GREEN}[$1]${NC} $2"; }

# Check if running in dom0
check_dom0() {
    if [[ "$(hostname)" != "dom0" ]]; then
        msg_error "This script must be run from dom0"
        exit 1
    fi
}

# Select template with numbered menu
# Usage: select_template "prompt" excluded_pattern
# Returns: selected template name in $SELECTED_TEMPLATE
select_template() {
    local prompt="${1:-Select template}"
    local exclude_pattern="${2:-}"
    
    echo -e "${BLUE}Available templates:${NC}"
    echo ""
    
    if [[ -n "$exclude_pattern" ]]; then
        mapfile -t TEMPLATES < <(qvm-ls --raw-list --class TemplateVM 2>/dev/null | grep -v -E "$exclude_pattern" | sort)
    else
        mapfile -t TEMPLATES < <(qvm-ls --raw-list --class TemplateVM 2>/dev/null | sort)
    fi
    
    if [ ${#TEMPLATES[@]} -eq 0 ]; then
        msg_error "No templates found!"
        exit 1
    fi
    
    for i in "${!TEMPLATES[@]}"; do
        echo "  $((i+1))) ${TEMPLATES[$i]}"
    done
    echo ""
    read -p "$prompt [1-${#TEMPLATES[@]}]: " NUM
    
    if ! [[ "$NUM" =~ ^[0-9]+$ ]] || [ "$NUM" -lt 1 ] || [ "$NUM" -gt "${#TEMPLATES[@]}" ]; then
        msg_error "Invalid selection"
        exit 1
    fi
    
    SELECTED_TEMPLATE="${TEMPLATES[$((NUM-1))]}"
    echo -e "${GREEN}Selected: $SELECTED_TEMPLATE${NC}"
}

# Detect package manager and Firefox paths based on template name
# Usage: detect_distro template_name
# Sets: PKG_INSTALL, FF_ETC, FF_LIB
detect_distro() {
    local template="$1"
    
    if [[ "$template" == *"debian"* ]]; then
        PKG_INSTALL="apt update && apt install -y"
        FF_ETC="/etc/firefox-esr/policies"
        FF_LIB="/usr/lib/firefox-esr/distribution"
    else
        PKG_INSTALL="dnf install -y"
        FF_ETC="/etc/firefox/policies"
        FF_LIB="/usr/lib64/firefox/distribution"
    fi
    
    export PKG_INSTALL FF_ETC FF_LIB
}

# Check if VM exists
vm_exists() {
    qvm-check --quiet "$1" 2>/dev/null
}

# Kill and remove VM
remove_vm() {
    local vm="$1"
    if vm_exists "$vm"; then
        echo "  Removing $vm..."
        qvm-kill "$vm" 2>/dev/null || true
        qvm-remove -f "$vm" 2>/dev/null || true
    fi
}

# Wait for VM to be ready
wait_for_vm() {
    local vm="$1"
    local timeout="${2:-30}"
    
    for ((i=0; i<timeout; i++)); do
        if qvm-run "$vm" "echo ready" 2>/dev/null | grep -q "ready"; then
            return 0
        fi
        sleep 1
    done
    return 1
}

# Get user desktop directory (handles FR/EN/etc locales)
# Usage: get_desktop_dir
# Returns: desktop directory path
get_desktop_dir() {
    local desktop_dir=""
    
    # Method 1: Try xdg-user-dir (most reliable)
    if command -v xdg-user-dir &>/dev/null; then
        desktop_dir="$(xdg-user-dir DESKTOP 2>/dev/null)"
    fi
    
    # Method 2: Parse user-dirs.dirs file
    if [[ -z "$desktop_dir" || ! -d "$desktop_dir" ]]; then
        local user_dirs_file="$HOME/.config/user-dirs.dirs"
        if [[ -f "$user_dirs_file" ]]; then
            # Extract XDG_DESKTOP_DIR value and expand $HOME
            desktop_dir=$(grep "^XDG_DESKTOP_DIR" "$user_dirs_file" | cut -d'"' -f2 | sed "s|\$HOME|$HOME|g")
        fi
    fi
    
    # Method 3: Try common directory names
    if [[ -z "$desktop_dir" || ! -d "$desktop_dir" ]]; then
        for dir in "Desktop" "Bureau" "Escritorio" "Schreibtisch" "Área de trabalho" "Skrivbord"; do
            if [[ -d "$HOME/$dir" ]]; then
                desktop_dir="$HOME/$dir"
                break
            fi
        done
    fi
    
    # Method 4: Fallback to Desktop (create if needed)
    if [[ -z "$desktop_dir" ]]; then
        desktop_dir="$HOME/Desktop"
    fi
    
    echo "$desktop_dir"
}

# Get desktop directory for a VM template (inside VM)
# Usage: get_vm_desktop_dir_command
# Returns: bash command string to get desktop dir inside VM
get_vm_desktop_dir_command() {
    cat << 'VMDESKTOP'
desktop_dir=""
if command -v xdg-user-dir &>/dev/null; then
    desktop_dir="$(xdg-user-dir DESKTOP 2>/dev/null)"
fi
if [[ -z "$desktop_dir" || ! -d "$desktop_dir" ]]; then
    user_dirs_file="$HOME/.config/user-dirs.dirs"
    if [[ -f "$user_dirs_file" ]]; then
        desktop_dir=$(grep "^XDG_DESKTOP_DIR" "$user_dirs_file" | cut -d'"' -f2 | sed "s|\$HOME|$HOME|g")
    fi
fi
if [[ -z "$desktop_dir" || ! -d "$desktop_dir" ]]; then
    for dir in "Desktop" "Bureau" "Escritorio" "Schreibtisch"; do
        if [[ -d "$HOME/$dir" ]]; then
            desktop_dir="$HOME/$dir"
            break
        fi
    done
fi
if [[ -z "$desktop_dir" ]]; then
    desktop_dir="$HOME/Desktop"
fi
mkdir -p "$desktop_dir"
echo "$desktop_dir"
VMDESKTOP
}

# Wait for VM to be fully shutdown
wait_for_shutdown() {
    local vm="$1"
    local timeout="${2:-120}"
    
    msg_info "Shutting down $vm..."
    qvm-shutdown --wait "$vm" 2>/dev/null || true
    
    for ((i=0; i<timeout; i++)); do
        # Use qvm-check --running to test if VM is running
        if ! qvm-check --running "$vm" 2>/dev/null; then
            # Extra wait for qubesd to finish internal cleanup
            msg_info "Waiting for qubesd cleanup..."
            sleep 10
            msg_ok "$vm is stopped"
            return 0
        fi
        sleep 1
    done
    
    # Force kill if still running
    msg_warn "VM $vm did not shutdown gracefully, forcing..."
    qvm-kill "$vm" 2>/dev/null || true
    sleep 5
    return 0
}
