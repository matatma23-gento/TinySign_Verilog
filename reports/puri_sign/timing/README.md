# Timing diagram PURI-Sign — 25 MHz

Diagram berasal dari **simulasi RTL aktual** `tb/tb_puri_timing.v` menggunakan Verilator. Clock 25 MHz (40 ns/siklus) adalah stimulus testbench. Ini bukan rekaman logic analyzer di DE10-Nano, simulasi netlist dengan delay routing, atau bukti Fmax. Pemeriksaan timing implementasi tetap menggunakan Quartus/TimeQuest.

## Diagram

| File | Isi |
|---|---|
| [01_overview.png](01_overview.png) / [SVG](01_overview.svg) | Provisioning, lock, signing lengkap, kemudian signing kedua yang dibatalkan dengan ZEROIZE |
| [02_signing_detail.png](02_signing_detail.png) / [SVG](02_signing_detail.svg) | Dua zoom: pembentukan nonce dan peluncuran scalar; konversi affine sampai signature selesai |
| [03_handshake_zeroize.png](03_handshake_zeroize.png) / [SVG](03_handshake_zeroize.svg) | Zoom per siklus: penerimaan SIGN, penyelesaian SIGN, dan interupsi ZEROIZE |
| [control_events.vcd](control_events.vcd) | Transisi sinyal kontrol terpilih untuk GTKWave |
| [control_events.csv](control_events.csv) | Trace kontrol mentah dari testbench |
| [timing_summary.json](timing_summary.json) | Angka terstruktur dan SHA-256 sumber RTL/testbench/trace |

Semua sumbu waktu linear dalam masing-masing panel. Pulsa 40 ns terlihat sangat tipis pada skala mikrodetik atau milidetik; gunakan diagram handshake untuk melihat lebar pulsa. Panel A dan B pada diagram detail merupakan jendela waktu terpisah.

## Hasil simulasi

Vektor uji menggunakan private key uji `d=1` dan digest SHA-256 dari `sample`. Testbench memeriksa hasil `r` dan `s` terhadap nilai yang diharapkan, status key lock, readback kunci yang selalu nol, serta pembatalan dan pembersihan state saat ZEROIZE. Kedua pemeriksaan utama **PASS**; lihat [simulation.log](simulation.log). Ini pengujian satu skenario untuk visualisasi, bukan pengganti seluruh regresi kriptografi.

| Operasi | Siklus core | Waktu pada 25 MHz |
|---|---:|---:|
| Provisioning termasuk pembentukan public key | 7,303,706 | 292.14824 ms |
| Signing ECDSA P-256 lengkap | 7,437,840 | 297.51360 ms |

Latensi dihitung dari awal sampai akhir kepemilikan engine oleh controller core. Tidak termasuk penulisan awal key/digest atau pembacaan signature melalui bus.

Rincian signing di bawah adalah waktu state controller, **termasuk handshake**, bukan hanya waktu `busy` masing-masing unit. Baris penerimaan dan publikasi masing-masing satu siklus.

| Tahap | Siklus | Waktu (µs) |
|---|---:|---:|
| Penerimaan / publikasi hasil | 1 | 0.04 |
| RFC6979 | 1,521 | 60.84 |
| Scalar kG | 7,169,026 | 286761.04 |
| Inversi Z modulo p | 132,610 | 5304.40 |
| Kuadrat Z^-1 modulo p | 517 | 20.68 |
| Konversi x dan pembentukan r | 517 | 20.68 |
| Inversi k modulo n | 132,610 | 5304.40 |
| Perkalian r*d modulo n | 517 | 20.68 |
| Penjumlahan z + r*d | 3 | 0.12 |
| Perkalian untuk s | 517 | 20.68 |
| Penerimaan / publikasi hasil | 1 | 0.04 |

## Cara membaca kontrol

- `owner: PROVISION` dan `owner: SIGN` menunjukkan controller yang sedang memakai engine bersama. Keduanya tidak pernah aktif bersamaan pada trace ini.
- `shared scalar busy` menunjukkan pemakaian scalar engine untuk `dG` pada provisioning, lalu `kG` pada signing. Operasi ini mendominasi durasi.
- `shared inverse busy` dan `shared multiply busy` adalah unit yang dibagi pada level core. Multiplier internal di dalam scalar/inverse tidak direkam secara terpisah; baris multiply yang rendah tidak berarti seluruh aktivitas perkalian berhenti.
- `start` dan `done` adalah handshake. Pulsa `scalar_done`, `inv_done`, `mul_done`, `sign_done`, dan `key_zeroize` yang diamati masing-masing 40 ns. `done_latch` adalah status core yang bertahan sampai perintah berikutnya.
- `sign_valid` juga merupakan status tersimpan. Dalam RTL saat ini, nilainya **tetap 1 ketika signing kedua dimulai**, karena hasil sebelumnya masih tersedia. Untuk mengetahui penyelesaian transaksi baru, gunakan urutan penerimaan perintah, `busy`, dan `done_latch`; jangan menganggap `sign_valid=1` sendiri sebagai tanda transaksi baru selesai.
- Diagram handshake bagian B juga memperlihatkan perintah signing kedua, dua siklus setelah transaksi pertama selesai; perubahan `busy` kembali tinggi memang bagian dari stimulus testbench.

Pada diagram ZEROIZE, siklus 0 adalah rising edge saat perintah diterima. `key_zeroize` aktif dan shared scalar berhenti pada timestamp itu dalam simulasi tanpa delay; `sign_valid` core juga turun pada timestamp penerimaan; `key_valid` dan `key_locked` turun pada +1 siklus (40 ns); core kembali idle dan menyatakan selesai pada +2 siklus (80 ns). Ini urutan kontrol RTL, bukan pengukuran waktu penghapusan fisik atau bukti ketahanan terhadap serangan fisik.

## Format trace dan reproduksi

Logger merekam perubahan kontrol secara event-driven. Jika ada beberapa perubahan delta-cycle pada timestamp yang sama, renderer mengambil nilai terakhir. Karena itu diagram dan VCD menampilkan state yang sudah stabil pada setiap timestamp, bukan glitch propagasi fisik. VCD memakai timescale 1 ns, hanya berisi kontrol pada `puri_sign_control`, tanpa operand rahasia atau clock. Clock dalam gambar zoom direkonstruksi persis dari stimulus testbench: rising edge pertama 20 ns, periode 40 ns.

Jalankan dari root proyek dengan Verilator, compiler C++, Python, NumPy, dan Matplotlib tersedia:

```sh
mkdir -p reports/puri_sign/timing
verilator --binary --timing -Wno-fatal -j 2 --top-module tb_puri_timing --Mdir /tmp/puri_timing_build rtl/*/*.v tb/tb_puri_timing.v > reports/puri_sign/timing/build.log 2>&1
/tmp/puri_timing_build/Vtb_puri_timing > reports/puri_sign/timing/simulation.log 2>&1
python3 scripts/render_puri_timing.py
gtkwave reports/puri_sign/timing/control_events.vcd
```

Renderer memeriksa jumlah siklus, tidak adanya owner yang tumpang tindih/error, lebar pulsa selesai, validitas hasil, serta status akhir sesudah ZEROIZE. Pembuatan diagram hanya menambah testbench, renderer, dan dokumentasi; RTL synthesizable dan SOF tidak diubah.
