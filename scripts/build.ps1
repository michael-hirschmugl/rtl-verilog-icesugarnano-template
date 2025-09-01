param([string]$Top="top")
. C:\oss-cad-suite\environment.ps1
$src=".\src\$Top.v"; $pcf=".\constraints\io.pcf"; $bld=".\build"
New-Item -ItemType Directory -Force -Path $bld | Out-Null
yosys -p "read_verilog $src; synth_ice40 -top $Top -json $bld\$Top.json"
nextpnr-ice40 --lp1k --package cm36 --pcf $pcf --json $bld\$Top.json --asc $bld\$Top.asc
icepack $bld\$Top.asc $bld\$Top.bin
icesprog -p
icesprog -w $bld\$Top.bin