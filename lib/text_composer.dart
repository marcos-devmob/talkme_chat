import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class TextComposer extends StatefulWidget {
  const TextComposer({
    super.key,
    required this.onSendMessage,
    required this.onSendAudio,
  });

  final void Function({String text, File? imgFile}) onSendMessage;
  final void Function(File audioFile) onSendAudio;

  @override
  State<TextComposer> createState() => _TextComposerState();
}

class _TextComposerState extends State<TextComposer> {
  bool _isComposing = false;
  final TextEditingController _controller = TextEditingController();
  bool _isRecording = false;
  late final AudioRecorder _recorder;

  @override
  void initState() {
    super.initState();
    _recorder = AudioRecorder();
    _initRecorder();
  }

  Future<void> _initRecorder() async {
    try {
      await _recorder.hasPermission();
    } catch (e) {
      print("⚠️ Erro ao inicializar gravador: $e");
    }
  }

  void _reset() {
    _controller.clear();
    setState(() => _isComposing = false);
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await ImagePicker().pickImage(
      source: ImageSource.camera,
    );
    if (pickedFile == null) return;
    widget.onSendMessage(imgFile: File(pickedFile.path));
  }

  Future<void> _startRecording() async {
    try {
      final hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        print("❌ Permissão negada para gravar áudio");
        return;
      }

      final dir = await getTemporaryDirectory();
      final filePath =
          '${dir.path}/${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: filePath,
      );

      setState(() => _isRecording = true);
      print("🎤 Gravando áudio em: $filePath");
    } catch (e) {
      print("⚠️ Erro ao iniciar gravação: $e");
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _recorder.stop();
      setState(() => _isRecording = false);

      if (path != null) {
        final audioFile = File(path);
        widget.onSendAudio(audioFile);
        print("✅ Áudio enviado: $path");
      } else {
        print("⚠️ Nenhum áudio gravado");
      }
    } catch (e) {
      print("⚠️ Erro ao parar gravação: $e");
    }
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: _pickImage,
            icon: const Icon(Icons.photo_camera_outlined),
            color: Colors.black,
          ),
          Expanded(
            child: TextField(
              maxLines: null,
              minLines: 1,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Enviar uma mensagem',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 2,
                ),
              ),
              onChanged: (text) {
                setState(() {
                  _isComposing = text.isNotEmpty;
                });
              },
              onSubmitted: (text) {
                if (text.isNotEmpty) {
                  widget.onSendMessage(text: text);
                  _reset();
                }
              },
            ),
          ),
          IconButton(
            onPressed: _isComposing
                ? () {
                    widget.onSendMessage(text: _controller.text);
                    _reset();
                  }
                : _isRecording
                ? _stopRecording
                : _startRecording,
            icon: Icon(
              _isComposing
                  ? Icons.send
                  : _isRecording
                  ? Icons.stop
                  : Icons.mic,
            ),
            color: Colors.black,
          ),
        ],
      ),
    );
  }
}
