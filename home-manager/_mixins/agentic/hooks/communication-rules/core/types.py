"""Shared records that cross the core seam.

Two records carry data through the core. Extractors fill an
``ExtractorRecord`` from raw agent JSON. The state machine and responders
touch only that record, never raw agent JSON, and they return a
``Decision``.
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass
class ExtractorRecord:
    """Normalised event an extractor hands to the core.

    The extractor fills every field. The state machine and responders read
    this record only; they never see raw agent JSON.
    """

    session: str
    turn: str | None
    tool: str
    target: str | None
    texts: list[str]


@dataclass
class Decision:
    """The decision the core returns for one event.

    Allowed values:

    - ``decision``: ``pass`` | ``block`` | ``yield`` | ``re-issue`` | ``remind``.
    - ``surface``: ``tierA`` | ``B1`` | ``B2``.
    - ``level``: ``warning`` | ``error``.

    ``inject_base_rules`` and ``append_correction`` are the Tier A injection
    flags. Pi and OpenCode shims apply them to live runtime objects.
    """

    decision: str
    surface: str
    notice: str
    level: str
    inject_base_rules: bool
    append_correction: bool
