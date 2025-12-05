import 'dart:convert';
import 'package:data_forge_studio/models/db_user_model.dart';
import 'package:data_forge_studio/widgets/app_loading_indicator.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../api_config.dart';
import '../app_theme.dart';
import '../models/database_model.dart';
import '../models/table_model.dart';
import 'create_table_screen.dart';

enum DetailView { tables, users }

class DatabaseDetailScreen extends StatefulWidget {
  final Database database;

  const DatabaseDetailScreen({super.key, required this.database});

  @override
  State<DatabaseDetailScreen> createState() => _DatabaseDetailScreenState();
}

class _DatabaseDetailScreenState extends State<DatabaseDetailScreen> {
  DetailView _currentView = DetailView.tables;

  // --- Estado de Tablas ---
  bool _isLoadingTables = true;
  List<String> _tables = [];
  String? _tablesError;
  String? _selectedTableName;
  TableDetails? _selectedTableDetails;
  List<ForeignKey> _selectedTableForeignKeys = [];
  bool _isLoadingTableContent = false;

  // --- Estado de Dynamic CRUD ---
  List<Map<String, dynamic>> _tableData = [];
  List<String> _tableDataHeaders = [];
  bool _isLoadingData = false;
  int _currentPage = 1;
  final int _limit = 20;

  // --- Estado de Usuarios ---
  bool _isLoadingUsers = true;
  List<DbUser> _users = [];
  String? _usersError;
  final Map<String, List<UserPermission>> _userPermissionsCache = {};
  final Map<String, bool> _isLoadingPermissions = {};

  @override
  void initState() {
    super.initState();
    _fetchTables();
  }

