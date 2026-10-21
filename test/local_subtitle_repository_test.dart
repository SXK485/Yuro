import 'dart:io';

import 'package:asmrapp/core/subtitle/storage/local_subtitle_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late LocalSubtitleRepository repository;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    tempDir = await Directory.systemTemp.createTemp('yuro_local_subtitle_');
    repository = LocalSubtitleRepository(
      prefs,
      supportDirectory: () async => tempDir,
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('saves, loads and clears per work/audio', () async {
    await repository.save(
      workId: 123,
      workTitle: 'work',
      audioTitle: 'track01.mp3',
      name: 'track01.srt',
      content: '1\n00:00:01,000 --> 00:00:02,000\nhello\n',
    );

    final loaded = await repository.load(
      workId: 123,
      workTitle: 'work',
      audioTitle: 'track01.mp3',
    );
    expect(loaded, isNotNull);
    expect(loaded!.name, 'track01.srt');
    expect(loaded.content, contains('hello'));

    // 同一作品的不同音轨互不串位。
    expect(
      await repository.load(
        workId: 123,
        workTitle: 'work',
        audioTitle: 'track02.mp3',
      ),
      isNull,
    );
    // 不同作品即使音轨同名也不串位。
    expect(
      await repository.load(
        workId: 456,
        workTitle: 'other',
        audioTitle: 'track01.mp3',
      ),
      isNull,
    );

    await repository.clear(
      workId: 123,
      workTitle: 'work',
      audioTitle: 'track01.mp3',
    );
    expect(
      await repository.load(
        workId: 123,
        workTitle: 'work',
        audioTitle: 'track01.mp3',
      ),
      isNull,
    );
  });

  test('falls back to work title when work id is missing', () async {
    await repository.save(
      workTitle: 'title-only',
      audioTitle: 'a.mp3',
      name: 'a.vtt',
      content: 'WEBVTT\n\n00:00:01.000 --> 00:00:02.000\nhi\n',
    );
    final loaded = await repository.load(
      workTitle: 'title-only',
      audioTitle: 'a.mp3',
    );
    expect(loaded?.name, 'a.vtt');
  });

  test('drops metadata when the subtitle file disappeared', () async {
    await repository.save(
      workId: 1,
      audioTitle: 'gone.mp3',
      name: 'gone.srt',
      content: '1\n00:00:01,000 --> 00:00:02,000\nbye\n',
    );
    final files = Directory('${tempDir.path}/local_subtitles').listSync();
    for (final file in files) {
      await file.delete();
    }
    expect(
      await repository.load(workId: 1, audioTitle: 'gone.mp3'),
      isNull,
    );
    // 第二次读取仍然是 null，不会残留坏记录。
    expect(
      await repository.load(workId: 1, audioTitle: 'gone.mp3'),
      isNull,
    );
  });

  test('storage key is stable and isolates audio titles', () {
    final a = repository.storageKey(workId: 1, audioTitle: 'a.mp3');
    final b = repository.storageKey(workId: 1, audioTitle: 'a.mp3');
    final c = repository.storageKey(workId: 1, audioTitle: 'b.mp3');
    expect(a, b);
    expect(a, isNot(c));
  });
}
