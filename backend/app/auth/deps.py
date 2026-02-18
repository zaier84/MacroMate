from fastapi import Depends, Header, HTTPException
from app.auth.firebase import verify_id_token

class Principal:
    def __init__(self, claims: dict):
        self.uid: str = claims["uid"]
        self.email: str | None = claims.get("email")
        self.name: str | None= claims.get("name")
        self.picture: str |None = claims.get("picture")
        self.email_verified: bool = claims.get("email_verified", False)


def get_current_user(authorization: str = Header(default="", alias="Authorization")) -> Principal:
    if not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Missing Bearer token")
    token = authorization.split(" ", 1)[1].strip()

    try:
        claims = verify_id_token(token)
    except Exception as e:
        print(e)
        raise HTTPException(status_code=401, detail="Invalid or expired token")

    return Principal(claims)
        
