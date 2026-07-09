-- SHARD 6 — master2 items 501–600 (Kertas A4 → Odol Sensodyne)
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
  ])[gs - 500] AS nama_barang,
  ((gs * 17 + 37) % 491) + 10 AS stok
FROM generate_series(501, 600) AS gs
ON CONFLICT (id_barang) DO NOTHING;
