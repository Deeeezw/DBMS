-- SHARD 5 — master2 items 401–500 (Pensil 2B → Guling Bayi)
CREATE TABLE IF NOT EXISTS barang (
    id_barang   INT PRIMARY KEY,
    nama_barang VARCHAR(100) NOT NULL,
    stok        INT NOT NULL DEFAULT 0,
    created_at  TIMESTAMP DEFAULT NOW()
);

INSERT INTO barang (id_barang, nama_barang, stok)
SELECT
  gs,
  (ARRAY[
    'Pensil 2B Faber','Pensil H Staedtler','Pensil Warna 24','Krayon 12 Warna','Oil Pastel 18',
    'Spidol Warna Snowman','Marker Permanent','Stabilo Highlighter','Tinta Isi Ulang','Whiteboard Marker',
    'Stop Kontak 4 Lubang','Kabel Roll 5m','Lampu LED 10W','Bohlam LED 7W','Saklar Tunggal',
    'Sekring 10A','Fitting Lampu','Adaptor 12V','Timer Listrik','Stabilizer Voltage',
    'Spatula Silikon','Sendok Kayu Masak','Kukusan Bambu','Peniris Minyak','Saringan Teh',
    'Cobek Mini Batu','Ulekan Kayu','Pisau Dapur 20cm','Talenan Kayu','Vegetable Peeler',
    'Toples Kaca Bulat','Toples Plastik Bening','Kotak Sepatu','Kotak Mainan','Keranjang Rotan',
    'Rak Buku Mini','Laci Plastik 3 Susun','Wadah Makanan Pyrex','Stoples Kedap','Kontainer Serbaguna',
    'Benang Jahit Putih','Jarum Jahit Set','Kancing Kemeja','Resleting 20cm','Peniti Safety',
    'Pita Satin','Meteran Jahit','Gunting Kain','Bidal Jari','Kapur Jahit',
    'Lilin Batang','Korek Api Gas','Baterai AA Alkaline','Baterai AAA Alkaline','Lampu Darurat LED',
    'Senter Mini','Obeng Plus Minus','Tang Kombinasi','Palu Besi','Meteran 5m',
    'Bingkai Foto 10x15','Cermin Oval Mini','Vas Bunga Keramik','Lilin Aromaterapi','Pot Tanaman Plastik',
    'Stiker Dinding','Keset Anti Slip','Gorden Mini Voile','Tirai Bambu','Wall Decal Bunga',
    'Sapu Ijuk','Serokan Plastik','Ember 10 Liter','Alat Pel Lipat','Sikat Lantai',
    'Sikat WC','Karet Wiper Lantai','Tempat Sampah Tertutup','Kantong Sampah Hitam','Sprayer Mini',
    'Skipping Rope','Resistance Band Set','Matras Yoga 6mm','Sarung Tangan Gym','Kacamata Renang',
    'Sarung Tinju','Pelindung Lutut','Pelindung Siku','Sepatu Slip On Olahraga','Kaos Kaki Olahraga',
    'Pampers Bayi S','Bedak Bayi Johnson','Sabun Bayi Cussons','Tisu Basah Bayi','Minyak Telon Lang',
    'Selimut Bayi Fleece','Kaus Kaki Bayi','Topi Bayi Rajut','Bantal Kepala Bayi','Guling Bayi'
  ])[gs - 400] AS nama_barang,
  ((gs * 17 + 37) % 491) + 10 AS stok
FROM generate_series(401, 500) AS gs
ON CONFLICT (id_barang) DO NOTHING;
