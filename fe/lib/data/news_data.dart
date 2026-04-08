class NewsArticle {
  final String id;
  final String title;
  final String excerpt;
  final String content;
  final String category;
  final String author;
  final String date;
  final String imageUrl;
  final bool isFeatured;

  const NewsArticle({
    required this.id,
    required this.title,
    required this.excerpt,
    required this.content,
    required this.category,
    required this.author,
    required this.date,
    required this.imageUrl,
    this.isFeatured = false,
  });
}

const List<String> newsCategories = [
  'All News',
  'K3 / HSE',
  'Operasional',
  'Regulasi',
  'Prestasi',
];

final List<NewsArticle> dummyNews = [
  NewsArticle(
    id: '1',
    title:
        'Target Produksi Dipangkas, Komisi XII DPR RI Usulkan Porsi DMO Batu Bara Naik Menjadi 30%',
    excerpt:
        'Jakarta, CNBC Indonesia - Pasar Batu Bara Global Memasuki Pergerakan Yang Penuh Gejolak. Harga Bergerak Naik Di Tengah Ketidakpastian...',
    content:
        'Jakarta, CNBC Indonesia - Pasar Batu Bara Global Memasuki Pergerakan Yang Penuh Gejolak. Harga Bergerak Naik Di Tengah Ketidakpastian geopolitik yang semakin kompleks. Komisi XII DPR RI mengusulkan agar porsi Domestic Market Obligation (DMO) batu bara ditingkatkan dari 25% menjadi 30% untuk menjaga ketahanan energi nasional. Kebijakan ini diharapkan dapat menstabilkan pasokan energi dalam negeri sekaligus mendorong pertumbuhan industri lokal.',
    category: 'Regulasi',
    author: 'Admin',
    date: '27 Februari 2026',
    imageUrl:
        'https://images.unsplash.com/photo-1611273426858-450d8e3c9fce?w=800&q=80',
    isFeatured: true,
  ),
  NewsArticle(
    id: '2',
    title:
        'Dunia Siaga Energi, Harga Batu Bara Menguat Imbas Perang Timur Tengah',
    excerpt:
        'Jakarta, CNBC Indonesia - Pasar Batu Bara Global Memasuki Pergerakan Yang Penuh Gejolak. Harga Bergerak Naik Di Tengah Ketidakpastian...',
    content:
        'Harga batu bara global terus menguat seiring meningkatnya ketegangan di kawasan Timur Tengah. Para analis memperkirakan harga akan terus bergerak naik dalam beberapa pekan ke depan. Kondisi ini memberikan peluang bagi produsen batu bara domestik untuk meningkatkan ekspor dan pendapatan.',
    category: 'Operasional',
    author: 'Admin',
    date: '15 Maret 2026',
    imageUrl:
        'https://images.unsplash.com/photo-1578662996442-48f60103fc96?w=800&q=80',
    isFeatured: true,
  ),
  NewsArticle(
    id: '3',
    title: 'BBE Raih Zero Accident Selama 365 Hari Berturut-turut',
    excerpt:
        'PT Bukit Baiduri Energi berhasil meraih pencapaian luar biasa dengan nol kecelakaan kerja selama satu tahun penuh...',
    content:
        'PT Bukit Baiduri Energi (BBE) berhasil meraih pencapaian membanggakan dengan mencatat nol kecelakaan kerja (Zero Accident) selama 365 hari berturut-turut. Pencapaian ini merupakan bukti nyata komitmen perusahaan dalam menerapkan standar Keselamatan dan Kesehatan Kerja (K3) yang ketat di seluruh area operasional.',
    category: 'Prestasi',
    author: 'Admin',
    date: '10 Maret 2026',
    imageUrl:
        'https://images.unsplash.com/photo-1504307651254-35680f356dfd?w=800&q=80',
    isFeatured: true,
  ),
  NewsArticle(
    id: '4',
    title: 'Pelatihan APAR Wajib Untuk Seluruh Karyawan BBE Periode Q1 2026',
    excerpt:
        'Program pelatihan penggunaan Alat Pemadam Api Ringan (APAR) kembali digelar untuk memastikan seluruh karyawan siap menghadapi situasi darurat...',
    content:
        'Departemen HSE BBE kembali menggelar program pelatihan penggunaan Alat Pemadam Api Ringan (APAR) yang wajib diikuti seluruh karyawan. Pelatihan ini bertujuan untuk memastikan setiap karyawan memiliki kemampuan dasar dalam menangani situasi darkebakaran di area kerja.',
    category: 'K3 / HSE',
    author: 'Tim HSE',
    date: '8 Maret 2026',
    imageUrl:
        'https://images.unsplash.com/photo-1558618666-fcd25c85cd64?w=800&q=80',
    isFeatured: false,
  ),
  NewsArticle(
    id: '5',
    title: 'Update SOP Pengelolaan Limbah B3 Sesuai Regulasi Terbaru KLHK',
    excerpt:
        'Kementerian Lingkungan Hidup dan Kehutanan menerbitkan regulasi baru terkait pengelolaan limbah bahan berbahaya dan beracun...',
    content:
        'Kementerian Lingkungan Hidup dan Kehutanan (KLHK) menerbitkan regulasi terbaru terkait pengelolaan limbah Bahan Berbahaya dan Beracun (B3). BBE langsung merespons dengan memperbarui seluruh Standar Operasional Prosedur (SOP) yang berkaitan agar tetap patuh terhadap ketentuan yang berlaku.',
    category: 'Regulasi',
    author: 'Admin',
    date: '5 Maret 2026',
    imageUrl:
        'https://images.unsplash.com/photo-1532996122724-e3c354a0b15b?w=800&q=80',
    isFeatured: false,
  ),
  NewsArticle(
    id: '6',
    title: 'Jadwal Inspeksi Rutin Area Tambang Maret 2026',
    excerpt:
        'Tim K3 BBE akan melaksanakan inspeksi rutin menyeluruh di seluruh area tambang sepanjang bulan Maret 2026...',
    content:
        'Tim K3 PT Bukit Baiduri Energi akan melaksanakan program inspeksi rutin menyeluruh di seluruh area tambang sepanjang bulan Maret 2026. Inspeksi ini mencakup pemeriksaan kondisi alat berat, instalasi listrik, fasilitas K3, serta kepatuhan prosedur kerja para operator.',
    category: 'Operasional',
    author: 'Tim K3',
    date: '1 Maret 2026',
    imageUrl:
        'https://images.unsplash.com/photo-1567789884554-0b844b597180?w=800&q=80',
    isFeatured: false,
  ),
  NewsArticle(
    id: '7',
    title: 'BBE Terima Penghargaan Proper Emas dari KLHK 2026',
    excerpt:
        'PT Bukit Baiduri Energi kembali meraih penghargaan PROPER Emas dari Kementerian Lingkungan Hidup dan Kehutanan...',
    content:
        'PT Bukit Baiduri Energi (BBE) kembali mendapatkan penghargaan tertinggi Program Penilaian Peringkat Kinerja Perusahaan (PROPER) Emas dari Kementerian Lingkungan Hidup dan Kehutanan. Penghargaan ini merupakan yang ketiga kalinya diraih BBE secara berturut-turut, mencerminkan komitmen perusahaan dalam pengelolaan lingkungan yang berkelanjutan.',
    category: 'Prestasi',
    author: 'Humas BBE',
    date: '20 Februari 2026',
    imageUrl:
        'https://images.unsplash.com/photo-1567427017947-545c5f8d16ad?w=800&q=80',
    isFeatured: false,
  ),
  NewsArticle(
    id: '8',
    title: 'Sosialisasi Prosedur Evakuasi Darurat Seluruh Area Operasional',
    excerpt:
        'Departemen HSE mengadakan sosialisasi dan simulasi prosedur evakuasi darurat untuk memastikan kesiapan seluruh personel...',
    content:
        'Departemen HSE BBE mengadakan program sosialisasi dan simulasi prosedur evakuasi darurat yang melibatkan seluruh personel di area operasional. Kegiatan ini dirancang untuk memastikan setiap karyawan memahami jalur evakuasi, titik kumpul, dan prosedur yang harus diikuti saat terjadi keadaan darurat.',
    category: 'K3 / HSE',
    author: 'Tim HSE',
    date: '15 Februari 2026',
    imageUrl:
        'https://images.unsplash.com/photo-1584036561566-baf8f5f1b144?w=800&q=80',
    isFeatured: false,
  ),
];
