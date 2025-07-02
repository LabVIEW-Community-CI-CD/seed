# json-vipb GitHub Action

[![CI](https://github.com/LabVIEW-Community-CI-CD/seed/actions/workflows/build-test-release.yml/badge.svg)](https://github.com/LabVIEW-Community-CI-CD/seed/actions/workflows/build-test-release.yml)

A GitHub Action to **convert LabVIEW .vipb (VI Package Build Spec) files into JSON** and vice versa.  
Useful for automation, code review, and integrating LabVIEW build processes with CI/CD.

---

## Features

- **Convert .vipb → JSON**: Extract and serialize VI Package Build spec files for inspection or processing.
- **Convert JSON → .vipb**: Generate .vipb files from machine‑editable JSON for LabVIEW build automation.
- **Easy integration**: Plug into any GitHub Actions workflow, including cross‑repo and matrix jobs.
- **Cross‑platform**: Runs wherever GitHub Actions are supported.

---

## Usage

### 1. Basic Usage

Add this to your workflow (e.g. `.github/workflows/convert-vipb.yml`):

```yaml
name: Convert VIPB to JSON

on:
  push:
    paths:
      - '**/*.vipb'

jobs:
  convert:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Convert VIPB to JSON
        uses: LabVIEW-Community-CI-CD/seed@v1.4.0
        with:
          input: './path/to/package.vipb'
          output: './path/to/package.json'
          direction: 'to-json'
```

#### Inputs

| Name        | Description                                         | Required | Default   |
|-------------|-----------------------------------------------------|----------|-----------|
| `input`     | Path to the input `.vipb` or `.json` file           | **Yes**  | N/A       |
| `output`    | Path for the output file                            | **Yes**  | N/A       |
| `direction` | Conversion direction: `to-json` or `to-vipb`        | No       | `to-json` |

#### Example – Convert JSON to VIPB

```yaml
- name: Convert JSON to VIPB
  uses: LabVIEW-Community-CI-CD/seed@v1.4.0
  with:
    input: './path/to/package.json'
    output: './path/to/package.vipb'
    direction: 'to-vipb'
```

---

### 2. Use from Another Repository

**Public repo:**

```yaml
- uses: LabVIEW-Community-CI-CD/seed@v1.4.0
  with:
    input: './other-repo/build/package.vipb'
    output: './result.json'
```

**Private repo:**  
You need a Personal Access Token (PAT) with `repo` scope.

```yaml
- uses: actions/checkout@v4
  with:
    repository: yourorg/private-repo
    token: ${{ secrets.PAT }}
    path: other-repo

- uses: LabVIEW-Community-CI-CD/seed@v1.4.0
  with:
    input: './other-repo/build/package.vipb'
    output: './result.json'
```

---

### 3. Pinning to a Commit (Best Practice for Security)

```yaml
- uses: LabVIEW-Community-CI-CD/seed@98d8221ca5721a980bb1049c9f53082a049fcc85
  with:
    input: './package.vipb'
    output: './package.json'
```

---

### 4. Workflow Variations

#### Matrix Conversion

```yaml
strategy:
  matrix:
    vipb: [pkg1.vipb, pkg2.vipb]
steps:
  - uses: actions/checkout@v4
  - name: Convert All
    uses: LabVIEW-Community-CI-CD/seed@v1.4.0
    with:
      input: './${{ matrix.vipb }}'
      output: './${{ matrix.vipb }}.json'
```

#### Use as a Step in a Larger Pipeline

```yaml
- name: Build LabVIEW Package
  run: lv_build ./source.lvproj

- name: Extract Build Spec as JSON
  uses: LabVIEW-Community-CI-CD/seed@v1.4.0
  with:
    input: './build/my_package.vipb'
    output: './build/my_package.json'
```

---

## Output

- Produces a `.json` or `.vipb` file at the path you specify.
- On error, fails the step with a clear message in the Actions log.

---

## Action Reference

See [`action.yml`](./action.yml) for the authoritative input/output spec.

---

## Continuous Integration (CI)

- **CI triggers:** The GitHub Actions workflow for this project runs on pushes to the **main** branch, on pull requests targeting **main**, and when new version tags (matching `v*`) are pushed.
- **Test coverage:** The CI pipeline builds the converter tool and runs a suite of Pester tests:  
  - *Basic round‑trip test:* Converts a sample `.vipb` file to JSON and back, and asserts that there is no loss or change in data.  
  - *Golden sample patch test:* Enumerates all fields in a sample `.vipb` (`tests/Samples/seed.vipb`), generates a patch file that modifies each field, applies the patch, and verifies that the patched output reflects all changes correctly (and that unchanged fields remain identical).
- **Release baseline:** The **v1.4.0** release is a milestone that includes full round‑trip fidelity and patch coverage tests. It is the recommended baseline for users integrating this action into their own CI/CD workflows (including any AI‑assisted automation).
- **Running tests locally:** Contributors can run the same tests locally. Install the [Pester](https://github.com/pester/Pester) module, build the project (to produce the `VipbJsonTool` CLI under `publish/linux-x64`), then execute `Invoke-Pester` in the repository root. This will run both the basic round‑trip test and the golden sample patch test locally, ensuring your changes pass all checks before pushing.

---

## Contributing

1. Fork this repo and make a branch.  
2. Test locally (for example, run the Pester test suite with `Invoke-Pester`) or use [nektos/act](https://github.com/nektos/act) to simulate the GitHub Actions run.  
3. Open a pull request.  
   Please include sample inputs and expected outputs in your PR.

---

## Troubleshooting

- **Path not found:** Make sure input/output paths are correct and relative to the root of your repository or checked‑out path.
- **Permission denied:** For private repositories, ensure your PAT has `repo` scope and that secrets are set in your repo’s settings.
- **Conversion errors:** Validate that your input is a valid `.vipb` or a well‑formed JSON file.

---

## License

[MIT](./LICENSE)

---

## Credits

Maintained by Sergio Velderrain Ruiz.  
Issues and PRs welcome!
