class AdminAuthService {
  static String adminPassword = "987654";

  static bool login(String password) {
    return password == adminPassword;
  }

  static void changePassword(String newPass) {
    adminPassword = newPass;
  }
}
