$RepoRoot = Split-Path $PSScriptRoot -Parent

Describe "CLI wrapper scripts basic behavior" {
    $cliCommands = @("vipb2json", "json2vipb", "lvproj2json", "json2lvproj", "buildspec2json", "json2buildspec")
    foreach ($cmd in $cliCommands) {
        $tool = $cmd
        It "exists and is executable: $tool" {
            (Get-Command $tool -ErrorAction SilentlyContinue) | Should -Not -Be $null -Because "$tool not found in PATH"
        }
        It "displays help for '$tool' when --help is given" {
            $output = & $tool --help 2>&1
            $LASTEXITCODE | Should -Be 0
            $output | Should -Match "\bUsage\b"
        }
        It "exits with error on unknown flag for '$tool'" {
            $output = & $tool --unknownFlag 2>&1
            $LASTEXITCODE | Should -Not -Be 0
            $output | Should -Match "Unknown"
        }
    }

    It "requires --input and --output parameters (shows usage if missing)" {
        $output = & vipb2json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        $output | Should -Match "\bUsage\b"
    }
}

Describe "End-to-end conversion via CLI wrappers" {
    # Use TestDrive for isolation and always clean output
    $TestOut = Join-Path $TestDrive "cli-out"
    BeforeEach {
        if (Test-Path $TestOut) {
            Remove-Item $TestOut -Recurse -Force -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 250
        }
        if (!(Test-Path $TestOut)) {
            New-Item $TestOut -Type Directory | Out-Null
        }
    }

    It "converts a VIPB file to JSON via vipb2json" {
        $vipbSample = Join-Path $RepoRoot "tests/Samples/seed.vipb"
        $outJson    = Join-Path $TestOut "seed.vipb.json"
        $vipb2json  = "vipb2json"
        (Test-Path $vipbSample) | Should -BeTrue
        & $vipb2json --input $vipbSample --output $outJson
        $LASTEXITCODE | Should -Be 0
        (Test-Path $outJson) | Should -BeTrue
        $content = Get-Content $outJson -Raw
        $content | Should -Match '"Package"'
    }

    It "converts a JSON file back to VIPB via json2vipb" {
        $vipbSample = Join-Path $RepoRoot "tests/Samples/seed.vipb"
        $outJson    = Join-Path $TestOut "roundtrip.json"
        $newVipb    = Join-Path $TestOut "roundtrip.vipb"
        $vipb2json  = "vipb2json"
        $json2vipb  = "json2vipb"
        (Test-Path $vipbSample) | Should -BeTrue
        & $vipb2json --input $vipbSample --output $outJson
        $LASTEXITCODE | Should -Be 0
        & $json2vipb --input $outJson --output $newVipb
        $LASTEXITCODE | Should -Be 0
        (Test-Path $newVipb) | Should -BeTrue
        $xmlContent = Get-Content $newVipb -Raw
        $xmlContent | Should -Match "<Package"
    }

    It "converts a LVPROJ file to JSON via lvproj2json and back via json2lvproj" {
        $lvprojSample = Join-Path $RepoRoot "tests/Samples/seed.lvproj"
        $outJson     = Join-Path $TestOut "project.json"
        $newLvproj   = Join-Path $TestOut "project.lvproj"
        $lvproj2json = "lvproj2json"
        $json2lvproj = "json2lvproj"
        (Test-Path $lvprojSample) | Should -BeTrue
        & $lvproj2json --input $lvprojSample --output $outJson
        $LASTEXITCODE | Should -Be 0
        & $json2lvproj --input $outJson --output $newLvproj
        $LASTEXITCODE | Should -Be 0
        (Test-Path $newLvproj) | Should -BeTrue
        $projContent = Get-Content $newLvproj -Raw
        $projContent | Should -Match "<Project"
    }
}
