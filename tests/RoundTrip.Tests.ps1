param()

Describe "VIPB round-trip equivalence via JSON" {

    It "serializes to JSON and back to VIPB with no data loss" {

        function Compare-JsonSemantic($expected, $actual, $path = "") {
            # Special-case root #whitespace
            if (
                $path -eq "" -and
                $expected.PSObject.Properties.Name -contains '#whitespace' -and
                $actual.PSObject.Properties.Name -contains '#whitespace'
            ) {
                $a = $expected.'#whitespace'
                $b = $actual.'#whitespace'
                if ($a -is [System.Collections.IEnumerable] -and $a -isnot [string]) { $a = ($a -join "") }
                if ($b -is [System.Collections.IEnumerable] -and $b -isnot [string]) { $b = ($b -join "") }
                if ($a -ne $b) {
                    throw "Difference at ${path}.#whitespace: expected '$a', got '$b'"
                }
                $expected.PSObject.Properties.Remove('#whitespace')
                $actual.PSObject.Properties.Remove('#whitespace')
            }

            if ($null -eq $expected -and $null -eq $actual) { return }
            elseif ($null -eq $expected -or $null -eq $actual) {
                throw "Difference at ${path}: one side is null, the other is not"
            }
            elseif ($expected -is [System.Management.Automation.PSCustomObject] -and $actual -is [System.Management.Automation.PSCustomObject]) {
                $allKeys = $expected.PSObject.Properties.Name + $actual.PSObject.Properties.Name | Sort-Object -Unique
                foreach ($k in $allKeys) {
                    Compare-JsonSemantic $expected.$k $actual.$k ("${path}.$k")
                }
            }
            elseif ($expected -is [System.Collections.IDictionary] -and $actual -is [System.Collections.IDictionary]) {
                $allKeys = $expected.Keys + $actual.Keys | Sort-Object -Unique
                foreach ($k in $allKeys) {
                    Compare-JsonSemantic $expected[$k] $actual[$k] ("${path}.$k")
                }
            }
            elseif ($expected -is [System.Collections.IEnumerable] -and $expected -isnot [string] -and
                    $actual -is [System.Collections.IEnumerable] -and $actual -isnot [string]) {
                $expectedArray = @($expected)
                $actualArray   = @($actual)
                if ($expectedArray.Count -ne $actualArray.Count) {
                    throw "Difference at ${path}: array lengths differ ($($expectedArray.Count) vs $($actualArray.Count))"
                }
                for ($i = 0; $i -lt $expectedArray.Count; $i++) {
                    Compare-JsonSemantic $expectedArray[$i] $actualArray[$i] ("${path}[$i]")
                }
            }
            elseif ($expected -is [System.Collections.IEnumerable] -and $expected -isnot [string] -and
                    ($actual -isnot [System.Collections.IEnumerable] -or $actual -is [string])) {
                if ($expected.Count -eq 1 -and $expected[0] -eq $actual) { return }
                throw "Difference at ${path}: expected array, actual scalar"
            }
            elseif (($expected -isnot [System.Collections.IEnumerable] -or $expected -is [string]) -and
                    $actual -is [System.Collections.IEnumerable] -and $actual -isnot [string]) {
                if ($actual.Count -eq 1 -and $actual[0] -eq $expected) { return }
                throw "Difference at ${path}: expected scalar, actual array"
            }
            else {
                # Robust string/array/whitespace comparison
                $a = $expected
                $b = $actual
                if ($a -is [System.Collections.IEnumerable] -and $a -isnot [string]) { $a = ($a -join "") }
                if ($b -is [System.Collections.IEnumerable] -and $b -isnot [string]) { $b = ($b -join "") }
                if ($a -ne $b) {
                    throw "Difference at ${path}: expected '$a', got '$b'"
                }
            }
        }

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

            # 4. Load and compare JSON objects
            try {
                $jsonOrig  = Get-Content $tmpJson1 -Raw | ConvertFrom-Json
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

            # 5. Recursively compare, tolerating array/scalar/whitespace ambiguity
            Compare-JsonSemantic $jsonOrig $jsonRound
        }
        finally {
            # Clean up temporary files
            foreach ($f in @($tmpJson1, $tmpJson2, $tmpVipb2)) {
                if ($f -and (Test-Path $f)) { Remove-Item $f -ErrorAction SilentlyContinue }
            }
        }
    }
}
