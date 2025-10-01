from fastapi import APIRouter, Depends
from app.auth.deps import get_current_user, Principal
from app.auth.firebase import revoke_user

router = APIRouter(prefix="/auth", tags=["auth"])

@router.get("/me")
def me(user: Principal = Depends(get_current_user)):
    return {
        "uid": user.uid,
        "email": user.email,
        "name": user.name,
        "picture": user.picture,
        "email_verified": user.email_verified,
    }

@router.post("/revoke")
def revoke(user: Principal = Depends(get_current_user)):
    revoke_user(user.uid)
    return {"status": "revoked"}
