param (
    [string]$Original = "tests/Samples/NI Icon editor.vipb",
    [string]$Patched  = "tmp.vipb",
    [string]$Json1    = "tmp.json",
    [string]$Json2    = "tmp2.json"
)

function Dump-Info {
    param([string]$File)
    Write-Host "`n===== $File ====="
    if (Test-Path $File) {
        Write-Host "SHA256: " -NoNewline
        (Get-FileHash $File -Algorithm SHA256).Hash
        Get-Content $File -Head 5 | Write-Host
    } else {
        Write-Host "File not found!"
    }
}

function Show-FirstDiff {
    param([string]$A, [string]$B)
    if ((Test-Path $A) -and (Test-Path $B)) {
        $linesA = Get-Content $A
        $linesB = Get-Content $B
        $min = [Math]::Min($linesA.Count, $linesB.Count)
        for ($i=0; $i -lt $min; $i++) {
            if ($linesA[$i] -ne $linesB[$i]) {
                Write-Host "`n=== First difference at line $($i+1) ==="
                Write-Host "A: $($linesA[$i])"
                Write-Host "B: $($linesB[$i])"
                break
            }
        }
        if ($linesA.Count -ne $linesB.Count) {
            Write-Host "=== Files have different number of lines ($($linesA.Count) vs $($linesB.Count)) ==="
        }
    } else {
        Write-Host "Cannot compare, missing files."
    }
}

# Show hashes and preview of each file
Dump-Info $Original
Dump-Info $Patched
Dump-Info $Json1
Dump-Info $Json2

# Show first diff (original VIPB vs rebuilt)
Show-FirstDiff $Original $Patched

# Show first diff (original JSON vs roundtripped)
Show-FirstDiff $Json1 $Json2
