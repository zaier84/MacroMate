from fastapi import APIRouter, Depends, Query
from datetime import date

from app.api.deps import get_db
from app.auth.deps import get_current_user, Principal
from app.services.progress_service import ProgressService

router = APIRouter(prefix="/progress", tags=["progress"])

@router.get("/monthly")
def get_monthly_progress(
    month: str | None = Query(None, description="YYYY-MM"),
    user: Principal = Depends(get_current_user),
    db=Depends(get_db),
):
    today = date.today()

    if month:
        year, month_num = map(int, month.split("-"))
    else:
        year, month_num = today.year, today.month

    svc = ProgressService(db)
    return svc.get_monthly_progress(user.uid, year, month_num)

