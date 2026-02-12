#!/bin/bash

exec < /dev/tty
echo "🚀 Starting Hik-Face-System Setup..."

# --- รับค่า User ---
read -p "👤 Enter Ubuntu Username (default: $(whoami)): " INPUT_USER
CURRENT_USER=${INPUT_USER:-$(whoami)}
echo "✅ Using Username: $CURRENT_USER"

# 1. Update & Dependencies
sudo apt update
sudo apt install -y curl firefox x11-xserver-utils

# 2. Install Docker
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo systemctl enable --now docker
fi

# เพิ่ม User เข้า group docker (ช่วยให้รันโดยไม่ต้อง sudo ในบางกรณี)
sudo usermod -aG docker $CURRENT_USER

# 3. Passwordless Docker (สำหรับสคริปต์ตอนบูต)
echo "$CURRENT_USER ALL=(ALL) NOPASSWD: /usr/bin/docker" | sudo tee /etc/sudoers.d/docker-nopasswd

# --- ส่วนของ Database (ต้องรันก่อน API) ---
echo "💾 Starting MySQL Database Container..."
sudo docker volume create mysql_data
sudo docker rm -f mysql-db 2>/dev/null || true
sudo docker run -d \
  --name mysql-db \
  --network host \
  --restart always \
  -e MYSQL_ROOT_PASSWORD=Bl_14042532 \
  -e MYSQL_DATABASE=nvr_system \
  -e TZ=Asia/Bangkok \
  -v mysql_data:/var/lib/mysql \
  -v /etc/localtime:/etc/localtime:ro \
  mysql:8.0

echo "⏳ Waiting for MySQL to warm up (20s)..."
sleep 20 # ให้เวลามันสร้างไฟล์ระบบข้างในหน่อยครับ

# 4. ตั้งค่าสคริปต์รันหน้าจอ
mkdir -p /home/$CURRENT_USER/.config/autostart
cat <<EOF > /home/$CURRENT_USER/allow_docker_display.sh
#!/bin/bash
export DISPLAY=:0
sleep 15
xhost +local:docker
/usr/bin/firefox --kiosk http://127.0.0.1:8000 &
# สั่ง restart api เพื่อให้มันไปเช็คตารางใน mysql ที่พร้อมแล้วอีกรอบ
sudo /usr/bin/docker restart face-api
EOF

chmod +x /home/$CURRENT_USER/allow_docker_display.sh
sudo chown $CURRENT_USER:$CURRENT_USER /home/$CURRENT_USER/allow_docker_display.sh

# 5. Autostart .desktop
cat <<EOF > /home/$CURRENT_USER/.config/autostart/kiosk_start.desktop
[Desktop Entry]
Type=Application
Exec=/bin/bash /home/$CURRENT_USER/allow_docker_display.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Hik Face System Kiosk
EOF

sudo chown $CURRENT_USER:$CURRENT_USER /home/$CURRENT_USER/.config/autostart/kiosk_start.desktop

# 6. Crontab Reboot
(crontab -l 2>/dev/null | grep -v "/sbin/shutdown -r now"; echo "0 0 * * * /sbin/shutdown -r now") | crontab -

# 7. Watchtower & Face-API
sudo docker rm -f watchtower face-api 2>/dev/null || true
sudo docker run -d --name watchtower -v /var/run/docker.sock:/var/run/docker.sock containrrr/watchtower --interval 300

sudo docker run -d \
  --name face-api \
  --network host \
  --restart always \
  -e DISPLAY=:0 \
  -e TZ=Asia/Bangkok \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  -v /etc/localtime:/etc/localtime:ro \
  -v face_images:/app/static/faces \
  boonhlua/hik-face-system:latest

echo "✅ ALL SETUP COMPLETE!"
echo "🔄 REBOOTING in 10 seconds..."
sleep 10
sudo reboot