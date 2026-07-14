// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'coin.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Coin {

 int get id; int get quantity; int get denomination;
/// Create a copy of Coin
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CoinCopyWith<Coin> get copyWith => _$CoinCopyWithImpl<Coin>(this as Coin, _$identity);

  /// Serializes this Coin to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Coin&&(identical(other.id, id) || other.id == id)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.denomination, denomination) || other.denomination == denomination));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,quantity,denomination);

@override
String toString() {
  return 'Coin(id: $id, quantity: $quantity, denomination: $denomination)';
}


}

/// @nodoc
abstract mixin class $CoinCopyWith<$Res>  {
  factory $CoinCopyWith(Coin value, $Res Function(Coin) _then) = _$CoinCopyWithImpl;
@useResult
$Res call({
 int id, int quantity, int denomination
});




}
/// @nodoc
class _$CoinCopyWithImpl<$Res>
    implements $CoinCopyWith<$Res> {
  _$CoinCopyWithImpl(this._self, this._then);

  final Coin _self;
  final $Res Function(Coin) _then;

/// Create a copy of Coin
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? quantity = null,Object? denomination = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,denomination: null == denomination ? _self.denomination : denomination // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [Coin].
extension CoinPatterns on Coin {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Coin value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Coin() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Coin value)  $default,){
final _that = this;
switch (_that) {
case _Coin():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Coin value)?  $default,){
final _that = this;
switch (_that) {
case _Coin() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int id,  int quantity,  int denomination)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Coin() when $default != null:
return $default(_that.id,_that.quantity,_that.denomination);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int id,  int quantity,  int denomination)  $default,) {final _that = this;
switch (_that) {
case _Coin():
return $default(_that.id,_that.quantity,_that.denomination);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int id,  int quantity,  int denomination)?  $default,) {final _that = this;
switch (_that) {
case _Coin() when $default != null:
return $default(_that.id,_that.quantity,_that.denomination);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Coin implements Coin {
  const _Coin({required this.id, required this.quantity, required this.denomination});
  factory _Coin.fromJson(Map<String, dynamic> json) => _$CoinFromJson(json);

@override final  int id;
@override final  int quantity;
@override final  int denomination;

/// Create a copy of Coin
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CoinCopyWith<_Coin> get copyWith => __$CoinCopyWithImpl<_Coin>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$CoinToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Coin&&(identical(other.id, id) || other.id == id)&&(identical(other.quantity, quantity) || other.quantity == quantity)&&(identical(other.denomination, denomination) || other.denomination == denomination));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,quantity,denomination);

@override
String toString() {
  return 'Coin(id: $id, quantity: $quantity, denomination: $denomination)';
}


}

/// @nodoc
abstract mixin class _$CoinCopyWith<$Res> implements $CoinCopyWith<$Res> {
  factory _$CoinCopyWith(_Coin value, $Res Function(_Coin) _then) = __$CoinCopyWithImpl;
@override @useResult
$Res call({
 int id, int quantity, int denomination
});




}
/// @nodoc
class __$CoinCopyWithImpl<$Res>
    implements _$CoinCopyWith<$Res> {
  __$CoinCopyWithImpl(this._self, this._then);

  final _Coin _self;
  final $Res Function(_Coin) _then;

/// Create a copy of Coin
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? quantity = null,Object? denomination = null,}) {
  return _then(_Coin(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,quantity: null == quantity ? _self.quantity : quantity // ignore: cast_nullable_to_non_nullable
as int,denomination: null == denomination ? _self.denomination : denomination // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
