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

# ------------------ Port-in-Use Check Function ------------------
is_port_in_use() {
  local port="$1"
  if sudo ss -tuln | grep -q ":$port "; then
    return 0 # Port is in use
  else
    return 1 # Port is not in use
  fi
}

# ------------------ Check Service Status Function ------------------
check_service_status() {
  local service_name="$1"
  if systemctl is-active --quiet "$service_name"; then
    log_event "Service '$service_name' is active and running."
    colorEcho "Service '$service_name' is active." green
  else
    log_event "Service '$service_name' failed to start or is inactive. Check logs with 'journalctl -u $service_name'."
    colorEcho "Service '$service_name' is not running. Please check the logs." red
  fi
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

# ------------------ View Logs Function ------------------
view_logs() {
  while true; do
    local log_menu_options=(
      "1 | View Full Log"
      "2 | View Last 20 Lines"
      "3 | Clear Log File"
      "4 | Back"
    )
    draw_menu "Log Management" "${log_menu_options[@]}"

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

# ------------------ Restart Management Function ------------------
restart_management_menu() {
  while true; do
    # Get current cron time for display
    CRON_COMMENT="# Hysteria Tunnels Auto-Restart"
    CURRENT_CRON=$(crontab -l 2>/dev/null | grep "$CRON_COMMENT" || echo "Not Set")
    if [[ "$CURRENT_CRON" != "Not Set" ]]; then
      CURRENT_CRON_TIME=$(echo "$CURRENT_CRON" | awk '{print $2 ":" $1}')
      CRON_DISPLAY="Daily Auto-Restart Time: ${CURRENT_CRON_TIME}"
    else
      CRON_DISPLAY="Daily Auto-Restart is Not Set"
    fi

    local menu_options=(
      "1 | Manually Restart a Tunnel"
      "2 | Manually Restart All Tunnels"
      "3 | Set/Update Daily Auto-Restart"
      "  | ($CRON_DISPLAY)"
      "4 | Back"
    )
    draw_menu "Restart Management" "${menu_options[@]}"

    read -r RESTART_CHOICE

    case "$RESTART_CHOICE" in
      1) # Manually Restart a Tunnel
        log_event "Manual restart: selecting a single tunnel."
        MAP_FILE="/etc/hysteria/port_mapping.txt"
        TUNNEL_NAMES=()
        if [ -f "$MAP_FILE" ]; then
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
          colorEcho "No tunnels found to restart." yellow
          sleep 2
          continue
        fi

        MENU_OPTIONS=()
        INDEX=1
        for NAME in "${TUNNEL_NAMES[@]}"; do
          MENU_OPTIONS+=("$INDEX | $NAME")
          INDEX=$((INDEX + 1))
        done
        MENU_OPTIONS+=("B | Back")

        draw_menu "Select Tunnel to Restart" "${MENU_OPTIONS[@]}"
        read -r TUNNEL_CHOICE

        if [[ "$TUNNEL_CHOICE" =~ ^[Bb]$ ]]; then
          continue
        fi

        if [[ "$TUNNEL_CHOICE" =~ ^[0-9]+$ ]]; then
            CHOICE_INDEX=$((TUNNEL_CHOICE - 1))
            if [ "$CHOICE_INDEX" -lt 0 ] || [ "$CHOICE_INDEX" -ge "${#TUNNEL_NAMES[@]}" ]; then
              colorEcho "Invalid index." red
              sleep 2
              continue
            fi
            TUNNEL_NAME="${TUNNEL_NAMES[$CHOICE_INDEX]}"
            colorEcho "Restarting tunnel '${TUNNEL_NAME}'..." blue
            log_event "Manually restarting tunnel: ${TUNNEL_NAME}."
            sudo systemctl restart "hysteria-${TUNNEL_NAME}.service"
            check_service_status "hysteria-${TUNNEL_NAME}.service"
            sleep 2
        else
            colorEcho "Invalid selection." red
            sleep 2
        fi
        ;;

      2) # Manually Restart All Tunnels
        log_event "Manual restart: restarting all tunnels."
        colorEcho "Restarting all tunnels..." blue
        
        SERVICES_TO_RESTART=$(systemctl list-unit-files --type=service | grep 'hysteria-.*\.service' | awk '{print $1}')
        
        if [ -z "$SERVICES_TO_RESTART" ]; then
            colorEcho "No Hysteria tunnel services found to restart." yellow
            log_event "Manual restart all: No services found."
        else
            RESTARTED_COUNT=0
            for SERVICE in $SERVICES_TO_RESTART; do
                # We only want to restart client tunnels, not the main server if it exists
                if [[ "$SERVICE" == "hysteria.service" ]]; then
                  continue
                fi
                sudo systemctl restart "$SERVICE"
                check_service_status "$SERVICE"
                RESTARTED_COUNT=$((RESTARTED_COUNT + 1))
            done
            
            if [ "$RESTARTED_COUNT" -eq 0 ]; then
              colorEcho "No active client tunnels found to restart." yellow
            else
              colorEcho "All active tunnels have been restarted." green
            fi
            log_event "Manual restart all tunnels complete. ${RESTARTED_COUNT} tunnels restarted."
        fi
        sleep 3
        ;;

      3) # Set/Update Auto-Restart
        while true; do
          local cron_menu_options=(
            "1 | Restart Every 6 Hours"
            "2 | Restart Every 12 Hours"
            "3 | Restart Every 24 Hours (at 4:00 AM)"
            "4 | Custom Daily Restart Time"
            "5 | Remove Auto-Restart"
            "6 | Back"
          )
          draw_menu "Auto-Restart Schedule" "${cron_menu_options[@]}"

          read -r CRON_CHOICE

          local CRON_JOB=""
          local SUCCESS_MSG=""

          case "$CRON_CHOICE" in
            1) # Every 6 hours
              CRON_JOB="0 */6 * * *"
              SUCCESS_MSG="Auto-restart set to every 6 hours."
              ;;
            2) # Every 12 hours
              CRON_JOB="0 */12 * * *"
              SUCCESS_MSG="Auto-restart set to every 12 hours."
              ;;
            3) # Every 24 hours
              CRON_JOB="0 4 * * *"
              SUCCESS_MSG="Auto-restart set to every 24 hours at 4:00 AM."
              ;;
            4) # Custom Time
              log_event "User is setting a custom auto-restart cronjob."
              colorEcho "Enter the time in 24-hour format." yellow
              read -rp "Enter hour (0-23): " CRON_HOUR
              read -rp "دقیقه را وارد کنید (0-59): " CRON_MINUTE

              if ! [[ "$CRON_HOUR" =~ ^[0-9]+$ ]] || [ "$CRON_HOUR" -lt 0 ] || [ "$CRON_HOUR" -gt 23 ] || \
                 ! [[ "$CRON_MINUTE" =~ ^[0-9]+$ ]] || [ "$CRON_MINUTE" -lt 0 ] || [ "$CRON_MINUTE" -gt 59 ]; then
                colorEcho "Invalid hour or minute." red
                log_event "Cronjob setup failed: Invalid custom time input."
                sleep 2
                continue
              fi
              CRON_JOB="$CRON_MINUTE $CRON_HOUR * * *"
              SUCCESS_MSG="Auto-restart time set to ${CRON_HOUR}:${CRON_MINUTE} daily."
              ;;
            5) # Remove
              (crontab -l 2>/dev/null | grep -v "$CRON_COMMENT") | crontab -
              colorEcho "Daily auto-restart has been removed." green
              log_event "Cronjob for auto-restart removed."
              sleep 2
              break # Exit the cron menu
              ;;
            6) # Back
              break # Exit the cron menu
              ;;
            *)
              colorEcho "Invalid choice." red
              sleep 2
              continue
              ;;
          esac

          if [ -n "$CRON_JOB" ]; then
            CRON_CMD_TO_RUN="systemctl restart \\\$(systemctl list-unit-files --type=service | grep 'hysteria-.*\\\\.service' | awk '{print \\\$1}' | grep -v 'hysteria.service')"
            FULL_CRON_JOB="$CRON_JOB $CRON_CMD_TO_RUN $CRON_COMMENT"
            (crontab -l 2>/dev/null | grep -v "$CRON_COMMENT" ; echo "$FULL_CRON_JOB") | crontab -
            colorEcho "$SUCCESS_MSG" green
            log_event "$SUCCESS_MSG"
            sleep 2
          fi
        done
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

