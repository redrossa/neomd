# Priority E2E harness corrections

The initial exact-head `15bbc400` selection run passed the runner trust guard and delivered the forward drag, then skipped because its helper required AXTextArea for the authored `Across blocks` heading. Recorded AX window identity survived; the attachment does not dump the heading role. Production `MarkdownLinkedImageText.accessibilityRole` explicitly returns AXHeading for headings, corroborating the selector mismatch.

Coordinator authorized a test-only correction: the exact full-text `Across blocks` fixture fragment requires AXHeading; other fragments still require AXTextArea. PID/window-scoped traversal, unique match, pre-action endpoint derivation, and independent selected-range/text assertions remain unchanged. AXValue is only identity, never selected-text evidence. Unsupported heading selected attributes must block, not pass. No production changes or telemetry.

Supplied selection Markdown/oracles and priority plan remain byte-identical. Actual execution results and exact product provenance are recorded in the external worker handoff and PR #67; this correction alone establishes no behavioral pass.
