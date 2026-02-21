from fastapi import APIRouter, HTTPException
from api.database import get_tasks_collection
from schemas.taskSchema import taskEntity
from models.task import TaskResponse

task = APIRouter()

@task.get("/{task_id}", response_model=TaskResponse)
def get_task_by_id(task_id: str):
    collection = get_tasks_collection()
    doc = collection.find_one({"taskId": task_id})
    if doc is None:
        raise HTTPException(status_code=404, detail=f"Tarea no encontrada con taskId: {task_id}")
    return taskEntity(doc)