param (
    [string]$Json1 = "tmp.json",
    [string]$Json2 = "tmp2.json",
    # hashtable <JSON‑path> = expected value
    [hashtable]$PatchedFields = @{
        "Library_General_Settings.Company_Name" = "SMOKETEST"
    }
)

function Compare-DeepJson {
    param (
        [object]$Original,
        [object]$Roundtrip,
        [string]$Path = "",
        [hashtable]$PatchedFields
    )

    # leaf
    if ($Original -isnot [System.Collections.IDictionary] -and
        $Original -isnot [System.Collections.IEnumerable]) {

        if ($PatchedFields.ContainsKey($Path)) {
            $Roundtrip | Should -Be $PatchedFields[$Path]
        } else {
            $Roundtrip | Should -Be $Original
        }
        return
    }

    # object
    if ($Original -is [System.Collections.IDictionary]) {
        foreach ($key in $Original.Keys) {
            $newPath = if ($Path) { "$Path.$key" } else { $key }
            Compare-DeepJson $Original[$key] $Roundtrip[$key] $newPath $PatchedFields
        }
        return
    }

    # array
    if ($Original -is [System.Collections.IEnumerable] -and $Original -isnot [string]) {
        $origList = @($Original)
        $rtList   = @($Roundtrip)
        $origList.Count | Should -Be $rtList.Count
        for ($i = 0; $i -lt $origList.Count; $i++) {
            $newPath = "$Path[$i]"
            Compare-DeepJson $origList[$i] $rtList[$i] $newPath $PatchedFields
        }
    }
}

Describe "VIPB deep round‑trip patch test" {
    It "only changes allowed fields; all others unchanged" {
        $orig = Get-Content $Json1 -Raw | ConvertFrom-Json
        $rt   = Get-Content $Json2 -Raw | ConvertFrom-Json

        Compare-DeepJson $orig $rt "" $PatchedFields
    }
}
