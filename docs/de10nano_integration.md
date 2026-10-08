# DE10-Nano integration status

`rtl/platform/tinysign_de10nano.v` is the Platform Designer-facing Avalon-MM shell. It uses byte offsets from `docs/interface.md`, 32-bit data, four byte enables, combinational reads, and no wait states. The register core rejects partial writes and busy writes; ZEROIZE remains accepted while an operation is active.

`quartus/TinySign.qpf` and `TinySign.qsf` define a Cyclone V project targeting device `5CSEBA6U23I7`. `TinySign.sdc` supplies a 20 ns clock constraint as a 50 MHz baseline. Confirm the actual clock source and replace or extend timing constraints as required by the final Platform Designer system.

## Remaining board work

- Open the project in a compatible Quartus Prime edition and run Analysis & Synthesis, then Fitter and timing analysis.
- Add the DE10-Nano HPS/Lightweight HPS-to-FPGA bridge system in Platform Designer and connect the Avalon-MM slave to that bridge.
- Add board pin assignments for the actual clock, reset, and any demo indicators. No pin locations are guessed in this project skeleton.
- Check generated clocks, address width/offsets, reset polarity, and HPS bridge access from software.
- Program the board and measure command latency and FPGA resource/timing results. Do not present simulator cycle counts as board measurements.

Quartus and the DE10-Nano are not available in the current workspace environment. The Avalon shell has passed Icarus elaboration and directed transaction simulation; synthesis and board behavior have not been verified.
