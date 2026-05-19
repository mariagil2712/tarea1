# =============================================================================
# main.tf — Arquitectura restaurant-api en AWS (IaC)
# =============================================================================
#
# Este archivo fusiona dos patrones del material de clase:
#
#   1) aws-iaas-rabbitmq-postgresql-mongodb-students/main.tf
#      - Varias instancias EC2 (RabbitMQ, API, Worker, Postgres, MongoDB).
#      - Parámetros SSM (Parameter Store) con IPs públicas para integración.
#
#   2) aws-iaas-alb/main.tf
#      - Application Load Balancer (ALB) con target group y listener HTTP.
#      - Varias instancias detrás del balanceador (aquí: 2 réplicas API).
#
# Flujo de tráfico hacia la API:
#   Cliente → ALB:80 → Target Group → instancia API:8000 (uvicorn / FastAPI).
#   La documentación Swagger suele consultarse en http://<DNS-ALB>/docs
#
# Requisitos de variables (variables.tf):
#   - var.subnets debe tener al menos 2 subnets en distintas AZ (el ALB lo exige).
#   - Las subnets deben pertenecer a var.vpc_id.
#
# Security groups (security_groups.tf):
#   - alb_sg  : entrada pública 80 hacia el ALB.
#   - api_sg  : puerto 8000 solo desde alb_sg hacia las instancias API.
#
# User data API: templatefile("install_api.tpl") inyecta IPs privadas de RabbitMQ
# y MongoDB (no se usa SSM desde la EC2; los parámetros SSM siguen existiendo para otros usos).
#
# =============================================================================

locals {                                                           # Define valores locales reutilizables dentro del módulo (fuente: Terraform locals)
  api_user_data = templatefile("${path.module}/install_api.tpl", { # Renderiza plantilla user_data inyectando variables dinámicas (fuente: Terraform templatefile)
    rabbit_private_ip = aws_instance.rabbitmq.private_ip           # Inserta IP privada de instancia RabbitMQ (fuente: aws_instance.private_ip)
    mongo_private_ip  = aws_instance.mongodb.private_ip            # Inserta IP privada de instancia MongoDB (fuente: aws_instance.private_ip)
    git_repo_url      = var.git_repo_url                           # Inserta URL de repositorio parametrizable (fuente: Terraform variable interpolation)
  })
  worker_user_data = templatefile("${path.module}/install_worker.tpl", {
    rabbit_private_ip = aws_instance.rabbitmq.private_ip
    mongo_private_ip  = aws_instance.mongodb.private_ip
    git_repo_url      = var.git_repo_url
  })
}

# -----------------------------------------------------------------------------
# Sección 1 — Instancias de soporte (una por servicio)
# -----------------------------------------------------------------------------
# Cada recurso "aws_instance" crea una máquina virtual. Todas usan la primera
# subnet de la lista para simplificar (tráfico interno entre servicios en VPC).

resource "aws_instance" "rabbitmq" {                                       # Crea instancia EC2 que alojará RabbitMQ (fuente: Terraform aws_instance)
  ami                         = var.ami_id                                 # Imagen base AMI definida en variables (fuente: AWS AMI usage)
  instance_type               = var.instance_type                          # Tamaño de instancia configurable (fuente: EC2 instance types)
  key_name                    = var.key_name                               # Key pair para acceso SSH (fuente: AWS EC2 key pairs)
  subnet_id                   = var.subnets[0]                             # Ubica instancia en primera subnet de la lista (fuente: diseño de red del proyecto)
  vpc_security_group_ids      = [aws_security_group.rabbitmq_sg.id]        # Asocia SG específico de RabbitMQ (fuente: AWS SG attachment)
  user_data                   = file("${path.module}/install_rabbitmq.sh") # Ejecuta script bootstrap en primer arranque (fuente: EC2 user_data)
  associate_public_ip_address = true                                       # Asigna IP pública para acceso/diagnóstico (fuente: AWS EC2 networking)

  tags = {                           # Etiquetas de inventario para instancia RabbitMQ (fuente: AWS tagging)
    Name = "restaurant-api-RabbitMQ" # Nombre humano del recurso (fuente: convención del proyecto)
    Role = "MessageBroker"           # Rol funcional dentro de la arquitectura (fuente: taxonomía interna)
  }
}

