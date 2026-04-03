import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

class _VoiceDictationEngine {
  static final SpeechToText _speechToText = SpeechToText();
  static bool _isListening = false;
  static bool _isInitialized = false;
  static int _sessionId = 0;
  static int _activeSessionId = 0;
  static String? _lastErrorMessage;
  static String _currentTranscript = '';
  static bool _currentEmitted = false;
  static void Function(String text)? _currentOnFinalResult;
  static void Function(bool isListening)? _currentOnListeningStateChanged;
  static void Function(String text)? _currentOnPartialResult;
  static void Function(bool hadSpeech)? _currentOnDone;

  static String mapLocaleId(String language) {
    switch (language.toLowerCase()) {
      case 'hindi':
        return 'hi_IN';
      case 'marathi':
        return 'mr_IN';
      default:
        return 'en_IN';
    }
  }

  static bool get isListening => _isListening;
  static String? get lastErrorMessage => _lastErrorMessage;

  static Future<void> stop() async {
    await _speechToText.stop();
    _isListening = false;
  }

  static Future<bool> _ensureInitialized() async {
    if (_isInitialized) {
      return true;
    }

    final available = await _speechToText.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          if (!_currentEmitted && _currentTranscript.isNotEmpty) {
            _currentEmitted = true;
            _currentOnFinalResult?.call(_currentTranscript);
            _currentTranscript = '';
          }
          _isListening = false;
          _currentOnListeningStateChanged?.call(false);
          _currentOnDone?.call(_currentEmitted);
          _activeSessionId = 0;
        }
      },
      onError: (error) {
        _lastErrorMessage = _describeError(error.errorMsg);
        _isListening = false;
        _currentOnListeningStateChanged?.call(false);
        _currentOnDone?.call(false);
        _activeSessionId = 0;
      },
    );

    _isInitialized = available;
    if (!available) {
      _lastErrorMessage =
          'Speech recognition is unavailable in this browser or microphone access was blocked.';
    }
    return available;
  }

  static Future<bool> start({
    required String language,
    required void Function(String text) onFinalResult,
    required void Function(bool isListening) onListeningStateChanged,
    void Function(String text)? onPartialResult,
    void Function(bool hadSpeech)? onDone,
    bool restartIfAlreadyListening = false,
  }) async {
    _lastErrorMessage = null;
    _currentTranscript = '';
    _currentEmitted = false;

    if (_isListening) {
      if (!restartIfAlreadyListening) {
        await stop();
        onListeningStateChanged(false);
        onDone?.call(false);
        return false;
      }

      // Invalidate previous session callbacks before stopping so old mic UI
      // doesn't enter "processing" when another field mic is tapped.
      _sessionId++;
      await _speechToText.stop();
      _isListening = false;
    }

    final thisSession = ++_sessionId;
    _activeSessionId = thisSession;
    _currentOnFinalResult = onFinalResult;
    _currentOnListeningStateChanged = onListeningStateChanged;
    _currentOnPartialResult = onPartialResult;
    _currentOnDone = onDone;

    final available = await _ensureInitialized();

    if (!available) {
      return false;
    }

    _isListening = true;
    onListeningStateChanged(true);

    await _speechToText.listen(
      localeId: mapLocaleId(language),
      listenMode: ListenMode.dictation,
      partialResults: true,
      onResult: (result) {
        if (thisSession != _activeSessionId) return;
        final words = result.recognizedWords.trim();
        if (words.isNotEmpty) {
          _currentTranscript = words;
          _currentOnPartialResult?.call(words);
        }
        if (result.finalResult && _currentTranscript.isNotEmpty) {
          _currentEmitted = true;
          _currentOnFinalResult?.call(_currentTranscript);
          _currentTranscript = '';
        }
      },
      onSoundLevelChange: (_) {},
      cancelOnError: true,
      listenFor: const Duration(seconds: 45),
      pauseFor: const Duration(seconds: 6),
    );

    return true;
  }

  static String _describeError(String errorCode) {
    switch (errorCode) {
      case 'error_permission':
      case 'error_permission_denied':
      case 'not-allowed':
      case 'service-not-allowed':
        return 'Microphone permission was denied.';
      case 'error_network':
      case 'error_network_timeout':
      case 'network':
        return 'Speech recognition needs a stable network connection.';
      case 'error_no_match':
      case 'no-speech':
        return 'No speech was detected. Please try again.';
      case 'error_speech_timeout':
        return 'Listening timed out before speech was detected.';
      case 'audio-capture':
        return 'No microphone was found in this browser.';
      case 'aborted':
        return 'Speech input was stopped before transcription finished.';
      case 'speech_not_supported':
      case 'not supported':
        return 'This browser does not support speech recognition.';
      default:
        return 'Speech recognition failed. Please try again.';
    }
  }

  static void insertIntoFocusedField(String recognizedText) {
    final trimmed = recognizedText.trim();
    if (trimmed.isEmpty) return;

    final focusedContext = FocusManager.instance.primaryFocus?.context;
    if (focusedContext == null) return;

    EditableTextState? editableState;

    if (focusedContext is StatefulElement &&
        focusedContext.state is EditableTextState) {
      editableState = focusedContext.state as EditableTextState;
    } else {
      editableState = focusedContext.findAncestorStateOfType<EditableTextState>();
    }

    if (editableState == null) return;

    _insertIntoController(editableState.widget.controller, trimmed);
  }

  static void insertIntoController(
    TextEditingController controller,
    String recognizedText,
  ) {
    final trimmed = recognizedText.trim();
    if (trimmed.isEmpty) return;
    _insertIntoController(controller, trimmed);
  }

  static void _insertIntoController(
    TextEditingController controller,
    String trimmed,
  ) {
    final currentText = controller.text;
    final selection = controller.selection;

    final start = selection.start >= 0 ? selection.start : currentText.length;
    final end = selection.end >= 0 ? selection.end : currentText.length;
    final safeStart = start.clamp(0, currentText.length);
    final safeEnd = end.clamp(0, currentText.length);

    final before = currentText.substring(0, safeStart);
    final after = currentText.substring(safeEnd);
    final spacer = before.isNotEmpty && !before.endsWith(' ') ? ' ' : '';
    final inserted = '$spacer$trimmed';
    final nextText = '$before$inserted$after';
    final nextOffset = (before + inserted).length;

    controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextOffset),
    );
  }
}

