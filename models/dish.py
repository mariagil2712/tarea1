#Archivo encargado de interactuar con la base de datos
#BaseModel es un modelo de pydantic que permite definir un modelo base para el plato
from pydantic import BaseModel

#Clase para lo que uno postea, que requiere de un body que valida el JSON del cuerpo contra un modelo establecido
class DishPost(BaseModel):
    id: str
    name: str
    price: float
    ingredients: list[str]

#Clase para lo que uno obtiene, se declara con response_model en el router
class DishResponse(BaseModel):
    id: str
    name: str
    price: float
    ingredients: list[str]