resource "aws_instance" "worker" {                                       # Crea instancia EC2 para worker asíncrono (fuente: Terraform aws_instance)
  ami                         = var.ami_id                               # Usa misma AMI del entorno para homogeneidad (fuente: diseño del módulo)
  instance_type               = var.instance_type                        # Tipo de instancia configurable por variable (fuente: Terraform variables)
  key_name                    = var.key_name                             # Clave SSH para administración manual (fuente: AWS EC2)
  subnet_id                   = var.subnets[0]                           # Se despliega en subnet principal definida (fuente: arquitectura actual)
  vpc_security_group_ids      = [aws_security_group.worker_sg.id]        # Aplica reglas de red del worker (fuente: SG separation of concerns)
  user_data                   = local.worker_user_data                   # Provisiona dependencias y ejecuta worker al iniciar (fuente: EC2 user_data)
  user_data_replace_on_change = true
  associate_public_ip_address = true                                     # Habilita IP pública para soporte/labs (fuente: configuración actual del proyecto)

  tags = {                         # Etiquetas para identificar la instancia worker (fuente: AWS tags)
    Name = "restaurant-api-Worker" # Nombre descriptivo del servidor (fuente: convención interna)
    Role = "AsyncWorker"           # Rol de procesamiento asíncrono (fuente: arquitectura del sistema)
  }
}

resource "aws_instance" "postgres" {                                       # Crea instancia EC2 para PostgreSQL (fuente: Terraform aws_instance)
  ami                         = var.ami_id                                 # AMI compartida del entorno (fuente: variable ami_id)
  instance_type               = var.instance_type                          # Tipo de cómputo parametrizado (fuente: EC2 families)
  key_name                    = var.key_name                               # Llave para acceso administrativo (fuente: AWS key pair)
  subnet_id                   = var.subnets[0]                             # Ubicación en subnet primaria (fuente: diseño simplificado del laboratorio)
  vpc_security_group_ids      = [aws_security_group.postgres_sg.id]        # Restringe acceso con SG de Postgres (fuente: network segmentation)
  user_data                   = file("${path.module}/install_postgres.sh") # Inicializa base y configuración de Postgres (fuente: EC2 user_data)
  associate_public_ip_address = true                                       # Exposición pública para pruebas del curso (fuente: configuración actual)

  tags = {                           # Metadatos operativos para instancia PostgreSQL (fuente: AWS tagging best practices)
    Name = "restaurant-api-Postgres" # Nombre del recurso en consola (fuente: convención del proyecto)
    Role = "Database"                # Clasifica su rol como base de datos (fuente: inventario interno)
  }
}

resource "aws_instance" "mongodb" {                                       # Crea instancia EC2 destinada a MongoDB (fuente: Terraform aws_instance)
  ami                         = var.ami_id                                # Imagen base parametrizada del proyecto (fuente: var.ami_id)
  instance_type               = var.instance_type                         # Tipo de máquina configurable (fuente: Terraform variables)
  key_name                    = var.key_name                              # Par de llaves para SSH (fuente: AWS EC2 key pair)
  subnet_id                   = var.subnets[0]                            # Se ubica en subnet seleccionada del entorno (fuente: diseño de red)
  vpc_security_group_ids      = [aws_security_group.mongodb_sg.id]        # Aplica SG específico de MongoDB (fuente: segmentación por servicio)
  user_data                   = file("${path.module}/install_mongodb.sh") # Ejecuta instalación y hardening base de Mongo (fuente: bootstrap script)
  associate_public_ip_address = true                                      # Habilita acceso público para prácticas/diagnóstico (fuente: configuración vigente)

  tags = {                          # Etiquetas de la instancia MongoDB (fuente: AWS tags)
    Name = "restaurant-api-MongoDB" # Nombre visible del nodo Mongo (fuente: convención del proyecto)
    Role = "PostgreSQL Database"    # Etiqueta heredada del template original (fuente: estado actual del archivo)
  }
}

