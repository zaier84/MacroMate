import tempfile
import json
import firebase_admin
from firebase_admin import credentials, auth
from app.core.config import settings

def init_firebase():
    # Option 1: GOOGLE_APPLICATION_CREDENTIALS points to a file path (already set in env)
    if settings.GOOGLE_APPLICATION_CREDENTIALS:
        cred = credentials.Certificate(settings.GOOGLE_APPLICATION_CREDENTIALS)
        firebase_admin.initialize_app(cred)
        return

    # Option 2: FIREBASE_SERVICE_ACCOUNT_JSON contains JSON string
    sa_json = settings.FIREBASE_SERVICE_ACCOUNT_JSON
    if sa_json:
        try:
            # If it's JSON string, write to temp file and init
            data = sa_json
            if isinstance(sa_json, str):
                # try parse to assert valid json, else assume already JSON string
                try:
                    json.loads(sa_json)
                except Exception:
                    pass
            tmp = tempfile.NamedTemporaryFile(delete=False, suffix=".json")
            tmp.write(sa_json.encode("utf-8"))
            tmp.flush()
            tmp.close()
            cred = credentials.Certificate(tmp.name)
            firebase_admin.initialize_app(cred)
            return
        except Exception:
            # Let initialization fail loudly if incorrect
            raise

    # fallback: try default app token or raise
    # If no credentials provided, you may want to raise or fallback to non-initialized state.
    raise RuntimeError("Firebase service account not configured. Set GOOGLE_APPLICATION_CREDENTIALS or FIREBASE_SERVICE_ACCOUNT_JSON")

def verify_id_token(id_token: str) -> dict:
    decoded = auth.verify_id_token(id_token, check_revoked=True)
    return decoded

def revoke_user(uid: str):
    auth.revoke_refresh_tokens(uid)
