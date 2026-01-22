import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        _emailController.text.trim(),
        redirectTo: 'io.supabase.flutterquickstart://reset-callback/',
      );

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          icon: const Icon(
            Icons.email_outlined,
            size: 64,
            color: Color(0xFF003DA5),
          ),
          title: const Text('Correo enviado'),
          content: const Text(
            'Te hemos enviado un correo con instrucciones para restablecer tu contraseña. '
            'Por favor revisa tu bandeja de entrada.',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Cerrar diálogo
                Navigator.of(context).pop(); // Volver a login
              },
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: const Color(0xFFE31E24),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error inesperado. Por favor intenta de nuevo.'),
          backgroundColor: Color(0xFFE31E24),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recuperar Contraseña'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Icono
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: const Color(0xFF003DA5).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_reset,
                      size: 60,
                      color: Color(0xFF003DA5),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    '¿Olvidaste tu contraseña?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF003DA5),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No te preocupes. Ingresa tu correo electrónico y te enviaremos instrucciones para restablecer tu contraseña.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Email
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      prefixIcon: Icon(Icons.email_outlined),
                      hintText: 'tucorreo@ejemplo.com',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Por favor ingresa tu correo';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(value)) {
                        return 'Ingresa un correo válido';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  
                  // Botón de Enviar
                  ElevatedButton(
                    onPressed: _isLoading ? null : _resetPassword,
                    child: _isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Enviar Instrucciones',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Volver al login
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('Volver al inicio de sesión'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}