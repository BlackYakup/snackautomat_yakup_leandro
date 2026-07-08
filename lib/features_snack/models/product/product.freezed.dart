// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'product.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Product {

 String get name; int? get id;@JsonKey(name: 'price_cents') int get priceCents;@JsonKey(name: 'stock_quantity') int get stockQuantity;@ProductCategoryConverter() ProductCategory get category;@JsonKey(name: 'row_label') String get rowLabel;@JsonKey(name: 'column_number') int get columnNumber;@JsonKey(name: 'slot_width') int get slotWidth;
/// Create a copy of Product
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProductCopyWith<Product> get copyWith => _$ProductCopyWithImpl<Product>(this as Product, _$identity);

  /// Serializes this Product to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Product&&(identical(other.name, name) || other.name == name)&&(identical(other.id, id) || other.id == id)&&(identical(other.priceCents, priceCents) || other.priceCents == priceCents)&&(identical(other.stockQuantity, stockQuantity) || other.stockQuantity == stockQuantity)&&(identical(other.category, category) || other.category == category)&&(identical(other.rowLabel, rowLabel) || other.rowLabel == rowLabel)&&(identical(other.columnNumber, columnNumber) || other.columnNumber == columnNumber)&&(identical(other.slotWidth, slotWidth) || other.slotWidth == slotWidth));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,id,priceCents,stockQuantity,category,rowLabel,columnNumber,slotWidth);

@override
String toString() {
  return 'Product(name: $name, id: $id, priceCents: $priceCents, stockQuantity: $stockQuantity, category: $category, rowLabel: $rowLabel, columnNumber: $columnNumber, slotWidth: $slotWidth)';
}


}

