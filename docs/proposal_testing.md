# Rencana pengujian RTL dan DE10-Nano

Dokumen ini mengubah pola pengujian pada proposal menjadi prosedur yang bisa
diulang untuk TinySign. Bagian simulasi memakai model Python sebagai oracle,
Icarus Verilog untuk simulasi Verilog-2001, dan Yosys untuk pemeriksaan struktur
serta pemetaan eksperimental Cyclone V. Bagian board memakai Quartus Prime
karena targetnya DE10-Nano dengan FPGA Cyclone V 5CSEBA6U23I7.

## Perbedaan target dari proposal

Proposal contoh menggunakan Basys3/Artix-7 dan openXC7. DE10-Nano memakai
Cyclone V, sehingga flow openXC7 tidak dapat menghasilkan bitstream untuk board
ini. openXC7 tetap dapat dipakai bila target lomba diganti ke FPGA Xilinx 7-series;
untuk DE10-Nano gunakan `quartus_sh` dan dukungan device Cyclone V. Yosys
`synth_intel_alm` di sini adalah pemeriksaan netlist eksperimental, bukan
pengganti fitter, timing analyzer, atau programmer Quartus.

## 1. Simulasi RTL

Siapkan Icarus Verilog. Jika memakai paket lokal yang sudah tersedia di mesin
pengembangan, environment berikut dapat digunakan:

```sh
export IVERILOG=/tmp/tinysign-iverilog/usr/bin/iverilog
export IVERILOG_BASE=/tmp/tinysign-iverilog/usr/lib/x86_64-linux-gnu/ivl
export VVP=/tmp/tinysign-iverilog/usr/bin/vvp
```

Jalankan pemeriksaan Python dan suite cepat:

```sh
python3 -m unittest discover -s tests -v
bash scripts/run_validation.py --quick
```

Suite lengkap menambahkan scalar multiplication, ECDSA signer, key manager,
core register, dan board self-test. Karena operasi P-256 serial memakan jutaan
siklus simulasi, jalankan setelah suite cepat lulus:

```sh
bash scripts/run_validation.py
```

Hasil tersimpan di `reports/validation/results.json`, `results.md`, dan log per
testbench. Semua angka `*_cycles` di laporan RTL adalah hitungan siklus
simulator pada clock 50 MHz; angka tersebut belum merupakan hasil timing FPGA.

### Cakupan yang dipetakan dari proposal

| Cakupan | Test yang tersedia | Bukti keluaran |
|---|---|---|
| P-256 dan RFC 6979 | `tests/test_p256.py`, `tb_rfc6979.v` | known-answer test Python/RTL |
| Montgomery dan modular arithmetic | `tb_montgomery_mul.v`, `tb_mod_arith.v` | lebar 2, 5, 8, 17, 256, 513 bit; operand/modulus invalid |
| Point/scalar/ECDSA | `tb_point_ops.v`, `tb_scalar_mult.v`, `tb_ecdsa_signer.v` | public key dan `(r,s)` deterministik |
| Key handling dan zeroize | `tb_key_manager.v`, `tb_tinysign_core.v` | write-only key, lock, readback nol, zeroize saat sign berjalan |
| Register/shell DE10 | `tb_tinysign_de10nano.v` | Avalon-MM command, status, byte-enable |
| Power-on board self-test | `tb_board_selftest.v`, `tb_selftest_uart.v` | public key `d=1`, signature, lock, zeroize, packet UART |

Kunci `d=1` hanya dipakai untuk self-test development; jangan memakainya untuk
prototipe yang menerima identitas atau kunci produksi.

## 2. Timing diagram

Untuk contoh gelombang Montgomery 8-bit:

```sh
bash scripts/run_rtl_tests.sh --waves
gtkwave sim/iverilog/build/tb_montgomery_wave.vcd
```

Sinyal utama adalah `clk`, `rst_n`, `start`, `busy`, `done`, `result`, dan
`error`. Panduan lengkap dan cara membuka VCD ada di `docs/waveforms.md`.

## 3. Pemeriksaan Yosys

Yosys hanya memeriksa elaborasi untuk target penuh dan mencoba mapping ALM untuk
Cyclone V:

```sh
export YOSYS=/tmp/tinysign-yosys/usr/bin/yosys
python3 scripts/run_yosys.py --top tinysign_core --mode check
python3 scripts/run_yosys.py --top tinysign_de10nano_selftest --mode check
python3 scripts/run_yosys.py --top mod_mul --mode cyclonev
```

Setiap run menyimpan `console.log`, `stat.json`, `netlist.json`, dan
`result.json` di `reports/yosys/<top>_<mode>/`. Hasil `pass` berarti Yosys dapat
membaca, mengelaborasi, dan memeriksa netlist; hasil itu belum berarti timing,
pinout, penggunaan resource akhir, atau bitstream sudah valid.

## 4. Build dan uji DE10-Nano

Install Quartus Prime yang memiliki device support Cyclone V, lalu compile image
self-test:

```sh
bash scripts/build_de10nano_selftest.sh
```

Project ada di `quartus/selftest/TinySignSelftest.qpf`. Top-level ini memakai
clock 50 MHz, `KEY0` sebagai reset/re-run, LED untuk heartbeat/status, dan
`GPIO0[0]` sebagai TX UART 115200 8N1. Sambungkan USB-to-TTL 3.3 V ke GPIO
tersebut (TX FPGA ke RX adapter, GND ke GND); jangan memberi 5 V ke pin FPGA.

Setelah `TinySignSelftest.sof` diprogram melalui Quartus Programmer, tahan lalu
lepas `KEY0`. LED running menyala selama test, LED pass atau fail menyala ketika
selesai. UART mengirim satu baris seperti:

```text
TS1,P,00,006F7E7A,00716670
```

Capture dan validasi paket dengan:

```sh
python3 scripts/capture_board_test.py \
  --port /dev/ttyUSB0 --timeout 30 \
  --output reports/hardware/board_test.json
```

Script membuat JSON, CSV, dan `.uart.log`. `provision_us` dan `sign_us`
dikalkulasi dari 50 MHz (`cycles / 50`) dan merupakan pengukuran board hanya
setelah perintah ini dijalankan terhadap hardware nyata. Jika tidak ada board,
status yang benar adalah `not_run`, bukan `PASS`.

## 5. Data yang dicatat untuk laporan lomba

Simpan commit RTL, versi Quartus, device/package, clock constraint, hasil
Analysis & Synthesis, Fitter, TimeQuest (Fmax/slack), resource ALM/register/
memory, dan packet UART. Pisahkan tiga bukti: hasil simulasi, hasil mapping
Yosys, dan hasil compile/timing/program Quartus. Dengan begitu angka simulasi
tidak tercampur dengan latency atau timing hasil FPGA.

