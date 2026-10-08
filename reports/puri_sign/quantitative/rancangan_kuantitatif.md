# Rancangan kuantitatif PURI-Sign

Tanggal analisis: 8 Oktober 2026. Target: Cyclone V 5CSEBA6U23I7 / DE10-Nano.

PURI-Sign merupakan core penandatanganan digest ECDSA P-256 dengan provisioning
kunci, perhitungan public key, lock, RFC6979/HMAC-SHA-256, dan zeroize. Host
mengirim digest 256 bit; core menyimpan kunci secara internal dan mengembalikan
signature `(r,s)`. Integrasi board memerlukan clock core 25 MHz dan antarmuka
Avalon-MM pada domain clock yang sesuai.

## 1. Batas perbandingan

Baseline adalah arsitektur dengan mesin ECC ganda yang gagal fit pada target.
Kandidat adalah arsitektur mesin bersama yang berhasil fit. Keduanya memakai
algoritma dan lebar operand 256 bit yang sama. Perbandingan latensi memakai
jumlah siklus simulasi pada frekuensi yang disamakan, bukan benchmark dua
bitstream yang berjalan di board. Belum ada pengukuran board fisik.

## 2. Kebutuhan sumber daya

| Metrik | Sebelum | Sesudah | Perubahan |
|---|---:|---:|---:|
| ALMs needed / logic utilization Quartus | 46.158 | 27.853 | turun 39,66% |
| ALM pada placement fisik yang dilaporkan | 45.164 | 32.834 | turun 27,30% |
| Register setelah Fitter | 67.887 | 45.242 | turun 33,36% |
| Scalar multiplier / point engine | 2 | 1 | turun 50% |
| Modular inverse | 2 | 1 | turun 50% |
| Modular multiplier seluruh hierarki | 8 | 4 | turun 50% |
| RFC6979 / HMAC-SHA256 | 1 / 1 | 1 / 1 | tetap |

Kandidat menempati 3.971 dari 4.191 LAB (94,75%). Baseline report mencatat 4.669
LAB dan status gagal; angka pada run lain dapat berbeda. Pengurangan ALMs needed
sebanyak 18.305 ALM dihitung dengan `(46.158 - 27.853) / 46.158 × 100%`.

ALMs needed mencakup perhitungan dense packing Quartus, sehingga berbeda dari
jumlah ALM yang benar-benar ditempati pada placement tertentu. **Die FPGA dan
ukuran kemasan tidak mengecil**. Istilah yang tepat untuk proposal adalah
“kebutuhan area logika berkurang 39,66%”, bukan “luas chip berkurang 39,66%”.
Luas ASIC dalam mm² belum dapat dihitung tanpa technology library dan flow ASIC.

## 3. Latensi, throughput, dan efisiensi area

RTL baseline dijalankan ulang dari backup menggunakan Verilator 5.020; signature
serta zeroize lulus. Jumlah siklus signing baseline dan kandidat sama pada vektor
uji: **7.437.840 siklus** melalui register core.

| Metrik, clock dinormalisasi 25 MHz | Sebelum | Sesudah |
|---|---:|---:|
| Siklus signing | 7.437.840 | 7.437.840 |
| Latensi signing | 297,5136 ms | 297,5136 ms |
| Throughput ideal, tanpa overhead host | 3,361 signature/s | 3,361 signature/s |
| Speedup | 1,00× | 1,00× — kenaikan 0% |
| Efisiensi throughput per ALMs needed, indeks baseline = 1 | 1,00 | 1,657 — naik 65,72% |

Rumus: `latensi = siklus / frekuensi`, `throughput = frekuensi / siklus`, dan
`efisiensi area = throughput / ALMs needed`. Peningkatan 65,72% adalah metrik
normalisasi throughput terhadap area, bukan percepatan waktu komputasi.
Baseline tetap tidak dapat dioperasikan pada DE10-Nano karena gagal fit.

Sharing tidak menambah waktu tunggu transaksi normal karena controller lama
sudah menjalankan provisioning dan signing secara bergantian. Core tidak
mendukung provisioning dan signing serentak dalam kedua arsitektur tersebut.

