
# json-vipb GitHub Action

[![CI](https://github.com/svelderrainruiz/json-vipb/actions/workflows/ci.yml/badge.svg)](https://github.com/svelderrainruiz/json-vipb/actions/workflows/ci.yml)

A GitHub Action to **convert LabVIEW .vipb (VI Package Build Spec) files into JSON** and vice versa.  
Useful for automation, code review, and integrating LabVIEW build processes with CI/CD.

---

## Features

- **Convert .vipb → JSON**: Extract and serialize VI Package Build spec files for inspection or processing.
- **Convert JSON → .vipb**: Generate .vipb files from machine-editable JSON for LabVIEW build automation.
- **Easy integration**: Plug into any GitHub Actions workflow, including cross-repo and matrix jobs.
- **Cross-platform**: Runs wherever GitHub Actions are supported.

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
        uses: svelderrainruiz/json-vipb@v1.3.0
        with:
          input: './path/to/package.vipb'
          output: './path/to/package.json'
          direction: 'to-json'
```

#### Inputs

| Name        | Description                                         | Required | Default     |
|-------------|-----------------------------------------------------|----------|-------------|
| `input`     | Path to the input `.vipb` or `.json` file           | Yes      | N/A         |
| `output`    | Path for the output file                            | Yes      | N/A         |
| `direction` | Conversion direction: `to-json` or `to-vipb`        | No       | `to-json`   |

#### Example: Convert JSON to VIPB

```yaml
- name: Convert JSON to VIPB
  uses: svelderrainruiz/json-vipb@v1.3.0
  with:
    input: './path/to/package.json'
    output: './path/to/package.vipb'
    direction: 'to-vipb'
```

---

### 2. Use from Another Repository

**Public repo:**

```yaml
- uses: svelderrainruiz/json-vipb@v1.3.0
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

- uses: svelderrainruiz/json-vipb@v1.3.0
  with:
    input: './other-repo/build/package.vipb'
    output: './result.json'
```

---

### 3. Pinning to a Commit (Best Practice for Security)

```yaml
- uses: svelderrainruiz/json-vipb@0c89e23f3eadf6ac6ede81f8bc4d2ba3c87e70fa
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
    uses: svelderrainruiz/json-vipb@v1.3.0
    with:
      input: './${{ matrix.vipb }}'
      output: './${{ matrix.vipb }}.json'
```

#### Use as a Step in a Larger Pipeline

```yaml
- name: Build LabVIEW Package
  run: lv_build ./source.lvproj

- name: Extract Build Spec as JSON
  uses: svelderrainruiz/json-vipb@v1.3.0
  with:
    input: './build/my_package.vipb'
    output: './build/my_package.json'
```

---

## Output

- Produces a `.json` or `.vipb` file at the path you specify.
- On error, fails the step with a clear message in the Actions log.

---

## Action Reference

See [`action.yml`](./action.yml) for the authoritative input/output spec.

---

## Contributing

1. Fork this repo and make a branch.
2. Test locally or with [nektos/act](https://github.com/nektos/act), or use GitHub Actions.
3. Open a pull request.  
   Please include sample inputs and expected outputs in your PR.

---

## Troubleshooting

- **Path not found:** Make sure input/output paths are correct and relative to the root of your repository or checked-out path.
- **Permission denied:** For private repositories, ensure your PAT has `repo` scope and that secrets are set in your repo’s settings.
- **Conversion errors:** Validate that your input is a valid `.vipb` or a well-formed JSON file.

---

## License

[MIT](./LICENSE)

---

## Credits

Maintained by Sergio Velderrain Ruiz.  
Issues and PRs welcome!

---
