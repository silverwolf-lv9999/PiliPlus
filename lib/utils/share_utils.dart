import 'dart:io' show Platform;

import 'package:PiliPlus/utils/device_utils.dart';
import 'package:PiliPlus/utils/platform_utils.dart';
import 'package:PiliPlus/utils/utils.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show Rect;
import 'package:flutter_smart_dialog/flutter_smart_dialog.dart';
import 'package:share_plus/share_plus.dart';

abstract final class ShareUtils {
  static bool? _isIpad;
  static Future<bool> get isIpad async {
    if (!Platform.isIOS) return false;
    return _isIpad ??= (await DeviceInfoPlugin().iosInfo).model
        .toLowerCase()
        .contains('ipad');
  }

  static Future<Rect?> get sharePositionOrigin async {
    if (await isIpad) {
      final screenSize = DeviceUtils.size;
      return Rect.fromLTRB(0, 0, screenSize.width, screenSize.height / 2);
    }
    return null;
  }

  /// 移动端弹出「复制链接 / 分享到其他应用」选项；桌面端直接复制。
  static Future<void> shareText(String text) async {
    if (PlatformUtils.isDesktop) {
      Utils.copyText(text);
      return;
    }
    final shareToApp = await _showShareOptions();
    if (shareToApp == null) return;
    if (shareToApp) {
      await _systemShare(text);
    } else {
      Utils.copyText(text);
    }
  }

  /// 直接唤起系统分享（用于入口本身已带「复制链接」的场景，避免二级弹窗）。
  static Future<void> shareToApp(String text) async {
    if (PlatformUtils.isDesktop) {
      Utils.copyText(text);
      return;
    }
    await _systemShare(text);
  }

  static Future<void> _systemShare(String text) async {
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, sharePositionOrigin: await sharePositionOrigin),
      );
    } catch (e) {
      SmartDialog.showToast(e.toString());
    }
  }

  /// 返回 null 表示取消；false=复制链接，true=分享到其他应用。
  static Future<bool?> _showShareOptions() {
    return SmartDialog.show<bool>(
      animationType: SmartAnimationType.centerScale_otherSlide,
      builder: (context) {
        final theme = Theme.of(context);
        return SimpleDialog(
          clipBehavior: Clip.hardEdge,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            ListTile(
              dense: true,
              minLeadingWidth: 0,
              leading: const Icon(Icons.copy_rounded, size: 19),
              title: Text(
                '复制链接',
                style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
              ),
              onTap: () => SmartDialog.dismiss(result: false),
            ),
            ListTile(
              dense: true,
              minLeadingWidth: 0,
              leading: const Icon(Icons.share_outlined, size: 19),
              title: Text(
                '分享到其他应用',
                style: TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
              ),
              onTap: () => SmartDialog.dismiss(result: true),
            ),
          ],
        );
      },
    );
  }
}