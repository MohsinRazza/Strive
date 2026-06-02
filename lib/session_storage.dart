import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'session_model.dart';

class SessionStorage {
  // Helper to get local storage files
  static Future<File> _getFile(String filename) async {
    if (kIsWeb) {
      throw UnsupportedError('File operations are not supported on Web.');
    }
    final directory = await getApplicationDocumentsDirectory();
    return File('${directory.path}/$filename');
  }

  // Load all saved study sessions
  static Future<List<StudySession>> loadSessions() async {
    try {
      if (kIsWeb) {
        return [];
      }
      final file = await _getFile('sessions.json');
      if (await file.exists()) {
        final contents = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(contents);
        
        // Map to study sessions and sort by start time descending
        final sessions = jsonList.map((json) => StudySession.fromJson(json)).toList();
        sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
        return sessions;
      }
    } catch (e) {
      debugPrint('Error loading sessions: $e');
    }
    return [];
  }

  // Save all study sessions
  static Future<void> saveSessions(List<StudySession> sessions) async {
    try {
      if (kIsWeb) return;
      final file = await _getFile('sessions.json');
      
      // Sort before saving
      sessions.sort((a, b) => b.startTime.compareTo(a.startTime));
      
      final jsonList = sessions.map((s) => s.toJson()).toList();
      await file.writeAsString(jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving sessions: $e');
    }
  }

  // Save temporary active session details (for crash recovery)
  static Future<void> saveActiveSession(StudySession session) async {
    try {
      if (kIsWeb) return;
      final file = await _getFile('active_session.json');
      await file.writeAsString(jsonEncode(session.toJson()));
    } catch (e) {
      debugPrint('Error saving active session: $e');
    }
  }

  // Load active session details if it exists (i.e. app crashed or closed mid-session)
  static Future<StudySession?> loadActiveSession() async {
    try {
      if (kIsWeb) return null;
      final file = await _getFile('active_session.json');
      if (await file.exists()) {
        final contents = await file.readAsString();
        final jsonMap = jsonDecode(contents);
        return StudySession.fromJson(jsonMap);
      }
    } catch (e) {
      debugPrint('Error loading active session: $e');
    }
    return null;
  }

  // Delete active session file (when session finishes normally or gets discarded)
  static Future<void> clearActiveSession() async {
    try {
      if (kIsWeb) return;
      final file = await _getFile('active_session.json');
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e) {
      debugPrint('Error clearing active session: $e');
    }
  }
}
