import 'package:asmrapp/core/subtitle/subtitle_loader.dart';
import 'package:asmrapp/core/subtitle/subtitle_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SubtitleService local subtitles', () {
    test('loads SRT content and updates current subtitle', () async {
      final service = SubtitleService(subtitleLoader: SubtitleLoader());
      addTearDown(service.dispose);

      await service.loadLocalSubtitle(
        '1\n00:00:01,000 --> 00:00:03,000\n本地字幕\n',
        name: 'local.srt',
      );

      expect(service.subtitleList?.subtitles, hasLength(1));
      service.updatePosition(const Duration(seconds: 2));
      expect(service.currentSubtitle?.text, '本地字幕');
    });

    test('rejects unsupported content without clearing the current list',
        () async {
      final service = SubtitleService(subtitleLoader: SubtitleLoader());
      addTearDown(service.dispose);

      await service.loadLocalSubtitle(
        '1\n00:00:01,000 --> 00:00:02,000\n保留\n',
        name: 'ok.srt',
      );

      await expectLater(
        service.loadLocalSubtitle('这不是字幕', name: 'bad.txt'),
        throwsA(isA<Exception>()),
      );
      expect(service.subtitleList?.subtitles, hasLength(1));
      expect(service.subtitleList?.subtitles.single.text, '保留');
    });

    test('accepts VTT and LRC too', () async {
      final service = SubtitleService(subtitleLoader: SubtitleLoader());
      addTearDown(service.dispose);

      await service.loadLocalSubtitle(
        'WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nVTT 字幕\n',
      );
      expect(service.subtitleList?.subtitles.single.text, 'VTT 字幕');

      await service.loadLocalSubtitle('[00:03.00]LRC 字幕\n');
      expect(service.subtitleList?.subtitles.single.text, 'LRC 字幕');
    });
  });
}
