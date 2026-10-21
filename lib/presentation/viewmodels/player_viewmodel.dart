import 'package:asmrapp/core/audio/events/playback_event.dart';
import 'package:asmrapp/core/audio/models/audio_track_info.dart';
import 'package:asmrapp/core/audio/models/playback_context.dart';
import 'package:asmrapp/core/subtitle/i_subtitle_service.dart';
import 'package:asmrapp/core/subtitle/storage/local_subtitle_repository.dart';
import 'package:asmrapp/utils/logger.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:asmrapp/core/audio/i_audio_player_service.dart';
import 'package:asmrapp/core/audio/models/subtitle.dart';
import 'dart:async';
import 'dart:convert';
import 'package:asmrapp/core/subtitle/subtitle_loader.dart';
import 'package:asmrapp/core/audio/events/playback_event_hub.dart';

class PlayerViewModel extends ChangeNotifier {
  final IAudioPlayerService _audioService;
  final PlaybackEventHub _eventHub;
  final ISubtitleService _subtitleService;
  final LocalSubtitleRepository _localSubtitles;
  final _subtitleLoader = SubtitleLoader();

  bool _isPlaying = false;
  Duration? _position;
  Duration? _duration;
  Subtitle? _currentSubtitle;
  String? _localSubtitleName;
  String? _savedLocalSubtitleName;

  final List<StreamSubscription> _subscriptions = [];

  static const _tag = 'PlayerViewModel';

  PlayerViewModel({
    required IAudioPlayerService audioService,
    required PlaybackEventHub eventHub,
    required ISubtitleService subtitleService,
    required LocalSubtitleRepository localSubtitleRepository,
  })  : _audioService = audioService,
        _eventHub = eventHub,
        _subtitleService = subtitleService,
        _localSubtitles = localSubtitleRepository {
    _initStreams();
    _requestInitialState();
  }

  void _initStreams() {
    // 播放状态事件
    _subscriptions.add(
      _eventHub.playbackState.listen(
        (event) {
          _isPlaying = event.state.playing;
          _position = event.position;
          _duration = event.duration;
          notifyListeners();
        },
        onError: (error) => debugPrint('$_tag - 播放状态流错误: $error'),
      ),
    );

    // 音轨变更事件
    _subscriptions.add(
      _eventHub.trackChange.listen(
        (event) {
          notifyListeners();
        },
        onError: (error) => debugPrint('$_tag - 音轨变更流错误: $error'),
      ),
    );

    // 播放进度事件
    _subscriptions.add(
      _eventHub.playbackProgress.listen(
        (event) {
          _position = event.position;
          if (_position != null) {
            _subtitleService.updatePosition(_position!);
          }
          notifyListeners();
        },
        onError: (error) => debugPrint('$_tag - 播放进度流错误: $error'),
      ),
    );

    // 上下文变更事件
    _subscriptions.add(
      _eventHub.contextChange.listen(
        (event) async {
          await _loadSubtitleIfAvailable(event.context);
          // 如果有保存的位置，在字幕加载完成后更新位置
          if (_position != null) {
            _subtitleService.updatePosition(_position!);
          }
        },
        onError: (error) => debugPrint('$_tag - 上下文流错误: $error'),
      ),
    );

    // 使用新添加的 initialState 流
    _subscriptions.add(
      _eventHub.initialState.listen(
        (event) {
          if (event.track != null) {
            notifyListeners();
          }
          if (event.context != null) {
            _loadSubtitleIfAvailable(event.context!);
          }
        },
        onError: (error) => debugPrint('$_tag - 初始状态流错误: $error'),
      ),
    );

    _initSubtitleStreams();
  }

  void _initSubtitleStreams() {
    _subscriptions.add(
      _subtitleService.subtitleStream.listen(
        (subtitleList) {
          debugPrint('$_tag - 字幕列表更新: ${subtitleList != null ? '已加载' : '未加载'}');
        },
        onError: (error) => debugPrint('$_tag - 字幕流错误: $error'),
      ),
    );

    _subscriptions.add(
      _subtitleService.currentSubtitleStream.listen(
        (subtitle) {
          _currentSubtitle = subtitle;
          notifyListeners();
        },
        onError: (error) => debugPrint('$_tag - 当前字幕流错误: $error'),
      ),
    );
  }

