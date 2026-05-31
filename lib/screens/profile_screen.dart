import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:news_application/screens/sign_in_screen.dart';
import 'package:url_launcher/url_launcher.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool loading = true;
  bool notificationsEnabled = true;

  String name = "";
  String email = "";
  

  final String disclaimerText = '''
RupeeLetter is a financial news and information platform.

All content is provided for educational and informational purposes only and should not be considered investment advice.

RupeeLetter is not a SEBI-registered advisor and does not recommend buying, selling, or holding any securities.

Users should conduct their own research or consult a qualified professional before making investment decisions.
''';
final String termsText = '''
By using the RupeeLetter app, you agree to the following:

• RupeeLetter provides financial news and information for informational purposes only.

• Content is sourced from third parties and public information; accuracy or completeness is not guaranteed.

• RupeeLetter does not provide investment, legal, or financial advice.

• Users are responsible for how they use the information provided.

• We may update, modify, or discontinue features without prior notice.

• Misuse of the app or attempts to disrupt services may result in account suspension.

• Continued use of the app constitutes acceptance of these Terms.
''';
final String privacyPolicyText = '''


RupeeLetter respects your privacy and is committed to protecting your personal information.

1. Information We Collect
• Name
• Email address or mobile number
• User preferences (notifications, followed stocks)

2. Automatically Collected Information
• App usage activity
• Device information
• Crash logs and performance data

3. Information We Do Not Collect
• Bank details
• Trading or brokerage data
• PAN, Aadhaar, or KYC information

4. How We Use Your Information
• Deliver relevant financial news
• Personalize content
• Improve app performance
• Respond to support requests

We do not sell your personal data.

5. Notifications
You can enable or disable notifications at any time from the App.

6. Your Rights
You may update preferences, opt out of notifications, or request account deletion.

7. Contact Us
Email: contact@rupeeletter.com
Website: https://rupeeletter.com
''';

final String feedbackText = '''
Have a question, spotted an issue, or want to share feedback?
We’re here to help.

RupeeLetter is built to deliver fast, clear, and reliable financial news.
Your feedback helps us improve.

Get in Touch
Email: contact@rupeeletter.com
Response time: Within 24–48 hours (business days)

For faster resolution, please mention:
• Your registered email (if applicable)
• App version
• Short description of the issue or feedback

App Support
You can contact us for:
• Incorrect or delayed news
• App bugs or crashes
• Notification issues
• Feature suggestions
• Account-related queries

Privacy & Data Requests
For privacy-related concerns, data usage questions, or account deletion requests, contact:
Email: contact@rupeeletter.com

Disclaimer
RupeeLetter provides financial news and information for educational and informational purposes only.
We do not provide investment advice or recommendations.

About RupeeLetter
RupeeLetter is a financial news and insights platform focused on simplifying market updates, corporate news, and key events for investors and market participants.
''';


  


  static const String baseUrl = "http://51.20.136.45:5000";

  @override
  void initState() {
    super.initState();
    fetchProfile();
    _loadNotificationPreference();
  }

  /// Load notification preference from SharedPreferences
  Future<void> _loadNotificationPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      notificationsEnabled = prefs.getBool('notificationsEnabled') ?? true;
    });
  }

  /// Toggle notification preference, persist it, and subscribe/unsubscribe from FCM topic
  Future<void> _toggleNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('notificationsEnabled', value);

    final messaging = FirebaseMessaging.instance;
    if (value) {
      await messaging.subscribeToTopic('market_alerts');
      debugPrint('✅ Subscribed to market_alerts');
    } else {
      await messaging.unsubscribeFromTopic('market_alerts');
      debugPrint('🔕 Unsubscribed from market_alerts');
    }

    setState(() {
      notificationsEnabled = value;
    });
  }

  /// 🔹 FETCH PROFILE
  Future<void> fetchProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString("userId");

    debugPrint("📍 Fetching profile for userId: $userId");

    if (userId == null) {
      debugPrint("❌ No userId found in SharedPreferences");
      setState(() {
        loading = false;
      });
      return;
    }

    try {
      debugPrint("🌐 Calling API: $baseUrl/api/users/profile");
      final response = await http.post(
        Uri.parse("$baseUrl/api/users/profile"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"userId": userId}),
      );

      debugPrint("📡 Response status: ${response.statusCode}");
      debugPrint("📦 Response body: ${response.body}");

      if (response.statusCode != 200) {
        throw Exception("API returned ${response.statusCode}");
      }

      final data = jsonDecode(response.body);
      final user = data['user'];

      debugPrint("✅ User data received: $user");

      setState(() {
        name = user['name'] ?? "";
        email = user['email'] ?? "";

        loading = false;
      });
    } catch (e) {
      debugPrint("❌ Profile fetch error: $e");
      setState(() {
        loading = false;
      });
    }
  }

  Future<void> deleteAccount() async {
  final prefs = await SharedPreferences.getInstance();
  final userId = prefs.getString("userId");

  if (userId == null) return;

  try {
    final response = await http.post(
      Uri.parse("$baseUrl/api/users/delete-account"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"userId": userId}),
    );

    if (response.statusCode == 200) {
      await prefs.clear();

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const SignInScreen()),
        (route) => false,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Account deleted successfully")),
      );
    } else {
      throw Exception("Delete failed");
    }
  } catch (e) {
    debugPrint("❌ Delete account error: $e");

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Failed to delete account")),
    );
  }
}
void showDeleteDialog() {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text("Delete Account"),
      content: const Text(
        "Are you sure? This action cannot be undone.",
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel"),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            deleteAccount();
          },
          child: const Text(
            "Delete",
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    ),
  );
}

  /// 🔹 LOGOUT
  Future<void> logout() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.clear();

  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(builder: (_) => const SignInScreen()),
    (route) => false,
  );
}

