class SlotCode {
  const SlotCode({required this.rowLabel, required this.columnNumber});

  final String rowLabel;
  final int columnNumber;

  String get code => '$rowLabel$columnNumber';

  static SlotCode? tryParse(String input) {
    final normalized = input.trim().toUpperCase();
    final match = RegExp(r'^([A-F])(10|[1-9])$').firstMatch(normalized);

    if (match == null) {
      return null;
    }

    return SlotCode(
      rowLabel: match.group(1)!,
      columnNumber: int.parse(match.group(2)!),
    );
  }
}