Timing kandidat: 25 MHz lulus pada jalur internal yang dikonstrain, worst setup
slack +14,994 ns; target 50 MHz gagal dengan -5,006 ns. Fmax internal yang
dilaporkan adalah 39,99 MHz. Nilai Fmax dari laporan lama yang berbeda device,
corner suhu, atau versi RTL tidak boleh dipakai sebagai baseline speedup.

Menghitung 148,7568 ms pada 50 MHz hanya skenario teoretis. Dibanding angka itu,
25 MHz menghasilkan latensi 2× dan throughput 50% lebih rendah; hal ini bukan
regresi terhadap baseline DE10-Nano yang sudah berfungsi, karena baseline
tersebut tidak pernah berhasil fit.

## 4. Daya dan energi

Power Analyzer telah dijalankan pada netlist hasil fit, dengan clock **25 MHz**.
Hasil ini adalah **estimasi awal dengan confidence Low**, bukan pengukuran rail
FPGA, bukan pengukuran input daya board, dan bukan profil aktivitas signing.

| Komponen estimasi thermal power | Daya |
|---|---:|
| Core dynamic | 150,04 mW |
| Core static | 413,52 mW |
| I/O | 15,22 mW |
| Total menurut Power Analyzer | **578,77 mW** |

Jumlah komponen yang ditampilkan berbeda 0,01 mW dari total akibat pembulatan.
Asumsi: model device Typical, VCC 1,10 V, ambient 25 °C, temperatur junction
terhitung otomatis 28,6 °C, default input toggle 12,5%, vectorless estimation
aktif, dan **0% aktivitas berasal dari VCD/SAF**. HPS aktif tidak dimodelkan,
board thermal model belum ada, dan pin/load I/O masih mengikuti shell. Nilai
ini bukan total konsumsi DE10-Nano beserta HPS, DDR, regulator, dan periferalnya.
Power Analyzer juga memperingatkan bahwa sebagian node tidak memiliki clock
domain yang valid.

Tidak ada laporan daya baseline yang setara. Karena itu **penghematan daya
sebelum–sesudah dalam persen atau mW belum dapat ditentukan**. Menyebut “hemat
39,66% daya” berdasarkan pengurangan ALM saja tidak didukung hasil ini.

Run dapat direproduksi dari `quartus/puri_sign` dengan:

```sh
quartus_pow TinySign -c TinySign --no_input_file \
    --default_input_io_toggle_rate=12.5% --use_vectorless_estimation=on \
    --write_settings_files=off
```

Bukti: [ringkasan Power Analyzer](power_vectorless_25mhz.summary) dan
[laporan lengkap beserta asumsi/confidence](power_vectorless_25mhz.rpt).

