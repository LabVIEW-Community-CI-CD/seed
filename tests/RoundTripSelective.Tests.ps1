param (
    [string]$OriginalVipb = "tests/Samples/NI Icon editor.vipb",
    [string]$PatchedVipb  = "tmp.vipb",
    [string]$Json1        = "tmp.json",
    [string]$Json2        = "tmp2.json",
    [string]$PatchedField = "Company_Name",
    [string]$ExpectedValue = "SMOKETEST"
)

Describe "VIPB selective round‑trip" {
    It "patches only the requested field" {
        # Convert both JSON files to objects
        $a = Get-Content $Json1 -Raw | ConvertFrom-Json
        $b = Get-Content $Json2 -Raw | ConvertFrom-Json

        # Compare all fields except the one we patched
        $a.PSObject.Properties | Where-Object { $_.Name -ne $PatchedField } | ForEach-Object {
            $name = $_.Name
            $valueA = $_.Value
            $valueB = $b."$name"
            # For deep objects, compare as string to ignore whitespace
            $vA = ($valueA | ConvertTo-Json -Compress)
            $vB = ($valueB | ConvertTo-Json -Compress)
            $vA | Should -Be $vB
        }
    }
    It "correctly patches the intended field" {
        $b = Get-Content $Json2 -Raw | ConvertFrom-Json
        $b.Company_Name | Should -Be $ExpectedValue
    }
}
