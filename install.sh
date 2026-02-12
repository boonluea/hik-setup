#!/bin/bash

echo "🚀 Starting Hik-Face-System Setup (Full Auto Version)..."

# 1. Update System & Install Dependencies
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

# 3. สร้างสคริปต์สำหรับจัดการหน้าจอและสั่งเปิด Firefox (หัวใจสำคัญอยู่ตรงนี้)
echo "📺 Setting up Auto-Display and Firefox Kiosk..."
mkdir -p ~/.config/autostart

# สร้างสคริปต์ที่จะรันตอนเข้า Desktop
cat <<EOF > ~/allow_docker_display.sh
#!/bin/bash
# รอให้ระบบ Graphic (X11) พร้อม
sleep 10
# 1. อนุญาตให้ Docker ส่งภาพออกจอ
xhost +local:docker
# 2. สั่งเปิด Firefox ไปที่ URL ที่ต้องการ (กำหนดตรงนี้เลย)
firefox --kiosk http://127.0.0.1:8000 &
# 3. รัน Docker ให้พร้อม
sudo docker restart face-api
EOF
chmod +x ~/allow_docker_display.sh

# สร้างไฟล์เรียกสคริปต์ข้างบนให้ทำงานตอน Login (Auto Start)
cat <<EOF > ~/.config/autostart/kiosk_start.desktop
[Desktop Entry]
Type=Application
Exec=/home/\$USER/allow_docker_display.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Hik Face System Kiosk
EOF

# 4. ตั้งค่า Auto Reboot ทุกเที่ยงคืน (00:00)
echo "⏰ Setting up Midnight Reboot..."
(crontab -l 2>/dev/null | grep -v "/sbin/shutdown -r now"; echo "0 0 * * * /sbin/shutdown -r now") | crontab -

# 5. รัน Watchtower (Auto Update ทุก 5 นาที)
sudo docker rm -f watchtower 2>/dev/null || true
sudo docker run -d \
  --name watchtower \
  -v /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower \
  --interval 300

# 6. รัน Main API Application
echo "🤖 Setting up Face-API Application..."
sudo docker rm -f face-api 2>/dev/null || true
sudo docker pull boonhlua/hik-face-system:latest
# รันแบบ host network และเชื่อม display
sudo docker run -d \
  --name face-api \
  --network host \
  --restart always \
  -e DISPLAY=\$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  boonhlua/hik-face-system:latest

echo "✅ ALL SETUP COMPLETE!"
echo "🔄 The system will REBOOT in 10 seconds..."
sleep 10
sudo reboot