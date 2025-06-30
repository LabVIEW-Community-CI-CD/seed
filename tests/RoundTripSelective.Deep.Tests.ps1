function Compare-DeepJson {
    param (
        [Parameter(Mandatory)][object]$Original,
        [Parameter(Mandatory)][object]$Roundtrip,
        [Parameter()][string]$Path = "",
        [Parameter()][hashtable]$PatchedFields
    )
    # If this is a leaf node
    if ($Original -isnot [System.Collections.IDictionary] -and $Original -isnot [System.Collections.IEnumerable]) {
        if ($PatchedFields.ContainsKey($Path)) {
            $Roundtrip | Should -Be $PatchedFields[$Path]
        } else {
            $Roundtrip | Should -Be $Original
        }
        return
    }
    # If this is a dictionary/object
    if ($Original -is [System.Collections.IDictionary]) {
        foreach ($key in $Original.Keys) {
            $newPath = if ($Path) { "$Path.$key" } else { $key }
            Compare-DeepJson $Original[$key] $Roundtrip[$key] $newPath $PatchedFields
        }
    }
    # If this is a list/array
    elseif ($Original -is [System.Collections.IEnumerable] -and
           $Original -isnot [string]) {
        $origList = @($Original)
        $rtList = @($Roundtrip)
        $origList.Count | Should -Be $rtList.Count
        for ($i=0; $i -lt $origList.Count; $i++) {
            $newPath = "$Path[$i]"
            Compare-DeepJson $origList[$i] $rtList[$i] $newPath $PatchedFields
        }
    }
}

param (
    [string]$Json1 = "tmp.json",
    [string]$Json2 = "tmp2.json",
    [hashtable]$PatchedFields = @{ "Library_General_Settings.Company_Name" = "SMOKETEST" }
)

Describe "VIPB deep round-trip patch test" {
    It "only changes allowed fields, and all other fields are unchanged" {
        $orig = Get-Content $Json1 -Raw | ConvertFrom-Json
        $rt   = Get-Content $Json2 -Raw | ConvertFrom-Json

        Compare-DeepJson $orig $rt "" $PatchedFields
    }
}
