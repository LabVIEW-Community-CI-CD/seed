param(
    [string] $SourceVipb = "tests/Samples/NI Icon editor.vipb"
)

Describe "VIPB full serialization-fidelity round-trip" {

    It "patches every field and verifies only patched fields changed" {

        function Compare-JsonSemantic($expected, $actual, $patchMap, $path = "") {
            # Universal handling of #whitespace anywhere in the JSON
            if (
                ($expected -is [System.Management.Automation.PSCustomObject] -or $expected -is [System.Collections.IDictionary]) -and
                ($actual -is [System.Management.Automation.PSCustomObject] -or $actual -is [System.Collections.IDictionary])
            ) {
                if ($expected -is [System.Management.Automation.PSCustomObject]) { $expKeys = $expected.PSObject.Properties.Name }
                else { $expKeys = $expected.Keys }
                if ($actual -is [System.Management.Automation.PSCustomObject]) { $actKeys = $actual.PSObject.Properties.Name }
                else { $actKeys = $actual.Keys }
                $allKeys = $expKeys + $actKeys | Sort-Object -Unique

                foreach ($k in $allKeys) {
                    if ($k -eq "#whitespace") {
                        $a = ($expected -is [System.Management.Automation.PSCustomObject]) ? $expected.'#whitespace' : $expected["#whitespace"]
                        $b = ($actual   -is [System.Management.Automation.PSCustomObject]) ? $actual.'#whitespace'   : $actual["#whitespace"]
                        if ($a -is [System.Collections.IEnumerable] -and $a -isnot [string]) { $a = ($a -join "") }
                        if ($b -is [System.Collections.IEnumerable] -and $b -isnot [string]) { $b = ($b -join "") }
                        if ($patchMap.ContainsKey(("${path}.$k").TrimStart("."))) {
                            if ($b -ne $patchMap[("${path}.$k").TrimStart(".")]) {
                                throw "Patched field ${path}.$k did not get expected value (got '$b', expected '$($patchMap[("${path}.$k").TrimStart(".")])')"
                            }
                            continue
                        } elseif ($a -ne $b) {
                            throw "Unpatched #whitespace field at ${path}.$k changed unexpectedly (expected '$a', got '$b')"
                        }
                        continue
                    }
                    # Standard recursive compare for all other keys
                    if ($expected -is [System.Management.Automation.PSCustomObject]) { $e = $expected.$k } else { $e = $expected[$k] }
                    if ($actual   -is [System.Management.Automation.PSCustomObject]) { $a = $actual.$k   } else { $a = $actual[$k] }
                    Compare-JsonSemantic $e $a $patchMap ("${path}.$k")
                }
                return
            }
            if ($null -eq $expected -and $null -eq $actual) { return }
            elseif ($null -eq $expected -or $null -eq $actual) {
                throw "Difference at ${path}: one side is null, the other is not"
            }
            # Handle arrays
            elseif ($expected -is [System.Collections.IEnumerable] -and $expected -isnot [string] -and
                    $actual -is [System.Collections.IEnumerable] -and $actual -isnot [string]) {
                $expectedArray = @($expected)
                $actualArray   = @($actual)
                if ($expectedArray.Count -ne $actualArray.Count) {
                    throw "Difference at ${path}: array lengths differ ($($expectedArray.Count) vs $($actualArray.Count))"
                }
                for ($i = 0; $i -lt $expectedArray.Count; $i++) {
                    Compare-JsonSemantic $expectedArray[$i] $actualArray[$i] $patchMap ("${path}[$i]")
                }
            }
            # Array/scalar interop
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
            # Leaf: robust string/array/whitespace compare, with patch handling
            else {
                $a = $expected
                $b = $actual
                if ($a -is [System.Collections.IEnumerable] -and $a -isnot [string]) { $a = ($a -join "") }
                if ($b -is [System.Collections.IEnumerable] -and $b -isnot [string]) { $b = ($b -join "") }
                $fullPath = $path.TrimStart(".")
                if ($patchMap.ContainsKey($fullPath)) {
                    if ($b -ne $patchMap[$fullPath]) {
                        throw "Patched field $fullPath did not get expected value (got '$b', expected '$($patchMap[$fullPath])')"
                    }
                } elseif ($a -ne $b) {
                    throw "Unpatched field at $fullPath changed unexpectedly (expected '$a', got '$b')"
                }
            }
        }

        # File prep
        $tmpJson1 = [IO.Path]::GetTempFileName()
        $tmpVipb2 = [IO.Path]::Combine([IO.Path]::GetTempPath(), [IO.Path]::GetRandomFileName() + ".vipb")
        $tmpJson2 = [IO.Path]::GetTempFileName()
        $patchFilePath = [IO.Path]::Combine([IO.Path]::GetTempPath(), [IO.Path]::GetRandomFileName() + ".yml")

        try {
            # VIPB → JSON
            & ./publish/linux-x64/VipbJsonTool vipb2json $SourceVipb $tmpJson1
            $LASTEXITCODE | Should -Be 0 -Because "vipb2json conversion failed"
            (Test-Path $tmpJson1) | Should -BeTrue
            ((Get-Content $tmpJson1 -Raw).Trim().Length) | Should -BeGreaterThan 0

            $jsonObj = Get-Content $tmpJson1 -Raw | ConvertFrom-Json

            # Gather all leaf paths
            $allPaths = New-Object System.Collections.Generic.List[string]
            function Add-Paths ($obj, $prefix = "") {
                if ($obj -is [System.Management.Automation.PSCustomObject]) {
                    foreach ($k in $obj.PSObject.Properties.Name) {
                        Add-Paths $obj.$k ($prefix ? "$prefix.$k" : $k)
                    }
                }
                elseif ($obj -is [System.Collections.IDictionary]) {
                    foreach ($k in $obj.Keys) {
                        Add-Paths $obj[$k] ($prefix ? "$prefix.$k" : $k)
                    }
                }
                elseif ($obj -is [System.Collections.IEnumerable] -and $obj -isnot [string]) {
                    $i = 0
                    foreach ($v in $obj) {
                        Add-Paths $v ($prefix ? "$prefix[$i]" : "[$i]")
                        $i++
                    }
                }
                else {
                    if ($prefix) { $allPaths.Add($prefix) }
                }
            }
            Add-Paths $jsonObj ""
            $allPaths = $allPaths | Sort-Object -Unique

            # Build a patch map (new value for every path)
            $patchMap = @{}
            function Get-ValueByPath($obj, [string[]] $parts, $index = 0) {
                if ($obj -eq $null) { return $null }
                if ($index -ge $parts.Length) { return $obj }
                $part = $parts[$index]
                # Array index
                if ($part -match '^(.*)\[(\d+)\]$') {
                    $name = $matches[1]; $idx = [int] $matches[2]
                    $child = ($obj -is [System.Management.Automation.PSCustomObject]) ? $obj.$name : $obj[$name]
                    if ($child -eq $null -or $child.Count -le $idx) { return $null }
                    return Get-ValueByPath $child $parts ($index + 1)
                }
                else {
                    if (($obj -is [System.Management.Automation.PSCustomObject] -and -not ($obj.PSObject.Properties.Name -contains $part)) -or
                        ($obj -is [System.Collections.IDictionary] -and -not ($obj.Keys -contains $part))) { return $null }
                    $child = ($obj -is [System.Management.Automation.PSCustomObject]) ? $obj.$part : $obj[$part]
                    return Get-ValueByPath $child $parts ($index + 1)
                }
            }
            foreach ($path in $allPaths) {
                $origVal = Get-ValueByPath $jsonObj ($path -split '\.')
                if ($origVal -is [bool]) { $newVal = -not $origVal }
                elseif ($origVal -is [int] -or $origVal -is [long] -or $origVal -is [double] -or $origVal -is [decimal]) { $newVal = try { [double]$origVal + 1 } catch { 1 } }
                elseif ($origVal -eq $null) { $newVal = "__PATCHED_NULL__" }
                else { $newVal = "__PATCHED__" }
                if ($origVal -ne $null -and $origVal -eq $newVal) {
                    if ($origVal -is [string]) { $newVal = "${origVal}_PATCHED" }
                    elseif ($origVal -is [bool]) { $newVal = -not $origVal }
                    elseif ($origVal -is [double] -or $origVal -is [int]) { $newVal = $origVal + 1 }
                    else { $newVal = "__PATCHED__" }
                }
                $patchMap[$path] = $newVal
            }

            # Write the patch as YAML
            $patchLines = @("schema_version: 1", "patch:")
            foreach ($p in $patchMap.Keys) {
                $val = $patchMap[$p]
                if ($val -is [bool]) { $patchLines += "  $p: $($val.ToString().ToLower())" }
                elseif ($val -is [string]) { $escaped = $val -replace "'", "''"; $patchLines += "  $p: '$escaped'" }
                else { $patchLines += "  $p: $val" }
            }
            Set-Content -Path $patchFilePath -Value $patchLines -Encoding UTF8

            # Apply the patch and rebuild VIPB
            & ./publish/linux-x64/VipbJsonTool patch2vipb $tmpJson1 $tmpVipb2 $patchFilePath
            $LASTEXITCODE | Should -Be 0

            # Convert the patched VIPB back to JSON
            & ./publish/linux-x64/VipbJsonTool vipb2json $tmpVipb2 $tmpJson2
            $LASTEXITCODE | Should -Be 0

            # Load JSON objects for comparison
            $origJsonObj  = Get-Content $tmpJson1 -Raw | ConvertFrom-Json
            $roundJsonObj = Get-Content $tmpJson2 -Raw | ConvertFrom-Json

            # Recursively compare, tolerating array/scalar/whitespace ambiguity, and allowing only patched fields to change
            Compare-JsonSemantic $origJsonObj $roundJsonObj $patchMap
        }
        finally {
            Remove-Item $tmpJson1, $tmpJson2, $tmpVipb2, $patchFilePath -ErrorAction SilentlyContinue
        }
    }
}
