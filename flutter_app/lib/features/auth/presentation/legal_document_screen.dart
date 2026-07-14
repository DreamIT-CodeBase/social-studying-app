import 'package:flutter/material.dart';

class TermsAndConditionsScreen extends StatelessWidget {
  const TermsAndConditionsScreen({super.key});

  @override
  Widget build(BuildContext context) => const _LegalDocumentScreen(
        title: 'Terms & Conditions',
        sections: [
          _LegalSection(
            heading: 'Acceptance of these terms',
            body:
                'By creating an account or using Social Studying, you agree to these Terms & Conditions. If you use Social Studying on behalf of a school, family, or other organization, you confirm that you have authority to accept these terms for that organization.',
          ),
          _LegalSection(
            heading: 'The service',
            body:
                'Social Studying provides study workspaces, AI-assisted questions and flashcards, progress tools, and educational-content processing. Generated learning content is intended to support study; it is not a substitute for teacher, parent, or professional educational judgment.',
          ),
          _LegalSection(
            heading: 'Accounts and access',
            body:
                'Keep your sign-in method and device access secure. Administrators are responsible for managing their workspaces, invite codes, uploaded materials, and student access. You must provide accurate account information and use the service only for lawful educational purposes.',
          ),
          _LegalSection(
            heading: 'Children and school users',
            body:
                'A parent, guardian, school, or other authorized educational organization must create or authorize an account for a child where required. Administrators are responsible for obtaining any permissions or consents required for the learners they invite or manage.',
          ),
          _LegalSection(
            heading: 'Your content',
            body:
                'You retain responsibility for documents, questions, responses, and other material submitted to Social Studying. Do not upload content that you do not have permission to use, that is unlawful, or that could harm others. We may restrict or remove material that fails safety or policy checks.',
          ),
          _LegalSection(
            heading: 'Acceptable use',
            body:
                'Do not attempt to bypass access controls, interfere with the service, scrape or misuse other users’ data, upload malicious files, or use AI-generated study material to cheat, misrepresent work, or cause harm.',
          ),
          _LegalSection(
            heading: 'Availability and changes',
            body:
                'We may update, maintain, or change features to improve reliability, safety, and learning quality. Services that depend on third-party providers, including sign-in, AI, notifications, or cloud processing, may occasionally be unavailable.',
          ),
          _LegalSection(
            heading: 'Contact and updates',
            body:
                'For questions about these terms or your account, contact your family or school administrator, or use the support contact provided with your account. We may update these terms; continued use after an update means you accept the revised terms.',
          ),
        ],
      );
}

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) => const _LegalDocumentScreen(
        title: 'Privacy Policy',
        sections: [
          _LegalSection(
            heading: 'Information we handle',
            body:
                'Social Studying handles account information such as your name, email address, sign-in identifier, role, and workspace membership. It also handles learning activity, including answers, flashcard ratings, mastery and progress data, XP, badges, and study history.',
          ),
          _LegalSection(
            heading: 'Educational content',
            body:
                'Administrators and authorized users may upload study materials. We process file metadata and extracted text to organize materials, generate topics, create learning content, and support search. Content that is flagged by safety checks may be retained for administrator review and compliance records.',
          ),
          _LegalSection(
            heading: 'How we use information',
            body:
                'We use information to authenticate users, provide workspaces, personalize questions and flashcards, measure progress, maintain streaks and rewards, moderate content, troubleshoot the service, and send requested or enabled notifications.',
          ),
          _LegalSection(
            heading: 'Service providers and storage',
            body:
                'Social Studying uses Microsoft Azure services to operate the app, including identity services, cloud databases, storage, search, AI processing, content safety, caching, and background queues. Push notifications may use Firebase Cloud Messaging and Azure Notification Hubs. These providers process data only to provide the services described here.',
          ),
          _LegalSection(
            heading: 'AI-assisted features',
            body:
                'When AI-assisted learning features are used, relevant study-material excerpts and learning context may be processed to generate or evaluate questions, flashcards, topics, and explanations. Do not include unnecessary sensitive personal information in study materials or free-text responses.',
          ),
          _LegalSection(
            heading: 'Sharing and access',
            body:
                'Information is scoped to your organization or family workspace. Authorized administrators can access information needed to manage their workspaces and learners. We do not sell personal information. We share information with service providers only as needed to operate, secure, and support Social Studying or when required by law.',
          ),
          _LegalSection(
            heading: 'Retention and security',
            body:
                'We use tenant-separated data storage, authenticated access, role-based permissions, encryption provided by our cloud services, and soft-deletion controls. We retain information while it is needed to provide the service, meet legal obligations, resolve disputes, or maintain security and audit records.',
          ),
          _LegalSection(
            heading: 'Your choices',
            body:
                'You can manage notification permissions on your device. To request access, correction, or deletion of account information, contact your family or school administrator, or use the support contact provided with your account. Requests involving a child should be made by the parent, guardian, or authorized school administrator.',
          ),
          _LegalSection(
            heading: 'Policy updates',
            body:
                'We may update this Privacy Policy as the service changes. The current version is effective July 14, 2026. Continued use after an update means you acknowledge the revised policy.',
          ),
        ],
      );
}

class _LegalDocumentScreen extends StatelessWidget {
  const _LegalDocumentScreen({required this.title, required this.sections});

  final String title;
  final List<_LegalSection> sections;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B);
    final secondaryColor = isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569);

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          children: [
            Text('Social Studying', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 8),
            Text('Effective July 14, 2026', style: TextStyle(fontSize: 13, color: secondaryColor)),
            const SizedBox(height: 24),
            for (final section in sections) ...[
              Text(section.heading, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: textColor)),
              const SizedBox(height: 8),
              Text(section.body, style: TextStyle(fontSize: 14, height: 1.55, color: secondaryColor)),
              const SizedBox(height: 24),
            ],
          ],
        ),
      ),
    );
  }
}

class _LegalSection {
  const _LegalSection({required this.heading, required this.body});

  final String heading;
  final String body;
}
