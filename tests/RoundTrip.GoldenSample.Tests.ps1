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
            return      # skip arrays for master file
        }
        else {
            if ($p) {
                $key       = ConvertTo-SnakeCase $p.TrimEnd('.')
                $out[$key] = if ($null -eq $o) { '' } else { $o }
            }
        }
    }
    Recurse $Obj
    return $out
}

#####  pester ##################################################################
Describe "Golden‑sample alias discovery" {

    # -------------- shared variables (script‑scope) --------------------------
    BeforeAll {
        # file locations
        $script:vipbFile   = "tests/Samples/seed.vipb"
        $script:lvprojFile = "tests/Samples/seed.lvproj"

        # release folder + outputs
        $script:release     = "release"
        $script:vipbYaml    = Join-Path $script:release "seed-vipb.yaml"
        $script:lvprojYaml  = Join-Path $script:release "seed-lvproj.yaml"

        if (Test-Path $script:release) { Remove-Item $script:release -Recurse -Force }
        New-Item $script:release -ItemType Directory -Force | Out-Null
    }

    It "extracts aliases & values from seed.vipb" {
        try {
            $vipbJson = Join-Path $script:release "seed.vipb.json"
            & dotnet run --project src/VipbJsonTool/VipbJsonTool.csproj `
                         -c Release -- buildspec2json `
                         $script:vipbFile $vipbJson
            if ($LASTEXITCODE) { throw "conversion failed (exit $LASTEXITCODE)" }

            $jObj      = Get-Content $vipbJson -Raw | ConvertFrom-Json
            $flattened = Flatten-Object $jObj

            $yamlLines = foreach ($alias in $flattened.Keys) {
                $v = $flattened[$alias]
                if ([string]::IsNullOrWhiteSpace("$v")) { "${alias}:" }
                else                                    { "${alias}: $v" }
            }
            Set-Content $script:vipbYaml $yamlLines -Encoding UTF8
        }
        catch {
            Write-Host "Error extracting patchable fields from ${script:vipbFile}: $($_.Exception.Message)"
            Write-Host "StackTrace:`n$($_.Exception.StackTrace)"
            throw
        }

        (Test-Path $script:vipbYaml)           | Should -BeTrue
        (Get-Content $script:vipbYaml).Count   | Should -BeGreaterThan 0
    }

    It "extracts aliases & values from seed.lvproj" {
        try {
            $lvprojJson = Join-Path $script:release "seed.lvproj.json"
            & dotnet run --project src/VipbJsonTool/VipbJsonTool.csproj `
                         -c Release -- buildspec2json `
                         $script:lvprojFile $lvprojJson
            if ($LASTEXITCODE) { throw "conversion failed (exit $LASTEXITCODE)" }

            $jObj      = Get-Content $lvprojJson -Raw | ConvertFrom-Json
            $flattened = Flatten-Object $jObj

            $yamlLines = foreach ($alias in $flattened.Keys) {
                $v = $flattened[$alias]
                if ([string]::IsNullOrWhiteSpace("$v")) { "${alias}:" }
                else                                    { "${alias}: $v" }
            }
            Set-Content $script:lvprojYaml $yamlLines -Encoding UTF8
        }
        catch {
            Write-Host "Error extracting patchable fields from ${script:lvprojFile}: $($_.Exception.Message)"
            Write-Host "StackTrace:`n$($_.Exception.StackTrace)"
            throw
        }

        (Test-Path $script:lvprojYaml)         | Should -BeTrue
        (Get-Content $script:lvprojYaml).Count | Should -BeGreaterThan 0
    }
}
