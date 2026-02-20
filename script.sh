#!/bin/bash

#################################
#         COLOR SYSTEM
#################################

GREEN="\e[32m"
RED="\e[31m"
YELLOW="\e[33m"
BLUE="\e[34m"
CYAN="\e[36m"
MAGENTA="\e[35m"
WHITE="\e[97m"
BOLD="\e[1m"
RESET="\e[0m"

#################################
#        GITHUB AUTO UPDATE
#################################

GITHUB_REPO="https://github.com/WOLFI-VPN/TAQ-BOSTAN.git"
INSTALL_DIR="/opt/taq-bostan"

install_git() {
  if ! command -v git &> /dev/null; then
    echo -e "${YELLOW}Git not found. Installing...${RESET}"
    apt update -y && apt install git -y
  fi
}

update_from_github() {

  install_git

  echo -e "${CYAN}Checking for updates from GitHub...${RESET}"

  if [ ! -d "$INSTALL_DIR" ]; then
    git clone $GITHUB_REPO $INSTALL_DIR
  else
    cd $INSTALL_DIR || exit 1
    git fetch --all
    git reset --hard origin/$(git rev-parse --abbrev-ref HEAD)
    git pull
  fi

  cd $INSTALL_DIR || exit 1
}

#################################
#        UI FUNCTIONS
#################################

line() {
  echo -e "${GREEN}╠══════════════════════════════════════════════╣${RESET}"
}

top() {
  echo -e "${GREEN}╔══════════════════════════════════════════════╗${RESET}"
}

bottom() {
  echo -e "${GREEN}╚══════════════════════════════════════════════╝${RESET}"
}

title() {
  echo -e "${GREEN}║${RESET}   ${BOLD}${CYAN}$1${RESET}$(printf "%*s" $((42-${#1})) "")${GREEN}║${RESET}"
}

option() {
  printf "${GREEN}║${RESET} ${YELLOW}%-2s${RESET} %-40s ${GREEN}║${RESET}\n" "$1)" "$2"
}

loading() {
  echo -ne "${CYAN}Loading"
  for i in {1..3}; do
    echo -ne "."
    sleep 0.3
  done
  echo -e "${RESET}"
}

#################################
#        SYSTEM CHECK
#################################

check_hysteria_script() {
  if [ ! -f "$INSTALL_DIR/hysteria.sh" ]; then
    echo -e "${RED}hysteria.sh not found in repository!${RESET}"
    exit 1
  fi
}

#################################
#        DELETE ALL
#################################

delete_all() {
  echo -e "${RED}Removing ALL Hysteria Components...${RESET}"

  systemctl stop hysteria 2>/dev/null || true
  systemctl disable hysteria 2>/dev/null || true

  for s in /etc/systemd/system/hysteria*.service; do
    name=$(basename "$s" .service)
    systemctl stop $name 2>/dev/null || true
    systemctl disable $name 2>/dev/null || true
    rm -f $s
  done

  rm -rf /etc/hysteria
  rm -rf /var/log/hysteria*
  rm -f /etc/logrotate.d/hysteria

  systemctl daemon-reload

  echo -e "${GREEN}✔ All Hysteria components removed successfully.${RESET}"
}

#################################
#        SPEEDTEST
#################################

speedtest() {
  read -p "Enter Tunnel ID: " id
  if [ -f "/etc/hysteria/iran-config$id.yaml" ]; then
    /usr/local/bin/hysteria -c /etc/hysteria/iran-config$id.yaml speedtest
  else
    echo -e "${RED}Tunnel not found.${RESET}"
  fi
}

#################################
#        START UPDATE FIRST
#################################

update_from_github

#################################
#        MAIN MENU
#################################

while true; do
clear
top
title "TAQ-BOSTAN ADVANCED PANEL"
line
option 1 "Hysteria Advanced Manager"
option 2 "Tunnel SpeedTest"
option 3 "Restart All Tunnels"
option 4 "Show Tunnel Status"
option 5 "Delete ALL Hysteria"
option 6 "System Resource Monitor"
option 7 "Exit"
bottom

echo
read -p "$(echo -e ${WHITE}Select an option [1-7]: ${RESET})" choice

case $choice in

1)
  check_hysteria_script
  loading
  bash $INSTALL_DIR/hysteria.sh
;;

2)
  speedtest
  read -p "Press Enter..."
;;

3)
  echo -e "${CYAN}Restarting all tunnels...${RESET}"
  for s in /etc/systemd/system/hysteria*.service; do
    name=$(basename "$s" .service)
    systemctl restart $name 2>/dev/null || true
  done
  echo -e "${GREEN}✔ All tunnels restarted.${RESET}"
  sleep 1
;;

4)
  echo -e "${CYAN}Tunnel Status:${RESET}"

  services=$(systemctl list-units --type=service --all | grep -E '^hysteria[0-9]*\.service' | awk '{print $1}')

  if [ -z "$services" ]; then
    echo "No hysteria services found."
  else
    for svc in $services; do
      name="${svc%.service}"
      status=$(systemctl is-active $name 2>/dev/null || echo "inactive")

      if [ "$name" = "hysteria" ]; then
        echo "Foreign Server → $status"
      elif [[ "$name" =~ ^hysteria[0-9]+$ ]]; then
        id="${name#hysteria}"
        echo "Iran Tunnel $id → $status"
      fi
    done
  fi

  read -p "Press Enter..."
;;

5)
  read -p "Are you sure? [y/N]: " confirm
  if [[ "$confirm" =~ ^[Yy]$ ]]; then
    delete_all
    read -p "Press Enter..."
  fi
;;

6)
  clear
  echo -e "${CYAN}===== SYSTEM RESOURCE =====${RESET}"
  echo
  echo -e "${YELLOW}CPU Load:${RESET}"
  uptime
  echo
  echo -e "${YELLOW}Memory Usage:${RESET}"
  free -h
  echo
  echo -e "${YELLOW}Disk Usage:${RESET}"
  df -h /
  echo
  read -p "Press Enter..."
;;

7)
  exit 0
;;

*)
  echo -e "${RED}Invalid option.${RESET}"
  sleep 1
;;

esac
done
