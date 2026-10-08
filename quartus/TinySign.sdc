# Baseline 50 MHz board clock constraint. Verify the selected DE10-Nano
# clock source and all generated clocks when integrating the Platform Designer system.
create_clock -name clk -period 20.000 [get_ports {clk}]
