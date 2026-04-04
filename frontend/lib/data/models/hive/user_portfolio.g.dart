// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_portfolio.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserPortfolioAdapter extends TypeAdapter<UserPortfolio> {
  @override
  final int typeId = 0;

  @override
  UserPortfolio read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserPortfolio(
      virtualBalance: fields[0] as double,
      totalInvested: fields[1] as double,
      createdDate: fields[2] as DateTime,
      initialBalance: fields[3] as double,
    );
  }

  @override
  void write(BinaryWriter writer, UserPortfolio obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.virtualBalance)
      ..writeByte(1)
      ..write(obj.totalInvested)
      ..writeByte(2)
      ..write(obj.createdDate)
      ..writeByte(3)
      ..write(obj.initialBalance);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserPortfolioAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
