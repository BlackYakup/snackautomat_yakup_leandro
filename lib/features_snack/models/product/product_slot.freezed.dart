// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'product_slot.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ProductSlot {

 int? get id;@JsonKey(name: 'product_id') int get productId;@JsonKey(name: 'row_label') String get rowLabel;@JsonKey(name: 'column_number') int get columnNumber;@JsonKey(name: 'stock_quantity') int get stockQuantity;@JsonKey(name: 'max_capacity') int get maxCapacity;
/// Create a copy of ProductSlot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProductSlotCopyWith<ProductSlot> get copyWith => _$ProductSlotCopyWithImpl<ProductSlot>(this as ProductSlot, _$identity);

  /// Serializes this ProductSlot to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProductSlot&&(identical(other.id, id) || other.id == id)&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.rowLabel, rowLabel) || other.rowLabel == rowLabel)&&(identical(other.columnNumber, columnNumber) || other.columnNumber == columnNumber)&&(identical(other.stockQuantity, stockQuantity) || other.stockQuantity == stockQuantity)&&(identical(other.maxCapacity, maxCapacity) || other.maxCapacity == maxCapacity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,productId,rowLabel,columnNumber,stockQuantity,maxCapacity);

@override
String toString() {
  return 'ProductSlot(id: $id, productId: $productId, rowLabel: $rowLabel, columnNumber: $columnNumber, stockQuantity: $stockQuantity, maxCapacity: $maxCapacity)';
}


}

