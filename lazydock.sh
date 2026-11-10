#!/usr/bin/env bash
# ==============================================================================
# LazyDock 🦥⚓ - The Zero-Effort Docker & Compose Manager
# "Why remember docker commands when you have 10 fingers and 0 motivation?"
# ==============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

# Detect docker-compose.yaml or docker-compose.yml
if [ -f "$SCRIPT_DIR/docker-compose.yaml" ]; then
    COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yaml"
elif [ -f "$SCRIPT_DIR/docker-compose.yml" ]; then
    COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
else
    COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yaml"
fi

# Compose profiles to include (override via: export COMPOSE_PROFILES="myprofile")
PROFILES="${COMPOSE_PROFILES:-manual}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Helper: print banner
print_header() {
    clear
    echo -e "${CYAN}${BOLD}======================================================${NC}"
    echo -e "${CYAN}${BOLD}         🦥 LazyDock - Minimum Effort Docker          ${NC}"
    echo -e "${CYAN}${BOLD}======================================================${NC}"
    echo -e "${BLUE}Project Directory:${NC} $SCRIPT_DIR"
    echo ""
}

# Helper: pause and wait for enter
pause() {
    echo ""
    read -rp "Press [Enter] to return to menu..."
}

# 1. Drop Caches
drop_caches() {
    echo -e "\n${YELLOW}${BOLD}[*] Syncing filesystems and dropping page caches...${NC}"
    sync
    if sudo sysctl -w vm.drop_caches=3; then
        echo -e "${GREEN}✓ Cache successfully dropped.${NC}"
    else
        echo -e "${RED}✗ Failed to drop cache (sudo permission required).${NC}"
    fi
    echo ""
    echo -e "${BOLD}Current Memory Status:${NC}"
    free -h
}

# Helper: get all services defined in docker compose file
get_compose_services() {
    if [ -f "$COMPOSE_FILE" ]; then
        sed -n '/^services:/,/^[a-z]/p' "$COMPOSE_FILE" | grep -E '^  [a-zA-Z0-9_-]+:' | tr -d ' :\r'
    fi
}

