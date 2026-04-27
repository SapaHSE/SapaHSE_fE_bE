import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import '../models/news_model.dart';
import '../services/api_service.dart';
import 'dashboard_widgets.dart';

class DashboardNewsModule extends StatefulWidget {
  const DashboardNewsModule({super.key});

  @override
  State<DashboardNewsModule> createState() => _DashboardNewsModuleState();
}

class _DashboardNewsModuleState extends State<DashboardNewsModule> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<NewsModel> _newsList = [];
  bool _isLoadingNews = false;
  int _newsTotalPages = 1;
  int _currentNewsPage = 1;
  XFile? _newsImage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchNews();
    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text.toLowerCase());
      _fetchNews(page: 1);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchNews({int page = 1}) async {
    setState(() => _isLoadingNews = true);
    final query = '?page=$page&search=$_searchQuery';
    final response = await ApiService.get('/news$query');
    if (response.success && mounted) {
      try {
        dynamic dataObj = response.data;
        final dynamic rawData = (dataObj is Map && dataObj.containsKey('data'))
            ? dataObj['data']
            : dataObj;

        List<NewsModel> parsedNews = [];
        int total = 1;
        int current = 1;

        if (rawData is Map<String, dynamic>) {
          parsedNews = (rawData['data'] as List? ?? [])
              .map((n) => NewsModel.fromJson(n))
              .toList();
          total = int.tryParse(rawData['last_page']?.toString() ?? '1') ?? 1;
          current = int.tryParse(rawData['current_page']?.toString() ?? '1') ?? 1;
        } else if (rawData is List) {
          parsedNews = rawData.map((n) => NewsModel.fromJson(n)).toList();
          if (dataObj is Map) {
            final meta = dataObj['meta'];
            total = int.tryParse(meta?['last_page']?.toString() ?? '1') ?? 1;
            current = int.tryParse(meta?['current_page']?.toString() ?? '1') ?? 1;
          }
        }

        setState(() {
          _newsList = parsedNews;
          _newsTotalPages = total;
          _currentNewsPage = current;
          _isLoadingNews = false;
        });
      } catch (e) {
        debugPrint('Error parsing news: $e');
        setState(() => _isLoadingNews = false);
      }
    } else if (mounted) {
      setState(() => _isLoadingNews = false);
    }
  }

  void _showCreateNewsForm() {
    final titleCtrl = TextEditingController();
    final catCtrl = TextEditingController();
    final excerptCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    final authorCtrl = TextEditingController();
    bool isLoading = false;
    _newsImage = null;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Buat Berita Baru'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Judul Berita',
                        border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(
                    controller: authorCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Nama Penulis',
                        border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(
                    controller: catCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Kategori (e.g. Training, Safety)',
                        border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(
                    controller: excerptCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                        labelText: 'Ringkasan / Excerpt',
                        border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(
                    controller: contentCtrl,
                    maxLines: 5,
                    decoration: const InputDecoration(
                        labelText: 'Isi Berita Lengkap',
                        border: OutlineInputBorder())),
                const SizedBox(height: 16),
                StatefulBuilder(builder: (ctx, setPickerState) {
                  return Column(
                    children: [
                      if (_newsImage != null)
                        const ClipRRect(
                            child: Icon(Icons.check_circle,
                                color: Colors.green, size: 40)),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () async {
                          final img = await ImagePicker()
                              .pickImage(source: ImageSource.gallery);
                          if (img != null) {
                            setModalState(() => _newsImage = img);
                            setPickerState(() {});
                          }
                        },
                        icon: const Icon(Icons.image_outlined),
                        label: Text(_newsImage == null
                            ? 'Pilih Gambar Berita'
                            : 'Gambar Terpilih'),
                      ),
                    ],
                  );
                }),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
                child: const Text('Batal')),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      setModalState(() => isLoading = true);
                      ApiResponse res;
                      final payload = {
                        'title': titleCtrl.text,
                        'category': catCtrl.text,
                        'excerpt': excerptCtrl.text,
                        'content': contentCtrl.text,
                        'author_name': authorCtrl.text,
                      };
                      if (_newsImage != null) {
                        final bytes = await _newsImage!.readAsBytes();
                        final file = http.MultipartFile.fromBytes(
                            'image', bytes,
                            filename: _newsImage!.name);
                        res = await ApiService.postMultipart(
                            '/news', payload, [file]);
                      } else {
                        res = await ApiService.post('/news', payload);
                      }
                      if (res.success && mounted) {
                        Navigator.pop(ctx);
                        _fetchNews(page: 1);
                        showDialog(
                          context: context,
                          builder: (ctx) => const DashboardSuccessDialog(
                            title: 'Berhasil!',
                            message:
                                'Berita baru telah berhasil dipublikasikan.',
                          ),
                        );
                      } else if (mounted) {
                        setModalState(() => isLoading = false);
                      }
                    },
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Simpan Berita'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditNewsForm(NewsModel n) async {
    // 1. Pre-fetch detail for full content
    final detailRes = await ApiService.get('/news/${n.id}');
    NewsModel fullNews = n;
    if (detailRes.success && detailRes.data['data'] != null) {
      fullNews = NewsModel.fromJson(detailRes.data['data']);
    }

    final titleCtrl = TextEditingController(text: fullNews.title);
    final excerptCtrl = TextEditingController(text: fullNews.excerpt);
    final contentCtrl = TextEditingController(text: fullNews.content ?? '');
    final catCtrl = TextEditingController(text: fullNews.category);
    final authorCtrl = TextEditingController(text: fullNews.authorName ?? '');
    XFile? pickedImage;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Edit Berita',
              style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  StatefulBuilder(builder: (ctx, setPickerState) {
                    return Column(
                      children: [
                        Container(
                          height: 150,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            image: pickedImage != null
                                ? DecorationImage(
                                    image: NetworkImage(pickedImage!.path),
                                    fit: BoxFit.cover,
                                  )
                                : (n.imageUrl != null
                                    ? DecorationImage(
                                        image: NetworkImage(n.imageUrl!),
                                        fit: BoxFit.cover,
                                      )
                                    : null),
                          ),
                          child: (pickedImage == null && n.imageUrl == null)
                              ? const Icon(Icons.image_not_supported_outlined,
                                  size: 48, color: Colors.grey)
                              : null,
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final img = await ImagePicker()
                                .pickImage(source: ImageSource.gallery);
                            if (img != null) {
                              setPickerState(() => pickedImage = img);
                            }
                          },
                          icon:
                              const Icon(Icons.photo_library_rounded, size: 18),
                          label: Text(pickedImage == null
                              ? 'Ganti Gambar'
                              : 'Gambar Dipilih'),
                        ),
                      ],
                    );
                  }),
                  const SizedBox(height: 20),
                  TextField(
                      controller: titleCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Judul Berita',
                          border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(
                      controller: authorCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Nama Penulis',
                          border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(
                      controller: catCtrl,
                      decoration: const InputDecoration(
                          labelText: 'Kategori', border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(
                      controller: excerptCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                          labelText: 'Ringkasan / Excerpt',
                          border: OutlineInputBorder())),
                  const SizedBox(height: 12),
                  TextField(
                      controller: contentCtrl,
                      maxLines: 5,
                      decoration: const InputDecoration(
                          labelText: 'Isi Konten',
                          border: OutlineInputBorder())),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: isLoading ? null : () => Navigator.pop(ctx),
                child: const Text('Batal')),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      setModalState(() => isLoading = true);
                      final fields = {
                        'title': titleCtrl.text,
                        'category': catCtrl.text,
                        'excerpt': excerptCtrl.text,
                        'content': contentCtrl.text,
                        'author_name': authorCtrl.text,
                      };

                      ApiResponse res;
                      if (pickedImage != null) {
                        final bytes = await pickedImage!.readAsBytes();
                        final file = http.MultipartFile.fromBytes(
                            'image', bytes,
                            filename: pickedImage!.name);
                        res = await ApiService.putMultipart(
                            '/news/${n.id}', fields, [file]);
                      } else {
                        res = await ApiService.put('/news/${n.id}', fields);
                      }

                      if (res.success && mounted) {
                        Navigator.pop(ctx);
                        _fetchNews(page: _currentNewsPage);
                        showDialog(
                          context: context,
                          builder: (ctx) => const DashboardSuccessDialog(
                            title: 'Berhasil!',
                            message:
                                'Berita berhasil diperbarui dengan data terbaru.',
                          ),
                        );
                      } else if (mounted) {
                        setModalState(() => isLoading = false);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                              content: Text(res.errorMessage ?? 'Gagal update'),
                              backgroundColor: Colors.red),
                        );
                      }
                    },
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Perbarui'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const DashboardSectionHeader(
          title: 'Berita & Update',
          subtitle: 'Kelola informasi broadcast dan edukasi keselamatan.'),
      const SizedBox(height: 24),
      _buildFilterBar(),
      const SizedBox(height: 24),
      if (_isLoadingNews)
        const Padding(
            padding: EdgeInsets.all(60),
            child: Center(child: CircularProgressIndicator()))
      else if (_newsList.isEmpty)
        _buildEmptyState()
      else
        _buildNewsGrid(),
    ]);
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: dashboardCardDecoration(radius: 20),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchCtrl,
              decoration: const InputDecoration(
                  hintText: 'Search news...',
                  prefixIcon: Icon(Icons.search),
                  border: InputBorder.none),
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton.icon(
            onPressed: _showCreateNewsForm,
            icon: const Icon(Icons.add),
            label: const Text('Buat Berita'),
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1D4ED8),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12))),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(60),
      decoration: dashboardCardDecoration(),
      child: const Column(children: [
        Icon(Icons.newspaper_outlined, size: 56, color: Color(0xFFCBD5E1)),
        SizedBox(height: 16),
        Text('Belum ada berita dipublikasikan',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569))),
        SizedBox(height: 6),
        Text('Klik "Buat Berita" untuk menambahkan konten baru.',
            style: TextStyle(fontSize: 13, color: Color(0xFF94A3B8))),
      ]),
    );
  }

  Widget _buildNewsGrid() {
    return Column(children: [
      LayoutBuilder(builder: (context, constraints) {
        final crossCount = constraints.maxWidth > 900
            ? 3
            : constraints.maxWidth > 580
                ? 2
                : 1;
        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossCount,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: crossCount == 1 ? 1.1 : 1.35),
          itemCount: _newsList.length,
          itemBuilder: (context, i) {
            final n = _newsList[i];
            return DashboardNewsCard(
              news: n,
              onEdit: () => _showEditNewsForm(n),
              onDelete: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => DashboardConfirmDialog(
                    title: 'Hapus Berita',
                    message:
                        'Apakah Anda yakin ingin menghapus "${n.title}"? Tindakan ini tidak dapat dibatalkan.',
                  ),
                );
                if (confirm == true && mounted) {
                  final res = await ApiService.delete('/news/${n.id}');
                  if (res.success && mounted) {
                    _fetchNews(page: _currentNewsPage);
                    showDialog(
                      context: context,
                      builder: (ctx) => const DashboardSuccessDialog(
                        title: 'Dihapus!',
                        message: 'Berita telah berhasil dihapus dari sistem.',
                      ),
                    );
                  } else if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(res.errorMessage ?? 'Gagal menghapus berita'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            );
          },
        );
      }),
      const SizedBox(height: 24),
      _buildPaginationFooter(),
    ]);
  }

  Widget _buildPaginationFooter() {
    if (_newsTotalPages <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Page $_currentNewsPage of $_newsTotalPages',
            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        Row(children: [
          DashboardPagerButton(
              icon: Icons.chevron_left,
              onPressed: _currentNewsPage > 1
                  ? () => _fetchNews(page: _currentNewsPage - 1)
                  : null),
          const SizedBox(width: 8),
          DashboardPagerButton(
              icon: Icons.chevron_right,
              onPressed: _currentNewsPage < _newsTotalPages
                  ? () => _fetchNews(page: _currentNewsPage + 1)
                  : null),
        ]),
      ],
    );
  }
}
