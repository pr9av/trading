// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'holding.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class HoldingAdapter extends TypeAdapter<Holding> {
  @override
  final int typeId = 1;

  @override
  Holding read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Holding(
      symbol: fields[0] as String,
      tradingSymbol: fields[1] as String,
      exchange: fields[2] as String,
      quantity: fields[3] as int,
      averagePrice: fields[4] as double,
      lastTransactionDate: fields[5] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, Holding obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.symbol)
      ..writeByte(1)
      ..write(obj.tradingSymbol)
      ..writeByte(2)
      ..write(obj.exchange)
      ..writeByte(3)
      ..write(obj.quantity)
      ..writeByte(4)
      ..write(obj.averagePrice)
      ..writeByte(5)
      ..write(obj.lastTransactionDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is HoldingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
