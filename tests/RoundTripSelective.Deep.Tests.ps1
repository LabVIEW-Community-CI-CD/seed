param (
    [string]$Json1 = "tmp.json",
    [string]$Json2 = "tmp2.json",
    [hashtable]$PatchedFields = @{ "Library_General_Settings.Company_Name" = "SMOKETEST" }
)

Describe "VIPB deep round‑trip patch test" {

    BeforeAll {
        function Is-JsonObject { param($o) return ($o -isnot [string] -and $o -isnot [System.Array] -and $o.PSObject.Properties.Count) }

        function Compare-DeepJson {
            param (
                [object]$Original,
                [object]$Roundtrip,
                [string]$Path = "",
                [hashtable]$PatchedFields
            )

            if (Is-JsonObject $Original) {
                foreach ($p in $Original.PSObject.Properties.Name) {
                    $newPath = if ($Path) { "$Path.$p" } else { $p }
                    Compare-DeepJson $Original.$p $Roundtrip.$p $newPath $PatchedFields
                }
                return
            }

            if ($Original -is [System.Array]) {
                $Original.Count | Should -Be $Roundtrip.Count
                for ($i=0; $i -lt $Original.Count; $i++) {
                    Compare-DeepJson $Original[$i] $Roundtrip[$i] "$Path[$i]" $PatchedFields
                }
                return
            }

            # leaf
            if ($PatchedFields.ContainsKey($Path)) {
                $Roundtrip | Should -Be $PatchedFields[$Path]
            } else {
                $Roundtrip | Should -Be $Original
            }
        }
    }

    It "only changes allowed fields; all others unchanged" {
        $orig = Get-Content $Json1 -Raw | ConvertFrom-Json
        $rt   = Get-Content $Json2 -Raw | ConvertFrom-Json
        Compare-DeepJson $orig $rt "" $PatchedFields
    }
}