# ------------------ تابع پشتیبان‌گیری و بازیابی ------------------
# عملکرد: منویی برای ایجاد فایل پشتیبان از کانفیگ‌ها و بازیابی آن‌ها نمایش می‌دهد.
backup_restore_menu() {
  local BACKUP_DIR="/root/hysteria_backups"
  sudo mkdir -p "$BACKUP_DIR"

  while true; do
    local backup_menu_options=(
      "1 | Create Backup"
      "2 | Restore from Backup"
      "3 | Back to Previous Menu"
    )
    draw_menu "Backup & Restore Management" "${backup_menu_options[@]}"
    read -rp "Select an option: " BACKUP_CHOICE

    case "$BACKUP_CHOICE" in
      1) # Create Backup
        log_event "User started creating a backup."
        local TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
        local BACKUP_FILE="${BACKUP_DIR}/hysteria_backup_${TIMESTAMP}.tar.gz"
        
        colorEcho "Creating backup..." blue
        if sudo tar -czf "$BACKUP_FILE" -C /etc hysteria; then
          colorEcho "✅ Backup created successfully at: ${BACKUP_FILE}" green
          log_event "Backup created: ${BACKUP_FILE}"
        else
          colorEcho "❌ Failed to create backup." red
          log_event "Backup creation failed."
        fi
        read -rp "Press Enter to continue..."
        ;;
      2) # Restore from Backup
        log_event "User started restoring from a backup."
        mapfile -t backups < <(sudo find "$BACKUP_DIR" -name "hysteria_backup_*.tar.gz" -printf "%f\n" | sort -r)

        if [ ${#backups[@]} -eq 0 ]; then
          colorEcho "No backup files found in ${BACKUP_DIR}." yellow
          sleep 2
          continue
        fi

        colorEcho "Available backups:" blue
        select backup_file in "${backups[@]}" "Cancel"; do
          if [[ "$REPLY" == "$((${#backups[@]} + 1))" ]] || [[ "$backup_file" == "Cancel" ]]; then
            colorEcho "Restore operation cancelled." yellow
            break
          elif [ -n "$backup_file" ]; then
            local FULL_BACKUP_PATH="${BACKUP_DIR}/${backup_file}"
            colorEcho "You are about to restore from: ${backup_file}" yellow
            colorEcho "WARNING: This will overwrite all current Hysteria configurations!" red
            read -rp "Are you absolutely sure? [y/N]: " CONFIRM

            if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
              log_event "User confirmed to restore from ${backup_file}."
              colorEcho "Restoring backup..." blue
              # Restore to a temporary directory first to be safe
              local TEMP_RESTORE_DIR=$(mktemp -d)
              if sudo tar -xzf "$FULL_BACKUP_PATH" -C "$TEMP_RESTORE_DIR"; then
                # Now copy the files over
                sudo rsync -av --delete "${TEMP_RESTORE_DIR}/hysteria/" /etc/hysteria/
                sudo rm -rf "$TEMP_RESTORE_DIR"
                colorEcho "✅ Restore completed successfully." green
                colorEcho "Please restart tunnels manually for changes to take effect." yellow
                log_event "Restore from ${backup_file} completed."
                sudo systemctl daemon-reload
              else
                colorEcho "❌ Failed to restore backup." red
                log_event "Restore from ${backup_file} failed."
                sudo rm -rf "$TEMP_RESTORE_DIR"
              fi
            else
              colorEcho "Restore operation cancelled." yellow
              log_event "User cancelled the restore operation."
            fi
            read -rp "Press Enter to continue..."
            break
          else
            colorEcho "Invalid selection. Please try again." red
          fi
        done
        ;;
      3) # Back
        break
        ;;
      *)
        colorEcho "Invalid option. Please try again." red
        sleep 1
        ;;
    esac
  done
}

