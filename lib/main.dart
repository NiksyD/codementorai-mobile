import 'package:flutter/material.dart';
import 'src/features/auth/presentation/login_screen.dart';

void main() {
  runApp(const CodeMentorApp());
}

class CodeMentorApp extends StatelessWidget {
  const CodeMentorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CodeMentor AI',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
