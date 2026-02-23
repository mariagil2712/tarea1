import json
import os
import pika
from pymongo import MongoClient
from bson import ObjectId
from datetime import datetime

# conecta a mongo
MONGO_URI = os.getenv("MONGO_URI", "mongodb://admin:admin123@localhost:27017/")
client = MongoClient(MONGO_URI)
db = client.tarea1_db
dishes_collection = db["dishes"]
tasks_collection = db["tasks"]

# nombre de la cola (mismo que en rabbitmq.py)
QUEUE_NAME = os.getenv("RABBITMQ_QUEUE", "dish_tasks")

def update_task(task_id: str, status: str, error: str = None):
    """Actualiza el status de una tarea en MongoDB"""
    tasks_collection.update_one(
        {"taskId": task_id},
        {"$set": {
            "status": status,
            "error": error,
            "updatedAt": int(datetime.timestamp(datetime.now()))
        }}
    )


#lo q sigue se ejecuta cada vez q llega un mensaje a la cola. ch es el canal de rabbitmq.
#method son los metadatos del mensaje y body el contendio en bytes
def process_message(ch, method, properties, body): 
    try:
        message = json.loads(body)  #convierte el JSON del mensaje a dict
        task_id = message["taskId"]
        payload = message["payload"]
        action = payload.get("action", "create")  # si no hay action, asume create (POST)

        print(f"[Worker] Procesando tarea {task_id}, acción: {action}")

        if action == "delete":
            # Tarea de DELETE: borrar el plato de MongoDB
            dish_id = payload["dish_id"]
            result = dishes_collection.delete_one({"_id": ObjectId(dish_id)})
            if result.deleted_count == 0:
                update_task(task_id, "error", f"Plato no encontrado con id: {dish_id}")
            else:
                update_task(task_id, "done")

        else:
            # POST: insertar el plato en MongoDB
            dishes_collection.insert_one(payload)
            update_task(task_id, "done")

        # OJO: ACK: le dice a RabbitMQ que el mensaje fue procesado exitosamente
        # OJO: Si no se hace ACK, RabbitMQ reintentará el mensaje
        ch.basic_ack(delivery_tag=method.delivery_tag)
        print(f"[Worker] Tarea {task_id} completada con status: done")

    except Exception as e:
        print(f"[Worker] Error procesando mensaje: {e}")
        if task_id != "unknown":
            update_task(task_id, "error", str(e))
        ch.basic_ack(delivery_tag=method.delivery_tag)  # ACK igual para sacar el mensaje de la cola


def main():
    # Conexión a RabbitMQ
    host = os.getenv("RABBITMQ_HOST", "localhost")
    port = int(os.getenv("RABBITMQ_PORT", "5672"))
    user = os.getenv("RABBITMQ_USER", "user")
    password = os.getenv("RABBITMQ_PASSWORD", "password")

    credentials = pika.PlainCredentials(user, password)
    params = pika.ConnectionParameters(host=host, port=port, credentials=credentials)
    connection = pika.BlockingConnection(params)
    channel = connection.channel()

    # Declara la misma cola que usa la API (idempotente: si ya existe no falla)
    channel.queue_declare(queue=QUEUE_NAME, durable=True)

    # Le dice a RabbitMQ: "solo dame 1 mensaje a la vez, espera a que haga ACK antes del siguiente"
    channel.basic_qos(prefetch_count=1)

    # Registra la función process_message como callback para cuando llegue un mensaje
    channel.basic_consume(queue=QUEUE_NAME, on_message_callback=process_message)

    print(f"[Worker] Esperando mensajes en la cola '{QUEUE_NAME}'. Ctrl+C para salir.")
    channel.start_consuming()  # Bucle infinito que escucha la cola


if __name__ == "__main__":
    main()