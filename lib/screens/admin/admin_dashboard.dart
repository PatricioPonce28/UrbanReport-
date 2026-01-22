import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/login_screen.dart';
import 'admin_users_screen.dart';
import 'admin_reports_screen.dart';

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
      final stats = await _supabase.from('admin_stats').select().single();
      setState(() {
        _stats = stats;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar estadísticas: $e'),
          backgroundColor: const Color(0xFFE31E24),
        ),
      );
    } finally {
      setState(() => _isLoadingStats = false);
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
      _DashboardTab(stats: _stats, isLoading: _isLoadingStats, onRefresh: _loadStats),
      const AdminReportsScreen(),
      const AdminUsersScreen(),
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

// Tab del Dashboard principal
class _DashboardTab extends StatelessWidget {
  final Map<String, dynamic> stats;
  final bool isLoading;
  final VoidCallback onRefresh;

  const _DashboardTab({
    required this.stats,
    required this.isLoading,
    required this.onRefresh,
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
            onPressed: () async {
              final supabase = Supabase.instance.client;
              await supabase.auth.signOut();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
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
                          child: _StatCard(
                            icon: Icons.people,
                            title: 'Usuarios',
                            value: stats['total_usuarios'].toString(),
                            color: const Color(0xFF003DA5),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatCard(
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

                    _StatCard(
                      icon: Icons.pending_actions,
                      title: 'Pendientes',
                      value: stats['reportes_pendientes'].toString(),
                      color: const Color(0xFFFDB913),
                      isWide: true,
                    ),
                    const SizedBox(height: 12),

                    _StatCard(
                      icon: Icons.engineering,
                      title: 'En Proceso',
                      value: stats['reportes_en_proceso'].toString(),
                      color: const Color(0xFF003DA5),
                      isWide: true,
                    ),
                    const SizedBox(height: 12),

                    _StatCard(
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

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  final bool isWide;

  const _StatCard({
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