# ------------------ View Tunnel Details Function ------------------
view_tunnel_details() {
  log_event "User is viewing tunnel details."
  MAP_FILE="/etc/hysteria/port_mapping.txt"
  TUNNEL_NAMES=()
  if [ -f "$MAP_FILE" ]; then
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
    colorEcho "No tunnels found to view." yellow
    sleep 2
    return
  fi

  MENU_OPTIONS=()
  INDEX=1
  for NAME in "${TUNNEL_NAMES[@]}"; do
    MENU_OPTIONS+=("$INDEX | $NAME")
    INDEX=$((INDEX + 1))
  done
  MENU_OPTIONS+=("B | Back")

  draw_menu "Select Tunnel to View" "${MENU_OPTIONS[@]}"
  read -r TUNNEL_CHOICE

  if [[ "$TUNNEL_CHOICE" =~ ^[Bb]$ ]]; then
    return
  fi

  if [[ "$TUNNEL_CHOICE" =~ ^[0-9]+$ ]]; then
      CHOICE_INDEX=$((TUNNEL_CHOICE - 1))
      if [ "$CHOICE_INDEX" -lt 0 ] || [ "$CHOICE_INDEX" -ge "${#TUNNEL_NAMES[@]}" ]; then
        colorEcho "Invalid index." red
        sleep 2
        return
      fi
      TUNNEL_NAME="${TUNNEL_NAMES[$CHOICE_INDEX]}"
  else
      colorEcho "Invalid selection." red
      sleep 2
      return
  fi

  CONFIG_FILE="/etc/hysteria/iran-${TUNNEL_NAME}.yaml"

  if [ ! -f "$CONFIG_FILE" ]; then
    colorEcho "Config file for '${TUNNEL_NAME}' not found." red
    sleep 2
    return
  fi

  clear
  colorEcho "Details for tunnel: ${TUNNEL_NAME}" magenta
  echo "-------------------------------------"
  
  SERVER=$(grep 'server:' "$CONFIG_FILE" | awk -F'\"' '{print $2}')
  AUTH=$(grep 'auth:' "$CONFIG_FILE" | awk -F'\"' '{print $2}')
  SNI=$(grep 'sni:' "$CONFIG_FILE" | awk -F'\"' '{print $2}')
  PORTS=$(grep -oP 'listen: 0.0.0.0:\K[0-9]+' "$CONFIG_FILE" | tr '\n' ',' | sed 's/,$//')

  echo "Server: $SERVER"
  echo "Password: $AUTH"
  echo "SNI: $SNI"
  echo "Forwarded Ports: $PORTS"
  
  echo "-------------------------------------"
  read -rp "Press Enter to return..."
}

