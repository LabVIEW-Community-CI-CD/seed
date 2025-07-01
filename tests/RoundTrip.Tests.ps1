param()

Describe "VIPB round-trip equivalence via JSON" {

    It "serializes to JSON and back to VIPB with no data loss" {
        $origVipb = "tests/Samples/NI Icon editor.vipb"
        $tmpJson1 = [IO.Path]::GetTempFileName()
        $tmpVipb2 = [IO.Path]::Combine([IO.Path]::GetTempPath(), [IO.Path]::GetRandomFileName() + ".vipb")
        $tmpJson2 = [IO.Path]::GetTempFileName()

        try {
            # 1. Convert VIPB → JSON
            & ./publish/linux-x64/VipbJsonTool vipb2json $origVipb $tmpJson1
            $LASTEXITCODE | Should -Be 0 -Because "vipb2json conversion failed"
            (Test-Path $tmpJson1) | Should -BeTrue -Because "First JSON output file was not created"
            ((Get-Content $tmpJson1 -Raw).Trim().Length) | Should -BeGreaterThan 0 -Because "First JSON output file is empty"

            # 2. Convert JSON → VIPB
            & ./publish/linux-x64/VipbJsonTool json2vipb $tmpJson1 $tmpVipb2
            $LASTEXITCODE | Should -Be 0 -Because "json2vipb conversion failed"
            (Test-Path $tmpVipb2) | Should -BeTrue -Because "VIPB reserialization failed"

            # 3. Convert the new VIPB → JSON
            & ./publish/linux-x64/VipbJsonTool vipb2json $tmpVipb2 $tmpJson2
            $LASTEXITCODE | Should -Be 0 -Because "second vipb2json conversion failed"
            (Test-Path $tmpJson2) | Should -BeTrue -Because "Second JSON output file was not created"
            ((Get-Content $tmpJson2 -Raw).Trim().Length) | Should -BeGreaterThan 0 -Because "Second JSON output file is empty"

            # 4. Load and normalize JSON text for comparison
            try {
                $jsonOrig = Get-Content $tmpJson1 -Raw | ConvertFrom-Json
                $jsonRound = Get-Content $tmpJson2 -Raw | ConvertFrom-Json
            } catch {
                Write-Host "=== Begin $tmpJson1 ==="
                Get-Content $tmpJson1
                Write-Host "=== End $tmpJson1 ==="
                Write-Host "=== Begin $tmpJson2 ==="
                Get-Content $tmpJson2
                Write-Host "=== End $tmpJson2 ==="
                throw "JSON conversion failed: $($_.Exception.Message)"
            }
            $normOrig = $jsonOrig | ConvertTo-Json -Depth 100
            $normRound = $jsonRound | ConvertTo-Json -Depth 100

            # 5. Verify the JSON content is identical after the round-trip
            $normOrig | Should -Be $normRound -Because "Round-trip JSON mismatch – data was lost or altered"
        }
        finally {
            # Defensive cleanup
            foreach ($f in @($tmpJson1, $tmpJson2, $tmpVipb2)) {
                if ($f -and (Test-Path $f)) { Remove-Item $f -ErrorAction SilentlyContinue }
            }
        }
    }
}
