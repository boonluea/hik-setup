#!/bin/bash

# ป้องกันปัญหาการอ่านค่า Input เมื่อรันผ่าน curl | bash
exec < /dev/tty

echo "🚀 Starting Hik-Face-System Setup..."

# --- ส่วนการรับค่าจากผู้ใช้งาน ---
# เด้งช่องมาให้กรอกชื่อ User ถ้าไม่กรอกจะใช้ชื่อปัจจุบันที่รันสคริปต์
read -p "👤 Enter Ubuntu Username (default: $(whoami)): " INPUT_USER
CURRENT_USER=${INPUT_USER:-$(whoami)}
echo "✅ Using Username: $CURRENT_USER"


# 1. Update & Install Dependencies
sudo apt update
sudo apt install -y curl firefox x11-xserver-utils

# 2. Install Docker
if ! command -v docker &> /dev/null; then
    echo "📦 Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo systemctl enable --now docker
else
    echo "✅ Docker is already installed."
fi

# 3. แก้ปัญหา sudo ถามรหัสผ่านตอน Restart Docker (จาก Error ในภาพ)
echo "🔑 Setting up Passwordless Docker for $CURRENT_USER..."
echo "$CURRENT_USER ALL=(ALL) NOPASSWD: /usr/bin/docker" | sudo tee /etc/sudoers.d/docker-nopasswd

# 4. สร้างสคริปต์สำหรับจัดการหน้าจอและสั่งเปิด Firefox
echo "📺 Setting up Auto-Display and Firefox Kiosk..."
mkdir -p /home/$CURRENT_USER/.config/autostart

# สร้างสคริปต์รันจริง (ใช้ Path เต็มตามชื่อที่กรอก)
cat <<EOF > /home/$CURRENT_USER/allow_docker_display.sh
#!/bin/bash
export DISPLAY=:0
sleep 15
xhost +local:docker
/usr/bin/firefox --kiosk http://127.0.0.1:8000 &
sudo /usr/bin/docker restart face-api
EOF

chmod +x /home/$CURRENT_USER/allow_docker_display.sh
sudo chown $CURRENT_USER:$CURRENT_USER /home/$CURRENT_USER/allow_docker_display.sh

# 5. สร้างไฟล์ Autostart .desktop
cat <<EOF > /home/$CURRENT_USER/.config/autostart/kiosk_start.desktop
[Desktop Entry]
Type=Application
Exec=/bin/bash /home/$CURRENT_USER/allow_docker_display.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Hik Face System Kiosk
EOF

chmod +x /home/$CURRENT_USER/.config/autostart/kiosk_start.desktop
sudo chown $CURRENT_USER:$CURRENT_USER /home/$CURRENT_USER/.config/autostart/kiosk_start.desktop

# 6. ตั้งค่า Auto Reboot เที่ยงคืน
(crontab -l 2>/dev/null | grep -v "/sbin/shutdown -r now"; echo "0 0 * * * /sbin/shutdown -r now") | crontab -

# 7. รัน Watchtower & Face-API
sudo docker rm -f watchtower face-api 2>/dev/null || true

sudo docker run -d --name watchtower -v /var/run/docker.sock:/var/run/docker.sock containrrr/watchtower --interval 300

sudo docker run -d \
  --name face-api \
  --network host \
  --restart always \
  -e DISPLAY=:0 \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  boonhlua/hik-face-system:latest

echo "💾 Starting MySQL Database Container..."
# สร้าง Volume เพื่อให้ข้อมูลไม่หายเวลาลบ Container
sudo docker volume create mysql_data

# รัน MySQL (ตั้งรหัสผ่านตามที่คุณต้องการ)
sudo docker run -d \
  --name mysql-db \
  --network host \
  --restart always \
  -e MYSQL_ROOT_PASSWORD=Bl_14042532 \
  -e MYSQL_DATABASE=nvr_system \
  -v mysql_data:/var/lib/mysql \
  mysql:8.0

echo "✅ ALL SETUP COMPLETE for user: $CURRENT_USER"
echo "🔄 The system will REBOOT in 10 seconds..."
sleep 10
sudo reboot