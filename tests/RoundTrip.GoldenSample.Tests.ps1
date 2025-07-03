# RoundTrip.GoldenSample.Tests.ps1 - Round-trip conversion tests for VIPB and LVPROJ samples
param()  # no params

##### Helper: Output directory setup #####
BeforeAll {
    # Define a temporary output directory for conversion artifacts
    $script:RoundTripOutDir = Join-Path $PSScriptRoot "RoundTripTestOutput"
    if (Test-Path $script:RoundTripOutDir) {
        Remove-Item $script:RoundTripOutDir -Recurse -Force
    }
    New-Item $script:RoundTripOutDir -Type Directory | Out-Null
}

AfterAll {
    # Clean up the output directory after tests (optional; remove if keeping artifacts for debugging)
    if (Test-Path $script:RoundTripOutDir) {
        Remove-Item $script:RoundTripOutDir -Recurse -Force
    }
}

##### VIPB Round-Trip Tests #####
Describe "VIPB golden sample round-trip" {
    # Discover all .vipb files in tests/Samples
    $vipbSamples = Get-ChildItem "$PSScriptRoot/Samples" -Filter '*.vipb' -File
    if ($vipbSamples.Count -eq 0) {
        It "has at least one .vipb sample file to test" {
            $vipbSamples.Count | Should -BeGreaterThan 0 -Because "No .vipb files found in tests/Samples/."
        }
    }
    else {
        foreach ($file in $vipbSamples) {
            $thisFile = $file
            It "round-trips $($thisFile.Name) without JSON differences" {
                $sampleName   = [System.IO.Path]::GetFileNameWithoutExtension($thisFile.Name)
                $sampleExt    = [System.IO.Path]::GetExtension($thisFile.Name)
                $workDir      = Join-Path $script:RoundTripOutDir "$($sampleName)$($sampleExt)"
                if (-not (Test-Path $workDir)) {
                    New-Item $workDir -Type Directory | Out-Null
                }

                # Define paths for intermediate files
                $origJsonPath      = Join-Path $workDir "$sampleName.original.json"
                $roundtripVipbPath = Join-Path $workDir "$sampleName.roundtrip.vipb"
                $roundtripJsonPath = Join-Path $workDir "$sampleName.roundtrip.json"

                try {
                    # 1. Convert original .vipb to JSON
                    & vipb2json --input "$($thisFile.FullName)" --output "$origJsonPath"
                    if ($LASTEXITCODE -ne 0) {
                        throw "vipb2json failed (exit code $LASTEXITCODE)"
                    }
                    if (-not (Test-Path $origJsonPath)) {
                        throw "Expected JSON output was not created: $origJsonPath"
                    }

                    # 2. Convert JSON back to .vipb
                    & json2vipb --input "$origJsonPath" --output "$roundtripVipbPath"
                    if ($LASTEXITCODE -ne 0) {
                        throw "json2vipb failed (exit code $LASTEXITCODE)"
                    }
                    if (-not (Test-Path $roundtripVipbPath)) {
                        throw "Expected .vipb output was not created: $roundtripVipbPath"
                    }

                    # 3. Convert the round-tripped .vipb again to JSON
                    & vipb2json --input "$roundtripVipbPath" --output "$roundtripJsonPath"
                    if ($LASTEXITCODE -ne 0) {
                        throw "vipb2json (round-trip) failed (exit code $LASTEXITCODE)"
                    }
                    if (-not (Test-Path $roundtripJsonPath)) {
                        throw "Expected JSON output was not created: $roundtripJsonPath"
                    }
                }
                catch {
                    Write-Host "ERROR: Round-trip conversion failed for $($thisFile.Name) - $($_.Exception.Message)"
                    throw  # Fail this test case
                }

                # Load JSON contents for comparison
                $origJson     = Get-Content $origJsonPath -Raw
                $roundtripJson = Get-Content $roundtripJsonPath -Raw

                # Compare original vs round-tripped JSON text
                if ($origJson -ne $roundtripJson) {
                    # Find and display the first difference between the two JSONs for debugging
                    $origLines  = $origJson -split "`r`n?|`n"
                    $roundLines = $roundtripJson -split "`r`n?|`n"
                    $minCount   = [Math]::Min($origLines.Count, $roundLines.Count)
                    for ($i = 0; $i -lt $minCount; $i++) {
                        if ($origLines[$i] -ne $roundLines[$i]) {
                            Write-Host ("JSON difference at line {0}:`n  Original: {1}`n  Round-trip: {2}" -f ($i+1), $origLines[$i], $roundLines[$i])
                            break
                        }
                    }
                    if ($origLines.Count -ne $roundLines.Count) {
                        Write-Host "JSON files have different line counts: $($origLines.Count) vs $($roundLines.Count)"
                    }
                    # Fail the test with a descriptive message
                    $false | Should -BeTrue -Because "Round-trip JSON output differs from original for $($thisFile.Name)."
                }
                else {
                    # Optionally assert success explicitly
                    $true | Should -BeTrue  # (passes trivially, ensures Pester counts this test as executed)
                }
            }
        }
    }
}

