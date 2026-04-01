# Reference And Distribution

## Blender Reference Remote

The rewrite lives in `blender-zig`. The Blender fork stays a reference source.

To add or refresh the local reference remote:

```bash
bash scripts/add-reference-remote.sh
```

Defaults:
- remote name: `blender-reference`
- remote URL: `https://github.com/stussysenik/blender.git`
- branch: `main`

This is local git configuration. It is not stored in repository history, which is why the setup command is versioned here.

## Local Release Packaging

For an optimized unsigned release artifact on the current machine:

```bash
npm run dist
```

That script:
- runs `zig build test` first by default
- builds with `zig build -Doptimize=ReleaseFast`
- packages the current-platform binary
- includes `README.md` and `NOTICE.md`
- writes a `.zip` on macOS or a `.tar.gz` on Linux into `dist/`
- writes a SHA-256 sidecar when `shasum` or `sha256sum` is available

## macOS Note

The current output is a native CLI binary and is launchable from Terminal on macOS.

The first native shell bundle now builds locally with:

```bash
bash scripts/build-phase-18-shell.sh
open zig-out/BlendZigShell.app
```

That bundle keeps the SwiftUI shell executable beside the bundled
`blender-zig-direct` helper under `zig-out/BlendZigShell.app/Contents/MacOS/`.
It is a local launch surface for development, not the final release artifact yet.

For local signing scaffolding on macOS:

```bash
npm run sign:macos -- zig-out/bin/blender-zig "Developer ID Application: Your Name"
```

Or with an environment variable:

```bash
export APPLE_DEVELOPER_IDENTITY="Developer ID Application: Your Name"
bash scripts/sign-macos-release.sh zig-out/bin/blender-zig
```

Or package and sign in one step:

```bash
export APPLE_DEVELOPER_IDENTITY="Developer ID Application: Your Name"
npm run dist
```

What is not configured yet:
- release packaging for the `.app` bundle
- Apple credentials in CI
- stapling or end-user Gatekeeper validation for a bundled app flow

The local packaging script can submit for notarization if `APPLE_NOTARY_PROFILE` already exists in the operator keychain. Full notarization still requires Apple credentials such as:
- `APPLE_TEAM_ID`
- `APPLE_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`

Those should be added only when an Apple signing identity and notarization credentials exist.

## CI Artifact Builds

The repo also ships a macOS artifact workflow in [native-artifacts.yml](/Users/s3nik/Desktop/blender-zig/.github/workflows/native-artifacts.yml).

That workflow:
- installs Zig on `macos-latest`
- runs `zig build test`
- packages an optimized native archive
- smoke-runs the built CLI
- uploads the `.zip` and checksum as workflow artifacts

If the `APPLE_DEVELOPER_IDENTITY` secret exists, the workflow signs the packaged binary. It does not notarize in CI yet.
