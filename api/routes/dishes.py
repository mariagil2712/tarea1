import uuid
from fastapi import APIRouter, HTTPException, Depends, BackgroundTasks
from bson import ObjectId

from api.database import get_platos_collection, get_tasks_collection
from models.dish import DishCreate, DishResponse

router = APIRouter()

def docToResponse(doc: dict) -> dict:
    doc = dict(doc)
    doc["id"] = str(doc.pop("_id"))
    return doc

@router.get("/", response_model=list[DishResponse])
def list_dishes(collection = Depends(get_platos_collection)):
    return [docToResponse(doc) for doc in collection.find()]