class VoiceDictationButton extends StatefulWidget {
  final String language;

  const VoiceDictationButton({
    super.key,
    required this.language,
  });

  @override
  State<VoiceDictationButton> createState() => _VoiceDictationButtonState();
}

class _VoiceDictationButtonState extends State<VoiceDictationButton> {
  bool _isListening = false;

  Future<void> _toggleListening() async {
    final wasListening = _VoiceDictationEngine.isListening;
    final ok = await _VoiceDictationEngine.start(
      language: widget.language,
      onFinalResult: _VoiceDictationEngine.insertIntoFocusedField,
      onListeningStateChanged: (listening) {
        if (!mounted) return;
        setState(() => _isListening = listening);
      },
      restartIfAlreadyListening: true,
    );
    if (!ok && !wasListening && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _VoiceDictationEngine.lastErrorMessage ??
                'Voice recognition is unavailable here.',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    if (_isListening) {
      _VoiceDictationEngine.stop();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: _toggleListening,
      icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
      label: Text(_isListening ? 'Listening...' : 'Voice Input'),
      style: OutlinedButton.styleFrom(
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}

class VoiceFieldMicIcon extends StatefulWidget {
  final String language;
  final TextEditingController controller;

  const VoiceFieldMicIcon({
    super.key,
    required this.language,
    required this.controller,
  });

  @override
  State<VoiceFieldMicIcon> createState() => _VoiceFieldMicIconState();
}

class _VoiceFieldMicIconState extends State<VoiceFieldMicIcon>
    with SingleTickerProviderStateMixin {
  static const _processingHold = Duration(milliseconds: 500);
  static const _stopFallback = Duration(milliseconds: 1200);
  static final ValueNotifier<int?> _activeOwnerId = ValueNotifier<int?>(null);
  static int _ownerCounter = 0;

  late final int _ownerId;
  late final AnimationController _pulseController;
  _MicUiState _state = _MicUiState.idle;

  @override
  void initState() {
    super.initState();
    _ownerId = ++_ownerCounter;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _activeOwnerId.addListener(_onActiveOwnerChanged);
  }

  void _onActiveOwnerChanged() {
    if (!mounted) return;
    if (_activeOwnerId.value == _ownerId) return;
    if (_state == _MicUiState.idle) return;
    setState(() => _state = _MicUiState.idle);
    _pulseController.stop();
  }

  Future<void> _toggleListening() async {
    final isActiveOwner = _activeOwnerId.value == _ownerId;
    if (isActiveOwner && _VoiceDictationEngine.isListening) {
      if (mounted) {
        setState(() {
          _state = _MicUiState.processing;
          _pulseController.stop();
        });
      }
      await _VoiceDictationEngine.stop();
      _resetToIdleAfterFallback();
      return;
    }

    if (_state == _MicUiState.processing) {
      return;
    }

    _activeOwnerId.value = _ownerId;

    widget.controller.selection = TextSelection.collapsed(
      offset: widget.controller.text.length,
    );

    final wasListening = _VoiceDictationEngine.isListening;
    final ok = await _VoiceDictationEngine.start(
      language: widget.language,
      onFinalResult: (text) =>
          _VoiceDictationEngine.insertIntoController(widget.controller, text),
      onListeningStateChanged: (listening) {
        if (!mounted) return;
        if (!listening && _activeOwnerId.value != _ownerId) {
          return;
        }
        setState(() {
          if (listening) {
            _state = _MicUiState.listening;
            _pulseController.repeat(reverse: true);
          } else {
            _state = _MicUiState.processing;
            _pulseController.stop();
          }
        });
      },
      onDone: (hadSpeech) async {
        if (!mounted) return;
        if (_activeOwnerId.value != _ownerId) {
          return;
        }
        if (!hadSpeech) {
          _activeOwnerId.value = null;
          setState(() {
            _state = _MicUiState.idle;
          });
          return;
        }

        await Future<void>.delayed(_processingHold);
        if (!mounted) return;
        if (_activeOwnerId.value != _ownerId) {
          return;
        }
        _activeOwnerId.value = null;
        setState(() {
          _state = _MicUiState.idle;
        });
      },
      restartIfAlreadyListening: true,
    );

    if (!ok && !wasListening && mounted) {
      if (_activeOwnerId.value == _ownerId) {
        _activeOwnerId.value = null;
      }
      setState(() {
        _state = _MicUiState.idle;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _VoiceDictationEngine.lastErrorMessage ??
                'Voice recognition is unavailable here.',
          ),
        ),
      );
    }
  }

  void _resetToIdleAfterFallback() {
    Future<void>.delayed(_stopFallback, () {
      if (!mounted) return;
      if (_activeOwnerId.value != _ownerId) return;
      if (_VoiceDictationEngine.isListening) return;
      if (_state != _MicUiState.processing) return;
      _activeOwnerId.value = null;
      setState(() => _state = _MicUiState.idle);
    });
  }

  @override
  void dispose() {
    _activeOwnerId.removeListener(_onActiveOwnerChanged);
    if (_activeOwnerId.value == _ownerId) {
      _activeOwnerId.value = null;
      if (_VoiceDictationEngine.isListening) {
        _VoiceDictationEngine.stop();
      }
    }
    _pulseController.dispose();
    super.dispose();
  }

  Widget _buildIdle() {
    return IconButton(
      tooltip: 'Voice Input',
      icon: const Icon(Icons.mic_none),
      onPressed: _toggleListening,
    );
  }

  Widget _buildListening() {
    return InkWell(
      onTap: _toggleListening,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                final scale = 1.0 + (_pulseController.value * 0.25);
                return Transform.scale(
                  scale: scale,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.red.withOpacity(0.14),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.mic,
                      color: Colors.red,
                      size: 16,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(width: 6),
            const Text(
              'Listening...',
              style: TextStyle(
                fontSize: 11,
                color: Colors.red,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            GestureDetector(
              onTap: _toggleListening,
              child: Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.arrow_upward,
                  size: 13,
                  color: Colors.red,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProcessing() {
    return const Padding(
      padding: EdgeInsets.symmetric(horizontal: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: 6),
          Text(
            'Converting speech...',
            style: TextStyle(
              fontSize: 11,
              color: Colors.blueGrey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 48),
      child: switch (_state) {
        _MicUiState.idle => _buildIdle(),
        _MicUiState.listening => _buildListening(),
        _MicUiState.processing => _buildProcessing(),
      },
    );
  }
}

enum _MicUiState {
  idle,
  listening,
  processing,
}
