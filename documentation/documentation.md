Tarea1 progreso y explicación

1.	Borré las imágenes y los contenedores que tenía en Docker. Tanto my-running-app como mongodb

Verificar contenedores:  docker ps-a
Verificar imágenes:           docker images

2.	Docker descarga la imagen mongo y crea un contenedor, inicia el proceso mongodb con el puerto y las credenciales correspondientes


Para levantar contenedor con mongoDB
docker run -d \
--name mongo_cloud \
-p 27017:27017 \
-e MONGO_INITDB_ROOT_USERNAME=admin \
-e MONGO_INITDB_ROOT_PASSWORD=admin123 \
mongo:latest
Esto es si queremos levantar un solo servicio


Para levantar varios servicios como usamos en este proyecto:
docker-compose up -d 
Esto es porque buscamos levantar servicios, no contenedores, y estos deben estar separados
Para el uso de buenas practicas, y esto se define en el archivo docker-compose.yml

Haciendo docker ps aparece ahora: 

En este punto la maquina ya puede conectarse usando localhost:27017

3.	Creé tarea1 (carpeta), en ella, se crea el entorno virtual

python3 -m venv .venv
source .venv/bin/actívate

Ahora la terminal se ve así:

 

Esto me confirma que me encuentro en el entorno virtual. Todas las librerías que instale ahora quedan aisladas en .venv/. A propósito de eso, venv es un módulo incorporado en Python diseñado para crear entornos virtuales ligeros y aislados.

Para desactivar el entorno en esa terminal en específico, se usa el comando deactivate

4.	pip install pymongo

Pymongo es un paquete de Python que facilita la conexión y comunicación con mongodb.

Ejecutando pip list muestra:

 

OJO:

El botón de run de visual usa el intérprete global por defecto, sin identificar el (.venv), por eso falla aunque el entorno este activado en la terminal.

Solución

En visual ejecutar:

Command + Shift + P

Escribir:

Python: Select Interpreter

Seleccionar:

 

5.	Creé el archivo prueba_mongo.py para aprender a insertar y consultar documentos.

from pymongo import MongoClient

Para la instalación de FastAPI, el framework más común en arquitecturas REST API, se ejecuta el comando

pip install "fastapi[standard]"

y para usar dicho framework en main.py debemos usar

from fastapi import FastAPI

client = MongoClient("mongodb://admin:password@localhost:27017/")

db = client["mi_base"]

collection = db["usuarios"]

documento = {
    "nombre": "Maria",
    "edad": 21
}

resultado = collection.insert_one(documento)

print("Inserted document id:", resultado.inserted_id)
Donde MongoClient es la clase que crea la conexión al servidor Mongo, y por lo tanto client es una instancia de MongoClient. 

client[“mi_base”] devuelve un objeto de tipo Database, en este caso llamado db.
Asimismo, db[“usuarios”] devuelve un objeto de tipo Collection, llamado collection en este caso. NO significa que collection sea de tipo database, collection es de tipo collection, solo que lo obtengo a partir de un database.

En mongodb, tanto la base de datos como la colección se crean automáticamente cuando se inserta el primer documento. -> con documento nos referimos a un objeto de tipo JSON.

Cada documento se almacena como registro separado e independiente uno del otro. Es decir, puedo insertar varios “documentos” en la misma colección misma base de datos pero NO están en una especie de archivo continuo cada cosa debajo de la otra.

*Es importante aclar que mongodb agrega automáticamente a cada documento un identificador único _id.

Definición de documento

Un documento es una estructura de datos tipo JSON (en realidad BSON para el computador) compuesta por pares clave-valor. Formalmente es un objeto, con claves y valores.

La única regla que siempre cumple un documento es tener el identificador (automático) único de mongodb. De resto, Mongodb no tiene un esquema fijo y permite meter cualquier cosa que siga esta estructura a tu colección. Es decir, podría tener una colección que tenga tanto “objetos” que describan una película (titulo, año, director) como objetos que describan personas “nombre, cc, edad” y mongo no nota la inconsistencia. Por eso, hay que ser cuidadoso con qué documento se mete en qué colección pues en caso de equivocaciones no hay alerta de parte de mongodb. En cambio, esta verificación se hace desde el backend del API

Insertar un documento en mongodb

Hay múltiples maneras de insertar un documento a una colección. 

Para insertar uno por uno, se utiliza collection.insert_one()   , esto crea un solo documento, al invocarlo de nuevo después se crea un documento nuevo distinto.

Para insertar varios documentos de una vez se utiliza collection.insert_many()   , creando varios documentos separados en la misma colección.

Hay otra posibilidad y es crear o almacenar varios “objetos” en un mismo documento y es insertando una lista dentro del documento y ahí almacenando la cantidad de objetos deseada.

Por ejemplo:

collection.insert_one({
    "peliculas": [
        {"titulo": "Inception", "anio": 2010},
        {"titulo": "Interstellar", "anio": 2014}
    ]
})

Eso sería un documento con un campo llamado películas que contiene un arreglo.

OJO:

Ejecutar el código de prueba varias veces hace que se cree ese mismo documento varias veces. Mongo NO impide que se repita el documento, de hecho, habrá una cantidad de copias con la misma info pero con id diferente de repetirse muchas veces.

¿Cómo evitar esto?

1.	Validar antes de insertar 

existe = collection.find_one({"titulo": "Inception"})

if not existe:
    collection.insert_one({...})


2.	Crear un índice único (pertinente según el objeto)

collection.create_index("titulo", unique=True)


Estructura utilizada:

tarea1/
├── api/
│   ├── main.py          # FastAPI app + include_router
│   ├── database.py      # Conexión MongoDB + get_db / get_collection
│   └── routes/
│       ├── dishes.py    # Router de platos
│       └── tasks.py     # Router de tareas
├── models/
│   ├── dish.py          # Pydantic: Plato, PlatoCreate, etc.
│   └── task.py          # Pydantic: TaskResponse, TaskStatus
└── requirements.txt


Para Arrancar el servidor, debemos usar el siguiente comando:
    uvicorn api.main:app --reload

    Esto es que usaremos la carpeta api, donde dentro hay un archivo main, con una
    función app que inicializa la instancia de FastAPI, y --reload para recargar el servidor cada vez que realicemos un cambio dentro de las carpetas

