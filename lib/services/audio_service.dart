import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class AudioService {
  final AudioRecorder _recorder = AudioRecorder();

  bool _isRecording = false;
  bool get isRecording => _isRecording;

  /// Starts recording. Saves to a temp .m4a file.
  /// Returns the path where the recording will be saved.
  Future<String> startRecording() async {
    final dir = await getTemporaryDirectory();
    final path = p.join(
      dir.path,
      'rec_${DateTime.now().millisecondsSinceEpoch}.m4a',
    );

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 16000, // 16 kHz preferred by Whisper
      ),
      path: path,
    );
    _isRecording = true;
    return path;
  }

  /// Stops recording and returns the file path of the saved audio.
  Future<String?> stopRecording() async {
    final path = await _recorder.stop();
    _isRecording = false;
    return path;
  }

  /// Check if microphone permission is available via the record package.
  Future<bool> hasMicrophonePermission() async {
    return await _recorder.hasPermission();
  }

  void dispose() {
    _recorder.dispose();
  }
}