  // --- Lógica de Tablas y Datos ---
  Future<void> _fetchTables() async {
    if (mounted) setState(() => _isLoadingTables = true);
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/databases/${widget.database.id}/tables'));
      if (response.statusCode == 200) {
        if (mounted) setState(() => _tables = (jsonDecode(response.body) as List).cast<String>());
      } else {
        throw Exception('Error al cargar las tablas: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) setState(() => _tablesError = e.toString());
    } finally {
      if (mounted) setState(() => _isLoadingTables = false);
    }
  }

  Future<void> _selectTable(String tableName, {int page = 1}) async {
    setState(() {
      _currentView = DetailView.tables;
      _selectedTableName = tableName;
      _isLoadingTableContent = true;
      _isLoadingData = true;
      _currentPage = page;
    });

    try {
      final responses = await Future.wait([
        http.get(Uri.parse('${ApiConfig.baseUrl}/databases/${widget.database.id}/tables/$tableName')),
        http.get(Uri.parse('${ApiConfig.baseUrl}/databases/${widget.database.id}/tables/$tableName/foreign-keys')),
        http.get(Uri.parse('${ApiConfig.baseUrl}/db/${widget.database.id}/tables/$tableName?page=$page&limit=$_limit')),
      ]);

      if (responses.every((r) => r.statusCode == 200)) {
        if (mounted) {
          final tableDetailsData = jsonDecode(responses[0].body);
          final foreignKeysData = jsonDecode(responses[1].body);
          final tableData = jsonDecode(responses[2].body) as List;

          setState(() {
            _selectedTableDetails = TableDetails.fromJson(tableDetailsData);
            _selectedTableForeignKeys = (foreignKeysData as List).map((fk) => ForeignKey.fromJson(fk)).toList();
            _tableData = tableData.cast<Map<String, dynamic>>();
            if (_tableData.isNotEmpty) {
              _tableDataHeaders = _tableData.first.keys.toList();
            } else if (_selectedTableDetails != null) {
              _tableDataHeaders = _selectedTableDetails!.columns.map((c) => c.name).toList();
            }
          });
        }
      } else {
        throw Exception('Error al cargar datos de la tabla.');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() {
        _isLoadingTableContent = false;
        _isLoadingData = false;
      });
    }
  }
  
  Future<void> _deleteColumn(String columnName) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Borrar Columna'),
              content: Text('¿Seguro que quieres borrar la columna \'$columnName\'?'),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
                TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Borrar', style: TextStyle(color: AppColors.error))),
              ],
            ));

    if (confirmed != true) return;

    try {
      final response = await http.delete(Uri.parse('${ApiConfig.baseUrl}/databases/${widget.database.id}/tables/$_selectedTableName/columns/$columnName'));
      if (response.statusCode == 204) {
        _selectTable(_selectedTableName!); 
      } else {
         throw Exception('Error al borrar la columna: ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    }
  }

  Future<void> _deleteForeignKey(String constraintName) async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
            title: const Text('Borrar Llave Foránea'),
            content: Text('¿Seguro que quieres borrar la constraint \'$constraintName\'?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
              TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Borrar', style: TextStyle(color: AppColors.error)))
            ]));

    if (confirmed != true) return;

    try {
      final response = await http.delete(Uri.parse('${ApiConfig.baseUrl}/databases/${widget.database.id}/tables/$_selectedTableName/foreign-keys/$constraintName'));
      if (response.statusCode == 204) {
        _selectTable(_selectedTableName!); 
      } else {
        throw Exception('Error al borrar la llave foránea: ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    }
  }

  Future<void> _showAddOrEditColumnDialog({ColumnDefinition? existingColumn}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _AddOrEditColumnDialog(
        databaseId: widget.database.id,
        tableName: _selectedTableName!,
        existingColumn: existingColumn,
      ),
    );

    if (result == true) {
      _selectTable(_selectedTableName!); // Recargar la tabla si hubo un cambio
    }
  }

  Future<void> _deleteTable(String tableName) async {
     final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Confirmar Borrado'),
              content: Text('¿Estás seguro de que quieres borrar la tabla \'$tableName\'? Esta acción no se puede deshacer.'),
              actions: [
                TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
                TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Borrar', style: TextStyle(color: AppColors.error))),
              ],
            ));

    if (confirmed != true) return;

    try {
      final response = await http.delete(Uri.parse('${ApiConfig.baseUrl}/databases/${widget.database.id}/tables/$tableName'));
      if (response.statusCode == 204) {
        setState(() {
          _tables.remove(tableName);
          if (_selectedTableName == tableName) {
            _selectedTableName = null;
            _selectedTableDetails = null;
          }
        });
      } else {
        throw Exception('Error al borrar la tabla');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    }
  }

  void _navigateToCreateTable() async {
    final result = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => CreateTableScreen(databaseId: widget.database.id)));
    if (result == true) {
      _fetchTables();
    }
  }

  // --- Lógica de CRUD Dinámico ---
  Future<void> _showAddOrEditRecordDialog({Map<String, dynamic>? existingRecord}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _AddOrEditRecordDialog(
        tableDetails: _selectedTableDetails!,
        databaseId: widget.database.id,
        existingRecord: existingRecord,
      ),
    );
    if (result == true) _selectTable(_selectedTableName!, page: _currentPage);
  }

  Future<void> _deleteRecord(Map<String, dynamic> record) async {
    final pkColumn = _selectedTableDetails?.columns.firstWhere((c) => c.isPrimaryKey, orElse: () => throw Exception('No PK'));
    if (pkColumn == null) return;
    final recordId = record[pkColumn.name];

    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('Borrar Registro'), content: const Text('¿Estás seguro?'), actions: [TextButton(onPressed:()=>Navigator.pop(ctx,false), child:const Text('No')), TextButton(onPressed:()=>Navigator.pop(ctx,true), child:const Text('Sí'))]));
    if(confirmed != true) return;

    try {
        final response = await http.delete(Uri.parse('${ApiConfig.baseUrl}/db/${widget.database.id}/tables/$_selectedTableName/$recordId'));
        if(response.statusCode == 204){
            _selectTable(_selectedTableName!, page: _currentPage);
        } else {
            throw Exception('Error al borrar: ${response.body}');
        }
    } catch(e){
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    }
  }

  // --- Lógica de Usuarios ---
  Future<void> _fetchUsers() async {
    setState(() {
      _isLoadingUsers = true;
      _usersError = null;
    });
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/databases/${widget.database.id}/db-users'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (mounted) setState(() => _users = data.map((json) => DbUser.fromJson(json)).toList());
      } else {
        throw Exception('Error al cargar usuarios: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) setState(() => _usersError = e.toString());
    } finally {
      if (mounted) setState(() => _isLoadingUsers = false);
    }
  }

  Future<void> _fetchPermissionsForUser(String username) async {
    setState(() => _isLoadingPermissions[username] = true);
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}/databases/${widget.database.id}/db-users/$username/permissions'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _userPermissionsCache[username] = data.map((p) => UserPermission.fromJson(p)).toList();
          });
        }
      } else {
        throw Exception('Error al cargar permisos');
      }
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _isLoadingPermissions[username] = false);
    }
  }

  Future<void> _revokePermission(String username, String tableName, String privilege) async {
     try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}/databases/${widget.database.id}/db-users/$username/permissions'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'tableName': tableName, 'privileges': [privilege]}),
      );
      if (response.statusCode == 200) {
        _fetchPermissionsForUser(username);
      } else {
        throw Exception('Error al revocar permiso: ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    }
  }

  Future<void> _showGrantPermissionDialog(String username) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _GrantPermissionDialog(databaseId: widget.database.id, username: username, tables: _tables),
    );
    if (result == true) {
      _fetchPermissionsForUser(username);
    }
  }

  Future<void> _deleteUser(String username) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmar Borrado'),
        content: Text('¿Seguro que quieres borrar al usuario \'$username\'?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: Text('Borrar', style: TextStyle(color: AppColors.error))),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final response = await http.delete(Uri.parse('${ApiConfig.baseUrl}/databases/${widget.database.id}/db-users/$username'));
      if (response.statusCode == 200 || response.statusCode == 204) {
        _fetchUsers();
      } else {
        throw Exception('Error al borrar el usuario: ${response.body}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    }
  }

  Future<void> _showAddUserDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _AddUserDialog(databaseId: widget.database.id),
    );
    if (result == true) _fetchUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.database.dbName)),
      drawer: Drawer(
        child: Column(
          children: [
            Container(
              color: AppColors.surface,
              padding: const EdgeInsets.fromLTRB(16.0, 40.0, 16.0, 16.0),
              child: Text(widget.database.dbName, style: Theme.of(context).textTheme.headlineSmall),
            ),
            ExpansionTile(
              leading: const Icon(Icons.table_rows_rounded), 
              title: const Text('Tablas'),
              initiallyExpanded: _currentView == DetailView.tables,
              children: [_buildTablesList()],
            ),
            ListTile(
              leading: const Icon(Icons.people_alt_outlined), 
              title: const Text('Usuarios'), 
              selected: _currentView == DetailView.users,
              onTap: () {
                setState(() => _currentView = DetailView.users);
                if (_users.isEmpty) _fetchUsers();
                Navigator.of(context).pop();
              },
            ),
            const Spacer(),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.arrow_back, color: AppColors.secondary),
              title: const Text('Volver a Conexiones'),
              onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
            ),
          ],
        ),
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: _currentView == DetailView.users ? _showAddUserDialog : _navigateToCreateTable,
        tooltip: _currentView == DetailView.users ? 'Añadir Usuario' : 'Crear Tabla',
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildBody() {
    switch (_currentView) {
      case DetailView.users:
        return _buildUsersView();
      case DetailView.tables:
      default:
        return _buildTablesView();
    }
  }

  Widget _buildTablesList() {
    if (_isLoadingTables) return const AppLoadingIndicator();
    if (_tablesError != null) return Center(child: Text(_tablesError!));
    if (_tables.isEmpty) return const ListTile(title: Text('No hay tablas.'));

    return Column(
      children: _tables.map((tableName) => ListTile(
        title: Text(tableName),
        selected: tableName == _selectedTableName,
        onTap: () {
          _selectTable(tableName);
          Navigator.of(context).pop();
        },
      )).toList(),
    );
  }

  Widget _buildTablesView() {
    if (_selectedTableName == null) {
      return const Center(child: Text('Selecciona una tabla para ver su estructura y datos.'));
    }
    if (_isLoadingTableContent) {
      return const AppLoadingIndicator();
    }
    if (_selectedTableDetails == null) {
      return const Center(child: Text('No se pudo cargar la estructura de la tabla.', style: TextStyle(color: AppColors.error)));
    }

    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Columnas de $_selectedTableName', style: Theme.of(context).textTheme.headlineSmall), IconButton(icon: const Icon(Icons.add_circle, color: AppColors.primary), tooltip: 'Añadir Columna', onPressed: () => _showAddOrEditColumnDialog())]),
        ..._selectedTableDetails!.columns.map((col) => ListTile(leading: Icon(col.isPrimaryKey ? Icons.vpn_key : Icons.notes), title: Text('${col.name} (${col.dataType})'), trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _showAddOrEditColumnDialog(existingColumn: col)), IconButton(icon: const Icon(Icons.delete_outline, color: AppColors.error), onPressed: () => _deleteColumn(col.name))]))),
        const Divider(height: 40),
        Text('Llaves Foráneas', style: Theme.of(context).textTheme.headlineSmall),
        if (_selectedTableForeignKeys.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Text('No hay llaves foráneas.')),
        ..._selectedTableForeignKeys.map((fk) => ListTile(leading: const Icon(Icons.link), title: Text(fk.constraintName), subtitle: Text('${fk.localColumnName} -> ${fk.foreignTableName}(${fk.foreignColumnName})'), trailing: IconButton(icon: const Icon(Icons.delete_outline), color: AppColors.error, onPressed: () => _deleteForeignKey(fk.constraintName)))),
        const Divider(height: 40),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Datos de la Tabla', style: Theme.of(context).textTheme.headlineSmall), IconButton(icon: const Icon(Icons.add_box_outlined, color: AppColors.primary), tooltip: 'Añadir Registro', onPressed: () => _showAddOrEditRecordDialog())]),
        _buildDataView(),
      ],
    );
  }

  Widget _buildDataView() {
    if (_isLoadingData) return const AppLoadingIndicator();
    if (_tableData.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('Esta tabla no tiene registros.')));

    final pkColumn = _selectedTableDetails?.columns.firstWhere((c) => c.isPrimaryKey, orElse: () => _selectedTableDetails!.columns.first);

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: _tableDataHeaders.map((h) => DataColumn(label: Text(h, style: const TextStyle(fontWeight: FontWeight.bold)))).toList()..add(const DataColumn(label: Text('Acciones'))),
            rows: _tableData.map((row) {
              return DataRow(
                cells: _tableDataHeaders.map((header) {
                  return DataCell(Text(row[header]?.toString() ?? ''));
                }).toList()
                  ..add(DataCell(Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(icon: const Icon(Icons.edit), onPressed: pkColumn != null ? () => _showAddOrEditRecordDialog(existingRecord: row) : null),
                    IconButton(icon: const Icon(Icons.delete), color: AppColors.error, onPressed: pkColumn != null ? () => _deleteRecord(row) : null),
                  ]))),
              );
            }).toList(),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(icon: const Icon(Icons.chevron_left), onPressed: _currentPage > 1 ? () => _selectTable(_selectedTableName!, page: _currentPage - 1) : null),
            Text('Página $_currentPage'),
            IconButton(icon: const Icon(Icons.chevron_right), onPressed: _tableData.length >= _limit ? () => _selectTable(_selectedTableName!, page: _currentPage + 1) : null),
          ],
        )
      ],
    );
  }

  Widget _buildUsersView() {
    if (_isLoadingUsers) return const AppLoadingIndicator();
    if (_usersError != null) return Center(child: Text(_usersError!, style: const TextStyle(color: AppColors.error)));
    if (_users.isEmpty) return const Center(child: Text('No hay usuarios en esta base de datos.'));

    return ListView.builder(
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        return ExpansionTile(
          key: PageStorageKey(user.username), // Keep state on scroll
          leading: Icon(user.canCreateRole ? Icons.admin_panel_settings : Icons.person, color: AppColors.secondary),
          title: Text(user.username, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: Text('Puede crear DB: ${user.canCreateDb}, Puede crear Roles: ${user.canCreateRole}'),
          onExpansionChanged: (isExpanding) {
            if (isExpanding && _userPermissionsCache[user.username] == null) {
              _fetchPermissionsForUser(user.username);
            }
          },
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            tooltip: 'Borrar Usuario',
            onPressed: () => _deleteUser(user.username),
          ),
          children: [_buildPermissionsViewForUser(user.username)],
        );
      },
    );
  }

  Widget _buildPermissionsViewForUser(String username) {
    final isLoading = _isLoadingPermissions[username] ?? false;
    if (isLoading) return const Padding(padding: EdgeInsets.all(16.0), child: AppLoadingIndicator());

    final permissions = _userPermissionsCache[username];
    if (permissions == null || permissions.isEmpty) {
      return ListTile(
        title: const Text('Este usuario no tiene permisos sobre tablas.'),
        trailing: ElevatedButton(onPressed: () => _showGrantPermissionDialog(username), child: const Text('Conceder')),
      );
    }

    return Column(
      children: [
        ...permissions.map((p) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.tableName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  ...p.privileges.map((priv) => ListTile(
                        dense: true,
                        title: Text(priv),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle_outline, size: 20, color: AppColors.error),
                          onPressed: () => _revokePermission(username, p.tableName, priv),
                        ),
                      )),
                ],
              ),
            )),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextButton.icon(
            icon: const Icon(Icons.add, color: AppColors.primary),
            label: const Text('Conceder Permiso', style: TextStyle(color: AppColors.primary)),
            onPressed: () => _showGrantPermissionDialog(username),
          ),
        )
      ],
    );
  }


}

