# LabVIEW CI/CD Seed GitHub Action

This GitHub Action automates conversion, patching, and seeding processes for LabVIEW project (`.lvproj`) and VI Package Build specification (`.vipb`) files, streamlining the CI/CD pipeline for LabVIEW applications.

## Detailed Usage Overview

The action supports the following primary functionalities:

1. **Conversion**: Convert between `.vipb` (VI Package Build) and JSON formats, facilitating easy tracking, version control, and automation of package specifications.
2. **Patching**: Apply modifications to existing `.vipb` or JSON files via simple patch files or YAML-defined patches.
3. **Seeding**: Automatically create initial `.lvproj` and `.vipb` files from predefined templates if they don't exist, essential for initializing projects quickly and consistently.

## Inputs Reference

| Name           | Required | Default | Description                                                                                                          |
| -------------- | -------- | ------- | -------------------------------------------------------------------------------------------------------------------- |
| `mode`         | yes      |         | Conversion mode: specify either `vipb2json` (VI Package Build to JSON) or `json2vipb` (JSON to VI Package Build).    |
| `input`        | yes      |         | Path to the input file (the file being converted or patched).                                                        |
| `output`       | yes      |         | Path to the output file (where the result will be saved).                                                            |
| `patch_file`   | no       |         | Path to a simple file containing patch operations (typically diff/patch files).                                      |
| `patch_yaml`   | no       |         | Path to a YAML-formatted file specifying structured patch operations. Requires `yq` tool installed.                  |
| `always_patch` | no       | false   | Force patching even if targeted fields are absent, allowing more aggressive file modification.                       |
| `branch_name`  | no       |         | Specify a branch name explicitly for committing or pull request operations.                                          |
| `auto_pr`      | no       | false   | When enabled (`true`), automatically opens a pull request after committing changes. Requires GitHub CLI (`gh`).      |
| `upload_files` | no       | true    | If enabled (`true`), uploads the generated or patched files as artifacts to the workflow run.                        |
| `seed_lvproj`  | no       | false   | Automatically seeds a LabVIEW project file (`.lvproj`) using the template in `tests/Samples/seed.lvproj` if missing. |
| `seed_vipb`    | no       | false   | Automatically seeds a VI Package build spec file (`.vipb`) from `tests/Samples/seed.vipb` if missing.                |
| `tag`          | no¹      |         | Git tag name for identifying the specific release or state. Required when using `seed_lvproj` or `seed_vipb`.        |

> ¹ **Important**: The `tag` parameter becomes mandatory whenever either `seed_lvproj` or `seed_vipb` is set to `true`.

## Comprehensive Seeding Example

Below is a complete example illustrating how to leverage the seeding capability within your GitHub Actions workflow:

```yaml
name: Seed LabVIEW Project and VIPB
on:
  push:
    tags:
      - 'v*'

jobs:
  seed-files:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Seed LabVIEW Project and Build Specification
        uses: LabVIEW-Community-CI-CD/seed@v2.0.0
        with:
          mode: vipb2json               # Dummy mode for compatibility; not utilized in seeding mode.
          input: dummy.vipb             # Placeholder; not utilized during seeding.
          output: dummy.json            # Placeholder; not utilized during seeding.
          seed_lvproj: true             # Enables automatic seeding of the .lvproj file.
          seed_vipb: true               # Enables automatic seeding of the .vipb file.
          tag: ${{ github.ref_name }}   # Automatically use the tag name from the triggering event.
```

This workflow step will:

* Automatically check for the existence of the LabVIEW project file (`seed.lvproj`) at the repository root. If absent, it creates the file based on a predefined golden template.
* Check for the existence of the VI Package build specification (`build/buildspec.vipb`). If missing, it seeds the file from a predefined golden template.
* Commit these newly created files directly to a dedicated branch named `seed-<tag>`, clearly indicating their association with the specific release or tag. This operation does not automatically open a pull request, giving you full control over subsequent integration steps.

## AI-Guidance Considerations

When leveraging this documentation with AI assistance:

* Explicitly specify each parameter based on your project's needs. Provide clear context around your project's structure, repository standards, and CI/CD strategies.
* Use provided examples as templates, clearly marking placeholders (`dummy.vipb`, `dummy.json`) as irrelevant for seeding operations.
* Highlight the dependency requirements (like `yq` and `gh`) clearly to avoid runtime issues.
* Clearly document and describe intended behavior for branching, tagging, and artifact uploading to align AI-generated recommendations closely with your workflow requirements.

Following these guidelines ensures that AI assistance effectively guides you through implementing and maintaining LabVIEW projects within a robust and automated CI/CD pipeline.
