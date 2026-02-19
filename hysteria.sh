#!/bin/bash
set -Eeuo pipefail

############################
#        GLOBALS
############################

BASE_DIR="/etc/hysteria"
LOG_DIR="/var/log/hysteria"
SERVICE_DIR="/etc/systemd/system"
BACKUP_DIR="/etc/hysteria/backups"
MAPPING_FILE="$BASE_DIR/port_mapping.txt"

GREEN="\e[32m"; RED="\e[31m"; YELLOW="\e[33m"
BLUE="\e[34m"; CYAN="\e[36m"; MAGENTA="\e[35m"
WHITE="\e[97m"; RESET="\e[0m"

############################
#        UTILITIES
############################

color(){ echo -e "${!1}$2${RESET}"; }

pause(){ read -p "Press Enter..."; }

ensure_dirs(){
  mkdir -p "$BASE_DIR" "$LOG_DIR" "$BACKUP_DIR"
  touch "$MAPPING_FILE"
}

arch_install(){
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64) URL="https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-amd64" ;;
    aarch64) URL="https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-arm64" ;;
    armv7l) URL="https://github.com/apernet/hysteria/releases/latest/download/hysteria-linux-arm" ;;
    *) echo "Unsupported architecture"; exit 1 ;;
  esac

  if [ ! -f /usr/local/bin/hysteria ]; then
    curl -L "$URL" -o hysteria
    chmod +x hysteria
    mv hysteria /usr/local/bin/
  fi
}

get_next_id(){
  max=0
  shopt -s nullglob
  for f in $BASE_DIR/iran-config*.yaml; do
    n="${f##*iran-config}"
    n="${n%.yaml}"
    (( n > max )) && max=$n
  done
  shopt -u nullglob
  echo $((max+1))
}

############################
#      BACKUP SYSTEM
############################

backup_config(){
  ts=$(date +%F_%H-%M-%S)
  tar czf "$BACKUP_DIR/backup_$ts.tar.gz" $BASE_DIR 2>/dev/null || true
}

restore_backup(){
  ls $BACKUP_DIR
  read -p "Enter backup filename: " file
  tar xzf "$BACKUP_DIR/$file" -C /
}

############################
#      FIREWALL
############################

apply_firewall_rules(){
  ports="$1"
  for p in $(echo $ports | tr ',' ' '); do
    iptables -C INPUT -p tcp --dport $p -j ACCEPT 2>/dev/null || \
    iptables -A INPUT -p tcp --dport $p -j ACCEPT
    iptables -C INPUT -p udp --dport $p -j ACCEPT 2>/dev/null || \
    iptables -A INPUT -p udp --dport $p -j ACCEPT
  done
}

############################
#      LOG ROTATION
############################

