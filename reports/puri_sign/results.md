# PURI-Sign — hasil refaktor 8 Oktober 2026

**Core ECDSA penuh berhasil fit pada Cyclone V 5CSEBA6U23I7.**

| Metrik | Hasil |
|---|---:|
| ALMs needed / logic utilization | 27.853 / 41.910 (66%) |
| ALMs dalam placement fisik | 32.834 |
| LAB terpakai sebagian/penuh | 3.971 / 4.191 (95%) |
| Register | 45.242 |
| Penurunan ALMs needed dari baseline 46.158 | 18.305 (39,66%) |
| Fitter / Assembler | PASS / PASS |
| Timing internal 50 MHz | FAIL, setup -5,006 ns |
| Timing internal 25 MHz, analisis ulang fit yang sama | PASS, setup +14,994 ns |
| Worst hold slack, seluruh corner | +0,113 ns |
| Signing pada 25 MHz, dihitung dari simulasi | 297,5136 ms |

Satu mesin scalar, satu inversi, dan satu multiplier tingkat atas dipakai
bersama provisioning dan signing. Total multiplier pada seluruh hierarki turun
dari 8 menjadi 4. RFC6979/HMAC tetap satu instance seperti sebelumnya.

## Validasi fungsi

| Pengujian | Simulator | Hasil |
|---|---|---|
| 9 tes referensi P-256 / protokol board | Python | PASS |
| HMAC dan RFC6979 | Icarus Verilog 12.0 | PASS |
| Core d=1, signature dan zeroize | Icarus Verilog 12.0 | PASS |
| Shared engines: RFC6979 public key/signature, repeat, busy rejection, abort/recovery | Verilator 5.020 | PASS |
| Key manager standalone | Verilator 5.020 | PASS |
| Signer standalone | Verilator 5.020 | PASS |
| Avalon-MM shell | Verilator 5.020 | PASS |

Dua simulasi Icarus yang lama dihentikan setelah cakupan terkait selesai dengan
Verilator; detail ada di [manifest](results.json). Tidak ada pengujian board fisik.

## Batas penggunaan

Proyek [TinySign.qpf](../../quartus/puri_sign/TinySign.qpf) menggunakan constraint
clock core **25 MHz**. SDC tidak mengubah clock fisik: integrasi memerlukan clock
25 MHz dari PLL/HPS dan domain Avalon yang sesuai. Build masih shell Avalon-MM,
memiliki 81 pin tanpa exact assignment dan jalur I/O belum diberi delay constraint.
SOF yang dihasilkan belum boleh diperlakukan sebagai image board siap program.

Build awal dan bitstream dibuat dengan fit bertarget 50 MHz; laporan timing itu
gagal dan disimpan sebagai [timing_50mhz.sta.summary](timing_50mhz.sta.summary).
SDC lalu diperbarui dan `quartus_sta TinySign -c TinySign` memvalidasi kembali
netlist yang sama pada 25 MHz. Tidak ada perubahan RTL atau refit pada langkah ini.
Klaim PASS timing hanya berlaku untuk jalur internal yang sudah diberi constraint.

## Bukti

- [Laporan Fitter](../../quartus/puri_sign/output_files/TinySign.fit.rpt)
- [Ringkasan timing 25 MHz](../../quartus/puri_sign/output_files/TinySign.sta.summary)
- [Log pengujian shared engines](verilator_shared.log)
- [Manifest sumber, pengujian, dan hash artefak](results.json)
- [Penjelasan arsitektur dan langkah reproduksi](../../docs/puri_sign_area.md)

## Proposal PERURI

Ringkasan hasil ini telah dimasukkan ke dalam proposal enam halaman utama, dengan referensi dan timing detail pada lampiran: [Proposal PERURI PURI-Sign](../../artifacts/proposal_peruri_20261008/Proposal_PERURI_PURI_Sign_final.docx). Naskah mempertahankan batas klaim: board fisik belum diuji, SOF masih shell Avalon-MM, dan timing 25 MHz berlaku untuk jalur internal yang dikonstrain.
