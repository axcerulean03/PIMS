class WFPEntry {
  final String id;
  final String title;
  final String targetSize;
  final String indicator;
  final int year;
  final String fundType;
  final double amount;

  const WFPEntry({
    required this.id,
    required this.title,
    required this.targetSize,
    required this.indicator,
    required this.year,
    required this.fundType,
    required this.amount,
  });

  /// Creates a copy of this entry with optional field overrides.
  WFPEntry copyWith({
    String? id,
    String? title,
    String? targetSize,
    String? indicator,
    int? year,
    String? fundType,
    double? amount,
  }) {
    return WFPEntry(
      id: id ?? this.id,
      title: title ?? this.title,
      targetSize: targetSize ?? this.targetSize,
      indicator: indicator ?? this.indicator,
      year: year ?? this.year,
      fundType: fundType ?? this.fundType,
      amount: amount ?? this.amount,
    );
  }

  /// Serializes to a map for SQLite insertion/update.
  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'targetSize': targetSize,
        'indicator': indicator,
        'year': year,
        'fundType': fundType,
        'amount': amount,
      };

  /// Deserializes from a SQLite map row.
  factory WFPEntry.fromMap(Map<String, dynamic> map) => WFPEntry(
        id: map['id'] as String,
        title: map['title'] as String,
        targetSize: map['targetSize'] as String,
        indicator: map['indicator'] as String,
        year: map['year'] as int,
        fundType: map['fundType'] as String,
        amount: (map['amount'] as num).toDouble(),
      );

  @override
  String toString() => 'WFPEntry($id, $title, $fundType, $year)';

  @override
  bool operator ==(Object other) =>
      other is WFPEntry && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
