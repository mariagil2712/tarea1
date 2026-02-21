from pydantic import BaseModel
from typing import Optional #Librería utilziada para definir tipos de campos opcionales
import uuid #Librería utilizada para generar IDs únicos para las tareas
from datetime import datetime #Librería utilizada para obtener la fecha y hora actual
#Creamos dos tipos de clase, uno para lo que uno Postea y otro para lo que uno Obtiene

#Clase Para lo que uno Postea, que requiere de un Body que valida el JSON del cuerpo contra un modelo establecido
#Por pydantic, cuyo cuerpo es la informacion que se envia a la base de datos, e inyecta el objeto en la función
class TaskPost(BaseModel):
    taskId: str
    status: str
    payload: dict
    error: Optional[str] = None
    createdAt: int = int(datetime.timestamp(datetime.now()))
    updatedAt: int = int(datetime.timestamp(datetime.now()))
#Clase para lo que uno obtiene, se declara con response_model en el router
class TaskResponse(BaseModel):
    taskId: str
    status: str
    error: Optional[str] = None
    createdAt: int = int(datetime.timestamp(datetime.now()))
    updatedAt: int = int(datetime.timestamp(datetime.now()))