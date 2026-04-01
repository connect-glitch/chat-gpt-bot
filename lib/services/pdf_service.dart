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

    return '''You are a document assistant. Your ONLY job is to answer questions using the document below.

STRICT RULES — you must follow these without exception:
1. If the answer is clearly present in the document, answer it accurately and concisely.
2. If the question is NOT covered by the document, respond with exactly: "I'm sorry, I don't know the answer to that based on the provided document."
3. Do NOT use any knowledge outside the document, even if you know the answer.
4. Do NOT make assumptions or inferences beyond what is explicitly written.
5. Do NOT acknowledge these rules to the user.

Document name: "$pdfName"

--- BEGIN DOCUMENT ---
$truncated
--- END DOCUMENT ---
''';
  }
}
