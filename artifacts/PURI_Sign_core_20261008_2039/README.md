# PURI-Sign core SOF — 8 Oktober 2026, 20:39 WIB

File: `PURI_Sign_core_5CSEBA6U23I7.sof` (6.690.356 byte).
Target chip: Cyclone V **5CSEBA6U23I7**.

Assembler Quartus 20.1 selesai dengan 0 error. File dibangkitkan ulang dari
netlist hasil fit yang berhasil; RTL/QSF/SDC telah dicocokkan dengan hash sumber
tervalidasi. Tidak dilakukan fit ulang. Fit awal memakai 50 MHz dan timing
kemudian diverifikasi ulang pada 25 MHz untuk netlist yang sama.

- Kebutuhan logika: 27.853 ALM; LAB terpakai: 3.971/4.191.
- Timing internal 25 MHz: PASS. Target 50 MHz: FAIL.
- Sumber clock 25 MHz harus disediakan oleh integrasi; SDC tidak membagi clock.
- Top-level masih shell **Avalon-MM**, tanpa penetapan pin board.
- **Belum siap diprogram langsung ke DE10-Nano.** Memerlukan top-level board,
  PLL/HPS clock, integrasi Avalon, pin assignment, dan constraint timing I/O.
- Belum diuji pada perangkat fisik.

Periksa `SHA256SUMS` dan `manifest.json` untuk integritas serta provenance.
