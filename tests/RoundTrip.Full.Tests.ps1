param(
    [string] $SourceVipb = "tests/Samples/NI Icon editor.vipb"
)

Describe "VIPB full serialization-fidelity round-trip" {

    BeforeAll {
        # Temporary file paths for conversion steps
        $tmpJson1     = [IO.Path]::Combine([IO.Path]::GetTempPath(), [IO.Path]::GetRandomFileName() + ".json")
        $tmpVipb2     = [IO.Path]::Combine([IO.Path]::GetTempPath(), [IO.Path]::GetRandomFileName() + ".vipb")
        $tmpJson2     = [IO.Path]::Combine([IO.Path]::GetTempPath(), [IO.Path]::GetRandomFileName() + ".json")
        $patchFilePath = [IO.Path]::Combine([IO.Path]::GetTempPath(), [IO.Path]::GetRandomFileName() + ".yml")

        # 1. VIPB → JSON
        & ./publish/linux-x64/VipbJsonTool vipb2json $SourceVipb $tmpJson1
        if ($LASTEXITCODE -ne 0) { throw "vipb2json failed (exit code $LASTEXITCODE)" }

        # 2. Enumerate all JSON leaf paths from the output
        $jsonObj = Get-Content $tmpJson1 -Raw | ConvertFrom-Json
        $allPaths = New-Object System.Collections.Generic.List[string]
        function Add-Paths ($obj, $prefix = "") {
            if ($obj -is [System.Collections.IDictionary]) {
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

        # Remove duplicate paths and sort for consistency
        $allPaths = $allPaths | Sort-Object -Unique
        if ($allPaths.Count -eq 0) { Write-Warning "No JSON paths enumerated from VIPB (unexpected)"; }

        # 3. Build a patch map with new values for every path (type-specific)
        $patchMap = @{}
        function Get-ValueByPath($obj, [string[]] $parts, $index = 0) {
            # Recursively get the value at a dotted path (with [index] support) from a JSON object
            if ($obj -eq $null) { return $null }
            if ($index -ge $parts.Length) { return $obj }
            $part = $parts[$index]
            if ($part -match '^(.*)\[(\d+)\]$') {
                $name = $matches[1]; $idx = [int] $matches[2]
                $child = $obj.$name
                if ($child -eq $null -or $child.Count -le $idx) { return $null }
                return Get-ValueByPath $child[$idx] $parts ($index + 1)
            }
            else {
                if (-not ($obj.PSObject.Properties.Name -contains $part)) { return $null }
                return Get-ValueByPath $obj.$part $parts ($index + 1)
            }
        }
        foreach ($path in $allPaths) {
            # Retrieve original value for this path:
            $origVal = Get-ValueByPath $jsonObj ($path -split '\.')
            # Determine a new value different from original, based on type
            if ($origVal -is [bool]) {
                $newVal = -not $origVal                    # flip boolean
            }
            elseif ($origVal -is [int] -or $origVal -is [long] -or $origVal -is [double] -or $origVal -is [decimal]) {
                $newVal = try { [double]$origVal + 1 } catch { 1 }   # increment numeric
            }
            elseif ($origVal -eq $null) {
                $newVal = "__PATCHED_NULL__"               # replace null with placeholder string
            }
            else {
                $newVal = "__PATCHED__"                    # default: replace string/text with placeholder
            }
            # Ensure the new value actually differs from original
            if ($origVal -ne $null -and $origVal -eq $newVal) {
                if ($origVal -is [string])    { $newVal = "${origVal}_PATCHED" }
                elseif ($origVal -is [bool]) { $newVal = -not $origVal }
                elseif ($origVal -is [double] -or $origVal -is [int]) { $newVal = $origVal + 1 }
                else { $newVal = "__PATCHED__" }
            }
            $patchMap[$path] = $newVal
        }

        # 4. Write the patch map to a YAML file (schema_version 1)
        $patchLines = @("schema_version: 1", "patch:")
        foreach ($p in $patchMap.Keys) {
            $val = $patchMap[$p]
            if ($val -is [bool]) {
                $patchLines += "  $p: $($val.ToString().ToLower())"
            }
            elseif ($val -is [string]) {
                $escaped = $val -replace "'", "''"
                $patchLines += "  $p: '$escaped'"
            }
            else {
                # numeric (int/double)
                $patchLines += "  $p: $val"
            }
        }
        Set-Content -Path $patchFilePath -Value $patchLines -Encoding UTF8

        # 5. Apply the patch and rebuild VIPB
        & ./publish/linux-x64/VipbJsonTool patch2vipb $tmpJson1 $tmpVipb2 $patchFilePath
        if ($LASTEXITCODE -ne 0) { throw "patch2vipb failed (exit code $LASTEXITCODE)" }

        # 6. Convert the patched VIPB back to JSON
        & ./publish/linux-x64/VipbJsonTool vipb2json $tmpVipb2 $tmpJson2
        if ($LASTEXITCODE -ne 0) { throw "vipb2json after patch failed (exit code $LASTEXITCODE)" }

        # Load original and round-tripped JSON into objects for comparison
        $origJsonObj  = Get-Content $tmpJson1 -Raw | ConvertFrom-Json
        $roundJsonObj = Get-Content $tmpJson2 -Raw | ConvertFrom-Json
    }

    It "preserves all fields except those explicitly patched" {
        # Recursive comparison: ensure only patched paths differ (and match expected new values)
        function Compare-Json ($orig, $round, $path = "") {
            if ($patchMap.ContainsKey($path)) {
                # Patched field: verify it changed to the expected value
                $round | Should -Be $patchMap[$path] -Because "Field `$path` did not match patched value"
                return
            }
            if ($orig -is [System.Collections.IDictionary]) {
                foreach ($key in ($orig.Keys + $round.Keys | Sort-Object -Unique)) {
                    Compare-Json $orig[$key] $round[$key] ($path ? "$path.$key" : $key)
                }
            }
            elseif ($orig -is [System.Collections.IEnumerable] -and $orig -isnot [string]) {
                # Check array length consistency
                $orig.Count | Should -Be $round.Count -Because "Array length changed at `$path`"
                for ($i = 0; $i -lt $orig.Count; $i++) {
                    $newPath = $path ? "$path[$i]" : "[$i]"
                    Compare-Json $orig[$i] $round[$i] $newPath
                }
            }
            else {
                # Unchanged leaf field: should remain identical
                $round | Should -Be $orig -Because "Unpatched field `$path` was altered"
            }
        }
        Compare-Json $origJsonObj $roundJsonObj
    }

    AfterAll {
        # Clean up temporary files
        Remove-Item $tmpJson1, $tmpJson2, $tmpVipb2, $patchFilePath -ErrorAction SilentlyContinue
    }
}
