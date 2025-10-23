import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';

class ChatMessage extends StatefulWidget {
  const ChatMessage({super.key, required this.data, required this.isMe});

  final Map<String, dynamic> data;
  final bool isMe;

  @override
  State<ChatMessage> createState() => _ChatMessageState();
}

class _ChatMessageState extends State<ChatMessage> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;

  @override
  void initState() {
    super.initState();

    _audioPlayer.onDurationChanged.listen((newDuration) {
      setState(() => _duration = newDuration);
    });

    _audioPlayer.onPositionChanged.listen((newPosition) {
      setState(() => _position = newPosition);
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      setState(() {
        _isPlaying = false;
        _position = Duration.zero;
      });
    });

    // Pré-carregar duração do áudio
    final hasAudio =
        widget.data['audioUrl'] != null &&
        widget.data['audioUrl'].toString().isNotEmpty;
    if (hasAudio) {
      _loadAudioDuration(widget.data['audioUrl']);
    }
  }

  // Função para pré-carregar duração
  Future<void> _loadAudioDuration(String url) async {
    try {
      // Define a fonte do áudio
      await _audioPlayer.setSource(UrlSource(url));
      // Quando a duração mudar, o listener já vai atualizar _duration
    } catch (e) {
      print('Erro ao carregar duração do áudio: $e');
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlay(String url) async {
    if (_isPlaying) {
      await _audioPlayer.pause();
      setState(() => _isPlaying = false);
    } else {
      await _audioPlayer.play(UrlSource(url));
      setState(() => _isPlaying = true);
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final isMe = widget.isMe;

    final hasText = data['text'] != null && data['text'].toString().isNotEmpty;
    final hasImage =
        data['imgUrl'] != null && data['imgUrl'].toString().isNotEmpty;
    final hasAudio =
        data['audioUrl'] != null && data['audioUrl'].toString().isNotEmpty;

    // Formatando a hora
    final timestamp = data['createdAt'] != null
        ? (data['createdAt'] as dynamic).toDate()
        : DateTime.now();
    final formattedTime = DateFormat('HH:mm').format(timestamp);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar do outro usuário
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: CircleAvatar(
                radius: 18,
                backgroundImage: NetworkImage(data['senderPhotoUrl'] ?? ''),
              ),
            ),

          // Balão da mensagem
          Flexible(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 220),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
              decoration: BoxDecoration(
                color: isMe ? Colors.cyan[500] : Colors.grey[300],
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(10),
                  topRight: const Radius.circular(10),
                  bottomLeft: isMe
                      ? const Radius.circular(10)
                      : const Radius.circular(0),
                  bottomRight: isMe
                      ? const Radius.circular(0)
                      : const Radius.circular(10),
                ),
              ),
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Nome do usuário
                  if (data['senderName'] != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        data['senderName'],
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: isMe ? Colors.white : Colors.black87,
                        ),
                      ),
                    ),

                  // Imagem (se existir)
                  if (hasImage)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.network(
                        data['imgUrl'],
                        width: double.infinity,
                        height: 300,
                        fit: BoxFit.cover,
                      ),
                    ),

                  // Texto (se existir)
                  if (hasText)
                    Padding(
                      padding: EdgeInsets.only(top: hasImage ? 8 : 0),
                      child: Text(
                        data['text'],
                        style: TextStyle(
                          fontSize: 18,
                          color: isMe ? Colors.white : Colors.black87,
                        ),
                        textAlign: isMe ? TextAlign.start : TextAlign.end,
                        softWrap: true,
                        overflow: TextOverflow.visible,
                        maxLines: null,
                      ),
                    ),

                  // Áudio (se existir)
                  if (hasAudio)
                    Padding(
                      padding: EdgeInsets.only(
                        top: hasText || hasImage ? 8 : 0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                onPressed: () => _togglePlay(data['audioUrl']),
                                icon: Icon(
                                  _isPlaying ? Icons.pause : Icons.play_arrow,
                                  color: isMe ? Colors.white : Colors.black87,
                                ),
                              ),
                              Expanded(
                                child: Slider(
                                  activeColor: isMe
                                      ? Colors.white
                                      : Colors.black87,
                                  inactiveColor: isMe
                                      ? Colors.white38
                                      : Colors.black26,
                                  value: _position.inSeconds.toDouble().clamp(
                                    0.0,
                                    _duration.inSeconds.toDouble(),
                                  ),
                                  max: _duration.inSeconds.toDouble() > 0
                                      ? _duration.inSeconds.toDouble()
                                      : 1,
                                  onChanged: (value) async {
                                    await _audioPlayer.seek(
                                      Duration(seconds: value.toInt()),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                          // Duração e tempo atual
                          Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Text(
                              '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isMe ? Colors.white : Colors.black54,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 4),

                  // Hora da mensagem
                  Align(
                    alignment: Alignment.bottomRight,
                    child: Text(
                      formattedTime,
                      style: TextStyle(
                        fontSize: 12,
                        color: isMe ? Colors.white : Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Avatar do próprio usuário
          if (isMe)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: CircleAvatar(
                radius: 18,
                backgroundImage: NetworkImage(data['senderPhotoUrl'] ?? ''),
              ),
            ),
        ],
      ),
    );
  }
}
