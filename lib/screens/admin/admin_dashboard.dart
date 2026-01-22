import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../auth/login_screen.dart';
import 'map_widget.dart'; // Importar el widget del mapa

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  final _supabase = Supabase.instance.client;
  int _currentIndex = 0;
  
  Map<String, dynamic> _stats = {
    'total_usuarios': 0,
    'total_reportes': 0,
    'reportes_pendientes': 0,
    'reportes_en_proceso': 0,
    'reportes_resueltos': 0,
    'reportes_hoy': 0,
  };
  bool _isLoadingStats = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _isLoadingStats = true);

    try {
      // Intentar usar la vista admin_stats primero
      final statsData = await _supabase
          .from('admin_stats')
          .select('*')
          .maybeSingle();
      
      if (statsData != null) {
        setState(() {
          _stats = {
            'total_usuarios': statsData['total_usuarios'] ?? 0,
            'total_reportes': statsData['total_reportes'] ?? 0,
            'reportes_pendientes': statsData['reportes_pendientes'] ?? 0,
            'reportes_en_proceso': statsData['reportes_en_proceso'] ?? 0,
            'reportes_resueltos': statsData['reportes_resueltos'] ?? 0,
            'reportes_hoy': statsData['reportes_hoy'] ?? 0,
          };
        });
      } else {
        // Si la vista no existe, usar método manual
        await _loadStatsManual();
      }
    } catch (e) {
      print('Error con vista admin_stats, usando método manual: $e');
      await _loadStatsManual();
    } finally {
      setState(() => _isLoadingStats = false);
    }
  }

  Future<void> _loadStatsManual() async {
    try {
      // Consulta simplificada para usuarios
      final usuariosData = await _supabase
          .from('profiles')
          .select('id');
      final totalUsuarios = usuariosData.length;

      // Consulta para reportes
      final reportesData = await _supabase
          .from('reportes')
          .select('estado, created_at');

      final reportesList = List<Map<String, dynamic>>.from(reportesData);
      
      final pendientes = reportesList.where((r) => r['estado'] == 'pendiente').length;
      final enProceso = reportesList.where((r) => r['estado'] == 'en_proceso').length;
      final resueltos = reportesList.where((r) => r['estado'] == 'resuelto').length;

      final hoy = DateTime.now();
      final reportesHoy = reportesList.where((r) {
        try {
          final createdAt = r['created_at'] is String 
              ? DateTime.parse(r['created_at'])
              : (r['created_at'] as DateTime);
          return createdAt.year == hoy.year &&
                 createdAt.month == hoy.month &&
                 createdAt.day == hoy.day;
        } catch (e) {
          return false;
        }
      }).length;

      setState(() {
        _stats = {
          'total_usuarios': totalUsuarios,
          'total_reportes': reportesList.length,
          'reportes_pendientes': pendientes,
          'reportes_en_proceso': enProceso,
          'reportes_resueltos': resueltos,
          'reportes_hoy': reportesHoy,
        };
      });
    } catch (e) {
      print('Error en método manual: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar estadísticas: $e'),
          backgroundColor: const Color(0xFFE31E24),
        ),
      );
    }
  }

  Future<void> _signOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFFE31E24),
            ),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );

    if (shouldSignOut != true) return;

    try {
      await _supabase.auth.signOut();
      
      if (!mounted) return;
      
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error al cerrar sesión'),
          backgroundColor: Color(0xFFE31E24),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      _DashboardTab(
        stats: _stats, 
        isLoading: _isLoadingStats, 
        onRefresh: _loadStats,
        onSignOut: _signOut,
        context: context,
      ),
      _AdminReportsScreen(context: context),
      _AdminUsersScreen(context: context),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF003DA5),
          unselectedItemColor: Colors.grey,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_outlined),
              activeIcon: Icon(Icons.dashboard),
              label: 'Dashboard',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.report_outlined),
              activeIcon: Icon(Icons.report),
              label: 'Reportes',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'Usuarios',
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================
// TAB DEL DASHBOARD
// ============================================
class _DashboardTab extends StatelessWidget {
  final Map<String, dynamic> stats;
  final bool isLoading;
  final VoidCallback onRefresh;
  final VoidCallback onSignOut;
  final BuildContext context;

