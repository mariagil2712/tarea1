import os
from pymongo import MongoClient

# Creacion de cliente con URI conectada a la base de datos de mongoDB compass
MONGO_URI = os.getenv("MONGO_URI", "mongodb://admin:admin123@localhost:27017/")
client = MongoClient(MONGO_URI)
#Seleccionar la base de datos
db = client.tarea1_db

# Colecciones para la API de platos y tasks
dishes_collection = db["dishes"]
tasks_collection = db["tasks"]

def get_dishes_collection():
    return dishes_collection

def get_tasks_collection():
    return tasks_collection