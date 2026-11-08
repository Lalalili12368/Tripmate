import 'package:flutter/material.dart';
import 'auth.dart';
import 'home.dart';

class Splash extends StatefulWidget {
  final bool loggedIn;
  const Splash({super.key, required this.loggedIn});
  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 600),
          pageBuilder: (_, __, ___) => widget.loggedIn ? const Home() : const AuthPage(),
          transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          width: double.infinity,
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF3E5C3F), Color(0xFF5A7D5A), Color(0xFF9BB895)]),
          ),
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 1400),
              curve: Curves.easeOutBack,
              builder: (_, v, __) => Opacity(
                opacity: v.clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 0.6 + 0.4 * v,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(.15), shape: BoxShape.circle),
                      child: const Icon(Icons.flight_takeoff, size: 70, color: Colors.white),
                    ),
                    const SizedBox(height: 20),
                    const Text('TripMate', style: TextStyle(fontSize: 38, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 1)),
                    const SizedBox(height: 6),
                    const Text('Plan smarter. Travel better.', style: TextStyle(color: Colors.white70, fontSize: 15)),
                    const SizedBox(height: 36),
                    const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}