setup_logrotate(){
cat >/etc/logrotate.d/hysteria<<EOF
$LOG_DIR/*.log $LOG_DIR/*.err {
  daily
  rotate 7
  compress
  missingok
  notifempty
}
EOF
}

############################
#      HEALTH CHECK
############################

health_check(){
while true; do
  shopt -s nullglob
  for f in $BASE_DIR/iran-config*.yaml; do
    id="${f##*iran-config}"
    id="${id%.yaml}"
    if ! systemctl is-active --quiet hysteria$id; then
      systemctl restart hysteria$id
    fi
  done
  shopt -u nullglob
  sleep 30
done
}

create_health_service(){
cat >$SERVICE_DIR/hysteria-health.service<<EOF
[Unit]
Description=Hysteria Health Check
After=network.target

[Service]
ExecStart=/bin/bash $BASE_DIR/health.sh
Restart=always

[Install]
WantedBy=multi-user.target
EOF

cat >$BASE_DIR/health.sh<<EOF
$(declare -f health_check)
health_check
EOF

chmod +x $BASE_DIR/health.sh
systemctl daemon-reload
systemctl enable --now hysteria-health
}

############################
#      LOAD BALANCER
############################

create_failover(){
read -p "Primary server: " S1
read -p "Backup server: " S2
echo "$S1,$S2" > $BASE_DIR/failover.list
}

############################
#      MONITOR
############################

monitor_tunnels(){
clear
echo "========== HYSTERIA STATUS =========="
echo

# گرفتن همه سرویس‌های hysteria
services=$(systemctl list-units --type=service --all | grep hysteria | awk '{print $1}')

if [ -z "$services" ]; then
  echo "No Hysteria services found."
  pause
  return
fi

for svc in $services; do
  name="${svc%.service}"
  status=$(systemctl is-active $name 2>/dev/null || echo "inactive")

  if [ "$name" = "hysteria" ]; then
    printf "Foreign Server     → %s\n" "$status"
  elif [[ "$name" =~ ^hysteria[0-9]+$ ]]; then
    id="${name#hysteria}"
    printf "Iran Tunnel %-5s → %s\n" "$id" "$status"
  fi
done

echo
pause
}

############################
#      IRAN SETUP FLOW
############################

iran_flow(){

echo "IP Version:"
echo "1) IPv4"
echo "2) IPv6"
read -p "Choice: " ip
[ "$ip" == "1" ] && REMOTE="0.0.0.0" || REMOTE="[::]"

echo "Usage Profile:"
echo "1) Light"
echo "2) Medium"
echo "3) Heavy"
read -p "Choice: " u

case $u in
1) QUIC="maxIncomingStreams: 4096" ;;
2) QUIC="maxIncomingStreams: 8192" ;;
3) QUIC="maxIncomingStreams: 20000" ;;
esac

read -p "Enable Obfs? [y/N]: " ob
if [[ "$ob" =~ ^[Yy]$ ]]; then
  OBFS="obfs:
  type: salamander
  salamander:
    password: __PASS__"
else
  OBFS=""
fi

id=$(get_next_id)

read -p "Foreign IP: " server
read -p "Port: " port
read -p "Password: " pass
read -p "SNI: " sni
read -p "Forward Ports (comma): " ports

TCP=""
UDP=""
for p in $(echo $ports | tr ',' ' '); do
TCP+="  - listen: 0.0.0.0:$p
    remote: '$REMOTE:$p'
"
UDP+="  - listen: 0.0.0.0:$p
    remote: '$REMOTE:$p'
"
done

[ -n "$OBFS" ] && OBFS=$(echo "$OBFS" | sed "s/__PASS__/$pass/")

cat >$BASE_DIR/iran-config$id.yaml<<EOF
server: "$server:$port"
auth: "$pass"
tls:
  sni: "$sni"
  insecure: true
$OBFS
quic:
  $QUIC
tcpForwarding:
$TCP
udpForwarding:
$UDP
EOF

cat >$SERVICE_DIR/hysteria$id.service<<EOF
[Unit]
Description=Hysteria Client $id
After=network.target

[Service]
ExecStart=/usr/local/bin/hysteria client -c $BASE_DIR/iran-config$id.yaml
Restart=always
StandardOutput=append:$LOG_DIR/hysteria$id.log
StandardError=append:$LOG_DIR/hysteria$id.err

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now hysteria$id

apply_firewall_rules "$ports"
backup_config

echo "Tunnel $id created."
pause
}

############################
#      FOREIGN SETUP
############################

foreign_setup(){
read -p "Listen Port: " port
read -p "Password: " pass

openssl req -x509 -nodes -days 3650 -newkey ed25519 \
-keyout $BASE_DIR/self.key \
-out $BASE_DIR/self.crt \
-subj "/CN=myserver"

cat >$BASE_DIR/server-config.yaml<<EOF
listen: ":$port"
tls:
  cert: $BASE_DIR/self.crt
  key: $BASE_DIR/self.key
auth:
  type: password
  password: "$pass"
EOF

cat >$SERVICE_DIR/hysteria.service<<EOF
[Unit]
Description=Hysteria Server
After=network.target

[Service]
ExecStart=/usr/local/bin/hysteria server -c $BASE_DIR/server-config.yaml
Restart=always
StandardOutput=append:$LOG_DIR/server.log
StandardError=append:$LOG_DIR/server.err

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now hysteria
backup_config
pause
}

############################
#      DELETE
############################

delete_tunnel(){
read -p "Tunnel ID: " id
systemctl stop hysteria$id 2>/dev/null || true
systemctl disable hysteria$id 2>/dev/null || true
rm -f $SERVICE_DIR/hysteria$id.service
rm -f $BASE_DIR/iran-config$id.yaml
systemctl daemon-reload
backup_config
echo "Deleted."
pause
}

############################
#      MAIN MENU
############################

main_menu(){
while true; do
clear
echo "====== HYSTERIA ADVANCED ======"
echo "1) Create Iran Tunnel"
echo "2) Setup Foreign Server"
echo "3) Monitor"
echo "4) Delete Tunnel"
echo "5) Backup Restore"
echo "6) Setup Failover"
echo "7) Exit"
read -p "Select: " opt

case $opt in
1) iran_flow ;;
2) foreign_setup ;;
3) monitor_tunnels ;;
4) delete_tunnel ;;
5) restore_backup ;;
6) create_failover ;;
7) exit 0 ;;
esac
done
}

############################
#      INIT
############################

ensure_dirs
arch_install
setup_logrotate
create_health_service
main_menu
