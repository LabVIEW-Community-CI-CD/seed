param(
    [string]$Vipb = 'tests/Samples/NI Icon editor.vipb',
    [string]$Patch = 'ci-patch-full.yml'
)

$Tmp1 = 'tmp_full.json'
$TmpVipb = 'tmp_full.vipb'
$Tmp2 = 'tmp_full2.json'

# 1. VIPB → JSON
dotnet run --project src/VipbJsonTool -- vipb2json $Vipb $Tmp1

# 2. Apply full patch & rebuild
dotnet run --project src/VipbJsonTool -- patch2vipb $Tmp1 $TmpVipb $Patch '' ''

# 3. VIPB → JSON again
dotnet run --project src/VipbJsonTool -- vipb2json $TmpVipb $Tmp2

# 4. Load YAML patch as allowed‑diff map
Import-Module powershell-yaml
$allowed = (Get-Content $Patch -Raw | ConvertFrom-Yaml).patch

# 5. Deep compare
function Compare-Deep($A,$B,$Path='') {
    if ($allowed.ContainsKey($Path)) { return }               # ignore patched path
    if ($A -is [System.Collections.IDictionary]) {
        $A.Keys + $B.Keys | Sort-Object -Unique | ForEach-Object {
            Compare-Deep $A[$_] $B[$_] ($Path ? "$Path.$_" : $_)
        }
    }
    elseif ($A -is [System.Collections.IEnumerable] -and $A -isnot [string]) {
        for ($i=0; $i -lt [Math]::Max($A.Count,$B.Count); $i++) {
            Compare-Deep $A[$i] $B[$i] "$Path[$i]"
        }
    }
    else {
        $A | Should -Be $B -Because "Path $Path changed unexpectedly"
    }
}

Describe 'VIPB full‐coverage round‑trip' {
    It 'only differences listed in patch' {
        $orig = Get-Content $Tmp1 -Raw | ConvertFrom-Json
        $rt   = Get-Content $Tmp2 -Raw | ConvertFrom-Json
        Compare-Deep $orig $rt
    }
}
