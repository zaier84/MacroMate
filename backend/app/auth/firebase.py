import os
import firebase_admin
from firebase_admin import credentials, auth
from app.core.config import settings

_initialized = False

def init_firebase():
    global _initialized
    if _initialized:
        return
    cred_path = settings.GOOGLE_APPLICATION_CREDENTIALS
    if not os.path.exists(cred_path):
        raise RuntimeError(f"Firebase service account not found at {cred_path}")
    
    cred = credentials.Certificate(cred_path)
    firebase_admin.initialize_app(cred)
    _initialized = True

def verify_id_token(id_token: str) -> dict:
    decoded = auth.verify_id_token(id_token, check_revoked=True)
    return decoded

def revoke_user(uid: str):
    auth.revoke_refresh_tokens(uid)
