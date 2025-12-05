class ForeignKey {
  final String constraintName;
  final String localColumnName;
  final String foreignTableName;
  final String foreignColumnName;

  ForeignKey.fromJson(Map<String, dynamic> json)
      : constraintName = json['constraintName'],
        localColumnName = json['localColumnName'],
        foreignTableName = json['foreignTableName'],
        foreignColumnName = json['foreignColumnName'];
}

class ColumnDefinition {
  final String name;
  final String dataType;
  final bool isPrimaryKey;
  final bool isNullable;
  final bool isUnique;

  ColumnDefinition({
    required this.name,
    required this.dataType,
    this.isPrimaryKey = false,
    this.isNullable = true,
    this.isUnique = false,
  });

  factory ColumnDefinition.fromJson(Map<String, dynamic> json) {
    return ColumnDefinition(
      name: json['name'] as String,
      dataType: json['dataType'] as String,
      isPrimaryKey: json['isPrimaryKey'] as bool? ?? false,
      isNullable: json['isNullable'] as bool? ?? true,
      isUnique: json['isUnique'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'dataType': dataType,
      'isPrimaryKey': isPrimaryKey,
      'isNullable': isNullable,
      'isUnique': isUnique,
    };
  }
}

class TableDetails {
  final String tableName;
  final List<ColumnDefinition> columns;

  TableDetails({required this.tableName, required this.columns});

  factory TableDetails.fromJson(Map<String, dynamic> json) {
    final columnsList = json['columns'] as List<dynamic>? ?? [];
    final columns = columnsList
        .map((i) => ColumnDefinition.fromJson(i as Map<String, dynamic>))
        .toList();

    return TableDetails(
      tableName: json['tableName'] as String,
      columns: columns,
    );
  }
}
