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
              'Last updated: June 2025',
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 24),
            _SectionTitle('Overview'),
            _SectionBody(
              'Board Box is a local multiplayer board game collection. '
              'We respect your privacy and are committed to protecting it.',
            ),
            SizedBox(height: 16),
            _SectionTitle('Data Collection'),
            _SectionBody(
              'Board Box does NOT collect, store, or transmit any personal data. '
              'All game statistics and preferences are stored locally on your device '
              'and are never sent to any server.',
            ),
            SizedBox(height: 16),
            _SectionTitle('Internet Access'),
            _SectionBody(
              'The app requests internet permission solely for potential future '
              'features (e.g., ads or analytics). Currently, no network requests '
              'are made by the app.',
            ),
            SizedBox(height: 16),
            _SectionTitle('Third-Party Services'),
            _SectionBody(
              'Board Box does not integrate any third-party analytics, advertising, '
              'or tracking services.',
            ),
            SizedBox(height: 16),
            _SectionTitle('Children\'s Privacy'),
            _SectionBody(
              'Board Box is suitable for all ages. We do not knowingly collect '
              'any information from children or any other users.',
            ),
            SizedBox(height: 16),
            _SectionTitle('Changes to This Policy'),
            _SectionBody(
              'We may update this Privacy Policy from time to time. Any changes '
              'will be reflected within the app.',
            ),
            SizedBox(height: 16),
            _SectionTitle('Contact'),
            _SectionBody(
              'If you have any questions about this Privacy Policy, please '
              'contact us via the app store listing.',
            ),
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
