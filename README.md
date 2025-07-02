# json‑vipb GitHub Action



**Convert LabVIEW VI Package Build Spec (**``**) files to and from JSON, apply YAML patches, and integrate effortlessly into GitHub Actions workflows.**

---

## Overview

This action simplifies LabVIEW package build automation, allowing users to:

- Convert `.vipb` files into JSON format for inspection or modification.
- Reconstruct `.vipb` files from modified JSON.
- Programmatically update `.vipb` content via structured YAML patches.
- Validate changes and automate LabVIEW build configurations in CI/CD pipelines.

---

## Use Cases

### 1. Automated Code Reviews

Convert `.vipb` files to JSON to facilitate automated or AI-driven reviews and identify structural or content differences clearly.

### 2. CI/CD Automation

Integrate this action within GitHub workflows to automatically verify and apply configuration changes to LabVIEW builds.

### 3. Change Tracking

Efficiently track and document changes in LabVIEW build specifications by converting them to JSON and maintaining them within version control systems.

### 4. Bulk Field Updates

Apply consistent updates across multiple `.vipb` files using YAML patches, significantly reducing manual effort and potential human error.

### 5. Enhanced AI Integration

Enable AI assistants to automate review, validation, and modification tasks, leveraging structured JSON representations and well-defined YAML patches.

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

| Name        | Required | Default   | Description                                    |
| ----------- | -------- | --------- | ---------------------------------------------- |
| `input`     | **yes**  | —         | Path to source `.vipb` or `.json` file.        |
| `output`    | **yes**  | —         | Path for the output file.                      |
| `direction` | no       | `to-json` | Conversion direction (`to-json` or `to-vipb`). |

---

## Continuous Integration (CI)

### Workflow Steps

- **Build CLI**: Compile a standalone CLI binary.
- **Test Suites**:
  - **Basic Round-trip**: Ensures fidelity of `.vipb` ↔ JSON conversions.
  - **Golden Sample Test**: Verifies YAML patch correctness across all patchable fields.
  - **Fallback Handling**: Performs no-op validation if no fields are patchable (whitespace changes ignored).
- **Publish Artifacts**: Docker images and test results.

### Triggers

- Every push to `main` or new tag (`v*`)
- Every pull request targeting `main`

---

## Local Testing

Ensure tests pass locally before committing changes:

```powershell
dotnet publish src/VipbJsonTool -c Release -r linux-x64 --self-contained `
    -p:PublishSingleFile=true -o publish/linux-x64

Install-Module Pester -Scope CurrentUser
Invoke-Pester
```

---

## Troubleshooting & FAQ

| Issue                           | Reason                              | Solution                                                          |
| ------------------------------- | ----------------------------------- | ----------------------------------------------------------------- |
| `object reference not set`      | YAML patch has no applicable fields | Update script to latest version (auto fallback implemented).      |
| `unpatched #whitespace changed` | Whitespace formatting differences   | Latest test script ignores whitespace changes in no-op scenarios. |
| `unpatched field Δ`             | Unexpected JSON changes             | Add changes explicitly to YAML patches.                           |

---

## Versioning & Security

- Use explicit tags (`v1.4.0`) or commit SHAs for secure and reproducible builds.
- Docker images available at: `ghcr.io/labview-community-ci-cd/seed:<tag>`

---

## Contributing

1. Fork the repository.
2. Run tests locally (`Invoke-Pester`).
3. Submit a pull request.

---

## License

MIT © 2025 LabVIEW Community CI/CD

