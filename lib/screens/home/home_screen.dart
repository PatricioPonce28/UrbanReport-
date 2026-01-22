import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/login_screen.dart';
import '../admin/admin_dashboard.dart';
import 'profile_screen.dart';
import 'reports_screen.dart';
import 'my_reports_screen.dart';
import 'map_view_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  int _currentIndex = 0;
  User? _user;
  String _userName = '';
  String _userRole = 'user';
  bool _isLoadingRole = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    _user = _supabase.auth.currentUser;
    if (_user != null) {
      setState(() {
        _userName = _user!.userMetadata?['name'] ?? 'Usuario';
      });

      try {
        print('🔍 Cargando perfil para usuario: ${_user!.id}');
        
        final response = await _supabase
            .from('profiles')
            .select('role')
            .eq('id', _user!.id)
            .single();
        
        print('✅ Perfil obtenido: $response');
        
        final userRole = response['role'] as String?;
        print('🎭 Rol del usuario: $userRole');
        
        setState(() {
          _userRole = userRole ?? 'user';
          _isLoadingRole = false;
        });

        if (_userRole == 'admin' && mounted) {
          print('🚀 Redirigiendo al Dashboard de Admin');
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const AdminDashboard()),
          );
        }
      } catch (e) {
        print('❌ Error al cargar perfil: $e');
        setState(() => _isLoadingRole = false);
      }
    }
  }

  Future<void> _signOut() async {
    final shouldSignOut = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Cerrar sesión?'),
        content: const Text('¿Estás seguro de que deseas cerrar sesión?'),
        actionsAlignment: MainAxisAlignment.spaceEvenly,
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE31E24),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
        SnackBar(
          content: const Text('Error al cerrar sesión'),
          backgroundColor: const Color(0xFFE31E24),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingRole) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFF003DA5))),
      );
    }

    final screens = [
      _HomeTab(userName: _userName, onSignOut: _signOut),
      const ReportsScreen(),
      const MyReportsScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) => setState(() => _currentIndex = index),
          type: BottomNavigationBarType.fixed,
          backgroundColor: Colors.white,
          selectedItemColor: const Color(0xFF003DA5),
          unselectedItemColor: Colors.grey.shade600,
          selectedFontSize: 11,
          unselectedFontSize: 11,
          elevation: 0,
          showUnselectedLabels: true,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Inicio'),
            BottomNavigationBarItem(icon: Icon(Icons.add_circle_outline), activeIcon: Icon(Icons.add_circle), label: 'Reportar'),
            BottomNavigationBarItem(icon: Icon(Icons.list_alt_outlined), activeIcon: Icon(Icons.list_alt), label: 'Mis Reportes'),
            BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Perfil'),
          ],
        ),
      ),
    );
  }
}

// Tarjeta de estadística (no la usas ahora, pero la dejo mejorada por si la usas después)
Widget _StatCard({
  required IconData icon,
  required String title,
  required String value,
  required Color color,
}) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.grey.shade200),
      boxShadow: [
        BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 12, offset: const Offset(0, 5)),
      ],
    ),
    child: Column(
      children: [
        Icon(icon, color: color, size: 36),
        const SizedBox(height: 10),
        Text(value, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 6),
        Text(title, style: TextStyle(fontSize: 13, color: Colors.grey.shade700)),
      ],
    ),
  );
}

// Tab Inicio
class _HomeTab extends StatelessWidget {
  final String userName;
  final VoidCallback onSignOut;

  const _HomeTab({required this.userName, required this.onSignOut});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quito App', style: TextStyle(fontWeight: FontWeight.w700)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF003DA5),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout_rounded),
            tooltip: 'Cerrar Sesión',
            onPressed: onSignOut,
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF8FAFC), Color(0xFFEFF4FF)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header de bienvenida
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF003DA5), Color(0xFF005BFF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF003DA5).withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '¡Bienvenido de nuevo!',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        userName,
                        style: const TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Ayúdanos a mantener Quito más limpia y segura',
                        style: TextStyle(fontSize: 15, color: Colors.white70),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // Sección Acciones Rápidas
                Row(
                  children: [
                    Container(
                      width: 5,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE31E24),
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Acciones Rápidas',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF003DA5)),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 20,
                  childAspectRatio: 1.05,
                  children: [
                    _QuickActionCard(
                      icon: Icons.report_problem_rounded,
                      title: 'Nuevo Reporte',
                      color: const Color(0xFFE31E24),
                      onTap: () {
                        final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                        homeState?.setState(() => homeState._currentIndex = 1);
                      },
                    ),
                    _QuickActionCard(
                      icon: Icons.list_alt_rounded,
                      title: 'Mis Reportes',
                      color: const Color(0xFF003DA5),
                      onTap: () {
                        final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                        homeState?.setState(() => homeState._currentIndex = 2);
                      },
                    ),
                    _QuickActionCard(
                      icon: Icons.person_rounded,
                      title: 'Mi Perfil',
                      color: const Color(0xFF00A650),
                      onTap: () {
                        final homeState = context.findAncestorStateOfType<_HomeScreenState>();
                        homeState?.setState(() => homeState._currentIndex = 3);
                      },
                    ),
                    // Tarjeta del mapa – ahora más bonita y con nombre correcto
                    _QuickActionCard(
                      icon: Icons.map_rounded,
                      title: 'Mapa de Reportes',
                      color: const Color(0xFFFDB913), // amarillo quiteño
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const MapViewScreen()),
                        );
                      },
                      isSpecial: true, // para aplicar estilo diferente
                    ),
                  ],
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Card de acción rápida – con opción para destacar la del mapa
class _QuickActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color color;
  final VoidCallback onTap;
  final bool isSpecial;

  const _QuickActionCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.onTap,
    this.isSpecial = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      splashColor: color.withOpacity(0.15),
      child: Container(
        decoration: BoxDecoration(
          gradient: isSpecial
              ? LinearGradient(
                  colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isSpecial ? null : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSpecial ? color.withOpacity(0.4) : Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: isSpecial ? color.withOpacity(0.35) : Colors.black.withOpacity(0.06),
              blurRadius: isSpecial ? 16 : 10,
              offset: const Offset(0, 6),
              spreadRadius: isSpecial ? 2 : 0,
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: isSpecial ? 44 : 38, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isSpecial ? 16 : 14,
                fontWeight: isSpecial ? FontWeight.bold : FontWeight.w600,
                color: isSpecial ? color : const Color(0xFF003DA5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}