# 2. Stop running container(s)
stop_containers() {
    print_header
    echo -e "${BOLD}Select a running container to stop:${NC}\n"

    mapfile -t RUNNING_CONTAINERS < <(docker ps --format "{{.Names}}" | tr -d '\r')

    if [ ${#RUNNING_CONTAINERS[@]} -eq 0 ]; then
        echo -e "${YELLOW}No running containers found.${NC}"
        pause
        return
    fi

    for i in "${!RUNNING_CONTAINERS[@]}"; do
        printf "  [%d] %s\n" "$((i+1))" "${RUNNING_CONTAINERS[$i]}"
    done
    echo ""
    echo "  [a] Stop ALL running containers"
    echo "  [b] Back to main menu"
    echo ""

    read -rp "Enter choice: " choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#RUNNING_CONTAINERS[@]}" ]; then
        TARGET="${RUNNING_CONTAINERS[$((choice-1))]}"
        echo -e "\n${YELLOW}Stopping container: $TARGET...${NC}"
        docker stop "$TARGET"
        echo -e "${GREEN}✓ Container $TARGET stopped.${NC}"
        pause
    elif [ "$choice" == "a" ] || [ "$choice" == "A" ]; then
        echo -e "\n${YELLOW}Stopping all running containers...${NC}"
        docker stop "${RUNNING_CONTAINERS[@]}"
        echo -e "${GREEN}✓ All containers stopped.${NC}"
        pause
    fi
}

# 3. Start a container
start_container() {
    print_header
    echo -e "${BOLD}Select a service to start (docker compose up -d):${NC}\n"

    mapfile -t SERVICES < <(get_compose_services)

    if [ ${#SERVICES[@]} -eq 0 ]; then
        echo -e "${RED}No services found in compose file.${NC}"
        pause
        return
    fi

    for i in "${!SERVICES[@]}"; do
        SVC="${SERVICES[$i]}"
        if docker ps --format '{{.Names}}' | grep -q "^${SVC}$"; then
            STATUS="${GREEN}[RUNNING]${NC}"
        else
            STATUS="${RED}[STOPPED]${NC}"
        fi
        printf "  [%2d] %-25s %b\n" "$((i+1))" "$SVC" "$STATUS"
    done
    echo ""
    echo "  [b] Back to main menu"
    echo ""

    read -rp "Enter choice: " choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#SERVICES[@]}" ]; then
        TARGET="${SERVICES[$((choice-1))]}"
        echo -e "\n${YELLOW}Starting $TARGET...${NC}"
        if docker compose --profile "$PROFILES" up -d "$TARGET"; then
            echo -e "\n${GREEN}✓ $TARGET started successfully.${NC}"
        else
            echo -e "\n${RED}✗ Failed to start $TARGET.${NC}"
        fi
        pause
    fi
}

# 4. Restart a container (Stop -> Drop Cache -> Start)
restart_container() {
    print_header
    echo -e "${BOLD}Select a service to restart (Stop -> Drop Cache -> Start):${NC}\n"

    mapfile -t SERVICES < <(get_compose_services)

    for i in "${!SERVICES[@]}"; do
        SVC="${SERVICES[$i]}"
        if docker ps --format '{{.Names}}' | grep -q "^${SVC}$"; then
            STATUS="${GREEN}[RUNNING]${NC}"
        else
            STATUS="${RED}[STOPPED]${NC}"
        fi
        printf "  [%2d] %-25s %b\n" "$((i+1))" "$SVC" "$STATUS"
    done
    echo ""
    echo "  [b] Back to main menu"
    echo ""

    read -rp "Enter choice: " choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#SERVICES[@]}" ]; then
        TARGET="${SERVICES[$((choice-1))]}"
        echo -e "\n${YELLOW}[1/3] Stopping $TARGET if running...${NC}"
        docker stop "$TARGET" 2>/dev/null || docker compose --profile "$PROFILES" stop "$TARGET"

        echo -e "\n${YELLOW}[2/3] Dropping caches before launch...${NC}"
        sync
        sudo sysctl -w vm.drop_caches=3

        echo -e "\n${YELLOW}[3/3] Starting $TARGET...${NC}"
        if docker compose --profile "$PROFILES" up -d "$TARGET"; then
            echo -e "\n${GREEN}✓ Restart complete for $TARGET.${NC}"
        else
            echo -e "\n${RED}✗ Failed to restart $TARGET.${NC}"
        fi
        pause
    fi
}

# 5. Recompile / Build and Start
build_and_start() {
    print_header
    echo -e "${BOLD}Select a service to rebuild and start:${NC}\n"

    mapfile -t SERVICES < <(get_compose_services)

    for i in "${!SERVICES[@]}"; do
        printf "  [%2d] %s\n" "$((i+1))" "${SERVICES[$i]}"
    done
    echo ""
    echo "  [b] Back to main menu"
    echo ""

    read -rp "Enter choice: " choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#SERVICES[@]}" ]; then
        TARGET="${SERVICES[$((choice-1))]}"
        echo ""
        echo "  [1] Normal Build & Start (uses Docker layer cache)"
        echo "  [2] Clean Build & Start (--no-cache)"
        echo "  [b] Cancel"
        echo ""
        read -rp "Choose build type [1/2]: " bchoice

        if [ "$bchoice" == "1" ]; then
            echo -e "\n${YELLOW}Building and starting $TARGET...${NC}"
            docker compose --profile "$PROFILES" up -d --build "$TARGET"
            echo -e "${GREEN}✓ Done.${NC}"
            pause
        elif [ "$bchoice" == "2" ]; then
            echo -e "\n${YELLOW}Clean building $TARGET (--no-cache)...${NC}"
            docker compose --profile "$PROFILES" build --no-cache "$TARGET"
            echo -e "${YELLOW}Starting $TARGET...${NC}"
            docker compose --profile "$PROFILES" up -d "$TARGET"
            echo -e "${GREEN}✓ Done.${NC}"
            pause
        fi
    fi
}

# 6. View logs
view_logs() {
    print_header
    echo -e "${BOLD}Select container to view logs (Ctrl+C to exit log stream):${NC}\n"

    mapfile -t ALL_CONTAINERS < <(docker ps -a --format "{{.Names}}" | tr -d '\r')

    if [ ${#ALL_CONTAINERS[@]} -eq 0 ]; then
        echo -e "${YELLOW}No containers found.${NC}"
        pause
        return
    fi

    for i in "${!ALL_CONTAINERS[@]}"; do
        printf "  [%2d] %s\n" "$((i+1))" "${ALL_CONTAINERS[$i]}"
    done
    echo ""
    echo "  [b] Back to main menu"
    echo ""

    read -rp "Enter choice: " choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#ALL_CONTAINERS[@]}" ]; then
        TARGET="${ALL_CONTAINERS[$((choice-1))]}"
        echo -e "\n${CYAN}Tailing logs for $TARGET (Press Ctrl+C to stop)...${NC}\n"
        docker logs -f --tail 100 "$TARGET"
        pause
    fi
}

# 7. Clear log and view
clear_and_view_logs() {
    print_header
    echo -e "${BOLD}Select container to CLEAR logs and view (Ctrl+C to exit log stream):${NC}\n"

    mapfile -t ALL_CONTAINERS < <(docker ps -a --format "{{.Names}}" | tr -d '\r')

    if [ ${#ALL_CONTAINERS[@]} -eq 0 ]; then
        echo -e "${YELLOW}No containers found.${NC}"
        pause
        return
    fi

    for i in "${!ALL_CONTAINERS[@]}"; do
        printf "  [%2d] %s\n" "$((i+1))" "${ALL_CONTAINERS[$i]}"
    done
    echo ""
    echo "  [b] Back to main menu"
    echo ""

    read -rp "Enter choice: " choice

    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#ALL_CONTAINERS[@]}" ]; then
        TARGET="${ALL_CONTAINERS[$((choice-1))]}"
        echo -e "\n${YELLOW}Locating log file for $TARGET...${NC}"
        LOG_PATH=$(docker inspect --format='{{.LogPath}}' "$TARGET" 2>/dev/null)

        if [ -n "$LOG_PATH" ] && [ "$LOG_PATH" != "<no value>" ]; then
            echo -e "${YELLOW}Truncating $LOG_PATH...${NC}"
            if sudo truncate -s 0 "$LOG_PATH"; then
                echo -e "${GREEN}✓ Log file cleared successfully.${NC}"
            else
                echo -e "${RED}✗ Failed to clear log file (sudo required).${NC}"
            fi
        else
            echo -e "${YELLOW}Notice: LogPath not available for $TARGET.${NC}"
        fi

        echo -e "\n${CYAN}Streaming fresh logs for $TARGET (Press Ctrl+C to exit)...${NC}\n"
        docker logs -f "$TARGET"
        pause
    fi
}

# 8. Show status
show_status() {
    print_header
    echo -e "${BOLD}=== Docker Containers ===${NC}"
    docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
    echo -e "${BOLD}=== System Memory ===${NC}"
    free -h
    pause
}

# ==============================================================================
# Main Interactive Loop
# ==============================================================================
main() {
    while true; do
        print_header
        echo -e "${BOLD}Actions:${NC}"
        echo -e "  ${CYAN}[1]${NC} 🛑 Stop running container(s)"
        echo -e "  ${CYAN}[2]${NC} 🚀 Start a container (docker compose up -d)"
        echo -e "  ${CYAN}[3]${NC} 🔄 Restart a container (Stop -> Drop Cache -> Start)"
        echo -e "  ${CYAN}[4]${NC} 🔨 Rebuild / Recompile & Start (--build)"
        echo -e "  ${CYAN}[5]${NC} 🧹 Drop Memory Caches (sync & sysctl drop_caches=3)"
        echo -e "  ${CYAN}[6]${NC} 📜 View Container Logs (-f --tail 100)"
        echo -e "  ${CYAN}[7]${NC} 🧼 Clear Container Log & Stream Fresh Logs"
        echo -e "  ${CYAN}[8]${NC} 📊 Show Status (Containers & Memory)"
        echo -e "  ${CYAN}[q]${NC} 🚪 Exit"
        echo ""
        read -rp "Enter your choice [1-8 or q]: " option

        case "$option" in
            1) stop_containers ;;
            2) start_container ;;
            3) restart_container ;;
            4) build_and_start ;;
            5) drop_caches; pause ;;
            6) view_logs ;;
            7) clear_and_view_logs ;;
            8) show_status ;;
            q|Q) 
                echo -e "\n${GREEN}Exiting. Stay lazy! 🦥${NC}\n"
                exit 0 
                ;;
            *) 
                echo -e "${RED}Invalid choice.${NC}"
                sleep 1 
                ;;
        esac
    done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main
fi
