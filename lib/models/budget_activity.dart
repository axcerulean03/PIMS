class BudgetActivity {
  final String id;
  final String wfpId;
  final String name;
  final double total;
  final double projected;
  final double disbursed;
  final String status;

  const BudgetActivity({
    required this.id,
    required this.wfpId,
    required this.name,
    required this.total,
    required this.projected,
    required this.disbursed,
    required this.status,
  });

  /// Auto-calculated: Total Amount minus Disbursed Amount.
  double get balance => total - disbursed;

  /// Creates a copy with optional field overrides.
  BudgetActivity copyWith({
    String? id,
    String? wfpId,
    String? name,
    double? total,
    double? projected,
    double? disbursed,
    String? status,
  }) {
    return BudgetActivity(
      id: id ?? this.id,
      wfpId: wfpId ?? this.wfpId,
      name: name ?? this.name,
      total: total ?? this.total,
      projected: projected ?? this.projected,
      disbursed: disbursed ?? this.disbursed,
      status: status ?? this.status,
    );
  }

  /// Serializes to a map for SQLite insertion/update.
  Map<String, dynamic> toMap() => {
        'id': id,
        'wfpId': wfpId,
        'name': name,
        'total': total,
        'projected': projected,
        'disbursed': disbursed,
        'status': status,
      };

  /// Deserializes from a SQLite map row.
  factory BudgetActivity.fromMap(Map<String, dynamic> map) => BudgetActivity(
        id: map['id'] as String,
        wfpId: map['wfpId'] as String,
        name: map['name'] as String,
        total: (map['total'] as num).toDouble(),
        projected: (map['projected'] as num).toDouble(),
        disbursed: (map['disbursed'] as num).toDouble(),
        status: map['status'] as String,
      );

  @override
  bool operator ==(Object other) =>
      other is BudgetActivity && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
