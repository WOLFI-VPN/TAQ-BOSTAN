#!/bin/bash
set -Eeuo pipefail
trap 'colorEcho "Script terminated prematurely." red' ERR SIGINT SIGTERM

# ------------------ Logging Function ------------------
LOG_FILE="/var/log/hysteria_script.log"
sudo touch $LOG_FILE
sudo chmod 664 $LOG_FILE

log_event() {
  local message="$1"
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $message" | sudo tee -a $LOG_FILE > /dev/null
}

# ------------------ Color Output Function ------------------
colorEcho() {
  local text="$1"
  local color="$2"
  case "$color" in
    red)     echo -e "\e[31m❌ ${text}\e[0m" ;;
    green)   echo -e "\e[32m✅ ${text}\e[0m" ;;
    yellow)  echo -e "\e[33m⚠️ ${text}\e[0m" ;;
    blue)    echo -e "\e[34mℹ️ ${text}\e[0m" ;;
    magenta) echo -e "\e[35m✨ ${text}\e[0m" ;;
    cyan)    echo -e "\e[36m➡️ ${text}\e[0m" ;;
    *)       echo "$text" ;;
  esac
}
# ------------------ draw_menu ------------------
draw_menu() {
  local title="$1"
  shift
  local options=("$@")

  local GREEN='\e[32m'
  local WHITE='\e[97m'
  local CYAN='\e[36m'
  local DIM='\e[2m'
  local RESET='\e[0m'

  clear

  local width=60
  local inner_width=$((width - 2))
  local line=$(printf "%${inner_width}s" "" | sed "s/ /═/g")

  local border_top="╔"
  local border_mid="╠"
  local border_bottom="╚"
  local border_side="║"
  local border_right="╗"
  local border_mid_right="╣"
  local border_bottom_right="╝"

  local title_length=${#title}
  local padding_left=$(( (inner_width - title_length) / 2 ))
  local padding_right=$(( inner_width - title_length - padding_left ))
  local title_line="$(printf "%${padding_left}s" "")${title}$(printf "%${padding_right}s" "")"

  echo -e "${CYAN}${border_top}${line}${border_right}${RESET}"
  echo -e "${CYAN}${border_side}${WHITE}${title_line}${CYAN}${border_side}${RESET}"
  echo -e "${CYAN}${border_mid}${line}${border_mid_right}${RESET}"

  for opt in "${options[@]}"; do
    printf "${CYAN}${border_side} ${WHITE}%-*s${CYAN} ${border_side}${RESET}\n" $((inner_width - 2)) "$opt"
  done

  echo -e "${CYAN}${border_mid}${line}${border_mid_right}${RESET}"
  printf "${CYAN}${border_side} ${DIM}Use number/letter then Enter${CYAN}%*s${border_side}${RESET}\n" $((inner_width - 30)) ""
  echo -e "${CYAN}${border_bottom}${line}${border_bottom_right}${RESET}"
  echo -ne "${WHITE}> ${RESET}"
}

# ------------------ Initialization ------------------
ARCH=$(uname -m)
HYSTERIA_VERSION_AMD64="https://github.com/apernet/hysteria/releases/download/app%2Fv2.6.1/hysteria-linux-amd64"
HYSTERIA_VERSION_ARM="https://github.com/apernet/hysteria/releases/download/app%2Fv2.6.1/hysteria-linux-arm"
HYSTERIA_VERSION_ARM64="https://github.com/apernet/hysteria/releases/download/app%2Fv2.6.1/hysteria-linux-arm64"

case "$ARCH" in
  x86_64)   DOWNLOAD_URL="$HYSTERIA_VERSION_AMD64" ;;
  armv7l|armv6l) DOWNLOAD_URL="$HYSTERIA_VERSION_ARM" ;;
  aarch64)  DOWNLOAD_URL="$HYSTERIA_VERSION_ARM64" ;;
  *)
    colorEcho "Unsupported architecture: $ARCH" red
    exit 1
    ;;
esac

