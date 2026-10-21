import 'package:asmrapp/core/subtitle/parsers/lrc_parser.dart';
import 'package:asmrapp/core/subtitle/parsers/srt_parser.dart';
import 'package:asmrapp/core/subtitle/parsers/subtitle_parser_factory.dart';
import 'package:asmrapp/core/subtitle/parsers/vtt_parser.dart';
import 'package:asmrapp/core/subtitle/utils/subtitle_matcher.dart';
import 'package:asmrapp/data/models/files/child.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SubtitleParserFactory', () {
    test('detects VTT, SRT and LRC', () {
      expect(
        SubtitleParserFactory.getParser(
          'WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nhello\n',
        ),
        isA<VttParser>(),
      );
      expect(
        SubtitleParserFactory.getParser(
          '1\n00:00:01,000 --> 00:00:02,000\nhello\n',
        ),
        isA<SrtParser>(),
      );
      expect(
        SubtitleParserFactory.getParser('[00:01.00]hello\n'),
        isA<LrcParser>(),
      );
    });

    test('returns null for unsupported text', () {
      expect(SubtitleParserFactory.getParser('plain text only'), isNull);
    });
  });

  group('SubtitleMatcher', () {
    test('supports SRT as a sidecar format', () {
      expect(SubtitleMatcher.supportedFormats, contains('.srt'));
      expect(SubtitleMatcher.isSubtitleFile('subtitle.SRT'), isTrue);
      expect(
        SubtitleMatcher.getPossibleSubtitleNames('track.mp3'),
        containsAll(['track.srt', 'track.mp3.srt']),
      );
    });

    test('finds the same-name SRT before other formats', () {
      final subtitle = Child(
        type: 'srt',
        title: 'track.srt',
        mediaDownloadUrl: 'https://example.com/track.srt',
      );
      final other = Child(
        type: 'vtt',
        title: 'track.vtt',
        mediaDownloadUrl: 'https://example.com/track.vtt',
      );
      final found = SubtitleMatcher.findMatchingSubtitle(
        'track.mp3',
        [other, subtitle],
      );
      expect(found?.title, 'track.srt');
    });

    test('does not match a different track', () {
      final subtitle = Child(
        type: 'srt',
        title: 'other.srt',
        mediaDownloadUrl: 'https://example.com/other.srt',
      );
      expect(
        SubtitleMatcher.findMatchingSubtitle('track.mp3', [subtitle]),
        isNull,
      );
    });
  });
}
