import 'package:chat_new/chat_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await Supabase.initialize(
    url: 'https://fcpvjgfpopakmmluevlk.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZjcHZqZ2Zwb3Bha21tbHVldmxrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA0NTc3MDYsImV4cCI6MjA3NjAzMzcwNn0.mEcEJX6of29Z5-tmVXOP_WFWMmjtnzWjqUCuiyUzfI0',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat Flutter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: false, // evita interferência do Material 3
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        iconTheme: IconThemeData(
          color: Colors.blue, // altera a cor dos ícones
        ),
      ),
      home: ChatScreen(),
    );
  }
}