if [ -f "/usr/local/bin/hysteria" ]; then
 colorEcho "Hysteria binary already exists at /usr/local/bin/hysteria. Skipping download." yellow
 else
 colorEcho "Downloading Hysteria binary for: $ARCH" cyan
 if ! curl -fsSL "$DOWNLOAD_URL" -o hysteria; then
   colorEcho "Failed to download hysteria binary." red
   exit 1
 fi
 chmod +x hysteria
 sudo mv hysteria /usr/local/bin/
 fi
sudo mkdir -p /etc/hysteria/
MAPPING_FILE="/etc/hysteria/port_mapping.txt"
if [ ! -f "$MAPPING_FILE" ]; then
  sudo touch "$MAPPING_FILE"
fi
sudo mkdir -p /var/log/hysteria/

if [ ! -f /etc/hysteria/hysteria-monitor.py ]; then
  sudo curl -fsSL https://raw.githubusercontent.com/ParsaKSH/TAQ-BOSTAN/main/hysteria-monitor.py \
    -o /etc/hysteria/hysteria-monitor.py
  sudo chmod +x /etc/hysteria/hysteria-monitor.py
fi

# ------------------ Monitor Ports Function ------------------
monitor_ports() {
  log_event "User requested to monitor ports."
  MONITOR_SCRIPT="/etc/hysteria/hysteria-monitor.py"

  if ! command -v python3 &> /dev/null; then
    colorEcho "Python 3 is not installed. Please install it to use the monitor." red
    log_event "Port monitoring failed: Python 3 not found."
    sleep 3
    return
  fi

  if [ ! -f "$MONITOR_SCRIPT" ]; then
    colorEcho "Monitor script not found at ${MONITOR_SCRIPT}." red
    log_event "Port monitoring failed: Monitor script not found."
    sleep 3
    return
  fi

  colorEcho "Starting traffic monitor... Press Ctrl+C to exit." blue
  log_event "Starting traffic monitor script."
  sleep 2
  clear
  sudo python3 "$MONITOR_SCRIPT"
  log_event "Traffic monitor stopped by user."
  colorEcho "Traffic monitor stopped." blue
  read -rp "Press Enter to return to the main menu..."
}

# ------------------ View Logs Function ------------------
view_logs() {
  while true; do
    draw_menu "Log Management" \
      "1 | View Full Log" \
      "2 | View Last 20 Lines" \
      "3 | Clear Log File" \
      "4 | Back"

    read -r LOG_CHOICE

    case "$LOG_CHOICE" in
      1)
        clear
        if [ -s "$LOG_FILE" ]; then
          sudo cat "$LOG_FILE"
          echo ""
          colorEcho "End of log file." blue
        else
          colorEcho "Log file is empty." yellow
        fi
        read -rp "Press Enter to return..."
        ;;
      2)
        clear
        if [ -s "$LOG_FILE" ]; then
          sudo tail -n 20 "$LOG_FILE"
          echo ""
          colorEcho "Showing last 20 lines." blue
        else
          colorEcho "Log file is empty." yellow
        fi
        read -rp "Press Enter to return..."
        ;;
      3)
        read -rp "Are you sure you want to clear the entire log file? [y/N]: " CONFIRM
        if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
          sudo truncate -s 0 "$LOG_FILE"
          log_event "Log file cleared by user."
          colorEcho "Log file has been cleared." green
        else
          colorEcho "Log clearing cancelled." yellow
        fi
        sleep 2
        ;;
      4)
        return
        ;;
      *)
        colorEcho "Invalid choice." red
        sleep 2
        ;;
    esac
  done
}

