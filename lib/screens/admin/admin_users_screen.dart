import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);

    try {
      final data = await _supabase
          .from('profiles')
          .select('*, auth.users!inner(email, email_confirmed_at, created_at, last_sign_in_at)')
          .order('created_at', ascending: false);

      setState(() {
        _users = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar usuarios: $e'),
          backgroundColor: const Color(0xFFE31E24),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteUser(String userId, String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Usuario'),
        content: Text('¿Estás seguro de que deseas eliminar a $userName?\n\n'
            'Esta acción eliminará todos sus reportes y no se puede deshacer.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFE31E24),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _supabase.rpc('delete_user', params: {'user_id': userId});

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Usuario eliminado exitosamente'),
          backgroundColor: Color(0xFF00A650),
        ),
      );

      _loadUsers();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar usuario: $e'),
          backgroundColor: const Color(0xFFE31E24),
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    if (_searchQuery.isEmpty) return _users;

    return _users.where((user) {
      final name = (user['name'] ?? '').toLowerCase();
      final email = (user['auth.users']['email'] ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();

      return name.contains(query) || email.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Usuarios'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: Column(
        children: [
          // Buscador
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o email...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
              ),
              onChanged: (value) => setState(() => _searchQuery = value),
            ),
          ),

          // Lista de usuarios
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_off_outlined,
                              size: 64,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _searchQuery.isEmpty
                                  ? 'No hay usuarios'
                                  : 'No se encontraron usuarios',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadUsers,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filteredUsers.length,
                          itemBuilder: (context, index) {
                            final user = _filteredUsers[index];
                            final authData = user['auth.users'] as Map<String, dynamic>;
                            final currentUserId = _supabase.auth.currentUser!.id;
                            final isCurrentUser = user['id'] == currentUserId;

                            return _UserCard(
                              user: user,
                              authData: authData,
                              isCurrentUser: isCurrentUser,
                              onDelete: () => _deleteUser(
                                user['id'],
                                user['name'] ?? 'Usuario',
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final Map<String, dynamic> user;
  final Map<String, dynamic> authData;
  final bool isCurrentUser;
  final VoidCallback onDelete;

  const _UserCard({
    required this.user,
    required this.authData,
    required this.isCurrentUser,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final name = user['name'] ?? 'Sin nombre';
    final email = authData['email'] ?? '';
    final role = user['role'] ?? 'user';
    final createdAt = authData['created_at'];
    final isVerified = authData['email_confirmed_at'] != null;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: role == 'admin'
              ? const Color(0xFFE31E24)
              : const Color(0xFF003DA5),
          child: Text(
            name[0].toUpperCase(),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
            if (role == 'admin')
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE31E24),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'ADMIN',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            if (isCurrentUser)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF00A650),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'TÚ',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  isVerified ? Icons.verified : Icons.pending,
                  size: 14,
                  color: isVerified ? const Color(0xFF00A650) : Colors.orange,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    email,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _InfoRow(
                  icon: Icons.calendar_today,
                  label: 'Registro',
                  value: _formatDate(createdAt),
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.email,
                  label: 'Email',
                  value: email,
                ),
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.check_circle,
                  label: 'Estado',
                  value: isVerified ? 'Verificado' : 'Pendiente',
                ),
                if (!isCurrentUser && role != 'admin') ...[
                  const Divider(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Eliminar Usuario'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFE31E24),
                        side: const BorderSide(color: Color(0xFFE31E24)),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'N/A';
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            fontSize: 14,
            color: Colors.grey.shade600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}