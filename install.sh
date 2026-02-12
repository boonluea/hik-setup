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

# 3. สร้างสคริปต์สำหรับแก้เรื่อง Display และใส่ใน Startup อัตโนมัติ
# วิธีนี้จะทำให้ xhost +local:docker ทำงานทุกครั้งที่เข้าหน้า Desktop
echo "📺 Setting up Auto-Display Permission..."
mkdir -p ~/.config/autostart

# สร้างสคริปต์ตัวจริงไว้ในเครื่อง
cat <<EOF > ~/allow_docker_display.sh
#!/bin/bash
sleep 5
xhost +local:docker
sudo docker restart face-api
EOF
chmod +x ~/allow_docker_display.sh

# สร้างไฟล์ .desktop เพื่อให้ Ubuntu รันสคริปต์ข้างบนตอน Login
cat <<EOF > ~/.config/autostart/docker_display_fix.desktop
[Desktop Entry]
Type=Application
Exec=/home/\$USER/allow_docker_display.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Docker Display Fix
EOF

# 4. ตั้งค่า Auto Reboot ทุกเที่ยงคืน (00:00)
echo "⏰ Setting up Midnight Reboot..."
(crontab -l 2>/dev/null | grep -v "/sbin/shutdown -r now"; echo "0 0 * * * /sbin/shutdown -r now") | crontab -

# 5. รัน Watchtower (Auto Update ทุก 5 นาที)
echo "🔍 Setting up Watchtower..."
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
sudo docker run -d \
  --name face-api \
  --network host \
  --restart always \
  -e DISPLAY=\$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  boonhlua/hik-face-system:latest

echo "✅ ALL SETUP COMPLETE!"
echo "⚠️  FINAL STEP: You MUST enable 'Automatic Login' in Ubuntu Settings manually."
echo "🔄 The system will REBOOT in 10 seconds to apply all changes..."
sleep 10
sudo reboot