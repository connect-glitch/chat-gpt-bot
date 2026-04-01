# 🤖 AI Chat Bot — Flutter + OpenAI + Whisper + PDF Scope

> **YouTube Tutorial Companion** — Follow along step by step to build a full-featured AI chatbot in Flutter from scratch.

---

## 📺 What We're Building

A Flutter mobile app that:
- Asks for your **OpenAI API key** on first launch and stores it securely in **SQLite**
- Lets you **chat with GPT-4o** with full conversation history
- Accepts **voice messages** — recorded audio is transcribed via **Whisper** and sent as a chat message
- Lets you **load a PDF** so GPT answers *only* from that document (great for Q&A on contracts, books, manuals)
- Supports **dark & light mode** out of the box (Material 3)

---

## ✅ Step-by-Step Checklist

### 1 · Prerequisites
- [ ] Install [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.x or later)
- [ ] Install [Android Studio](https://developer.android.com/studio) or Xcode (for iOS)
- [ ] Connect a physical device **or** start an emulator
- [ ] Get an [OpenAI API key](https://platform.openai.com/api-keys) — you'll need it at runtime

---

### 2 · Clone & Install
```bash
git clone https://github.com/connect-glitch/chat-gpt-bot.git
cd chat-gpt-bot
flutter pub get
```

---

### 3 · Project Structure
```
lib/
├── main.dart                    ← App entry point + splash router
├── models/
│   └── message_model.dart       ← Message data model
├── screens/
│   ├── api_key_screen.dart      ← First-run API key entry screen
│   └── chat_screen.dart         ← Main chat UI
├── services/
│   ├── database_service.dart    ← SQLite (key storage + chat history)
│   ├── openai_service.dart      ← Chat Completions + Whisper API calls
│   ├── pdf_service.dart         ← PDF text extraction + system prompt
│   └── audio_service.dart       ← Microphone recording
└── widgets/
    └── chat_bubble.dart         ← Styled message bubbles
```

---

### 4 · Key Packages Used
| Package | Purpose |
|---|---|
| `sqflite` | Local SQLite database |
| `http` | OpenAI REST API calls |
| `record` | Microphone recording for Whisper |
| `syncfusion_flutter_pdf` | Extract text from PDF files |
| `file_picker` | Let the user pick a PDF |
| `permission_handler` | Request mic permission on Android/iOS |
| `path_provider` | Locate temp/storage directories |

---

### 5 · Android Permissions to Add
In `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
```
> Already included in this repo ✅

---

### 6 · iOS Permissions to Add
In `ios/Runner/Info.plist`:
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Needed to record voice messages for transcription.</string>
<key>UIFileSharingEnabled</key>
<true/>
```
> Already included in this repo ✅

---

### 7 · Run the App
```bash
flutter run
```
1. On first launch → enter your `sk-...` API key
2. Key is validated against OpenAI and stored in SQLite
3. Start chatting by typing **or** tapping the 🎤 mic button
4. Tap the **PDF icon** in the top bar to load a document — GPT will only answer from it
5. Tap the PDF banner's ✕ to remove the scope and return to general knowledge

---

### 8 · How the PDF Scope Works
1. You pick a `.pdf` file
2. The app extracts all text using `syncfusion_flutter_pdf`
3. That text is injected as a **system prompt**: *"Answer ONLY from this document"*
4. Every subsequent message is sent with this context — GPT stays on-topic
5. Remove it any time from the banner

---

### 9 · How Whisper Voice Input Works
1. Tap 🎤 → recording starts (`.m4a`, 16 kHz)
2. Tap ⏹ → recording stops
3. The audio file is sent to `whisper-1` via the OpenAI API
4. The transcription is displayed as your message and replied to by GPT

---

### 10 · Things to Extend (Homework!)
- [ ] Add **text-to-speech** to read GPT replies aloud
- [ ] Support **multiple chat sessions** (conversations list)
- [ ] Add a **model picker** (GPT-4o, GPT-4o-mini, etc.)
- [ ] Stream GPT replies token-by-token for a faster feel
- [ ] Add **image attachment** support (GPT-4o vision)
- [ ] Export chat history as a PDF or text file

---

## 🔒 Security Notes
- Your API key is stored in **local SQLite only** — it never leaves your device except for direct calls to `api.openai.com`
- Never commit your key to git — the `.gitignore` already excludes `*.env` and `secrets.dart`

---

## 📄 License
MIT — free to use, modify, and share.