# ------------------ Manage Tunnels Function ------------------
manage_tunnels() {

  while true; do
    draw_menu "Manage Iranian Tunnels" \
      "1 | Edit Tunnel" \
      "2 | Delete Tunnel" \
      "3 | Back"

    read -r ACTION_CHOICE

    case "$ACTION_CHOICE" in

      1)
        # build a numbered list of existing iran tunnels from mapping file
        MAP_FILE="/etc/hysteria/port_mapping.txt"
        TUNNEL_NAMES=()
        if [ -f "$MAP_FILE" ]; then
          # Use sort -u to get unique tunnel names
          TUNNEL_NAMES=($(while IFS='|' read -r CFG_NAME SERVICE_NAME PORTS; do
            case "$CFG_NAME" in
              iran-*.yaml)
                NAME="${CFG_NAME#iran-}"
                NAME="${NAME%.yaml}"
                echo "$NAME"
                ;;
            esac
          done < "$MAP_FILE" | sort -u))
        fi

        if [ ${#TUNNEL_NAMES[@]} -eq 0 ]; then
          colorEcho "No tunnels found. You can create one from the main menu." yellow
          sleep 2
          continue
        fi

        MENU_OPTIONS=()
        INDEX=1
        for NAME in "${TUNNEL_NAMES[@]}"; do
          MENU_OPTIONS+=("$INDEX | $NAME")
          INDEX=$((INDEX + 1))
        done
        MENU_OPTIONS+=("E | Enter name manually")
        MENU_OPTIONS+=("B | Back")

        draw_menu "Select Tunnel to Edit" \
          "${MENU_OPTIONS[@]}"

        read -r TUNNEL_CHOICE

        case "$TUNNEL_CHOICE" in
          [0-9]*)
            CHOICE_INDEX=$((TUNNEL_CHOICE - 1))
            if [ "$CHOICE_INDEX" -lt 0 ] || [ "$CHOICE_INDEX" -ge "${#TUNNEL_NAMES[@]}" ]; then
              colorEcho "Invalid index." red
              sleep 2
              continue
            fi
            TUNNEL_NAME="${TUNNEL_NAMES[$CHOICE_INDEX]}"
            ;;
          [Ee])
            read -rp "Enter tunnel name (example: my-tunnel): " TUNNEL_NAME
            ;;
          [Bb])
            continue
            ;;
          *)
            colorEcho "Invalid selection." red
            sleep 2
            continue
            ;;
        esac

        CONFIG_FILE="/etc/hysteria/iran-${TUNNEL_NAME}.yaml"

        if [ ! -f "$CONFIG_FILE" ]; then
          colorEcho "Tunnel does not exist." red
          sleep 2
          continue
        fi

        log_event "Attempting to edit tunnel: ${TUNNEL_NAME}"
        echo ""
        colorEcho "Leave empty to keep current value." yellow

        CURRENT_SERVER=$(grep 'server:' "$CONFIG_FILE" | cut -d'"' -f2)
        CURRENT_AUTH=$(grep 'auth:' "$CONFIG_FILE" | cut -d'"' -f2)
        CURRENT_SNI=$(grep 'sni:' "$CONFIG_FILE" | cut -d'"' -f2)

        read -rp "Server [$CURRENT_SERVER]: " NEW_SERVER
        read -rp "Password [$CURRENT_AUTH]: " NEW_PASSWORD
        read -rp "SNI [$CURRENT_SNI]: " NEW_SNI

        [ -n "$NEW_SERVER" ] && \
          sed -i "s|server: .*|server: \"$NEW_SERVER\"|" "$CONFIG_FILE"

        [ -n "$NEW_PASSWORD" ] && \
          sed -i "s|auth: .*|auth: \"$NEW_PASSWORD\"|" "$CONFIG_FILE"

        [ -n "$NEW_SNI" ] && \
          sed -i "s|sni: .*|sni: \"$NEW_SNI\"|" "$CONFIG_FILE"

        echo ""
        read -rp "Do you want to edit forwarded ports? [y/N]: " EDIT_PORTS

        if [[ "$EDIT_PORTS" =~ ^[Yy]$ ]]; then

          read -rp "How many ports do you want to forward? " PORT_FORWARD_COUNT

          EXISTING_REMOTE_IP=$(grep -m1 "remote:" "$CONFIG_FILE" | awk -F"'" '{print $2}' | cut -d':' -f1)
          [ -z "$EXISTING_REMOTE_IP" ] && EXISTING_REMOTE_IP="0.0.0.0"

          TCP_FORWARD=""
          UDP_FORWARD=""
          PORT_LIST=""

          for (( p=1; p<=PORT_FORWARD_COUNT; p++ )); do
            read -rp "Enter port #$p: " TUNNEL_PORT

            TCP_FORWARD+="  - listen: 0.0.0.0:$TUNNEL_PORT
    remote: '$EXISTING_REMOTE_IP:$TUNNEL_PORT'
