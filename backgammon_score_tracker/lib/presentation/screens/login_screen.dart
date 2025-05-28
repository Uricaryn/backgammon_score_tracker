import 'package:flutter/material.dart';
import 'package:backgammon_score_tracker/core/routes/app_router.dart';
import 'package:backgammon_score_tracker/core/widgets/background_board.dart';
import 'package:backgammon_score_tracker/core/widgets/dice_icon.dart';
import 'package:backgammon_score_tracker/core/services/firebase_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firebaseService = FirebaseService();
  bool _isLoading = false;
  bool _isSignUp = false;
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _firebaseService.signIn(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRouter.home);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _firebaseService.signUp(
        _emailController.text.trim(),
        _passwordController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Kayıt başarılı! Lütfen e-posta adresinizi doğrulayın.'),
            backgroundColor: Colors.green,
          ),
        );
        setState(() => _isSignUp = false);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BackgroundBoard(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: FadeTransition(
                opacity: _fadeAnimation,
                child: SlideTransition(
                  position: _slideAnimation,
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const DiceIcon(
                              size: 80,
                              color: Colors.brown,
                            ),
                            const SizedBox(height: 24),
                            Text(
                              _isSignUp ? 'Hesap Oluştur' : 'Giriş Yap',
                              style: Theme.of(context).textTheme.displayMedium,
                            ),
                            const SizedBox(height: 32),
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'E-posta',
                                prefixIcon: Icon(Icons.email),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              enabled: !_isLoading,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'E-posta adresi gerekli';
                                }
                                if (!value.contains('@')) {
                                  return 'Geçerli bir e-posta adresi girin';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _passwordController,
                              decoration: const InputDecoration(
                                labelText: 'Şifre',
                                prefixIcon: Icon(Icons.lock),
                              ),
                              obscureText: true,
                              enabled: !_isLoading,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Şifre gerekli';
                                }
                                if (value.length < 6) {
                                  return 'Şifre en az 6 karakter olmalı';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: _isLoading
                                    ? null
                                    : (_isSignUp
                                        ? _handleSignUp
                                        : _handleLogin),
                                icon: _isLoading
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                  Colors.white),
                                        ),
                                      )
                                    : Icon(_isSignUp
                                        ? Icons.person_add
                                        : Icons.login),
                                label: Text(
                                    _isSignUp ? 'Hesap Oluştur' : 'Giriş Yap'),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextButton.icon(
                              onPressed: _isLoading
                                  ? null
                                  : () {
                                      setState(() => _isSignUp = !_isSignUp);
                                    },
                              icon: Icon(
                                  _isSignUp ? Icons.login : Icons.person_add),
                              label: Text(
                                  _isSignUp ? 'Giriş Yap' : 'Hesap Oluştur'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
