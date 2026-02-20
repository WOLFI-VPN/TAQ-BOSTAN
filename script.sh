#!/bin/bash
#
# ==================================================================================
# 
#                            WOLFI-VPN Script Launcher
# 
#  این اسکریپت به عنوان یک منوی مرکزی برای اجرای اسکریپت‌های مختلف عمل می‌کند.
#  کاربران می‌توانند با انتخاب گزینه‌های مختلف، ابزارهای متفاوتی را اجرا کنند.
#
#  نگارش: 1.0.0
#  توسعه‌دهنده: ParsaKSH
#
# ==================================================================================
#

# --- تعریف رنگ‌ها برای خروجی بهتر در ترمینال ---
GREEN="\e[32m"
BOLD_GREEN="\e[1;32m"
YELLOW="\e[33m"
BLUE="\e[34m"
CYAN="\e[36m"
MAGENTA="\e[35m"
WHITE="\e[37m"
RED="\e[31m"
RESET="\e[0m"

# ------------------ تابع نمایش بنر گرافیکی ------------------
# عملکرد: یک بنر زیبا با استفاده از کاراکترهای ASCII و رنگ‌های مختلف نمایش می‌دهد.
#          همچنین اطلاعات توسعه‌دهنده و حامی مالی را چاپ می‌کند.
print_art() {
  local art_width=62
  local line_char="═"
  local line=$(printf "%${art_width}s" | sed "s/ /${line_char}/g")

  local art=$(cat << "EOF"
@@@@@@@   @@@@@@    @@@@@@
@@@@@@@  @@@@@@@@  @@@@@@@@
  @@!    @@!  @@@  @@!  @@@
  !@!    !@!  @!@  !@!  @!@
  @!!    @!@!@!@!  @!@  !@!
  !!!    !!!@!!!!  !@!  !!!
  !!:    !!:  !!!  !!:!!:!:
  :!:    :!:  !:!  :!: :!:
   ::    ::   :::  ::::: :!
   :      :   : :   : :  :::
@@@@@@@    @@@@@@    @@@@@@  @@@@@@@   @@@@@@   @@@  @@@
@@@@@@@@  @@@@@@@@  @@@@@@@  @@@@@@@  @@@@@@@@  @@@@ @@@
@@!  @@@  @@!  @@@  !@@        @@!    @@!  @@@  @@!@!@@@
!@   @!@  !@!  @!@  !@!        !@!    !@!  @!@  !@!!@!@!
@!@!@!@   @!@  !@!  !!@@!!     @!!    @!@!@!@!  @!@ !!@!
!!!@!!!!  !@!  !!!   !!@!!!    !!!    !!!@!!!!  !@!  !!!
!!:  !!!  !!:  !!!       !:!   !!:    !!:  !!!  !!:  !!!
:!:  !:!  :!:  !:!      !:!    :!:    :!:  !:!  :!:  !:!
 :: ::::  ::::: ::  :::: ::     ::    ::   :::   ::   ::
:: : ::    : :  :   :: : :      :      :   : :  ::    :
EOF
)
  clear
  echo -e "${CYAN}╔${line}╗${RESET}"
  
  while IFS= read -r art_line; do
    printf "${CYAN}║${BOLD_GREEN}%*s%s%*s${CYAN}║${RESET}\n" $(((art_width - ${#art_line}) / 2)) "" "$art_line" $(((art_width - ${#art_line} + 1) / 2)) ""
  done <<< "$art"

  echo -e "${CYAN}╠${line}╣${RESET}"

  local dev_line="Developed by ParsaKSH"
  local sponsor_line="Sponsored by DigitalVPS.ir"
  local love_line="♥ With Love From Iran ♥"

  printf "${CYAN}║${YELLOW}%*s%s%*s${CYAN}║${RESET}\n" $(((art_width - ${#dev_line}) / 2)) "" "$dev_line" $(((art_width - ${#dev_line} + 1) / 2)) ""
  printf "${CYAN}║${RED}%*s%s%*s${CYAN}║${RESET}\n" $(((art_width - ${#sponsor_line}) / 2)) "" "$sponsor_line" $(((art_width - ${#sponsor_line} + 1) / 2)) ""
  printf "${CYAN}║${MAGENTA}%*s%s%*s${CYAN}║${RESET}\n" $(((art_width - ${#love_line}) / 2)) "" "$love_line" $(((art_width - ${#love_line} + 1) / 2)) ""
  
  echo -e "${CYAN}╚${line}╝${RESET}"
  echo ""
}
# ------------------ تابع نمایش منوی اصلی ------------------
# عملکرد: لیست گزینه‌های قابل انتخاب را برای کاربر نمایش می‌دهد.
print_menu() {
  local menu_width=55
  local line=$(printf "%${menu_width}s" | sed "s/ /─/g")

  echo -e "${CYAN}┌${line}┐${RESET}"
  printf "${CYAN}│${YELLOW}%*s%s%*s${CYAN}│${RESET}\n" $(((menu_width-24)/2)) "" "TAQ-BOSTAN Main Menu" $(((menu_width-24+1)/2)) ""
  echo -e "${CYAN}├${line}┤${RESET}"
  printf "${CYAN}│${GREEN} %-53s ${CYAN}│${RESET}\n" "1) Create best and safest tunnel"
  printf "${CYAN}│${GREEN} %-53s ${CYAN}│${RESET}\n" "2) Create local IPv6 with Sit"
  printf "${CYAN}│${GREEN} %-53s ${CYAN}│${RESET}\n" "3) Create local IPv6 with Wireguard"
  echo -e "${CYAN}├${line}┤${RESET}"
  printf "${CYAN}│${RED} %-53s ${CYAN}│${RESET}\n" "4) Delete tunnel"
  printf "${CYAN}│${RED} %-53s ${CYAN}│${RESET}\n" "5) Delete local IPv6 with Sit"
  printf "${CYAN}│${RED} %-53s ${CYAN}│${RESET}\n" "6) Delete local IPv6 with Wireguard"
  echo -e "${CYAN}├${line}┤${RESET}"
  printf "${CYAN}│${BLUE} %-53s ${CYAN}│${RESET}\n" "7) Hysteria Tunnel Speedtest (Run in Iran server)"
  echo -e "${CYAN}└${line}┘${RESET}"
  echo ""
}

# ------------------ تابع اجرای گزینه انتخابی ------------------
# ورودی: شماره گزینه انتخاب شده توسط کاربر.
# عملکرد: بر اساس شماره ورودی، دستور یا اسکریپت مربوطه را اجرا می‌کند.
execute_option() {
  local choice="$1"
  case "$choice" in
    1)
      echo -e "${CYAN}Executing: Create best and safest tunnel...${RESET}"
      bash <(curl -Ls https://raw.githubusercontent.com/WOLFI-VPN/TAQ-BOSTAN/main/hysteria.sh)
      ;;
    2)
      echo -e "${CYAN}Executing: Create local IPv6 with Sit...${RESET}"
      bash <(curl -Ls https://raw.githubusercontent.com/WOLFI-VPN/TAQ-BOSTAN/main/sit.sh)
      ;;
    3)
      echo -e "${CYAN}Executing: Create local IPv6 with Wireguard...${RESET}"
      bash <(curl -Ls https://raw.githubusercontent.com/WOLFI-VPN/TAQ-BOSTAN/main/wireguard.sh)
      ;;
    4)
      echo -e "${CYAN}Deleting Hysteria tunnel...${RESET}"
      sudo systemctl daemon-reload 2>/dev/null
      for i in {1..9}; do
        sudo systemctl disable hysteria$i 2>/dev/null
      done
      sudo systemctl disable hysteria 2>/dev/null
      sudo rm /etc/hysteria/server-config.yaml 2>/dev/null
      sudo rm /etc/hysteria/iran-config*.yaml 2>/dev/null
      rm /etc/hysteria/hysteria-mapping.txt
      echo -e "${GREEN}Hysteria tunnel successfully deleted.${RESET}"
      read -p "Do you want to reboot now? [y/N]: " REBOOT_CHOICE
      if [[ "$REBOOT_CHOICE" =~ ^[Yy]$ ]]; then
        sudo shutdown -r now
      fi
      ;;
     5)
       echo -e "${CYAN}Deleting local IPv6 with Sit...${RESET}"
       for i in {1..8}; do
         sudo rm /etc/netplan/pdtun$i.yaml 2>/dev/null
         sudo rm /etc/systemd/network/tun$i.network 2>/dev/null
         sudo rm /etc/netplan/pdtun.yaml 2>/dev/null
         sudo rm /etc/systemd/network/tun0.network 2>/dev/null
       done
       sudo netplan apply 
       sudo systemctl restart systemd-networkd
       echo -e "${GREEN}Local IPv6 with Sit successfully deleted.${RESET}"
       read -p "Do you want to reboot now? [y/N]: " REBOOT_CHOICE
       if [[ "$REBOOT_CHOICE" =~ ^[Yy]$ ]]; then
         sudo shutdown -r now
       fi
       ;;
     6)
       echo -e "${CYAN}Deleting local IPv6 with Wireguard...${RESET}"
       sudo wg-quick down TAQBOSTANwg 2>/dev/null
       sudo systemctl disable wg-quick@TAQBOSTANwg 2>/dev/null
       sudo rm /etc/wireguard/TAQBOSTANwg.conf 2>/dev/null
       echo -e "${GREEN}Local IPv6 with Wireguard successfully deleted.${RESET}"
       read -p "Do you want to reboot now? [y/N]: " REBOOT_CHOICE
       if [[ "$REBOOT_CHOICE" =~ ^[Yy]$ ]]; then
         sudo shutdown -r now
       fi
       ;;
     7)
       read -p "Enter the tunnel name to run the speedtest: " tunnel_name
       if [ -z "$tunnel_name" ]; then
         echo -e "${RED}Tunnel name cannot be empty.${RESET}"
       elif [ ! -f "/etc/hysteria/iran-${tunnel_name}.yaml" ]; then
         echo -e "${RED}Config file for tunnel '${tunnel_name}' not found.${RESET}"
       else
         /usr/local/bin/hysteria -c "/etc/hysteria/iran-${tunnel_name}.yaml" speedtest
       fi
       ;;
     *)
       echo -e "${RED}Invalid option. Exiting...${RESET}"
       exit 1
       ;;
   esac
 }
 
 print_art
 print_menu
 read -p "$(echo -e "${WHITE}Select an option [1-7]: ${RESET}")" user_choice
 execute_option "$user_choice"
