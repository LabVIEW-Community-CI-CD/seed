param()

Describe "VIPB round‑trip fidelity – smoke" {

    It "round‑trips with no semantic loss" {

        #################################
        # helper – tolerant comparer
        #################################
        function Compare‑Semantic($exp,$act,$path='') {
            # treat '#whitespace' anywhere as a blob of joined text
            if(($exp -is [pscustomobject] -or $exp -is [hashtable]) -and
               ($act -is [pscustomobject] -or $act -is [hashtable])) {

                $keys = ($exp.psobject.Properties.Name + $act.psobject.Properties.Name |
                         Select‑Object -Unique)
                foreach($k in $keys) {
                    $e = $exp.$k; $a = $act.$k
                    if($k -eq '#whitespace') {
                        if($e -isnot [string]){$e=@($e) -join ''}
                        if($a -isnot [string]){$a=@($a) -join ''}
                        if($e -ne $a){throw "Δ at ${path}.#whitespace"}
                    } else { Compare‑Semantic $e $a "$path.$k" }
                }; return
            }

            if($exp -is [System.Collections.IEnumerable] -and $exp -isnot [string] -and
               $act -is [System.Collections.IEnumerable] -and $act -isnot [string]) {
                if($exp.Count -ne $act.Count){throw "Δ len $path"}
                for($i=0;$i -lt $exp.Count;$i++){Compare‑Semantic $exp[$i] $act[$i] "$path[$i]"}
                return
            }

            # scalar/array single‑element tolerance
            if($exp -isnot [string] -and $exp -is [System.Collections.IEnumerable] -and $exp.Count -eq 1){$exp=$exp[0]}
            if($act -isnot [string] -and $act -is [System.Collections.IEnumerable] -and $act.Count -eq 1){$act=$act[0]}

            # join whitespace arrays
            if($exp -is [System.Collections.IEnumerable] -and $exp -isnot [string]){$exp=@($exp) -join ''}
            if($act -is [System.Collections.IEnumerable] -and $act -isnot [string]){$act=@($act) -join ''}

            if($exp -ne $act){throw "Δ at $path"}
        }

        #############################
        # temp files
        #############################
        $vipb       = "tests/Samples/NI Icon editor.vipb"
        $json1      = [IO.Path]::GetTempFileName()
        $vipbRound  = [IO.Path]::GetTempPath() + ([guid]::NewGuid().Guid) + ".vipb"
        $json2      = [IO.Path]::GetTempFileName()

        try {
            & ./publish/linux-x64/VipbJsonTool vipb2json $vipb $json1
            $LASTEXITCODE | Should -Be 0
            & ./publish/linux-x64/VipbJsonTool json2vipb $json1 $vipbRound
            & ./publish/linux-x64/VipbJsonTool vipb2json $vipbRound $json2

            $orig  = Get‑Content $json1 -Raw | ConvertFrom‑Json
            $round = Get‑Content $json2 -Raw | ConvertFrom‑Json
            Compare‑Semantic $orig $round
        }
        finally { Remove‑Item $json1,$json2,$vipbRound -ea SilentlyContinue }
    }
}
