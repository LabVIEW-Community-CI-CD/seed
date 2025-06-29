param(
    [string]$SampleVipb = "tests/Samples/NI Icon editor.vipb"
)

Describe 'VIPB round‑trip' {
    It 'converts to JSON' {
        & dotnet run --project src/VipbJsonTool -- vipb2json "$SampleVipb" out.json
        Test-Path out.json | Should -BeTrue
    }
    It 'rebuilds from JSON' {
        & dotnet run --project src/VipbJsonTool -- json2vipb out.json rebuilt.vipb
        Test-Path rebuilt.vipb | Should -BeTrue
    }
    It 'hash‑matches original' {
        $orig = (Get-FileHash "$SampleVipb" -Algorithm SHA256).Hash
        $new  = (Get-FileHash rebuilt.vipb  -Algorithm SHA256).Hash
        $orig | Should -Be $new
    }
}
