#!/bin/bash
# Amazon Linux 2023 - Worker (IPs privadas inyectadas por Terraform)
set -euo pipefail
exec > >(tee /var/log/user-data-install-worker.log | logger -t user-data -s 2>/dev/console) 2>&1

sudo dnf update -y
sudo dnf install -y python3 python3-pip git

wait_for_port() {
  local host=$1 port=$2
  local i
  for i in $(seq 1 36); do
    if timeout 2 bash -c "echo >/dev/tcp/$${host}/$${port}" 2>/dev/null; then
      echo "[wait] $${host}:$${port} disponible"
      return 0
    fi
    echo "[wait] esperando $${host}:$${port}... ($${i}/36)"
    sleep 10
  done
  echo "[wait] TIMEOUT $${host}:$${port}"
  return 1
}

sleep 90
wait_for_port "${rabbit_private_ip}" 5672
wait_for_port "${mongo_private_ip}" 27017

cd /home/ec2-user
rm -rf restaurant-api
git clone --depth 1 "${git_repo_url}" restaurant-api
cd restaurant-api

pip3 install -r requirements.txt

export PYTHONPATH=/home/ec2-user/restaurant-api
export RABBITMQ_HOST="${rabbit_private_ip}"
export RABBITMQ_PORT=5672
export RABBITMQ_USER=admin
export RABBITMQ_PASSWORD=password123
export MONGO_URI="mongodb://admin:password123@${mongo_private_ip}:27017/?authSource=admin"

nohup python3 api/worker.py > /var/log/worker.log 2>&1 &

echo "[install_worker] Worker; Rabbit=${rabbit_private_ip} Mongo=${mongo_private_ip}" >> /var/log/worker_setup.log
