import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import '../app_theme.dart';
import '../models/table_model.dart';

const List<String> _postgresDataTypes = [
  'varchar', 'text', 'integer', 'bigint', 'smallint', 'numeric', 'decimal',
  'real', 'double precision', 'boolean', 'date', 'timestamp', 'timestamptz', 'time',
  'interval', 'uuid', 'json', 'jsonb', 'bytea', 'serial', 'bigserial'
];

// Lista de tipos de datos que admiten longitud/precisión
const List<String> _typesWithLength = ['varchar', 'char', 'numeric', 'decimal', 'bit', 'varbit'];

class _ColumnRowController {
  final nameController = TextEditingController();
  String selectedType = 'varchar';
  final lengthController = TextEditingController(); // Controlador para el largo
  bool isPrimaryKey = false;
  bool isNullable = true;
  bool isUnique = false;
}

class _ForeignKeyRowController {
  final constraintNameController = TextEditingController();
  String? selectedLocalColumn;
  String? selectedForeignTable;
  String? selectedForeignColumn;
  bool isLoadingForeignColumns = false;
  List<String> availableForeignColumns = [];
}

class CreateTableScreen extends StatefulWidget {
  final int databaseId;
  const CreateTableScreen({super.key, required this.databaseId});

  @override
  State<CreateTableScreen> createState() => _CreateTableScreenState();
}