# -----------------------------------------------------------------------------
# Sección 2 — Instancias API (mínimo 2) para alta disponibilidad detrás del ALB
# -----------------------------------------------------------------------------
# count = 2 crea dos recursos: aws_instance.api_server[0] y [1].
# Cada una va en una subnet distinta (índices 0 y 1) para repartir AZs.

resource "aws_instance" "api_server" { # Crea réplicas EC2 de la API detrás del ALB (fuente: patrón escalado horizontal)
  count = 2                            # Número de instancias API para alta disponibilidad mínima (fuente: AWS ALB multi-target)

  user_data_replace_on_change = true   # Reemplaza instancia si cambia user_data (user_data no se reejecuta en updates in-place)

  ami                         = var.ami_id                     # AMI base común para las dos réplicas (fuente: variable compartida)
  instance_type               = var.instance_type              # Tamaño de instancia de API (fuente: configuración por variable)
  key_name                    = var.key_name                   # Llave SSH para administración de nodos API (fuente: AWS EC2)
  subnet_id                   = var.subnets[count.index]       # Distribuye instancias en subnets distintas por índice (fuente: count.index en Terraform)
  vpc_security_group_ids      = [aws_security_group.api_sg.id] # Aplica SG que solo permite tráfico desde ALB en 8000 (fuente: security_groups.tf)
  user_data                   = local.api_user_data            # Usa plantilla renderizada con IPs privadas dependientes (fuente: local templatefile)
  associate_public_ip_address = true                           # Mantiene IP pública para diagnóstico/lab (fuente: configuración actual)

  tags = {                                         # Etiquetas para identificar cada réplica API (fuente: AWS tagging)
    Name = "restaurant-api-API-${count.index + 1}" # Nombra secuencialmente API-1 y API-2 (fuente: interpolación HCL)
    Role = "BackendAPI"                            # Define rol de backend HTTP (fuente: taxonomía del proyecto)
  }
}

# -----------------------------------------------------------------------------
# Sección 3 — Target Group del ALB (puerto de aplicación 8000)
# -----------------------------------------------------------------------------
# El listener del ALB escucha en 80; el target group envía tráfico al puerto
# donde escucha la app en la instancia (8000). El health check usa GET / .

resource "aws_lb_target_group" "api" { # Define target group para enrutar tráfico del ALB a instancias API (fuente: AWS ALB target groups)
  name_prefix = "rapitg"               # Prefijo de nombre; AWS completa con sufijo único (fuente: Terraform aws_lb_target_group constraints)
  port        = 8000                   # Puerto backend donde escucha la aplicación (fuente: arquitectura app)
  protocol    = "HTTP"                 # Protocolo de comunicación ALB -> target (fuente: AWS ALB protocols)
  vpc_id      = var.vpc_id             # VPC donde existen targets y load balancer (fuente: AWS ALB requirements)

  health_check {                 # Configura comprobaciones de salud del target group (fuente: AWS ALB health checks)
    enabled             = true   # Activa health checks periódicos (fuente: AWS defaults/configuration)
    path                = "/"    # Endpoint HTTP consultado en cada instancia (fuente: ruta raíz de la API)
    protocol            = "HTTP" # Protocolo del health check (fuente: AWS ALB health check protocol)
    matcher             = "200"  # Considera saludable solo respuestas 200 (fuente: ALB matcher codes)
    interval            = 15     # Ejecuta chequeo cada 15 segundos (fuente: tuning de disponibilidad)
    timeout             = 5      # Espera máxima de respuesta por chequeo (fuente: AWS health check settings)
    healthy_threshold   = 2      # Requiere 2 éxitos consecutivos para healthy (fuente: AWS ALB thresholds)
    unhealthy_threshold = 3      # Marca unhealthy tras 3 fallos consecutivos (fuente: AWS ALB thresholds)
  }

  tags = {                     # Tags del target group para trazabilidad (fuente: AWS tagging)
    Name = "restaurant-api-tg" # Nombre amigable del grupo de destino (fuente: convención del proyecto)
  }

  lifecycle {                    # Controla orden de reemplazo de recurso (fuente: Terraform lifecycle meta-arguments)
    create_before_destroy = true # Evita downtime creando nuevo target group antes de eliminar el anterior (fuente: Terraform zero-downtime pattern)
  }
}

