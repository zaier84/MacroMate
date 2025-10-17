from fastapi import APIRouter, Depends
from app.auth.deps import Principal, get_current_user

router = APIRouter(prefix="/protected", tags=["protected"])

@router.get("/ping")
def ping(user: Principal = Depends(get_current_user)):
    return {"ok": True, "uid": user.uid}
