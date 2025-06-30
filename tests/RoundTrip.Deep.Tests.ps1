param (
    # original VIPB sample
    [string]$SourceVipb = "tests/Samples/NI Icon editor.vipb",

    # alias map file
    [string]$AliasMap   = ".vipb-alias-map.yml",

    # patch to apply during test
    [string]$PatchFile  = "ci-patch.yml"
)

$Json1 = "tmp.json"
$Vipb2 = "tmp.vipb"
$Json2 = "tmp2.json"

Describe "CI round‑trip & deep‑patch test" {

    BeforeAll {
        # ----- generate tmp.json -----
        dotnet run --project src/VipbJsonTool -- vipb2json $SourceVipb $Json1

        # ----- patch & rebuild -----
        dotnet run --project src/VipbJsonTool `
            -- patch2vipb $Json1 $Vipb2 $PatchFile '' ''

        # ----- convert back to json -----
        dotnet run --project src/VipbJsonTool -- vipb2json $Vipb2 $Json2
    }

    BeforeAll {
        # load patched‑field expectations from YAML patch
        $PatchedFields = @{}
        if (Test-Path $PatchFile) {
            $pairs = ((Get-Content $PatchFile -Raw) | ConvertFrom-Yaml)
            $pairs.PSObject.Properties | ForEach-Object {
                $PatchedFields[$_.Name] = $_.Value
            }
        }

        function Is-Obj ($o) { $o -isnot [string] -and $o -isnot [System.Array] -and $o.PSObject.Properties.Count }
        function Compare-Deep {
            param($A,$B,$Path="")
            if (Is-Obj $A) {
                foreach ($k in $A.PSObject.Properties.Name) {
                    Compare-Deep $A.$k $B.$k ($Path ? "$Path.$k" : $k)
                }
                return
            }
            if ($A -is [System.Array]) {
                $A.Count | Should -Be $B.Count
                for ($i=0;$i -lt $A.Count;$i++){
                    Compare-Deep $A[$i] $B[$i] "$Path[$i]"
                }
                return
            }
            if ($PatchedFields.ContainsKey($Path)) {
                $B | Should -Be $PatchedFields[$Path]
            } else {
                $B | Should -Be $A
            }
        }
    }

    It "only patched fields differ; everything else identical" {
        $orig = Get-Content $Json1 -Raw | ConvertFrom-Json
        $rt   = Get-Content $Json2 -Raw | ConvertFrom-Json
        Compare-Deep $orig $rt
    }
}
