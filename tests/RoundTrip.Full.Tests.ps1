param(
    [string] $SourceVipb = "tests/Samples/NI Icon editor.vipb"
)

Describe "VIPB 100% field-coverage and alias enumeration" {

    It "prints all JSON aliases and verifies full patch coverage" {

        function Join-IfArray($v){if($v -is [System.Collections.IEnumerable] -and $v -isnot [string]){@($v) -join ''}else{$v}}

        function Get-LeafPaths([object]$obj, [string]$prefix='') {
            $list = New-Object System.Collections.Generic.List[string]
            if($obj -is [pscustomobject]) {
                foreach($n in $obj.PSObject.Properties.Name){
                    $list.AddRange( Get-LeafPaths $obj.$n, ($prefix ? "$prefix.$n" : $n) )
                }
            } elseif($obj -is [System.Collections.IEnumerable] -and $obj -isnot [string]) {
                $i=0; foreach($v in $obj){$list.AddRange( Get-LeafPaths $v, "$prefix[$i]");$i++}
            } else { if($prefix){$list.Add($prefix)} }
            return $list
        }

        function Compare-AfterPatch($exp,$act,$patchMap,$path=''){
            if(($exp -is [pscustomobject] -or $exp -is [hashtable]) -and
               ($act -is [pscustomobject] -or $act -is [hashtable])){
                $keys = ($exp.PSObject.Properties.Name + $act.PSObject.Properties.Name | Select-Object -Unique)
                foreach($k in $keys){
                    $e=$exp.$k; $a=$act.$k
                    if($k -eq '#whitespace'){
                        if(Join-IfArray($e) -ne Join-IfArray($a)){
                            $full="$path.$k".Trim('.')
                            if($patchMap.ContainsKey($full)){
                                if(Join-IfArray($a) -ne $patchMap[$full]){
                                    throw "patched field $full wrong"
                                }
                            } else { throw "unpatched #whitespace changed at $full" }
                        }
                    } else {Compare-AfterPatch $e $a $patchMap "$path.$k"}
                }; return
            }
            if($exp -is [System.Collections.IEnumerable] -and $exp -isnot [string] -and
               $act -is [System.Collections.IEnumerable] -and $act -isnot [string]){
                if($exp.Count -ne $act.Count){throw "array len Δ $path"}
                for($i=0;$i -lt $exp.Count;$i++){Compare-AfterPatch $exp[$i] $act[$i] $patchMap "$path[$i]"}
                return
            }
            if($exp -isnot [string] -and $exp -is [System.Collections.IEnumerable] -and $exp.Count -eq 1){$exp=$exp[0]}
            if($act -isnot [string] -and $act -is [System.Collections.IEnumerable] -and $act.Count -eq 1){$act=$act[0]}
            $pathClean=$path.TrimStart('.')
            if($patchMap.ContainsKey($pathClean)){
                if(Join-IfArray($act) -ne $patchMap[$pathClean]){throw "patch fail $pathClean"}
            }
            else{
                if(Join-IfArray($exp) -ne Join-IfArray($act)){throw "unpatched field Δ $pathClean"}
            }
        }

        $j1  =[IO.Path]::GetTempFileName()
        $vip =[IO.Path]::GetTempPath()+([guid]::NewGuid()).Guid+".vipb"
        $j2  =[IO.Path]::GetTempFileName()
        $patch=[IO.Path]::GetTempFileName()

        try{
            & ./publish/linux-x64/VipbJsonTool vipb2json $SourceVipb $j1
            $orig = Get-Content $j1 -Raw | ConvertFrom-Json

            # create patch map and enumerate aliases
            $paths = Get-LeafPaths $orig
            Write-Host ""
            Write-Host "********** BEGIN: Discovered JSON Aliases (field paths) **********"
            $paths | Sort-Object | ForEach-Object { Write-Host $_ }
            Write-Host "********** END: Discovered JSON Aliases **********"
            Write-Host ""

            $patchMap=@{}
            foreach($p in $paths){
                $val = "__PATCHED__"
                $origVal=Join-IfArray((Invoke-Expression "`$orig.$($p -replace '\.','`.`')"))
                if($origVal -is [bool]) {$val = -not $origVal}
                elseif($origVal -is [double] -or $origVal -is [int]){$val=[double]$origVal+1}
                $patchMap[$p]=$val
            }

            # write YAML
            $yaml=@("schema_version: 1","patch:")
            foreach($k in $patchMap.Keys){
                $v=$patchMap[$k]
                if($v -is [bool]){ $yaml+="  $k: $($v.ToString().ToLower())"}
                elseif($v -is [string]){ $yaml+="  $k: '$($v -replace '''','''''')'"}
                else{ $yaml+="  $k: $v" }
            }
            Set-Content $patch $yaml -Encoding UTF8

            & ./publish/linux-x64/VipbJsonTool patch2vipb $j1 $vip $patch
            & ./publish/linux-x64/VipbJsonTool vipb2json $vip $j2
            $round = Get-Content $j2 -Raw | ConvertFrom-Json

            Compare-AfterPatch $orig $round $patchMap
        }
        finally{Remove-Item $j1,$j2,$vip,$patch -ea SilentlyContinue}
    }
}
