## 🌐 Internet of Things (IoT) – Monitoring Sensor Suhu & Kelembapan (Kelompok 14)

# Nama Anggota :
1. Muhammad Fayruz Zamzamy (2042231032)
2. Lu'lu' Rusyida Hamudyah (2042231058)
   
Proyek ini merupakan implementasi sistem Internet of Things (IoT) berbasis ESP32-S3 dengan sensor DS18B20 untuk suhu dan sensor kelembapan digital yang terhubung ke platform ThingsBoard.
Sistem ini juga dilengkapi dengan fitur OTA (Over-The-Air) Update, sehingga perangkat dapat diperbarui firmware-nya secara jarak jauh tanpa perlu koneksi fisik.

Visualisasi data dilakukan langsung melalui dashboard ThingsBoard, menampilkan grafik tren suhu dan kelembapan secara real-time, serta mendukung penyimpanan dan analisis data jangka panjang


# 📡 Fitur Utama

- Pembacaan suhu menggunakan sensor DS18B20
- Pengiriman data telemetri ke ThingsBoard via MQTT/HTTP
- Visualisasi data suhu dan kelembapan dalam bentuk grafik interaktif
- Sistem OTA Update (pembaruan firmware jarak jauh)
- Integrasi yang stabil dan sinkron antara perangkat dan server

# ⚙️ Cara Menjalankan Program

Ikuti langkah-langkah berikut untuk menjalankan proyek ini di perangkatmu:
1. Download semua file dari repositori ini
2. Gabungkan semua file ke dalam satu folder
3. Buka folder tersebut, lalu klik kanan dan pilih “Open in Terminal”
4. Jalankan perintah berikut di terminal: ./export-esp.sh
5. Tunggu beberapa saat, perangkat akan mulai membaca data dari sensor dan mengirimkannya ke ThingsBoard.

# 🧠 Kesimpulan

Proyek ini berhasil menunjukkan integrasi penuh antara sensor – mikrokontroler – platform cloud dengan performa yang stabil.
Sistem IoT ini dapat digunakan sebagai dasar pengembangan untuk aplikasi monitoring lingkungan, industri, atau penelitian akademik.

# 💡 Saran Pengembangan

- Tambahkan sensor lain seperti tekanan udara atau kualitas udara
- Gunakan notifikasi real-time melalui Telegram atau Email
- Tambahkan validasi integritas firmware OTA (misalnya SHA256)
- Integrasikan dengan InfluxDB + Grafana untuk visualisasi yang lebih kaya
- Gunakan MQTT QoS 1/2 agar lebih tahan terhadap gangguan jaringan
