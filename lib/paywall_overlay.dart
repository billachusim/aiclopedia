import 'dart:ui';
import 'package:ai_clopedia/screens/credits_screen.dart';
import 'package:ai_clopedia/services/firebase_services.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'models/user_model.dart';

class PaywallOverlay extends StatelessWidget {
  final UserModel user;
  final VoidCallback onUnlock;
  final int cost;

  const PaywallOverlay({
    super.key,
    required this.user,
    required this.onUnlock,
    this.cost = 50,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = GoogleFonts.interTextTheme();
    final db = FirebaseServices();

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
      child: Container(
        color: Colors.black.withAlpha((255 * 0.75).round()),
        child: Center(
          // --- WRAP THE DIALOG CONTENT WITH A MATERIAL WIDGET ---
          child: Material(
            color: Colors.transparent, // Keep the background transparent
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF121212),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.lock,
                        size: 42,
                        color: Colors.white,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        "Continue With AI",
                        style: textTheme.headlineSmall!.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "This conversation just got interesting...\nUnlock the model to learn the rest.",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        "1,241 people are still asking questions",
                        style: TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (user.credits >= cost) {
                              await db.updateUserCredits(user.userId, -cost);
                              onUnlock();
                            } else {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const CreditsScreen()),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            "Unlock AI — $cost Credits",
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const CreditsScreen()),
                          );
                        },
                        child: const Text(
                          "Top up credits",
                          style: TextStyle(color: Colors.white70),
                        ),
                      ),
                      const SizedBox(height: 10),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: const Text(
                          "Leave Quietly",
                          style: TextStyle(color: Colors.white54),
                        ),
                      )
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
