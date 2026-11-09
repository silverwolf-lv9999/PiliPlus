import 'package:PiliPlus/models/common/account_type.dart';
import 'package:PiliPlus/utils/accounts/account.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:hive_ce/hive.dart';

class LoginAccountAdapter extends TypeAdapter<LoginAccount> {
  @override
  final int typeId = 9;

  @override
  LoginAccount read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    // 兼容 fork 旧数据：field 4 曾用于 bool(replyAccountInitialized)，
    // 上游同一位置是 String(buvid)。按运行时类型区分，避免升级后读取崩溃。
    final field4 = fields[4];
    return LoginAccount(
      fields[0] as DefaultCookieJar,
      fields[1] as String?,
      fields[2] as String?,
      (fields[3] as List?)?.cast<AccountType>().toSet(),
      field4 is String ? field4 : null,
      fields[5] as bool? ?? (field4 is bool ? field4 : true),
    );
  }

  @override
  void write(BinaryWriter writer, LoginAccount obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.cookieJar)
      ..writeByte(1)
      ..write(obj.accessKey)
      ..writeByte(2)
      ..write(obj.refresh)
      ..writeByte(3)
      ..write(obj.type.toList())
      ..writeByte(4)
      ..write(obj.buvid)
      ..writeByte(5)
      ..write(obj.replyAccountInitialized);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LoginAccountAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
