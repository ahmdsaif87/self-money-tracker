# Self Money Tracker

Aplikasi pencatat keuangan pribadi berbasis Flutter. Kelola akun, transaksi, kategori, dan dapatkan analisis keuangan lewat asisten AI.

## Fitur

- **Dashboard** — total saldo, pemasukan/pengeluaran bulan ini, daftar akun & transaksi terbaru
- **Transaksi** — tambah/ubah/hapus; tipe Pengeluaran, Pemasukan, dan Transfer antar akun; cari & filter; catatan + tanggal
- **Laporan** — ringkasan bulanan, selisih, breakdown per kategori
- **Asisten AI (Gemini)** — tanya saldo, riwayat, analisis kategori, rekomendasi budget/rencana tabungan, dan buat transaksi langsung dari chat
  - Kategori transaksi dari chat dicocokkan otomatis dari isi pesan (mis. "gaji" → Gaji, "freelance" → Pekerjaan Lepas); fallback ke "Lainnya"
  - Antrean offline: pertanyaan diproses otomatis saat koneksi pulih
- **Akun & Kategori** — multi-akun dengan warna/ikon, kategori sistem + kustom
- **Pengaturan** — profil, tema gelap/terang, backup & export/import data, koneksi API Gemini
- **Data lokal** — tersimpan di SQLite (perangkat), tidak ada cloud

## Persyaratan

- Flutter 3.41+ (Dart SDK ^3.11)
- Android / Linux desktop (web belum didukung)

## Menjalankan

```sh
flutter pub get
flutter run
```

## API Key Gemini (opsional, untuk Asisten AI)

Key diambil dari salah satu sumber, urutan prioritas:

1. `--dart-define=GEMINI_API_KEY=...`
2. File `.env` di root proyek:

```sh
GEMINI_API_KEY=your_key_here
```

3. Secure storage (`flutter_secure_storage`), atur via **Pengaturan → Asisten AI**

`.env` jangan pernah di-commit (sudah masuk `.gitignore`).

## Struktur Proyek

```
lib/
├── components/       # Widget reusable (nav bar, sheet, ikon, dll.)
├── db/               # SQLite, skema & migrasi
├── models/           # Model data (akun, kategori, transaksi, chat)
├── screens/          # Halaman (dashboard, transaksi, laporan, chat AI, pengaturan)
├── services/         # Gemini, tools AI, export/import, backup
├── stores/           # State (ChangeNotifier)
├── theme/            # Tema & warna
└── utils/            # Format angka, tanggal
```

Arsitektur meniru struktur aplikasi React Native versi sebelumnya (folders `services/stores`), memudahkan migrasi balik bila diperlukan.

## Lisensi

Privasi & penggunaan internal — data pengguna sepenuhnya lokal di perangkat.