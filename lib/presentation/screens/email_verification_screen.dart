import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:backgammon_score_tracker/core/auth/auth_verification.dart';
import 'package:backgammon_score_tracker/core/auth/post_auth_navigation.dart';
import 'package:backgammon_score_tracker/core/routes/app_router.dart';
import 'package:backgammon_score_tracker/core/services/firebase_service.dart';
import 'package:backgammon_score_tracker/core/services/session_service.dart';
import 'package:backgammon_score_tracker/core/widgets/background_board.dart';
import 'package:backgammon_score_tracker/core/widgets/styled_container.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _firebaseService = FirebaseService();
  final _sessionService = SessionService();
  bool _isLoading = false;
  bool _isResending = false;

  String? get _email => FirebaseAuth.instance.currentUser?.email;

  Future<void> _checkVerification() async {
    setState(() => _isLoading = true);
    try {
      final verified = await _firebaseService.refreshAndCheckEmailVerified();
      if (!mounted) return;

      if (verified) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
            {'isEmailVerified': true},
            SetOptions(merge: true),
          );
        }
        await _sessionService.startSession();
        if (!mounted) return;
        await PostAuthNavigation.go(context);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'E-posta henüz doğrulanmadı. Gelen kutunuzu ve spam klasörünü kontrol edin.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kontrol edilemedi: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendEmail() async {
    setState(() => _isResending = true);
    try {
      await _firebaseService.sendEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Doğrulama e-postası tekrar gönderildi.'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceAll('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  Future<void> _signOut() async {
    await _sessionService.logout();
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, AppRouter.login);
  }

  @override
  Widget build(BuildContext context) {
    final email = _email;

    return Scaffold(
      body: BackgroundBoard(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: SingleChildScrollView(
                child: StyledContainer(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.mark_email_unread_outlined,
                          size: 64,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'E-postanızı Doğrulayın',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          email != null
                              ? '$email adresine bir doğrulama bağlantısı gönderdik. Uygulamayı kullanmadan önce e-postanızdaki bağlantıya tıklayın.'
                              : 'Hesabınızı kullanmadan önce e-posta adresinizi doğrulamanız gerekir.',
                          style: Theme.of(context).textTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _isLoading ? null : _checkVerification,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text('Doğruladım, Devam Et'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed:
                                _isResending || _isLoading ? null : _resendEmail,
                            child: _isResending
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('E-postayı Tekrar Gönder'),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _isLoading ? null : _signOut,
                          child: const Text('Çıkış Yap'),
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
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        Navigator.pushReplacementNamed(context, AppRouter.login);
        return;
      }
      if (!AuthVerification.requiresEmailVerification(user)) {
        PostAuthNavigation.go(context);
      }
    });
  }
}