##### LVPROJ Round-Trip Tests #####
Describe "LVPROJ golden sample round-trip" {
    # Discover all .lvproj files in tests/Samples
    $lvprojSamples = Get-ChildItem "$PSScriptRoot/Samples" -Filter '*.lvproj' -File
    if ($lvprojSamples.Count -eq 0) {
        It "has at least one .lvproj sample file to test" {
            $lvprojSamples.Count | Should -BeGreaterThan 0 -Because "No .lvproj files found in tests/Samples/."
        }
    }
    else {
        foreach ($file in $lvprojSamples) {
            $thisFile = $file
            It "round-trips $($thisFile.Name) without JSON differences" {
                $sampleName     = [System.IO.Path]::GetFileNameWithoutExtension($thisFile.Name)
                $sampleExt      = [System.IO.Path]::GetExtension($thisFile.Name)
                $workDir        = Join-Path $script:RoundTripOutDir "$($sampleName)$($sampleExt)"
                if (-not (Test-Path $workDir)) {
                    New-Item $workDir -Type Directory | Out-Null
                }

                # Define paths for intermediate files
                $origJsonPath        = Join-Path $workDir "$sampleName.original.json"
                $roundtripProjPath   = Join-Path $workDir "$sampleName.roundtrip.lvproj"
                $roundtripJsonPath   = Join-Path $workDir "$sampleName.roundtrip.json"

                try {
                    # 1. Convert original .lvproj to JSON
                    & lvproj2json --input "$($thisFile.FullName)" --output "$origJsonPath"
                    if ($LASTEXITCODE -ne 0) {
                        throw "lvproj2json failed (exit code $LASTEXITCODE)"
                    }
                    if (-not (Test-Path $origJsonPath)) {
                        throw "Expected JSON output was not created: $origJsonPath"
                    }

                    # 2. Convert JSON back to .lvproj
                    & json2lvproj --input "$origJsonPath" --output "$roundtripProjPath"
                    if ($LASTEXITCODE -ne 0) {
                        throw "json2lvproj failed (exit code $LASTEXITCODE)"
                    }
                    if (-not (Test-Path $roundtripProjPath)) {
                        throw "Expected .lvproj output was not created: $roundtripProjPath"
                    }

                    # 3. Convert the round-tripped .lvproj again to JSON
                    & lvproj2json --input "$roundtripProjPath" --output "$roundtripJsonPath"
                    if ($LASTEXITCODE -ne 0) {
                        throw "lvproj2json (round-trip) failed (exit code $LASTEXITCODE)"
                    }
                    if (-not (Test-Path $roundtripJsonPath)) {
                        throw "Expected JSON output was not created: $roundtripJsonPath"
                    }
                }
                catch {
                    Write-Host "ERROR: Round-trip conversion failed for $($thisFile.Name) - $($_.Exception.Message)"
                    throw
                }

                # Load JSON contents and compare
                $origJson     = Get-Content $origJsonPath -Raw
                $roundtripJson = Get-Content $roundtripJsonPath -Raw

                if ($origJson -ne $roundtripJson) {
                    # Identify first difference for output
                    $origLines  = $origJson -split "`r`n?|`n"
                    $roundLines = $roundtripJson -split "`r`n?|`n"
                    $minCount   = [Math]::Min($origLines.Count, $roundLines.Count)
                    for ($i = 0; $i -lt $minCount; $i++) {
                        if ($origLines[$i] -ne $roundLines[$i]) {
                            Write-Host ("JSON difference at line {0}:`n  Original: {1}`n  Round-trip: {2}" -f ($i+1), $origLines[$i], $roundLines[$i])
                            break
                        }
                    }
                    if ($origLines.Count -ne $roundLines.Count) {
                        Write-Host "JSON files have different line counts: $($origLines.Count) vs $($roundLines.Count)"
                    }
                    $false | Should -BeTrue -Because "Round-trip JSON output differs from original for $($thisFile.Name)."
                }
                else {
                    $true | Should -BeTrue
                }
            }
        }
    }
}
