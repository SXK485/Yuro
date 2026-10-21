import 'package:asmrapp/data/models/files/child.dart';
import 'package:asmrapp/data/models/files/files.dart';

/// 作品文件树里的一张图片，保留所在目录用于标题/排序。
class WorkImage {
  final Child file;
  final String path;

  const WorkImage({required this.file, required this.path});

  String get title => file.title ?? '';
  String get url => file.mediaDownloadUrl ?? '';
}

const _imageExtensions = ['.jpg', '.jpeg', '.png', '.webp', '.gif'];
const _audioExtensions = ['.mp3', '.wav'];

bool isImageFile(Child file) {
  final type = (file.type ?? '').toLowerCase();
  if (type == 'image' || _imageExtensions.contains('.$type')) return true;
  final name = (file.title ?? '').toLowerCase();
  return _imageExtensions.any(name.endsWith);
}

bool isAudioFile(Child file) {
  final type = (file.type ?? '').toLowerCase();
  if (type == 'audio') return true;
  final name = (file.title ?? '').toLowerCase();
  return _audioExtensions.any(name.endsWith);
}

/// 递归收集作品文件树里的所有可显示图片（jpg/jpeg/png/webp/gif）。
List<WorkImage> collectWorkImages(Files files) {
  final images = <WorkImage>[];

  void walk(List<Child>? children, String prefix) {
    for (final child in children ?? const <Child>[]) {
      final name = child.title ?? '';
      if (child.type == 'folder') {
        walk(child.children, '$prefix$name/');
        continue;
      }
      if (!isImageFile(child) || (child.mediaDownloadUrl ?? '').isEmpty) {
        continue;
      }
      images.add(WorkImage(file: child, path: '$prefix$name'));
    }
  }

  walk(files.children, '');
  return images;
}
