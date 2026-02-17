from fastapi import FastAPI 

app = FastAPI() #Inicializar instancia de FastAPI

@app.get("/") #Decordador que define la ruta principal de la API
def read_root():
    return{"message": "Hello World"}