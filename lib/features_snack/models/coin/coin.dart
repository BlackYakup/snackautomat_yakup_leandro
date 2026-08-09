import 'package:freezed_annotation/freezed_annotation.dart';

part 'coin.freezed.dart';
part 'coin.g.dart';

@freezed
abstract class Coin with _$Coin {
  const factory Coin({
    required int id,
    required int quantity,
    required int denomination
  }) = _Coin;

  factory Coin.fromJson(Map<String, dynamic> json) =>
    _$CoinFromJson(json);
}