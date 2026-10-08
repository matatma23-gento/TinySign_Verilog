# Melihat timing diagram dengan GTKWave

Script simulasi mendukung `--waves` untuk menghasilkan VCD. Perekaman ditambahkan melalui modul simulasi terpisah, sehingga RTL sintetis tidak berubah. Tanpa opsi ini, regresi biasa tidak merekam waveform.

## Membuka contoh yang sudah dibuat

Pasang GTKWave jika belum tersedia:

```sh
sudo apt update
sudo apt install gtkwave
```

Dari folder proyek:

```sh
gtkwave sim/iverilog/build/tb_montgomery_wave.vcd
```

Pada panel hierarki/SST, pilih `tb_montgomery_wave`. Pilih sinyal di bawah ini, lalu seret ke area sinyal/waveform atau gunakan **Append**. Sinyal tidak otomatis muncul hanya karena file sudah dibuka; proses pemilihannya dijelaskan dalam [dokumentasi GTKWave](https://gtkwave.github.io/gtkwave/quickstart/launching.html#displaying-waveforms). Gunakan **Zoom Fit** untuk melihat seluruh simulasi ([panduan toolbar](https://gtkwave.github.io/gtkwave/ui/toolbar.html)).

```text
clk
rst_n
start
a[7:0]
b[7:0]
modulus[7:0]
raw_busy
raw_done
raw_result[7:0]
raw_error
ordinary_busy
ordinary_done
ordinary_result[7:0]
ordinary_error
```

`ordinary_*` adalah jalur perkalian biasa `a*b mod m`; `raw_*` adalah mesin Montgomery mentah. Untuk melihat langkah internal, buka `ordinary_dut` atau `raw_dut` dan tambahkan `state`, `round_count`, `b_mont`, atau `accumulator` sesuai modulnya.

## Membaca contoh

Contoh memakai WIDTH=8 agar angka mudah dibaca. Desain ECC utama tetap WIDTH=256. Periode clock contoh adalah 10 ns.

| Sinyal | Arti |
|---|---|
| `rst_n=0` | Reset aktif |
| `start=1` saat rising edge clock dan modul idle | Operand diterima |
| `busy=1` | Perhitungan sedang berlangsung |
| `done=1` | Hasil valid; pulsa satu clock |
| `error=1` | Input tidak valid; pulsa satu clock |

Transaksi pertama menerima `a=7`, `b=9`, `m=251` pada 35 ns. Mesin mentah selesai pada 125 ns (9 clock) dengan hasil 113 (`0x71`). Wrapper biasa selesai pada 225 ns (19 clock) dengan hasil 63 (`0x3F`). Kedua hasil berbeda karena mesin mentah menyertakan faktor `R^-1`, dengan `R=256`.

Transaksi kedua menghitung `250*250 mod 251`: hasil biasa adalah 1 dan hasil mentah 201 (`0xC9`). Transaksi terakhir memakai modulus genap 250: `error` aktif tanpa `busy` atau `done`. Simulasi selesai pada 550 ns. Rentang dari penerimaan request sampai `done` adalah latensi; `done` sendiri hanya selebar satu clock.

## Membuat ulang waveform

Dengan Icarus Verilog terpasang:

```sh
cd /home/mateus/Documents/Peruri/TinySign
bash scripts/run_rtl_tests.sh --waves
gtkwave sim/iverilog/build/tb_montgomery_wave.vcd
```

Jika masih memakai simulator sementara dari sesi pengujian sebelumnya, jalankan dahulu di terminal yang sama:

```sh
export IVERILOG=/tmp/tinysign-iverilog/usr/bin/iverilog
export IVERILOG_BASE=/tmp/tinysign-iverilog/usr/lib/x86_64-linux-gnu/ivl
export VVP=/tmp/tinysign-iverilog/usr/bin/vvp
```

Untuk menguji dan merekam modul lain, sebutkan testbench:

```sh
bash scripts/run_rtl_tests.sh --waves tb_hmac
gtkwave sim/iverilog/build/tb_hmac.vcd

bash scripts/run_rtl_tests.sh --waves tb_ecdsa_signer
gtkwave sim/iverilog/build/tb_ecdsa_signer.vcd
```

`--waves tb_montgomery_mul` menjalankan seluruh vektor dan menghasilkan enam file terpisah, misalnya `tb_montgomery_mul_256.vcd`. Contoh pendek cukup untuk belajar handshake; waveform regresi penuh, terutama ECDSA, membutuhkan waktu dan ruang lebih besar. Nama file hasil selalu dicetak oleh script.

GTKWave menampilkan perubahan sinyal dari simulasi RTL. Waktu 10 ns pada clock testbench adalah stimulus simulasi, bukan hasil pengukuran Fmax atau timing fisik FPGA; pemeriksaan timing implementasi tetap dilakukan di Quartus/TimeQuest.

## Diagram sistem PURI-Sign 256-bit

Waveform provisioning, signing ECDSA lengkap, dan ZEROIZE pada 25 MHz tersedia di [laporan timing PURI-Sign](../reports/puri_sign/timing/README.md). Trace berasal dari `tb/tb_puri_timing.v`; PNG/SVG dibuat oleh `scripts/render_puri_timing.py`. Ini melengkapi contoh aritmetika WIDTH=8 di atas.
