-- SHARD 4 — master2 items 301–400 (Kabel → Card Reader USB)
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
    'Kabel USB Type-C','Kabel USB Type-A','Kabel HDMI','Kabel Aux','Kabel Lightning',
    'Kabel Micro USB','Kabel Ethernet','Kabel VGA','Kabel DisplayPort','Kabel Thunderbolt',
    'Buku Tulis A4 Folio','Buku Tulis Kwarto','Buku Tulis A5','Binder Kertas','Buku Spiral',
    'Buku Hardcover','Buku Softcover','Buku Motif','Buku Polos','Buku Grid',
    'Pulpen Pilot G2','Pulpen Faber Castell','Stabilo Point 88','Spidol Snowman','Pulpen Joyko',
    'Pulpen Parker','Pulpen BIC','Uni-ball Signo','Pentel Energel','Zebra Sarasa',
    'Stapler Kenko','Perforator Joyko','Gunting Kantor','Paper Clip','Binder Clip',
    'Lem UHU','Selotip Bening','Double Tape Foam','Map Plastik','Ordner A4',
    'Pemutih Bayclin','Karbol Soklin','Wipol Lavender','Sabun Cuci Sunlight','Dettol Spray',
    'Glass Cleaner','Floor Polish','Pembersih Saluran','Pembersih AC','Anti Karat WD40',
    'Kondisioner Pantene','Serum Rambut TRESemme','Hair Mask Garnier','Hair Tonic Makarizo','Minyak Kemiri VoV',
    'Pomade Gatsby','Hair Gel Brylcreem','Hair Spray Rejoice','Pewarna Rambut Garnier','Masker Rambut Loreal',
    'Pembersih Wajah Cetaphil','Toner Wardah','Pelembap Nivea','Sunscreen Biore','Masker Wajah Garnier',
    'Serum Vitamin C','Eye Cream Olay','BB Cream Wardah','Foundation Maybelline','Micellar Water Garnier',
    'Spons Scotch-Brite','Kain Lap Kanebo','Kain Microfiber','Scrubber Dapur','Steel Wool',
    'Spon Mandi','Busa Cuci Motor','Lap Kering','Lap Dapur','Lap Kaca',
    'Plester Hansaplast','Betadin Merah','Kapas Kecantikan','Kasa Steril','Termometer Digital',
    'Tensimeter Digital','Masker Medis','Alkohol 70%','Obat Nyamuk Bakar','Minyak Kayu Putih Cap Lang',
    'Case HP Silikon','Tempered Glass 5D','Ring Holder HP','Pop Socket','Wireless Charger',
    'Holder Motor HP','Earphone Bluetooth','Powerbank 10000mAh','USB Hub 4 Port','Card Reader USB'
  ])[gs - 300] AS nama_barang,
  ((gs * 17 + 37) % 491) + 10 AS stok
FROM generate_series(301, 400) AS gs
ON CONFLICT (id_barang) DO NOTHING;
