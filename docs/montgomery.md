# Montgomery dan migrasi Verilog-2001

## Ruang lingkup

TinySign sekarang menggunakan file `.v` untuk semua RTL dan testbench. Perubahan mencakup pemanggilan task tanpa argumen, penggantian `$clog2` dengan fungsi konstanta Verilog-2001, dan deklarasi `hmac_digest` sebagai `wire` karena digerakkan keluaran submodul. Testbench memakai `$display` dan `$stop` untuk kegagalan; script menjalankan `vvp -N` agar kegagalan menghasilkan exit code nonzero. Konfigurasi Quartus memakai `VERILOG_FILE`.

Montgomery ladder di `scalar_mult.v` sudah ada sebelumnya: itu adalah jadwal penjumlahan/penggandaan titik untuk menghitung `kG`. Penambahan saat ini adalah **Montgomery modular multiplication**, yang bekerja di tingkat perkalian bilangan modulo `p` atau `n`. Keduanya memiliki fungsi berbeda.

## Dua antarmuka aritmetika

| Modul | Hasil | Latensi setelah request diterima |
|---|---|---|
| `montgomery_mul` | `a*b*R^-1 mod m` | `WIDTH+1` clock |
| `mod_mul` | `a*b mod m` | `2*WIDTH+3` clock |

`R=2^WIDTH`. Kedua modul menerima `WIDTH>=2`, `3<=m<R`, `m` ganjil, dan `0<=a,b<m`. Modulus komposit ganjil boleh digunakan untuk perkalian; inversi Fermat dalam `mod_inv` hanya benar untuk modulus prima dan input bukan nol. Pemeriksaan primalitas tidak dilakukan oleh RTL. Jalur ECC/RFC 6979 tetap khusus P-256 dengan lebar 256 bit.

Mesin mentah menggunakan radix 2. Setiap putaran menambahkan operand jika bit pengali bernilai satu, menambahkan modulus jika hasil sementara ganjil, lalu menggeser satu bit ke kanan. Setelah `WIDTH` putaran dilakukan satu pengurangan bersyarat. Akumulator memiliki `WIDTH+1` bit dan penjumlahan sebelum pergeseran memiliki `WIDTH+2` bit agar carry tidak hilang. Dasar matematikanya adalah Algorithm 14.36 dalam [Handbook of Applied Cryptography, bab 14](https://cacr.uwaterloo.ca/hac/about/chap14.pdf), disesuaikan ke radix 2.

`mod_mul` terlebih dahulu menghitung `bR mod m` dengan `WIDTH` kali penggandaan modular, kemudian memanggil `Mont(a,bR)`. Ini mempertahankan representasi biasa pada seluruh antarmuka ECC dan ECDSA. Tidak ada tabel `R^2`, pembagi, atau pengali penuh 256×256 pada mesin baru. Jangan mengganti instansiasi `mod_mul` langsung dengan `montgomery_mul`: faktor `R^-1` akan mengubah hasil.

Modulus genap kini ditolak oleh `mod_mul` dan `mod_inv`. Jalur TinySign memakai `p` dan `n` yang ganjil sehingga antarmuka host, format tanda tangan, dan nilai kunci publik tidak berubah.

## Handshake dan reset

- Request diterima pada rising edge saat `start=1` dan `busy=0`; input disalin ke register internal.
- `busy` tetap aktif sampai hasil siap. Pulsa `start` selama operasi diabaikan.
- `done` menandai hasil valid selama satu clock; `result` tetap tersimpan sampai hasil berikutnya atau reset.
- Input tidak valid menghasilkan pulsa `error` satu clock, tanpa `busy` atau `done`. Nilai `result` sebelumnya tidak berubah.
- `rst_n=0` membatalkan operasi dan menghapus register mesin baru, termasuk hasil. Jalur zeroize yang sudah ada pada signer/key manager meneruskan reset ini ke aritmetika.
- `start` adalah request per clock, bukan deteksi tepi: jika terus ditahan tinggi hingga modul kembali idle, request berikutnya akan diterima.

## Dampak latensi

Pada 256 bit, mesin mentah membutuhkan 257 clock. Wrapper normal membutuhkan 515 clock, dibanding 256 clock pada multiplier shift/add sebelumnya. Slot tetap untuk setiap operasi titik dinaikkan dari 7.000 ke 14.000 clock di scalar multiplier, signer, key manager, core, dan wrapper DE10-Nano. Ini juga menampung kasus penjumlahan titik sama yang berlanjut ke penggandaan.

Implementasi ini memudahkan integrasi dan verifikasi, tetapi konversi setiap perkalian menambah waktu. Optimasi berikutnya dapat menyimpan operand dalam domain Montgomery selama rangkaian operasi, dengan konversi hanya pada batas modul. Itu memerlukan perubahan konsisten pada koordinat, konstanta, inversi, dan pengujiannya. Penghematan area, Fmax, dan ketahanan side-channel tidak dapat disimpulkan dari pemilihan algoritma atau bahasa RTL saja.

## Pengujian

```sh
python3 -m unittest discover -s tests -v
bash scripts/run_rtl_tests.sh
```

`gen_montgomery_vectors.py` menggunakan aritmetika integer Python dan `pow(R,-1,m)` sebagai oracle independen. Testbench memeriksa mesin mentah dan wrapper secara bersamaan: seluruh kombinasi operand untuk semua modulus ganjil pada lebar 2 dan 5 bit; batas carry dan operand acak pada 8, 17, 256, dan 513 bit; modulus P-256 `p` dan `n`; pulsa status; latensi tepat; perubahan input/start saat sibuk; input tidak valid; dan reset di kedua tahap wrapper. Total 7.322 vektor menghasilkan 14.644 perbandingan hasil.

Script menerima nama testbench sebagai argumen untuk menjalankan subset. Instalasi Icarus nonstandar dapat memakai variabel `IVERILOG`, `VVP`, dan opsional `IVERILOG_BASE` (direktori backend `ivl`). Hasil vektor dan simulator ditulis ke `sim/iverilog/build/`.
