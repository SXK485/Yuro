import 'dart:async';
import 'package:asmrapp/utils/logger.dart';
import 'package:asmrapp/core/audio/models/subtitle.dart';
import 'package:asmrapp/core/subtitle/i_subtitle_service.dart';
import 'package:get_it/get_it.dart';
import 'package:asmrapp/core/subtitle/subtitle_loader.dart';
import 'package:asmrapp/core/subtitle/managers/subtitle_state_manager.dart';

class SubtitleService implements ISubtitleService {
  final SubtitleLoader _subtitleLoader;
  final _stateManager = SubtitleStateManager();

  SubtitleService({SubtitleLoader? subtitleLoader})
      : _subtitleLoader = subtitleLoader ?? GetIt.I<SubtitleLoader>();

  @override
  Stream<SubtitleList?> get subtitleStream => _stateManager.subtitleStream;

  @override
  Stream<Subtitle?> get currentSubtitleStream =>
      _stateManager.currentSubtitleStream;

  @override
  Subtitle? get currentSubtitle => _stateManager.currentSubtitle;

  @override
  Future<void> loadSubtitle(String url) async {
    try {
      clearSubtitle();
      final subtitleList = await _subtitleLoader.loadSubtitleContent(url);
      _stateManager.setSubtitleList(subtitleList);
    } catch (e) {
      AppLogger.debug('字幕加载失败: $e');
      clearSubtitle();
      rethrow;
    }
  }

  @override
  Future<void> loadLocalSubtitle(String content, {String name = ''}) async {
    // 先解析、后替换：格式不对时保留当前字幕，不把用户正在看的字幕清空。
    final subtitleList = _subtitleLoader.parseSubtitleContent(content);
    if (subtitleList == null || subtitleList.subtitles.isEmpty) {
      throw const FormatException('字幕文件里没有可用条目');
    }
    _stateManager.setSubtitleList(subtitleList);
    AppLogger.debug(
      '本地外挂字幕已加载: ${name.isEmpty ? '未命名' : name} '
      '(${subtitleList.subtitles.length} 条)',
    );
  }

  @override
  void updatePosition(Duration position) {
    _stateManager.updatePosition(position);
  }

  @override
  void dispose() {
    _stateManager.dispose();
  }

  @override
  SubtitleList? get subtitleList => _stateManager.subtitleList;

  @override
  void clearSubtitle() {
    _stateManager.clear();
  }

  @override
  Stream<SubtitleWithState?> get currentSubtitleWithStateStream =>
      _stateManager.currentSubtitleWithStateStream;

  @override
  SubtitleWithState? get currentSubtitleWithState =>
      _stateManager.currentSubtitleWithState;
}
