from pydantic import BaseModel
from datetime import datetime

# Modelo del plato, lo que se va a enviar al cliente
class DishCreate(BaseModel):
    name: str
    price: float
    ingredients: list[str] = []
    creation: int = int(datetime.timestamp(datetime.now()))
    updatedAt: int = int(datetime.timestamp(datetime.now()))

#Plato como lo devolverá la API
class DishResponse(BaseModel):
    id: str
    name: str
    price: float
    ingredients: list[str] = []

    class Config:
        from_attributes = True
