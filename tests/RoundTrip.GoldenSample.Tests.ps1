<#
  RoundTrip.GoldenSample.Tests.ps1
  --------------------------------
  Full-fidelity round-trip tests for seed.vipb and seed.lvproj.

  For each file:
  1. Convert the file (VIPB or LVPROJ) to JSON.
  2. Enumerate every patchable JSON leaf path.
  3. Build a YAML patch that changes every such path.
  4. Apply the patch, convert the patched file back to JSON.
  5. Verify:
       • Patched paths changed to the expected value.
       • All other paths remained identical.
#>

Describe "Golden Sample Full Coverage — VIPB and LVPROJ" {

    # Helper functions for JSON traversal and comparison
    function Join-IfArray($v) {
        if ($v -is [System.Collections.IEnumerable] -and $v -isnot [string]) {
            @($v) -join ''
        } else {
            $v
        }
    }

    function Get-LeafPaths([object]$obj) {
        $stack = [System.Collections.Stack]::new()
        $stack.Push([pscustomobject]@{ Node = $obj; Path = "" })
        $out = New-Object System.Collections.Generic.List[string]
        while ($stack.Count) {
            $frame = $stack.Pop()
            $node  = $frame.Node
            $path  = $frame.Path
            if ($node -is [pscustomobject] -or $node -is [hashtable]) {
                foreach ($p in $node.psobject.Properties) {
                    $newPath = ($path ? "$path.$($p.Name)" : $p.Name)
                    $stack.Push([pscustomobject]@{ Node = $p.Value; Path = $newPath })
                }
            }
            elseif ($node -is [System.Collections.IEnumerable] -and $node -isnot [string]) {
                $i = 0
                foreach ($v in $node) {
                    $stack.Push([pscustomobject]@{ Node = $v; Path = "$path[$i]" })
                    $i++
                }
            }
            else {
                if ($path) { $out.Add($path) }
            }
        }
        return $out
    }

    function Get-ByPath($obj, [string]$path) {
        $cur = $obj
        foreach ($seg in $path -split '\.') {
            if ($null -eq $cur) { return $null }
            # Handle any [index] segments in the path
            if ($seg -match '^(.*?)((\[\d+\])+)$') {
                $base = $Matches[1]
                $indices = $Matches[2]
                if ($base) { $cur = $cur[$base] }
                foreach ($m in ([regex]::Matches($indices, '\[(\d+)\]'))) {
                    if ($null -eq $cur) { return $null }
                    $cur = $cur[[int]$m.Groups[1].Value]
                }
            }
            else {
                $cur = $cur[$seg]
            }
        }
        return $cur
    }

    function Compare-AfterPatch($expected, $actual, $patchMap, $path='') {
        $ignoreWhitespace = ($patchMap.Count -eq 0)
        if ((($expected -is [pscustomobject]) -or ($expected -is [hashtable])) -and 
            (($actual   -is [pscustomobject]) -or ($actual   -is [hashtable]))) {
            # Compare all keys in the combined set
            foreach ($key in ($expected.psobject.Properties.Name + $actual.psobject.Properties.Name | Sort-Object -Unique)) {
                $expVal = $expected.$key
                $actVal = $actual.$key
                if ($key -eq '#whitespace') {
                    # Normalize whitespace nodes to strings for comparison
                    if (Join-IfArray($expVal) -ne Join-IfArray($actVal)) {
                        $fullPath = "$path.$key".Trim('.')
                        if (-not $ignoreWhitespace) {
                            if ($patchMap.ContainsKey($fullPath)) {
                                if (Join-IfArray($actVal) -ne $patchMap[$fullPath]) {
                                    throw "patched field $fullPath has incorrect whitespace"
                                }
                            } else {
                                throw "unpatched #whitespace changed at $fullPath"
                            }
                        }
                        # If ignoring whitespace (no patches), do nothing on whitespace diffs
                    }
                }
                else {
                    Compare-AfterPatch $expVal $actVal $patchMap "$path.$key"
                }
            }
            return
        }
        elseif (($expected -is [System.Collections.IEnumerable] -and $expected -isnot [string]) -and
                ($actual   -is [System.Collections.IEnumerable] -and $actual   -isnot [string])) {
            # Compare arrays element-wise
            if ($expected.Count -ne $actual.Count) {
                throw "array length mismatch at $path"
            }
            for ($i = 0; $i -lt $expected.Count; $i++) {
                Compare-AfterPatch $expected[$i] $actual[$i] $patchMap "$path[$i]"
            }
            return
        }
        # For leaf values (scalars or single-element arrays), flatten any arrays for fair comparison
        $expected = Join-IfArray($expected)
        $actual   = Join-IfArray($actual)
        $cleanPath = $path.TrimStart('.')
        if ($patchMap.ContainsKey($cleanPath)) {
            # Patched field: verify it matches the expected patched value
            if ($actual -ne $patchMap[$cleanPath]) {
                throw "patched field $cleanPath did not update correctly"
            }
        }
        elseif ($expected -ne $actual) {
            # Unpatched field changed, which is a failure
            throw "unpatched field changed at $cleanPath"
        }
    }

    function Test-RoundTrip($SourceFile) {
        # Determine file type and corresponding CLI modes
        $ext = ([IO.Path]::GetExtension($SourceFile)).ToLower()
        switch ($ext) {
            ".vipb"   { $toJsonMode = "vipb2json";  $toXmlMode = "json2vipb";  $patchMode = "patch2vipb"  }
            ".lvproj" { $toJsonMode = "lvproj2json"; $toXmlMode = "json2lvproj"; $patchMode = "patch2lvproj" }
            default   { throw "Unsupported file type: $ext" }
        }

        # Temporary file paths for intermediate outputs
        $jsonOrig    = [IO.Path]::GetTempFileName()
        $patchedFile = [IO.Path]::GetTempPath() + ([guid]::NewGuid()).Guid + $ext
        $jsonPatched = [IO.Path]::GetTempFileName()
        $patchYaml   = [IO.Path]::GetTempFileName()

        try {
            # 1. Convert original file to JSON
            & ./publish/linux-x64/VipbJsonTool $toJsonMode $SourceFile $jsonOrig
            $orig = Get-Content $jsonOrig -Raw | ConvertFrom-Json

            # 2. Enumerate all patchable JSON leaf paths (exclude whitespace nodes and XML attributes)
            $allPaths = Get-LeafPaths $orig
            $patchMap = @{}
            foreach ($p in $allPaths) {
                if ($p -like '*#whitespace*') { continue }
                if ($p -match '^@')           { continue }
                $origVal = Join-IfArray (Get-ByPath $orig $p)
                if ($null -eq $origVal) { continue }
                if ($origVal -is [bool]) {
                    $patchMap[$p] = -not $origVal
                }
                elseif ($origVal -is [double] -or $origVal -is [int64]) {
                    $patchMap[$p] = [double]$origVal + 1
                }
                else {
                    $patchMap[$p] = '__PATCHED__'
                }
            }

            if ($patchMap.Count -eq 0) {
                # No fields to patch – perform a no-op round-trip and compare
                Write-Host "No patchable fields found in $SourceFile! Performing no-op round-trip."
                $tempOut = [IO.Path]::GetTempPath() + ([guid]::NewGuid()).Guid + $ext
                $jsonOut = [IO.Path]::GetTempFileName()
                & ./publish/linux-x64/VipbJsonTool $toXmlMode $jsonOrig $tempOut
                & ./publish/linux-x64/VipbJsonTool $toJsonMode $tempOut $jsonOut
                $roundTripJson = Get-Content $jsonOut -Raw | ConvertFrom-Json
                Compare-AfterPatch $orig $roundTripJson @{}  # Expect identical JSON (ignoring whitespace)
                Remove-Item $tempOut, $jsonOut -ErrorAction SilentlyContinue
                return
            }

            # 3. Build the YAML patch file with all patches
            $yamlLines = @("schema_version: 1", "patch:")
            foreach ($key in $patchMap.Keys) {
                $val = $patchMap[$key]
                if ($val -is [bool]) {
                    $yamlLines += "  ${key}: $($val.ToString().ToLower())"
                }
                elseif ($val -is [string]) {
                    # Quote string and escape any single quotes
                    $yamlLines += "  ${key}: '$($val -replace '''','''''')'"
                }
                else {
                    $yamlLines += "  ${key}: $val"
                }
            }
            Set-Content $patchYaml $yamlLines -Encoding utf8

            # 4. Apply the patch to the JSON and convert back to the original format
            & ./publish/linux-x64/VipbJsonTool $patchMode $jsonOrig $patchedFile $patchYaml
            & ./publish/linux-x64/VipbJsonTool $toJsonMode $patchedFile $jsonPatched
            $patchedJson = Get-Content $jsonPatched -Raw | ConvertFrom-Json

            # 5. Verify patched vs original JSON
            Compare-AfterPatch $orig $patchedJson $patchMap
        }
        finally {
            # Clean up temp files
            Remove-Item $jsonOrig, $jsonPatched, $patchedFile, $patchYaml -ErrorAction SilentlyContinue
        }
    }

    It "maintains full round-trip fidelity for seed.vipb (with all fields patched)" {
        Test-RoundTrip "tests/Samples/seed.vipb"
    }

    It "maintains full round-trip fidelity for seed.lvproj (with all fields patched)" {
        Test-RoundTrip "tests/Samples/seed.lvproj"
    }
}
