# LabVIEW CI/CD Seed GitHub Action

This GitHub Action automates conversion, patching, and seeding processes for LabVIEW project (`.lvproj`) and VI Package Build specification (`.vipb`) files, streamlining the CI/CD pipeline for LabVIEW applications.

## Detailed Usage Overview

The action supports the following primary functionalities:

1. **Conversion** – Convert between `.vipb` (VI Package Build) or `.lvproj` (LabVIEW Project) and JSON formats, facilitating easy tracking, version control, and automated edits.
2. **Patching** – Apply modifications to existing `.vipb`, `.lvproj`, or JSON files via diff patches or YAML-defined patches.
3. **Seeding** – Automatically create initial `.lvproj` and/or `.vipb` files from predefined templates when they don’t exist, ensuring projects start with known-good “golden” files.

## Inputs Reference

| Name           | Required | Default | Description                                                                                                                                      |
| -------------- | -------- | ------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| `mode`         | yes      |         | Conversion mode: `vipb2json`, `json2vipb`, `lvproj2json`, or `json2lvproj`. (Aliases `buildspec2json` and `json2buildspec` also accepted.)       |
| `input`        | yes      |         | Path to the input file (VIPB, LVPROJ, or JSON).                                                                                                  |
| `output`       | yes      |         | Path to the output file (VIPB, LVPROJ, or JSON, depending on mode).                                                                              |
| `patch_file`   | no       |         | Path to a Unix-style diff/patch file to apply after conversion.                                                                                  |
| `patch_yaml`   | no       |         | Path to a YAML merge patch file (requires `yq`).                                                                                                 |
| `always_patch` | no       | `false` | If `true`, apply patches even when target fields are missing.                                                                                    |
| `branch_name`  | no       |         | Branch name to commit generated changes.                                                                                                         |
| `auto_pr`      | no       | `false` | If `true`, automatically open a pull request after committing (requires GitHub CLI `gh`).                                                        |
| `upload_files` | no       | `true`  | Upload generated files as workflow artifacts.                                                                                                    |
| `seed_lvproj`  | no       | `false` | If `true`, seed a project file (`seed.lvproj`) from `tests/Samples/seed.lvproj` if it doesn’t exist.                                             |
| `seed_vipb`    | no       | `false` | If `true`, seed a build-spec file (`build/buildspec.vipb`) from `tests/Samples/seed.vipb` if it doesn’t exist.                                   |
| `tag`¹         | no       |         | Git tag used to name the seeding branch (`seed-<tag>`). **Required** when `seed_lvproj` or `seed_vipb` is `true`.                                |

> ¹ **Important:** `tag` must be supplied whenever seeding is enabled.

---

## Comprehensive Seeding Example

```yaml
name: Seed LabVIEW Project and Build Specification
on:
  push:
    tags:
      - 'v*'         # Trigger on any tag push like v1.2.3

jobs:
  seed-files:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Seed LabVIEW project & VIPB
        uses: LabVIEW-Community-CI-CD/seed@v2.0.0
        with:
          mode: vipb2json            # Dummy mode – ignored during seeding
          input: dummy.vipb          # Placeholder
          output: dummy.json         # Placeholder
          seed_lvproj: true          # Create seed.lvproj if missing
          seed_vipb: true           # Create build/buildspec.vipb if missing
          tag: ${{ github.ref_name }}
```

**What happens?**

1. If `seed.lvproj` is missing, the action copies `tests/Samples/seed.lvproj` to the repo root.
2. If `build/buildspec.vipb` is missing, the action copies `tests/Samples/seed.vipb` to that path.
3. Both files are committed to a new branch `seed-<tag>` (e.g., `seed-v1.2.3`).  
4. No pull request is opened unless `auto_pr: true` is set.

---

## AI-Guidance Tips

When using AI tools to author or modify workflows:

- **Clarify parameters** – Provide concrete file paths and desired modes to avoid ambiguity.
- **Highlight dependencies** – Ensure runners (or the Docker image) include `yq` for YAML patches and `gh` for PR operations.
- **Explain your branching strategy** – Document how `branch_name`, `tag`, and `auto_pr` interplay so automated suggestions remain consistent with your repo policies.

---

## Troubleshooting Docker Builds

If the action’s Docker build fails:

1. Verify `entrypoint.sh` is executable (`chmod +x entrypoint.sh`).
2. Ensure all wrapper scripts (`bin/*`) are in place and executable.
3. Confirm conversion binary `VipbJsonTool` is present in `bin/` and has execution permissions.
4. Double-check sample files exist:
   ```
   tests/Samples/seed.lvproj
   tests/Samples/seed.vipb
   ```
5. Re-run `docker build .` and inspect any missing-file errors.

These steps resolve most “file not found” or permission issues during image creation.
