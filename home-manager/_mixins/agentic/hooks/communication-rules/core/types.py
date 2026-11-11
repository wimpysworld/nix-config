"""Records shared by extraction, advisory state and native responses."""

from dataclasses import dataclass


@dataclass
class ExtractorRecord:
    session: str
    turn: str | None
    tool: str
    target: str | None
    texts: list[str]


@dataclass
class Decision:
    """Feedback only, with no authority over tool permissions."""

    decision: str = "pass"
    surface: str = "tierA"
    notice: str = ""
    level: str = "warning"
    inject_base_rules: bool = False
    append_correction: bool = False
