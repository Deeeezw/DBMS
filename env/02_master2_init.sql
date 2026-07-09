-- ============================================================
-- MASTER 2 INIT — Household & Non-Food (300 items, 3 shards)
-- master2 → shard4 (ids 1–100), shard5 (ids 101–200), shard6 (ids 201–300)
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
    (1, 'shard4', 'online'),
    (2, 'shard5', 'online'),
    (3, 'shard6', 'online')
ON CONFLICT (shard_id) DO NOTHING;

INSERT INTO barang (id_barang, nama_barang, stok, target_shard)
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
    'Holder Motor HP','Earphone Bluetooth','Powerbank 10000mAh','USB Hub 4 Port','Card Reader USB',
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
    'Selimut Bayi Fleece','Kaus Kaki Bayi','Topi Bayi Rajut','Bantal Kepala Bayi','Guling Bayi',
    'Kertas A4 80gsm Sinar','Kertas F4 70gsm','Kertas HVS Warna','Kertas Foto Glossy','Kertas Kalkir A4',
    'Kertas Karton Duplex','Stiker Label Putih','Amplop Putih','Plastik Mika Bening','Kertas Origami',
    'Mouse Wireless Logitech','Keyboard Wireless','Mouse Pad Gaming XL','Cooling Pad Laptop','Tas Laptop 14 Inch',
    'Screen Protector Laptop','USB Hub 7 Port','Docking Station','Adaptor Laptop Universal','Antivirus 1 Tahun',
    'Balon Pesta Latex','Lilin Angka Ulang Tahun','Topi Pesta Karton','Confetti Pelangi','Tiup-tiupan Pesta',
    'Hiasan Cupcake','Pita Hadiah Emas','Kotak Kado Besar','Kartu Ucapan Premium','Dekorasi Banner HBD',
    'Koper Cabin 20 Inch','Kunci Gembok TSA','Bantal Leher Memory Foam','Penutup Mata Tidur','Adaptor Travel Universal',
    'Dry Bag 10L','Tag Koper Kulit','Botol Travel 100ml','Kantong Laundry','Alas Sepatu Travel',
    'Makanan Kucing Whiskas','Makanan Anjing Pedigree','Pasir Kucing Wangi','Vitamin Kucing Nutri','Kandang Hamster',
    'Mainan Kucing Bola','Shampo Anjing','Obat Cacing Hewan','Tempat Minum Kucing','Sangkar Burung',
    'Handuk Mandi Cotton','Shower Cap Plastik','Bath Bomb Lavender','Scrub Kopi','Loofah Alami',
    'Batu Apung','Keset Kamar Mandi Anti Slip','Sabun Scrub Cokelat','Shower Gel Sensate','Body Butter Vaseline',
    'Catok Rambut Philips','Hair Dryer Mini','Hair Curler Ceramic','Sisir Kayu Jati','Sisir Paddle',
    'Sisir Blow Bulat','Jepit Rambut Claw','Ikat Rambut Karet','Headband Kain','Bando Pita',
    'Pot Bunga Tanah Liat','Cangkul Mini Taman','Sekop Taman','Sprayer Tanaman 1L','Pupuk NPK Mutiara',
    'Bibit Tomat Cherry','Tanah Pot Humus','Batu Hias Akuarium','Selang Taman 10m','Net Tanaman',
    'Cat Akrilik Set 12','Cat Air Winsor','Kuas Lukis Set 10','Kanvas A3','Sketsa Pad A4',
    'Oil Pastel Mungyo','Pensil Karbon Conte','Tinta India Pelikan','Palet Plastik','Fixative Spray',
    'Sikat Gigi Oral-B','Odol Pepsodent Charcoal','Mouthwash Listerine','Benang Gigi Oral-B','Tongue Cleaner',
    'Sikat Gigi Elektrik Braun','Floss Pick','Water Flosser','Whitening Gel','Odol Sensodyne'
  ])[gs] AS nama_barang,
  ((gs * 17 + 37) % 491) + 10 AS stok,
  CASE WHEN gs <= 100 THEN 1 WHEN gs <= 200 THEN 2 ELSE 3 END AS target_shard
FROM generate_series(1, 300) AS gs
ON CONFLICT (id_barang) DO NOTHING;
