import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:snackautomat_yakup_leandro/features_snack/constants/vending_coin_config.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/placed_product.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product_category.dart';
import 'package:snackautomat_yakup_leandro/features_snack/models/product/product_slot.dart';
import 'package:snackautomat_yakup_leandro/features_snack/repositories/coin_repository.dart';
import 'package:snackautomat_yakup_leandro/features_snack/repositories/db_creater.dart';
import 'package:snackautomat_yakup_leandro/features_snack/repositories/product_repository.dart';
import 'package:snackautomat_yakup_leandro/features_snack/repositories/transaction_repository.dart';
import 'package:snackautomat_yakup_leandro/features_snack/services/change_calculator.dart';
import 'package:snackautomat_yakup_leandro/features_snack/services/double_slot_layout.dart';
import 'package:snackautomat_yakup_leandro/features_snack/services/local_file_cache.dart';
import 'package:snackautomat_yakup_leandro/features_snack/services/product_asset_storage.dart';
import 'package:snackautomat_yakup_leandro/features_snack/services/product_catalog_assets.dart';
import 'package:snackautomat_yakup_leandro/features_snack/services/slot_code_parser.dart';
import 'package:sqflite/sqflite.dart';

export 'package:snackautomat_yakup_leandro/features_snack/constants/vending_coin_config.dart'
    show coinCassetteCapacity, coinDenominationsCents, formatCents;


part 'vending_phase.dart';
part 'product_controller.dart';
part 'placed_products_controller.dart';
part 'vending_session_state.dart';
part 'vending_session_fields.dart';
part 'vending_session_coin_persist.dart';
part 'vending_session_helpers.dart';
part 'vending_session_slot_input.dart';
part 'vending_session_payment.dart';
part 'vending_session_coin_admin.dart';
part 'vending_session_notifier.dart';
part 'vending_session_demo_data.dart';
