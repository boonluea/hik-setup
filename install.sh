#!/bin/bash

echo "🚀 Starting Hik-Face-System Setup..."

# 1. Update System & Install Dependencies
sudo apt update && sudo apt install -y curl firefox
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo systemctl enable --now docker

# 2. Permission for Display (X11)
# ทำให้ Docker เปิด Firefox ออกหน้าจอได้
echo "xhost +local:docker" >> ~/.bashrc
xhost +local:docker

# 3. Setup Auto Reboot at Midnight
# ตรวจสอบก่อนว่ามีบรรทัดนี้หรือยัง ถ้ายังไม่มีค่อยใส่
(crontab -l 2>/dev/null | grep -q "/sbin/shutdown -r now") || (crontab -l 2>/dev/null; echo "0 0 * * * /sbin/shutdown -r now") | crontab -

# 4. Run Watchtower (For Auto Update every 5 mins)
sudo docker rm -f watchtower || true
sudo docker run -d \
  --name watchtower \
  -v /var/run/docker.sock:/var/run/docker.sock \
  containrrr/watchtower \
  --interval 300

# 5. Run Main API Application
sudo docker rm -f face-api || true
sudo docker run -d \
  --name face-api \
  --network host \
  --restart always \
  -e DISPLAY=$DISPLAY \
  -v /tmp/.X11-unix:/tmp/.X11-unix \
  boonhlua/hik-face-system:latest

echo "✅ Setup Complete! Please enable 'Automatic Login' in Ubuntu Settings."