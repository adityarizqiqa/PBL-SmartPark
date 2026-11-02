#!/usr/bin/env bash
# Setup satu kali di server (Azure VM). Jalankan dari HOME sebagai user
# yang nanti dipakai service (mis. `deploy`), dengan sudo untuk baris systemd.
#
#   curl -sSL <raw-url-bootstrap.sh> | bash
# atau
#   bash bootstrap.sh
set -euo pipefail

REPO="${REPO:-git@github.com:adityarizqiqa/PBL-SMT5-KELOMPOK-4.git}"
BRANCH="${BRANCH:-Develop}"
DEPLOY_DIR="${DEPLOY_DIR:-/opt/smartpark}"
SERVICE_USER="${SERVICE_USER:-deploy}"

echo "== 1/5 clone repo =="
sudo mkdir -p "$DEPLOY_DIR"
sudo chown "$SERVICE_USER":"$SERVICE_USER" "$DEPLOY_DIR"
if [ -d "$DEPLOY_DIR/.git" ]; then
  echo "repo sudah ada, dilewati"
else
  git clone --branch "$BRANCH" "$REPO" "$DEPLOY_DIR"
fi
cd "$DEPLOY_DIR"

echo "== 2/5 virtualenv + dependensi =="
python3 -m venv backend/.venv
backend/.venv/bin/pip install --upgrade pip --quiet
backend/.venv/bin/pip install -r backend/requirements.txt --quiet

echo "== 3/5 .env produksi =="
if [ ! -f backend/.env ]; then
  cp backend/.env.example backend/.env
  echo "  -> salin .env.example ke .env. WAJIB disesuaikan:
       DEBUG=false (reloader bentrok systemd)
       HOST=0.0.0.0, PORT=9876
       DATABASE_URL, password, dll."
else
  echo "  -> .env sudah ada, tidak disentuh (data produksi) "
fi

echo "== 4/5 aktifkan layanan systemd =="
sudo cp backend/deploy/smartpark.service /etc/systemd/system/smartpark.service
sudo sed -i "s|User=deploy|User=${SERVICE_USER}|" /etc/systemd/system/smartpark.service
sudo systemctl daemon-reload
sudo systemctl enable --now smartpark

echo "== 5/5 kunci deploy SSH =="
echo "  Generate kunci khusus deploy (TANPA passphrase) dan tambahkan:
    1) ssh-keygen -t ed25519 -f ~/.ssh/smartpark_deploy -C deploy -N ''
    2) cat ~/.ssh/smartpark_deploy.pub >> ~/.ssh/authorized_keys
    3) simpan isi ~/.ssh/smartpark_deploy (PRIVATE) ke GitHub repo Secrets:
       SSH_HOST=4.213.226.116
       SSH_USER=${SERVICE_USER}
       SSH_DEPLOY_KEY=<isi private key>
       SSH_PORT=22

     GitHub: Settings -> Secrets and variables -> Actions -> New repository secret

  Semenjak ini, tiap push ke branch ${BRANCH} otomatis deploy. Tidak ada lagi zip."

echo "Selesai. Cek status: sudo systemctl status smartpark"