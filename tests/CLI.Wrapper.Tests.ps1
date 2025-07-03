# Tests for CLI wrapper scripts (vipb2json, json2vipb, lvproj2json, etc.)
# Ensure that help text is shown, invalid flags are handled, and conversions work.

# Determine repository root and key directories
$RepoRoot = Split-Path $PSScriptRoot -Parent
$BinDir   = Join-Path $RepoRoot "bin"
$ToolsDir = Join-Path $RepoRoot "tools"

Describe "CLI wrapper scripts basic behavior" {
    $cliCommands = @("vipb2json", "json2vipb", "lvproj2json", "json2lvproj", "buildspec2json", "json2buildspec")
    foreach ($cmd in $cliCommands) {
        It "displays help for '$cmd' when --help is given" {
            $output = & (Join-Path $BinDir $cmd) --help 2>&1
            $LASTEXITCODE | Should -Be 0
            $output | Should -Match "\bUsage\b"
        }
        It "exits with error on unknown flag for '$cmd'" {
            $output = & (Join-Path $BinDir $cmd) --unknownFlag 2>&1
            $LASTEXITCODE | Should -Not -Be 0
            $output | Should -Match "Unknown option"
        }
    }

    It "requires --input and --output parameters (shows usage if missing)" {
        $output = & (Join-Path $BinDir "vipb2json") 2>&1   # no arguments
        $LASTEXITCODE | Should -Not -Be 0
        $output | Should -Match "\bUsage\b"
    }
}

Describe "End-to-end conversion via CLI wrappers" {
    # Use Pester's TestDrive for temporary files
    It "converts a VIPB file to JSON via vipb2json" {
        $vipbSample = Join-Path $RepoRoot "tests/Samples/seed.vipb"
        $outJson    = Join-Path $TestDrive "seed.vipb.json"
        & (Join-Path $BinDir "vipb2json") --input $vipbSample --output $outJson
        $LASTEXITCODE | Should -Be 0
        (Test-Path $outJson) | Should -BeTrue
        # The output JSON should contain the root element "Package"
        (Get-Content $outJson -Raw) | Should -Match '"Package"'
    }

    It "converts a JSON file back to VIPB via json2vipb" {
        $vipbSample = Join-Path $RepoRoot "tests/Samples/seed.vipb"
        $jsonFile   = Join-Path $TestDrive "roundtrip.json"
        $newVipb    = Join-Path $TestDrive "roundtrip.vipb"
        # First, produce JSON from the sample VIPB
        & (Join-Path $BinDir "vipb2json") --input $vipbSample --output $jsonFile
        $LASTEXITCODE | Should -Be 0
        # Now convert the JSON back to VIPB
        & (Join-Path $BinDir "json2vipb") --input $jsonFile --output $newVipb
        $LASTEXITCODE | Should -Be 0
        (Test-Path $newVipb) | Should -BeTrue
        # The resulting file should be an XML with root element <Package>
        $xmlContent = Get-Content $newVipb -Raw
        $xmlContent | Should -Match "<Package"
    }

    It "converts a LVPROJ file to JSON via lvproj2json and back via json2lvproj" {
        $lvprojSample = Join-Path $RepoRoot "tests/Samples/seed.lvproj"
        $jsonFile     = Join-Path $TestDrive "project.json"
        $newLvproj    = Join-Path $TestDrive "project.lvproj"
        & (Join-Path $BinDir "lvproj2json") --input $lvprojSample --output $jsonFile
        $LASTEXITCODE | Should -Be 0
        & (Join-Path $BinDir "json2lvproj") --input $jsonFile --output $newLvproj
        $LASTEXITCODE | Should -Be 0
        (Test-Path $newLvproj) | Should -BeTrue
        # The resulting .lvproj should be an XML with root element <Project>
        $projContent = Get-Content $newLvproj -Raw
        $projContent | Should -Match "<Project"
    }
}

Describe "Auxiliary tools and coverage" {
    It "enumerates JSON paths from a VIPB JSON (using Enumerate-VipbPaths.ps1)" {
        # Convert VIPB to JSON, then enumerate all JSON dot-paths
        $vipbSample = Join-Path $RepoRoot "tests/Samples/seed.vipb"
        $jsonFile   = Join-Path $TestDrive "sample.json"
        & (Join-Path $BinDir "vipb2json") --input $vipbSample --output $jsonFile
        $LASTEXITCODE | Should -Be 0
        # Use the PowerShell tool to list all JSON field paths
        $paths = & (Join-Path $ToolsDir "Enumerate-VipbPaths.ps1") -JsonPath $jsonFile
        $paths.Count    | Should -BeGreaterThan 0
        $paths          | Should -Contain "Package.PackageName"
    }
}