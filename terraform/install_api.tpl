#!/bin/bash # Usa Bash para user_data renderizado por Terraform (fuente: GNU Bash manual)
# User data — API (Amazon Linux 2023), ALB target :8000
# IPs de RabbitMQ y Mongo inyectadas por Terraform (templatefile); no hace falta IAM ni SSM en la instancia.
# Credenciales: install_rabbitmq.sh (admin/password123) e install_mongodb.sh (admin/password123).
set -euo pipefail # Habilita modo estricto para prevenir errores silenciosos (fuente: buenas prácticas Bash)
exec > >(tee /var/log/user-data-install-api.log | logger -t user-data -s 2>/dev/console) 2>&1 # Redirige logs a archivo, syslog y consola de instancia (fuente: AWS user-data logging)

sudo dnf update -y # Actualiza paquetes del sistema operativo (fuente: DNF docs)
sudo dnf install -y docker git # Instala Docker y Git necesarios para desplegar API (fuente: dependencias del proyecto)

sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose # Descarga Docker Compose para plataforma actual (fuente: Docker Compose release binaries)
sudo chmod +x /usr/local/bin/docker-compose # Otorga permiso de ejecución al binario (fuente: chmod manual)

sudo systemctl enable docker # Activa Docker en cada boot (fuente: systemctl enable)
sudo systemctl start docker # Inicia Docker en el arranque inicial (fuente: systemctl start)
sudo usermod -aG docker ec2-user || true # Añade ec2-user al grupo docker, tolerando si ya existe (fuente: Docker post-install)

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

# Rabbit/Mongo instalan paquetes vía dnf; 60s suele ser insuficiente en t3.micro
sleep 90
wait_for_port "${rabbit_private_ip}" 5672
wait_for_port "${mongo_private_ip}" 27017

cd /home/ec2-user # Cambia a carpeta de trabajo del usuario EC2 (fuente: convención Amazon Linux)
rm -rf restaurant-api # Limpia versión previa del repositorio para despliegue limpio (fuente: bootstrap idempotente)
git clone --depth 1 "${git_repo_url}" restaurant-api # Clona repo configurable desde Terraform con historial mínimo (fuente: templatefile + Git shallow clone)
cd restaurant-api # Entra al directorio de la aplicación para construir imagen (fuente: estructura del repo)

sudo docker build -t restaurant-api:latest . # Construye imagen de la API desde Dockerfile del proyecto (fuente: Docker build docs)

sudo docker rm -f restaurant-api 2>/dev/null || true # Elimina contenedor previo si existe para evitar conflicto de nombre (fuente: Docker rm)
sudo docker run -d --name restaurant-api --restart unless-stopped -p 8000:8000 -e "RABBITMQ_HOST=${rabbit_private_ip}" -e "RABBITMQ_PORT=5672" -e "RABBITMQ_USER=admin" -e "RABBITMQ_PASSWORD=password123" -e "MONGO_URI=mongodb://admin:password123@${mongo_private_ip}:27017/?authSource=admin" restaurant-api:latest # Ejecuta API exponiendo :8000 e inyectando IPs privadas y credenciales actuales (fuente: Docker run + variables Terraform)

echo "[install_api] API en :8000; Rabbit=${rabbit_private_ip} Mongo=${mongo_private_ip}" # Log de verificación con endpoints usados por la API (fuente: observabilidad operativa)
