#!/bin/bash
#
# lib/cleanup.sh
# Functions for cleaning up existing VMs
#

# Source common if not already loaded
[[ -z "$NC" ]] && source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

# Find all filtered VMs (only our custom ones, not system)
find_filtered_vms() {
    # DVM templates we created
    EXISTING_DVM_TEMPLATES=$(qvm-ls --raw-list 2>/dev/null | grep -E "^dvm-(email|drive|banking|shopping|social|media|travel|admin|health|gov|ai|crypto|news|work)" || true)
    # AppVMs we created
    EXISTING_APPVMS=$(qvm-ls --raw-list 2>/dev/null | grep -E "^(email|drive|banking|shopping|social|media|travel|admin|health|gov|ai|crypto|news|work)$" || true)
    # Templates we created
    EXISTING_TEMPLATES=$(qvm-ls --raw-list --class TemplateVM 2>/dev/null | grep -E "\-(email|drive|banking|shopping|social|media|travel|admin|health|gov|ai|crypto|news|work)$" || true)
    
    export EXISTING_DVM_TEMPLATES EXISTING_APPVMS EXISTING_TEMPLATES
}

# Check if any filtered VMs exist
has_filtered_vms() {
    find_filtered_vms
    [[ -n "$EXISTING_DVM_TEMPLATES" || -n "$EXISTING_APPVMS" || -n "$EXISTING_TEMPLATES" ]]
}

# Interactive cleanup with multi-select
interactive_cleanup() {
    echo -e "${BLUE}=== Cleanup ===${NC}"
    echo ""
    
    find_filtered_vms
    
    # Build list of VMs
    declare -a VM_LIST
    declare -a VM_TYPES
    
    for vm in $EXISTING_DVM_TEMPLATES; do
        VM_LIST+=("$vm")
        VM_TYPES+=("DVM Template")
    done
    
    for vm in $EXISTING_APPVMS; do
        VM_LIST+=("$vm")
        VM_TYPES+=("AppVM")
    done
    
    for vm in $EXISTING_TEMPLATES; do
        VM_LIST+=("$vm")
        VM_TYPES+=("Template")
    done
    
    if [ ${#VM_LIST[@]} -eq 0 ]; then
        echo "No existing filtered VMs found."
        echo ""
        return 0
    fi
    
    echo "Found existing filtered VMs:"
    echo ""
    for i in "${!VM_LIST[@]}"; do
        echo -e "  $((i+1))) ${VM_LIST[$i]} ${CYAN}(${VM_TYPES[$i]})${NC}"
    done
    echo ""
    echo -e "  ${YELLOW}a) Select all${NC}"
    echo -e "  ${YELLOW}n) Select none (skip cleanup)${NC}"
    echo ""
    echo "Enter numbers separated by spaces (e.g., '1 3 4') or 'a' for all:"
    read -p "> " SELECTION
    
    if [[ "$SELECTION" == "n" || -z "$SELECTION" ]]; then
        msg_warn "Skipping cleanup"
        echo ""
        return 0
    fi
    
    declare -a TO_DELETE
    
    if [[ "$SELECTION" == "a" ]]; then
        TO_DELETE=("${VM_LIST[@]}")
    else
        for num in $SELECTION; do
            if [[ "$num" =~ ^[0-9]+$ ]] && [ "$num" -ge 1 ] && [ "$num" -le ${#VM_LIST[@]} ]; then
                TO_DELETE+=("${VM_LIST[$((num-1))]}")
            fi
        done
    fi
    
    if [ ${#TO_DELETE[@]} -eq 0 ]; then
        msg_warn "No valid selection, skipping cleanup"
        echo ""
        return 0
    fi
    
    echo ""
    echo "Will delete:"
    for vm in "${TO_DELETE[@]}"; do
        echo -e "  - ${RED}$vm${NC}"
    done
    echo ""
    read -p "Confirm deletion? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        msg_warn "Cancelled"
        echo ""
        return 0
    fi
    
    echo ""
    echo -e "${YELLOW}Deleting VMs...${NC}"
    
    # Get desktop directory (handles FR/EN locales)
    local desktop_dir
    desktop_dir="$(get_desktop_dir)"
    
    # Delete in correct order: DVM templates first, then AppVMs, then Templates
    # First pass: DVM templates and AppVMs
    for vm in "${TO_DELETE[@]}"; do
        if [[ ! "$vm" =~ \-(email|drive|banking|shopping|social|media|travel|admin|health|gov|ai|crypto|news|work)$ ]]; then
            remove_vm "$vm"
            # Also remove dom0 shortcuts for this VM
            rm -f "$desktop_dir/${vm}-"*.desktop 2>/dev/null
            rm -f "$HOME/.local/share/applications/${vm}-"*.desktop 2>/dev/null
        fi
    done
    
    # Second pass: Templates
    for vm in "${TO_DELETE[@]}"; do
        if [[ "$vm" =~ \-(email|drive|banking|shopping|social|media|travel|admin|health|gov|ai|crypto|news|work)$ ]]; then
            remove_vm "$vm"
        fi
    done
    
    msg_ok "Cleanup complete"
    echo ""
}
