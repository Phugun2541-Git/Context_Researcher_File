import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../data/db.dart';
import '../data/index_repository.dart';
import '../data/project_repository.dart';
import '../data/settings_repository.dart';
import '../domain/app_settings.dart';
import '../domain/models.dart';
import 'theme/app_colors.dart';
import 'theme/motion.dart';
import '../services/file_scanner.dart';
import '../services/indexer.dart';
import '../services/search_service.dart';

enum SearchMode { project, adHoc }

/// state กลางของแอป — โปรเจค, การ index, การค้นหา, ไฟล์/จุดที่เลือกอยู่
class AppState extends ChangeNotifier {
  AppState(AppDb db)
      : projectRepo = ProjectRepository(db),
        indexRepo = IndexRepository(db),
        settingsRepo = SettingsRepository(db) {
    settings = settingsRepo.load();
    _applySettingsToApp();
    _rebuildServices();
    loadProjects();
  }

  final ProjectRepository projectRepo;
  final IndexRepository indexRepo;
  final SettingsRepository settingsRepo;
  late Indexer indexer;
  late SearchService searchService;

  /// ค่าตั้งค่าจากหน้า "ตั้งค่า"
  late AppSettings settings;

  void _rebuildServices() {
    final scanner = FileScanner(
      allowedKinds: settings.enabledKinds,
      maxFileSizeBytes: settings.maxFileSizeBytes,
    );
    indexer = Indexer(
      indexRepo: indexRepo,
      projectRepo: projectRepo,
      scanner: scanner,
    );
    searchService = SearchService(indexRepo: indexRepo, scanner: scanner);
  }

  void _applySettingsToApp() {
    applyTheme(settings.themeId);
    Motion.reduced = settings.reduceMotion;
  }

  /// อัปเดตค่าตั้งค่า + บันทึกลง DB + ใช้ผลทันที
  void updateSettings(AppSettings next) {
    settings = next;
    settingsRepo.save(next);
    _applySettingsToApp();
    _rebuildServices();
    notifyListeners();
  }

  // ── โปรเจค ──
  List<Project> projects = const [];
  Project? currentProject;

  // ── โหมด/คำค้น ──
  SearchMode mode = SearchMode.project;
  String query = '';
  List<String> adHocRoots = const [];

  // ── ผล/สถานะ ──
  List<FileResult> results = const [];
  bool searching = false;
  bool indexing = false;
  ScanProgress? progress;
  String? message;
  bool hasSearched = false;

  // ── การเลือกเพื่อ preview ──
  FileResult? selectedFile;
  SearchHit? selectedHit;

  StreamSubscription<void>? _liveSub;
  StreamSubscription<void>? _indexSub;

  void loadProjects() {
    projects = projectRepo.listProjects();
    notifyListeners();
  }

  // ─────────── โปรเจค ───────────

  int createProject(String name) {
    final id = projectRepo.createProject(name);
    loadProjects();
    return id;
  }

  void deleteProject(int id) {
    projectRepo.deleteProject(id);
    if (currentProject?.id == id) currentProject = null;
    loadProjects();
  }

  void openProject(Project project) {
    currentProject = projectRepo.findProject(project.id) ?? project;
    mode = SearchMode.project;
    results = const [];
    hasSearched = false;
    selectedFile = null;
    selectedHit = null;
    message = null;
    notifyListeners();
  }

  void startAdHoc() {
    currentProject = null;
    mode = SearchMode.adHoc;
    results = const [];
    hasSearched = false;
    selectedFile = null;
    selectedHit = null;
    message = null;
    notifyListeners();
  }

  void addRoots(List<String> paths) {
    final project = currentProject;
    if (project == null) {
      adHocRoots = {...adHocRoots, ...paths}.toList()..sort();
      notifyListeners();
      return;
    }
    for (final path in paths) {
      final isFile =
          FileSystemEntity.typeSync(path) == FileSystemEntityType.file;
      projectRepo.addRoot(project.id, path, isFile: isFile);
    }
    currentProject = projectRepo.findProject(project.id);
    loadProjects();
  }

  void removeRoot(ProjectRoot root) {
    final project = currentProject;
    if (project == null) return;
    projectRepo.removeRoot(root.id);
    currentProject = projectRepo.findProject(project.id);
    loadProjects();
  }

  void removeAdHocRoot(String path) {
    adHocRoots = adHocRoots.where((r) => r != path).toList();
    notifyListeners();
  }

  List<String> get activeRoots => mode == SearchMode.project
      ? (currentProject?.roots.map((r) => r.path).toList() ?? const [])
      : adHocRoots;

