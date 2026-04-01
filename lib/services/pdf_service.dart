import 'dart:io';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class PdfService {
  /// Extracts all plain text from a PDF file.
  /// Returns the extracted text, or throws on error.
  Future<String> extractText(String filePath) async {
    final bytes = await File(filePath).readAsBytes();
    final document = PdfDocument(inputBytes: bytes);
    final extractor = PdfTextExtractor(document);
    final text = extractor.extractText();
    document.dispose();
    if (text.trim().isEmpty) {
      throw Exception(
        'No extractable text found in the PDF. '
        'The file may be scanned or image-only.',
      );
    }
    return text;
  }

  /// Builds the system prompt that restricts GPT to answer only from the PDF.
  String buildSystemPrompt(String pdfText, String pdfName) {
    // Truncate to stay within sensible token limits (~60 000 chars ≈ 15k tokens)
    const maxChars = 60000;
    final truncated = pdfText.length > maxChars
        ? '${pdfText.substring(0, maxChars)}\n\n[...document truncated for length...]'
        : pdfText;

    return '''You are a helpful assistant. You MUST answer questions based ONLY on the content of the document provided below. If the answer is not found in the document, say: "I could not find that information in the provided document."

Document name: "$pdfName"

--- BEGIN DOCUMENT ---
$truncated
--- END DOCUMENT ---
''';
  }
}
