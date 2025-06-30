param()

Describe "VIPB round-trip equivalence via JSON" {

```
It "should serialize → deserialize without losing data" {
    $origVipb = "tests/Samples/NI Icon editor.vipb"

    # Create temp file paths
    $tmpJson1 = [System.IO.Path]::GetTempFileName()
    $tmpVipb2 = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), [System.IO.Path]::GetRandomFileName() + ".vipb")
    $tmpJson2 = [System.IO.Path]::GetTempFileName()

    # 1. Original VIPB → JSON
    ./publish/linux-x64/VipbJsonTool vipb2json $origVipb $tmpJson1

    # 2. JSON → VIPB
    ./publish/linux-x64/VipbJsonTool json2vipb $tmpJson1 $tmpVipb2

    # 3. New VIPB → JSON
    ./publish/linux-x64/VipbJsonTool vipb2json $tmpVipb2 $tmpJson2

    # 4. Compare JSON text
    $json1 = Get-Content $tmpJson1 -Raw
    $json2 = Get-Content $tmpJson2 -Raw

    # Normalize for consistent comparison
    $norm1 = (ConvertFrom-Json $json1 | ConvertTo-Json -Depth 100)
    $norm2 = (ConvertFrom-Json $json2 | ConvertTo-Json -Depth 100)

    $norm1 | Should -Be $norm2
}
```

}