class _AddUserDialog extends StatefulWidget {
  final int databaseId;
  const _AddUserDialog({required this.databaseId});

  @override
  State<_AddUserDialog> createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<_AddUserDialog> {
    final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _saveUser() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/databases/${widget.databaseId}/db-users'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({
          'username': _usernameController.text,
          'password': _passwordController.text,
        }),
      );

      if (response.statusCode == 201) {
        if (mounted) Navigator.of(context).pop(true);
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception('Error al crear usuario: ${errorBody['message'] ?? response.body}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Añadir Nuevo Usuario'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _usernameController,
              decoration: const InputDecoration(labelText: 'Nombre de Usuario'),
              validator: (v) => v!.isEmpty ? 'Requerido' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Contraseña'),
              validator: (v) => v!.isEmpty ? 'Requerido' : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
        ElevatedButton(
          onPressed: _isLoading ? null : _saveUser,
          child: _isLoading ? const AppLoadingIndicator(size: 20) : const Text('Guardar'),
        ),
      ],
    );
  }
}

class _GrantPermissionDialog extends StatefulWidget {
  final int databaseId;
  final String username;
  final List<String> tables;

  const _GrantPermissionDialog({required this.databaseId, required this.username, required this.tables});

  @override
  State<_GrantPermissionDialog> createState() => _GrantPermissionDialogState();
}