  bool get isPlaying => _isPlaying;
  Duration? get position => _position;
  Duration? get duration => _duration;
  Subtitle? get currentSubtitle => _currentSubtitle;

  Future<void> playPause() async {
    if (_isPlaying) {
      _audioService.pause();
    } else {
      _audioService.resume();
    }
  }

  Future<void> seek(Duration position) async {
    await _audioService.seek(position);
  }

  Future<void> previous() async {
    await _audioService.previous();
  }

  Future<void> next() async {
    await _audioService.next();
  }

  Future<void> stop() async {
    await _audioService.stop();
    _position = Duration.zero;
    notifyListeners();
  }

  @override
  void dispose() {
    for (var subscription in _subscriptions) {
      subscription.cancel();
    }
    _subscriptions.clear();
    super.dispose();
  }

  // 请求初始状态
  void _requestInitialState() {
    _eventHub.emit(RequestInitialStateEvent());
  }

  // 修改字幕加载方法，返回 Future 以便等待加载完成。
  // 本地外挂字幕优先于服务器自动匹配：用户手动选过就以他的选择为准。
  Future<void> _loadSubtitleIfAvailable(PlaybackContext context) async {
    final local = await _localSubtitles.load(
      workId: context.work.id,
      workTitle: context.work.title,
      audioTitle: context.currentFile.title,
    );
    if (local != null) {
      try {
        await _subtitleService.loadLocalSubtitle(local.content,
            name: local.name);
        _localSubtitleName = local.name;
        _savedLocalSubtitleName = local.name;
        return;
      } catch (e) {
        // 字幕文件损坏/格式不再受支持：清掉记录并回退服务器字幕。
        AppLogger.debug('本地外挂字幕加载失败，回退服务器字幕: $e');
        _savedLocalSubtitleName = null;
        await _localSubtitles.clear(
          workId: context.work.id,
          workTitle: context.work.title,
          audioTitle: context.currentFile.title,
        );
      }
    }
    _localSubtitleName = null;
    if (local == null) _savedLocalSubtitleName = null;
    await _loadServerSubtitle(context);
  }

  /// 尝试加载服务器自动匹配的字幕。返回是否真的加载到了。
  Future<bool> _loadServerSubtitle(PlaybackContext context) async {
    final subtitleFile =
        _subtitleLoader.findSubtitleFile(context.currentFile, context.files);
    // 有些文件节点只有 stream URL；两者都试，避免“找到了文件但没 URL”导致静默清空。
    final url = subtitleFile?.mediaDownloadUrl ?? subtitleFile?.mediaStreamUrl;
    if (url == null || url.isEmpty) {
      _subtitleService.clearSubtitle();
      AppLogger.debug('未找到可用的服务器字幕，清除现有字幕');
      return false;
    }
    try {
      await _subtitleService.loadSubtitle(url);
      return true;
    } catch (e) {
      // 服务器字幕 404/网络失败时也要把本地字幕清掉，并给出“没有自动字幕”的结果。
      AppLogger.debug('服务器字幕加载失败: $e');
      _subtitleService.clearSubtitle();
      return false;
    }
  }

  AudioTrackInfo? get currentTrackInfo => _audioService.currentTrack;
  PlaybackContext? get currentContext => _audioService.currentContext;
  String? get localSubtitleName => _localSubtitleName;
  String? get savedLocalSubtitleName => _savedLocalSubtitleName;
  bool get hasLocalSubtitle => _localSubtitleName != null;
  bool get hasSavedLocalSubtitle => _savedLocalSubtitleName != null;

