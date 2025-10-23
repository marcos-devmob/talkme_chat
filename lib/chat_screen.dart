import 'dart:io';
import 'package:chat_new/text_composer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path/path.dart' as path;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'chat_message.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final supabase = Supabase.instance.client;
  final GoogleSignIn googleSignIn = GoogleSignIn();
  firebase_auth.User? _currentUser;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    firebase_auth.FirebaseAuth.instance.authStateChanges().listen((user) {
      setState(() {
        _currentUser = user;
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.black,
          statusBarIconBrightness: Brightness.light,
        ),
      );
    });
  }

  Future<firebase_auth.User?> _getUser() async {
    if (_currentUser != null) return _currentUser;

    try {
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;
      if (googleAuth.idToken == null || googleAuth.accessToken == null) {
        return null;
      }

      final credential = firebase_auth.GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
        accessToken: googleAuth.accessToken,
      );

      final userCredential = await firebase_auth.FirebaseAuth.instance
          .signInWithCredential(credential);
      final user = userCredential.user;

      if (user != null) print('Usuário logado: ${user.displayName}');
      return user;
    } catch (e) {
      print('Erro: $e');
      return null;
    }
  }

  /// Função para obter a duração de um arquivo de áudio local
  Future<Duration?> getAudioDuration(String filePath) async {
    final player = AudioPlayer();
    try {
      await player.setFilePath(filePath);
      final duration = player.duration;
      await player.dispose();
      return duration;
    } catch (e) {
      print('Erro ao obter duração: $e');
      return null;
    }
  }

  Future<void> _sendMessage({
    String? text,
    File? imgFile,
    File? audioFile,
  }) async {
    final user = await _getUser();
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível fazer o login. Tente novamente!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final data = <String, dynamic>{
      'uid': user.uid,
      'senderName': user.displayName,
      'senderPhotoUrl': user.photoURL,
      'createdAt': FieldValue.serverTimestamp(),
    };

    setState(() => _isLoading = true);

    // Upload de imagem
    if (imgFile != null) {
      final fileName =
          '${user.uid}${DateTime.now().millisecondsSinceEpoch}_${path.basename(imgFile.path)}';
      try {
        await supabase.storage.from('images').upload(fileName, imgFile);
        final publicUrl = supabase.storage
            .from('images')
            .getPublicUrl(fileName);
        data['imgUrl'] = publicUrl;
      } catch (e) {
        print('❌ Erro no upload da imagem: $e');
        setState(() => _isLoading = false);
        return;
      }
    }

    // Upload de áudio + duração
    if (audioFile != null) {
      final fileName =
          '${user.uid}${DateTime.now().millisecondsSinceEpoch}_${path.basename(audioFile.path)}';

      try {
        // Obter duração ANTES de enviar
        final duration = await getAudioDuration(audioFile.path);
        if (duration != null) {
          data['audioDuration'] = duration.inSeconds;
        }

        await supabase.storage.from('audios').upload(fileName, audioFile);
        final publicUrl = supabase.storage
            .from('audios')
            .getPublicUrl(fileName);
        data['audioUrl'] = publicUrl;
      } catch (e) {
        print('❌ Erro no upload do áudio: $e');
        setState(() => _isLoading = false);
        return;
      }
    }

    // Texto
    if (text != null && text.trim().isNotEmpty) data['text'] = text.trim();

    await FirebaseFirestore.instance.collection('messages').add(data);

    setState(() => _isLoading = false);
  }

  Future<void> _clearMessages() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Apagar todas as mensagens?'),
        content: const Text(
          'Essa ação vai apagar todas as mensagens do chat e não poderá ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Apagar'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final collection = FirebaseFirestore.instance.collection('messages');
      final snapshots = await collection.get();
      for (final doc in snapshots.docs) {
        await doc.reference.delete();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Todas as mensagens foram apagadas.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Colors.grey.shade100,
        leading: IconButton(
          icon: const Icon(Icons.delete_forever, color: Colors.black),
          tooltip: 'Apagar mensagens',
          onPressed: _clearMessages,
        ),
        title: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            _currentUser != null
                ? 'Olá, ${_currentUser!.displayName}.'
                : 'Chat App',
            style: const TextStyle(color: Colors.black, fontSize: 22),
          ),
        ),
        elevation: 0,
        centerTitle: true,
        actions: [
          if (_currentUser != null)
            IconButton(
              onPressed: () {
                firebase_auth.FirebaseAuth.instance.signOut();
                googleSignIn.signOut();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Você saiu com sucesso!')),
                );
              },
              icon: const Icon(Icons.exit_to_app),
              color: Colors.black,
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('messages')
                  .orderBy('createdAt')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final documents = snapshot.data!.docs.reversed.toList();

                return ListView.builder(
                  itemCount: documents.length,
                  reverse: true,
                  itemBuilder: (context, index) {
                    final message = documents[index];
                    final data = message.data() as Map<String, dynamic>;

                    return ChatMessage(
                      data: data,
                      isMe: _currentUser?.uid == data['uid'],
                    );
                  },
                );
              },
            ),
          ),
          if (_isLoading) const LinearProgressIndicator(),
          TextComposer(
            onSendMessage: _sendMessage,
            onSendAudio: (audioFile) => _sendMessage(audioFile: audioFile),
          ),
        ],
      ),
    );
  }
}
