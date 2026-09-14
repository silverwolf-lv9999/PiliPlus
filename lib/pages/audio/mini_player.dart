import 'dart:math' show max;

import 'package:PiliPlus/common/widgets/image/network_img_layer.dart';
import 'package:PiliPlus/pages/audio/controller.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// 应用内可拖动的音频悬浮窗控制条。
///
/// 需作为 `Stack` 的直接子 widget 放置；不可用时返回占位 widget 以消除命中。
class AudioMiniPlayer extends StatefulWidget {
  const AudioMiniPlayer({super.key});

  @override
  State<AudioMiniPlayer> createState() => _AudioMiniPlayerState();
}

class _AudioMiniPlayerState extends State<AudioMiniPlayer> {
  static const double _w = 200;
  static const double _h = 52;
  static const double _margin = 8;

  /// 拖拽后的左上角位置（初次构建时依据屏幕尺寸初始化）。
  Offset? _origin;
  Offset _drag = Offset.zero;

  @override
  Widget build(BuildContext context) {
    if (!PlatformUtils.isMobile) return const SizedBox.shrink();

    return Obx(() {
      // 订阅独立的“会话激活”信号，避免顶层 widget 首次构建时会话尚未
      // 建立、后续却又不重建的问题。
      if (!AudioController.audioSessionActive.value) {
        return const SizedBox.shrink();
      }
      final controller = AudioController.maybeInstance;
      if (controller == null) return const SizedBox.shrink();
      if (!controller.enableFloat.value) return const SizedBox.shrink();
      final item = controller.audioItem.value;
      if (item == null) return const SizedBox.shrink();

      final size = MediaQuery.sizeOf(context);
      final bottomPad = MediaQuery.paddingOf(context).bottom;
      _origin ??= Offset(
        size.width - _w - _margin,
        size.height - _h - _margin - bottomPad,
      );
      final maxDx = max(0.0, size.width - _w);
      final maxDy = max(0.0, size.height - _h - bottomPad);
      final left = (_origin!.dx + _drag.dx).clamp(0.0, maxDx);
      final top = (_origin!.dy + _drag.dy).clamp(0.0, maxDy);

      return Positioned(
        left: left,
        top: top,
        child: GestureDetector(
          onPanStart: (_) => _drag = Offset.zero,
          onPanUpdate: (d) => setState(() => _drag += d.delta),
          onPanEnd: (_) => setState(() {
            _origin = Offset(left, top);
            _drag = Offset.zero;
          }),
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(_h / 2),
            color: ColorScheme.of(context).surfaceContainerHigh,
            child: SizedBox(
              width: _w,
              height: _h,
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: controller.reopen,
                      borderRadius: BorderRadius.horizontal(
                        left: const Radius.circular(_h / 2),
                      ),
                      child: Row(
                        children: [
                          _cover(controller),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _title(controller),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _iconBtn(
                    context,
                    Icons.skip_previous,
                    controller.onHeadsetPrevious,
                  ),
                  _iconBtn(
                    context,
                    controller.playing.value ? Icons.pause : Icons.play_arrow,
                    controller.playOrPause,
                  ),
                  _iconBtn(
                    context,
                    Icons.skip_next,
                    controller.onHeadsetNext,
                  ),
                  const SizedBox(width: 6),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _cover(AudioController c) {
    final cover = c.audioItem.value?.arc.cover;
    if (cover == null || cover.isEmpty) {
      return Container(
        width: _h,
        height: _h,
        decoration: BoxDecoration(
          color: ColorScheme.of(context).surfaceContainerHighest,
          borderRadius: BorderRadius.horizontal(
            left: const Radius.circular(_h / 2),
          ),
        ),
        child: const Icon(Icons.music_note),
      );
    }
    return NetworkImgLayer(
      src: cover,
      width: _h,
      height: _h,
      borderRadius: BorderRadius.horizontal(
        left: const Radius.circular(_h / 2),
      ),
    );
  }

  String _title(AudioController c) => c.audioItem.value?.arc.title ?? '';

  Widget _iconBtn(
    BuildContext context,
    IconData icon,
    VoidCallback? onTap,
  ) {
    return IconButton(
      visualDensity: VisualDensity.compact,
      iconSize: 22,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: _h),
      onPressed: onTap,
      icon: Icon(icon),
    );
  }
}