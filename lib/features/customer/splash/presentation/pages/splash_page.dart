import 'package:flutter/material.dart';
import 'package:delwaqty/shared/widgets/delwa_intro_cinematic.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  Widget build(BuildContext context) {
    return const DelwaIntroScene();
  }
}
