import 'package:asmrapp/core/utils/work_image_utils.dart';
import 'package:asmrapp/data/models/files/child.dart';
import 'package:asmrapp/data/models/files/files.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('work image detection', () {
    test('detects jpg/png by extension and type', () {
      expect(
        isImageFile(
            Child(type: 'image', title: 'cover', mediaDownloadUrl: 'u')),
        isTrue,
      );
      expect(
        isImageFile(Child(type: 'file', title: 'A.JPG', mediaDownloadUrl: 'u')),
        isTrue,
      );
      expect(
        isImageFile(Child(type: 'file', title: 'b.png', mediaDownloadUrl: 'u')),
        isTrue,
      );
      expect(
        isImageFile(
            Child(type: 'file', title: 'track.mp3', mediaDownloadUrl: 'u')),
        isFalse,
      );
    });

    test('detects audio tracks', () {
      expect(
        isAudioFile(
            Child(type: 'audio', title: 'track.mp3', mediaDownloadUrl: 'u')),
        isTrue,
      );
      expect(
        isAudioFile(
            Child(type: 'file', title: 'track.wav', mediaDownloadUrl: 'u')),
        isTrue,
      );
      expect(
        isAudioFile(
            Child(type: 'file', title: 'cover.jpg', mediaDownloadUrl: 'u')),
        isFalse,
      );
    });
  });

  group('collectWorkImages', () {
    test('walks folders and keeps relative paths in tree order', () {
      final files = Files(
        type: 'folder',
        children: [
          Child(
            type: 'folder',
            title: 'イラスト',
            children: [
              Child(
                type: 'file',
                title: '01.jpg',
                mediaDownloadUrl: 'https://example.com/01.jpg',
              ),
              Child(
                type: 'file',
                title: '02.png',
                mediaDownloadUrl: 'https://example.com/02.png',
              ),
            ],
          ),
          Child(
            type: 'file',
            title: 'track.mp3',
            mediaDownloadUrl: 'https://example.com/track.mp3',
          ),
          Child(
            type: 'file',
            title: '03.webp',
            mediaDownloadUrl: 'https://example.com/03.webp',
          ),
        ],
      );

      final images = collectWorkImages(files);

      expect(
          images.map((image) => image.title), ['01.jpg', '02.png', '03.webp']);
      expect(images[0].path, 'イラスト/01.jpg');
      expect(images[2].path, '03.webp');
    });

    test('ignores images without a download url', () {
      final files = Files(
        type: 'folder',
        children: [
          Child(type: 'file', title: 'broken.jpg'),
          Child(
            type: 'file',
            title: 'ok.jpg',
            mediaDownloadUrl: 'https://example.com/ok.jpg',
          ),
        ],
      );
      expect(collectWorkImages(files).map((image) => image.title), ['ok.jpg']);
    });
  });
}
