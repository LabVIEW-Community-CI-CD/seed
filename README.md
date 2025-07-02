
# json‑vipb GitHub Action

[![CI](https://github.com/LabVIEW-Community-CI-CD/seed/actions/workflows/build-test-release.yml/badge.svg)](https://github.com/LabVIEW-Community-CI-CD/seed/actions/workflows/build-test-release.yml)

Convert LabVIEW **VI Package Build Spec (.vipb)** files ↔ JSON, apply
patches, and automate builds.

---

## Features

| Capability                 | Details                                                                                   |
| -------------------------- | ----------------------------------------------------------------------------------------- |
| **vipb ➞ json**            | Serialize .vipb to structured JSON for diffing/review                                     |
| **json ➞ vipb**            | Create a .vipb file from edited JSON                                                      |
| **YAML patching**          | Change fields programmatically via YAML patches                                           |
| **Cross-platform action**  | Single-file .NET 8 CLI (Linux-x64) in Docker                                              |
| **Robust CI**              | Validated by comprehensive Pester tests                                                   |

---

## Quick Start

```yaml
name: Convert VIPB

on:
  push:
    paths: [ '**/*.vipb' ]

jobs:
  convert:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: VIPB to JSON
        uses: LabVIEW-Community-CI-CD/seed@v1.4.0
        with:
          input:  './build/MyPackage.vipb'
          output: './build/MyPackage.json'
          direction: 'to-json'
```

### Inputs

| Name        | Required | Default   | Description                      |
|-------------|:--------:|-----------|----------------------------------|
| `input`     | **yes**  | —         | Source .vipb or .json file       |
| `output`    | **yes**  | —         | Output file path                 |
| `direction` | no       | `to-json` | Conversion direction             |

---

## Continuous Integration (CI)

Every push (main), pull_request, and tag triggers CI:

- **Build** the CLI binary
- **Test suites**:
  - **Basic**: Verifies round-trip JSON ↔ vipb
  - **Golden sample**: Verifies every patchable field via YAML patch
  - No-op fallback if no fields patchable (whitespace ignored)
- **Publish** Docker image (main/tags)
- **Artifacts** always uploaded

---

## Local Testing

```pwsh
dotnet publish src/VipbJsonTool -c Release -r linux-x64 --self-contained `
    -p:PublishSingleFile=true -o publish/linux-x64

Install-Module Pester -Scope CurrentUser
Invoke-Pester
```

---

## Troubleshooting & FAQ

| Issue                             | Reason                          | Solution                               |
|-----------------------------------|---------------------------------|----------------------------------------|
| `object reference not set`        | Empty YAML patch                | Latest script auto-fallback            |
| `unpatched #whitespace changed`   | Whitespace differs on no-op run | Update test script (≥ v1.4.0)         |
| `unpatched field Δ`               | Unexpected JSON edits           | Include changed field in YAML patch    |

---

## Versioning & Security

- Tag actions explicitly (`v1.4.0` or commit SHA).
- Docker: `ghcr.io/labview-community-ci-cd/seed:<tag>`

---

## Contributing

Fork, test locally (`Invoke-Pester`), then PR.

---

## License

BSD0
