FROM python:3.11-slim 
# Version pequeña de python
WORKDIR /code
#Directorio de trabajo
RUN pip install flask pika
#Instalacion de framework flask, cache redis y pika para rabbitMQ
COPY . .
#Coge todo dentro del directorio de DockerFIle y lo mete dentro del 
#contenedor en el directorio de trabajo code estipulado en la linea 3
CMD ["python", "app.py"]
#Define el comando que se ejecuta cuando arranca un contenedor