"
            UDP_FORWARD+="  - listen: 0.0.0.0:$TUNNEL_PORT
    remote: '$EXISTING_REMOTE_IP:$TUNNEL_PORT'
"

            if [ -z "$PORT_LIST" ]; then
              PORT_LIST="$TUNNEL_PORT"
            else
              PORT_LIST="$PORT_LIST,$TUNNEL_PORT"
            fi
          done

          sed -i '/^tcpForwarding:/,$d' "$CONFIG_FILE"

          cat <<EOF >> "$CONFIG_FILE"
tcpForwarding:
${TCP_FORWARD}
udpForwarding:
${UDP_FORWARD}
EOF

          # update mapping file safely
          sed -i "/^iran-${TUNNEL_NAME}\.yaml|/d" /etc/hysteria/port_mapping.txt
          echo "iran-${TUNNEL_NAME}.yaml|hysteria-${TUNNEL_NAME}|${PORT_LIST}" \
            | sudo tee -a /etc/hysteria/port_mapping.txt > /dev/null
        fi

        sudo systemctl restart "hysteria-${TUNNEL_NAME}"
        log_event "Tunnel ${TUNNEL_NAME} updated successfully."
        colorEcho "Tunnel ${TUNNEL_NAME} updated successfully." green
        sleep 2
        ;;

      2)
        # build a numbered list of existing iran tunnels from mapping file
        MAP_FILE="/etc/hysteria/port_mapping.txt"
        TUNNEL_NAMES=()
        if [ -f "$MAP_FILE" ]; then
          # Use sort -u to get unique tunnel names
          TUNNEL_NAMES=($(while IFS='|' read -r CFG_NAME SERVICE_NAME PORTS; do
            case "$CFG_NAME" in
              iran-*.yaml)
                NAME="${CFG_NAME#iran-}"
                NAME="${NAME%.yaml}"
                echo "$NAME"
                ;;
            esac
          done < "$MAP_FILE" | sort -u))
        fi

        if [ ${#TUNNEL_NAMES[@]} -eq 0 ]; then
          colorEcho "No tunnels found. You can create one from the main menu." yellow
          sleep 2
          continue
        fi

        MENU_OPTIONS=()
        INDEX=1
        for NAME in "${TUNNEL_NAMES[@]}"; do
          MENU_OPTIONS+=("$INDEX | $NAME")
          INDEX=$((INDEX + 1))
        done
        MENU_OPTIONS+=("E | Enter name manually")
        MENU_OPTIONS+=("B | Back")

        draw_menu "Select Tunnel to Delete" \
          "${MENU_OPTIONS[@]}"

        read -r TUNNEL_CHOICE

        case "$TUNNEL_CHOICE" in
          [0-9]*)
            CHOICE_INDEX=$((TUNNEL_CHOICE - 1))
            if [ "$CHOICE_INDEX" -lt 0 ] || [ "$CHOICE_INDEX" -ge "${#TUNNEL_NAMES[@]}" ]; then
              colorEcho "Invalid index." red
              sleep 2
              continue
            fi
            TUNNEL_NAME="${TUNNEL_NAMES[$CHOICE_INDEX]}"
            ;;
          [Ee])
            read -rp "Enter tunnel name to delete: " TUNNEL_NAME
            ;;
          [Bb])
            continue
            ;;
          *)
            colorEcho "Invalid selection." red
            sleep 2
            continue
            ;;
        esac

        CONFIG_FILE="/etc/hysteria/iran-${TUNNEL_NAME}.yaml"
        SERVICE_FILE="/etc/systemd/system/hysteria-${TUNNEL_NAME}.service"

        if [ ! -f "$CONFIG_FILE" ]; then
          colorEcho "Tunnel does not exist." red
          sleep 2
          continue
        fi

        log_event "Attempting to delete tunnel: ${TUNNEL_NAME}"
        read -rp "Are you sure you want to delete tunnel '${TUNNEL_NAME}'? [y/N]: " CONFIRM
        if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
          colorEcho "Deletion cancelled." yellow
          sleep 2
          continue
        fi

        sudo systemctl stop "hysteria-${TUNNEL_NAME}"
        sudo systemctl disable "hysteria-${TUNNEL_NAME}"
        sudo rm -f "$CONFIG_FILE"
        sudo rm -f "$SERVICE_FILE"
        sudo systemctl daemon-reload

        sed -i "/^iran-${TUNNEL_NAME}\.yaml|/d" /etc/hysteria/port_mapping.txt

        log_event "Tunnel ${TUNNEL_NAME} deleted."
        colorEcho "Tunnel ${TUNNEL_NAME} deleted." green
        sleep 2
        ;;

      3)
        return
        ;;

      *)
        colorEcho "Invalid choice." red
        sleep 2
        ;;
    esac
  done
}

