from pymongo import MongoClient

# Creacion de cliente con URI conectada a la base de datos de mongoDB compass
client = MongoClient("mongodb://admin:admin123@localhost:27017/")
#Seleccionar la base de datos
db = client["tarea1_db"]

# Colecciones para la API de platos y tasks
platos_collection = db["platos"]
tasks_collection = db["tasks"]

def get_platos_collection():
    return platos_collection

def get_tasks_collection():
    return tasks_collection