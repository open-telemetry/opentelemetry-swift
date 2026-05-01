# Agent instructions

Guidance for AI coding agents (Claude Code, Cursor, Copilot, etc.) working in this repository.

## Tests are load-bearing — do not weaken them

Never delete, skip, comment out, or weaken an existing test without explicit
human approval in the current conversation.

This includes:

- Removing a test function or test file.
- Adding `@Ignore`, `XCTSkip`, `XCTSkipIf`, `XCTSkipUnless`, or any conditional
  skip that did not exist before.
- Downgrading an assertion (e.g. `XCTAssertEqual` → `XCTAssertNotNil`,
  tightening a tolerance into a looser one, dropping assertions from a test).
- Shortening a wait/expectation timeout below the original value to make a
  flaky test "pass" faster.
- Replacing real types with mocks/stubs inside a test that previously
  exercised the real thing.
- Deleting setup/teardown steps that a test was relying on.
- Commenting out the body of a test or replacing it with `// TODO`.

If a test is genuinely broken, stop and surface it. Do not "fix" it by
reducing what it checks. Explain the failure and propose options; wait for a
human decision.

Mechanical rewrites that preserve the test's intent and coverage are fine
without extra approval:

- Renaming a test method so its name still describes the same behavior.
- Swapping one non-deprecated API for an equivalent one (e.g.
  `waitForExpectations` → `wait(for:timeout:)`).
- Reformatting, reindenting, or resolving lint warnings inside a test.
- Extracting shared setup into helpers as long as every original assertion
  still runs.

When in doubt, ask.

## Tests must actually run

Related: do not land changes that cause the test binary to silently skip
tests. If the test count on a platform drops after your change, that is a
regression even if the suite "passes". SwiftPM's Linux test discovery in
particular is fragile around actor isolation — verify the test count before
and after.

## Scope discipline

- A bug fix does not need surrounding cleanup. Do not refactor adjacent code
  "while you're in there" unless the user asked.
- Do not introduce new abstractions, feature flags, or indirection layers
  that the task does not require.
- Do not add backwards-compat shims or re-exports for code you removed
  unless a consumer requires them.

## Before committing

- Build the package. This repo uses SwiftPM; run `swift build --build-tests`
  and fix errors at the root cause rather than suppressing them.
- Only commit when the user asks you to commit.
- Follow Conventional Commits for the subject line.
- Never `git push`, `git push --force`, or rewrite published history without
  explicit instruction.

## Comments

- Default to writing no comments. Preserve existing comments — do not delete
  a comment unless you are also deleting the logic it describes.
- When a refactor makes a comment partially stale, update it. Do not leave
  it as a lie.
