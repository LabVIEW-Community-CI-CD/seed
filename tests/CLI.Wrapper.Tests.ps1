$RepoRoot = Split-Path $PSScriptRoot -Parent

Describe "CLI wrapper scripts basic behavior" {

    $cliCommands = @(
        "vipb2json","json2vipb",
        "lvproj2json","json2lvproj",
        "buildspec2json","json2buildspec"
    )

    It "exists and is executable: <cmd>" -TestCases $cliCommands {
        param($cmd)
        (Get-Command $cmd -ErrorAction SilentlyContinue) |
            Should -Not -Be $null -Because "$cmd not found on PATH"
    }

    It "displays help for <cmd> when --help is given" -TestCases $cliCommands {
        param($cmd)
        $exe = (Get-Command $cmd -ErrorAction Stop).Path
        $out = & $exe --help 2>&1
        $LASTEXITCODE | Should -Be 0
        $out | Should -Match '\bUsage\b'
    }

    It "exits with error on unknown flag for <cmd>" -TestCases $cliCommands {
        param($cmd)
        $exe = (Get-Command $cmd -ErrorAction Stop).Path
        $out = & $exe --noSuchFlag 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        $out | Should -Match 'Unknown'
    }

    It "requires --input and --output parameters (shows usage if missing)" {
        $vipb2json = (Get-Command vipb2json -ErrorAction Stop).Path
        $out = & $vipb2json 2>&1
        $LASTEXITCODE | Should -Not -Be 0
        $out | Should -Match '\bUsage\b'
    }
}