# ------------------ Server Type Menu ------------------
while true; do
draw_menu "Server Type Selection" \
    "1 | Setup Iranian Server" \
    "2 | Setup Foreign Server" \
    "3 | Exit"
  read -r SERVER_CHOICE
  case "$SERVER_CHOICE" in
    1)
      while true; do
        draw_menu "Iranian Server Options" \
          "1 | Create New Tunnel" \
          "2 | Manage Tunnels" \
          "3 | Monitor Traffic Ports" \
          "4 | View Script Logs" \
          "5 | Exit"
        read -rp "> " IRAN_CHOICE
        case "$IRAN_CHOICE" in
          1) 
            SERVER_TYPE="iran"; break 2
            ;;
          2) 
            manage_tunnels 
            ;;
          3) 
            monitor_ports     
            ;;
          4)
            view_logs
            ;;
          5) 
            colorEcho "Exiting..." yellow; exit 0 
            ;;
          *) 
            colorEcho "Invalid selection. Please enter a valid number." red 
            ;;
        esac
      done
      ;;
    2)
      SERVER_TYPE="foreign"
      break
      ;;
    3)
      colorEcho "Exiting..." yellow
      exit 0
      ;;
    *)
      colorEcho "Invalid selection. Please enter 1, 2, or 3." red
      ;;
  esac
done

# ------------------ IP Version Menu (Only for Iran) ------------------
if [ "$SERVER_TYPE" == "iran" ]; then
  while true; do
    # Scan for existing tunnels and find the next available number using glob
  NEXT_TUNNEL=1
while [ -f "/etc/hysteria/iran-config${NEXT_TUNNEL}.yaml" ]; do
  NEXT_TUNNEL=$((NEXT_TUNNEL + 1))
done
    shopt -u nullglob
    
    colorEcho "Next available tunnel number: $NEXT_TUNNEL" cyan
    
    draw_menu "IP Version Selection" \
      "1 | IPv4" \
      "2 | IPv6" \
      "3 | Exit"
    read -r IP_VERSION_CHOICE

    case "$IP_VERSION_CHOICE" in
      1)
        REMOTE_IP="0.0.0.0"
        export NEXT_TUNNEL
        break
        ;;
      2)
        REMOTE_IP="[::]"
        export NEXT_TUNNEL
        break
        ;;
      3)
        # Return to previous menu
        continue 2
        ;;
      *)
        colorEcho "Invalid selection. Please enter 1, 2, or 3." red
        ;;
    esac
  done
fi

# ------------------ Obfuscation Option ------------------
read -p "Do you want to enable Obfuscation (obfs)? [y/N]: " ENABLE_OBFS
ENABLE_OBFS=$(echo "$ENABLE_OBFS" | tr '[:upper:]' '[:lower:]')

