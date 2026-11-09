part of 'base_quality.dart';

class AudioQuality extends BaseQuality {
  /// 音质优先级，数值越大音质越高。未知音质为 0。
  final int rank;

  const AudioQuality(super.code, super.desc, {this.rank = 0});

  /// 「自动选择最佳音质」项的内部标识码，不参与实际音轨匹配。
  static const int autoCode = 0;

  /// 「自动选择最佳音质」：rank 高于所有具体音质，
  /// 因而按 rank 匹配时必然命中当前视频可用的最高音质。
  static const AudioQuality auto = .new(autoCode, '自动选择最佳音质', rank: 1000);

  // 历史遗留的高位音质码，实际不会有对应音轨；
  // 选中时按 rank 自然回落到可用最高音质。
  static const AudioQuality u_100010 = .new(100010, '100010', rank: 90);
  static const AudioQuality u_100009 = .new(100009, '100009', rank: 85);
  static const AudioQuality u_100008 = .new(100008, '100008', rank: 80);

  static const AudioQuality hiRes = .new(30251, 'Hi-Res无损', rank: 60);
  static const AudioQuality dolby_30255 = .new(30255, '杜比全景声', rank: 50);
  static const AudioQuality dolby_30250 = .new(30250, '杜比全景声', rank: 50);
  static const AudioQuality k192 = .new(30280, '192K', rank: 40);
  static const AudioQuality k132 = .new(30232, '132K', rank: 30);
  static const AudioQuality k64 = .new(30216, '64K', rank: 20);

  static const List<AudioQuality> values = [
    hiRes,
    dolby_30255,
    dolby_30250,
    k192,
    k132,
    k64,
  ];

  /// 设置页「默认音质 / 蜂窝网络音质」可选项。
  /// 「自动选择最佳音质」置于列表最前。
  static const List<AudioQuality> defaultAudioQualityOptions = [
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

  static final _codeMap = {
    for (final i in defaultAudioQualityOptions) i.code: i,
  };

  AudioQuality.fromId(super.code) : rank = 0, super.fromId();

  factory AudioQuality.fromCode(int code) => _codeMap[code] ?? .fromId(code);
}
