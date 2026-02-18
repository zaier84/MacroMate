from datetime import date
from fastapi import APIRouter, Depends, Query, HTTPException

from app.api.deps import get_db
from app.auth.deps import get_current_user, Principal
from app.services.diary_service import DiaryService

router = APIRouter(prefix="/diary", tags=["diary"])


@router.get("")
def get_diary(
    diary_date: date | None = Query(default=None, alias="date"),
    user: Principal = Depends(get_current_user),
    db = Depends(get_db),
):
    try:
        svc = DiaryService(db)
        return svc.get_daily_diary(
            user.uid,
            diary_date or date.today(),
        )
    except Exception as e:
        print(e)
        raise HTTPException(status_code=500, detail="Failed to load diary")

