# tests/RoundTrip.GoldenSample.Tests.ps1

# Function to convert CamelCase/PascalCase or dot notation into snake_case for alias keys
function ConvertTo-SnakeCase {
    param([string]$Name)
    # Replace dot separators with underscore, then insert underscore between lowercase-to-uppercase transitions, finally lowercase everything
    $Name = $Name -replace '\.', '_'
    $Name = $Name -replace '([0-9a-z])([A-Z])', '$1_$2'
    return $Name.ToLower()
}

# Recursive function to flatten all properties of an object into alias-value pairs
function Flatten-Object {
    param($Obj)
    $result = [ordered]@{}
    function Flatten-Internal($obj, $prefix="") {
        # Skip arrays or collections entirely (not considered patchable fields for YAML output)
        if ($obj -is [System.Collections.IEnumerable] -and -not ($obj -is [string])) {
            return
        }
        if ($obj -is [PSCustomObject]) {
            # Iterate through each property of the object
            foreach ($prop in $obj.PSObject.Properties) {
                Flatten-Internal -obj $prop.Value -prefix ($prefix + $prop.Name + ".")
            }
        }
        else {
            # Base case: $obj is a primitive value (string, number, bool, or null)
            $key = $prefix.TrimEnd(".")  # remove trailing dot from accumulated prefix
            if ([string]::IsNullOrEmpty($key)) { return }
            # Convert to alias (snake_case) and assign value (use empty string for null)
            $result[(ConvertTo-SnakeCase $key)] = if ($obj -eq $null) { "" } else { $obj }
        }
    }
    Flatten-Internal -obj $Obj -prefix ""
    return $result
}

# Define paths for canonical seed input files and output YAMLs
$vipbFile    = "tests/Samples/seed.vipb"
$lvprojFile  = "tests/Samples/seed.lvproj"
$releaseDir  = "release"
$vipbYamlOut = Join-Path $releaseDir "seed-vipb.yaml"
$lvprojYamlOut = Join-Path $releaseDir "seed-lvproj.yaml"

Describe "RoundTrip Golden Sample YAML Extraction" {
    BeforeAll {
        # Ensure a clean output directory for release artifacts
        if (Test-Path $releaseDir) {
            Remove-Item -Recurse -Force $releaseDir
        }
        New-Item -Type Directory -Path $releaseDir -Force | Out-Null
    }

    It "should generate seed-vipb.yaml from the seed.vipb file" {
        try {
            # Convert the VIPB file to JSON using the CLI tool
            $vipbJsonPath = Join-Path $releaseDir "seed.vipb.json"
            & dotnet run --project src/VipbJsonTool/VipbJsonTool.csproj --no-build -- buildspec2json $vipbFile $vipbJsonPath
            if ($LastExitCode -ne 0) {
                throw "CLI conversion vipb->json failed with exit code $LastExitCode"
            }
            # Load and parse the JSON output
            $vipbJson = Get-Content -Path $vipbJsonPath -Raw | ConvertFrom-Json
            # Flatten all patchable fields (aliases) and their values into a hashtable
            $flatVipb = Flatten-Object -Obj $vipbJson
            # Build YAML content lines from the flattened key-value pairs
            $yamlLines = foreach ($alias in $flatVipb.Keys) {
                $val = $flatVipb[$alias]
                if ($val -eq $null -or ([string]::IsNullOrWhiteSpace([string]$val))) {
                    # Include key with empty value
                    "$alias:"
                }
                else {
                    "$alias: $val"
                }
            }
            # Write the YAML content to the output file
            Set-Content -Path $vipbYamlOut -Value $yamlLines -Encoding UTF8
        }
        catch {
            # On failure, output detailed debug information (file path, error message, and stack trace)
            Write-Host "Error extracting patchable fields from $vipbFile: $($_.Exception.Message)"
            if ($_.InvocationInfo) {
                Write-Host "Failure at $($_.InvocationInfo.ScriptName): line $($_.InvocationInfo.ScriptLineNumber)"
            }
            Write-Host "Stack Trace:`n$($_.Exception.StackTrace)"
            throw  # Rethrow to mark this test as failed
        }
        # Validate that the YAML file was created and is not empty
        (Test-Path $vipbYamlOut) | Should -BeTrue -Because "seed-vipb.yaml was not generated."
        (Get-Content $vipbYamlOut | Measure-Object -Line).Lines | Should -BeGreaterThan 0 -Because "seed-vipb.yaml is empty."
    }

    It "should generate seed-lvproj.yaml from the seed.lvproj file" {
        try {
            # Convert the LVPROJ file to JSON using the CLI tool
            $lvprojJsonPath = Join-Path $releaseDir "seed.lvproj.json"
            & dotnet run --project src/VipbJsonTool/VipbJsonTool.csproj --no-build -- buildspec2json $lvprojFile $lvprojJsonPath
            if ($LastExitCode -ne 0) {
                throw "CLI conversion lvproj->json failed with exit code $LastExitCode"
            }
            # Load and parse the JSON output
            $lvprojJson = Get-Content -Path $lvprojJsonPath -Raw | ConvertFrom-Json
            # Flatten all patchable fields (aliases) and their values
            $flatLvproj = Flatten-Object -Obj $lvprojJson
            # Build YAML content lines
            $yamlLines2 = foreach ($alias in $flatLvproj.Keys) {
                $val = $flatLvproj[$alias]
                if ($val -eq $null -or ([string]::IsNullOrWhiteSpace([string]$val))) {
                    "$alias:"
                }
                else {
                    "$alias: $val"
                }
            }
            Set-Content -Path $lvprojYamlOut -Value $yamlLines2 -Encoding UTF8
        }
        catch {
            # Debug output on failure for LVPROJ extraction
            Write-Host "Error extracting patchable fields from $lvprojFile: $($_.Exception.Message)"
            if ($_.InvocationInfo) {
                Write-Host "Failure at $($_.InvocationInfo.ScriptName): line $($_.InvocationInfo.ScriptLineNumber)"
            }
            Write-Host "Stack Trace:`n$($_.Exception.StackTrace)"
            throw
        }
        # Validate YAML file creation and content
        (Test-Path $lvprojYamlOut) | Should -BeTrue -Because "seed-lvproj.yaml was not generated."
        (Get-Content $lvprojYamlOut | Measure-Object -Line).Lines | Should -BeGreaterThan 0 -Because "seed-lvproj.yaml is empty."
    }
}
