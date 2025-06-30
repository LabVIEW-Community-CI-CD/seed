param()

Describe "VIPB round-trip equivalence via JSON" {

    It "should serialize → deserialize without losing data" {
        $origVipb = "tests/Samples/NI Icon editor.vipb"
        $tmpJson1 = New-TemporaryFile
        $tmpVipb2 = New-TemporaryFile -Suffix ".vipb"
        $tmpJson2 = New-TemporaryFile

        # 1. Original VIPB → JSON
        ./publish/linux-x64/VipbJsonTool vipb2json $origVipb $tmpJson1

        # 2. JSON → VIPB
        ./publish/linux-x64/VipbJsonTool json2vipb $tmpJson1 $tmpVipb2

        # 3. New VIPB → JSON
        ./publish/linux-x64/VipbJsonTool vipb2json $tmpVipb2 $tmpJson2

        # 4. Compare JSON text
        $json1 = Get-Content $tmpJson1 -Raw
        $json2 = Get-Content $tmpJson2 -Raw

        # Normalize whitespace (optional)
        $norm1 = ($json1 | ConvertFrom-Json | ConvertTo-Json -Depth 100)
        $norm2 = ($json2 | ConvertFrom-Json | ConvertTo-Json -Depth 100)

        $norm1 | Should -Be $norm2
    }
}
