"""CSV generation for one ISO week of meetings."""

import asyncio
import csv
import io
import re
from datetime import date, datetime, time, timedelta
from zoneinfo import ZoneInfo

from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import async_sessionmaker, create_async_engine
from sqlalchemy.pool import NullPool

from app.config import settings
from app.models import Meeting, meeting_participants

WEEK_PATTERN = re.compile(r"^(\d{4})-W(\d{2})$")
REPORT_TIMEZONE = ZoneInfo("Europe/Kyiv")


def _bounds(week: str) -> tuple[datetime, datetime]:
    match = WEEK_PATTERN.fullmatch(week)
    if not match:
        raise ValueError("week must use ISO format YYYY-Www, for example 2026-W40")
    monday = date.fromisocalendar(int(match[1]), int(match[2]), 1)
    start = datetime.combine(monday, time.min, REPORT_TIMEZONE)
    end = datetime.combine(monday + timedelta(days=7), time.min, REPORT_TIMEZONE)
    return start, end


async def _rows(
    session_factory: async_sessionmaker, start: datetime, end: datetime
) -> list[dict[str, object]]:
    participant_counts = (
        select(
            meeting_participants.c.meeting_id,
            func.count(meeting_participants.c.participant_id).label("participant_count"),
        )
        .group_by(meeting_participants.c.meeting_id)
        .subquery()
    )
    async with session_factory() as session:
        result = await session.execute(
            select(
                Meeting.title,
                Meeting.starts_at,
                Meeting.ends_at,
                func.coalesce(participant_counts.c.participant_count, 0),
            )
            .outerjoin(participant_counts, Meeting.id == participant_counts.c.meeting_id)
            .where(Meeting.starts_at >= start, Meeting.starts_at < end)
            .order_by(Meeting.starts_at)
        )
        return [
            {
                "title": row[0],
                "starts_at": row[1],
                "duration_minutes": (row[2] - row[1]).total_seconds() / 60,
                "participants": row[3],
            }
            for row in result
        ]


async def _week_rows(start: datetime, end: datetime) -> tuple[list[dict[str, object]], list[dict[str, object]]]:
    # This sync entry point uses a fresh event loop per invocation. A non-pooling engine avoids
    # carrying asyncpg connections from one Lambda invocation's loop into the next.
    engine = create_async_engine(settings.database_url, poolclass=NullPool)
    session_factory = async_sessionmaker(engine, expire_on_commit=False)
    try:
        return (
            await _rows(session_factory, start, end),
            await _rows(session_factory, start - timedelta(days=7), start),
        )
    finally:
        await engine.dispose()


def build_weekly_report(week: str) -> bytes:
    """Query meetings for an ISO week and return a UTF-8 CSV document."""
    start, end = _bounds(week)
    current_rows, previous_rows = asyncio.run(_week_rows(start, end))

    def total(rows: list[dict[str, object]]) -> float:
        return sum(float(row["duration_minutes"]) for row in rows) / 60

    this_hours, previous_hours = total(current_rows), total(previous_rows)
    output = io.StringIO(newline="")
    writer = csv.writer(output)
    writer.writerow(["Weekly meetings report", week])
    writer.writerow(["period", "meeting_count", "total_hours"])
    writer.writerow([week, len(current_rows), f"{this_hours:.2f}"])
    writer.writerow(["previous week", len(previous_rows), f"{previous_hours:.2f}"])
    writer.writerow(["change", len(current_rows) - len(previous_rows), f"{this_hours - previous_hours:+.2f}"])
    writer.writerow([])
    writer.writerow(["Five longest meetings"])
    writer.writerow(["title", "starts_at", "duration_minutes", "participants"])
    for row in sorted(current_rows, key=lambda item: float(item["duration_minutes"]), reverse=True)[:5]:
        starts_at = row["starts_at"]
        writer.writerow(
            [row["title"], starts_at.isoformat(), f"{float(row['duration_minutes']):.0f}", row["participants"]]
        )
    return output.getvalue().encode("utf-8-sig")
