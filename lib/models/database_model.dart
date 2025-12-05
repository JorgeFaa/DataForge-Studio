class Database {
  final int id;
  final String dbName;
  final String user;
  final String host;
  final int? port; // 1. Hacer el puerto opcional (nullable)
  final String status; // 2. Añadir el campo de estado

  Database({
    required this.id,
    required this.dbName,
    required this.user,
    required this.host,
    this.port, // Puerto ya no es requerido
    required this.status,
  });

  factory Database.fromJson(Map<String, dynamic> json) {
    return Database(
      id: json['id'],
      dbName: json['dbName'],
      user: json['user'],
      host: json['host'],
      port: json['port'], // Se manejará si es nulo
      status: json['status'],
    );
  }
}
