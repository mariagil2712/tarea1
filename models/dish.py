#Archivo encargado de interactuar con la base de datos
#BaseModel es un modelo de pydantic que permite definir un modelo base para el plato
from pydantic import BaseModel

#Clase creada para crear un plato, solo lo crea aun no se publica en la base de datos
class DishCreate(BaseModel):
    name: str
    price: float
    ingredients: list[str] = []

#Clase para lo que uno postea, que requiere de un body que valida el JSON del cuerpo contra un modelo establecido
#Este se encarga de crear el iD para publicarlo en la base de datos, el cual es un UUID
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