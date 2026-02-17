#Funcion que convierte los datos de un plato en un diccionario para proceder a retornarlo al usuario
def individualDishData(todo_data):
    return{
        "id": str(todo_data["_id"]),
        "name": todo_data["name"],
        "price": todo_data["price"],
        "ingredients": list[str](todo_data["ingredients"])
    }