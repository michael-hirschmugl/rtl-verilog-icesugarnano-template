param(
  [string]$Top = "top",                      # top module name (src\<Top>.v)
  [string]$SrcDir = ".\src",
  [string]$BldDir = ".\build",
  [string]$Pcf = ".\constraints\io.pcf",
  [string]$Device = "lp1k",                  # lp1k, up5k, hx8k, ...
  [string]$Package = "cm36",                 # e.g. cm36
  [switch]$SynthesizeIfMissing,              # build JSON if missing
  [switch]$ForceSynthesize,                  # always rebuild JSON
  [int]$FreqMHz = 0,                         # placement target (0 = skip)
  [int]$Seed = -1,                           # placer seed (-1 = skip)
  [string]$EnvScript = "C:\oss-cad-suite\environment.ps1",
  [string[]]$ExtraNextpnrArgs = @()
)

$ErrorActionPreference = "Stop"

# 0) environment
if (Test-Path $EnvScript) { . $EnvScript }

# 1) paths
$src  = Join-Path $SrcDir "$Top.v"
$json = Join-Path $BldDir "$Top.json"
$asc  = Join-Path $BldDir "$Top.asc"

# 2) ensure build folder
New-Item -ItemType Directory -Force -Path $BldDir | Out-Null

# 3) provide JSON (optional synth)
$needSynth = $ForceSynthesize -or (-not (Test-Path $json))
if ($needSynth) {
  if (-not $SynthesizeIfMissing -and -not $ForceSynthesize) {
    throw "Netlist not found: $json. Run with -SynthesizeIfMissing or create it first."
  }
  if (-not (Test-Path $src)) { throw "Source not found: $src" }
  Write-Host "[*] Yosys: synth_ice40 -> $json"
  $cmd = "read_verilog $src; synth_ice40 -top $Top -json $json"
  yosys -q -p $cmd
}

# 4) run nextpnr GUI
if (-not (Test-Path $Pcf)) {
  Write-Warning "PCF not found: $Pcf (nextpnr will run without it, pins/timing will be generic)."
}

$npArgs = @("--$Device","--package",$Package,"--json",$json,"--asc",$asc,"--gui")
if (Test-Path $Pcf) { $npArgs += @("--pcf",$Pcf) }
if ($FreqMHz -gt 0) { $npArgs += @("--freq",$FreqMHz) }
if ($Seed -ge 0)    { $npArgs += @("--seed",$Seed) }
if ($ExtraNextpnrArgs.Count -gt 0) { $npArgs += $ExtraNextpnrArgs }

Write-Host "[*] nextpnr-ice40 $($npArgs -join ' ')"
& nextpnr-ice40 @npArgs

# 5) result hint
if (Test-Path $asc) {
  Write-Host "[OK] ASC written: $asc"
} else {
  Write-Warning "ASC not found. Check nextpnr log or save from the GUI."
}
