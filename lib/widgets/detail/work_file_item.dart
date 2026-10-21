import 'package:flutter/material.dart';
import 'package:asmrapp/core/utils/work_image_utils.dart';
import 'package:asmrapp/data/models/files/child.dart';
import 'package:asmrapp/utils/logger.dart';
import 'package:asmrapp/utils/file_size_formatter.dart';

class WorkFileItem extends StatelessWidget {
  final Child file;
  final double indentation;
  final Function(Child file)? onFileTap;

  const WorkFileItem({
    super.key,
    required this.file,
    required this.indentation,
    this.onFileTap,
  });

  @override
  Widget build(BuildContext context) {
    final bool isAudio = isAudioFile(file);
    final bool isImage = isImageFile(file);
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: EdgeInsets.only(left: indentation),
      child: ListTile(
        title: Text(
          file.title ?? '',
          style: TextStyle(
            color: colorScheme.onSurface,
          ),
        ),
        subtitle: Text(
          FileSizeFormatter.format(file.size),
          style: TextStyle(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        leading: Icon(
          isAudio
              ? Icons.audio_file
              : isImage
                  ? Icons.image
                  : Icons.insert_drive_file,
          color: isAudio
              ? Colors.green
              : isImage
                  ? Colors.deepPurpleAccent
                  : Colors.blue,
        ),
        dense: true,
        onTap: (isAudio || isImage)
            ? () {
                AppLogger.debug(
                  '点击${isImage ? '图片' : '音频'}文件: ${file.title}',
                );
                onFileTap?.call(file);
              }
            : null,
      ),
    );
  }
}
