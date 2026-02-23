FROM python:3.11-slim 
# Version pequeña de python
WORKDIR /code
#Directorio de trabajo
COPY . .
#Coge todo dentro del directorio de DockerFIle y lo mete dentro del 
#contenedor en el directorio de trabajo code estipulado en la linea 3
RUN pip install --no-cache-dir -r requirements.txt
#Instalacion de dependencias de requirements.txt sin reduccion del tamaño de la imagen
CMD ["uvicorn", "api.main:app", "--host", "0.0.0.0", "--port", "8000"]
#Define el comando que se ejecuta cuando arranca un contenedor
#Contenedor arranca la API con uvicorn en el puerto 8000 en el host 0.0.0.0,
#Que posteriormente el compose mapea al puerto 5001 del host
