import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dialogflow/chatMessage.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:rxdart/subjects.dart';
import 'package:sound_stream/sound_stream.dart';
import 'package:dialog_flowtter/dialog_flowtter.dart';
import 'package:rxdart/rxdart.dart';

class Chat extends StatefulWidget {
  const Chat({super.key});

  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  final List<ChatMessage> _messages = <ChatMessage>[];
  final TextEditingController _textController = TextEditingController();

  bool _isRecording = false;

  final RecorderStream _recorder = RecorderStream();
  late StreamSubscription _recorderStatus;
  late StreamSubscription<List<int>> _audioStreamSubscription;
  late BehaviorSubject<List<int>> _audioStream;

// TODO DialogFlowtter class instance
  late DialogAuthCredentials _credentials;
  late DialogFlowtter _instance;

  //VOICE
  late FlutterTts flutterTts;
  String? language;
  String? engine;
  double volume = 1.0;
  double pitch = 1.0;
  double rate = 0.5;
  bool get isIOS => !kIsWeb && Platform.isIOS;
  bool get isAndroid => !kIsWeb && Platform.isAndroid;
  String? _newVoiceText;
  int? _inputLength;

  Future<dynamic> _getLanguages() async => await flutterTts.getLanguages;
  Future<dynamic> _getEngines() async => await flutterTts.getEngines;

  Future<void> _getDefaultEngine() async {
    var engine = await flutterTts.getDefaultEngine;
    if (engine != null) {
      print(engine);
    }
  }

  Future<void> _getDefaultVoice() async {
    var voice = await flutterTts.getDefaultVoice;
    if (voice != null) {
      print(voice);
    }
  }

  @override
  void initState() {
    super.initState();
    initPlugin();
    initTts();
  }

  @override
  void dispose() {
    _recorderStatus?.cancel();
    _audioStreamSubscription?.cancel();
    flutterTts.stop();
    _instance.dispose();
    super.dispose();
  }

  dynamic initTts() {
    flutterTts = FlutterTts();

    _setAwaitOptions();

    if (isAndroid) {
      _getDefaultEngine();
      _getDefaultVoice();
    }
    flutterTts.setLanguage("fr-FR");
  }

  Future<void> _speak() async {
    await flutterTts.setVolume(volume);
    await flutterTts.setSpeechRate(rate);
    await flutterTts.setPitch(pitch);

    if (_newVoiceText != null) {
      if (_newVoiceText!.isNotEmpty) {
        print("Saying: $_newVoiceText");
        await flutterTts.speak(_newVoiceText!);
      }
    }
  }

  Future<void> _setAwaitOptions() async {
    await flutterTts.awaitSpeakCompletion(true);
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlugin() async {
    _recorderStatus = _recorder.status.listen((status) {
      if (mounted) {
        setState(() {
          _isRecording = status == SoundStreamStatus.Playing;
        });
      }
    });

    await Future.wait([_recorder.initialize()]);

    // TODO Get a Service account
    initDialogFlow();
  }

  void initDialogFlow() async {
    _credentials =
        await DialogAuthCredentials.fromFile("assets/credentials.json");
    _instance = DialogFlowtter(
        credentials: _credentials,
        sessionId: DateTime.now().millisecondsSinceEpoch.toString());
  }

  void stopStream() async {
    await _recorder.stop();
    await _audioStreamSubscription?.cancel();
    await _audioStream?.close();
  }

  void handleSubmitted(text) async {
    _textController.clear();

    //TODO Dialogflow Code
    _addMessage(text, "You", type: true);

    final QueryInput queryInput = QueryInput(
      text: TextInput(
        text: text,
        languageCode: "fr",
      ),
    );

    DetectIntentResponse response =
        await _instance.detectIntent(queryInput: queryInput);
    String? textResponse = response.text;

    if (textResponse == null) {
      return;
    } else {
      _addMessage(textResponse, "Bot", type: false);
      setState(() {
        _newVoiceText = textResponse;
      });
      _speak();
    }
  }

  _addMessage(String text, String name, {bool type = true}) {
    ChatMessage message = ChatMessage(
      text: text,
      name: name,
      type: type,
    );
    setState(() {
      _messages.insert(0, message);
    });
  }

  void handleStream() async {
    _recorder.start();

    _audioStream = BehaviorSubject<List<int>>();
    _audioStreamSubscription = _recorder.audioStream.listen((data) {
      print(data);
      _audioStream.add(data);
    });

    // TODO Create SpeechContexts
    // Create an audio InputConfig

    // TODO Make the streamingDetectIntent call, with the InputConfig and the audioStream
    // TODO Get the transcript and detectedIntent and show on screen
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Flexible(
          child: ListView.builder(
            padding: const EdgeInsets.all(8.0),
            reverse: true,
            itemBuilder: (_, int index) => _messages[index],
            itemCount: _messages.length,
          ),
        ),
        const Divider(height: 1.0),
        Container(
          decoration: BoxDecoration(color: Theme.of(context).cardColor),
          child: IconTheme(
            data: IconThemeData(color: Theme.of(context).canvasColor),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  Flexible(
                    child: TextField(
                      controller: _textController,
                      onSubmitted: handleSubmitted,
                      decoration: const InputDecoration.collapsed(
                          hintText: "Send a message"),
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.symmetric(horizontal: 4.0),
                    child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.black45),
                      onPressed: () => handleSubmitted(_textController.text),
                    ),
                  ),
                  IconButton(
                    iconSize: 30.0,
                    icon: Icon(_isRecording ? Icons.mic_off : Icons.mic,
                        color: Colors.black45),
                    onPressed: _isRecording ? stopStream : handleStream,
                  ),
                ],
              ),
            ),
          ),
        )
      ],
    );
  }
}
