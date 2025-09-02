#-----------------------------------------------------------
# Timing Constraints for IceSugarNano (iCE40LP1K-CM36)
# System clock = 12 MHz from APM32 MCO on FPGA pin D1
# UART TX on A3 and UART RX on B3
#-----------------------------------------------------------

# --- System Clock ---
# 12 MHz -> Period = 83.333 ns
create_clock -name CLK_IN -period 83.333 [get_ports {CLK_IN}]

# --- UART ---
# UART_RX is asynchronous (driven by external MCU, not phase-aligned with CLK_IN).
# Do not apply input delay constraints; instead handle with CDC/synchronizer in RTL.
set_false_path -from [get_ports {UART_RX}]

# UART_TX is synchronous to CLK_IN inside the FPGA.
# No additional constraints are required unless the receiving device
# specifies setup/hold requirements relative to CLK_IN.
# For a standard UART, no extra timing constraints are necessary.

#-----------------------------------------------------------
# End of file
#-----------------------------------------------------------