  // ─────────── index ───────────

  Future<void> indexCurrentProject({bool force = false}) async {
    final project = currentProject;
    if (project == null || indexing) return;
    if (project.roots.isEmpty) {
      message = 'ยังไม่ได้เลือกโฟลเดอร์/ไฟล์ของโปรเจคนี้';
      notifyListeners();
      return;
    }
    indexing = true;
    message = null;
    notifyListeners();

    await _indexSub?.cancel();
    final completer = Completer<void>();
    _indexSub = indexer
        .indexProject(
          projectId: project.id,
          roots: project.roots.map((r) => r.path).toList(),
          force: force,
        )
        .listen(
      (p) {
        progress = p;
        notifyListeners();
      },
      onDone: () {
        indexing = false;
        progress = null;
        currentProject = projectRepo.findProject(project.id);
        loadProjects();
        if (!completer.isCompleted) completer.complete();
      },
      onError: (Object e) {
        indexing = false;
        progress = null;
        message = 'index ไม่สำเร็จ: $e';
        notifyListeners();
        if (!completer.isCompleted) completer.complete();
      },
    );
    return completer.future;
  }

  // ─────────── ค้นหา ───────────

  void setQuery(String value) {
    query = value;
    notifyListeners();
  }

  /// เงื่อนไขที่กดค้นหาได้: มีคำค้น + ระบุขอบเขตแล้ว (ไม่มีโหมดค้นทั้งเครื่อง)
  bool get canSearch =>
      query.trim().isNotEmpty && activeRoots.isNotEmpty && !searching && !indexing;

  Future<void> runSearch() async {
    if (!canSearch) return;
    final q = query.trim();
    selectedFile = null;
    selectedHit = null;
    hasSearched = true;
    message = null;

    if (mode == SearchMode.project) {
      final project = currentProject!;
      searching = true;
      notifyListeners();
      // index ให้ทันไฟล์ที่เพิ่ง sync มาใหม่ก่อนค้นเสมอ (เฉพาะไฟล์ที่เปลี่ยน)
      await indexCurrentProject();
      results = searchService.searchIndexed(projectId: project.id, query: q);
      final problems = indexRepo.problemFiles(project.id);
      if (problems.isNotEmpty) {
        results = [...results, ...problems.where((f) => !results.any((r) => r.path == f.path))];
      }
      searching = false;
      notifyListeners();
      return;
    }

    // โหมดไม่ผูกโปรเจค: scan สด ทยอยแสดงผล
    searching = true;
    results = const [];
    notifyListeners();
    await _liveSub?.cancel();
    final completer = Completer<void>();
    _liveSub = searchService
        .searchLive(roots: adHocRoots, query: q)
        .listen((event) {
      progress = event.progress;
      results = event.results;
      notifyListeners();
    }, onDone: () {
      searching = false;
      progress = null;
      notifyListeners();
      if (!completer.isCompleted) completer.complete();
    }, onError: (Object e) {
      searching = false;
      progress = null;
      message = 'ค้นหาไม่สำเร็จ: $e';
      notifyListeners();
      if (!completer.isCompleted) completer.complete();
    });
    return completer.future;
  }

  void cancelSearch() {
    _liveSub?.cancel();
    _indexSub?.cancel();
    searching = false;
    indexing = false;
    progress = null;
    notifyListeners();
  }

  // ─────────── เลือกไฟล์/จุด ───────────

  void selectFile(FileResult file, {SearchHit? hit}) {
    selectedFile = file;
    selectedHit = hit ?? (file.hits.isNotEmpty ? file.hits.first : null);
    notifyListeners();
  }

  void selectHit(FileResult file, SearchHit hit) {
    selectedFile = file;
    selectedHit = hit;
    notifyListeners();
  }

  void clearSelection() {
    selectedFile = null;
    selectedHit = null;
    notifyListeners();
  }

  void setMessage(String? value) {
    message = value;
    notifyListeners();
  }

  /// สร้าง ScannedFile สำหรับโหลด preview ของไฟล์ที่เลือก
  ScannedFile? scannedFileFor(String path) {
    final kind = FileKind.fromExtension(p.extension(path));
    if (kind == null) return null;
    try {
      final stat = File(path).statSync();
      return ScannedFile(
        path: path,
        kind: kind,
        size: stat.size,
        mtimeMs: stat.modified.millisecondsSinceEpoch,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _liveSub?.cancel();
    _indexSub?.cancel();
    super.dispose();
  }
}
