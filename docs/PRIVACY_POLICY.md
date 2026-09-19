# PRIVACY POLICY FOR SOCIAL STUDYING

**Effective Date:** August 20, 2026  
**Last Updated:** August 20, 2026  
**Official Website:** [https://socialstudying.ai](https://socialstudying.ai)  
**Privacy Contact:** privacy@socialstudying.ai  

---

## 1. INTRODUCTION AND OVERVIEW

Social Studying ("we", "us", "our", or the "Company") provides an AI-powered, adaptive learning and study platform through mobile applications (Android and iOS) and web services (collectively, the "Service"). The Service enables students, parents, teachers, and school administrators to organize learning materials, generate adaptive practice questions and flashcards, track academic progress, manage study screen time, and collaborate within private educational workspaces.

We are committed to protecting the privacy, safety, and security of all our users, especially children and students. This Privacy Policy explains in detail:
- What personal and educational information we collect;
- How we use, store, and process that information;
- Our strict guarantees regarding Artificial Intelligence (AI) processing and zero public model training;
- Our compliance with the Children's Online Privacy Protection Act (COPPA), the Family Educational Rights and Privacy Act (FERPA), and global privacy laws (including GDPR and CCPA/CPRA);
- How parents, students, and administrators can inspect, export, or permanently delete their data.

By creating an account, accessing, or using the Service, you acknowledge that you have read and understood this Privacy Policy.

---

## 2. APPLICABILITY AND ROLES

This Privacy Policy applies to all users of Social Studying:
1. **Administrators / Teachers / Parents:** Individuals who create or manage organizational, school, or family workspaces and invite learners.
2. **Students / Learners:** Individuals who join a private workspace (via an invite code) or utilize self-directed study to practice questions, review flashcards, and track academic mastery.
3. **Visitors:** Individuals who visit our public websites.

---

## 3. INFORMATION WE COLLECT

We collect only the minimum information necessary to deliver and personalize the educational experience.

### A. Information Provided Directly by Users
* **Account Information:** Full name, email address, password/authentication credentials (managed securely via Microsoft Entra ID or Google OAuth), user role (e.g., Student, Workspace Admin, Tenant Admin), and optional profile avatar.
* **Educational Materials & Study Documents:** Files uploaded by administrators or students, including textbook chapters, syllabi, notes, slide presentations, and homework assignments (in PDF, DOCX, TXT, or image formats captured via device camera or photo picker).
* **Student Responses & Learning Submissions:** Answers submitted to AI-generated multiple-choice and free-text questions, flashcard self-evaluation ratings (e.g., easy, medium, hard), quiz submissions, and notes.
* **Workspace & Invite Information:** Workspace names, invite codes, and organizational affiliation.

### B. Information Generated Automatically Through App Usage
* **Learning Analytics & Mastery Data:** Topic mastery percentages, chapter progress, accuracy rates, question attempt counts, time spent actively studying, and revision schedules.
* **Gamification & Engagement:** Daily login streaks, earned experience points (XP), achievement badges unlocked, and workspace-scoped leaderboard standings.
* **Device & Push Notification Identifiers:** Firebase Cloud Messaging (FCM v1) registration tokens, operating system type (Android / iOS), app version, and timestamp of notification delivery.

### C. Screen Time & Focus Management Data (Android Optional Feature)
To help students build disciplined study habits, our Android application includes an optional parental/guardian-controlled screen time management feature:
* **Foreground Application Category Detection:** Uses the Android `PACKAGE_USAGE_STATS` permission and companion `AccessibilityService` to determine whether the app currently in the foreground belongs to an educational category or a designated distracting/social category (e.g., games or social media).
* **Earned Time Balance:** Tracks the student's earned minutes balance, unlocking entertainment apps only when academic milestones are achieved.
* **STRICT PRIVACY GUARANTEE:** The Screen Time Accessibility Service operates **locally on the device** and **ONLY** reads the active application package name. **It does NOT inspect, read, capture, log, or transmit screen contents, keystrokes, messages, browsing history, photos, passwords, or personal communications.**

---

## 4. HOW WE USE YOUR INFORMATION

We process collected information strictly for educational, operational, and safety purposes:

1. **Adaptive Learning Delivery:** Dynamically generating practice questions, flashcards, answer explanations, and customized review sessions matching the learner's knowledge gaps.
2. **Workspace & Progress Reporting:** Allowing teachers and parents to monitor student progress, identify learning difficulties, and assign study materials within their private workspace.
3. **Safety & Content Moderation:** Automatically scanning uploaded study documents and generated content via Azure AI Content Safety to detect and filter profanity, self-harm, hate speech, violence, or inappropriate content.
4. **Gamification & Motivation:** Awarding badges, XP, and streak milestones to encourage daily study consistency.
5. **Push Notifications:** Sending study reminders, streak alerts, and screen time balance updates (only when notification permissions are granted).
6. **Platform Integrity & Authentication:** Verifying user identities, securing tenant-isolated database access, preventing fraud, and troubleshooting system errors.

We **DO NOT** sell, rent, or lease personal data. We **DO NOT** use personal data for commercial profiling or cross-context behavioral advertising.

---

## 5. ARTIFICIAL INTELLIGENCE (AI) PROCESSING & DATA INTEGRITY

Social Studying uses **Azure OpenAI Service (GPT-4o)** to provide intelligent study assistance. Because we handle student data, we adhere to strict AI privacy standards:

* **Purpose-Limited AI Processing:** AI models are invoked exclusively to extract topic outlines from uploaded documents, generate relevant practice questions and flashcard decks, and semantically evaluate student answer explanations.
* **Zero Model Training Commitment:** Data sent to Azure OpenAI Service (including document text chunks and student answers) is processed in our dedicated, enterprise-isolated cloud environment. **Your data, study materials, and answers are NEVER used by OpenAI, Microsoft, or any third party to train, retrain, fine-tune, or improve public AI models.**
* **Content Safety Filtering:** All inputs and AI outputs pass through automated safety guardrails to ensure age-appropriate, pedagogically sound educational content.

---

## 6. CHILDREN'S PRIVACY & COPPA / FERPA COMPLIANCE

Protecting young learners is a core architectural requirement of our platform.

### A. Children's Online Privacy Protection Act (COPPA)
* **Parental & School Authorization:** For students under the age of 13, accounts must be created, authorized, or invited by a parent, legal guardian, teacher, or authorized educational institution.
* **No Public Profiles or Search:** Student profiles, progress, and rankings are strictly private and accessible only to verified members and administrators of the student's designated workspace.
* **No Behavioral Tracking or Ads:** We never serve advertisements, behavioral trackers, or third-party marketing SDKs to children.
* **Parental Rights:** Parents and legal guardians possess the right to:
  1. Review all personal and educational data collected from their child;
  2. Refuse further data collection or revoke consent;
  3. Direct the permanent deletion of their child's account and history.

### B. Family Educational Rights and Privacy Act (FERPA)
When Social Studying is adopted by schools or educational agencies:
* We act as a "School Official" with legitimate educational interests under 34 CFR § 99.31(a)(1).
* Student educational records remain under the direct control and ownership of the educational institution.
* Student records are used solely to deliver the authorized educational services and are never re-disclosed without institutional authorization.

---

## 7. THIRD-PARTY SERVICE PROVIDERS & DATA PROCESSORS

We work only with enterprise-grade cloud providers bound by strict Data Processing Agreements (DPAs) and confidentiality terms:

| Service Provider | Role / Purpose | Data Transferred | Data Location |
| :--- | :--- | :--- | :--- |
| **Microsoft Azure** | Core Infrastructure: Azure Container Apps (API hosting), Azure Cosmos DB (database), Azure Blob Storage (documents), Azure AI Search (vector retrieval), Azure Redis (caching) | User profiles, learning history, uploaded materials, progress metrics | United States (Central US) |
| **Azure OpenAI Service** | Generative AI question generation & answer grading | Excerpted document text chunks, student answer text | United States (Enterprise Isolated) |
| **Microsoft Entra ID (B2C)** | User identity & authentication management | Email address, name, login credentials, auth tokens | United States |
| **Google Identity Services** | Optional Google OAuth sign-in | Email address, name, Google User ID | United States |
| **Google Firebase (FCM v1)** | Mobile push notification delivery | Device registration tokens | United States |
| **Azure Notification Hubs** | Multi-platform push dispatch orchestration | Device tokens, notification message payload | United States |

---

## 8. DATA SECURITY & MULTI-TENANT ISOLATION

We implement defense-in-depth technical and organizational safeguards:
* **Multi-Tenant Partition Isolation:** Data in Azure Cosmos DB is strictly segregated by organizational Tenant ID. Cross-tenant access is structurally impossible at the database query level.
* **Encryption in Transit:** All client-to-server and inter-service communications enforce TLS 1.3 / HTTPS encryption.
* **Encryption at Rest:** All databases, blob containers, and backups are encrypted using enterprise AES-256 encryption.
* **Role-Based Access Control (RBAC):** Access to administrative tools, learner progress, and content moderation logs is gated by least-privilege role permissions.
* **Vulnerability & Safety Audits:** Ongoing automated testing, code linting, and dependency audits prevent data leakage.

---

## 9. DATA RETENTION AND DESTRUCTION

We retain personal information only for as long as necessary to fulfill the educational purposes described in this policy:
* **Active Accounts:** Data is maintained for the active lifecycle of the student's or administrator's account.
* **Uploaded Documents:** Study materials remain active until deleted by the workspace administrator or upon workspace closure.
* **Revoked Device Tokens:** Inactive or uninstalled push tokens are purged automatically.
* **Deleted Accounts:** When an account deletion is executed, the user record, authentication link, notification tokens, study records, flashcard data, and gamification profiles are permanently deleted across all databases within 30 days.

---

## 10. ACCOUNT AND DATA DELETION (YOUR PRIVACY RIGHTS)

We provide comprehensive, frictionless mechanisms for users to exercise their privacy rights:

### How to Permanently Delete Your Account and Data
1. **In-App Deletion:**
   - Open the Social Studying App $\rightarrow$ Go to **Profile / Settings** $\rightarrow$ Tap **Delete Account** $\rightarrow$ Confirm your request.
   - The deletion process initiates immediately, revoking all active sessions and removing your data.
2. **Web Deletion Portal:**
   - Visit our dedicated external deletion webpage: **[https://socialstudying.ai/delete-account](https://socialstudying.ai/delete-account)**
   - Enter your registered email address and confirm verification to trigger automated backend data removal.
3. **Email Request:**
   - Send an email to **privacy@socialstudying.ai** with the subject line *"Account Deletion Request"*.

### Access, Correction, and Export
You have the right to request a copy of your personal data in a structured, commonly used format (data portability) or request the correction of inaccurate profile information through your workspace administrator or by contacting our privacy team.

---

## 11. REGIONAL PRIVACY DISCLOSURES

### A. European Union (GDPR) and United Kingdom (UK GDPR)
If you reside in the EEA or UK:
* **Legal Bases for Processing:** We process data based on (1) Performance of a Contract (providing the study service), (2) Legitimate Interests (securing and optimizing our educational platform), (3) Compliance with Legal Obligations, and (4) Consent (where required for specific features).
* **Your Rights:** You have the right to access, rectify, erase, restrict processing, object to processing, and exercise data portability. You may also lodge a complaint with your local Data Protection Authority.

### B. California Residents (CCPA / CPRA)
Under the California Consumer Privacy Act as amended by the California Privacy Rights Act:
* **No Sale or Sharing:** We have not sold or shared any personal information for cross-context behavioral advertising in the preceding 12 months.
* **Rights:** California residents have the right to know what personal information is collected, request deletion, request correction, and not be discriminated against for exercising these rights.

---

## 12. INTERNATIONAL DATA TRANSFERS

Social Studying operates its cloud infrastructure in the United States. If you access the Service from outside the United States, your information will be transferred to, stored, and processed in the United States under standard contractual clauses and rigorous enterprise security safeguards.

---

## 13. CHANGES TO THIS PRIVACY POLICY

We may update this Privacy Policy periodically to reflect new features, operational practices, or legal requirements. When changes are published, we will revise the "Last Updated" date at the top of this document. If changes are material, we will provide prominent notice through the application or via email prior to the changes taking effect.

---

## 14. CONTACT US

If you have questions, comments, or concerns regarding this Privacy Policy, our COPPA compliance, or our data practices, please contact our Data Protection and Privacy Team:

* **Email:** [privacy@socialstudying.ai](mailto:privacy@socialstudying.ai)
* **General Support:** [support@socialstudying.ai](mailto:support@socialstudying.ai)
* **Website:** [https://socialstudying.ai](https://socialstudying.ai)
* **Mailing Address:**  
  Social Studying AI — Privacy Compliance  
  Attn: Data Protection Officer  