class _CreateTableScreenState extends State<CreateTableScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tableNameController = TextEditingController();
  final List<_ColumnRowController> _columnControllers = [];
  final List<_ForeignKeyRowController> _foreignKeyControllers = [];
  bool _isLoading = false;
  List<String> _existingTables = [];

  @override
  void initState() {
    super.initState();
    _addColumn();
    _fetchExistingTables();
  }

  void _addColumn() => setState(() => _columnControllers.add(_ColumnRowController()));
  void _removeColumn(int index) => setState(() => _columnControllers.removeAt(index));

  void _addForeignKey() => setState(() => _foreignKeyControllers.add(_ForeignKeyRowController()));
  void _removeForeignKey(int index) => setState(() => _foreignKeyControllers.removeAt(index));

  Future<void> _fetchExistingTables() async {
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/databases/${widget.databaseId}/tables'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          _existingTables = data.cast<String>();
        });
      }
    } catch (e) {
      // No es crítico si falla
    }
  }

  Future<void> _fetchForeignColumnsFor(_ForeignKeyRowController fkController) async {
    if (fkController.selectedForeignTable == null) return;
    setState(() => fkController.isLoadingForeignColumns = true);
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/databases/${widget.databaseId}/tables/${fkController.selectedForeignTable}'));
      if (response.statusCode == 200) {
        final details = TableDetails.fromJson(jsonDecode(response.body));
        setState(() {
          fkController.availableForeignColumns = details.columns.map((c) => c.name).toList();
        });
      } else {
        throw Exception();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudieron cargar las columnas de la tabla foránea.'), backgroundColor: AppColors.error));
    } finally {
      setState(() => fkController.isLoadingForeignColumns = false);
    }
  }

  Future<void> _createTable() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Por favor, completa todos los campos requeridos.')));
      return;
    }
    setState(() => _isLoading = true);

    final columns = _columnControllers.map((c) {
      String finalDataType = c.selectedType;
      if (_typesWithLength.contains(c.selectedType) && c.lengthController.text.isNotEmpty) {
        finalDataType = '$finalDataType(${c.lengthController.text})';
      }
      return ColumnDefinition(name: c.nameController.text, dataType: finalDataType, isPrimaryKey: c.isPrimaryKey, isNullable: c.isNullable, isUnique: c.isUnique).toJson();
    }).toList();

    final foreignKeys = _foreignKeyControllers.where((fk) => fk.selectedLocalColumn != null && fk.selectedForeignTable != null && fk.selectedForeignColumn != null).map((fk) => {
          'constraintName': fk.constraintNameController.text,
          'localColumn': fk.selectedLocalColumn,
          'foreignTable': fk.selectedForeignTable,
          'foreignColumn': fk.selectedForeignColumn,
          'valid': true,
        }).toList();

    final body = {'tableName': _tableNameController.text, 'columns': columns, 'foreignKeys': foreignKeys, 'valid': true};

    try {
      final response = await http.post(Uri.parse('${ApiConfig.baseUrl}/databases/${widget.databaseId}/tables'), headers: {'Content-Type': 'application/json; charset=UTF-8'}, body: jsonEncode(body));
      if (response.statusCode == 201 || response.statusCode == 200) {
        if (mounted) Navigator.of(context).pop(true);
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception('Error: ${errorBody['message'] ?? response.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Crear Nueva Tabla')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: TextFormField(controller: _tableNameController, decoration: const InputDecoration(labelText: 'Nombre de la Tabla'), validator: (v) => (v == null || v.isEmpty) ? 'El nombre no puede estar vacío' : null),
                  ),
                ),
                const Divider(),
                Expanded(
                  child: ListView(
                    children: [
                      _buildSectionHeader('Columnas', _addColumn),
                      ..._columnControllers.asMap().entries.map((entry) => _buildColumnRow(entry.value, entry.key)),
                      const SizedBox(height: 16),
                      const Divider(),
                      _buildSectionHeader('Foreign Keys', _addForeignKey),
                      ..._foreignKeyControllers.asMap().entries.map((entry) => _buildForeignKeyRow(entry.value, entry.key)),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 400),
                      child: SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _createTable,
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: AppColors.onPrimary, padding: const EdgeInsets.symmetric(vertical: 16)),
                          child: _isLoading ? const CircularProgressIndicator(color: AppColors.onPrimary) : const Text('Crear Tabla'),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, VoidCallback onAdd) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(title, style: Theme.of(context).textTheme.titleLarge), IconButton(icon: const Icon(Icons.add_circle, color: AppColors.primary), tooltip: 'Añadir', onPressed: onAdd)]),
    );
  }

  Widget _buildColumnRow(_ColumnRowController controller, int index) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Expanded(flex: 3, child: TextFormField(controller: controller.nameController, decoration: const InputDecoration(labelText: 'Nombre'), validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null, onChanged: (_) => setState(() {}))),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: DropdownButtonFormField<String>(value: controller.selectedType, items: _postgresDataTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(), onChanged: (val) => setState(() => controller.selectedType = val!), decoration: const InputDecoration(labelText: 'Tipo'))),
              if (_typesWithLength.contains(controller.selectedType)) ...[
                const SizedBox(width: 8),
                Expanded(flex: 1, child: TextFormField(controller: controller.lengthController, decoration: const InputDecoration(labelText: 'Largo'), keyboardType: TextInputType.number)),
              ],
              if (_columnControllers.length > 1) IconButton(icon: Icon(Icons.remove_circle_outline, color: AppColors.error.withOpacity(0.8)), onPressed: () => _removeColumn(index)),
            ]),
            Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [_buildCheckbox('PK', controller.isPrimaryKey, (val) => setState(() => controller.isPrimaryKey = val!)), _buildCheckbox('Nullable', controller.isNullable, (val) => setState(() => controller.isNullable = val!)), _buildCheckbox('Unique', controller.isUnique, (val) => setState(() => controller.isUnique = val!))]),
          ],
        ),
      ),
    );
  }

  Widget _buildForeignKeyRow(_ForeignKeyRowController controller, int index) {
    final currentColumnNames = _columnControllers.map((c) => c.nameController.text).where((name) => name.isNotEmpty).toList();
    return Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(children: [
              Row(children: [Expanded(child: TextFormField(controller: controller.constraintNameController, decoration: const InputDecoration(labelText: 'Nombre del Constraint'))), IconButton(icon: Icon(Icons.remove_circle_outline, color: AppColors.error.withOpacity(0.8)), onPressed: () => _removeForeignKey(index))]),
              const SizedBox(height: 8),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: DropdownButtonFormField<String>(value: controller.selectedLocalColumn, items: currentColumnNames.map((col) => DropdownMenuItem(value: col, child: Text(col))).toList(), onChanged: (val) => setState(() => controller.selectedLocalColumn = val), decoration: const InputDecoration(labelText: 'Columna Local'))),
                const SizedBox(width: 8),
                Expanded(child: DropdownButtonFormField<String>(value: controller.selectedForeignTable, items: _existingTables.map((tbl) => DropdownMenuItem(value: tbl, child: Text(tbl))).toList(), onChanged: (val) {setState(() {controller.selectedForeignTable = val; controller.selectedForeignColumn = null;}); _fetchForeignColumnsFor(controller);}, decoration: const InputDecoration(labelText: 'Tabla Foránea'))),
                const SizedBox(width: 8),
                Expanded(child: controller.isLoadingForeignColumns ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())) : DropdownButtonFormField<String>(value: controller.selectedForeignColumn, items: controller.availableForeignColumns.map((col) => DropdownMenuItem(value: col, child: Text(col))).toList(), onChanged: (val) => setState(() => controller.selectedForeignColumn = val), decoration: const InputDecoration(labelText: 'Columna Foránea'))),
              ])
            ])));
  }

  Widget _buildCheckbox(String label, bool value, ValueChanged<bool?>? onChanged) => Row(mainAxisSize: MainAxisSize.min, children: [Checkbox(value: value, onChanged: onChanged, visualDensity: VisualDensity.compact), Text(label)]);
}
