param([string]$SourceFile = "tests/Samples/seed.vipb")

Describe "Golden Sample Full Coverage — $SourceFile" {

    It "enumerates all patchable aliases, patches them, and validates round‑trip" {

        function Join-IfArray($v) {
            if ($v -is [System.Collections.IEnumerable] -and $v -isnot [string]) { @($v) -join '' } else { $v }
        }

        ############# NON‑RECURSIVE LEAF ENUMERATION #############
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
        ##########################################################

        function Compare-AfterPatch($exp,$act,$patchMap,$path='') {
            if (($exp -is [pscustomobject] -or $exp -is [hashtable]) -and
                ($act -is [pscustomobject] -or $act -is [hashtable])) {
                foreach ($k in ($exp.psobject.Properties.Name + $act.psobject.Properties.Name | Sort-Object -Unique)) {
                    $e=$exp.$k; $a=$act.$k
                    if ($k -eq '#whitespace') {
                        if (Join-IfArray($e) -ne Join-IfArray($a)) {
                            $full = "$path.$k".Trim('.')
                            if ($patchMap.ContainsKey($full)) {
                                if (Join-IfArray($a) -ne $patchMap[$full]) { throw "patched field $full wrong" }
                            } else { throw "unpatched #whitespace changed at $full" }
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
            $pathClean = $path.TrimStart('.')
            if ($patchMap.ContainsKey($pathClean)) {
                if ($act -ne $patchMap[$pathClean]) { throw "patch fail $pathClean" }
            } elseif ($exp -ne $act) { throw "unpatched field Δ $pathClean" }
        }

        ######################## MAIN LOGIC ########################
        $jsonOrig    = [IO.Path]::GetTempFileName()
        $patchedVipb = [IO.Path]::GetTempPath() + ([guid]::NewGuid()).Guid + ".vipb"
        $jsonPatched = [IO.Path]::GetTempFileName()
        $patchYaml   = [IO.Path]::GetTempFileName()

        try {
            & ./publish/linux-x64/VipbJsonTool vipb2json $SourceFile $jsonOrig
            $orig = Get-Content $jsonOrig -Raw | ConvertFrom-Json

            $allPaths   = Get-LeafPaths $orig
            $patchMap   = @{}

            foreach ($p in $allPaths) {
                # Skip read‑only or problematic fields
                if ($p -like '*#whitespace*') { continue }
                if ($p -match '^@')           { continue }

                $origVal = Join-IfArray((Invoke-Expression "`$orig.$($p -replace '\.','.`')"))
                if ($origVal -is [bool])         { $patchMap[$p] = -not $origVal }
                elseif ($origVal -is [int64] -or $origVal -is [double]) { $patchMap[$p] = [double]$origVal + 1 }
                else                              { $patchMap[$p] = '__PATCHED__' }
            }

            # Emit YAML
            $yaml = @("schema_version: 1","patch:")
            foreach ($k in $patchMap.Keys) {
                $v = $patchMap[$k]
                if ($v -is [bool])   { $yaml += "  ${k}: $($v.ToString().ToLower())" }
                elseif ($v -is [string]) { $yaml += "  ${k}: '$($v -replace '''','''''')'" }
                else                 { $yaml += "  ${k}: $v" }
            }
            Set-Content $patchYaml $yaml -Encoding utf8

            # Patch & re‑round‑trip
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
