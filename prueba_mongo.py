from pymongo import MongoClient

# Crear cliente
client = MongoClient("mongodb://admin:admin123@localhost:27017/")

# Seleccionar base de datos
db = client["tarea1_db"]

# Seleccionar colección
collection = db["movies"]

# Documento a insertar
movie = {
    "title": "The Matrix",
    "year": 1999
}

# Insertar documento
result = collection.insert_one(movie)

print("Inserted document ID:", result.inserted_id)
