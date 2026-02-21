import os
# Para leer variables de entorno (RABBITMQ_HOST, RABBITMQ_QUEUE, etc.) y así configurar la conexión sin hardcodear.

import json
# Para convertir el mensaje (dict) a string antes de enviarlo a la cola; RabbitMQ envía y recibe bytes/string.

import pika
# Cliente de RabbitMQ en Python; permite conectarse al broker, declarar colas y publicar/consumir mensajes.

QUEUE_NAME = os.getenv("RABBITMQ_QUEUE", "dish_tasks")
# Nombre de la cola donde se publican las tareas de platos. Si no hay env, se usa "dish_tasks". El worker debe consumir de la misma cola.

def get_connection_params():
    host = os.getenv("RABBITMQ_HOST", "localhost")
    # Host del broker: en Docker es "rabbitmq" (nombre del servicio), en local "localhost".
    port = int(os.getenv("RABBITMQ_PORT", "5672"))
    # Puerto AMQP por defecto de RabbitMQ.
    user = os.getenv("RABBITMQ_USER", "user")
    password = os.getenv("RABBITMQ_PASSWORD", "password")
    # Credenciales definidas en docker-compose (user/password).
    credentials = pika.PlainCredentials(user, password)
    # Objeto que pika usa para autenticarse con el broker.
    return pika.ConnectionParameters(host=host, port=port, credentials=credentials)
    # Parámetros de conexión (sin conectar aún); quien llame los usa para abrir la conexión.

def publish_dish_task(task_id: str, dish_payload: dict):
    params = get_connection_params()
    # Obtiene host, puerto y credenciales desde variables de entorno.
    connection = pika.BlockingConnection(params)
    # Abre la conexión TCP con RabbitMQ (bloqueante hasta que se establece).
    channel = connection.channel()
    # Crea un canal sobre la conexión; por el canal se declaran colas y se publican mensajes.
    channel.queue_declare(queue=QUEUE_NAME, durable=True)
    # Declara la cola: si no existe se crea. durable=True hace que la cola sobreviva reinicios del broker.
    body = json.dumps({"taskId": task_id, "payload": dish_payload})
    # Cuerpo del mensaje: taskId para que el worker actualice la tarea, payload con los datos del plato a insertar.
    channel.basic_publish(exchange="", routing_key=QUEUE_NAME, body=body)
    # exchange="" significa cola directa; routing_key es el nombre de la cola; body es el mensaje en string.
    connection.close()
    # Cierra la conexión y libera recursos.
