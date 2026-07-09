-- SHARD 1 — master1 items 1–100 (Beras → Deterjen)
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
    'Deterjen Cair','Deterjen Bubuk','Deterjen Bayi','Deterjen Wol','Deterjen Pewangi'
  ])[gs] AS nama_barang,
  ((gs * 17 + 37) % 491) + 10 AS stok
FROM generate_series(1, 100) AS gs
ON CONFLICT (id_barang) DO NOTHING;
