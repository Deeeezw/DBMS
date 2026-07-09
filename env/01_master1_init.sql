-- ============================================================
-- MASTER 1 INIT — Food & Grocery (300 items, 3 shards)
-- master1 → shard1 (ids 1–100), shard2 (ids 101–200), shard3 (ids 201–300)
-- ============================================================

CREATE TABLE IF NOT EXISTS barang (
    id_barang    SERIAL PRIMARY KEY,
    nama_barang  VARCHAR(100) NOT NULL,
    stok         INT          NOT NULL DEFAULT 0,
    target_shard INT          NOT NULL,
    created_at   TIMESTAMP    DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS shard_status (
    shard_id   INT PRIMARY KEY,
    shard_name VARCHAR(20) NOT NULL,
    status     VARCHAR(10) DEFAULT 'online'
);

INSERT INTO shard_status (shard_id, shard_name, status) VALUES
    (1, 'shard1', 'online'),
    (2, 'shard2', 'online'),
    (3, 'shard3', 'online')
ON CONFLICT (shard_id) DO NOTHING;

INSERT INTO barang (id_barang, nama_barang, stok, target_shard)
SELECT
  gs,
  (ARRAY[
    'Beras Pandan Wangi','Beras Pulen','Beras Merah','Beras Ketan','Beras Jasmine',
    'Beras Basmati','Beras Organik','Beras IR64','Beras Ramos','Beras Cianjur',
    'Minyak Goreng Tropical','Minyak Goreng Bimoli','Minyak Goreng Sania','Minyak Goreng Fortune','Minyak Zaitun',
    'Minyak Kelapa','Minyak Jagung','Minyak Canola','Minyak Wijen','Minyak Kedelai',
    'Gula Pasir','Gula Merah','Gula Aren','Gula Batu','Gula Rendah Kalori',
    'Gula Kelapa','Gula Castor','Gula Tepung','Gula Tebu','Gula Jawa',
    'Tepung Terigu','Tepung Beras','Tepung Tapioka','Tepung Maizena','Tepung Sagu',
    'Tepung Ketan','Tepung Roti','Tepung Bumbu','Tepung Kacang','Tepung Singkong',
    'Kopi Arabika','Kopi Robusta','Kopi Luwak','Kopi Gayo','Kopi Toraja',
    'Kopi Flores','Kopi Mandailing','Kopi Wamena','Kopi Sidikalang','Kopi Bajawa',
    'Teh Hijau','Teh Hitam','Teh Oolong','Teh Putih','Teh Melati',
    'Teh Chamomile','Teh Rosehip','Teh Peppermint','Teh Jahe','Teh Botol',
    'Mie Instant Goreng','Mie Instant Kuah','Mie Telur','Mie Bihun','Mie Sohun',
    'Mie Udon','Mie Ramen','Mie Soba','Mie Shirataki','Mie Lidi',
    'Sabun Lifebuoy','Sabun Dettol','Sabun Cuci Tangan','Sabun Cair','Sabun Batang',
    'Sabun Bayi','Sabun Gliserin','Sabun Antiseptik','Sabun Arang','Sabun Susu',
    'Sampo Pantene','Sampo Sunsilk','Sampo Dove','Sampo Rejoice','Sampo Clear',
    'Sampo Zinc','Sampo Herbal','Sampo Bayi','Sampo Keriting','Sampo Anti Ketombe',
    'Deterjen Rinso','Deterjen Surf','Deterjen Attack','Deterjen So Klin','Deterjen Mama Lemon',
    'Deterjen Cair','Deterjen Bubuk','Deterjen Bayi','Deterjen Wol','Deterjen Pewangi',
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
    'Kornet BBQ','Kornet Pedas','Kornet Manis','Kornet Original','Kornet Premium',
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
  ])[gs] AS nama_barang,
  ((gs * 17 + 37) % 491) + 10 AS stok,
  CASE WHEN gs <= 100 THEN 1 WHEN gs <= 200 THEN 2 ELSE 3 END AS target_shard
FROM generate_series(1, 300) AS gs
ON CONFLICT (id_barang) DO NOTHING;