class _GrantPermissionDialogState extends State<_GrantPermissionDialog> {
  final List<String> _allPrivileges = ['SELECT', 'INSERT', 'UPDATE', 'DELETE', 'TRUNCATE', 'REFERENCES', 'TRIGGER'];
  final Set<String> _selectedPrivileges = {};
  String? _selectedTable;
  bool _isLoading = false;

  Future<void> _grantPermissions() async {
    if (_selectedTable == null || _selectedPrivileges.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona una tabla y al menos un privilegio.')));
      return;
    }
    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/databases/${widget.databaseId}/db-users/${widget.username}/permissions'),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode({'tableName': _selectedTable, 'privileges': _selectedPrivileges.toList()}),
      );
      if (response.statusCode == 200) {
        if (mounted) Navigator.of(context).pop(true);
      } else {
        throw Exception('Error al conceder permisos: ${response.body}');
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Conceder Permisos'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedTable,
                items: widget.tables.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) => setState(() => _selectedTable = val),
                decoration: const InputDecoration(labelText: 'Tabla'),
              ),
              const SizedBox(height: 16),
              const Text('Privilegios:'),
              ..._allPrivileges.map((p) => CheckboxListTile(
                    title: Text(p),
                    value: _selectedPrivileges.contains(p),
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedPrivileges.add(p);
                        } else {
                          _selectedPrivileges.remove(p);
                        }
                      });
                    },
                  )),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
        ElevatedButton(onPressed: _isLoading ? null : _grantPermissions, child: _isLoading ? const AppLoadingIndicator(size: 20) : const Text('Conceder')),
      ],
    );
  }
}

