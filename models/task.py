from pydantic import BaseModel

class TaskResponse(BaseModel):
    taskId: str
    status: str
    creation: int = int(datetime.timestamp(datetime.now()))
    updatedAt: int = int(datetime.timestamp(datetime.now()))