if [[ "$ENABLE_OBFS" == "y" || "$ENABLE_OBFS" == "yes" ]]; then
  OBFS_CONFIG=$(cat <<EOF
obfs:
  type: salamander
  salamander:
    password: "__REPLACE_PASSWORD__"
EOF
)
else
  OBFS_CONFIG=""
fi

# ------------------ QUIC Settings Based on Usage ------------------
draw_menu "Expected Simultaneous Users" \
  "1 | 1 to 50 users (Light load)" \
  "2 | 50 to 100 users (Medium load)" \
  "3 | 100 to 300 users (Heavy load)"
read -r USAGE_CHOICE

case "$USAGE_CHOICE" in
  1)
    QUIC_SETTINGS=$(cat <<EOF
quic:
  initStreamReceiveWindow: 25165824
  maxStreamReceiveWindow: 50331648
  initConnReceiveWindow: 50331648
  maxConnReceiveWindow: 100663296
  maxIdleTimeout: 15s
  keepAliveInterval: 10s
  maxIncomingStreams: 4096
  disablePathMTUDiscovery: false
EOF
)
    ;;
  2)
    QUIC_SETTINGS=$(cat <<EOF
quic:
  initStreamReceiveWindow: 50331648
  maxStreamReceiveWindow: 100663296
  initConnReceiveWindow: 100663296
  maxConnReceiveWindow: 201326592
  maxIdleTimeout: 15s
  keepAliveInterval: 10s
  maxIncomingStreams: 8192
  disablePathMTUDiscovery: false
EOF
)
    ;;
  3)
    QUIC_SETTINGS=$(cat <<EOF
quic:
  initStreamReceiveWindow: 100663296
  maxStreamReceiveWindow: 201326592
  initConnReceiveWindow: 201326592
  maxConnReceiveWindow: 402653184
  maxIdleTimeout: 15s
  keepAliveInterval: 10s
  maxIncomingStreams: 24576
  disablePathMTUDiscovery: false
EOF
)
    ;;
  *)
    echo "Invalid option. Defaulting to 1-50 users (light load)."
    QUIC_SETTINGS=$(cat <<EOF
quic:
  initStreamReceiveWindow: 25165824
  maxStreamReceiveWindow: 50331648
  initConnReceiveWindow: 50331648
  maxConnReceiveWindow: 100663296
  maxIdleTimeout: 15s
  keepAliveInterval: 10s
  maxIncomingStreams: 4096
  disablePathMTUDiscovery: false
EOF
)
    ;;
esac

# ------------------ Foreign Server Setup ------------------
if [ "$SERVER_TYPE" == "foreign" ]; then
  colorEcho "Setting up foreign server..." green

  if ! command -v openssl &> /dev/null; then
    sudo apt update -y && sudo apt install -y openssl
  fi

  colorEcho "Generating self-signed certificate..." cyan
  sudo openssl req -x509 -nodes -days 3650 -newkey ed25519 \
    -keyout /etc/hysteria/self.key \
    -out /etc/hysteria/self.crt \
    -subj "/CN=myserver"
  sudo chmod 600 /etc/hysteria/self.*

  while true; do
    read -p "Enter Hysteria port ex.(443) or (1-65535): " H_PORT
    if [[ "$H_PORT" =~ ^[0-9]+$ ]] && (( H_PORT > 0 && H_PORT < 65536 )); then
      break
    else
      colorEcho "Invalid port. Try again." red
    fi
  done

  while true; do
    read -p "Enter password: " H_PASSWORD
    if [[ -z "$H_PASSWORD" ]]; then
      colorEcho "Password cannot be empty. Please enter a valid password." red
    else
      break
    fi
  done

  cat << EOF | sudo tee /etc/hysteria/server-config.yaml > /dev/null
listen: ":$H_PORT"
tls:
  cert: /etc/hysteria/self.crt
  key: /etc/hysteria/self.key
auth:
  type: password
  password: "$H_PASSWORD"
