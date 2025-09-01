param([string]$Top = "top")

$ErrorActionPreference = "Stop"

# 0) Environment
. C:\oss-cad-suite\environment.ps1

# 1) Folders
$Bld  = ".\build"
$Docs = ".\docs"
New-Item -ItemType Directory -Force -Path $Bld, $Docs | Out-Null

# 2) Paths
$Src  = ".\src\$Top.v"
$Json = "$Bld\$Top.json"
$Asc  = "$Bld\$Top.asc"
$Pcf  = ".\constraints\io.pcf"
$Dot  = "$Docs\${Top}_schem.dot"
$Svg  = "$Docs\${Top}_schem.svg"

if (-not (Test-Path $Src)) { throw "Source not found: $Src" }

# 3) RTL-Schematic (DOT erzeugen; Rendering optional)
$yosysShow = @(
  "read_verilog $Src",
  "hierarchy -check -top $Top",
  "proc; opt; fsm; opt",
  "show -format dot -prefix $Docs\${Top}_schem -colors 2 $Top"
) -join "; "
yosys -q -p $yosysShow

# Try to render DOT -> SVG if Graphviz is present
function Find-Dot {
  $cands = @()

  # 1) dot aus PATH (liefert ein Command-Objekt)
  $cmd = Get-Command dot -ErrorAction SilentlyContinue
  if ($cmd) { $cands += $cmd.Source }  # .Source ist der volle Pfad zur EXE

  # 2) typische Installationspfade
  $cands += @(
    "C:\Program Files\Graphviz\bin\dot.exe",
    "$env:ProgramFiles\Graphviz\bin\dot.exe",
    "$env:ProgramFiles(x86)\Graphviz\bin\dot.exe",
    "C:\msys64\mingw64\bin\dot.exe"
  )

  foreach ($c in $cands) {
    if ($c -and (Test-Path $c)) {
      return (Resolve-Path $c).Path  # garantiert ein sauberer String-Pfad
    }
  }
  return $null
}

$dotExe = Find-Dot
if ($dotExe) {
  Write-Host "Using dot at: $dotExe"
  # Variante 1: Call-Operator mit Quotes
  & "$dotExe" -Tsvg "$Dot" -o "$Svg"

  # Alternative (noch robuster):
  # Start-Process -FilePath "$dotExe" -ArgumentList @("-Tsvg", "$Dot", "-o", "$Svg") -NoNewWindow -Wait

  Write-Host "[OK] Schematic SVG: $Svg"
} else {
  Write-Warning "Graphviz 'dot' not found. DOT written: $Dot"
}

# 4) Techmapped JSON (Pflicht für nextpnr)
$yosysSynth = @(
  "read_verilog $Src",
  "synth_ice40 -top $Top -json $Json"
) -join "; "
yosys -q -p $yosysSynth

# 5) Optional: netlistsvg (Blockdiagramm)
try {
  $npx = Get-Command npx -ErrorAction SilentlyContinue
  if ($npx) { & $npx.Path netlistsvg $Json "-o" "$Docs\${Top}_block.svg" }
} catch { Write-Warning "netlistsvg failed: $($_.Exception.Message)" }

# 6) P&R + Timing + Rückführung
nextpnr-ice40 --lp1k --package cm36 --pcf $Pcf --json $Json --asc $Asc
icetime -d lp1k -P cm36 -p $Pcf -r "$Docs\timing.rpt" $Asc
icebox_vlog $Asc > "$Docs\${Top}_from_bitstream.v"

# 7) Quick timing digest
Get-Content "$Docs\timing.rpt" | Select-String -Pattern "Fmax|Max delay|Critical path" | ForEach-Object { $_.Line }
