from datetime import date
from fastapi import APIRouter, Depends, HTTPException, Query

from app.auth.deps import Principal, get_current_user
from app.api.deps import get_dashboard_service
from app.services.dashboard_service import DashboardService

router = APIRouter(prefix="/dashboard", tags=["dashboard"])


@router.get("/", summary="Daily dashboard (targets + intake + progress)")
def daily_dashboard(
    date_: date | None = Query(None, alias="date", description="Day to fetch (YYYY-MM-DD). Defaults to today"),
    user: Principal = Depends(get_current_user),
    svc: DashboardService = Depends(get_dashboard_service),
):
    day = date_ or date.today()
    try:
        return svc.get_daily_dashboard(user.uid, day)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/weekly", summary="Weekly summary for last completed week (Mon-Sun) or specified week_start (YYYY-MM-DD = monday)")
def weekly_dashboard(
    week_start: date | None = Query(None, description="Monday of the week to fetch. If omitted returns last completed week."),
    user: Principal = Depends(get_current_user),
    svc: DashboardService = Depends(get_dashboard_service),
):
    try:
        return svc.get_weekly_summary(user.uid, week_monday=week_start)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/monthly", summary="Monthly summary for last completed month or specified month_start")
def monthly_dashboard(
    month_start: date | None = Query(None, description="Any date in the month to fetch (YYYY-MM-DD). If omitted returns last completed month."),
    user: Principal = Depends(get_current_user),
    svc: DashboardService = Depends(get_dashboard_service),
):
    try:
        return svc.get_monthly_summary(user.uid, month_start=month_start)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.get("/timeseries", summary="Arbitrary time-series for range (charting)")
def timeseries(
    start: date = Query(..., description="Start date (YYYY-MM-DD)"),
    end: date = Query(..., description="End date (YYYY-MM-DD)"),
    user: Principal = Depends(get_current_user),
    svc: DashboardService = Depends(get_dashboard_service),
):
    try:
        return svc.get_time_series(user.uid, start, end)
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))
