#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "missing required command: $1" >&2
    exit 1
  }
}

prompt_default() {
  local prompt="$1"
  local def="$2"
  local input
  read -r -p "$prompt [$def]: " input
  if [[ -z "$input" ]]; then
    echo "$def"
  else
    echo "$input"
  fi
}

ensure_sudo() {
  if [[ "$EUID" -ne 0 ]]; then
    SUDO="sudo"
  else
    SUDO=""
  fi
}

install_file() {
  local src="$1"
  local dst="$2"
  local mode="$3"
  $SUDO install -m "$mode" "$src" "$dst"
}

backup_file() {
  local path="$1"
  if [[ -f "$path" ]]; then
    $SUDO cp "$path" "$path.bak"
  fi
}

append_pam_exec() {
  local pam_file="$1"
  local line="account required pam_exec.so stdout /usr/local/bin/screentime-check"
  if $SUDO grep -q "screentime-check" "$pam_file"; then
    if $SUDO grep -q "pam_exec.so stdout /usr/local/bin/screentime-check" "$pam_file"; then
      return
    fi
    backup_file "$pam_file"
    $SUDO sed -i "s|^account[[:space:]]\\+required[[:space:]]\\+pam_exec\\.so[[:space:]]\\+/usr/local/bin/screentime-check$|$line|" "$pam_file"
    return
  fi
  backup_file "$pam_file"
  echo "$line" | $SUDO tee -a "$pam_file" >/dev/null
}

main() {
  ensure_sudo

  need_cmd systemctl
  need_cmd loginctl
  need_cmd python3
  need_cmd notify-send

  install_file "$ROOT_DIR/bin/screentime-daemon" "/usr/local/bin/screentime-daemon" 0755
  install_file "$ROOT_DIR/bin/screentime-check" "/usr/local/bin/screentime-check" 0755

  if [[ ! -f "/etc/screentime.conf" ]]; then
    echo "Creating /etc/screentime.conf"
    local username
    local reset_time
    username="$(prompt_default "Target username" "yourusername")"
    reset_time="$(prompt_default "Reset time (HH:MM)" "06:00")"

    local mon tue wed thu fri sat sun
    mon="$(prompt_default "Monday minutes" "120")"
    tue="$(prompt_default "Tuesday minutes" "120")"
    wed="$(prompt_default "Wednesday minutes" "120")"
    thu="$(prompt_default "Thursday minutes" "120")"
    fri="$(prompt_default "Friday minutes" "120")"
    sat="$(prompt_default "Saturday minutes" "60")"
    sun="$(prompt_default "Sunday minutes" "60")"

    $SUDO tee /etc/screentime.conf >/dev/null <<EOF_CONF
[user]
name = $username

[reset]
time = $reset_time

[limits]
mon = $mon
tue = $tue
wed = $wed
thu = $thu
fri = $fri
sat = $sat
sun = $sun
EOF_CONF
  else
    echo "/etc/screentime.conf already exists; leaving as-is"
  fi

  install_file "$ROOT_DIR/systemd/screentime.service" "/etc/systemd/system/screentime.service" 0644
  install_file "$ROOT_DIR/systemd/screentime.timer" "/etc/systemd/system/screentime.timer" 0644

  if [[ -f "/etc/pam.d/system-login" ]]; then
    append_pam_exec "/etc/pam.d/system-login"
  else
    echo "WARN: /etc/pam.d/system-login not found" >&2
  fi

  if [[ -f "/etc/pam.d/gdm-password" ]]; then
    append_pam_exec "/etc/pam.d/gdm-password"
  fi

  $SUDO systemctl daemon-reload
  $SUDO systemctl enable --now screentime.timer

  echo "Installed screentime. Check status with: systemctl status screentime.timer"
}

main "$@"
