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
- `.app` bundling
- Apple credentials in CI
- stapling or end-user Gatekeeper validation for a bundled app flow

The local packaging script can submit for notarization if `APPLE_NOTARY_PROFILE` already exists in the operator keychain. Full notarization still requires Apple credentials such as:
- `APPLE_TEAM_ID`
- `APPLE_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`

Those should be added only when an Apple signing identity and notarization credentials exist.