# ------------------ تابع نمایش وضعیت پیشرفته ------------------
# عملکرد: وضعیت دقیق هر تونل شامل وضعیت سرویس، مصرف منابع و لاگ‌ها را نمایش می‌دهد.
view_advanced_status() {
  colorEcho "This feature is under development." yellow
  sleep 2
}

# ------------------ Manage Tunnels Function ------------------
manage_tunnels() {

  while true; do
    local manage_menu_options=(
      "1 | View Tunnel Details"
      "2 | Edit Tunnel"
      "3 | Delete Tunnel"
      "4 | Back"
    )
    draw_menu "Manage Iranian Tunnels" "${manage_menu_options[@]}"

    read -r ACTION_CHOICE

    case "$ACTION_CHOICE" in
      1)
        view_tunnel_details
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
            read -rp "نام تونل را وارد کنید (مثال: my-tunnel): " TUNNEL_NAME
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

        CURRENT_SERVER=$(grep 'server:' "$CONFIG_FILE" | cut -d'\"' -f2)
        CURRENT_AUTH=$(grep 'auth:' "$CONFIG_FILE" | cut -d'\"' -f2)
        CURRENT_SNI=$(grep 'sni:' "$CONFIG_FILE" | cut -d'\"' -f2)

        read -rp "سرور [$CURRENT_SERVER]: " NEW_SERVER
        read -rp "رمز عبور [$CURRENT_AUTH]: " NEW_PASSWORD
        read -rp "SNI [$CURRENT_SNI]: " NEW_SNI

        [ -n "$NEW_SERVER" ] && \
          sed -i "s|server: .*|server: \"$NEW_SERVER\"|" "$CONFIG_FILE"

        [ -n "$NEW_PASSWORD" ] && \
          sed -i "s|auth: .*|auth: \"$NEW_PASSWORD\"|" "$CONFIG_FILE"

        [ -n "$NEW_SNI" ] && \
          sed -i "s|sni: .*|sni: \"$NEW_SNI\"|" "$CONFIG_FILE"

        echo ""
        read -rp "آیا می‌خواهید پورت‌های فوروارد شده را ویرایش کنید؟ [y/N]: " EDIT_PORTS

        if [[ "$EDIT_PORTS" =~ ^[Yy]$ ]]; then

          read -rp "چه تعداد پورت می‌خواهید فوروارد کنید؟ " PORT_FORWARD_COUNT

          EXISTING_REMOTE_IP=$(grep -m1 "remote:" "$CONFIG_FILE" | awk -F"'" '{print $2}' | cut -d':' -f1)
          [ -z "$EXISTING_REMOTE_IP" ] && EXISTING_REMOTE_IP="0.0.0.0"

          TCP_FORWARD=""
          UDP_FORWARD=""
          PORT_LIST=""

          for (( p=1; p<=PORT_FORWARD_COUNT; p++ )); do
            read -rp "پورت شماره #$p را وارد کنید: " TUNNEL_PORT

            # Check if port is in use
            if is_port_in_use "$TUNNEL_PORT"; then
              colorEcho "Port $TUNNEL_PORT is already in use. Please choose a different port." red
              log_event "Port conflict detected for port $TUNNEL_PORT during tunnel creation."
              p=$((p - 1)) # Ask for the same port number again
              continue
            fi

            TCP_FORWARD+="  - listen: 0.0.0.0:$TUNNEL_PORT\n    remote: '$EXISTING_REMOTE_IP:$TUNNEL_PORT'\n"
            UDP_FORWARD+="  - listen: 0.0.0.0:$TUNNEL_PORT\n    remote: '$EXISTING_REMOTE_IP:$TUNNEL_PORT'\n"

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

        sudo systemctl restart "hysteria-${TUNNEL_NAME}.service"
        log_event "Tunnel ${TUNNEL_NAME} updated successfully."
        colorEcho "Tunnel ${TUNNEL_NAME} updated successfully." green
        check_service_status "hysteria-${TUNNEL_NAME}.service"
        sleep 2
        ;;

      3)
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
          colorEcho "No tunnels found to delete." yellow
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

        read -rp "آیا از حذف تونل '${TUNNEL_NAME}' مطمئن هستید؟ [y/N]: " CONFIRM

        if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
          log_event "User confirmed deletion of tunnel: ${TUNNEL_NAME}"
          sudo systemctl stop "hysteria-${TUNNEL_NAME}.service"
          sudo systemctl disable "hysteria-${TUNNEL_NAME}.service"
          sudo rm "/etc/systemd/system/hysteria-${TUNNEL_NAME}.service"
          sudo rm "/etc/hysteria/iran-${TUNNEL_NAME}.yaml"
          
          # Use sed's in-place editing with a backup for safety, and handle the delimiter
          sudo sed -i.bak -e "/^iran-${TUNNEL_NAME}\.yaml|/d" /etc/hysteria/port_mapping.txt

          sudo systemctl daemon-reload
          log_event "Tunnel ${TUNNEL_NAME} deleted successfully."
          colorEcho "Tunnel ${TUNNEL_NAME} deleted successfully." green
        else
          log_event "User cancelled deletion of tunnel: ${TUNNEL_NAME}"
          colorEcho "Deletion cancelled." yellow
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

