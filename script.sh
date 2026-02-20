#!/bin/bash

############################################################
#                 TAQ-BOSTAN ENTERPRISE PANEL
#                   Production Edition
############################################################

######################## COLORS ############################

GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
BLUE="\e[34m"
CYAN="\e[36m"
MAGENTA="\e[35m"
WHITE="\e[97m"
BOLD="\e[1m"
RESET="\e[0m"

######################## CONFIG ############################

INSTALL_DIR="/opt/taq-bostan"
LOG_FILE="/var/log/taq-bostan.log"

GITHUB_BASE="https://raw.githubusercontent.com/WOLFI-VPN/TAQ-BOSTAN/main"
HYSTERIA_URL="$GITHUB_BASE/hysteria.sh"
SCRIPT_URL="$GITHUB_BASE/script.sh"

LOCAL_HYSTERIA="$INSTALL_DIR/hysteria.sh"
LOCAL_SCRIPT="$INSTALL_DIR/script.sh"

######################## LOGGER ############################

log() {
  echo -e "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> $LOG_FILE
}

######################## CHECK ROOT ########################

check_root() {
  if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Run as root.${RESET}"
    exit 1
  fi
}

######################## CHECK INTERNET ####################

check_internet() {
  ping -c1 github.com >/dev/null 2>&1 || {
    echo -e "${RED}No internet connection.${RESET}"
    exit 1
  }
}

######################## INSTALL CURL ######################

install_curl() {
  if ! command -v curl &> /dev/null; then
    echo -e "${YELLOW}Installing curl...${RESET}"
    apt update -y >/dev/null 2>&1
    apt install curl -y >/dev/null 2>&1
  fi
}

######################## SHA CHECK #########################

sha_check() {
  local file1=$1
  local file2=$2
  sha256sum "$file1" | awk '{print $1}' > /tmp/sha1
  sha256sum "$file2" | awk '{print $1}' > /tmp/sha2
  cmp -s /tmp/sha1 /tmp/sha2
}

######################## DOWNLOAD FILE #####################

download_file() {
  local url=$1
  local dest=$2
  curl -Ls --connect-timeout 10 "$url" -o "$dest"
}

######################## UPDATE HYSTERIA ###################

update_hysteria() {

  mkdir -p $INSTALL_DIR
  TMP="/tmp/hysteria_new.sh"

  echo -e "${CYAN}Checking hysteria update...${RESET}"
  download_file $HYSTERIA_URL $TMP

  if [ ! -s "$TMP" ]; then
    echo -e "${RED}Download failed.${RESET}"
    log "Hysteria download failed"
    return
  fi

  if [ ! -f "$LOCAL_HYSTERIA" ]; then
    mv $TMP $LOCAL_HYSTERIA
    chmod +x $LOCAL_HYSTERIA
    echo -e "${GREEN}Installed hysteria.sh${RESET}"
    log "Hysteria installed"
    return
  fi

  if ! sha_check $TMP $LOCAL_HYSTERIA; then
    cp $LOCAL_HYSTERIA "$LOCAL_HYSTERIA.bak"
    mv $TMP $LOCAL_HYSTERIA
    chmod +x $LOCAL_HYSTERIA
    echo -e "${GREEN}Updated hysteria.sh${RESET}"
    log "Hysteria updated"
  else
    rm -f $TMP
    echo -e "${GREEN}Already up to date${RESET}"
  fi
}

######################## SELF UPDATE #######################

self_update() {

  TMP="/tmp/script_new.sh"
  download_file $SCRIPT_URL $TMP

  if [ ! -s "$TMP" ]; then
    echo -e "${RED}Self update failed.${RESET}"
    return
  fi

  if ! sha_check $TMP $0; then
    echo -e "${YELLOW}New version detected. Updating...${RESET}"
    cp $0 "$0.bak"
    mv $TMP $0
    chmod +x $0
    echo -e "${GREEN}Updated. Restarting...${RESET}"
    exec $0
  else
    rm -f $TMP
  fi
}

######################## SYSTEM MONITOR ####################

system_monitor() {
  clear
  echo -e "${CYAN}===== SYSTEM STATUS =====${RESET}"
  echo
  uptime
  echo
  free -h
  echo
  df -h /
  echo
  read -p "Press Enter..."
}

######################## TUNNEL STATUS #####################

tunnel_status() {

  services=$(systemctl list-units --type=service --all | grep hysteria | awk '{print $1}')

  if [ -z "$services" ]; then
    echo "No hysteria services."
  else
    for svc in $services; do
      name="${svc%.service}"
      status=$(systemctl is-active $name 2>/dev/null)
      echo "$name → $status"
    done
  fi

  read -p "Press Enter..."
}

######################## RESTART ALL ########################

restart_all() {
  for s in /etc/systemd/system/hysteria*.service; do
    name=$(basename "$s" .service)
    systemctl restart $name 2>/dev/null
  done
  echo -e "${GREEN}All restarted.${RESET}"
  sleep 1
}

######################## DELETE ALL #########################

delete_all() {

  read -p "Are you sure? [y/N]: " confirm
  [[ "$confirm" =~ ^[Yy]$ ]] || return

  systemctl stop hysteria* 2>/dev/null
  rm -rf /etc/hysteria
  rm -rf /etc/systemd/system/hysteria*
  systemctl daemon-reload

  echo -e "${GREEN}All removed.${RESET}"
  read -p "Press Enter..."
}

######################## UI ###############################

draw_menu() {
  clear
  echo -e "${GREEN}============================================${RESET}"
  echo -e "${BOLD}${CYAN}      TAQ-BOSTAN ENTERPRISE PANEL${RESET}"
  echo -e "${GREEN}============================================${RESET}"
  echo
  echo "1) Hysteria Manager"
  echo "2) Restart All Tunnels"
  echo "3) Tunnel Status"
  echo "4) System Monitor"
  echo "5) Delete All"
  echo "6) Self Update"
  echo "7) Exit"
  echo
}

######################## INIT ###############################

check_root
check_internet
install_curl
update_hysteria

######################## MAIN LOOP ##########################

while true; do

draw_menu
read -p "Select option [1-7]: " choice

case $choice in

1)
  bash $LOCAL_HYSTERIA
  ;;

2)
  restart_all
  ;;

3)
  tunnel_status
  ;;

4)
  system_monitor
  ;;

5)
  delete_all
  ;;

6)
  self_update
  ;;

7)
  exit 0
  ;;

*)
  echo -e "${RED}Invalid option${RESET}"
  sleep 1
  ;;

esac

done