$(echo "$OBFS_CONFIG" | sed "s/__REPLACE_PASSWORD__/$H_PASSWORD/")
$(echo "$QUIC_SETTINGS")
speedTest: true
EOF

  cat << EOF | sudo tee /etc/systemd/system/hysteria.service > /dev/null
[Unit]
Description=Hysteria2 Tunnel Service
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/hysteria server -c /etc/hysteria/server-config.yaml
Restart=always
RestartSec=5
LimitNOFILE=1048576
StandardOutput=append:/var/log/hysteria.log
StandardError=append:/var/log/hysteria.err

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable --now hysteria
  sudo systemctl reload-or-restart hysteria
  CRON_CMD='0 4 * * * /usr/bin/systemctl restart hysteria'
  TMP_FILE=$(mktemp)

  crontab -l 2>/dev/null | grep -vF "$CRON_CMD" > "$TMP_FILE" || true
  echo "$CRON_CMD" >> "$TMP_FILE"
  crontab "$TMP_FILE"
  rm -f "$TMP_FILE"

  colorEcho "Foreign server setup completed." green
fi

# ------------------ Iranian Client Setup (Create New Tunnel) ------------------
if [ "$SERVER_TYPE" == "iran" ]; then
  log_event "Starting new Iranian tunnel creation..."
  colorEcho "Creating new Iranian tunnel..." cyan

  read -p "Enter a name for this tunnel (example: my-tunnel): " TUNNEL_NAME

  read -p "Enter IP Address or Domain for Foreign server: " SERVER_ADDRESS
  read -p "Hysteria Port ex.(443): " PORT

  while true; do
    read -p "Password: " PASSWORD
    [[ -n "$PASSWORD" ]] && break
    colorEcho "Password cannot be empty." red
  done

  read -p "SNI ex.(google.com): " SNI
  read -p "How many ports do you have for forwarding? " PORT_FORWARD_COUNT

  TCP_FORWARD=""
  UDP_FORWARD=""
  FORWARDED_PORTS=""

  for (( p=1; p<=PORT_FORWARD_COUNT; p++ )); do
    read -p "Enter port number #$p you want to tunnel: " TUNNEL_PORT

    TCP_FORWARD+="  - listen: 0.0.0.0:$TUNNEL_PORT
    remote: '$REMOTE_IP:$TUNNEL_PORT'
"
    UDP_FORWARD+="  - listen: 0.0.0.0:$TUNNEL_PORT
    remote: '$REMOTE_IP:$TUNNEL_PORT'
"

    FORWARDED_PORTS="${FORWARDED_PORTS:+$FORWARDED_PORTS,}$TUNNEL_PORT"
  done

  CONFIG_FILE="/etc/hysteria/iran-${TUNNEL_NAME}.yaml"
  SERVICE_FILE="/etc/systemd/system/hysteria-${TUNNEL_NAME}.service"

  cat <<EOF | sudo tee "$CONFIG_FILE" > /dev/null
server: "$SERVER_ADDRESS:$PORT"
auth: "$PASSWORD"
tls:
  sni: "$SNI"
  insecure: true
$(echo "$OBFS_CONFIG" | sed "s/__REPLACE_PASSWORD__/$PASSWORD/")
$(echo "$QUIC_SETTINGS")
tcpForwarding:
$TCP_FORWARD
udpForwarding:
$UDP_FORWARD
EOF

  cat <<EOF | sudo tee "$SERVICE_FILE" > /dev/null
[Unit]
Description=Hysteria2 Client $TUNNEL_NAME
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/hysteria client -c "$CONFIG_FILE"
Restart=always
RestartSec=5
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl daemon-reload
  sudo systemctl enable --now hysteria-"${TUNNEL_NAME}"

  echo "iran-${TUNNEL_NAME}.yaml|hysteria-${TUNNEL_NAME}|${FORWARDED_PORTS}" \
    | sudo tee -a "$MAPPING_FILE" > /dev/null

  log_event "Tunnel ${TUNNEL_NAME} setup completed."
  colorEcho "Tunnel ${TUNNEL_NAME} setup completed." green
fi
