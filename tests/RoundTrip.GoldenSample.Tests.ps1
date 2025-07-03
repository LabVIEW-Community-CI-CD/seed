# ──────────────────────────────────────────────────────────────────────────────
# RoundTrip.GoldenSample.Tests.ps1  ▶  self‑patching alias discovery
# ──────────────────────────────────────────────────────────────────────────────
param()

#####  helper functions ########################################################
function ConvertTo-SnakeCase {
    param([string]$Name)
    $Name = $Name -replace '\.', '_'                    # dots → underscores
    $Name = $Name -replace '([0-9a-z])([A-Z])', '$1_$2' # aB → a_B
    $Name.ToLower()
}

function Flatten-Object {
    param($Obj)
    $out = [ordered]@{}
    function Recurse ($o,$p='') {
        if ($o -is [pscustomobject]) {
            foreach ($prop in $o.psobject.Properties) {
                Recurse $prop.Value "$p$($prop.Name)."
            }
        }
        elseif ($o -is [System.Collections.IEnumerable] -and $o -isnot [string]) {
            return      # skip arrays for YAML master file
        }
        else {
            if ($p) {
                $key              = ConvertTo-SnakeCase $p.TrimEnd('.')
                $out[$key]        = if ($null -eq $o) { '' } else { $o }
            }
        }
    }
    Recurse $Obj
    return $out
}

#####  paths ###################################################################
$vipbFile  = "tests/Samples/seed.vipb"
$lvprojFile= "tests/Samples/seed.lvproj"
$release   = "release"
$vipbYaml  = Join-Path $release "seed-vipb.yaml"
$lvprojYaml= Join-Path $release "seed-lvproj.yaml"

#####  pester ##################################################################
Describe "Golden‑sample alias discovery" {

    BeforeAll {
        if (Test-Path $release) { Remove-Item $release -Recurse -Force }
        New-Item $release -ItemType Directory -Force | Out-Null
    }

    It "extracts aliases & values from seed.vipb" {
        try {
            $vipbJson = Join-Path $release "seed.vipb.json"
            & dotnet run --project src/VipbJsonTool/VipbJsonTool.csproj `
                         --no-build -- buildspec2json $vipbFile $vipbJson
            if ($LASTEXITCODE) { throw "conversion failed (exit $LASTEXITCODE)" }

            $jObj      = Get-Content $vipbJson -Raw | ConvertFrom-Json
            $flattened = Flatten-Object $jObj

            $yamlLines = foreach ($alias in $flattened.Keys) {
                $v = $flattened[$alias]
                if ([string]::IsNullOrWhiteSpace("$v")) { "${alias}:" }
                else                                    { "${alias}: $v" }
            }
            Set-Content $vipbYaml $yamlLines -Encoding UTF8
        }
        catch {
            Write-Host "Error extracting patchable fields from ${vipbFile}: $($_.Exception.Message)"
            Write-Host "StackTrace:`n$($_.Exception.StackTrace)"
            throw
        }

        (Test-Path $vipbYaml)                | Should -BeTrue
        (Get-Content $vipbYaml).Count        | Should -BeGreaterThan 0
    }

    It "extracts aliases & values from seed.lvproj" {
        try {
            $lvprojJson = Join-Path $release "seed.lvproj.json"
            & dotnet run --project src/VipbJsonTool/VipbJsonTool.csproj `
                         --no-build -- buildspec2json $lvprojFile $lvprojJson
            if ($LASTEXITCODE) { throw "conversion failed (exit $LASTEXITCODE)" }

            $jObj      = Get-Content $lvprojJson -Raw | ConvertFrom-Json
            $flattened = Flatten-Object $jObj

            $yamlLines = foreach ($alias in $flattened.Keys) {
                $v = $flattened[$alias]
                if ([string]::IsNullOrWhiteSpace("$v")) { "${alias}:" }
                else                                    { "${alias}: $v" }
            }
            Set-Content $lvprojYaml $yamlLines -Encoding UTF8
        }
        catch {
            Write-Host "Error extracting patchable fields from ${lvprojFile}: $($_.Exception.Message)"
            Write-Host "StackTrace:`n$($_.Exception.StackTrace)"
            throw
        }

        (Test-Path $lvprojYaml)              | Should -BeTrue
        (Get-Content $lvprojYaml).Count      | Should -BeGreaterThan 0
    }
}