Pengurangan ALM tidak otomatis sama dengan pengurangan daya. Daya dinamis
bergantung pada aktivitas switching, kapasitansi efektif, tegangan, dan clock:
`P_dynamic ∝ activity × C × V² × f`. Dalam desain awal, sebagian mesin duplikat
bisa berada dalam keadaan idle. Sharing juga menambahkan mux dan mengubah
routing. Daya statis die FPGA tidak turun sebanding dengan jumlah ALM terpakai.
Lihat [model daya FPGA Intel/Altera](https://cdrdv2-public.intel.com/650020/wp-01044.pdf).

Energi per signature adalah `E = integral P(t) dt`; pendekatan daya rata-rata
konstan memberi `E_mJ = P_mW × 0,2975136 s`. Contoh perhitungan, bukan pengukuran:
setiap 100 mW daya rata-rata selama signing setara 29,75136 mJ/signature.
Jika rata-rata daya saat signing benar-benar sama dengan angka model
578,77 mW, perkalian sederhana memberi **172.19 mJ/signature**.
Ini nilai bersyarat, belum merupakan estimasi energi workload yang tervalidasi;
Power Analyzer belum diberi waveform signing.
Untuk energi tambahan operasi, gunakan integral `(P_sign(t) - P_idle)` pada
kondisi idle pembanding yang sama, dan sebutkan bahwa daya statis tidak disertakan.

### Skenario target optimasi daya berikutnya — bukan hasil sebelum–sesudah

Dengan model saat ini, core static menyumbang sekitar 71,45% dari total.
Sebagai analisis sensitivitas, bila daya dinamis core dapat dikurangi pada
clock dan workload yang sama, sementara statis dan I/O tetap:

| Asumsi penurunan dynamic core di masa depan | Hemat daya | Total model baru | Penurunan total |
|---|---:|---:|---:|
| 20% | 30,01 mW | 548,76 mW | 5,18% |
| 40% | 60,02 mW | 518,75 mW | 10,37% |

Tabel ini membantu menetapkan target penelitian; belum ada implementasi atau
pengukuran yang membuktikan penghematan tersebut. Misalnya, penghematan clock
lokal atau perbaikan aktivitas internal perlu dievaluasi lewat waveform dan
Power Analyzer. Efek tambahan routing dan perubahan suhu juga harus dihitung.

## 5. Cara memperoleh klaim penghematan daya yang dapat dipertanggungjawabkan

1. Bandingkan dua desain pada device, tegangan, clock, suhu, beban I/O, dan
   workload yang sama. Karena baseline gagal fit di DE10-Nano, gunakan device
   lebih besar yang sama untuk kedua desain saat membandingkan arsitektur,
   atau nyatakan baseline sebagai estimasi awal tanpa klaim persen terukur.
2. Siapkan aktivitas simulasi representatif: provisioning, signing berulang,
   dan idle. Gunakan VCD/SAF yang cocok dengan hierarki implementasi, lalu
   periksa coverage dan confidence Power Analyzer.
3. Pisahkan daya dinamis core, statis, I/O, serta daya HPS/DDR/regulator board.
   Laporkan batas pengukuran: rail FPGA atau input board.
4. Pada board, ukur idle dan signing dengan kondisi HPS/software identik;
   integrasikan daya selama transaksi untuk mendapatkan mJ/signature.
5. Hitung `penghematan = (P_lama - P_baru) / P_lama × 100%` dan
   `selisih_mW = P_lama - P_baru`. Jangan mengisi P_lama dengan perkiraan
   yang diturunkan hanya dari rasio ALM.

Intel menjelaskan bahwa vectorless estimation memakai metode probabilistik;
aktivitas dari simulasi merupakan sumber bukti yang berbeda. Lihat
[Power Analyzer Confidence Metric](https://www.intel.com.tw/content/www/tw/zh/programmable/quartushelp/22.1/mapIdTopics/lwu1527718714470.htm).

## Sumber hasil proyek

- [Laporan ringkas implementasi](../results.md)
- [Baseline Fitter](../../../.refactor_backup/shared_engines_20261008/baseline.fit.rpt)
- [Fitter kandidat](../../../quartus/puri_sign/output_files/TinySign.fit.rpt)
- [Simulasi baseline](baseline_cycles.log)
- [Simulasi kandidat](../verilator_shared.log)
- [Data numerik dan hash bukti](metrics.json)

## Kalimat yang dapat dipakai dalam proposal

> PURI-Sign menerapkan pemakaian mesin ECC bersama untuk mengurangi kebutuhan
> logika dari 46.158 menjadi 27.853 ALM (39,66%) dan jumlah register sebesar
> 33,36%, sehingga core ECDSA P-256 berhasil diimplementasikan pada
> Cyclone V 5CSEBA6U23I7. Jumlah siklus signing tetap 7.437.840 siklus,
> setara 297,51 ms atau 3,36 signature/detik pada clock 25 MHz tanpa overhead
> host. Efisiensi throughput terhadap kebutuhan ALM meningkat 65,72%.
> Power Analyzer memberikan estimasi thermal power awal 578,77 mW dengan
> confidence rendah; persentase penghematan daya dan energi operasi perlu
> divalidasi menggunakan aktivitas representatif dan pengukuran perangkat.

## Proposal PERURI

Angka pada rancangan ini dirangkum pada [Proposal PERURI PURI-Sign](../../../artifacts/proposal_peruri_20261008/Proposal_PERURI_PURI_Sign_final.docx). Proposal memuat resource FPGA, latensi dan throughput, estimasi Power Analyzer, batas timing, serta timing diagram RTL; rincian metodologi dan bukti tetap berada pada laporan ini.