/// @nodoc
abstract mixin class $ProductSlotCopyWith<$Res>  {
  factory $ProductSlotCopyWith(ProductSlot value, $Res Function(ProductSlot) _then) = _$ProductSlotCopyWithImpl;
@useResult
$Res call({
 int? id,@JsonKey(name: 'product_id') int productId,@JsonKey(name: 'row_label') String rowLabel,@JsonKey(name: 'column_number') int columnNumber,@JsonKey(name: 'stock_quantity') int stockQuantity,@JsonKey(name: 'max_capacity') int maxCapacity
});




}
/// @nodoc
class _$ProductSlotCopyWithImpl<$Res>
    implements $ProductSlotCopyWith<$Res> {
  _$ProductSlotCopyWithImpl(this._self, this._then);

  final ProductSlot _self;
  final $Res Function(ProductSlot) _then;

/// Create a copy of ProductSlot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? productId = null,Object? rowLabel = null,Object? columnNumber = null,Object? stockQuantity = null,Object? maxCapacity = null,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,productId: null == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as int,rowLabel: null == rowLabel ? _self.rowLabel : rowLabel // ignore: cast_nullable_to_non_nullable
as String,columnNumber: null == columnNumber ? _self.columnNumber : columnNumber // ignore: cast_nullable_to_non_nullable
as int,stockQuantity: null == stockQuantity ? _self.stockQuantity : stockQuantity // ignore: cast_nullable_to_non_nullable
as int,maxCapacity: null == maxCapacity ? _self.maxCapacity : maxCapacity // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ProductSlot].
extension ProductSlotPatterns on ProductSlot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProductSlot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProductSlot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProductSlot value)  $default,){
final _that = this;
switch (_that) {
case _ProductSlot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProductSlot value)?  $default,){
final _that = this;
switch (_that) {
case _ProductSlot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int? id, @JsonKey(name: 'product_id')  int productId, @JsonKey(name: 'row_label')  String rowLabel, @JsonKey(name: 'column_number')  int columnNumber, @JsonKey(name: 'stock_quantity')  int stockQuantity, @JsonKey(name: 'max_capacity')  int maxCapacity)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProductSlot() when $default != null:
return $default(_that.id,_that.productId,_that.rowLabel,_that.columnNumber,_that.stockQuantity,_that.maxCapacity);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int? id, @JsonKey(name: 'product_id')  int productId, @JsonKey(name: 'row_label')  String rowLabel, @JsonKey(name: 'column_number')  int columnNumber, @JsonKey(name: 'stock_quantity')  int stockQuantity, @JsonKey(name: 'max_capacity')  int maxCapacity)  $default,) {final _that = this;
switch (_that) {
case _ProductSlot():
return $default(_that.id,_that.productId,_that.rowLabel,_that.columnNumber,_that.stockQuantity,_that.maxCapacity);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int? id, @JsonKey(name: 'product_id')  int productId, @JsonKey(name: 'row_label')  String rowLabel, @JsonKey(name: 'column_number')  int columnNumber, @JsonKey(name: 'stock_quantity')  int stockQuantity, @JsonKey(name: 'max_capacity')  int maxCapacity)?  $default,) {final _that = this;
switch (_that) {
case _ProductSlot() when $default != null:
return $default(_that.id,_that.productId,_that.rowLabel,_that.columnNumber,_that.stockQuantity,_that.maxCapacity);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProductSlot extends ProductSlot {
  const _ProductSlot({this.id, @JsonKey(name: 'product_id') required this.productId, @JsonKey(name: 'row_label') required this.rowLabel, @JsonKey(name: 'column_number') required this.columnNumber, @JsonKey(name: 'stock_quantity') required this.stockQuantity, @JsonKey(name: 'max_capacity') this.maxCapacity = 10}): super._();
  factory _ProductSlot.fromJson(Map<String, dynamic> json) => _$ProductSlotFromJson(json);

@override final  int? id;
@override@JsonKey(name: 'product_id') final  int productId;
@override@JsonKey(name: 'row_label') final  String rowLabel;
@override@JsonKey(name: 'column_number') final  int columnNumber;
@override@JsonKey(name: 'stock_quantity') final  int stockQuantity;
@override@JsonKey(name: 'max_capacity') final  int maxCapacity;

/// Create a copy of ProductSlot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProductSlotCopyWith<_ProductSlot> get copyWith => __$ProductSlotCopyWithImpl<_ProductSlot>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProductSlotToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProductSlot&&(identical(other.id, id) || other.id == id)&&(identical(other.productId, productId) || other.productId == productId)&&(identical(other.rowLabel, rowLabel) || other.rowLabel == rowLabel)&&(identical(other.columnNumber, columnNumber) || other.columnNumber == columnNumber)&&(identical(other.stockQuantity, stockQuantity) || other.stockQuantity == stockQuantity)&&(identical(other.maxCapacity, maxCapacity) || other.maxCapacity == maxCapacity));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,productId,rowLabel,columnNumber,stockQuantity,maxCapacity);

@override
String toString() {
  return 'ProductSlot(id: $id, productId: $productId, rowLabel: $rowLabel, columnNumber: $columnNumber, stockQuantity: $stockQuantity, maxCapacity: $maxCapacity)';
}


}

/// @nodoc
abstract mixin class _$ProductSlotCopyWith<$Res> implements $ProductSlotCopyWith<$Res> {
  factory _$ProductSlotCopyWith(_ProductSlot value, $Res Function(_ProductSlot) _then) = __$ProductSlotCopyWithImpl;
@override @useResult
$Res call({
 int? id,@JsonKey(name: 'product_id') int productId,@JsonKey(name: 'row_label') String rowLabel,@JsonKey(name: 'column_number') int columnNumber,@JsonKey(name: 'stock_quantity') int stockQuantity,@JsonKey(name: 'max_capacity') int maxCapacity
});




}
/// @nodoc
class __$ProductSlotCopyWithImpl<$Res>
    implements _$ProductSlotCopyWith<$Res> {
  __$ProductSlotCopyWithImpl(this._self, this._then);

  final _ProductSlot _self;
  final $Res Function(_ProductSlot) _then;

/// Create a copy of ProductSlot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? productId = null,Object? rowLabel = null,Object? columnNumber = null,Object? stockQuantity = null,Object? maxCapacity = null,}) {
  return _then(_ProductSlot(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,productId: null == productId ? _self.productId : productId // ignore: cast_nullable_to_non_nullable
as int,rowLabel: null == rowLabel ? _self.rowLabel : rowLabel // ignore: cast_nullable_to_non_nullable
as String,columnNumber: null == columnNumber ? _self.columnNumber : columnNumber // ignore: cast_nullable_to_non_nullable
as int,stockQuantity: null == stockQuantity ? _self.stockQuantity : stockQuantity // ignore: cast_nullable_to_non_nullable
as int,maxCapacity: null == maxCapacity ? _self.maxCapacity : maxCapacity // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