# ------------------ Main Logic ------------------
main() {
  # Initialization
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

  # Main Menu Loop
  while true; do
    local main_menu_options=(
      "1 | Setup Iranian Server"
      "2 | Setup Foreign Server"
      "3 | Exit"
    )
    draw_menu "Server Type Selection" "${main_menu_options[@]}"
    read -rp "> " SERVER_TYPE

    case "$SERVER_TYPE" in
      1)
        # Iranian Server Menu
        while true; do
          local iran_menu_options=(
            "1 | Create New Tunnel"
            "2 | Manage Tunnels"
            "3 | View Script Logs"
            "4 | Restart Management"
            "5 | Backup & Restore"
            "6 | Back to Main Menu"
          )
          draw_menu "Iranian Server Options" "${iran_menu_options[@]}"
          read -rp "> " IRAN_CHOICE

          case "$IRAN_CHOICE" in
            1) # Create New Tunnel
              log_event "User selected to create a new tunnel."
              read -rp "Enter a name for the tunnel (e.g., my-tunnel): " TUNNEL_NAME

              if [ -f "/etc/hysteria/iran-${TUNNEL_NAME}.yaml" ]; then
                colorEcho "A tunnel with this name already exists." red
                sleep 2
                continue
              fi

              read -rp "آدرس سرور را وارد کنید (IP یا دامنه): " SERVER_ADDR
              read -rp "رمز عبور را وارد کنید: " PASSWORD
              read -rp "Enter SNI (Server Name Indication, google.com): " SNI
              read -rp "How many ports do you want to forward? " PORT_FORWARD_COUNT

              TCP_FORWARD=""
              UDP_FORWARD=""
              PORT_LIST=""

              for (( p=1; p<=PORT_FORWARD_COUNT; p++ )); do
                read -rp "پورت شماره #$p را وارد کنید: " TUNNEL_PORT
                
                if is_port_in_use "$TUNNEL_PORT"; then
                  colorEcho "Port $TUNNEL_PORT is already in use. Please choose a different port." red
                  log_event "Port conflict detected for port $TUNNEL_PORT during tunnel creation."
                  p=$((p - 1)) # Ask for the same port number again
                  continue
                fi

                TCP_FORWARD+="  - listen: 0.0.0.0:$TUNNEL_PORT\n    remote: '0.0.0.0:$TUNNEL_PORT'\n"
                UDP_FORWARD+="  - listen: 0.0.0.0:$TUNNEL_PORT\n    remote: '0.0.0.0:$TUNNEL_PORT'\n"

                if [ -z "$PORT_LIST" ]; then
                  PORT_LIST="$TUNNEL_PORT"
                else
                  PORT_LIST="$PORT_LIST,$TUNNEL_PORT"
                fi
              done

              CONFIG_FILE="/etc/hysteria/iran-${TUNNEL_NAME}.yaml"
              SERVICE_FILE="/etc/systemd/system/hysteria-${TUNNEL_NAME}.service"

              cat <<EOF | sudo tee "$CONFIG_FILE" > /dev/null
