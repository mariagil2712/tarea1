from fastapi import APIRouter, HTTPException
from api.database import get_tasks_collection
from schemas.taskSchema import taskEntity, tasksEntity
from models.task import TaskResponse, TaskPost

from bson import ObjectId
task = APIRouter()

@task.get(f"/task/{task_id}", response_model=TaskResponse)
def get_task(task_id: str):
    try:
        oId = ObjectId(task_id)
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Invalid taskId format")
    collection = get_tasks_collection()
    it = collection.find_one({"taskId": oId})
    if it is None:
        raise HTTPException(status_code=404, detail=f"No Task Found with iD: {task_id}")
    return taskEntity(it)