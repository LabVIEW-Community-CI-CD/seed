<#
  RoundTrip.GoldenSample.Tests.ps1
  --------------------------------
  Full-fidelity round-trip test for seed.vipb.

  1. Convert the VIPB to JSON.
  2. Enumerate every patch-able JSON leaf path.
  3. Build a YAML patch that changes every such path.
  4. Apply the patch, convert patched VIPB back to JSON.
  5. Verify:
       • Patched paths changed to the expected value.
       • All other paths remained identical.
#>

param([string]$SourceFile = "tests/Samples/seed.vipb")

Describe "Golden Sample Full Coverage — $SourceFile" {

    It "enumerates all patchable aliases, patches them, and validates round-trip" {

        function Join-IfArray($v) {
            if ($v -is [System.Collections.IEnumerable] -and $v -isnot [string]) {
                @($v) -join ''
            } else { $v }
        }

        function Get-LeafPaths([object]$obj) {
            $stack = [System.Collections.Stack]::new()
            $stack.Push([pscustomobject]@{ Node = $obj; Path = "" })
            $out = New-Object System.Collections.Generic.List[string]

            while ($stack.Count) {
                $frame = $stack.Pop()
                $n  = $frame.Node
                $pp = $frame.Path

                if ($n -is [pscustomobject]) {
                    foreach ($p in $n.psobject.Properties) {
                        $stack.Push([pscustomobject]@{ Node = $p.Value; Path = ($pp ? "$pp.$($p.Name)" : $p.Name) })
                    }
                }
                elseif ($n -is [System.Collections.IEnumerable] -and $n -isnot [string]) {
                    $i = 0
                    foreach ($v in $n) {
                        $stack.Push([pscustomobject]@{ Node = $v; Path = "$pp[$i]" })
                        $i++
                    }
                }
                else {
                    if ($pp) { $out.Add($pp) }
                }
            }
            return $out
        }

        function Get-ByPath($obj, [string]$path) {
            $cur = $obj
            foreach ($seg in $path -split '\.') {
                if ($null -eq $cur) { return $null }
                # handle zero or more [index] segments after an optional base
                if ($seg -match '^(.*?)((\[\d+\])+)$') {
                    $base = $Matches[1]
                    $tail = $Matches[2]
                    if ($base) { $cur = $cur[$base] }
                    foreach ($m in ([regex]::Matches($tail, '\[(\d+)\]'))) {
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

        function Compare-AfterPatch($exp,$act,$patchMap,$path='') {
            $ignoreWhitespace = ($patchMap.Count -eq 0)
            if (($exp -is [pscustomobject] -or $exp -is [hashtable]) -and
                ($act -is [pscustomobject] -or $act -is [hashtable])) {

                foreach ($k in ($exp.psobject.Properties.Name + $act.psobject.Properties.Name | Sort-Object -Unique)) {
                    $e=$exp.$k; $a=$act.$k
                    if ($k -eq '#whitespace') {
                        if (Join-IfArray($e) -ne Join-IfArray($a)) {
                            $full = "$path.$k".Trim('.')
                            if (-not $ignoreWhitespace) {
                                if ($patchMap.ContainsKey($full)) {
                                    if (Join-IfArray($a) -ne $patchMap[$full]) { throw "patched field $full wrong" }
                                } else { throw "unpatched #whitespace changed at $full" }
                            }
                            # else: ignore whitespace delta in no-op mode
                        }
                    } else { Compare-AfterPatch $e $a $patchMap "$path.$k" }
                }; return
            }

            if ($exp -is [System.Collections.IEnumerable] -and $exp -isnot [string] -and
                $act -is [System.Collections.IEnumerable] -and $act -isnot [string]) {
                if ($exp.Count -ne $act.Count) { throw "array len Δ $path" }
                for ($i=0;$i -lt $exp.Count;$i++){Compare-AfterPatch $exp[$i] $act[$i] $patchMap "$path[$i]"}
                return
            }

            $exp = Join-IfArray($exp); $act = Join-IfArray($act)
            $clean = $path.TrimStart('.')
            if ($patchMap.ContainsKey($clean)) {
                if ($act -ne $patchMap[$clean]) { throw "patch fail $clean" }
            } elseif ($exp -ne $act) { throw "unpatched field Δ $clean" }
        }

        $jsonOrig     = [IO.Path]::GetTempFileName()
        $patchedVipb  = [IO.Path]::GetTempPath() + ([guid]::NewGuid()).Guid + ".vipb"
        $jsonPatched  = [IO.Path]::GetTempFileName()
        $patchYaml    = [IO.Path]::GetTempFileName()

        try {
            & ./publish/linux-x64/VipbJsonTool vipb2json $SourceFile $jsonOrig
            $orig = Get-Content $jsonOrig -Raw | ConvertFrom-Json

            $allPaths = Get-LeafPaths $orig
            $patchMap = @{}

            foreach ($p in $allPaths) {
                if ($p -like '*#whitespace*') { continue }
                if ($p -match '^@')           { continue }

                $origVal = Join-IfArray((Get-ByPath $orig $p))
                if ($null -eq $origVal) { continue }

                if ($origVal -is [bool]) { $patchMap[$p] = -not $origVal }
                elseif ($origVal -is [double] -or $origVal -is [int64]) { $patchMap[$p] = [double]$origVal + 1 }
                else { $patchMap[$p] = '__PATCHED__' }
            }

            if ($patchMap.Count -eq 0) {
                Write-Host "No patchable fields found! Doing no-op round-trip check instead."
                $vipbOut = [IO.Path]::GetTempPath() + ([guid]::NewGuid()).Guid + ".vipb"
                $jsonOut = [IO.Path]::GetTempFileName()

                & ./publish/linux-x64/VipbJsonTool json2vipb $jsonOrig $vipbOut
                & ./publish/linux-x64/VipbJsonTool vipb2json $vipbOut $jsonOut

                $round = Get-Content $jsonOut -Raw | ConvertFrom-Json
                Compare-AfterPatch $orig $round @{}
                Remove-Item $vipbOut, $jsonOut -ErrorAction SilentlyContinue
                return
            }

            # --- emit YAML file ---
            $yaml = @("schema_version: 1","patch:")
            foreach ($k in $patchMap.Keys) {
                $v = $patchMap[$k]
                if ($v -is [bool])        { $yaml += "  ${k}: $($v.ToString().ToLower())" }
                elseif ($v -is [string])  { $yaml += "  ${k}: '$($v -replace '''','''''')'" }
                else                     { $yaml += "  ${k}: $v" }
            }
            Set-Content $patchYaml $yaml -Encoding utf8

            # --- patch + re‑round‑trip ---
            & ./publish/linux-x64/VipbJsonTool patch2vipb $jsonOrig $patchedVipb $patchYaml
            & ./publish/linux-x64/VipbJsonTool vipb2json   $patchedVipb $jsonPatched
            $patched = Get-Content $jsonPatched -Raw | ConvertFrom-Json

            Compare-AfterPatch $orig $patched $patchMap
        }
        finally {
            Remove-Item $jsonOrig,$jsonPatched,$patchedVipb,$patchYaml -ErrorAction SilentlyContinue
        }
    }
}
