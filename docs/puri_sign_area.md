# PURI-Sign: penghematan area untuk DE10-Nano

PURI-Sign (Protected Utility for Reliable Identity) tetap memakai ECDSA P-256,
RFC 6979, HMAC-SHA-256, provisioning kunci, public-key derivation, lock, dan
zeroize. Nama modul `tinysign_*` dan register map dipertahankan agar host dan
testbench yang ada tetap kompatibel.

## Hasil Fitter pada 8 Oktober 2026

**Fitter berhasil pada Cyclone V `5CSEBA6U23I7`**, memakai Quartus Prime Lite
20.1.0 Build 711. Assembler juga berhasil menghasilkan `TinySign.sof` untuk
target tersebut.

| Metrik | Baseline gagal | Setelah sharing |
|---|---:|---:|
| Logic utilization / ALMs needed | 46.158 / 41.910 | 27.853 / 41.910 |
| ALMs used in final placement | 45.164 | 32.834 |
| LAB sebagian atau seluruhnya terpakai | 4.669 / 4.191 | 3.971 / 4.191 |
| Fitter | Gagal | Berhasil |

Metrik ALMs needed berkurang **18.305 ALM (39,66%)**. Angka 27.853 adalah
metrik *logic utilization* Quartus yang memperhitungkan estimasi dense packing;
ALM yang ditempati pada placement ini adalah 32.834. Jangan menyamakan kedua
metrik tersebut. LAB terpakai 95%, sehingga penambahan logika atau integrasi HPS
tetap perlu fit ulang. Angka LAB baseline tabel berasal dari laporan lama yang
disimpan; pesan error pada percobaan lain dapat memiliki angka berbeda.

Laporan sumber: [`TinySign.fit.summary`](../quartus/puri_sign/output_files/TinySign.fit.summary)
dan [`TinySign.fit.rpt`](../quartus/puri_sign/output_files/TinySign.fit.rpt).
Fitter mencatat 45.242 register, tanpa RAM block maupun DSP block.

### Clock dan batas hasil timing

Fit awal memakai constraint 50 MHz, tetapi timing setup **gagal** dengan slack
terburuk -5,006 ns dan Fmax internal 39,99 MHz. Keberhasilan full compilation
Quartus tidak berarti persyaratan timing terpenuhi.

Constraint proyek PURI-Sign sekarang memakai **25 MHz** (periode 40 ns).
Analisis ulang `quartus_sta` dijalankan terhadap placement/routing yang sama;
tidak ada perubahan RTL maupun fit ulang untuk pengukuran 25 MHz tersebut.
Hasil analisis ulang lulus untuk seluruh jalur internal yang dikonstrain pada
empat timing corner: worst setup slack +14,994 ns dan worst hold slack +0,113 ns.
Laporan 50 MHz disimpan di `reports/puri_sign/timing_50mhz.sta.*` agar tidak
hilang saat laporan timing diperbarui.

**SDC tidak membagi clock fisik.** Saat integrasi board, berikan clock core
25 MHz dari PLL/HPS; jangan langsung menghubungkan oscillator 50 MHz ke core
ini. Avalon dan core harus berada dalam domain clock yang sesuai, atau memakai
clock-crossing bridge. Pin serta delay I/O masih belum ditentukan: keberhasilan
timing internal tidak menggantikan penutupan timing sistem board lengkap.

## Perubahan arsitektur

`tinysign_core.v` memiliki satu `u_shared_scalar`, satu `u_shared_inverse`, dan
satu `u_shared_multiply`. `key_manager` dan `ecdsa_signer` menjadi pemakai
datapath tersebut dengan parameter `SHARED_ENGINES=1`. Default parameter `0`
mempertahankan operasi standalone untuk pengujian unit.

| Mesin | Sebelum | Sesudah, pada top-level core |
|---|---:|---:|
| `scalar_mult` / `point_ops` | 2 / 2 | 1 / 1 |
| `mod_inv` | 2 | 1 |
| `mod_mul`, seluruh hierarki | 8 | 4 |
| `rfc6979` | 1 | 1 |
| `hmac_sha256` | 1 | 1 |
| `sha256_hash` / `sha256_compress` | 1 / 1 | 1 / 1 |

Empat multiplier tersisa terdiri dari satu di `point_ops`, dua di `mod_inv`
(square dan product paralel), dan satu untuk konversi affine/perhitungan
signature. Refaktor ini bukan satu multiplier untuk seluruh chip.

