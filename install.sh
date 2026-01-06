#!/bin/bash
# SmartSocialVPN - One File Ultra Low RAM Script
# SSH WS + VLESS WS | Auto | Menu | Social Packages

set -e

PORT_DEFAULT=8080
XRAY_BIN="/usr/local/bin/xray"
XRAY_CONF="/etc/xray.json"
WS_PATH="/ws"
SSH_WS_BIN="/usr/local/bin/ws-ssh"

check_root() {
  [ "$EUID" -ne 0 ] && echo "شغل السكربت كـ root" && exit 1
}

find_free_port() {
  for p in 8080 8880 2095 2082 2086 80; do
    ss -lnt | grep -q ":$p " || { echo $p; return; }
  done
  echo 8080
}

enable_autostart() {
  cat > /etc/rc.local << 'EOF'
#!/bin/bash
[ -f /usr/local/bin/ws-ssh ] && nohup /usr/local/bin/ws-ssh >/dev/null 2>&1 &
[ -f /usr/local/bin/xray ] && nohup /usr/local/bin/xray run -c /etc/xray.json >/dev/null 2>&1 &
exit 0
EOF
  chmod +x /etc/rc.local
}

install_base() {
  apt update -y >/dev/null 2>&1
  apt install -y curl wget socat openssh-server dropbear unzip >/dev/null 2>&1
}

install_ssh_ws() {
  PORT=$(find_free_port)

  systemctl restart ssh || service ssh restart
  dropbear -p 109

  cat > $SSH_WS_BIN << EOF
#!/bin/bash
while true; do
  socat TCP-LISTEN:$PORT,reuseaddr,fork TCP:127.0.0.1:22
done
EOF

  chmod +x $SSH_WS_BIN
  nohup $SSH_WS_BIN >/dev/null 2>&1 &

  echo "SSH WebSocket جاهز"
  echo "Port: $PORT → SSH 22"
}

add_ssh_user() {
  read -p "اسم المستخدم: " U
  read -p "كلمة المرور: " P
  read -p "المدة (أيام): " D
  useradd -e $(date -d "$D days" +%Y-%m-%d) -s /bin/false -M $U
  echo "$U:$P" | chpasswd
  echo "تم إنشاء المستخدم"
}

install_vless_ws() {
  PORT=$(find_free_port)
  UUID=$(cat /proc/sys/kernel/random/uuid)

  wget -qO /tmp/xray.zip https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip
  unzip -o /tmp/xray.zip -d /usr/local/bin >/dev/null 2>&1
  chmod +x $XRAY_BIN

  cat > $XRAY_CONF << EOF
{
  "inbounds": [{
    "port": $PORT,
    "protocol": "vless",
    "settings": {
      "clients": [{ "id": "$UUID" }],
      "decryption": "none"
    },
    "streamSettings": {
      "network": "ws",
      "wsSettings": { "path": "$WS_PATH" }
    }
  }],
  "outbounds": [{ "protocol": "freedom" }]
}
EOF

  nohup $XRAY_BIN run -c $XRAY_CONF >/dev/null 2>&1 &

  IP=$(curl -s ifconfig.me)

  echo "VLESS WebSocket جاهز"
  echo "vless://$UUID@$IP:$PORT?type=ws&path=$WS_PATH#SmartSocialVPN"
}

menu() {
  clear
  echo "=== SmartSocialVPN Menu ==="
  echo "1) تثبيت SSH WebSocket"
  echo "2) إضافة مستخدم SSH"
  echo "3) تثبيت VLESS WebSocket"
  echo "4) عرض رابط VLESS"
  echo "5) إعادة تشغيل الخدمات"
  echo "0) خروج"
  read -p "اختيارك: " CH

  case $CH in
    1) install_ssh_ws ;;
    2) add_ssh_user ;;
    3) install_vless_ws ;;
    4)
      IP=$(curl -s ifconfig.me)
      UUID=$(jq -r '.inbounds[0].settings.clients[0].id' $XRAY_CONF 2>/dev/null)
      PORT=$(jq -r '.inbounds[0].port' $XRAY_CONF 2>/dev/null)
      echo "vless://$UUID@$IP:$PORT?type=ws&path=$WS_PATH#SmartSocialVPN"
      ;;
    5)
      pkill xray || true
      pkill socat || true
      [ -f $SSH_WS_BIN ] && nohup $SSH_WS_BIN >/dev/null 2>&1 &
      [ -f $XRAY_BIN ] && nohup $XRAY_BIN run -c $XRAY_CONF >/dev/null 2>&1 &
      echo "تمت إعادة التشغيل"
      ;;
    0) exit ;;
    *) echo "خيار غير صحيح" ;;
  esac

  read -p "اضغط Enter للمتابعة..."
  menu
}

# ==== START ====
check_root
install_base
enable_autostart
menu
