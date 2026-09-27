import 'package:PiliPlus/utils/extension/iterable_ext.dart';

enum AudioQuality {
  auto(0, '自动选择最佳音质'),
  u_100010(100010, '100010'),
  u_100009(100009, '100009'),
  u_100008(100008, '100008'),
  hiRes(30251, 'Hi-Res无损'),
  dolby_30250(30250, '杜比全景声'),
  dolby_30255(30255, '杜比全景声'),
  k192(30280, '192K'),
  k132(30232, '132K'),
  k64(30216, '64K'),
  ;

  final int code;
  final String desc;

  const AudioQuality(this.code, this.desc);

  /// 「自动选择最佳音质」项的内部标识码，不参与实际音轨匹配。
  static const int autoCode = 0;

  static final _codeMap = {for (final i in values) i.code: i};

  static AudioQuality fromCode(int code) => _codeMap[code]!;

  /// 设置页「默认音质 / 蜂窝网络音质」可选项。
  /// 将「自动选择最佳音质」置于列表最前，其余保持原有顺序。
  static final List<AudioQuality> defaultAudioQualityOptions = [
    auto,
    u_100010,
    u_100009,
    u_100008,
    hiRes,
    dolby_30250,
    dolby_30255,
    k192,
    k132,
    k64,
  ];

  /// 自动选择时的优先级：高级音效优先，其后按码率从高到低。
  /// Hi-Res → 杜比全景声(30250/30255) → 192K → 132K → 64K。
  /// 三种高级音效互斥，同一视频最多只有一种，故其内部顺序不影响结果。
  static const List<int> autoPriority = [
    30251, // Hi-Res 无损
    30250, // 杜比全景声
    30255, // 杜比全景声
    30280, // 192K
    30232, // 132K
    30216, // 64K
  ];

  /// 依据当前视频实际可用的音轨 [availableIds]，挑选要使用的音质码。
  ///
  /// - [preferQa] 为 [autoCode]（即用户选了「自动选择最佳音质」）时，
  ///   按 [autoPriority] 顺序返回第一个可用的音质码；都不可用时回退到
  ///   原有的「不超过默认值中最高者」逻辑，保证不劣于改动前。
  /// - [preferQa] 为具体音质码时，行为与改动前完全一致。
  static int selectAudioQuality(
    int preferQa,
    Iterable<int> availableIds, {
    int fallbackQa = 30280,
  }) {
    final ids = availableIds.toList();
    if (ids.isEmpty) return preferQa;
    if (preferQa == autoCode) {
      for (final code in autoPriority) {
        if (ids.contains(code)) return code;
      }
      // 无任何已知音轨：取码率最高者
      var best = ids.first;
      for (final id in ids) {
        if (id > best) best = id;
      }
      return best;
    }
    int closest = ids.findClosestTarget(
      (e) => e <= preferQa,
      (a, b) => a > b ? a : b,
    );
    if (!ids.contains(preferQa) && ids.any((e) => e > preferQa)) {
      closest = fallbackQa;
    }
    return closest;
  }
}

