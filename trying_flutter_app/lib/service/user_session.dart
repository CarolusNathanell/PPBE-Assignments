import 'package:firebase_auth/firebase_auth.dart';

class UserSession {
  UserSession._privateConstructor();

  static final UserSession _instance = UserSession._privateConstructor();

  static UserSession get instance => _instance;

  User? _user;

  /// Set the current user
  void setUser(User? user) {
    _user = user;
  }

  /// Get the current user
  User? get user => _user;

  /// Get the user's ID token (JWT)
  Future<String?> getIdToken() async {
    if (_user != null) {
      return await _user!.getIdToken();
    }
    return null;
  }

  /// Clear the session
  void clear() {
    _user = null;
  }
}