  const _DashboardTab({
    required this.stats,
    required this.isLoading,
    required this.onRefresh,
    required this.onSignOut,
    required this.context,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Administración'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: onRefresh,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: onSignOut,
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async => onRefresh(),
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF003DA5), Color(0xFF0055CC)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(
                                Icons.admin_panel_settings,
                                color: Colors.white,
                                size: 32,
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Administrador',
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Gestión de Quito App',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Estadísticas principales
                    const Text(
                      'Estadísticas Generales',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF003DA5),
                      ),
                    ),
                    const SizedBox(height: 16),

                    Row(
                      children: [
                        Expanded(
                          child: _StatCardWidget(
                            icon: Icons.people,
                            title: 'Usuarios',
                            value: stats['total_usuarios'].toString(),
                            color: const Color(0xFF003DA5),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCardWidget(
                            icon: Icons.report,
                            title: 'Reportes',
                            value: stats['total_reportes'].toString(),
                            color: const Color(0xFFE31E24),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Estados de reportes
                    const Text(
                      'Estado de Reportes',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF003DA5),
                      ),
                    ),
                    const SizedBox(height: 16),

                    _StatCardWidget(
                      icon: Icons.pending_actions,
                      title: 'Pendientes',
                      value: stats['reportes_pendientes'].toString(),
                      color: const Color(0xFFFDB913),
                      isWide: true,
                    ),
                    const SizedBox(height: 12),

                    _StatCardWidget(
                      icon: Icons.engineering,
                      title: 'En Proceso',
                      value: stats['reportes_en_proceso'].toString(),
                      color: const Color(0xFF003DA5),
                      isWide: true,
                    ),
                    const SizedBox(height: 12),

                    _StatCardWidget(
                      icon: Icons.check_circle,
                      title: 'Resueltos',
                      value: stats['reportes_resueltos'].toString(),
                      color: const Color(0xFF00A650),
                      isWide: true,
                    ),
                    const SizedBox(height: 24),

                    // Reportes de hoy
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFFE31E24).withOpacity(0.1),
                            const Color(0xFFE31E24).withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFE31E24).withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE31E24),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.today,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Reportes Hoy',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF003DA5),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  stats['reportes_hoy'].toString(),
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFFE31E24),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

// Widget de tarjeta de estadística
class _StatCardWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final bool isWide;

  const _StatCardWidget({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    this.isWide = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isWide
          ? Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            )
          : Column(
              children: [
                Icon(icon, color: color, size: 32),
                const SizedBox(height: 8),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
    );
  }
}

// ============================================
// PANTALLA DE REPORTES - VERSIÓN CORREGIDA
// ============================================
class _AdminReportsScreen extends StatefulWidget {
  final BuildContext context;
  
  const _AdminReportsScreen({required this.context});

  @override
  State<_AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<_AdminReportsScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _reportes = [];
  bool _isLoading = true;
  String _filtroEstado = 'todos';

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  // Función para cargar nombres de usuarios desde profiles
  Future<Map<String, String>> _loadUserNames() async {
    final Map<String, String> nombresMap = {};
    
    try {
      // Obtener todos los perfiles con nombre
      final perfilesData = await _supabase
          .from('profiles')
          .select('id, name')
          .not('name', 'is', null); // Solo donde name no sea null
      
      for (final perfil in perfilesData) {
        if (perfil['id'] != null && perfil['name'] != null) {
          nombresMap[perfil['id']] = perfil['name'];
        }
      }
    } catch (e) {
      print('Error al cargar nombres de usuarios: $e');
    }
    
    return nombresMap;
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);

