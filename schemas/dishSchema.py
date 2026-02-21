#Esquema de datos, para determinar qué va a llevar cada plato

#Esto puede sonar redundante, ya que la dishEntity retornará los mismos datos que le
#ingresamos, pero esto servirá para luego poder especificar qué datos retornará la API
#A nivel de documentación, seguridad y control de acceso.
def dishEntity(dish) -> dict:   #Se crea una entidad la cual va a recibir un plato y va a retornar un diccionario con la informacion del plato
    return {
        "id": str(dish["_id"]),
        "name": dish["name"],
        "price": dish["price"],
        "ingredients": dish["ingredients"]
    }

def dishesEntity(dishes) -> list:
    return [dishEntity(dish) for dish in dishes]
    #Recorre una lista de platos y retorna una lista de diccionarios
    # con dichos platos en la base de datos