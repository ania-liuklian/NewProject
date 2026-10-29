"""Store meeting agendas and their AI suggestions."""

from collections.abc import Sequence

import sqlalchemy as sa
from sqlalchemy.dialects import postgresql

from alembic import op

revision: str = "0003"
down_revision: str | None = "0002"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("meetings", sa.Column("agenda", postgresql.JSONB(), nullable=True))
    op.add_column("meetings", sa.Column("parser_suggestion", postgresql.JSONB(), nullable=True))


def downgrade() -> None:
    op.drop_column("meetings", "parser_suggestion")
    op.drop_column("meetings", "agenda")