  /// 选择并加载本地外挂字幕（SRT / VTT / LRC），并记住到当前音轨。
  Future<String?> pickAndLoadLocalSubtitle() async {
    final context = currentContext;
    if (context == null) {
      throw StateError('当前没有正在播放的音轨');
    }
    final picked = await FilePicker.platform.pickFiles(
      // 不用 FileType.custom：iOS 对 .lrc 这类自定义扩展名没有稳定 UTI。
      // 先让系统文件选择器打开，再在 Dart 侧校验扩展名。
      type: FileType.any,
      withData: true,
      allowMultiple: false,
    );
    if (picked == null || picked.files.isEmpty) return null;

    final file = picked.files.single;
    final extension = (file.extension ??
            (file.name.contains('.') ? file.name.split('.').last : ''))
        .toLowerCase();
    if (!const {'srt', 'vtt', 'lrc'}.contains(extension)) {
      throw Exception('只支持 SRT / VTT / LRC 字幕文件');
    }
    final bytes = file.bytes;
    if (bytes == null) {
      throw Exception('无法读取字幕文件：文件选择器没有返回内容');
    }
    final content = utf8.decode(bytes, allowMalformed: true);
    // 先走同一套解析校验；失败时不会覆盖当前字幕。
    await _subtitleService.loadLocalSubtitle(content, name: file.name);
    _localSubtitleName = file.name;
    try {
      await _localSubtitles.save(
        workId: context.work.id,
        workTitle: context.work.title,
        audioTitle: context.currentFile.title,
        name: file.name,
        content: content,
      );
      _savedLocalSubtitleName = file.name;
    } catch (e) {
      // 保存失败不影响本次播放，但下次进入不会自动恢复。
      AppLogger.debug('本地外挂字幕保存失败: $e');
    }
    notifyListeners();
    return file.name;
  }

  /// 临时切换到服务器自动字幕；**保留**已保存的本地字幕，之后可一键恢复。
  /// 返回服务器字幕是否真的加载成功。
  Future<bool> useServerSubtitle() async {
    final context = currentContext;
    if (context == null) {
      _localSubtitleName = null;
      _subtitleService.clearSubtitle();
      notifyListeners();
      return false;
    }
    _localSubtitleName = null;
    _subtitleService.clearSubtitle();
    final restored = await _loadServerSubtitle(context);
    notifyListeners();
    return restored;
  }

  /// 重新加载此前保存的本地外挂字幕（不需要重新选文件）。
  Future<bool> useSavedLocalSubtitle() async {
    final context = currentContext;
    if (context == null) return false;
    final local = await _localSubtitles.load(
      workId: context.work.id,
      workTitle: context.work.title,
      audioTitle: context.currentFile.title,
    );
    if (local == null) {
      _savedLocalSubtitleName = null;
      notifyListeners();
      return false;
    }
    try {
      await _subtitleService.loadLocalSubtitle(local.content, name: local.name);
      _localSubtitleName = local.name;
      _savedLocalSubtitleName = local.name;
      notifyListeners();
      return true;
    } catch (e) {
      AppLogger.debug('恢复本地字幕失败: $e');
      _savedLocalSubtitleName = null;
      await _localSubtitles.clear(
        workId: context.work.id,
        workTitle: context.work.title,
        audioTitle: context.currentFile.title,
      );
      notifyListeners();
      return false;
    }
  }

  /// 彻底删除当前音轨的本地字幕记录；如果正在显示本地字幕，则回退服务器字幕。
  Future<void> forgetLocalSubtitle() async {
    final context = currentContext;
    if (context != null) {
      try {
        await _localSubtitles.clear(
          workId: context.work.id,
          workTitle: context.work.title,
          audioTitle: context.currentFile.title,
        );
      } catch (e) {
        AppLogger.debug('删除本地字幕记录失败: $e');
      }
    }
    _savedLocalSubtitleName = null;
    if (_localSubtitleName != null) {
      _localSubtitleName = null;
      _subtitleService.clearSubtitle();
      if (context != null) {
        await _loadServerSubtitle(context);
      }
    }
    notifyListeners();
  }

  Future<void> seekToNextLyric() async {
    final currentSubtitle = _subtitleService.currentSubtitleWithState;
    final subtitleList = _subtitleService.subtitleList;

    if (currentSubtitle != null && subtitleList != null) {
      final nextSubtitle = currentSubtitle.subtitle.getNext(subtitleList);
      if (nextSubtitle != null) {
        await seek(nextSubtitle.start);
      }
    }
  }

  Future<void> seekToPreviousLyric() async {
    final currentSubtitle = _subtitleService.currentSubtitleWithState;
    final subtitleList = _subtitleService.subtitleList;

    if (currentSubtitle != null && subtitleList != null) {
      final previousSubtitle =
          currentSubtitle.subtitle.getPrevious(subtitleList);
      if (previousSubtitle != null) {
        await seek(previousSubtitle.start);
      }
    }
  }
}
