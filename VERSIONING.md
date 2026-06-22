# Versioning

GlyphSift uses calendar versions for user-facing builds.

## Format

- First build on a date: `YYYY.MM.DD-Release`
- Additional builds on the same date: `YYYY.MM.DD.NN-Release`
- Non-release channels replace the suffix, such as `-Beta`, `-Alpha`, or `-RC`.

Examples:

- `2026.06.22-Release`
- `2026.06.22.01-Release`
- `2026.06.22-Beta`

## Xcode Settings

`GLYPHSIFT_RELEASE_VERSION` contains the complete user-facing version.

`MARKETING_VERSION` remains a three-component numeric value because Apple bundle metadata requires that format. For example, `2026.06.22-Release` uses `2026.6.22` as `MARKETING_VERSION`.

`CURRENT_PROJECT_VERSION` uses the date plus the optional same-day sequence:

- `20260622` for the first build
- `2026062201` for the next build on the same date

Update both Debug and Release configurations when changing the date or sequence. Debug normally uses the `-Beta` suffix and Release uses `-Release`.
