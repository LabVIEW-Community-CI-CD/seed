param()

Describe "VIPB round-trip equivalence via JSON" {

    It "serializes to JSON and back to VIPB with no data loss" {
        # Paths for original and temporary files
        $origVipb = "tests/Samples/NI Icon editor.vipb"
        $tmpJson1 = [IO.Path]::GetTempFileName()
        $tmpVipb2 = [IO.Path]::Combine([IO.Path]::GetTempPath(), [IO.Path]::GetRandomFileName() + ".vipb")
        $tmpJson2 = [IO.Path]::GetTempFileName()

        # 1. Convert VIPB → JSON
        & ./publish/linux-x64/VipbJsonTool vipb2json $origVipb $tmpJson1
        $LASTEXITCODE | Should -Be 0 -Because "vipb2json conversion failed"

        # 2. Convert JSON → VIPB
        & ./publish/linux-x64/VipbJsonTool json2vipb $tmpJson1 $tmpVipb2
        $LASTEXITCODE | Should -Be 0 -Because "json2vipb conversion failed"

        # 3. Convert the new VIPB → JSON
        & ./publish/linux-x64/VipbJsonTool vipb2json $tmpVipb2 $tmpJson2
        $LASTEXITCODE | Should -Be 0 -Because "second vipb2json conversion failed"

        # 4. Load and normalize JSON text for comparison
        $jsonOrig       = Get-Content $tmpJson1 -Raw
        $jsonRoundTripped = Get-Content $tmpJson2 -Raw
        $normOrig = $jsonOrig        | ConvertFrom-Json | ConvertTo-Json -Depth 100
        $normRound = $jsonRoundTripped | ConvertFrom-Json | ConvertTo-Json -Depth 100

        # 5. Verify the JSON content is identical after the round-trip
        $normOrig | Should -Be $normRound -Because "Round-trip JSON mismatch – data was lost or altered"
    }

    AfterAll {
        # Clean up temporary files
        Remove-Item $tmpJson1, $tmpJson2, $tmpVipb2 -ErrorAction SilentlyContinue
    }
}