    try {
      // 1. Obtener todos los reportes
      final reportesData = await _supabase
          .from('reportes')
          .select('*')
          .order('created_at', ascending: false);

      List<Map<String, dynamic>> reportesList = 
          List<Map<String, dynamic>>.from(reportesData);
      
      // 2. Obtener nombres de usuarios
      final nombresUsuarios = await _loadUserNames();
      
      // 3. Asignar nombres a cada reporte
      for (var reporte in reportesList) {
        final usuarioId = reporte['usuario_id']?.toString();
        
        if (usuarioId != null && nombresUsuarios.containsKey(usuarioId)) {
          reporte['usuario_nombre'] = nombresUsuarios[usuarioId]!;
        } else {
          reporte['usuario_nombre'] = 'Usuario ${usuarioId?.substring(0, 8) ?? 'Desconocido'}';
        }
      }

      setState(() {
        _reportes = reportesList;
      });

    } catch (e) {
      print('Error al cargar reportes: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(widget.context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar reportes: $e'),
          backgroundColor: const Color(0xFFE31E24),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateEstado(String reporteId, String nuevoEstado) async {
    try {
      await _supabase
          .from('reportes')
          .update({'estado': nuevoEstado})
          .eq('id', reporteId);

      if (!mounted) return;

      ScaffoldMessenger.of(widget.context).showSnackBar(
        const SnackBar(
          content: Text('Estado actualizado'),
          backgroundColor: Color(0xFF00A650),
        ),
      );

      _loadReports();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(widget.context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: const Color(0xFFE31E24),
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredReports {
    if (_filtroEstado == 'todos') return _reportes;
    return _reportes.where((r) => r['estado'] == _filtroEstado).toList();
  }

  // FUNCIÓN PARA MOSTRAR EL MAPA
  void _showMapDialog(double lat, double lon, String titulo) {
    showDialog(
      context: widget.context,
      builder: (context) => AlertDialog(
        title: Text(titulo),
        content: SizedBox(
          width: 550,
          child: MapWidget(
            latitud: lat,
            longitud: lon,
            titulo: titulo,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reportes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReports,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtros
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                _buildFilterChip('Todos', 'todos'),
                const SizedBox(width: 8),
                _buildFilterChip('Pendientes', 'pendiente'),
                const SizedBox(width: 8),
                _buildFilterChip('En Proceso', 'en_proceso'),
                const SizedBox(width: 8),
                _buildFilterChip('Resueltos', 'resuelto'),
              ],
            ),
          ),

          // Lista de reportes
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredReports.isEmpty
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.report_problem, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No hay reportes',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _filteredReports.length,
                        itemBuilder: (context, index) {
                          final reporte = _filteredReports[index];
                          
                          // Obtener nombre del usuario
                          String userName = reporte['usuario_nombre'] ?? 
                                          'Usuario ${reporte['usuario_id']?.toString().substring(0, 8) ?? 'Desconocido'}';
                          
                          // Determinar color según estado
                          Color estadoColor = Colors.grey;
                          switch (reporte['estado']) {
                            case 'pendiente':
                              estadoColor = const Color(0xFFFDB913);
                              break;
                            case 'en_proceso':
                              estadoColor = const Color(0xFF003DA5);
                              break;
                            case 'resuelto':
                              estadoColor = const Color(0xFF00A650);
                              break;
                          }

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            elevation: 3,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              contentPadding: const EdgeInsets.all(16),
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    reporte['titulo'] ?? 'Sin título',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: estadoColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: estadoColor.withOpacity(0.3)),
                                        ),
                                        child: Text(
                                          reporte['estado']?.toString().toUpperCase() ?? 'PENDIENTE',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: estadoColor,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE31E24).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: const Color(0xFFE31E24).withOpacity(0.3)),
                                        ),
                                        child: Text(
                                          reporte['categoria']?.toString().toUpperCase() ?? 'OTRO',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFFE31E24),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.person, size: 16, color: Colors.grey),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          'Reportado por: $userName',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (reporte['descripcion'] != null && reporte['descripcion'].toString().isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        reporte['descripcion'].toString(),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    ),
                                  if (reporte['latitud'] != null && reporte['longitud'] != null)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Row(
                                        children: [
                                          const Icon(Icons.location_on, size: 16, color: Colors.grey),
                                          const SizedBox(width: 6),
                                          Text(
                                            '${reporte['latitud'].toStringAsFixed(6)}, ${reporte['longitud'].toStringAsFixed(6)}',
                                            style: const TextStyle(fontSize: 12, color: Colors.grey),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (reporte['latitud'] != null && reporte['longitud'] != null)
                                    IconButton(
                                      icon: const Icon(Icons.map, color: Color(0xFF003DA5)),
                                      tooltip: 'Ver ubicación',
                                      onPressed: () {
                                        final lat = double.tryParse(reporte['latitud'].toString()) ?? 0.0;
                                        final lon = double.tryParse(reporte['longitud'].toString()) ?? 0.0;
                                        if (lat != 0.0 && lon != 0.0) {
                                          _showMapDialog(lat, lon, reporte['titulo'] ?? 'Reporte');
                                        }
                                      },
                                    ),
                                  PopupMenuButton(
                                    icon: const Icon(Icons.more_vert, color: Colors.grey),
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'pendiente',
                                        child: Row(
                                          children: [
                                            Icon(Icons.pending, color: Color(0xFFFDB913)),
                                            SizedBox(width: 8),
                                            Text('Pendiente'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'en_proceso',
                                        child: Row(
                                          children: [
                                            Icon(Icons.engineering, color: Color(0xFF003DA5)),
                                            SizedBox(width: 8),
                                            Text('En Proceso'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'resuelto',
                                        child: Row(
                                          children: [
                                            Icon(Icons.check_circle, color: Color(0xFF00A650)),
                                            SizedBox(width: 8),
                                            Text('Resuelto'),
                                          ],
                                        ),
                                      ),
                                    ],
                                    onSelected: (value) {
                                      _updateEstado(reporte['id'], value);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _filtroEstado == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        setState(() => _filtroEstado = value);
      },
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFF003DA5).withOpacity(0.2),
      checkmarkColor: const Color(0xFF003DA5),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF003DA5) : Colors.grey,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? const Color(0xFF003DA5) : Colors.grey.shade300,
          width: isSelected ? 2 : 1,
        ),
      ),
    );
  }
}

// ============================================
// PANTALLA DE USUARIOS
// ============================================
class _AdminUsersScreen extends StatefulWidget {
  final BuildContext context;
  
  const _AdminUsersScreen({required this.context});

  @override
  State<_AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<_AdminUsersScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);

    try {
      // Consultar todos los perfiles
      final data = await _supabase
          .from('profiles')
          .select('*')
          .order('created_at', ascending: false);

      List<Map<String, dynamic>> usersList = List<Map<String, dynamic>>.from(data);
      
      // Para cada usuario, contar sus reportes
      for (var user in usersList) {
        try {
          final reportesData = await _supabase
              .from('reportes')
              .select()
              .eq('usuario_id', user['id']);
          
          user['total_reportes'] = reportesData.length;
        } catch (e) {
          print('Error al contar reportes para usuario ${user['id']}: $e');
          user['total_reportes'] = 0;
        }
      }

      setState(() {
        _users = usersList;
      });
    } catch (e) {
      print('Error al cargar usuarios: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(widget.context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar usuarios: $e'),
          backgroundColor: const Color(0xFFE31E24),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Usuarios'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadUsers,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _users.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people, size: 64, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'No hay usuarios registrados',
                        style: TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    final user = _users[index];
                    final isAdmin = user['role'] == 'admin';
                    
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 3,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(16),
                        leading: CircleAvatar(
                          radius: 24,
                          backgroundColor: isAdmin 
                              ? const Color(0xFFE31E24)
                              : const Color(0xFF003DA5),
                          child: Text(
                            (user['name']?[0] ?? 'U').toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        title: Text(
                          user['name'] ?? 'Usuario sin nombre',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.article, size: 14, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  '${user['total_reportes'] ?? 0} reportes',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: isAdmin 
                                ? const Color(0xFFE31E24).withOpacity(0.1)
                                : const Color(0xFF003DA5).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isAdmin 
                                  ? const Color(0xFFE31E24).withOpacity(0.3)
                                  : const Color(0xFF003DA5).withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            isAdmin ? 'ADMIN' : 'USER',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isAdmin 
                                  ? const Color(0xFFE31E24)
                                  : const Color(0xFF003DA5),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}