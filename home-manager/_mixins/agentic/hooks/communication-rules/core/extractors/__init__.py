"""Per-agent extractors.

Each module reads one agent's raw event JSON and returns a normalised
``Extraction`` (see ``core.dispatch``). Extractors hold no policy and no
detection; they only route a normalised record into the shared middle.
"""
