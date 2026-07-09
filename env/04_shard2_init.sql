-- SHARD 2 — master1 items 101–200 (Susu → Kornet Premium)
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
    'Susu Sapi','Susu UHT','Susu Full Cream','Susu Kedelai','Susu Kambing',
    'Susu Almond','Susu Oat','Susu Cokelat','Susu Bubuk','Susu Skim',
    'Kerupuk Udang','Kerupuk Bawang','Kerupuk Ikan','Kerupuk Kulit','Kerupuk Melarat',
    'Kerupuk Singkong','Kerupuk Opak','Emping Melinjo','Peyek Kacang','Rempeyek',
    'Coca Cola','Pepsi','Sprite','Fanta Merah','Mountain Dew',
    '7Up','Mirinda','Big Cola','RC Cola','Schweppes',
    'Aqua 600ml','Club 600ml','Vit 600ml','Ades 600ml','Le Minerale',
    'Prima','Cleo','Oasis','Nestle Pure Life','Total',
    'Kecap Manis','Saus Tomat','Saus Sambal','Terasi','Tauco',
    'Petis','Kari Bubuk','Kunyit Bubuk','Jahe Bubuk','Ketumbar',
    'Roti Tawar','Roti Gandum','Roti Kupas','Roti Sobek','Roti Manis',
    'Croissant','Roti Pisang','Donat','Brioche','Baguette',
    'Biskuit Oreo','Roma Kelapa','Marie Regal','Khong Guan','Jacobs Cream Cracker',
    'Monde Butter','Tango Wafer','Wafer Abon','Cracker Keju','Biskuat',
    'Cokelat Batang','Cokelat Bubuk','Cokelat Putih','Ferrero Rocher','Kit Kat',
    'Snickers','Toblerone','MnM','Cadbury','Silver Queen',
    'Sarden ABC','Sarden Maya','Sarden Botan','Sarden 555','Sarden Pedas',
    'Sarden Bumbu Tomat','Sarden Asam Manis','Sarden Cabai','Sarden Kecap','Sarden Mustard',
    'Kornet Pronas','Kornet Maling','Kornet Herford','Kornet Sapi','Kornet Ayam',
    'Kornet BBQ','Kornet Pedas','Kornet Manis','Kornet Original','Kornet Premium'
  ])[gs - 100] AS nama_barang,
  ((gs * 17 + 37) % 491) + 10 AS stok
FROM generate_series(101, 200) AS gs
ON CONFLICT (id_barang) DO NOTHING;