const List<String> _postgresDataTypes = ['varchar', 'text', 'integer', 'bigint', 'smallint', 'numeric', 'decimal', 'real', 'double precision', 'boolean', 'date', 'timestamp', 'timestamptz', 'time', 'interval', 'uuid', 'json', 'jsonb', 'bytea', 'serial', 'bigserial'];
const List<String> _typesWithLength = ['varchar', 'char', 'numeric', 'decimal', 'bit', 'varbit'];

class _AddOrEditColumnDialog extends StatefulWidget {
  final int databaseId;
  final String tableName;
  final ColumnDefinition? existingColumn;

  const _AddOrEditColumnDialog({required this.databaseId, required this.tableName, this.existingColumn});

  @override
  State<_AddOrEditColumnDialog> createState() => _AddOrEditColumnDialogState();
}

class _AddOrEditColumnDialogState extends State<_AddOrEditColumnDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _lengthController = TextEditingController();
  late List<String> _dropdownDataTypes;
  String _selectedType = 'varchar';
  bool _isNullable = true;
  bool _isUnique = false;
  bool _isPrimaryKey = false;
  bool _isLoading = false;

  bool get _isEditing => widget.existingColumn != null;

  @override
  void initState() {
    super.initState();
    _dropdownDataTypes = List.from(_postgresDataTypes);
    if (_isEditing) {
      final col = widget.existingColumn!;
      _nameController.text = col.name;

      String rawDataType = col.dataType.contains('(') ? col.dataType.substring(0, col.dataType.indexOf('(')) : col.dataType;
      if (!_dropdownDataTypes.contains(rawDataType)) {
        _dropdownDataTypes.insert(0, rawDataType);
      }
      _selectedType = rawDataType;

      if (col.dataType.contains('(')) {
        _lengthController.text = col.dataType.substring(col.dataType.indexOf('(') + 1, col.dataType.indexOf(')'));
      }
      _isNullable = col.isNullable;
      _isUnique = col.isUnique;
      _isPrimaryKey = col.isPrimaryKey;
    }
  }

  Future<void> _saveColumn() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      http.Response response;
      String url;
      Map<String, dynamic> body;

      String finalDataType = _selectedType;
      if (_typesWithLength.contains(_selectedType) && _lengthController.text.isNotEmpty) {
        finalDataType = '$finalDataType(${_lengthController.text})';
      }

      if (_isEditing) {
        url = '${ApiConfig.baseUrl}/databases/${widget.databaseId}/tables/${widget.tableName}/columns/${widget.existingColumn!.name}';
        body = {
          'newColumnName': _nameController.text,
          'newDataType': finalDataType,
          'isNullable': _isNullable,
          'isUnique': _isUnique,
          'valid': true,
        };
        response = await http.put(Uri.parse(url), headers: {'Content-Type': 'application/json; charset=UTF-8'}, body: jsonEncode(body));
      } else {
        url = '${ApiConfig.baseUrl}/databases/${widget.databaseId}/tables/${widget.tableName}/columns';
        body = {
          'name': _nameController.text,
          'dataType': finalDataType,
          'isPrimaryKey': _isPrimaryKey,
          'isNullable': _isNullable,
          'isUnique': _isUnique,
        };
        response = await http.post(Uri.parse(url), headers: {'Content-Type': 'application/json; charset=UTF-8'}, body: jsonEncode(body));
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) Navigator.of(context).pop(true);
      } else {
        final errorBody = jsonDecode(response.body);
        throw Exception('Error al guardar: ${errorBody['message'] ?? response.body}');
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
    return AlertDialog(
      title: Text(_isEditing ? 'Editar Columna' : 'Añadir Columna'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Nombre de la Columna'),
                validator: (v) => v!.isEmpty ? 'Requerido' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedType,
                items: _dropdownDataTypes.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
                onChanged: (val) => setState(() => _selectedType = val!),
                decoration: const InputDecoration(labelText: 'Tipo de Dato'),
              ),
              if (_typesWithLength.contains(_selectedType)) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _lengthController,
                  decoration: const InputDecoration(labelText: 'Largo/Precisión'),
                  keyboardType: TextInputType.number,
                ),
              ],
              Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
                _buildCheckbox('PK', _isPrimaryKey, _isEditing ? null : (val) => setState(() => _isPrimaryKey = val!)),
                _buildCheckbox('Nullable', _isNullable, (val) => setState(() => _isNullable = val!)),
                _buildCheckbox('Unique', _isUnique, (val) => setState(() => _isUnique = val!)),
              ]),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
        ElevatedButton(onPressed: _isLoading ? null : _saveColumn, child: _isLoading ? const AppLoadingIndicator(size: 20) : const Text('Guardar')),
      ],
    );
  }

  Widget _buildCheckbox(String label, bool value, ValueChanged<bool?>? onChanged) {
    return Row(mainAxisSize: MainAxisSize.min, children: [Checkbox(value: value, onChanged: onChanged), Text(label)]);
  }
}