Future<void> _openUrl(String url) async {
  final uri = Uri.parse(url);
  
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    await launchUrl(uri, mode: LaunchMode.inAppWebView);
  }
}


@override
Widget build(BuildContext context) {
  if (loading) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }

  return Scaffold(
    backgroundColor: const Color(0xFFF5F5F5),
    appBar: AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      title: Text(
        "Profile",
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
      centerTitle: false,
      leading: const BackButton(color: Colors.black),
    ),
    body: SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 30),

          /// PROFILE AVATAR
          Center(
            child: CircleAvatar(
              radius: 50,
              backgroundColor: const Color(0xFFE8E8E8),
              child: Icon(
                Icons.person_outline,
                size: 50,
                color: Colors.grey.shade600,
              ),
            ),
          ),

          const SizedBox(height: 16),

          /// NAME
          Text(
            name.isEmpty ? "No name" : name,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),

          const SizedBox(height: 4),

          /// EMAIL
          Text(
            email.isEmpty ? "No email" : email,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),

          const SizedBox(height: 30),

          /// DATA & PRIVACY SECTION
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "DATA & PRIVACY",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                buildMenuItem(
                  icon: Icons.info_outline,
                  text: "Disclaimer",
                  onTap: () => _openUrl("https://news.rupeeletter.com/disclaimer"),
                ),
                const Divider(height: 1),
                buildMenuItem(
                  icon: Icons.shield_outlined,
                  text: "Terms & Conditions",
                  onTap: () => _openUrl("https://news.rupeeletter.com/terms-and-conditions"),
                ),
                const Divider(height: 1),
                buildMenuItem(
                  icon: Icons.lock_outline,
                  text: "Privacy Policy",
                  onTap: () => _openUrl("https://news.rupeeletter.com/privacy-policy"),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          /// SETTINGS SECTION
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "SETTINGS",
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8E8F5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        Icons.notifications_outlined,
                        size: 20,
                        color: Colors.grey.shade700,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Notifications",
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              color: Colors.black,
                            ),
                          ),
                          Text(
                            "Push, Email, SMS",
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: notificationsEnabled,
                      onChanged: _toggleNotifications,
                      activeColor: const Color(0xFF00C853),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          /// LOGOUT BUTTON
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            width: double.infinity,
            child: ElevatedButton(
              onPressed: logout,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5252),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.logout, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "Logout",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          /// DELETE ACCOUNT BUTTON
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            width: double.infinity,
            child: ElevatedButton(
              onPressed: showDeleteDialog,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5252),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.delete_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    "Delet Account",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 30),
        ],
      ),
    ),
  );
}


  /// ================== UI HELPERS ==================

  Widget buildTile(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 16)),
        ],
      ),
    );
  }

  Widget buildSection(String title) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget buildMenuItem({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE8E8F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 20, color: Colors.grey.shade700),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.black,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade400),
          ],
        ),
      ),
    );
  }

  Widget buildLink(String text, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        child: Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 15,
            color: Colors.black,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }


}