# Adjuntar cada instancia API al target group en el puerto 8000.
resource "aws_lb_target_group_attachment" "api" {            # Adjunta cada EC2 API al target group (fuente: Terraform aws_lb_target_group_attachment)
  count            = 2                                       # Crea dos attachments, uno por cada réplica API (fuente: count en Terraform)
  target_group_arn = aws_lb_target_group.api.arn             # ARN del target group receptor (fuente: referencia entre recursos)
  target_id        = aws_instance.api_server[count.index].id # ID de instancia EC2 a registrar como target (fuente: aws_instance.id)
  port             = 8000                                    # Puerto de destino registrado en el target (fuente: backend app port)
}

# -----------------------------------------------------------------------------
# Sección 4 — Application Load Balancer y listener HTTP
# -----------------------------------------------------------------------------
# subnets: las dos primeras subnets en AZ distintas (requisito del ALB).
# security_groups: tráfico entrante al balanceador gestionado por alb_sg.

resource "aws_lb" "api" {                             # Crea Application Load Balancer público (fuente: Terraform aws_lb)
  name_prefix        = "rapalb"                       # Prefijo de nombre administrado por AWS (fuente: aws_lb name constraints)
  internal           = false                          # Indica balanceador internet-facing (fuente: AWS ALB scheme)
  load_balancer_type = "application"                  # Tipo L7 para tráfico HTTP/HTTPS (fuente: AWS ELB types)
  security_groups    = [aws_security_group.alb_sg.id] # SG que controla entrada al ALB (fuente: AWS ALB SG association)
  subnets            = slice(var.subnets, 0, 2)       # Selecciona al menos dos subnets para requisito multi-AZ (fuente: Terraform slice + AWS ALB requirement)

  tags = {                      # Tags del ALB para operación e inventario (fuente: AWS tagging)
    Name = "restaurant-api-alb" # Nombre de identificación del balanceador (fuente: convención del proyecto)
  }

  lifecycle {                    # Política de reemplazo para cambios de ALB (fuente: Terraform lifecycle)
    create_before_destroy = true # Minimiza indisponibilidad al recrear ALB (fuente: zero-downtime IaC)
  }
}

resource "aws_lb_listener" "http" {  # Configura listener HTTP del ALB (fuente: Terraform aws_lb_listener)
  load_balancer_arn = aws_lb.api.arn # Enlaza listener al ALB creado (fuente: AWS listener association)
  port              = 80             # Puerto público de entrada para clientes (fuente: HTTP standard)
  protocol          = "HTTP"         # Protocolo del listener en capa 7 (fuente: AWS ALB listeners)

  default_action {                                 # Acción por defecto cuando llega una solicitud al listener (fuente: AWS listener rules)
    type             = "forward"                   # Reenvía tráfico a target group (fuente: ALB action types)
    target_group_arn = aws_lb_target_group.api.arn # Destino backend de la acción forward (fuente: referencia TG)
  }
}

# -----------------------------------------------------------------------------
# Sección 5 — AWS Systems Manager Parameter Store
# -----------------------------------------------------------------------------
# Publicamos IPs (y DNS del ALB) para que aplicaciones o scripts lean valores
# sin hardcodear (patrón del ejemplo rabbitmq-postgresql-mongodb-students).
# Rutas bajo /message-queue/dev/restaurant-api/ para no chocar con otros labs.

