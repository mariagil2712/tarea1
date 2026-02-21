def taskEntity(task) -> dict:
    return{
        "taskId": task["taskId"],
        "status": task["status"],
        "error": task["error"],
    }

def tasksEntity(tasks) -> list:
    return [taskEntity(task) for task in tasks]

#Documentacion correspondiente en dishSchema.py