#!/usr/bin/env bash

check_conflicts() {
    echo -e "${STY_CYAN}Checking for conflicting processes...${STY_RST}"
    
    local conflicts=()
    local running_procs=()
    
    declare -A conflict_map
    conflict_map["dunst"]="Notification Daemon"
    conflict_map["mako"]="Notification Daemon"
    conflict_map["swaync"]="Notification Daemon"
    conflict_map["waybar"]="Status Bar"
    conflict_map["ironbar"]="Status Bar"
    conflict_map["eww"]="Widget System"
    conflict_map["ags"]="Shell System"
    conflict_map["hyprpaper"]="Wallpaper Daemon"
    conflict_map["swww"]="Wallpaper Daemon"
    conflict_map["mpvpaper"]="Wallpaper Daemon"
    conflict_map["wpaperd"]="Wallpaper Daemon"
    
    for pkg in "${!conflict_map[@]}"; do
        if pgrep -x "$pkg" &>/dev/null; then
            conflicts+=("$pkg (${conflict_map[$pkg]})")
            running_procs+=("$pkg")
        fi
    done
    
    if [ ${#conflicts[@]} -gt 0 ]; then
        echo -e "${STY_YELLOW}Found conflicting processes running:${STY_RST}"
        for c in "${conflicts[@]}"; do
            echo -e "  ${STY_RED}⚠${STY_RST} $c"
        done
        echo ""
        
        if [[ "$ask" == "true" ]]; then
            if tui_confirm "Terminate conflicting processes?"; then
                for proc in "${running_procs[@]}"; do
                    pkill -x "$proc" && log_success "Terminated $proc"
                done
            fi
        else
            for proc in "${running_procs[@]}"; do
                pkill -x "$proc"
            done
        fi
    else
        log_success "No conflicting processes found."
    fi
}
