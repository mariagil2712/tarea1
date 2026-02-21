from fastapi import APIRouter, HTTPException #Librerías utilizadas para que FastAPI devuelva una respuesta de error con codigo HTTP y un mensaje 
from schemas.dishSchema import dishesEntity, dishEntity
from api.database import get_dishes_collection
from models.dish import DishResponse, DishPost

from bson import ObjectId #Librería utilizada para convertir el id de la base de datos a un objeto ObjectId, para que 
                            #cuando mongoDB busque un iD, (su identificador es "_id") sea correspondiente a su tipo ObjectId

#APIRouter es un modulo de FastAPI que permite crear y definir rutas para la API
dish = APIRouter() 
#Response Model es un decorador que permite especificar el modelo de respuesta que se va a devolver, ideal para documentación en Swagger
@dish.get("/dish", response_model=DishResponse)
def get_dishes():
    collection = get_dishes_collection()
    it = collection.find() #Puntero sobre el resultado de la consulta
    return dishesEntity(list(it))

@dish.post("dish")
def create_dish():
    return "hello world"

@dish.get("/dish/{dish_id}")
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

