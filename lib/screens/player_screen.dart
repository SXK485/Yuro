import 'package:asmrapp/core/platform/lyric_overlay_manager.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:asmrapp/presentation/viewmodels/player_viewmodel.dart';
import 'package:asmrapp/widgets/player/player_controls.dart';
import 'package:asmrapp/widgets/player/player_progress.dart';
import 'package:asmrapp/widgets/player/player_cover.dart';
import 'package:asmrapp/screens/detail_screen.dart';
import 'package:asmrapp/widgets/lyrics/components/player_lyric_view.dart';
import 'package:asmrapp/widgets/player/player_work_info.dart';
import 'package:asmrapp/core/platform/wakelock_controller.dart';

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key});

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  bool _showLyrics = false;
  bool _canSwitchView = true;
  late final PlayerViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = GetIt.I<PlayerViewModel>();
  }

  Future<void> _showSubtitleSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final localName = _viewModel.localSubtitleName;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.file_open_outlined),
                title: const Text('加载本地外挂字幕'),
                subtitle: const Text('支持 SRT / VTT / LRC，会记住到当前音轨'),
                onTap: () async {
                  Navigator.of(sheetContext).pop();
                  await _loadLocalSubtitle();
                },
              ),
              if (localName != null)
                ListTile(
                  leading: const Icon(Icons.restore),
                  title: const Text('恢复自动字幕'),
                  subtitle: Text('当前：$localName'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _restoreAutoSubtitle();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _loadLocalSubtitle() async {
    try {
      final name = await _viewModel.pickAndLoadLocalSubtitle();
      if (!mounted || name == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已加载本地字幕：$name')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('字幕加载失败：$error')),
      );
    }
  }

  Future<void> _restoreAutoSubtitle() async {
    try {
      await _viewModel.clearLocalSubtitle();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已恢复自动字幕')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('恢复自动字幕失败：$error')),
      );
    }
  }

  Widget _buildContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOutQuart,
      switchOutCurve: Curves.easeInQuart,
      transitionBuilder: (Widget child, Animation<double> animation) {
        final isLyrics = (child as dynamic).key == const ValueKey('lyrics');

        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0, isLyrics ? 0.1 : -0.1),
              end: Offset.zero,
            ).animate(animation),
            child: ScaleTransition(
              scale: Tween<double>(
                begin: 0.95,
                end: 1.0,
              ).animate(animation),
              child: child,
            ),
          ),
        );
      },
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          alignment: Alignment.center,
          children: <Widget>[
            ...previousChildren,
            if (currentChild != null) currentChild,
          ],
        );
      },
      child: _showLyrics
          ? LayoutBuilder(
              key: const ValueKey('lyrics'),
              builder: (context, constraints) {
                return PlayerLyricView(
                  onScrollStateChanged: (canSwitch) {
                    setState(() {
                      _canSwitchView = canSwitch;
                    });
                  },
                );
              },
            )
          : ListenableBuilder(
              listenable: _viewModel,
              builder: (context, _) {
                return Column(
                  key: const ValueKey('cover'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Hero(
                        tag: 'mini-player-cover',
                        child: PlayerCover(
                          coverUrl: _viewModel.currentTrackInfo?.coverUrl,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        children: [
                          Hero(
                            tag: 'player-title',
                            child: Material(
                              color: Colors.transparent,
                              child: Text(
                                _viewModel.currentTrackInfo?.title ?? '未在播放',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_viewModel.currentTrackInfo?.artist != null)
                            Text(
                              _viewModel.currentTrackInfo!.artist,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyLarge
                                  ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurface
                                        .withOpacity(0.7),
                                  ),
                              textAlign: TextAlign.center,
                            ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    PlayerWorkInfo(context: _viewModel.currentContext),
                  ],
                );
              },
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final lyricManager = GetIt.I<LyricOverlayManager>();
    final wakeLockController = GetIt.I<WakeLockController>();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.expand_more),
          onPressed: () {
            Navigator.of(context).pop();
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              final currentWork = _viewModel.currentContext?.work;
              if (currentWork != null) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => DetailScreen(
                      work: currentWork,
                      fromPlayer: true,
                    ),
                  ),
                );
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.subtitles_outlined),
            tooltip: '外挂字幕',
            onPressed: _showSubtitleSheet,
          ),
          IconButton(
            icon: Icon(
              lyricManager.isShowing ? Icons.lyrics : Icons.lyrics_outlined,
            ),
            onPressed: () => lyricManager.toggle(context),
          ),
          ListenableBuilder(
            listenable: wakeLockController,
            builder: (context, _) {
              return IconButton(
                icon: Icon(
                  wakeLockController.enabled
                      ? Icons.lightbulb
                      : Icons.lightbulb_outline,
                ),
                tooltip: wakeLockController.enabled ? '关闭屏幕常亮' : '开启屏幕常亮',
                onPressed: () => wakeLockController.toggle(),
              );
            },
          ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (_canSwitchView) {
                    setState(() {
                      _showLyrics = !_showLyrics;
                    });
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: _buildContent(),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 32),
              child: Column(
                children: const [
                  PlayerProgress(),
                  SizedBox(height: 8),
                  SizedBox(height: 8),
                  PlayerControls(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
