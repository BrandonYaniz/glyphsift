# GlyphSift

GlyphSift is a native macOS utility for cleaning pasted text and exposing characters that are easy to miss. It runs entirely on the Mac, makes deterministic changes, and keeps the original text visible while showing the cleaned result beside it.

The app is intended for text copied from websites, email, documents, content management systems, and source code. It does not rewrite prose or send text to a service.

## What It Does

- Accepts pasted or typed text in an editable source pane.
- Highlights every replacement candidate for the selected preset.
- Shows cleaned output in a separate read-only pane.
- Reports the number and type of changes found.
- Detects plain text, Markdown, HTML, and Rich Text input where possible.
- Copies cleaned output as plain text, Markdown, HTML, or Rich Text when that makes sense for the detected input.
- Preserves settings and custom regex rules between launches.
- Imports and exports settings as JSON.
- Makes selected invisible Unicode characters visible through marker labels.

## Cleaning Presets

### Plain Text

Normalizes line endings and unusual spaces, trims trailing whitespace, and reduces excessive blank lines without changing ordinary punctuation.

### Privacy Clean

Removes hidden Unicode characters that can be used for tracking, visual manipulation, or accidental contamination. This includes zero-width characters, directional controls, Unicode tag characters, variation selectors, byte-order marks, and soft hyphens.

### Publishing Clean

Prepares text for articles, documentation, email, and content management systems. It normalizes smart quotes, apostrophes, ellipses, dashes, tabs, repeated spaces, and trailing whitespace.

### Code Safe

Removes dangerous hidden characters while preserving tabs, indentation, repeated spaces, punctuation, and code formatting.

### Aggressive Clean

Combines privacy and publishing cleanup with optional Markdown, HTML, destructive Unicode, and custom regex processing.

## Output And Conversion

GlyphSift auto-detects the input format instead of asking for an input mode. The output picker changes based on what was detected.

**Plain Text** is always available. For plain text input, it is the only output option because there is no formatting to preserve.

**Raw** is available for Markdown and HTML input. It keeps the original Markdown or HTML structure, cleans the source text, and preserves tags, Markdown markers, and embedded source as much as possible.

**Markdown** is available for Markdown, HTML, and Rich Text input. Markdown-to-Markdown keeps the cleaned source. HTML and Rich Text conversion are best effort.

**HTML** is available for Markdown, HTML, and Rich Text input. HTML-to-HTML keeps the cleaned source. Markdown and Rich Text conversion are best effort.

**Rich Text** is available for Markdown, HTML, and Rich Text input. Rich Text pasted from another app keeps formatting where the cleanup can safely preserve the attributed ranges. Rich Text output is copied as RTF with a plain-text fallback.

The current Markdown and Rich Text renderer supports common formatting:

- First-, second-, and third-level headings
- Ordered and unordered lists
- Bold and italic text
- Inline code
- Markdown links

Conversion warnings appear below the output pane when formatting is removed or when a conversion is best effort. Raw output is the safest choice when the original markup needs to remain complete.

Embedded JavaScript and CSS are never executed. In Raw HTML output, GlyphSift treats `<script>` and `<style>` content as source text: it applies conservative cleanup, keeps the source in place, and does not try to convert it into Markdown or Rich Text.

## Custom Regex Rules

Regex rules are applied in their displayed order after built-in cleanup.

Each rule supports:

- Enabled or disabled state
- Name
- Find pattern
- Replacement template
- Case sensitivity
- Multiline anchors
- Dot-matches-newline behavior

An empty replacement removes matching text. Capture replacements use `NSRegularExpression` replacement syntax, including values such as `$1`.

Invalid patterns are skipped during cleaning and shown as errors in Settings.

## Privacy

GlyphSift processes text locally. The app has no accounts, analytics, telemetry, cloud sync, or network-based text processing.

Settings are stored at:

```text
~/Library/Application Support/GlyphSift/settings.json
```

## Requirements

- macOS 15.6 or later
- Xcode 26.2 or later
- Swift 5 language mode

The project currently builds with the macOS 26.2 SDK and targets macOS 15.6.

## Building

Open `GlyphSift.xcodeproj` in Xcode, select the `GlyphSift` scheme, and run the macOS target.

To build from Terminal:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild build \
  -project GlyphSift.xcodeproj \
  -scheme GlyphSift \
  -destination 'platform=macOS' \
  -derivedDataPath /private/tmp/GlyphSiftDerived
```

## Tests

The unit tests cover hidden Unicode removal, line-ending and whitespace normalization, punctuation cleanup, Code Safe formatting, regex replacement, invalid regex handling, format detection, raw source preservation, conversion warnings, and clipboard output types.

Run them with:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild test \
  -project GlyphSift.xcodeproj \
  -scheme GlyphSift \
  -destination 'platform=macOS' \
  -only-testing:GlyphSiftTests \
  -derivedDataPath /private/tmp/GlyphSiftDerived
```

## Project Layout

```text
GlyphSift/
  Models/       Settings, presets, findings, source formats, results, and output types
  Services/     Cleaning, source preservation, rendering, clipboard writing, and settings persistence
  ViewModels/   Main application state and actions
  Views/        SwiftUI views and AppKit text view bridges
GlyphSiftTests/ Engine unit tests
GlyphSiftUITests/
Configuration/ Bundle metadata
Assets/        Source artwork
```

## Versioning

GlyphSift uses calendar versions:

```text
YYYY.MM.DD-Release
YYYY.MM.DD.NN-Release
YYYY.MM.DD-Beta
```

The optional sequence is used when more than one build is produced on the same day. See `VERSIONING.md` for the Xcode settings and bundle-version details.

## Current Scope

GlyphSift is an early native build focused on reliable paste, inspect, clean, and copy workflows. File batches, background clipboard monitoring, cloud features, and automatic rewriting are intentionally outside the current scope.
