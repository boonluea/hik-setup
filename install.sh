#!/bin/bash

echo "🚀 Starting Hik-Face-System Setup (Resumable Version)..."

# 1. Update System & Install Dependencies
sudo apt update
# ติดตั้งเฉพาะตัวที่ยังไม่มี เพื่อประหยัดเวลา
sudo apt install -y curl firefox x11-xserver-utils

# 2. Install Docker (เช็คก่อนว่ามีหรือยัง)
if ! command -v docker &> /dev/null; then
    echo "📦 Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo systemctl enable --now docker
else
    echo "✅ Docker is already installed."
fi

# 3. Permission for Display (X11) - ป้องกันการเขียนซ้ำ
if ! grep -q "xhost +local:docker" ~/.bashrc; then
    echo "xhost +local:docker" >> ~/.baserc
    echo "📺 Display permissions added to .bashrc"
fi
# รันคำสั่งเพื่อให้มีผลทันทีใน session นี้
xhost +local:docker || echo "⚠️ Warning: Display not found, will be fixed after reboot."

# 4. Setup Auto Reboot at Midnight (ป้องกันบรรทัดซ้ำ)
(crontab -l 2>/dev/null | grep -v "/sbin/shutdown -r now"; echo "0 0 * * * /sbin/shutdown -r now") | crontab -

# 5. Run Watchtower (ลบตัวเก่าก่อนรันใหม่เสมอ เพื่อให้รันซ้ำได้)
echo "🔍 Setting up Watchtower..."
sudo docker rm -f watchtower 2>/dev/null || true
sudo docker run -d \
  --name watchtower \
  -v /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower \
  --interval 300

# 6. Run Main API Application (ลบตัวเก่าก่อนรันใหม่เสมอ)
echo "🤖 Setting up Face-API Application..."
sudo docker rm -f face-api 2>/dev/null || true
sudo docker pull boonhlua/hik-face-system:latest
sudo docker run -d \
  --name face-api \
  --network host \
  --restart always \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  boonhlua/hik-face-system:latest

echo "✅ Setup Complete! The system will REBOOT in 10 seconds..."
sleep 10
sudo reboot