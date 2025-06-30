```yaml
- uses: svelderrainruiz/json-vipb@v1.1.0
  with:
    mode: patch2vipb
    in:  ./ni-labview-icon-editor.json
    out: ./ni-labview-icon-editor.vipb
    patch_file: vipb-patch.yml
    always_patch_fields: |
      company_name: ${{ github.repository_owner }}
      author: ${{ github.actor }}
    branch_name: seed/json-vipb/${{ github.repository_owner }}-${{ github.repository }}
    auto_open_pr: true
    upload_files: |
      ni-labview-icon-editor.json
      ni-labview-icon-editor.vipb