/// @nodoc
abstract mixin class $ProductCopyWith<$Res>  {
  factory $ProductCopyWith(Product value, $Res Function(Product) _then) = _$ProductCopyWithImpl;
@useResult
$Res call({
 String name, int? id,@JsonKey(name: 'price_cents') int priceCents,@JsonKey(name: 'stock_quantity') int stockQuantity,@ProductCategoryConverter() ProductCategory category,@JsonKey(name: 'row_label') String rowLabel,@JsonKey(name: 'column_number') int columnNumber,@JsonKey(name: 'slot_width') int slotWidth
});




}
/// @nodoc
class _$ProductCopyWithImpl<$Res>
    implements $ProductCopyWith<$Res> {
  _$ProductCopyWithImpl(this._self, this._then);

  final Product _self;
  final $Res Function(Product) _then;

/// Create a copy of Product
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? name = null,Object? id = freezed,Object? priceCents = null,Object? stockQuantity = null,Object? category = null,Object? rowLabel = null,Object? columnNumber = null,Object? slotWidth = null,}) {
  return _then(_self.copyWith(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,priceCents: null == priceCents ? _self.priceCents : priceCents // ignore: cast_nullable_to_non_nullable
as int,stockQuantity: null == stockQuantity ? _self.stockQuantity : stockQuantity // ignore: cast_nullable_to_non_nullable
as int,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as ProductCategory,rowLabel: null == rowLabel ? _self.rowLabel : rowLabel // ignore: cast_nullable_to_non_nullable
as String,columnNumber: null == columnNumber ? _self.columnNumber : columnNumber // ignore: cast_nullable_to_non_nullable
as int,slotWidth: null == slotWidth ? _self.slotWidth : slotWidth // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [Product].
extension ProductPatterns on Product {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Product value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Product() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Product value)  $default,){
final _that = this;
switch (_that) {
case _Product():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Product value)?  $default,){
final _that = this;
switch (_that) {
case _Product() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String name,  int? id, @JsonKey(name: 'price_cents')  int priceCents, @JsonKey(name: 'stock_quantity')  int stockQuantity, @ProductCategoryConverter()  ProductCategory category, @JsonKey(name: 'row_label')  String rowLabel, @JsonKey(name: 'column_number')  int columnNumber, @JsonKey(name: 'slot_width')  int slotWidth)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Product() when $default != null:
return $default(_that.name,_that.id,_that.priceCents,_that.stockQuantity,_that.category,_that.rowLabel,_that.columnNumber,_that.slotWidth);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String name,  int? id, @JsonKey(name: 'price_cents')  int priceCents, @JsonKey(name: 'stock_quantity')  int stockQuantity, @ProductCategoryConverter()  ProductCategory category, @JsonKey(name: 'row_label')  String rowLabel, @JsonKey(name: 'column_number')  int columnNumber, @JsonKey(name: 'slot_width')  int slotWidth)  $default,) {final _that = this;
switch (_that) {
case _Product():
return $default(_that.name,_that.id,_that.priceCents,_that.stockQuantity,_that.category,_that.rowLabel,_that.columnNumber,_that.slotWidth);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String name,  int? id, @JsonKey(name: 'price_cents')  int priceCents, @JsonKey(name: 'stock_quantity')  int stockQuantity, @ProductCategoryConverter()  ProductCategory category, @JsonKey(name: 'row_label')  String rowLabel, @JsonKey(name: 'column_number')  int columnNumber, @JsonKey(name: 'slot_width')  int slotWidth)?  $default,) {final _that = this;
switch (_that) {
case _Product() when $default != null:
return $default(_that.name,_that.id,_that.priceCents,_that.stockQuantity,_that.category,_that.rowLabel,_that.columnNumber,_that.slotWidth);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Product extends Product {
  const _Product({required this.name, this.id, @JsonKey(name: 'price_cents') required this.priceCents, @JsonKey(name: 'stock_quantity') required this.stockQuantity, @ProductCategoryConverter() required this.category, @JsonKey(name: 'row_label') required this.rowLabel, @JsonKey(name: 'column_number') required this.columnNumber, @JsonKey(name: 'slot_width') required this.slotWidth}): super._();
  factory _Product.fromJson(Map<String, dynamic> json) => _$ProductFromJson(json);

@override final  String name;
@override final  int? id;
@override@JsonKey(name: 'price_cents') final  int priceCents;
@override@JsonKey(name: 'stock_quantity') final  int stockQuantity;
@override@ProductCategoryConverter() final  ProductCategory category;
@override@JsonKey(name: 'row_label') final  String rowLabel;
@override@JsonKey(name: 'column_number') final  int columnNumber;
@override@JsonKey(name: 'slot_width') final  int slotWidth;

/// Create a copy of Product
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProductCopyWith<_Product> get copyWith => __$ProductCopyWithImpl<_Product>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProductToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Product&&(identical(other.name, name) || other.name == name)&&(identical(other.id, id) || other.id == id)&&(identical(other.priceCents, priceCents) || other.priceCents == priceCents)&&(identical(other.stockQuantity, stockQuantity) || other.stockQuantity == stockQuantity)&&(identical(other.category, category) || other.category == category)&&(identical(other.rowLabel, rowLabel) || other.rowLabel == rowLabel)&&(identical(other.columnNumber, columnNumber) || other.columnNumber == columnNumber)&&(identical(other.slotWidth, slotWidth) || other.slotWidth == slotWidth));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,name,id,priceCents,stockQuantity,category,rowLabel,columnNumber,slotWidth);

@override
String toString() {
  return 'Product(name: $name, id: $id, priceCents: $priceCents, stockQuantity: $stockQuantity, category: $category, rowLabel: $rowLabel, columnNumber: $columnNumber, slotWidth: $slotWidth)';
}


}

/// @nodoc
abstract mixin class _$ProductCopyWith<$Res> implements $ProductCopyWith<$Res> {
  factory _$ProductCopyWith(_Product value, $Res Function(_Product) _then) = __$ProductCopyWithImpl;
@override @useResult
$Res call({
 String name, int? id,@JsonKey(name: 'price_cents') int priceCents,@JsonKey(name: 'stock_quantity') int stockQuantity,@ProductCategoryConverter() ProductCategory category,@JsonKey(name: 'row_label') String rowLabel,@JsonKey(name: 'column_number') int columnNumber,@JsonKey(name: 'slot_width') int slotWidth
});




}
/// @nodoc
class __$ProductCopyWithImpl<$Res>
    implements _$ProductCopyWith<$Res> {
  __$ProductCopyWithImpl(this._self, this._then);

  final _Product _self;
  final $Res Function(_Product) _then;

/// Create a copy of Product
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? name = null,Object? id = freezed,Object? priceCents = null,Object? stockQuantity = null,Object? category = null,Object? rowLabel = null,Object? columnNumber = null,Object? slotWidth = null,}) {
  return _then(_Product(
name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int?,priceCents: null == priceCents ? _self.priceCents : priceCents // ignore: cast_nullable_to_non_nullable
as int,stockQuantity: null == stockQuantity ? _self.stockQuantity : stockQuantity // ignore: cast_nullable_to_non_nullable
as int,category: null == category ? _self.category : category // ignore: cast_nullable_to_non_nullable
as ProductCategory,rowLabel: null == rowLabel ? _self.rowLabel : rowLabel // ignore: cast_nullable_to_non_nullable
as String,columnNumber: null == columnNumber ? _self.columnNumber : columnNumber // ignore: cast_nullable_to_non_nullable
as int,slotWidth: null == slotWidth ? _self.slotWidth : slotWidth // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
