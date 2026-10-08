# Diagram alur sistem PURI-Sign

Buka **PURI_Sign_Alur_Sistem.drawio** melalui menu **File → Open From → Device** di draw.io / diagrams.net, atau buka langsung dengan aplikasi draw.io Desktop. Pilih tab halaman di bagian bawah editor. Semua blok, tulisan, keputusan, dan konektor merupakan objek native yang dapat diedit; bukan gambar yang ditempel ke canvas.

## Isi lima halaman

1. **Alur utama** — host menyiapkan key/digest, provisioning, lock, signing, dan pembacaan hasil.
2. **Provisioning** — validasi key, Q = dG, konversi affine, penyimpanan key, dan lock.
3. **Signing ECDSA** — RFC6979/HMAC-SHA-256, kG, pembentukan r dan s, serta jalur error.
4. **Engine bersama** — dua controller menggunakan scalar, inverse, dan multiplier bersama sesuai owner FSM.
5. **ZEROIZE dan error** — pembatalan operasi, pembersihan state, penolakan akses, dan status.

PNG dan SVG bernomor merupakan preview tiap halaman, dirender offline dari data geometri yang sama dengan file draw.io. Preview bukan screenshot aplikasi draw.io; editor dapat menyesuaikan font atau routing konektor. File XML diperiksa: lima halaman, ID unik, dan semua endpoint konektor valid.

Diagram diturunkan dari `rtl/security/tinysign_core.v`, `rtl/security/key_manager.v`, dan `rtl/ecdsa/ecdsa_signer.v`. Hash sumber dicatat pada `manifest.json`. Tidak ada perubahan RTL atau SOF untuk membuat diagram ini.

## Batas dan interpretasi

- Core menerima digest 256 bit dari host; diagram tidak menempatkan hashing file dokumen pada input core. HMAC-SHA-256 dipakai untuk nonce RFC6979.
- Input private key berasal dari host. Pembacaan register private key mengembalikan nol; ini tidak menyatakan ketahanan terhadap semua serangan fisik.
- Penulisan input/perintah dilakukan saat core idle, kecuali ZEROIZE yang dapat membatalkan operasi aktif. Read status tetap tersedia saat busy.
- Jalur utama pada halaman 01 menunjukkan urutan sukses. Host memeriksa error setelah setiap operasi. LOCK tidak perlu diulang untuk setiap signature dengan key yang sama.
- Status `sign_valid` dan register signature core dapat menyimpan hasil lama ketika transaksi baru berlangsung atau gagal. Host memeriksa `busy`, `done_latch`, dan `error_latch` untuk transaksi baru.
- Durasi provisioning 292,14824 ms dan signing 297,51360 ms berasal dari trace RTL pada clock simulasi 25 MHz. Bukan pengukuran board atau bukti Fmax.
- Total multiplier di seluruh hierarki adalah empat: satu pada level core, satu di point engine, dan dua di inverse engine. Blok shared multiply pada halaman 04 hanya mewakili multiplier level core.
- Persentase 66% pada laporan proyek merujuk pada ALMs needed; LAB occupied adalah 3.971/4.191 (sekitar 95%). Diagram tidak mengubah atau mengukur ulang area.

## Membuat ulang

Dari root proyek, dengan Python, NumPy, dan Matplotlib tersedia:

```sh
python3 scripts/create_puri_drawio.py
```

Generator membuat file `.drawio`, lima PNG, lima SVG, dan manifest. ZIP adalah paket distribusi dari file-file tersebut beserta README dan generator.
