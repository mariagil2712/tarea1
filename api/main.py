from fastapi import FastAPI 
from api.routes.dishes import dish #Importar el router de platos
from api.routes.tasks import task #Importar el router de tareas
app = FastAPI() #Inicializar instancia de FastAPI

#Registrar el router de platos con prefijo /dishes para que las rutas sean GET /dishes y GET /dishes/{dish_id}
app.include_router(dish, prefix="/dishes", tags=["dishes"])
app.include_router(task, prefix="/tasks", tags=["tasks"])

@app.get("/") #Decordador que define la ruta principal de la API
def read_root():
    return{"message": "Hello World"}