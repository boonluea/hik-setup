#!/bin/bash

exec < /dev/tty
echo "🚀 Starting Hik-Face-System Setup..."

# --- รับค่า User ---
read -p "👤 Enter Ubuntu Username (default: $(whoami)): " INPUT_USER
CURRENT_USER=${INPUT_USER:-$(whoami)}
echo "✅ Using Username: $CURRENT_USER"

# --- 0. Clean Up (ลบของเก่าทิ้งทั้งหมดก่อนเริ่มใหม่) ---
echo "🧹 Cleaning up existing containers and volumes..."
# หยุดและลบ container ที่เกี่ยวข้อง
sudo docker rm -f mysql-db face-api watchtower 2>/dev/null || true
# ลบ volume ของ mysql เพื่อ reset รหัสผ่านใหม่ (ระวัง: ข้อมูลใน DB จะหาย)
sudo docker volume rm mysql_data 2>/dev/null || true
# สร้างโฟลเดอร์เก็บรูปถ้ายังไม่มี
mkdir -p /home/$CURRENT_USER/faces

# 1. Update & Dependencies
sudo apt update
sudo apt install -y curl firefox x11-xserver-utils

# 2. Install Docker
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo systemctl enable --now docker
fi

# เพิ่ม User เข้า group docker
sudo usermod -aG docker $CURRENT_USER

# 3. Passwordless Docker
echo "$CURRENT_USER ALL=(ALL) NOPASSWD: /usr/bin/docker" | sudo tee /etc/sudoers.d/docker-nopasswd

# --- ส่วนของ Database ---
echo "💾 Starting MySQL Database Container..."
sudo docker volume create mysql_data
# ใส่ ' ' ครอบ password เพื่อป้องกันตัว $ มีปัญหา
sudo docker run -d \
  --name mysql-db \
  --network host \
  --restart always \
  -e MYSQL_ROOT_PASSWORD='Kj#9v$Lp2!mZ7xR@Qn^4tW*8' \
  -e MYSQL_DATABASE=nvr_system \
  -e TZ=Asia/Bangkok \
  -v mysql_data:/var/lib/mysql \
  -v /etc/localtime:/etc/localtime:ro \
  mysql:8.0

echo "⏳ Waiting for MySQL to warm up (20s)..."
sleep 20 


# 5. Autostart .desktop
cat <<EOF > /home/$CURRENT_USER/.config/autostart/kiosk_start.desktop
[Desktop Entry]
Type=Application
Exec=firefox --kiosk http://127.0.0.1:8000
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Hik Face System Kiosk
EOF

sudo chown $CURRENT_USER:$CURRENT_USER /home/$CURRENT_USER/.config/autostart/kiosk_start.desktop

# 6. Crontab Reboot
(crontab -l 2>/dev/null | grep -v "/sbin/shutdown -r now"; echo "0 0 * * * /sbin/shutdown -r now") | crontab -

# 7. Watchtower & Face-API
sudo docker run -d \
  --name watchtower \
  --restart always \
  -e DOCKER_API_VERSION=1.44 \
  -e TZ=Asia/Bangkok \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v /etc/localtime:/etc/localtime:ro \
  containrrr/watchtower --interval 300 --cleanup

sudo docker run -d \
  --name face-api \
  --network host \
  --restart always \
  -e DISPLAY=:0 \
  -e TZ=Asia/Bangkok \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v /etc/localtime:/etc/localtime:ro \
  -v /home/$CURRENT_USER/faces:/app/static/faces \
  boonhlua/hik-face-system:latest

echo "✅ ALL SETUP COMPLETE!"
echo "🔄 REBOOTING in 10 seconds..."
sleep 10
sudo reboot