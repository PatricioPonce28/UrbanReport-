import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MyReportsScreen extends StatefulWidget {
  const MyReportsScreen({super.key});

  @override
  State<MyReportsScreen> createState() => _MyReportsScreenState();
}

class _MyReportsScreenState extends State<MyReportsScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _reportes = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    setState(() => _isLoading = true);

    try {
      final userId = _supabase.auth.currentUser!.id;
      final data = await _supabase
          .from('reportes')
          .select()
          .eq('usuario_id', userId)
          .order('created_at', ascending: false);

      setState(() {
        _reportes = List<Map<String, dynamic>>.from(data);
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar reportes: $e'),
          backgroundColor: const Color(0xFFE31E24),
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Color _getEstadoColor(String estado) {
    switch (estado) {
      case 'pendiente':
        return const Color(0xFFFDB913);
      case 'en_proceso':
        return const Color(0xFF003DA5);
      case 'resuelto':
        return const Color(0xFF00A650);
      default:
        return Colors.grey;
    }
  }

  String _getEstadoLabel(String estado) {
    switch (estado) {
      case 'pendiente':
        return 'Pendiente';
      case 'en_proceso':
        return 'En Proceso';
      case 'resuelto':
        return 'Resuelto';
      default:
        return estado;
    }
  }

  IconData _getCategoriaIcon(String categoria) {
    switch (categoria) {
      case 'bache':
        return Icons.warning_amber;
      case 'luminaria':
        return Icons.lightbulb_outline;
      case 'basura':
        return Icons.delete_outline;
      case 'alcantarilla':
        return Icons.water_damage_outlined;
      default:
        return Icons.more_horiz;
    }
  }

  String _getCategoriaLabel(String categoria) {
    switch (categoria) {
      case 'bache':
        return 'Bache';
      case 'luminaria':
        return 'Luminaria';
      case 'basura':
        return 'Basura';
      case 'alcantarilla':
        return 'Alcantarilla';
      default:
        return 'Otro';
    }
  }

  void _showReportDetail(Map<String, dynamic> reporte) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF003DA5).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getCategoriaIcon(reporte['categoria']),
                      color: const Color(0xFF003DA5),
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reporte['titulo'],
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _getEstadoColor(reporte['estado']),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            _getEstadoLabel(reporte['estado']),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Categoría
              _DetailRow(
                icon: Icons.category,
                label: 'Categoría',
                value: _getCategoriaLabel(reporte['categoria']),
              ),
              const SizedBox(height: 16),

              // Descripción
              _DetailRow(
                icon: Icons.description,
                label: 'Descripción',
                value: reporte['descripcion'],
              ),
              const SizedBox(height: 16),

              // Fecha
              _DetailRow(
                icon: Icons.calendar_today,
                label: 'Fecha',
                value: _formatDate(reporte['created_at']),
              ),
              const SizedBox(height: 16),

              // Ubicación
              if (reporte['latitud'] != null && reporte['longitud'] != null) ...[
                _DetailRow(
                  icon: Icons.location_on,
                  label: 'Ubicación',
                  value: 'Lat: ${reporte['latitud'].toStringAsFixed(6)}\n'
                      'Lng: ${reporte['longitud'].toStringAsFixed(6)}',
                ),
                const SizedBox(height: 16),
              ],

              // Foto
              if (reporte['foto_url'] != null) ...[
                const Text(
                  'Fotografía',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF003DA5),
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    reporte['foto_url'],
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        height: 200,
                        color: Colors.grey.shade200,
                        child: const Center(
                          child: Icon(Icons.error_outline, size: 48),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Reportes'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReports,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _reportes.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 80,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No tienes reportes aún',
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Crea tu primer reporte',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadReports,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _reportes.length,
                    itemBuilder: (context, index) {
                      final reporte = _reportes[index];
                      return _ReportCard(
                        reporte: reporte,
                        onTap: () => _showReportDetail(reporte),
                        getCategoriaIcon: _getCategoriaIcon,
                        getCategoriaLabel: _getCategoriaLabel,
                        getEstadoColor: _getEstadoColor,
                        getEstadoLabel: _getEstadoLabel,
                      );
                    },
                  ),
                ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          return 'Hace ${difference.inMinutes} min';
        }
        return 'Hace ${difference.inHours}h';
      } else if (difference.inDays < 7) {
        return 'Hace ${difference.inDays}d';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return 'N/A';
    }
  }
}

class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> reporte;
  final VoidCallback onTap;
  final IconData Function(String) getCategoriaIcon;
  final String Function(String) getCategoriaLabel;
  final Color Function(String) getEstadoColor;
  final String Function(String) getEstadoLabel;

  const _ReportCard({
    required this.reporte,
    required this.onTap,
    required this.getCategoriaIcon,
    required this.getCategoriaLabel,
    required this.getEstadoColor,
    required this.getEstadoLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF003DA5).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  getCategoriaIcon(reporte['categoria']),
                  color: const Color(0xFF003DA5),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reporte['titulo'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      getCategoriaLabel(reporte['categoria']),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: getEstadoColor(reporte['estado']),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        getEstadoLabel(reporte['estado']),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF003DA5), size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(fontSize: 14),
              ),
            ],
          ),
        ),
      ],
    );
  }
}