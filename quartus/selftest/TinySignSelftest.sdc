create_clock -name clk50 -period 20.000 [get_ports {FPGA_CLK1_50}]
derive_clock_uncertainty
# KEY0 asynchronously asserts reset; release is synchronized by reset_pipe.
set_false_path -from [get_ports {KEY0_N}] -to [get_registers {*reset_pipe*}]
# LED and UART observers are asynchronous, not synchronous receiving registers.
set_false_path -to [get_ports {LED[*] GPIO0_TX}]
