import 'package:flutter/material.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy')),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Privacy Policy',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Effective date: June 2025  ·  Last updated: June 2025',
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 24),

            _SectionTitle('Overview'),
            _SectionBody(
              'Board Box is a local multiplayer board game collection. '
              'We respect your privacy and are committed to protecting it. '
              'Board Box does NOT collect, store, or transmit any personal data.',
            ),

            SizedBox(height: 16),
            _SectionTitle('Data Collection'),
            _SectionBody(
              'Board Box collects no personal information. The only data stored '
              'are game statistics (wins, losses, draws) and app settings '
              '(theme, hints, haptics). This data is saved locally on your '
              'device and is never sent to any server or third party.',
            ),

            SizedBox(height: 16),
            _SectionTitle('Internet Access'),
            _SectionBody(
              'Board Box makes no network requests. The INTERNET permission in '
              'the app manifest is retained for potential future features but '
              'is currently unused — no data is sent over the network.',
            ),

            SizedBox(height: 16),
            _SectionTitle('Advertising'),
            _SectionBody(
              'Board Box contains no advertisements of any kind. No advertising '
              'SDK or ad network is integrated in the app.',
            ),

            SizedBox(height: 16),
            _SectionTitle('Third-Party Services'),
            _SectionBody(
              'Board Box integrates only the Flutter framework and the '
              'shared_preferences plugin for local device storage. No analytics, '
              'crash-reporting, social-login, advertising, or any other '
              'third-party SDK is included.',
            ),

            SizedBox(height: 16),
            _SectionTitle("Children's Privacy (COPPA)"),
            _SectionBody(
              'Board Box is designed to be safe for users of all ages, '
              'including children under 13. We comply with the US Children\'s '
              'Online Privacy Protection Act (COPPA):\n\n'
              '• We do not collect any personal information from any user, '
              'including children under 13.\n'
              '• No account registration or login is required.\n'
              '• No advertisements are shown.\n'
              '• No in-app purchases are present.\n'
              '• No social features, chat, or user-generated content exist.\n'
              '• All content is appropriate for all ages.',
            ),

            SizedBox(height: 16),
            _SectionTitle('GDPR'),
            _SectionBody(
              'Because we collect no personal data, Board Box has no processing '
              'activities that require a legal basis under the EU General Data '
              'Protection Regulation (GDPR). There is no personal data to '
              'access, rectify, erase, or port.',
            ),

            SizedBox(height: 16),
            _SectionTitle('Data Deletion'),
            _SectionBody(
              'Uninstalling Board Box permanently removes all locally stored '
              'app data (game stats and settings) from your device.',
            ),

            SizedBox(height: 16),
            _SectionTitle('Changes to This Policy'),
            _SectionBody(
              'We may update this Privacy Policy from time to time. Any changes '
              'will be reflected in the app and on our website. The full policy '
              'is available at:\n'
              'https://learn-by-exploration.github.io/BoardBox/privacy-policy.html',
            ),

            SizedBox(height: 16),
            _SectionTitle('Contact'),
            _SectionBody(
              'If you have questions about this Privacy Policy, please contact '
              'us via our Google Play Store listing or open an issue on our '
              'GitHub repository.',
            ),

            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
    );
  }
}

class _SectionBody extends StatelessWidget {
  final String text;
  const _SectionBody(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(text, style: const TextStyle(fontSize: 14, height: 1.5)),
    );
  }
}
