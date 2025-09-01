param(
  [string]$Top = "top",                 # matches src\<Top>.v
  [string]$TbFile = "tb_top.v",         # testbench in tb\
  [string]$SrcDir = ".\src",
  [string]$TbDir  = ".\tb",
  [string]$BldDir = ".\build",
  [string[]]$ExtraSrc = @(),            # extra RTL (not already `include`d)
  [switch]$NoWave,                      # opt-out: don't open gtkwave
  [string]$EnvScript = "C:\oss-cad-suite\environment.ps1",
  [string]$GtkwavePath = ""             # optional explicit path to gtkwave.exe
)

$ErrorActionPreference = "Stop"

# Load OSS CAD Suite environment (adds iverilog/vvp/gtkwave to PATH if present)
if (Test-Path $EnvScript) { . $EnvScript }

# Paths
$TopSrc = Join-Path $SrcDir "$Top.v"
$TbPath = Join-Path $TbDir  $TbFile
$SimOut = Join-Path $BldDir "sim.vvp"

# Checks
if (-not (Test-Path $TopSrc)) { throw "Top source not found: $TopSrc" }
if (-not (Test-Path $TbPath)) { throw "Testbench not found: $TbPath" }

# Create build folder
New-Item -ItemType Directory -Force -Path $BldDir | Out-Null

# Order matters: TB first (has `initial`), then top, then extras
$Sources = @($TbPath, $TopSrc) + $ExtraSrc

Write-Host "[*] Compile with iverilog..."
& iverilog -g2012 -o $SimOut $Sources

Write-Host "[*] Run simulation (vvp)..."
& vvp $SimOut

# Find latest VCD produced by TB
$vcd = Get-ChildItem -Path $BldDir -Filter *.vcd -ErrorAction SilentlyContinue |
       Sort-Object LastWriteTime -Descending | Select-Object -First 1

if ($vcd) {
  Write-Host "[OK] VCD written: $($vcd.FullName)"

  if (-not $NoWave) {
    # Resolve gtkwave path:
    $gtkw = $null
    if ($GtkwavePath -and (Test-Path $GtkwavePath)) {
      $gtkw = $GtkwavePath
    } else {
      $cmd = Get-Command gtkwave -ErrorAction SilentlyContinue
      if ($cmd) { $gtkw = $cmd.Path }
      # fallback: common OSS CAD Suite location
      if (-not $gtkw -and $Env:OSS_CAD_SUITE) {
        $cand = Join-Path $Env:OSS_CAD_SUITE "bin\gtkwave.exe"
        if (Test-Path $cand) { $gtkw = $cand }
      }
      if (-not $gtkw) {
        $cand2 = "C:\oss-cad-suite\bin\gtkwave.exe"
        if (Test-Path $cand2) { $gtkw = $cand2 }
      }
    }

    if ($gtkw) {
      Write-Host "[*] Launching gtkwave..."
      & $gtkw $vcd.FullName
    } else {
      Write-Warning "gtkwave not found. Provide -GtkwavePath <path>\` or add it to PATH."
    }
  }
} else {
  Write-Warning 'No .vcd found. Does your TB call $dumpfile("build/tb_top.vcd") and $dumpvars(0, tb_top)?'
}

Write-Host "[DONE] Simulation finished."
