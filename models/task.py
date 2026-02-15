from pydantic import BaseModel

class TaskResponse(BaseModel):
    taskId: str
    status: str