import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dragchat.dart';
import 'package:studygpt1/UserProfilePage.dart';

class PDFReaderPage extends StatefulWidget {
  const PDFReaderPage({super.key});

  @override
  State<PDFReaderPage> createState() => _PDFReaderPageState();
}

class _PDFReaderPageState extends State<PDFReaderPage> {
  String? localPath;
  final FlutterTts flutterTts = FlutterTts();
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();
  final PdfViewerController _pdfViewerController = PdfViewerController();
  int currentPage = 1;
  double readingProgress = 0.0;
  Set<int> bookmarkedPages = {};
  PdfDocument? pdfDocument;
  List<Map<String, dynamic>> chapters = [];
  String? selectedVoiceName;
  double _speechRate = 0.5;
  String? userEmail;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Load user email and PDF concurrently
    await Future.wait([
      _loadUserEmail(),
      _loadPDF(),
    ]);
    // Load bookmarks and TTS settings in the background
    _loadBookmarks();
    _loadTtsSettings();
    setState(() => _isLoading = false);
  }

  Future<void> _loadUserEmail() async {
    final prefs = await SharedPreferences.getInstance();
    userEmail = prefs.getString('username') ?? 'default';
  }

  Future<void> _loadBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    final savedBookmarks = prefs.getStringList('bookmarked_pages_$userEmail') ?? [];
    setState(() {
      bookmarkedPages = savedBookmarks.map((e) => int.parse(e)).toSet();
    });
  }

  Future<void> _saveBookmarks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('bookmarked_pages_$userEmail', bookmarkedPages.map((e) => e.toString()).toList());
  }

  Future<void> _loadPDF() async {
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/chem.pdf');

    // Check if file already exists
    if (await file.exists()) {
      setState(() => localPath = file.path);
      _loadLastPage();
      _loadChapters();
      return;
    }

    // Copy file from assets if it doesn't exist
    final byteData = await DefaultAssetBundle.of(context).load('assets/pdf/chem.pdf');
    await file.writeAsBytes(byteData.buffer.asUint8List());
    setState(() => localPath = file.path);

    pdfDocument = PdfDocument(inputBytes: await file.readAsBytes());
    _loadLastPage();
    _loadChapters();
  }

  Future<void> _loadLastPage() async {
    final prefs = await SharedPreferences.getInstance();
    final lastPage = prefs.getInt('last_page_$userEmail') ?? 1;
    _pdfViewerController.jumpToPage(lastPage);
    setState(() {
      currentPage = lastPage;
      if (pdfDocument != null) {
        readingProgress = (lastPage / pdfDocument!.pages.count) * 100;
      }
    });
  }

  Future<void> _loadChapters() async {
    // Check if chapters are cached
    final prefs = await SharedPreferences.getInstance();
    final cachedChapters = prefs.getString('chapters_$userEmail');
    if (cachedChapters != null) {
      setState(() => chapters = List<Map<String, dynamic>>.from(jsonDecode(cachedChapters)));
      return;
    }

    // Extract chapters in a separate isolate
    chapters = await compute(_extractChapters, pdfDocument!);
    setState(() {});
    await prefs.setString('chapters_$userEmail', jsonEncode(chapters));
  }

  static List<Map<String, dynamic>> _extractChapters(PdfDocument document) {
    final chapters = <Map<String, dynamic>>[];
    for (int i = 0; i < document.pages.count; i++) {
      final text = PdfTextExtractor(document).extractText(startPageIndex: i, endPageIndex: i);
      if (text.toLowerCase().contains('unit')) {
        final unitTitle = text.split('\n').firstWhere(
              (line) => line.toLowerCase().contains('unit'),
          orElse: () => 'Unit ${i + 1}',
        );
        chapters.add({'title': unitTitle, 'page': i + 1});
      }
    }
    return chapters;
  }

  Future<void> _loadTtsSettings() async {
    final prefs = await SharedPreferences.getInstance();
    _speechRate = prefs.getDouble('speech_rate') ?? 0.5;
    selectedVoiceName = prefs.getString('voice_name');
    await flutterTts.setSpeechRate(_speechRate);
    if (selectedVoiceName != null) {
      final voices = await flutterTts.getVoices;
      final matchingVoice = voices.firstWhere((v) => v['name'] == selectedVoiceName, orElse: () => null);
      if (matchingVoice != null) await flutterTts.setVoice(matchingVoice);
    }
  }

  Future<void> _startTextToSpeech() async {
    if (pdfDocument != null && pdfDocument!.pages.count >= currentPage) {
      final pageText = PdfTextExtractor(pdfDocument!).extractText(startPageIndex: currentPage - 1, endPageIndex: currentPage - 1);
      if (pageText.isNotEmpty) {
        await flutterTts.speak(pageText);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No text found on this page.")));
      }
    }
  }

  void _showChapters() {
    if (chapters.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No chapters found.")));
      return;
    }
    showModalBottomSheet(
      context: context,
      builder: (_) => ListView.builder(
        itemCount: chapters.length,
        itemBuilder: (context, index) => ListTile(
          title: Text(chapters[index]['title']),
          onTap: () {
            _pdfViewerController.jumpToPage(chapters[index]['page']);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  void _openSettings() {
    showDialog(
      context: context,
      builder: (context) {
        double speechRate = _speechRate;
        String? tempVoiceName = selectedVoiceName;
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text("Command Center"),
              content: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        flutterTts.stop();
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("TTS Reset.")));
                      },
                      child: const Text("🔁 Reset TTS"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        _pdfViewerController.jumpToPage(1);
                        _saveLastReadPage(1);
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reading progress reset.")));
                      },
                      child: const Text("🧨 Reset Reading Progress"),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        final bookmarksText = bookmarkedPages.map((e) => "Page $e").join("\n");
                        Navigator.pop(context);
                        showDialog(
                          context: context,
                          builder: (_) => AlertDialog(
                            title: const Text("📚 Bookmarked Pages"),
                            content: Text(bookmarksText.isEmpty ? "No bookmarks yet." : bookmarksText),
                            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
                          ),
                        );
                      },
                      child: const Text("📥 Export Bookmarks"),
                    ),
                    const SizedBox(height: 16),
                    const Text("🎙️ Read Aloud Speed"),
                    Slider(
                      value: speechRate,
                      min: 0.2,
                      max: 1.5,
                      divisions: 13,
                      label: speechRate.toStringAsFixed(2),
                      onChanged: (value) async {
                        setState(() => speechRate = value);
                        await flutterTts.setSpeechRate(value);
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setDouble('speech_rate', value);
                        _speechRate = value;
                      },
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        var voices = await flutterTts.getVoices;
                        showDialog(
                          context: context,
                          builder: (_) => StatefulBuilder(
                            builder: (context, innerSetState) {
                              return AlertDialog(
                                title: const Text("🗣️ Available Voices"),
                                content: SizedBox(
                                  width: double.maxFinite,
                                  height: 300,
                                  child: ListView.builder(
                                    itemCount: voices.length,
                                    itemBuilder: (context, index) {
                                      final voice = voices[index];
                                      final voiceName = voice['name'] ?? 'Voice $index';
                                      final isSelected = voiceName == tempVoiceName;
                                      return ListTile(
                                        title: Text(voiceName),
                                        subtitle: Text(voice['locale'] ?? 'Unknown'),
                                        trailing: isSelected ? const Icon(Icons.check) : null,
                                        onTap: () async {
                                          final voiceMap = <String, String>{'name': voiceName, 'locale': voice['locale']};
                                          await flutterTts.setVoice(voiceMap);
                                          final prefs = await SharedPreferences.getInstance();
                                          await prefs.setString('voice_name', voiceName);
                                          await prefs.setString('voice_locale', voice['locale']);
                                          innerSetState(() => tempVoiceName = voiceName);
                                          setState(() => selectedVoiceName = voiceName);
                                          Navigator.pop(context);
                                        },
                                      );
                                    },
                                  ),
                                ),
                              );
                            },
                          ),
                        );
                      },
                      child: const Text("🎧 Choose Voice"),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        final file = File(localPath!);
                        if (await file.exists()) {
                          await file.delete();
                          Navigator.pop(context);
                          setState(() => localPath = null);
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PDF cache deleted.")));
                        }
                      },
                      child: const Text("🧹 Delete Cached PDF"),
                    ),
                  ],
                ),
              ),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
            );
          },
        );
      },
    );
  }

  void _saveLastReadPage(int page) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('last_page_$userEmail', page);
    await prefs.setDouble('reading_progress', (page / (pdfDocument?.pages.count ?? 1)) * 100);
  }

  void _bookmarkPage() {
    setState(() {
      if (bookmarkedPages.contains(currentPage)) {
        bookmarkedPages.remove(currentPage);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bookmark removed.")));
      } else {
        bookmarkedPages.add(currentPage);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Page bookmarked.")));
      }
    });
    _saveBookmarks();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        _saveLastReadPage(_pdfViewerController.pageNumber);
        Navigator.pop(context, true);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.teal,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context, true),
          ),
          title: const Text('Some Book Grade 9', style: TextStyle(color: Colors.white)),
          centerTitle: true,
          actions: [
            IconButton(icon: const Icon(Icons.volume_up, color: Colors.white), onPressed: _startTextToSpeech),
            IconButton(icon: const Icon(Icons.menu_book, color: Colors.white), onPressed: _showChapters),
            IconButton(icon: const Icon(Icons.settings, color: Colors.white), onPressed: _openSettings),
          ],
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : localPath != null
            ? Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(
                    value: readingProgress / 100,
                    color: Colors.green,
                    backgroundColor: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${readingProgress.toStringAsFixed(1)}% read',
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
                ),
                child: SfPdfViewer.file(
                  File(localPath!),
                  key: _pdfViewerKey,
                  controller: _pdfViewerController,
                  enableTextSelection: true,
                  onPageChanged: (details) {
                    setState(() {
                      currentPage = _pdfViewerController.pageNumber;
                      if (pdfDocument != null) {
                        readingProgress = (currentPage / pdfDocument!.pages.count) * 100;
                      }
                    });
                    _saveLastReadPage(currentPage);
                  },
                ),
              ),
            ),
            BottomNavigationBar(
              backgroundColor: Colors.white,
              selectedItemColor: Colors.deepOrange,
              unselectedItemColor: Colors.grey,
              items: [
                const BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
                BottomNavigationBarItem(
                  icon: Icon(Icons.bookmark, color: bookmarkedPages.contains(currentPage) ? Colors.deepOrange : Colors.grey),
                  label: 'Bookmark',
                ),
              ],
              onTap: (index) {
                if (index == 1) _bookmarkPage();
              },
            ),
          ],
        )
            : const Center(child: Text('Error loading PDF')),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.teal,
          child: const Icon(Icons.chat),
          onPressed: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) => const DraggableChatSheet(),
            );
          },
        ),
      ),
    );
  }
}