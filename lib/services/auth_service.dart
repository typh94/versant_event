import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _kUsernameKey = 'auth.username';
  static const String _kRoleKey = 'auth.role';

  // Simple in-app user directory
  // role: 'tech' or 'admin'
  static const List<Map<String, String>> users = [
    {'username': 'kane', 'password': 'kane123', 'role': 'tech'},
    {'username': 'SAB', 'password': 'samir123', 'role': 'tech'},
    {'username': 'MCO', 'password': 'maati123', 'role': 'tech'},
    {'username': 'JOS', 'password': 'johan123', 'role': 'tech'},
    {'username': 'AMM', 'password': 'alexis123', 'role': 'tech'},
    {'username': 'CHO', 'password': 'cham123', 'role': 'tech'},
    {'username': 'DIB', 'password': 'didier123', 'role': 'tech'},
    {'username': 'PRESTA', 'password': 'cham123', 'role': 'tech'},
    {'username': 'admin', 'password': 'admin123', 'role': 'admin'},
  ];

  static Future<bool> login(String username, String password) async {
    final match = users.firstWhere(
      (u) => u['username'] == username && u['password'] == password,
      orElse: () => {},
    );
    if (match.isEmpty) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUsernameKey, match['username']!);
    await prefs.setString(_kRoleKey, match['role']!);
    return true;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUsernameKey);
    await prefs.remove(_kRoleKey);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kUsernameKey) != null;
  }

  static Future<String?> currentUsername() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kUsernameKey);
  }

  static Future<String?> currentRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kRoleKey);
  }

  static Future<Map<String, String>?> currentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final u = prefs.getString(_kUsernameKey);
    final r = prefs.getString(_kRoleKey);
    if (u == null || r == null) return null;
    return {'username': u, 'role': r};
  }

  static bool isAdminRole(String? role) => role == 'admin';
  static bool isTechRole(String? role) => role == 'tech';
}