param(
    [Parameter(Mandatory=$true)]
    [string]$SourceFile
)

Describe "Golden Sample Full Coverage — $SourceFile" {

    It "Enumerates fields, generates dynamic patch, validates round-trip" {

        function Join-IfArray($v){if($v -is [System.Collections.IEnumerable] -and $v -isnot [string]){@($v)-join''}else{$v}}

        function Get-LeafPaths([object]$obj,[string]$prefix=''){
            $list=New-Object System.Collections.Generic.List[string]
            if($obj -is [pscustomobject]){
                foreach($n in $obj.PSObject.Properties.Name){
                    $list.AddRange((Get-LeafPaths $obj.$n, ($prefix?"$prefix.$n":$n)))
                }
            }elseif($obj -is [System.Collections.IEnumerable]-and$obj -isnot[string]){
                $i=0;foreach($v in $obj){$list.AddRange((Get-LeafPaths $v,"$prefix[$i]"));$i++}
            }else{if($prefix){$list.Add($prefix)}}
            return$list
        }

        function Compare-AfterPatch($exp,$act,$patchMap,$path=''){
            if(($exp -is [pscustomobject]-or$exp -is[hashtable])-and($act -is[pscustomobject]-or$act -is[hashtable])){
                $keys=($exp.PSObject.Properties.Name+$act.PSObject.Properties.Name|Select-Object-Unique)
                foreach($k in$keys){
                    $e=$exp.$k;$a=$act.$k
                    if($k-eq'#whitespace'){
                        if(Join-IfArray($e)-ne Join-IfArray($a)){
                            $full="$path.$k".Trim('.')
                            if($patchMap.ContainsKey($full)){
                                if(Join-IfArray($a)-ne$patchMap[$full]){throw"patched field$full wrong"}
                            }else{throw"unpatched#whitespace changed at$full"}
                        }
                    }else{Compare-AfterPatch$e$a$patchMap"$path.$k"}
                };return
            }
            if($exp -is[System.Collections.IEnumerable]-and$exp-isnot[string]-and
                $act-is[System.Collections.IEnumerable]-and$act-isnot[string]){
                if($exp.Count-ne$act.Count){throw"array lenΔ$path"}
                for($i=0;$i-lt$exp.Count;$i++){Compare-AfterPatch$exp[$i]$act[$i]$patchMap"$path[$i]"}
                return
            }
            $exp=Join-IfArray($exp);$act=Join-IfArray($act)
            $pathClean=$path.TrimStart('.')
            if($patchMap.ContainsKey($pathClean)){
                if($act-ne$patchMap[$pathClean]){throw"patch fail$pathClean"}
            }elseif($exp-ne$act){throw"unpatched fieldΔ$pathClean"}
        }

        $jsonOrig=[IO.Path]::GetTempFileName()
        $patchedFile=[IO.Path]::GetTempPath()+([guid]::NewGuid()).Guid+[IO.Path]::GetExtension($SourceFile)
        $jsonPatched=[IO.Path]::GetTempFileName()
        $patchYaml=[IO.Path]::GetTempFileName()

        try{
            & ./publish/linux-x64/VipbJsonTool vipb2json $SourceFile $jsonOrig
            $orig=Get-Content$jsonOrig-Raw|ConvertFrom-Json

            $paths=Get-LeafPaths$orig
            Write-Host"`n==== BEGIN: Aliases (Paths) in $SourceFile ===="
            $paths|Sort-Object|ForEach-Object{Write-Host$_}
            Write-Host"==== END: Aliases ====`n"

            $patchMap=@{}
            foreach($p in$paths){
                $origVal=Join-IfArray(Invoke-Expression"`$orig.$($p-replace'\.','`.`')")
                $val="__PATCHED__"
                if($origVal-is[bool]){$val=-not$origVal}
                elseif($origVal-is[double]-or$origVal-is[int]){$val=[double]$origVal+1}
                $patchMap[$p]=$val
            }

            $yaml=@("schema_version: 1","patch:")
            foreach($k in$patchMap.Keys){
                $v=$patchMap[$k]
                if($v-is[bool]){$yaml+="  $k: $($v.ToString().ToLower())"}
                elseif($v-is[string]){$yaml+="  $k: '$($v-replace'''','''''')'"}
                else{$yaml+="  $k: $v"}
            }
            Set-Content$patchYaml$yaml-Encoding UTF8

            & ./publish/linux-x64/VipbJsonTool patch2vipb $jsonOrig $patchedFile $patchYaml
            & ./publish/linux-x64/VipbJsonTool vipb2json $patchedFile $jsonPatched
            $patched=Get-Content$jsonPatched-Raw|ConvertFrom-Json

            Compare-AfterPatch$orig$patched$patchMap
        }
        finally{Remove-Item$jsonOrig,$jsonPatched,$patchedFile,$patchYaml -ea 0}
    }
}
