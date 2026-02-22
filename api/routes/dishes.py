from fastapi import APIRouter, HTTPException #Librerías utilizadas para que FastAPI devuelva una respuesta de error con codigo HTTP y un mensaje 
from schemas.dishSchema import dishesEntity, dishEntity
from api.database import get_dishes_collection, get_tasks_collection
from models.dish import DishResponse, DishCreate
from datetime import datetime
from api.rabbitmq import publish_dish_task
from pymongo import ReturnDocument 

from bson import ObjectId #Librería utilizada para convertir el id de la base de datos a un objeto ObjectId, para que 
                            #cuando mongoDB busque un iD, (su identificador es "_id") sea correspondiente a su tipo ObjectId
import uuid #Librería utilizada para generar UUIDs unicos

#APIRouter es un modulo de FastAPI que permite crear y definir rutas para la API
dish = APIRouter() 

#Response Model es un decorador que permite especificar el modelo de respuesta que se va a devolver, ideal para documentación en Swagger
@dish.get("/", response_model=list[DishResponse])
def get_dishes():
    collection = get_dishes_collection()
    it = collection.find() #Puntero sobre el resultado de la consulta
    return dishesEntity(list(it))

@dish.post("/")
def create_dish(body: DishCreate):
    taskId = str(uuid.uuid4()) #Genera un UUID unico para la tarea
    payload = body.model_dump()
    task = {
        "taskId": taskId,
        "status": "running",
        "payload": payload,
        "error": None,
        "createdAt": int(datetime.timestamp(datetime.now())),
        "updatedAt": int(datetime.timestamp(datetime.now())),
    }
    tasks_collection = get_tasks_collection()
    tasks_collection.insert_one(task)
    publish_dish_task(taskId, payload)
    return{"taskId": taskId, "status": "running"}

@dish.get("/{dish_id}")
def get_dish(dish_id: str):
    try: #Primero verifica que el iD sea valido, que esté en el formato valid de ObjectId(24 caracteres hexadecimales)
        oId = ObjectId(dish_id)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Invalid dishId format") #Si no es valido, deuvelve error 400 con mensaje de error
    collection = get_dishes_collection()
    it = collection.find_one({"_id": oId})
    if it is None: #Si no encuentra el plato, devuelve error 404 con mensaje de error
        raise HTTPException(status_code=404, detail=f"No Dish Found with iD: {dish_id}")
    return dishEntity(it)

@dish.put("/{dish_id}", response_model=DishResponse)
def update_dish(dish_id: str, body: DishCreate):
    try:
        oId = ObjectId(dish_id)
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid dishId format")
    
    collection = get_dishes_collection()
    updated = collection.find_one_and_update(
        {"_id": oId},
        {"$set": body.model_dump()},
        return_document=ReturnDocument.AFTER  # Retorna el documento ya actualizado
    )
    if updated is None:
        raise HTTPException(status_code=404, detail=f"No Dish Found with iD: {dish_id}")
    return dishEntity(updated)


@dish.delete("/{dish_id}")
def delete_dish(dish_id: str):
    try:
        ObjectId(dish_id)  # Solo valida el formato, no busca aún
    except Exception:
        raise HTTPException(status_code=400, detail="Invalid dishId format")
    
    taskId = str(uuid.uuid4())
    task = {
        "taskId": taskId,
        "status": "running",
        "payload": {"dish_id": dish_id},
        "error": None,
        "createdAt": int(datetime.timestamp(datetime.now())),
        "updatedAt": int(datetime.timestamp(datetime.now())),
    }
    tasks_collection = get_tasks_collection()
    tasks_collection.insert_one(task)
    publish_dish_task(taskId, {"action": "delete", "dish_id": dish_id})
    return {"taskId": taskId, "status": "running"}