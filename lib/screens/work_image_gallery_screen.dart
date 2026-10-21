import 'package:asmrapp/core/utils/work_image_utils.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

/// 打开作品图片全屏查看器；`initial` 指定从哪一张开始。
Future<void> openWorkImageGallery(
  BuildContext context, {
  required List<WorkImage> images,
  WorkImage? initial,
}) async {
  if (images.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('这个作品没有可查看的图片')),
    );
    return;
  }
  var initialIndex = 0;
  if (initial != null) {
    final found = images.indexWhere((image) => image.url == initial.url);
    if (found >= 0) initialIndex = found;
  }
  await Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: true,
      transitionDuration: const Duration(milliseconds: 220),
      reverseTransitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (_, __, ___) => WorkImageGalleryScreen(
        images: images,
        initialIndex: initialIndex,
      ),
      transitionsBuilder: (_, animation, __, child) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1).animate(
              CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    ),
  );
}

class WorkImageGalleryScreen extends StatefulWidget {
  final List<WorkImage> images;
  final int initialIndex;

  const WorkImageGalleryScreen({
    super.key,
    required this.images,
    this.initialIndex = 0,
  });

  @override
  State<WorkImageGalleryScreen> createState() => _WorkImageGalleryScreenState();
}

class _WorkImageGalleryScreenState extends State<WorkImageGalleryScreen> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _overlayVisible = true;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex.clamp(0, widget.images.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: Colors.black,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    // 退出全屏查看后恢复系统栏。
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  void _close() {
    if (_closing) return;
    _closing = true;
    Navigator.of(context).maybePop();
  }

  bool _handleOverscroll(OverscrollNotification notification) {
    // 在第一张图继续向右拖 → 返回。只在明显拖动时触发，避免轻碰误退出。
    if (_currentIndex == 0 && notification.overscroll < -12) {
      _close();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final image = widget.images[_currentIndex];
    return Scaffold(
      backgroundColor: Colors.black,
      body: NotificationListener<OverscrollNotification>(
        onNotification: _handleOverscroll,
        child: Stack(
          children: [
            PhotoViewGallery.builder(
              pageController: _pageController,
              // Bouncing 才能在第一张继续右拖时产生 overscroll，用于滑动返回。
              scrollPhysics: const BouncingScrollPhysics(),
              itemCount: widget.images.length,
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              onPageChanged: (index) => setState(() => _currentIndex = index),
              loadingBuilder: (_, __) => const Center(
                child: CircularProgressIndicator(color: Colors.white54),
              ),
              builder: (context, index) {
                final item = widget.images[index];
                return PhotoViewGalleryPageOptions(
                  imageProvider: CachedNetworkImageProvider(item.url),
                  minScale: PhotoViewComputedScale.contained,
                  initialScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.contained * 4,
                  onTapUp: (_, __, ___) {
                    setState(() => _overlayVisible = !_overlayVisible);
                  },
                  errorBuilder: (_, __, ___) => const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_outlined,
                            color: Colors.white54, size: 42),
                        SizedBox(height: 8),
                        Text('图片加载失败', style: TextStyle(color: Colors.white54)),
                      ],
                    ),
                  ),
                );
              },
            ),
            // iOS 式左缘右滑返回；PageView 的 overscroll 是第二重保障。
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 24,
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onHorizontalDragEnd: (details) {
                  if ((details.primaryVelocity ?? 0) > 250) _close();
                },
              ),
            ),
            IgnorePointer(
              ignoring: !_overlayVisible,
              child: AnimatedOpacity(
                opacity: _overlayVisible ? 1 : 0,
                duration: const Duration(milliseconds: 160),
                child: Stack(
                  children: [
                    _topBar(),
                    _bottomCaption(image),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black54, Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
              tooltip: '返回',
              onPressed: _close,
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black45,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_currentIndex + 1} / ${widget.images.length}',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
            ),
            const Spacer(),
            const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }

  Widget _bottomCaption(WorkImage image) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black54, Colors.transparent],
          ),
        ),
        child: SafeArea(
          top: false,
          child: Text(
            image.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 12.5),
          ),
        ),
      ),
    );
  }
}
