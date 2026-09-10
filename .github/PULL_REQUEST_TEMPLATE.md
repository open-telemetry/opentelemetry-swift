## Summary

<!-- What does this change and why? Link the issue it resolves, e.g. "Resolves #123". -->

## Testing

<!-- How did you verify the change? Paste relevant output, screenshots, or link a workflow run. -->

## Checklist

- [ ] `swift test` passes locally
- [ ] Unit tests added or updated for the change
- [ ] **Instrumentation and event changes only:** the integration tests in
      `Tests/IntegrationTests` are updated. Anything that adds, removes or
      renames a span, log record, event name, or attribute emitted by an
      instrumentation (`Sources/Instrumentation/**`) must be exercised by
      `IntegrationTestScenario` in `Examples/HackerNewsDemo` and asserted on
      in `Tests/IntegrationTests/Assertions`. Run `make integ-tests-ios` to
      verify, and see `Tests/IntegrationTests/README.md`.
- [ ] Documentation updated (README, doc comments) where behavior changed
