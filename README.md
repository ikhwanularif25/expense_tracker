# Expense Tracker Portfolio App 💰

Aplikasi manajemen keuangan pribadi yang dibangun dengan Flutter untuk mendemonstrasikan penerapan arsitektur modern dan clean code.

 
*(Ganti teks ini dengan screenshot aplikasi aslimu nanti)*

## ✨ Fitur Utama
* **Dashboard Ringkasan**: Melihat total saldo, pemasukan, dan pengeluaran bulan ini secara real-time.
* **Pencatatan Transaksi**: Tambah transaksi dengan mudah (Pemasukan/Pengeluaran), lengkap dengan kategori dan tanggal.
* **Laporan Visual**: Pie chart interaktif untuk melihat proporsi pengeluaran per kategori.
* **Database Lokal**: Semua data tersimpan aman di perangkat menggunakan **Drift (SQLite)**.
* **Dark Mode**: Tampilan antarmuka modern yang nyaman di mata.

## 🛠 Tech Stack
* **Framework**: Flutter (Dart)
* **State Management**: Riverpod (with Code Generation soon)
* **Local Database**: Drift (SQLite abstraction)
* **Navigation**: GoRouter (ShellRoute for nested navigation)
* **UI Components**: Fl_chart (for visualizing data), Google Fonts

## 📂 Struktur Proyek
Proyek ini menggunakan pendekatan **Feature-First Layered Architecture**:
lib/src/ ├── common_widgets/ # Widget yang dipakai ulang (Reusable UI) 
         ├── constants/ # Tema, warna, gaya teks 
         ├── features/ # Fitur utama aplikasi 
         │                                     ├── dashboard/ # UI ringkasan & home            
         │                                     ├── transactions/ # CRUD transaksi & repository 
         │                                     └── reports/ # Visualisasi chart          
         ├── routing/ # Konfigurasi navigasi (GoRouter) 
         └── services/ # Layanan global (Database Drift)

## 🚀 Cara Menjalankan
1.  Clone repositori ini.
2.  Jalankan `flutter pub get`.
3.  Jalankan `dart run build_runner build` untuk generate file database.
4.  Jalankan `flutter run`.