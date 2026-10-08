# PURI-Sign core clock: 25 MHz. The fitted shared engine does not meet 50 MHz.
# This constraint does NOT divide the physical clock. Supply clk from a 25 MHz
# PLL/HPS clock when integrating with the DE10-Nano's 50 MHz board oscillator.
# Add board/system I/O timing constraints during Platform Designer integration.
create_clock -name clk -period 40.000 [get_ports {clk}]
