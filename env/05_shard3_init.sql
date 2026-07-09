-- SHARD 3 — master1 items 201–300 (Sambal → Jamu Sehat Wanita)
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
    'Sambal ABC','Sambal Indofood','Sambal Terasi','Sambal Bajak','Sambal Matah',
    'Sambal Dabu-Dabu','Sambal Ijo','Sambal Roa','Sambal Bawang','Sambal Geprek',
    'Agar-Agar Cokelat','Agar-Agar Vanilla','Agar-Agar Strawberry','Agar-Agar Pandan','Agar-Agar Mangga',
    'Nutrijell Jeruk','Nutrijell Leci','Nutrijell Melon','Pudding Susu','Cincau Hitam',
    'Mayones Hellmanns','Mayones Kewpie','Mustard French','Saus Inggris','Kecap Asin',
    'Saus Ikan','Saus Tiram','Cuka Apel','Saus BBQ Manis','Saus Tartar',
    'Royco Ayam','Royco Sapi','Masako Ayam','Masako Sapi','Penyedap Totole',
    'Maggi Masala','Knorr Blok Ayam','Kaldu Ayam Instan','Kaldu Udang Instan','Krim Sup Instan',
    'Vitamin C Redoxon','Vitamin D3','Multivitamin Centrum','Minyak Ikan Omega','Kalsium Tablet',
    'Zinc Tablet','Vitamin B Kompleks','Omega 3 Kapsul','Probiotik Lacto','Suplemen Imun',
    'Pocari Sweat','Mizone Lemon','Gatorade Grape','Hydro Coco','Revive Isotonic',
    'Aquarius','100 Plus','Isomax','Electrolyte Drink','Air Kelapa Coco',
    'Chitato Sapi','Pringles Original','Qtela Tempe','Chiki Balls','Taro Sapi',
    'Potabee','Cheetos','Lays BBQ','Doritos Nacho','Twisties Keju',
    'Merica Bubuk','Cabai Bubuk','Bawang Putih Bubuk','Bawang Merah Kering','Kayu Manis',
    'Cengkeh','Kapulaga','Pala Bubuk','Jintan','Ketumbar Bubuk',
    'Susu Formula Aptamil','Bubur Bayi Gerber','Biskuit Bayi Milna','Jus Buah Bayi','Minyak Bayi Cussons',
    'Bedak Bayi Johnson','Vitamin Bayi Morinaga','Makanan MPASI Heinz','Teh Bayi Bebe','Puree Buah Bayi',
    'Jamu Temulawak','Jamu Kunyit Asam','Jamu Beras Kencur','Jamu Jahe Merah','Jamu Sinom',
    'Jamu Uyah Asem','Jamu Pahitan','Jamu Cabe Puyang','Tolak Angin Cair','Jamu Sehat Wanita'
  ])[gs - 200] AS nama_barang,
  ((gs * 17 + 37) % 491) + 10 AS stok
FROM generate_series(201, 300) AS gs
ON CONFLICT (id_barang) DO NOTHING;
