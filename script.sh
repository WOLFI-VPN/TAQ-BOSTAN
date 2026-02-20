#!/bin/bash
############################################################
#                  WOLFI VPN FULL SCRIPT                  #
#        All-in-One Manager + GitHub Raw Downloader       #
#  - Downloads hysteria.sh from your GitHub (raw)        #
#  - Install / Reinstall / Update                         #
#  - BBR Enable                                           #
#  - Firewall Auto Open                                   #
#  - SpeedTest                                            #
#  - QR Code                                              #
#  - Backup / Restore                                     #
#  - Service Manager                                      #
############################################################

### ====== CONFIG ====== ###
REPO_BASE="https://raw.githubusercontent.com/WOLFI-VPN/TAQ-BOSTAN/main"
INSTALL_DIR="/opt/wolfi"
MAIN_FILE="$INSTALL_DIR/hysteria.sh"
CONFIG_DIR="/etc/hysteria"
CONFIG_FILE="$CONFIG_DIR/config.yaml"
SERVICE_FILE="/etc/systemd/system/hysteria.service"
HYSTERIA_BIN="/usr/local/bin/hysteria"
BACKUP_DIR="/opt/wolfi/backups"
LOG_FILE="/opt/wolfi/install.log"

### ====== COLORS ====== ###
green(){ echo -e "\e[32m$1\e[0m"; }
red(){ echo -e "\e[31m$1\e[0m"; }
yellow(){ echo -e "\e[33m$1\e[0m"; }
blue(){ echo -e "\e[36m$1\e[0m"; }

log(){
echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> $LOG_FILE
}

check_root(){
if [ "$EUID" -ne 0 ]; then
red "Run as root!"
exit 1
fi
}

prepare_dirs(){
mkdir -p $INSTALL_DIR
mkdir -p $BACKUP_DIR
}

detect_os(){
if [ -f /etc/debian_version ]; then
PKG_UPDATE="apt update -y"
PKG_INSTALL="apt install -y"
elif [ -f /etc/redhat-release ]; then
PKG_UPDATE="yum update -y"
PKG_INSTALL="yum install -y"
else
red "Unsupported OS"
exit 1
fi
}

install_deps(){
$PKG_UPDATE
$PKG_INSTALL curl wget unzip openssl qrencode bc tar
}

enable_bbr(){
if ! sysctl net.ipv4.tcp_congestion_control | grep -q bbr; then
echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
sysctl -p
green "BBR Enabled"
else
yellow "BBR Already Active"
fi
}

download_main(){
blue "Downloading hysteria.sh from GitHub..."
curl -fSL $REPO_BASE/hysteria.sh -o $MAIN_FILE
if [ $? -ne 0 ]; then
red "Download failed. Check if repo is PUBLIC."
exit 1
fi
chmod +x $MAIN_FILE
green "Download successful."
}

run_main(){
bash $MAIN_FILE
}

open_firewall(){
if command -v ufw &> /dev/null; then
ufw allow 443/tcp
ufw allow 443/udp
elif command -v firewall-cmd &> /dev/null; then
firewall-cmd --permanent --add-port=443/tcp
firewall-cmd --permanent --add-port=443/udp
firewall-cmd --reload
fi
}

show_status(){
echo "------ Service Status ------"
systemctl status hysteria --no-pager
}

restart_service(){
systemctl restart hysteria
green "Service restarted."
}

stop_service(){
systemctl stop hysteria
red "Service stopped."
}

enable_service(){
systemctl enable hysteria
}

disable_service(){
systemctl disable hysteria
}

uninstall_all(){
systemctl stop hysteria 2>/dev/null
systemctl disable hysteria 2>/dev/null
rm -rf $CONFIG_DIR
rm -f $SERVICE_FILE
rm -f $HYSTERIA_BIN
rm -rf $INSTALL_DIR
systemctl daemon-reload
green "Completely removed."
}

speed_test(){
if ! command -v speedtest &> /dev/null; then
curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | bash 2>/dev/null
$PKG_INSTALL speedtest 2>/dev/null
fi
speedtest --accept-license --accept-gdpr
}

system_stats(){
echo "CPU:"
top -bn1 | grep "Cpu(s)"
echo ""
echo "RAM:"
free -h
echo ""
echo "Disk:"
df -h
}

backup_config(){
DATE=$(date +%Y%m%d-%H%M%S)
tar -czf $BACKUP_DIR/backup-$DATE.tar.gz $CONFIG_DIR 2>/dev/null
green "Backup saved: backup-$DATE.tar.gz"
}

restore_backup(){
echo "Available backups:"
ls $BACKUP_DIR
read -p "Enter backup file name: " FILE
tar -xzf $BACKUP_DIR/$FILE -C /
green "Restored."
systemctl restart hysteria
}

update_script(){
blue "Updating from GitHub..."
bash <(curl -s $REPO_BASE/script.sh)
}

show_client(){
SERVER_IP=$(curl -s https://api.ipify.org)
if [ -f $CONFIG_FILE ]; then
PASSWORD=$(grep password $CONFIG_FILE | awk '{print $2}')
PORT=$(grep listen $CONFIG_FILE | awk -F: '{print $2}')
LINK="hysteria2://$PASSWORD@$SERVER_IP:$PORT/?sni=$SERVER_IP&insecure=1#WOLFI"
echo ""
green "Client Link:"
echo $LINK
echo ""
qrencode -t ANSIUTF8 "$LINK"
else
red "Config not found."
fi
}

header(){
clear
echo "=================================================="
echo "               WOLFI VPN FULL PANEL              "
echo "=================================================="
}

menu(){
header
echo "1) Download & Install (from GitHub)"
echo "2) Reinstall from GitHub"
echo "3) Show Client Link"
echo "4) Restart Service"
echo "5) Stop Service"
echo "6) Service Status"
echo "7) Enable BBR"
echo "8) Open Firewall"
echo "9) Speed Test"
echo "10) System Stats"
echo "11) Backup Config"
echo "12) Restore Backup"
echo "13) Update Script"
echo "14) Uninstall Everything"
echo "0) Exit"
echo "=================================================="
read -p "Select: " opt

case $opt in
1)
check_root
prepare_dirs
detect_os
install_deps
download_main
run_main
;;
2)
download_main
run_main
;;
3) show_client ;;
4) restart_service ;;
5) stop_service ;;
6) show_status ;;
7) enable_bbr ;;
8) open_firewall ;;
9) speed_test ;;
10) system_stats ;;
11) backup_config ;;
12) restore_backup ;;
13) update_script ;;
14) uninstall_all ;;
0) exit ;;
*) echo "Invalid"; sleep 1 ;;
esac

read -p "Press Enter to continue..."
menu
}

menu
