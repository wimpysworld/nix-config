# Pi Adapter Fixtures

These fixtures exercise the Pi helper for `context`, `input`, `tool_call`,
`message_end`, and `tool_result` events.

`message_update` streamed text is not gated in v1. Pi can show streamed tokens
before `message_end`, so the final correction fixture covers the supported
post-stream correction point.
