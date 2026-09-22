---
name: verify
description: Run Readr's full verification sequence — generate, build, test, lint, format, and spec validation — and report exactly what passed and what failed. Use before any commit, handoff, or PR.
allowed-tools: Bash, Read, Glob, Grep
---

Run Readr's verification sequence and report the results honestly.

Prefer delegating to the `runner` agent when several steps are expected to fail —
it keeps the build noise out of the main conversation.

## Prerequisites

Xcode must be selected and licensed. If `xcodebuild` reports a license error, stop
and tell the user to run:

```
sudo xcode-select -s /Applications/Xcode.app
sudo xcodebuild -license accept
```

Do not attempt these yourself — they need `sudo`.

## The sequence

Run in order. Continue past a failure unless it makes later steps meaningless.

**1. Generate the project**

```bash
xcodegen generate
```

`Readr.xcodeproj` is a build artifact. Run this after any `project.yml` change and
after cloning.

**2. Build**

```bash
xcodebuild -scheme Readr -destination 'generic/platform=iOS Simulator' build
```

If this fails, the test step is meaningless — say so and skip it.

**3. Test**

```bash
xcodebuild -scheme Readr -destination 'platform=iOS Simulator,name=iPhone 17' test
```

Adjust the simulator name to one that exists (`xcrun simctl list devices available`).

**4. Bundle check**

Confirm no documentation shipped in the app. Per-folder `codemap.md` and
`AGENTS.md` files live inside the source tree and are excluded by
`project.yml`; a regression here is silent.

```bash
find "$(xcodebuild -scheme Readr -showBuildSettings 2>/dev/null \
  | awk -F' = ' '/ BUILT_PRODUCTS_DIR/ {print $2}' | head -1)/Readr.app" -name '*.md'
```

Any output is a failure.

**5. Lint and format**

```bash
swiftlint
swift-format lint --recursive Readr ReadrTests
```

If either tool is not installed, report it as missing — never as passing.

**6. Validate specs**

```bash
openspec validate --all
```

## Reporting

Report every step as **passed**, **failed**, **skipped**, or **tool missing**.
For failures, quote the actual error output trimmed to the relevant lines.

Never report a step as passing if you did not run it.

## Do not

- Do not edit code, tests, or config to make a step pass.
- Do not add `// swiftlint:disable`, skip a test, or relax a build setting.
- Do not "fix" a project-file error by regenerating — the fix belongs in
  `project.yml`.

Fixing failures is a separate task from verifying. Report first.
