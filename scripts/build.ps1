param(
    [string]$Top = "top",
    [ValidateSet("8","12","36","72")]
    [string]$BoardClockMHz = "12"    # iCESugar-nano: 8/12/36/72 MHz möglich
)

# OSS CAD Suite einbinden
. C:\oss-cad-suite\environment.ps1

# Pfade aus deinem Repo
$src = ".\src\$Top.v"
$pcf = ".\constraints\iCE40LP1K_CM36_IceSugarNano_v1.pcf"
# Hinweis: SDC wird vom IceStorm/nextpnr-ice40-Flow ignoriert – hier nur der Vollständigkeit halber:
$sdc = ".\constraints\IceSugarNano_iCE40LP1K_12MHz_UART.sdc"

$build = ".\build"
New-Item -ItemType Directory -Force -Path $build | Out-Null

# 1) Synthesis
yosys -p "read_verilog $src; synth_ice40 -top $Top -json $build\$Top.json"

# 2) Place & Route (LP1K + CM36 passen zum iCESugar-nano)
#    --freq ist ein Zielwert für die Timing-Optimierung (hier 12 MHz als pragmatisches Default)
nextpnr-ice40 `
  --lp1k `
  --package cm36 `
  --pcf $pcf `
  --json $build\$Top.json `
  --asc $build\$Top.asc `
  --freq 12

# Optional: PnR-Report (zeigt u.a. max. erreichbare Frequenz)
# nextpnr-ice40 ... --report $build\$Top.nextpnr.json

# 3) Bitstream packen
icepack $build\$Top.asc $build\$Top.bin

# 4) Board-Clock (MCO) auf gewünschte Frequenz stellen
#    iCESugar-nano Mapping: 1=8MHz, 2=12MHz, 3=36MHz, 4=72MHz
$clkIndex = switch ($BoardClockMHz) {
    "8"  { 1 }
    "12" { 2 }
    "36" { 3 }
    "72" { 4 }
}
icesprog -c $clkIndex

# 5) Probe (optional) und Flash
icesprog -p
icesprog -w $build\$Top.bin
