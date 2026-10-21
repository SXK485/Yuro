import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 用户为某条音轨手动选择的外挂字幕。
class LocalSubtitleData {
  final String name;
  final String content;

  const LocalSubtitleData({required this.name, required this.content});
}

/// 本地外挂字幕的持久化仓库。
///
/// 字幕正文写到应用支持目录（避免 SharedPreferences 存大字符串），
/// SharedPreferences 只保存“当前音轨 -> 文件路径/显示名”的映射。
/// 键按 work + audio title 隔离，所以同一作品的多条音轨可以各挂各的字幕。
class LocalSubtitleRepository {
  static const _keyPrefix = 'local_subtitle_v1';
  static const _supportedExtensions = ['.srt', '.vtt', '.lrc'];

  final SharedPreferences _prefs;
  final Future<Directory> Function() _supportDirectory;

  LocalSubtitleRepository(
    this._prefs, {
    Future<Directory> Function()? supportDirectory,
  }) : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory;

  String storageKey({
    int? workId,
    String? workTitle,
    String? audioTitle,
  }) {
    final work = workId?.toString() ?? workTitle ?? 'unknown-work';
    final audio = audioTitle ?? 'unknown-audio';
    return '$_keyPrefix:${Uri.encodeComponent(work)}:${Uri.encodeComponent(audio)}';
  }

  Future<LocalSubtitleData?> load({
    int? workId,
    String? workTitle,
    String? audioTitle,
  }) async {
    final key = storageKey(
      workId: workId,
      workTitle: workTitle,
      audioTitle: audioTitle,
    );
    final raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        await _remove(key);
        return null;
      }
      final path = decoded['file'] as String?;
      final name = decoded['name'] as String? ?? '外挂字幕';
      if (path == null || path.isEmpty) {
        await _remove(key);
        return null;
      }
      final file = File(path);
      if (!await file.exists()) {
        await _remove(key);
        return null;
      }
      final content = await file.readAsString();
      if (content.trim().isEmpty) {
        await _remove(key);
        return null;
      }
      return LocalSubtitleData(name: name, content: content);
    } catch (_) {
      await _remove(key);
      return null;
    }
  }

  Future<void> save({
    int? workId,
    String? workTitle,
    String? audioTitle,
    required String name,
    required String content,
  }) async {
    final key = storageKey(
      workId: workId,
      workTitle: workTitle,
      audioTitle: audioTitle,
    );
    final directory = await _subtitleDirectory();
    final digest = sha1.convert(utf8.encode('$key:$name')).toString();
    final file = File(
      '${directory.path}${Platform.pathSeparator}$digest${_extension(name)}',
    );
    await file.writeAsString(content, flush: true);
    await _prefs.setString(
      key,
      jsonEncode({'name': name, 'file': file.path}),
    );
  }

  Future<void> clear({
    int? workId,
    String? workTitle,
    String? audioTitle,
  }) async {
    final key = storageKey(
      workId: workId,
      workTitle: workTitle,
      audioTitle: audioTitle,
    );
    await _remove(key);
  }

  Future<void> _remove(String key) async {
    final raw = _prefs.getString(key);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        final path =
            decoded is Map<String, dynamic> ? decoded['file'] as String? : null;
        if (path != null && path.isNotEmpty) {
          final file = File(path);
          if (await file.exists()) await file.delete();
        }
      } catch (_) {
        // 元数据损坏时仍然要清掉键，不能留下永远无法恢复的脏记录。
      }
    }
    await _prefs.remove(key);
  }

  Future<Directory> _subtitleDirectory() async {
    final support = await _supportDirectory();
    final directory = Directory(
      '${support.path}${Platform.pathSeparator}local_subtitles',
    );
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    return directory;
  }

  String _extension(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0) return '.txt';
    final extension = name.substring(dot).toLowerCase();
    return _supportedExtensions.contains(extension) ? extension : '.txt';
  }
}
