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

# ==============================================================================
# 5. Autostart .desktop (Chrome Kiosk + Anti-Keyring + Robust Health Check)
# ==============================================================================

# --- [1] ขั้นตอนการติดตั้ง Google Chrome (เสถียรที่สุดสำหรับ Kiosk Mode) ---
echo "[*] Downloading and Installing Google Chrome..."
sudo apt-get update
sudo apt-get install -y wget curl

# ดาวน์โหลด Google Chrome ตัวล่าสุด (.deb)
wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/google-chrome.deb

# ติดตั้ง Chrome พร้อมแก้ปัญหา Dependencies อัตโนมัติ
sudo dpkg -i /tmp/google-chrome.deb || sudo apt-get install -f -y

# ลบไฟล์ติดตั้งที่ใช้เสร็จแล้วเพื่อประหยัดพื้นที่
rm /tmp/google-chrome.deb

# --- [2] ขั้นตอนการตั้งค่า Autostart และสร้างสคริปต์ดักรอระบบ ---
echo "[*] Setting up Google Chrome Kiosk Autostart..."

# สร้างโฟลเดอร์สำหรับเก็บสคริปต์ควบคุมการเปิดหน้าจอ
mkdir -p /home/$CURRENT_USER/.config/autostart
os_bin_dir="/home/$CURRENT_USER/.local/bin" 
mkdir -p $os_bin_dir

# --- สร้าง Script ดักรอ Docker Container จนกว่าเว็บจะตอบสนองสมบูรณ์ ---
cat << 'EOF' > "$os_bin_dir/launch_kiosk.sh"
#!/bin/bash
# ล้างโปรเซสเก่าของ Chrome ที่อาจตกค้างจากการปิดระบบไม่สมบูรณ์
pkill --oldest chrome
pkill -f google-chrome
sleep 1

echo "[*] Waiting for face_api Docker container to be ready..."

# ลูปตรวจสอบหน้าเว็บพอร์ต 8000 แบบเข้มงวด (จนกว่าจะได้รหัส 200, 302 หรือ 401 เพื่อป้องกันอาการหลุดลูปไปหน้าขาว)
while true; do
    HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --connect-timeout 2 http://127.0.0.1:8000/)
    
    if [ "$HTTP_STATUS" = "200" ] || [ "$HTTP_STATUS" = "401" ] || [ "$HTTP_STATUS" = "302" ]; then
        echo "[+] Web service detected with status: $HTTP_STATUS"
        break
    else
        echo "[-] System status is $HTTP_STATUS (Waiting for FastAPI to boot...). Retrying in 3 seconds..."
        sleep 3
    fi
done

echo "[+] face_api Docker is up! Launching Google Chrome Kiosk mode..."
# หน่วงเวลาเพิ่มอีก 5 วินาทีเพื่อให้มั่นใจว่า FastAPI โหลดเธรด NVR และ Connection ต่างๆ เสร็จสิ้น
sleep 5

# เรียกใช้ Chrome ในโหมด Kiosk และบล็อกการเรียกถามสิทธิ์พาสเวิร์ด Keyring ของ Ubuntu
google-chrome --kiosk \
              --no-first-run \
              --fast \
              --fast-start \
              --disable-infobars \
              --disable-session-crashed-bubble \
              --no-default-browser-check \
              --autoplay-policy=no-user-gesture-required \
              --password-store=basic \
              "http://127.0.0.1:8000"
EOF

# ตั้งสิทธิ์ให้สคริปต์ตัวตรวจสอบสามารถทำงานได้
chmod +x "$os_bin_dir/launch_kiosk.sh"
chown $CURRENT_USER:$CURRENT_USER "$os_bin_dir/launch_kiosk.sh"


# --- [3] สร้างไฟล์ควบคุม .desktop ชี้ไปที่ตัว Script วนลูปเช็คพอร์ต ---
mkdir -p /home/$CURRENT_USER/.config/autostart/
cat <<EOF > /home/$CURRENT_USER/.config/autostart/kiosk_start.desktop
[Desktop Entry]
Type=Application
Exec=/home/$CURRENT_USER/.local/bin/launch_kiosk.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
Name=Hik Face System Kiosk (Chrome)
Comment=Wait for Docker Container and Open Chrome Kiosk
EOF

# จัดการกำหนดสิทธิ์เจ้าของไฟล์ของตัว .desktop ให้ถูกต้อง
sudo chown $CURRENT_USER:$CURRENT_USER /home/$CURRENT_USER/.config/autostart/kiosk_start.desktop
chmod +x /home/$CURRENT_USER/.config/autostart/kiosk_start.desktop

echo "[+] Chrome Kiosk Installation & Configuration Completed Successfully!"
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
  containrrr/watchtower --interval 120 --cleanup

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
