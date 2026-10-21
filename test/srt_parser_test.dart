import 'package:asmrapp/core/subtitle/parsers/srt_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SrtParser', () {
    test('parses BOM, CRLF, comma milliseconds and multiline text', () {
      const content = '\uFEFF1\r\n'
          '00:00:01,250 --> 00:00:03,500\r\n'
          '<i>こんにちは</i>\r\n'
          '\r\n'
          '2\r\n'
          '00:00:04.000 --> 00:00:05.200\r\n'
          '二行目\r\n'
          '続き\r\n';

      final list = SrtParser().parse(content);

      expect(list.subtitles, hasLength(2));
      expect(list.subtitles[0].start,
          const Duration(seconds: 1, milliseconds: 250));
      expect(
          list.subtitles[0].end, const Duration(seconds: 3, milliseconds: 500));
      expect(list.subtitles[0].text, 'こんにちは');
      expect(list.subtitles[1].start, const Duration(seconds: 4));
      expect(
          list.subtitles[1].end, const Duration(seconds: 5, milliseconds: 200));
      expect(list.subtitles[1].text, '二行目\n続き');
      expect(list.subtitles[1].index, 1);
    });

    test('supports hours, short millis and ASS override tags', () {
      const content = '1\n'
          '1:02:03,4 --> 1:02:05,600\n'
          '{\\an8}一行目\n';

      final list = SrtParser().parse(content);

      expect(list.subtitles, hasLength(1));
      expect(
        list.subtitles.single.start,
        const Duration(hours: 1, minutes: 2, seconds: 3, milliseconds: 400),
      );
      expect(list.subtitles.single.text, '一行目');
    });

    test('skips malformed blocks and invalid time ranges', () {
      const content = '1\n'
          'not a timestamp\n'
          'ignored\n'
          '\n'
          '2\n'
          '00:00:05,000 --> 00:00:04,000\n'
          'end before start\n'
          '\n'
          '3\n'
          '00:00:06,000 --> 00:00:07,000\n'
          'kept\n';

      final list = SrtParser().parse(content);

      expect(list.subtitles, hasLength(1));
      expect(list.subtitles.single.text, 'kept');
    });

    test('does not parse VTT or LRC as SRT', () {
      const vtt = 'WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nhello\n';
      const lrc = '[00:01.00]hello\n';
      expect(SrtParser().canParse(vtt), isFalse);
      expect(SrtParser().canParse(lrc), isFalse);
    });
  });
}