FSM perintah yang sudah ada menentukan pemilik selama seluruh transaksi:
`ST_PROVISION_WAIT` untuk key manager, `ST_SIGN_WAIT` untuk signer. Operand dan
modulus dipilih sesuai pemilik; sinyal selesai/error hanya diteruskan ke pemilik.
Perintah lain saat BUSY ditolak, kecuali ZEROIZE yang membatalkan transaksi dan
mereset kedua controller serta seluruh mesin bersama. Kunci dan nonce tetap
berada di jalur internal; tidak ada register bus baru untuk membaca keduanya.

Provisioning memakai modulus p. Signer bergantian memakai p untuk konversi
koordinat dan n untuk persamaan signature. Jadwal scalar tetap 256 bit dengan
slot 14.000 siklus. Karena core sebelumnya sudah melarang provisioning dan
signing serentak, sharing ini tidak menambah antrean pada antarmuka host.

## Build dan pengujian

Sumber aktif adalah file `.v` (Verilog-2001); file `.sv` historis tidak masuk
proyek Quartus maupun skrip Icarus. Salinan RTL sebelum perubahan dan laporan
Fitter baseline disimpan di `.refactor_backup/shared_engines_20261008/`.

```sh
python3 -m unittest discover -s tests -v
bash scripts/run_rtl_tests.sh tb_tinysign_core tb_shared_engines \
    tb_key_manager tb_ecdsa_signer tb_tinysign_de10nano tb_hmac tb_rfc6979
cd quartus/puri_sign
/home/mateus/intelFPGA_lite/20.1/quartus/bin/quartus_sh --flow compile TinySign
```

`tb_shared_engines` memeriksa public key dan signature RFC 6979 melalui core,
signature berulang beserta kesamaan latensinya, zeroize saat scalar aktif dan
saat inversi nonce modulo n, penolakan perintah tumpang tindih, serta pemulihan
provisioning setelah pembatalan. `tb_tinysign_core` memeriksa vektor kunci d=1.

Pengujian terarah pada 8 Oktober 2026 lulus: 9 tes Python, HMAC/RFC6979 dan
integrasi d=1 dengan Icarus Verilog 12.0, serta `tb_shared_engines`,
`tb_key_manager`, `tb_ecdsa_signer`, dan shell Avalon-MM dengan Verilator 5.020.
Log, pemeriksaan jumlah instance, dan SHA-256 sumber tersedia di
[`reports/puri_sign/`](../reports/puri_sign/). Ini regresi terarah, bukan
pengulangan seluruh suite aritmetika maupun pengujian board.

Latensi yang terukur adalah 7.303.704 siklus untuk provisioning standalone,
7.437.838 siklus untuk signing standalone, dan 7.437.840 siklus untuk signing
melalui register core. Pada clock **25 MHz**, signing melalui core membutuhkan
297,5136 ms (sekitar 3,36 signature/detik tanpa overhead host). Ini konversi
dari hasil simulasi, bukan pengukuran perangkat fisik. Angka 148,7568 ms pada
50 MHz hanya perhitungan teoretis dan tidak memenuhi timing build ini.

Untuk simulator Verilator terpasang, regresi tambahan dapat direproduksi dengan:

```sh
verilator --binary --timing -Wno-fatal -j 2 --top-module tb_shared_engines \
    --Mdir /tmp/puri_sign_shared_sim rtl/*/*.v tb/tb_shared_engines.v
/tmp/puri_sign_shared_sim/Vtb_shared_engines
```

Proyek build terpisah `quartus/puri_sign/TinySign.qpf` menargetkan
`5CSEBA6U23I7`, sehingga laporan dan bitstream baseline tidak tertimpa. Top-level
masih shell Avalon-MM, belum sistem board dengan HPS/Platform Designer dan pin
assignment DE10-Nano. Keberhasilan Fitter membuktikan kapasitas implementasi
shell; pemrograman board memerlukan integrasi dan constraint I/O yang benar.

## Batas klaim keamanan

Perubahan ini mengurangi duplikasi hardware. Jadwal scalar tetap dipertahankan,
tetapi tidak membuktikan ketahanan terhadap power/EM analysis, fault injection,
atau akses fisik. Key storage tetap volatil. Input dokumen di-hash oleh host;
HMAC-SHA-256 internal dipertahankan untuk nonce deterministik.

## Pemeriksaan opsi yang sudah tersedia

[ANSSI IPECC](https://github.com/ANSSI-FR/IPECC) menyediakan akselerator ECC VHDL
beserta integrasi perangkat lunak; [Secworks SHA-256](https://github.com/secworks/sha256)
menyediakan hash core iteratif. Keduanya berguna sebagai referensi, tetapi
migrasi ke IP tersebut tidak diperlukan untuk menghilangkan duplikasi konkret
pada RTL ini. Tidak ada kode pihak ketiga yang disalin dalam refaktor ini.