server: "$SERVER_ADDR"
auth: "$PASSWORD"
sni: "$SNI"
tcpForwarding:
${TCP_FORWARD}
udpForwarding:
${UDP_FORWARD}
EOF

              cat <<EOF | sudo tee "$SERVICE_FILE" > /dev/null
[Unit]
Description=Hysteria Tunnel (iran-${TUNNEL_NAME})
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/hysteria -c ${CONFIG_FILE} client
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

              echo "iran-${TUNNEL_NAME}.yaml|hysteria-${TUNNEL_NAME}|${PORT_LIST}" \
                | sudo tee -a /etc/hysteria/port_mapping.txt > /dev/null

              sudo systemctl daemon-reload
              sudo systemctl enable "hysteria-${TUNNEL_NAME}.service"
              sudo systemctl start "hysteria-${TUNNEL_NAME}.service"

              log_event "Tunnel '${TUNNEL_NAME}' created and started successfully."
              colorEcho "Tunnel '${TUNNEL_NAME}' created and started successfully." green
              check_service_status "hysteria-${TUNNEL_NAME}.service"
              sleep 2
              ;;
            2) # Manage Tunnels
              manage_tunnels
              ;;
            3) # View Logs
              view_logs
              ;;
            4) # Restart Management
              restart_management_menu
              ;;
            5) # Backup & Restore
              backup_restore_menu
              ;;
            6) # Back to Main Menu
              break
              ;;
            *)
              colorEcho "Invalid choice." red
              sleep 2
              ;;
          esac
        done
        ;;
      2) # Foreign Server
        # Foreign Server Setup
        log_event "User selected to set up a foreign server."
        colorEcho "در حال راه اندازی سرور Hysteria در سرور خارج." blue

        # Check if a server config already exists
        if [ -f "/etc/hysteria/kharej-server.yaml" ]; then
          colorEcho "یک فایل کانفیگ برای سرور خارج از قبل وجود دارد." yellow
          read -rp "آیا می‌خواهید آن را بازنویسی کنید؟ [y/N]: " OVERWRITE
          if [[ ! "$OVERWRITE" =~ ^[Yy]$ ]]; then
            colorEcho "راه اندازی لغو شد." yellow
            sleep 2
            continue
          fi
          log_event "User chose to overwrite existing foreign server config."
        fi

        read -rp "نام دامنه برای این سرور را وارد کنید (برای گواهی TLS): " SERVER_DOMAIN
        read -rp "رمز عبور برای سرور را وارد کنید: " SERVER_PASSWORD
        read -rp "پورتی که سرور روی آن گوش دهد را وارد کنید (مثال: 443): " SERVER_PORT

        if is_port_in_use "$SERVER_PORT"; then
          colorEcho "پورت $SERVER_PORT در حال استفاده است. لطفا پورت دیگری انتخاب کنید." red
          log_event "Port conflict detected for port $SERVER_PORT during foreign server setup."
          sleep 2
          continue
        fi

        CONFIG_FILE="/etc/hysteria/kharej-server.yaml"
        SERVICE_FILE="/etc/systemd/system/hysteria-server.service"

        # Create server config
        cat <<EOF | sudo tee "$CONFIG_FILE" > /dev/null