resource "aws_ssm_parameter" "rabbitmq_ip" {                        # Publica IP de RabbitMQ en Parameter Store (fuente: Terraform aws_ssm_parameter)
  name        = "${var.ssm_parameter_prefix}/rabbitmq/public_ip"    # Ruta jerárquica del parámetro en SSM (fuente: AWS SSM parameter naming)
  type        = "String"                                            # Tipo de parámetro en texto plano (fuente: AWS SSM parameter types)
  value       = aws_instance.rabbitmq.public_ip                     # Valor dinámico tomado de la instancia EC2 (fuente: interpolación Terraform)
  description = "IP publica del servidor RabbitMQ (restaurant-api)" # Texto descriptivo para operadores (fuente: convención de documentación)
}

resource "aws_ssm_parameter" "api_alb_dns" {                                       # Publica DNS del ALB para consumo externo (fuente: AWS SSM + ALB)
  name        = "${var.ssm_parameter_prefix}/api/alb_dns_name"                     # Clave de parámetro bajo namespace del proyecto (fuente: estructura de paths SSM)
  type        = "String"                                                           # Almacena DNS como cadena (fuente: AWS SSM types)
  value       = aws_lb.api.dns_name                                                # Obtiene nombre DNS asignado por AWS al ALB (fuente: aws_lb attributes)
  description = "DNS publico del ALB; punto de entrada HTTP de la API (puerto 80)" # Explica uso del parámetro como endpoint base (fuente: arquitectura)
}

resource "aws_ssm_parameter" "api_instance_ips" {                                                 # Guarda IPs públicas de réplicas API para diagnóstico (fuente: AWS SSM parameters)
  name        = "${var.ssm_parameter_prefix}/api/instance_public_ips"                             # Nombre jerárquico para identificar el dato (fuente: convención SSM path)
  type        = "String"                                                                          # Se serializa como texto CSV en un solo parámetro (fuente: diseño actual)
  value       = join(",", aws_instance.api_server[*].public_ip)                                   # Une lista de IPs con comas (fuente: función Terraform join)
  description = "IPs publicas de las instancias API (diagnostico; trafico de usuarios va al ALB)" # Aclara uso no primario para tráfico cliente (fuente: diseño ALB)
}

resource "aws_ssm_parameter" "worker_ip" {                     # Publica IP del worker en SSM (fuente: Terraform aws_ssm_parameter)
  name        = "${var.ssm_parameter_prefix}/worker/public_ip" # Ruta estándar bajo prefijo del entorno (fuente: naming del proyecto)
  type        = "String"                                       # Tipo textual para dirección IP (fuente: AWS SSM parameter types)
  value       = aws_instance.worker.public_ip                  # Valor obtenido desde recurso EC2 worker (fuente: aws_instance.public_ip)
  description = "IP publica del Worker (restaurant-api)"       # Descripción de contenido para operadores (fuente: convención Terraform)
}

resource "aws_ssm_parameter" "postgres_ip" {                          # Publica IP del nodo PostgreSQL en Parameter Store (fuente: AWS SSM usage)
  name        = "${var.ssm_parameter_prefix}/postgres/public_ip"      # Clave de parámetro para endpoint de Postgres (fuente: esquema del proyecto)
  type        = "String"                                              # IP almacenada como texto (fuente: AWS SSM types)
  value       = aws_instance.postgres.public_ip                       # Referencia IP pública de instancia postgres (fuente: Terraform resource attribute)
  description = "IP publica del servidor PostgreSQL (restaurant-api)" # Contexto de lectura del parámetro (fuente: documentación operativa)
}

resource "aws_ssm_parameter" "mongodb_ip" {                        # Registra IP de MongoDB para consultas externas (fuente: AWS SSM Parameter Store)
  name        = "${var.ssm_parameter_prefix}/mongodb/public_ip"    # Ruta jerárquica del parámetro de Mongo (fuente: convención de paths)
  type        = "String"                                           # Tipo string para valor IP (fuente: AWS parameter type system)
  value       = aws_instance.mongodb.public_ip                     # Obtiene IP pública calculada por AWS (fuente: aws_instance.public_ip)
  description = "IP publica del servidor MongoDB (restaurant-api)" # Explica contenido para usuario operador (fuente: convención del proyecto)
}
