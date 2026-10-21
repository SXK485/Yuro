import 'package:asmrapp/core/audio/models/subtitle.dart';
import 'package:asmrapp/core/subtitle/parsers/subtitle_parser.dart';

/// SRT（SubRip）解析器。
///
/// Yuro 原有的自动匹配只认服务器上的 VTT/LRC；本 fork 增加本地外挂字幕，
/// 而 ASMR 字幕工具最常导出的就是 SRT，所以这里补齐解析。
class SrtParser extends BaseSubtitleParser {
  // SRT 时间戳允许逗号或点作毫秒分隔；小时允许一位（`0:00:01,000`）。
  static final _timeLineRegex = RegExp(
    r'^\s*(\d{1,2}):(\d{2}):(\d{2})[,.](\d{1,3})\s*-->\s*'
    r'(\d{1,2}):(\d{2}):(\d{2})[,.](\d{1,3})',
    multiLine: true,
  );
  static final _htmlTagRegex = RegExp(r'<[^>]+>');
  static final _assOverrideRegex = RegExp(r'\{\\[^}]*\}');

  @override
  bool canParse(String content) {
    final normalized = _normalize(content);
    // VTT 也使用 `-->` 和点号毫秒；必须让 VttParser 优先，别把 VTT 当 SRT。
    if (normalized.toUpperCase().startsWith('WEBVTT')) return false;
    return _timeLineRegex.hasMatch(normalized);
  }

  @override
  SubtitleList doParse(String content) {
    final lines = _normalize(content).split('\n');
    final subtitles = <Subtitle>[];
    var index = 0;

    while (index < lines.length) {
      final match = _timeLineRegex.firstMatch(lines[index]);
      if (match == null) {
        index++;
        continue;
      }

      final start = _duration(
        match.group(1)!,
        match.group(2)!,
        match.group(3)!,
        match.group(4)!,
      );
      final end = _duration(
        match.group(5)!,
        match.group(6)!,
        match.group(7)!,
        match.group(8)!,
      );
      index++;

      final textLines = <String>[];
      while (index < lines.length) {
        final line = lines[index].trim();
        if (line.isEmpty) break;
        // 容错：有些字幕省略了条目之间的空行，下一条时间轴直接开始。
        if (_timeLineRegex.hasMatch(line)) break;
        textLines.add(line);
        index++;
      }

      final text = _cleanText(textLines.join('\n'));
      if (text.isNotEmpty && end > start) {
        subtitles.add(
          Subtitle(
            start: start,
            end: end,
            text: text,
            index: subtitles.length,
          ),
        );
      }
    }

    return SubtitleList(subtitles);
  }

  String _normalize(String content) {
    return content
        .replaceFirst('\uFEFF', '')
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();
  }

  String _cleanText(String text) {
    return text
        .replaceAll(_assOverrideRegex, '')
        .replaceAll(_htmlTagRegex, '')
        .trim();
  }

  Duration _duration(
    String hours,
    String minutes,
    String seconds,
    String millis,
  ) {
    return Duration(
      hours: int.parse(hours),
      minutes: int.parse(minutes),
      seconds: int.parse(seconds),
      milliseconds: int.parse(millis.padRight(3, '0')),
    );
  }
}