listen: :${SERVER_PORT}

acme:
  domains:
    - ${SERVER_DOMAIN}
  email: your-email@example.com # User should change this

auth:
  type: string
  string: "${SERVER_PASSWORD}"
EOF

        # Create systemd service
        cat <<EOF | sudo tee "$SERVICE_FILE" > /dev/null
[Unit]
Description=Hysteria Server
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/hysteria -c ${CONFIG_FILE} server
Restart=always
RestartSec=5
LimitNPROC=512
LimitNOFILE=1048576

[Install]
WantedBy=multi-user.target
EOF

        colorEcho "لطفا فایل ${CONFIG_FILE} را ویرایش کرده و 'your-email@example.com' را با ایمیل واقعی خود برای ACME جایگزین کنید." yellow
        log_event "User prompted to edit email in server config."

        sudo systemctl daemon-reload
        sudo systemctl enable hysteria-server.service
        sudo systemctl start hysteria-server.service

        log_event "Hysteria server setup complete. Service started."
        colorEcho "راه اندازی سرور Hysteria کامل شد و سرویس شروع به کار کرد." green
        check_service_status "hysteria-server.service"

        echo "-------------------------------------"
        colorEcho "مشخصات سرور:" magenta
        echo "دامنه/IP: ${SERVER_DOMAIN}"
        echo "پورت: ${SERVER_PORT}"
        echo "رمز عبور: ${SERVER_PASSWORD}"
        echo "-------------------------------------"
        read -rp "برای بازگشت به منوی اصلی، Enter را فشار دهید..."
        ;;
      3) # Exit
        colorEcho "Exiting script." blue
        exit 0
        ;;
      *)
        colorEcho "Invalid choice." red
        sleep 2
        ;;
    esac
  done
}

# ------------------ Script Entry Point ------------------
main
