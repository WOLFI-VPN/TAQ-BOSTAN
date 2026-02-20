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
#  توسعه‌دهنده: WOLFI-VPN
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

  local dev_line="Developed by WOLFI-VPN"
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

# ------------------ تابع حذف نصب تعاملی ------------------
# عملکرد: یک منوی تعاملی برای حذف اجزای مختلف Hysteria نمایش می‌دهد.
#          کاربر می‌تواند انتخاب کند کدام بخش‌ها حذف شوند.
uninstall_menu() {
    while true; do
        echo -e "${YELLOW}Scanning for Hysteria components...${RESET}"

        local tunnel_configs=($(sudo find /etc/hysteria -name "iran-*.yaml" 2>/dev/null))
        local menu_options=()
        local tunnel_names=()

        # Add individual tunnels to the menu
        if [ ${#tunnel_configs[@]} -gt 0 ]; then
            for config in "${tunnel_configs[@]}"; do
                local tunnel_name=$(basename "$config" .yaml | sed 's/^iran-//')
                menu_options+=("Delete Tunnel: $tunnel_name")
                tunnel_names+=("$tunnel_name")
            done
        fi

        # Add other components
        local hysteria_binary=$(which hysteria 2>/dev/null)
        local log_file="/var/log/hysteria_script.log"
        local cron_job=$(crontab -l 2>/dev/null | grep "# Hysteria Tunnels Auto-Restart")

        [[ -n "$hysteria_binary" ]] && menu_options+=("Delete Hysteria Binary")
        [[ -f "$log_file" ]] && menu_options+=("Delete Script Log File")
        [[ -n "$cron_job" ]] && menu_options+=("Delete Auto-Restart Cronjob")
        
        menu_options+=("DELETE ALL COMPONENTS")
        menu_options+=("Back to Main Menu")

        if [ ${#menu_options[@]} -eq 2 ]; then # Only ALL and Back options are present
            echo -e "${GREEN}No Hysteria components found to uninstall.${RESET}"
            sleep 2
            return
        fi

        echo -e "${CYAN}Select the component to uninstall:${RESET}"
        select choice in "${menu_options[@]}"; do
            case "$choice" in
                "Delete Tunnel: "*) # Handles all tunnel deletion choices
                    local tunnel_to_delete=$(echo "$choice" | sed 's/Delete Tunnel: //')
                    read -p "Are you sure you want to permanently delete tunnel '$tunnel_to_delete'? [y/N]: " confirm
                    if [[ "$confirm" =~ ^[yY]$ ]]; then
                        echo "Deleting tunnel: $tunnel_to_delete..."
                        sudo systemctl disable --now "hysteria-iran-${tunnel_to_delete}.service" &>/dev/null
                        sudo rm -f "/etc/systemd/system/hysteria-iran-${tunnel_to_delete}.service"
                        sudo rm -f "/etc/hysteria/iran-${tunnel_to_delete}.yaml"
                        sudo sed -i "/^${tunnel_to_delete},/d" /etc/hysteria/port_mapping.txt
                        echo -e "${GREEN}Tunnel '$tunnel_to_delete' has been deleted.${RESET}"
                        sudo systemctl daemon-reload
                    else
                        echo "Deletion cancelled."
                    fi
                    break
                    ;;
                "Delete Hysteria Binary")
                    read -p "Are you sure you want to delete the Hysteria executable? [y/N]: " confirm
                    if [[ "$confirm" =~ ^[yY]$ ]]; then
                        sudo rm -f "$hysteria_binary"
                        echo -e "${GREEN}Hysteria binary deleted.${RESET}"
                    fi
                    break
                    ;;
                "Delete Script Log File")
                    read -p "Are you sure you want to delete the script log file? [y/N]: " confirm
                    if [[ "$confirm" =~ ^[yY]$ ]]; then
                        sudo rm -f "$log_file"
                        echo -e "${GREEN}Script log file deleted.${RESET}"
                    fi
                    break
                    ;;
                "Delete Auto-Restart Cronjob")
                    read -p "Are you sure you want to delete the auto-restart cronjob? [y/N]: " confirm
                    if [[ "$confirm" =~ ^[yY]$ ]]; then
                        (crontab -l | grep -v "# Hysteria Tunnels Auto-Restart" | crontab -)
                        echo -e "${GREEN}Auto-restart cronjob deleted.${RESET}"
                    fi
                    break
                    ;;
                "DELETE ALL COMPONENTS")
                    read -p "Are you sure you want to delete ALL Hysteria components? This is irreversible. [y/N]: " confirm
                    if [[ "$confirm" =~ ^[yY]$ ]]; then
                        echo "Deleting all components..."
                        # Stop and remove all services
                        local services=($(systemctl list-unit-files | grep -o 'hysteria-.*\.service'))
                        if [ ${#services[@]} -gt 0 ]; then
                            sudo systemctl disable --now ${services[@]} &>/dev/null
                            sudo rm -f /etc/systemd/system/hysteria-*.service
                        fi
                        # Remove all other files
                        sudo rm -rf /etc/hysteria
                        sudo rm -f "$hysteria_binary"
                        sudo rm -f "$log_file"
                        (crontab -l | grep -v "# Hysteria Tunnels Auto-Restart" | crontab -)
                        sudo systemctl daemon-reload
                        echo -e "${GREEN}All Hysteria components have been removed.${RESET}"
                    fi
                    break
                    ;;
                "Back to Main Menu")
                    return
                    ;;
                *)
                    echo "Invalid option. Please try again."
                    break
                    ;;
            esac
        done
        sleep 2
    done
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
      echo -e "${CYAN}Starting Hysteria Uninstallation...${RESET}"
      uninstall_menu
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