// DIÁLOGO PARA AÑADIR/EDITAR REGISTROS (CRUD)
class _AddOrEditRecordDialog extends StatefulWidget {
  final TableDetails tableDetails;
  final int databaseId;
  final Map<String, dynamic>? existingRecord;

  const _AddOrEditRecordDialog({
    required this.tableDetails,
    required this.databaseId,
    this.existingRecord,
  });

  @override
  State<_AddOrEditRecordDialog> createState() => _AddOrEditRecordDialogState();
}

class _AddOrEditRecordDialogState extends State<_AddOrEditRecordDialog> {
  final _formKey = GlobalKey<FormState>();
  late Map<String, TextEditingController> _controllers;
  bool _isLoading = false;

  bool get _isEditing => widget.existingRecord != null;

  @override
  void initState() {
    super.initState();
    _controllers = { for (var col in widget.tableDetails.columns) col.name : TextEditingController(text: _isEditing ? widget.existingRecord![col.name]?.toString() : null) };
  }

  @override
  void dispose() {
    _controllers.forEach((_, controller) => controller.dispose());
    super.dispose();
  }

  Future<void> _saveRecord() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final body = { for (var entry in _controllers.entries) entry.key: entry.value.text };
    
    try {
      http.Response response;
      String url;

      if (_isEditing) {
        final pkColumn = widget.tableDetails.columns.firstWhere((c) => c.isPrimaryKey);
        final recordId = widget.existingRecord![pkColumn.name];
        url = '${ApiConfig.baseUrl}/db/${widget.databaseId}/tables/${widget.tableDetails.tableName}/$recordId';
        response = await http.put(Uri.parse(url), headers: {'Content-Type': 'application/json; charset=UTF-8'}, body: jsonEncode(body));
      } else {
        url = '${ApiConfig.baseUrl}/db/${widget.databaseId}/tables/${widget.tableDetails.tableName}';
        response = await http.post(Uri.parse(url), headers: {'Content-Type': 'application/json; charset=UTF-8'}, body: jsonEncode(body));
      }

      if (response.statusCode == 200 || response.statusCode == 201) {
        if (mounted) Navigator.of(context).pop(true);
      } else {
        throw Exception('Error al guardar el registro: ${response.body}');
      }

    } catch(e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    } finally {
       if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Editar Registro' : 'Añadir Registro'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: widget.tableDetails.columns.map((col) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: TextFormField(
                  controller: _controllers[col.name],
                  decoration: InputDecoration(labelText: col.name),
                  validator: (v) => col.isPrimaryKey && !_isEditing && (v == null || v.isEmpty) ? 'La PK es requerida' : null,
                ),
              );
            }).toList(),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
        ElevatedButton(onPressed: _isLoading ? null : _saveRecord, child: _isLoading ? const AppLoadingIndicator(size: 20) : const Text('Guardar')),
      ],
    );
  }
}
