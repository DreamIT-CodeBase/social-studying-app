# Social Studying App — Complete iOS QA Test Cases & Execution Guide

> **Document Version:** 1.0.0  
> **Target Platforms:** iOS 16.0 – iOS 18.x (iPhone)  
> **App Flavors:**
> - **Student App:** *Social Studying AI* (`ai.socialstudying.app`)
> - **Admin App:** *Social Studying Admin* (`ai.socialstudying.app.admin`)  
> **Author:** QA Engineering & Mobile Architecture Team  
> **Last Updated:** September 2026

---

## 1. Executive Summary & Testing Scope

This document provides an exhaustive, step-by-step test specification for manual QA testers to validate the **Social Studying App** ecosystem on Apple iPhone devices.

The application is built with a single Flutter codebase producing two distinct native iOS targets via Xcode schemes and bundle identifiers:
1. **Student App (`Social Studying AI`)**: Focuses on student onboarding, Screen Time / FamilyControls app shielding, adaptive question answering, 3D flashcards, revision sessions, gamification (XP, streaks, 15+ badges, leaderboards), mascot animations, and local/remote APNs notifications.
2. **Admin App (`Social Studying Admin`)**: Focuses on tenant/workspace administration, document ingestion (PDF, TXT, native iOS camera capture, and photo library uploads), AI-generated taxonomy management, content moderation review, student progress analytics, and Stripe subscription management.

---

## 2. Test Environment, Hardware & Prerequisites

### 2.1 Recommended Test Devices Matrix
| Device Category | Recommended Model(s) | Screen / Hardware Characteristics | Primary Focus Areas |
|---|---|---|---|
| **Tier 1: Dynamic Island** | iPhone 15 Pro / iPhone 16 / iPhone 14 Pro | 6.1" OLED, Dynamic Island, Face ID, ProMotion 120Hz | Notch/Island clipping, safe area padding, 120Hz animations |
| **Tier 2: Standard Notch** | iPhone 13 / iPhone 14 / iPhone 12 | 6.1" OLED, Classic Sensor Notch, Face ID | Standard viewport, notch collision, keyboard avoidance |
| **Tier 3: Compact / Home Button** | iPhone SE (3rd Gen) | 4.7" LCD, Touch ID, Bottom bezel, Home button | Compact layout, small screen overflow, no Dynamic Island |
| **Tier 4: Large Max / Plus** | iPhone 15 Pro Max / iPhone 16 Plus | 6.7" OLED, Large Dynamic Island | Asset scaling, reachability, tablet/large phone spacing |

### 2.2 Software & OS Requirements
- Minimum OS: **iOS 16.0** (Required for Apple FamilyControls, ManagedSettings, DeviceActivity frameworks)
- Primary OS: **iOS 17.x** and **iOS 18.x**
- Xcode Archive Source: Must be archived from `ios/Runner.xcworkspace` (never `Runner.xcodeproj`).

### 2.3 Prerequisites & Test Accounts
Before commencing testing, the QA tester must ensure the following credentials and devices are prepared:

1. **Apple IDs**:
   - Primary Apple ID with Screen Time Family Sharing configured (Parent account).
   - Secondary Apple ID designated as a Child/Student account (to test FamilyControls / parental permissions).
   - TestFlight account enrolled in internal/external testing groups.
2. **Authentication Accounts**:
   - Microsoft Entra CIAM test user (email + password).
   - Google Account for Google Sign-In.
   - Apple ID for native Sign in with Apple.
   - Pre-seeded Tenant Admin credentials (`admin_test@socialstudy.ai`).
   - Pre-seeded Workspace Student credentials (`student_test@socialstudy.ai`).
3. **Network Configurations**:
   - High-speed Wi-Fi network.
   - Cellular LTE/5G network.
   - Capability to toggle Airplane Mode and simulate low-bandwidth / throttling.
4. **App Groups & Entitlements Verified**:
   - `group.ai.socialstudying.app.screentime`
   - `com.apple.developer.family-controls` enabled on Apple Developer Provisioning Profile.

---

## 3. Test Traceability Matrix

| Suite ID | Suite Name | Target Flavor | Test Case Count | Priority Breakdown |
|---|---|---|---|---|
| **ST-01** | Installation, Flavors & App Lifecycle | Both | 5 Cases | P0: 3, P1: 2 |
| **ST-02** | Authentication, SSO & Account Session | Both | 7 Cases | P0: 5, P1: 2 |
| **ST-03** | iOS Onboarding & System Permission Priming | Student | 6 Cases | P0: 5, P1: 1 |
| **ST-04** | Apple Screen Time, FamilyControls & App Shielding | Student | 10 Cases | P0: 8, P1: 2 |
| **ST-05** | Student Home, Daily Goal & Mascot Interactions | Student | 5 Cases | P0: 2, P1: 3 |
| **ST-06** | Adaptive Learning Engine & Question Experience | Student | 8 Cases | P0: 6, P1: 2 |
| **ST-07** | 3D Flashcards & Spaced Repetition | Student | 5 Cases | P0: 3, P1: 2 |
| **ST-08** | Revision Mode (Bounded Session) | Student | 4 Cases | P1: 3, P2: 1 |
| **ST-09** | Gamification, Badges & Leaderboards | Student | 5 Cases | P1: 4, P2: 1 |
| **ST-10** | Study Documents & In-App Viewer | Student | 3 Cases | P1: 2, P2: 1 |
| **ST-11** | Apple Push Notifications (APNs) & Deep Links | Both | 6 Cases | P0: 4, P1: 2 |
| **ST-12** | Admin App — Workspaces, Roster & Invite Codes | Admin | 5 Cases | P0: 4, P1: 1 |
| **ST-13** | Admin App — Document Ingestion, Camera & Photos | Admin | 6 Cases | P0: 5, P1: 1 |
| **ST-14** | Admin App — AI Taxonomy Viewer & Editor | Admin | 4 Cases | P1: 3, P2: 1 |
| **ST-15** | Admin App — Content Moderation & Workspace Settings | Admin | 4 Cases | P0: 2, P1: 2 |
| **ST-16** | Admin App — Student Progress & Analytics Dashboards | Admin | 4 Cases | P1: 3, P2: 1 |
| **ST-17** | Admin App — Stripe Subscription Paywall & Checkout | Admin | 5 Cases | P0: 3, P1: 2 |
| **ST-18** | iOS Hardware, System UX, Accessibility & Edge Cases | Both | 8 Cases | P0: 3, P1: 5 |
| **TOTAL** | **18 Suites** | | **95 Test Cases** | **P0: 56, P1: 34, P2: 5** |

---

## 4. Detailed Step-by-Step Test Cases

```
Test Case Legend:
- [P0] Critical / Blocker: Core functionality; release cannot proceed if failing.
- [P1] Major: Important feature or edge-case behavior.
- [P2] Minor: Visual polish, non-critical telemetry, or minor UX discrepancy.
```

---

### Suite 01: Installation, Flavors & App Lifecycle (iOS)

#### TC-IOS-INST-01 [P0] Coexistence of Student and Admin Apps on the Same iPhone
- **Objective:** Verify that both the Student App and Admin App can be installed, coexist, and launch independently on the same physical iPhone without bundle ID collisions or shared container corruption.
- **Flavors:** Both
- **Preconditions:** iPhone running iOS 16+. TestFlight builds for both flavors available.
- **Steps:**
  1. Install `Social Studying AI` (`ai.socialstudying.app`) via TestFlight.
  2. Install `Social Studying Admin` (`ai.socialstudying.app.admin`) via TestFlight.
  3. Observe the iPhone Home Screen and App Library.
  4. Launch the Student App; verify splash screen and login landing.
  5. Press Home / swipe up to return to Home Screen.
  6. Launch the Admin App; verify splash screen and admin landing.
- **Expected Results:**
  - Both apps display distinct icons (`AppIcon` for Student, `AdminAppIcon` for Admin).
  - App display names are accurate ("Social Studying AI" vs "Social Studying Admin").
  - Launching one does not terminate or reset the state of the other.
  - Keychain items and local SharedPreferences/UserDefaults stay segregated.

#### TC-IOS-INST-02 [P1] Cold Launch, Splash Screen & LaunchScreen.storyboard Performance
- **Objective:** Verify cold launch performance, absence of white flash, and smooth transition to the first interactive frame.
- **Flavors:** Both
- **Preconditions:** App process killed from iOS App Switcher.
- **Steps:**
  1. Tap the App icon on the iPhone Home Screen.
  2. Measure time from tap until the interactive Login or Home screen is displayed.
  3. Observe visual rendering across light mode and dark mode.
- **Expected Results:**
  - `LaunchScreen.storyboard` renders immediately matching system appearance (no harsh white/black flashes).
  - Transition from native launch screen to Flutter first frame occurs in `< 2.0 seconds` on iPhone 12 or newer.
  - No frame drops or visual jitter during initialization.

#### TC-IOS-INST-03 [P0] Backgrounding, Foregrounding & Lifecycle Recovery
- **Objective:** Verify that the app preserves UI state and resumes seamlessly when switched to background and back.
- **Flavors:** Both
- **Preconditions:** User is on an active screen (e.g., answering question #3 in a session).
- **Steps:**
  1. While in the middle of a study session, swipe up to send app to background.
  2. Open 2-3 other apps (e.g., Safari, Camera, Settings).
  3. Re-open the Social Studying app from the App Switcher.
  4. Repeat step 1, lock the iPhone, wait 30 seconds, and unlock.
- **Expected Results:**
  - App resumes immediately without restarting or crashing.
  - Active question state, timer, and entered inputs are intact.
  - In `didChangeAppLifecycleState`, background token/shield sync executes cleanly.

#### TC-IOS-INST-04 [P1] OS Termination / Memory Pressure Recovery
- **Objective:** Ensure user session and in-flight states are gracefully restored if iOS terminates the app in the background.
- **Flavors:** Both
- **Preconditions:** User logged in.
- **Steps:**
  1. Background the app.
  2. Force-kill the process from the iOS App Switcher (swipe up).
  3. Tap the app icon to perform a cold start.
- **Expected Results:**
  - `SessionPersistenceService` restores the active user authentication state automatically.
  - User is not unexpectedly logged out or prompted for credentials again.
  - Shield enforcement remains active via the App Group ManagedSettings store.

#### TC-IOS-INST-05 [P0] Dynamic Island & Notch Safe Area Compliance
- **Objective:** Verify that no UI content, headers, or buttons are obstructed by the Dynamic Island or Notch on modern iPhones.
- **Flavors:** Both
- **Preconditions:** iPhone 14 Pro / 15 / 16 (Dynamic Island) or iPhone 13/14 (Notch).
- **Steps:**
  1. Navigate through: Login, Student Home, Question Screen, Flashcard Screen, Admin Dashboard, Document Upload.
  2. Inspect top AppBar, close buttons, progress bars, and bottom navigation bars.
  3. Rotate device to landscape if orientation is supported, then back to portrait.
- **Expected Results:**
  - All AppBars, status indicators, and close icons are fully positioned below the Dynamic Island / Notch (`SafeArea` top inset respected).
  - Bottom navigation bar and action buttons sit comfortably above the iOS Home Indicator bar.
  - No text or tappable icons collide with the physical screen boundaries.

---

### Suite 02: Authentication, CIAM, Social Login & Parent/Child Access

#### TC-IOS-AUTH-01 [P0] Native Microsoft Entra (CIAM) Email & Password Sign-In
- **Objective:** Validate authentication using Microsoft Entra External ID via native iOS URL scheme callback.
- **Flavors:** Both
- **Preconditions:** Valid registered test user credentials in Entra CIAM tenant.
- **Steps:**
  1. Launch app, tap "Sign In with Email / Microsoft".
  2. Observe the native `ASWebAuthenticationSession` / browser modal presenting the Entra login page.
  3. Enter valid email and password; tap "Sign In".
  4. Observe prompt: *"Social Studying wants to use 'ciamlogin.com' to Sign In"*; tap **Continue**.
  5. Verify redirect handling via `msauth.$(PRODUCT_BUNDLE_IDENTIFIER)://auth`.
- **Expected Results:**
  - URL redirect is caught by `AppDelegate.swift` `application(_:open:options:)` and passed to `NativeEntraAuthCoordinator`.
  - JWT token is returned, parsed, and stored in secure iOS Keychain storage.
  - User transitions directly to Student Home or Admin Dashboard within `< 2.5 seconds`.

#### TC-IOS-AUTH-02 [P0] Google Sign-In via iOS Custom URL Scheme
- **Objective:** Verify Google Sign-In OAuth flow using Safari / `GIDClientID`.
- **Flavors:** Both
- **Preconditions:** Google Client ID configured in `Info.plist` and Google Cloud Console.
- **Steps:**
  1. On login screen, tap "Continue with Google".
  2. Observe system authorization dialog; tap **Continue**.
  3. Select or enter Google account credentials.
  4. Complete 2-Step Verification if prompted.
  5. Confirm redirect back to the app.
- **Expected Results:**
  - Browser opens smoothly and redirects back via `com.googleusercontent.apps.*` scheme.
  - Google ID token is validated against backend `/auth/register-completion` or session handler.
  - User profile avatar and display name populate accurately.

#### TC-IOS-AUTH-03 [P0] Sign in with Apple (Mandatory for iOS App Store)
- **Objective:** Verify Sign in with Apple using native iOS Face ID / Touch ID authentication.
- **Flavors:** Both
- **Preconditions:** Apple ID logged into iPhone Settings.
- **Steps:**
  1. On the login screen, tap the official black "Sign in with Apple" button.
  2. Observe the native iOS Apple Sign-In bottom sheet.
  3. Select either "Share My Email" or "Hide My Email" (relay service).
  4. Authenticate using Face ID / Touch ID / Device Passcode.
- **Expected Results:**
  - Native sheet completes instantly upon Face ID confirmation.
  - Identity token is transmitted to backend; user session is created.
  - User is routed to Onboarding (if first time) or Home Dashboard.

#### TC-IOS-AUTH-04 [P1] Authentication Error Handling & Network Failure
- **Objective:** Verify appropriate user feedback when authentication fails or connection drops.
- **Flavors:** Both
- **Preconditions:** Device on Airplane Mode OR using invalid credentials.
- **Steps:**
  1. Enter invalid email or password; tap Sign In.
  2. Observe error alert.
  3. Enable Airplane Mode in iOS Control Center.
  4. Tap "Sign In with Google" or "Sign in with Apple".
- **Expected Results:**
  - Clear, user-friendly error message is displayed (e.g., "Invalid credentials", "No internet connection").
  - App does not freeze, crash, or remain in an indefinite loading spinner state.
  - Retry button is interactive and responsive.

#### TC-IOS-AUTH-05 [P0] Token Refresh & Long-Lived Session Persistence
- **Objective:** Validate that expired access tokens refresh automatically via refresh token without logging the user out.
- **Flavors:** Both
- **Preconditions:** User logged in. Access token expires after 75 minutes.
- **Steps:**
  1. Log in to the app.
  2. Advance device time by 2 hours in iPhone Settings > General > Date & Time (or wait for token expiry).
  3. Trigger an API call (e.g., pull to refresh on Home screen or tap Start Study Session).
  4. Inspect network request.
- **Expected Results:**
  - Dio HTTP interceptor intercepts 401 response, executes token refresh transparently.
  - Subsequent request succeeds with the new bearer token.
  - User experiences zero interruption or unexpected logout.

#### TC-IOS-AUTH-06 [P0] Sign Out Flow & Local State Teardown
- **Objective:** Verify complete session teardown and token de-registration upon sign out.
- **Flavors:** Both
- **Preconditions:** User authenticated with active APNs push token registered.
- **Steps:**
  1. Navigate to Profile / Settings.
  2. Tap "Sign Out". Confirm the sign-out confirmation modal.
  3. Observe network call to deregister notification token.
  4. Check destination route.
  5. Attempt to use iOS swipe-back gesture to navigate to the previous screen.
- **Expected Results:**
  - Notification token is revoked on backend (`/users/me/notification-tokens`).
  - Auth token, cached knowledge state, and user details are wiped from memory and Keychain.
  - User lands on `/login`. Swipe-back gesture does nothing (auth guards block unauthenticated routes).

#### TC-IOS-AUTH-07 [P1] Student Enrollment via 6-Character Workspace Invite Code
- **Objective:** Verify school student onboarding flow using an admin-issued 6-character code.
- **Flavors:** Student
- **Preconditions:** Valid workspace code generated by an admin (e.g., `BIO101`).
- **Steps:**
  1. Sign up as a new student user.
  2. On the workspace join screen, enter an invalid 6-character code `ZZZZZZ`. Tap **Join**.
  3. Observe validation feedback.
  4. Enter the valid workspace code `BIO101`. Tap **Join**.
- **Expected Results:**
  - Invalid code shows red error banner: *"Invalid or expired invite code"*.
  - Valid code joins the student to the workspace and routes to Student Home.
  - Workspace title matches the admin's workspace name.

---

### Suite 03: iOS Onboarding & System Permission Priming

#### TC-IOS-ONBD-01 [P0] Student First-Launch Onboarding Carousel
- **Objective:** Verify the educational onboarding slides and feature walkthrough.
- **Flavors:** Student
- **Preconditions:** Fresh install or cleared app data.
- **Steps:**
  1. Launch app as a new user.
  2. Swipe horizontally through the 3 onboarding carousel slides.
  3. Tap the "Next" button on each slide.
  4. Tap "Get Started" on the final slide.
- **Expected Results:**
  - Smooth page transitions with page indicator dots updating.
  - Graphics, typography, and text are crisp on Retina display.
  - Reaching the end navigates to `PermissionOnboardingScreen`.

#### TC-IOS-ONBD-02 [P0] Push Notifications Native iOS Permission Dialog
- **Objective:** Verify the native iOS push notification authorization request.
- **Flavors:** Student
- **Preconditions:** Reaching the notification permission step in onboarding.
- **Steps:**
  1. On the permission onboarding screen, observe the Notification card.
  2. Tap "Enable Notifications" / "Continue".
  3. Observe the native iOS system dialog: *"Social Studying AI Would Like to Send You Notifications"*.
  4. Tap **Allow**.
- **Expected Results:**
  - Dialog presents standard Apple options: *Allow*, *Don't Allow*.
  - Tapping **Allow** transitions permission status to `granted` (green checkmark).
  - APNs device token is fetched from `UIApplication.shared.registerForRemoteNotifications()`.

#### TC-IOS-ONBD-03 [P0] Screen Time / FamilyControls Native Authorization (Face ID)
- **Objective:** Verify requesting Apple FamilyControls authorization via `AuthorizationCenter.shared.requestAuthorization(for: .individual)`.
- **Flavors:** Student
- **Preconditions:** Notification permission step completed. Device has Face ID / Passcode enabled.
- **Steps:**
  1. On the permission setup screen, observe the Screen Time card.
  2. Tap "Authorize Screen Time".
  3. Observe native Apple FamilyControls prompt: *"Social Studying AI Wants to Manage Screen Time"*.
  4. Authenticate using Face ID or enter the device Passcode.
- **Expected Results:**
  - Native iOS Face ID scanner appears and completes authentication.
  - `ScreenTimeManager.shared.isAuthorized()` returns `true` (`status == .approved`).
  - The UI updates to show the Screen Time permission as complete (green checkmark).
  - App advances to the blocked apps selection step.

#### TC-IOS-ONBD-04 [P1] Handling "Don't Allow" / Permission Denied Recovery
- **Objective:** Verify graceful recovery and deep link to iOS Settings when a user denies permissions.
- **Flavors:** Student
- **Preconditions:** User taps "Don't Allow" on either Notification or Screen Time prompts.
- **Steps:**
  1. Tap "Don't Allow" on the Screen Time or Notification system prompt.
  2. Observe the onboarding UI feedback.
  3. Tap the "Open iOS Settings" button.
- **Expected Results:**
  - App displays an informative banner: *"Permission is required to lock apps during study hours"*.
  - Tapping "Open iOS Settings" launches the native iOS Settings app directly to the app's permission page.
  - Upon toggling permission in Settings and returning to the app, app detects change and updates status automatically.

#### TC-IOS-ONBD-05 [P0] FamilyActivityPicker Presentation & App Selection
- **Objective:** Verify presenting the native Apple `FamilyActivityPicker` SwiftUI sheet to pick apps to block.
- **Flavors:** Student
- **Preconditions:** Screen Time authorization approved.
- **Steps:**
  1. On the app setup screen, tap "Select Apps to Block".
  2. Observe the native iOS `FamilyActivityPicker` modal sheet slide up from bottom.
  3. Expand categories (e.g., Social, Games, Entertainment).
  4. Select sample apps: Instagram, YouTube, TikTok.
  5. Tap **Done** in the top-right corner of the picker.
- **Expected Results:**
  - Native Apple app picker lists all installed apps and categories.
  - Tapping **Done** dismisses sheet and saves selection to `AppGroup` storage via `ScreenTimeManager.selectionStorageKey`.
  - The onboarding screen displays: *"3 apps selected for protection"*.
  - "Continue" button activates.

#### TC-IOS-ONBD-06 [P1] Theme Selection (Light, Dark, System Match)
- **Objective:** Verify theme selection screen and immediate visual adaptation.
- **Flavors:** Student
- **Preconditions:** Reaching the theme selection step (`/theme-selection`).
- **Steps:**
  1. Select **Light Mode**; verify background, cards, and text change to light palette.
  2. Select **Dark Mode**; verify deep slate/midnight dark theme activates.
  3. Select **Match System**; open iOS Control Center, toggle system Dark Mode on and off.
  4. Tap **Finish Setup**.
- **Expected Results:**
  - UI updates instantly with smooth color transitions.
  - Selecting "Match System" tracks iOS Control Center appearance changes in real time.
  - Tapping Finish Setup sets `isPermissionSetupCompleteSync(userId) = true` and navigates to `/student/home`.

---

### Suite 04: Apple Screen Time, FamilyControls & App Shielding (Core iOS Feature)

#### TC-IOS-SCRN-01 [P0] Immediate Shield Activation When Available Time = 0
- **Objective:** Verify that native shields are applied to selected apps when the student's Screen Time wallet is 0 minutes.
- **Flavors:** Student
- **Preconditions:** Student has selected blocked apps (e.g., Instagram/YouTube). Available minutes = 0.
- **Steps:**
  1. Ensure Screen Time blocking is enabled in settings.
  2. Check wallet balance shows `0m Available`.
  3. Return to iPhone Home Screen.
  4. Tap the blocked app icon (e.g., Instagram).
- **Expected Results:**
  - Blocked app does not open its main interface.
  - Native Apple Shield overlay (`ShieldConfigurationExtension`) appears over the app window.
  - Custom UI is displayed:
    - Background: System Material Dark (`#0F172A`)
    - Title: *"Study Session Needed"*
    - Subtitle: *"To gain access to your app, let’s create a study session."*
    - Primary Button: *"Close"* (Blue button `#2563EB`)
  - Tapping *"Close"* dismisses the app to the Home Screen.

#### TC-IOS-SCRN-02 [P0] Earning Screen Time via Studying & Instant Shield Removal
- **Objective:** Verify that answering questions or completing a study session credits minutes and immediately lifts shields.
- **Flavors:** Student
- **Preconditions:** Shields currently active (0 minutes available).
- **Steps:**
  1. Open `Social Studying AI`.
  2. Start an adaptive study session.
  3. Answer 5 questions correctly (earning +15 minutes of screen time).
  4. Observe the session completion modal: *"Earned 15 min of Screen Time!"*.
  5. Check `ScreenTimeManager.shared.syncScreenTimeBalance(availableMinutes: 15, enableBlocking: true)`.
  6. Return to iPhone Home screen and tap the previously blocked app (e.g., Instagram).
- **Expected Results:**
  - Wallet balance increments from `0m` to `15m`.
  - Native shields are revoked from `ManagedSettingsStore`.
  - Blocked app launches immediately without any shield overlay.

#### TC-IOS-SCRN-03 [P0] Screen Time Countdown & Background Consumption
- **Objective:** Verify that using unshielded apps decrements available minutes accurately over time.
- **Flavors:** Student
- **Preconditions:** Available minutes = 5. Blocked apps currently unshielded.
- **Steps:**
  1. Open and use Instagram or YouTube actively for 5 minutes.
  2. Monitor DeviceActivity / ScreenTime countdown tracking.
  3. Observe behavior when the 5 minutes expire.
- **Expected Results:**
  - After 5 minutes, available time reaches 0.
  - `DeviceActivityEvent.Name.socialTimeExhausted` triggers.
  - Shields are immediately reapplied to all selected apps.
  - Attempting to continue using the app brings up the "Study Session Needed" shield.

#### TC-IOS-SCRN-04 [P0] Time Exhausted Push Notification with "Study Now ➔" Action
- **Objective:** Verify local notification alert when screen time runs out and action button routing.
- **Flavors:** Student
- **Preconditions:** Available minutes reach 0 while user is outside the study app.
- **Steps:**
  1. Allow available minutes to reach 0 while in another app.
  2. Observe the top banner notification drop down.
  3. Inspect notification content:
     - Title: *"Study Session Needed"*
     - Body: *"Your social screen time has expired. Complete a study session to unlock more time!"*
     - Action Button: *"Study Now ➔"*
  4. Tap the *"Study Now ➔"* action button.
- **Expected Results:**
  - Notification banner appears with sound and haptic vibration.
  - Tapping *"Study Now ➔"* launches `Social Studying AI` directly into an adaptive study session (`unlock_question` route).
  - First question is presented immediately without extra navigation clicks.

#### TC-IOS-SCRN-05 [P1] Suppressing Exhausted Notification When App is Already Active
- **Objective:** Verify that time-exhausted banners do NOT annoyingly drop down if the student is currently inside the study app.
- **Flavors:** Student
- **Preconditions:** Student is inside the Social Studying app.
- **Steps:**
  1. Manually trigger a time-exhausted event while the student is actively on the Home screen or answering a question.
  2. Observe `AppDelegate.swift` `userNotificationCenter(_:willPresent:withCompletionHandler:)`.
- **Expected Results:**
  - The notification banner is suppressed (`completionHandler([])`).
  - No disruptive top banner appears while the user is already studying.

#### TC-IOS-SCRN-06 [P0] Re-Applying Shields on App Foreground (`applicationDidBecomeActive`)
- **Objective:** Verify that shields are re-verified and enforced every time the app comes to the foreground.
- **Flavors:** Student
- **Preconditions:** Available minutes = 0.
- **Steps:**
  1. Lock the iPhone.
  2. Unlock the iPhone and tap the Social Studying app.
  3. Inspect console logs / debugger for `ScreenTimeManager.shared.reapplyShields()`.
- **Expected Results:**
  - `reapplyShields()` executes synchronously without blocking the UI thread.
  - Shields are re-committed to `ManagedSettingsStore(named: "ai.socialstudying.screentime")`.

#### TC-IOS-SCRN-07 [P0] Persistence Across iPhone Reboot & App Kill
- **Objective:** Verify that app shielding survives a complete device reboot and app kill.
- **Flavors:** Student
- **Preconditions:** Shields active on social apps. Available minutes = 0.
- **Steps:**
  1. Verify shields are active on Instagram.
  2. Force-restart the iPhone (Volume Up, Volume Down, hold Power until Apple logo appears).
  3. After phone boots, do NOT open the Social Studying app.
  4. Immediately tap the Instagram icon on the Home Screen.
- **Expected Results:**
  - Native shields remain active immediately after reboot.
  - Instagram is shielded by `ShieldConfigurationExtension`.
  - Shielding does NOT rely on the Flutter engine running in the background.

#### TC-IOS-SCRN-08 [P1] Updating Blocked Apps in Screen Time Settings Screen
- **Objective:** Verify that adding or removing apps in Screen Time Settings takes effect instantly.
- **Flavors:** Student
- **Preconditions:** Student has Instagram selected.
- **Steps:**
  1. Open Social Studying app > Screen Time Settings (`/student/screen-time-settings`).
  2. Tap "Edit Blocked Apps".
  3. In `FamilyActivityPicker`, add "TikTok" and uncheck "Instagram".
  4. Tap **Done**.
  5. Check both apps on the iPhone Home Screen.
- **Expected Results:**
  - TikTok is now shielded if minutes = 0.
  - Instagram is immediately accessible and unshielded.
  - Changes persist across sessions.

#### TC-IOS-SCRN-09 [P1] Daily Midnight Balance Reset & Daily Limit Cap
- **Objective:** Verify that daily consumed minutes reset at midnight (00:00 local time).
- **Flavors:** Student
- **Preconditions:** Student consumed 45 minutes today.
- **Steps:**
  1. Verify consumed today shows `45 min`.
  2. In iPhone Settings, change time to `11:59 PM` and wait 1 minute (or wait for real midnight).
  3. Re-open the app at `12:01 AM`.
- **Expected Results:**
  - `getConsumedToday()` resets to `0 min`.
  - Daily goal ring resets to 0% for the new calendar day.
  - Streak counter advances or retains status based on yesterday's completion.

#### TC-IOS-SCRN-10 [P0] Web Domain Shielding (Safari URL Blocking)
- **Objective:** Verify that web domains selected in FamilyActivityPicker are shielded in Safari.
- **Flavors:** Student
- **Preconditions:** A web domain (e.g., `tiktok.com` or `reddit.com`) selected in the picker. Available minutes = 0.
- **Steps:**
  1. Open Safari on the iPhone.
  2. Navigate to `https://www.tiktok.com`.
- **Expected Results:**
  - Safari does not load the website content.
  - Custom WebDomain shield overlay is rendered by `ShieldConfigurationExtension`:
    - Icon: Globe icon (`systemName: "globe"`)
    - Title: *"Study Session Needed"*
    - Subtitle: *"To gain access to your website, let’s create a study session."*
    - Primary button: *"Close"*

---

### Suite 05: Student Home, Daily Goal & Mascot Interactions

#### TC-IOS-HOME-01 [P0] Home Screen Initial Load, Header & Wallet Card
- **Objective:** Verify visual rendering of student profile, daily goal ring, streak counter, and screen time wallet.
- **Flavors:** Student
- **Preconditions:** Student logged in with active workspace.
- **Steps:**
  1. Launch app to Student Home.
  2. Inspect the top header: student greeting, grade level badge, streak flame counter.
  3. Inspect the Screen Time Wallet card: available minutes, shield status ("Protected"), "Earn Time" CTA.
  4. Inspect the Daily Goal circular progress indicator.
- **Expected Results:**
  - All metrics render matching backend data.
  - Streak flame has subtle shimmer or glow animation.
  - Card layouts adjust cleanly without text truncation on iPhone SE or iPhone 15 Pro.

#### TC-IOS-HOME-02 [P1] Mascot Emotional States & Interactive Taps
- **Objective:** Verify mascot animations, mood changes based on streak/goal, and touch reaction.
- **Flavors:** Student
- **Preconditions:** Student on Home screen.
- **Steps:**
  1. Tap on the study mascot character.
  2. Observe animation and speech bubble.
  3. Complete a study goal; observe mascot mood changing to celebratory.
  4. Let streak lapse; observe mascot looking encouraged / inviting.
- **Expected Results:**
  - Mascot displays bounce/nod animation upon tap with a gentle Taptic feedback (`HapticFeedback.lightImpact()`).
  - Speech bubble displays motivational study advice.
  - No sprite clipping or stuttering during animation.

#### TC-IOS-HOME-03 [P0] Recommended Topics & Quick Start Buttons
- **Objective:** Verify adaptive topic recommendations based on current knowledge state.
- **Flavors:** Student
- **Preconditions:** Workspace has multiple topics with varying mastery scores.
- **Steps:**
  1. Inspect the "Recommended For You" carousel on the Home screen.
  2. Tap on the highest priority topic card.
  3. Verify route destination.
- **Expected Results:**
  - Cards show Topic Title, Mastery percentage bar, and Difficulty badge.
  - Lowest mastery / high-priority topics appear first.
  - Tapping card opens the study session directly seeded with that topic.

#### TC-IOS-HOME-04 [P1] Pull-to-Refresh Gesture & Physics on iOS
- **Objective:** Verify native Cupertino / iOS scroll physics and pull-to-refresh behavior.
- **Flavors:** Student
- **Preconditions:** Student on Home screen.
- **Steps:**
  1. Drag down from top of Home screen and hold.
  2. Observe native iOS activity indicator spinner.
  3. Release gesture.
- **Expected Results:**
  - Overscroll bounce follows native iOS rubber-banding physics.
  - Spinner animates smoothly and triggers API re-fetch (`refreshWallet()`, progress, streak).
  - Screen snaps back smoothly when data refresh completes.

#### TC-IOS-HOME-05 [P1] Navigation Bar Switching & Bottom Bar Safe Area
- **Objective:** Verify bottom tab bar navigation between Home, Revision, Flashcards, and Profile.
- **Flavors:** Student
- **Preconditions:** Student logged in.
- **Steps:**
  1. Tap **Revision** tab; verify instant tab switch.
  2. Tap **Flashcards** tab; verify deck list.
  3. Tap **Profile** tab; verify user details.
  4. Tap **Home** tab to return.
- **Expected Results:**
  - Tab transitions are instant and preserve scroll position where expected.
  - Bottom navigation bar sits above the iPhone home indicator with proper background blurring/color.

---

### Suite 06: Adaptive Learning Engine & Question Experience

#### TC-IOS-QSTN-01 [P0] Starting an Adaptive Study Session (<3s Latency)
- **Objective:** Verify starting a study session, question prefetching, and render latency.
- **Flavors:** Student
- **Preconditions:** Student on Home or topic card. Tap "Start Session".
- **Steps:**
  1. Tap "Start Session" button.
  2. Time the duration until question #1 is fully interactive.
  3. Inspect question header: Topic Tag, Difficulty Chip (Easy/Medium/Hard), Question Number, XP reward badge.
- **Expected Results:**
  - Question renders in `< 3.0 seconds` via precomputed/prefetched queue.
  - Skeleton loading shimmer displays while awaiting AI response.
  - Question text is clean, formatted, and readable without layout shifts.

#### TC-IOS-QSTN-02 [P0] Multiple Choice Question (MCQ) Answering Flow
- **Objective:** Verify selecting an option, submit action, and visual state feedback.
- **Flavors:** Student
- **Preconditions:** MCQ question displayed with 4 distinct options.
- **Steps:**
  1. Tap Option A; verify option card highlights with a selection ring.
  2. Tap Option B; verify selection moves to Option B.
  3. Tap the "Submit Answer" button at the bottom.
- **Expected Results:**
  - Single selection enforced (cannot select multiple options).
  - Tapping Submit disables further option tapping to prevent race conditions.
  - Button shows a brief loading state while evaluating.

#### TC-IOS-QSTN-03 [P0] Correct Answer Feedback, Confetti & Haptic Feedback
- **Objective:** Verify celebratory visual feedback, sound/haptics, and XP increment on correct answer.
- **Flavors:** Student
- **Preconditions:** User submits the correct answer.
- **Steps:**
  1. Select the known correct option and submit.
  2. Observe screen feedback:
     - Selected option turns Green (`#10B981`) with a checkmark icon.
     - Confetti particle explosion (`_ConfettiLayer`) renders.
     - iPhone vibrates with success haptic pattern (`HapticFeedback.mediumImpact()`).
     - Feedback card displays: *"Awesome Job! +25 XP"* and explanation.
     - Screen time shield badge shows `+3 min unlocked`.
  3. Tap "Next Question".
- **Expected Results:**
  - Confetti layer renders at 60/120 FPS without dropped frames.
  - Taptic Engine provides crisp physical feedback.
  - Tapping "Next Question" loads question #2 instantly (prefetched in background).

#### TC-IOS-QSTN-04 [P0] Incorrect Answer Feedback, Hint & Knowledge Recovery
- **Objective:** Verify educational feedback, mild haptic, and explanation on wrong answer.
- **Flavors:** Student
- **Preconditions:** User submits an incorrect option.
- **Steps:**
  1. Select an incorrect option and submit.
  2. Observe screen feedback:
     - Selected option turns Red (`#EF4444`) with an 'X' icon.
     - Correct option is highlighted in Green outline.
     - iPhone triggers error haptic (`HapticFeedback.lightImpact()`).
     - Feedback card provides detailed explanation of why the answer was incorrect and tips for review.
  3. Tap "Next Question".
- **Expected Results:**
  - Tone is constructive and encouraging.
  - Knowledge state updates synchronously to schedule topic for spaced repetition review.
  - Next question advances cleanly.

#### TC-IOS-QSTN-05 [P1] Mathematical Notation & LaTeX Rendering
- **Objective:** Verify proper rendering of mathematical formulas, superscripts, subscripts, and equations.
- **Flavors:** Student
- **Preconditions:** Math/Science topic question loaded containing LaTeX (e.g., $E = mc^2$, $\frac{-b \pm \sqrt{b^2-4ac}}{2a}$).
- **Steps:**
  1. Navigate to a question with mathematical equations.
  2. Inspect equation alignment, font clarity, and symbol scaling.
- **Expected Results:**
  - Equations render clearly via LaTeX parser without raw syntax code leakage (no raw `\frac` strings visible).
  - Formulas do not wrap awkwardly or clip at the right margin.

#### TC-IOS-QSTN-06 [P0] Text Answer Input & iOS Virtual Keyboard Avoidance
- **Objective:** Verify text input questions with the iOS virtual keyboard, Done accessory, and scrolling.
- **Flavors:** Student
- **Preconditions:** Open-ended / short text answer question displayed.
- **Steps:**
  1. Tap inside the text answer input box.
  2. Observe the native iOS virtual keyboard slide up.
  3. Type a sample answer: *"Photosynthesis occurs in the chloroplasts"*.
  4. Tap the "Done" keyboard accessory button or tap outside to dismiss keyboard.
  5. Tap "Submit Answer".
- **Expected Results:**
  - Input field auto-scrolls above the keyboard; nothing is obscured.
  - Cursor is responsive with native iOS text selection magnifiers working.
  - Dismissing keyboard returns viewport smoothly to original dimensions.

#### TC-IOS-QSTN-07 [P1] Session Early Exit Confirmation Modal
- **Objective:** Verify behavior when user attempts to exit a session prematurely.
- **Flavors:** Student
- **Preconditions:** In the middle of an active session (question 3 of 10).
- **Steps:**
  1. Tap the top-left "X" close button OR perform an iOS interactive swipe-from-left-edge gesture.
  2. Observe the exit confirmation dialog.
  3. Tap "Cancel / Keep Studying"; verify session continues.
  4. Tap "X" again, then tap "Exit Session".
- **Expected Results:**
  - Modal warns: *"Are you sure? Your earned XP will be saved, but your session streak bonus requires completion."*
  - Tapping "Keep Studying" returns with zero state loss.
  - Tapping "Exit Session" saves current progress and navigates back to Home.

#### TC-IOS-QSTN-08 [P0] Study Session Completion Summary & Reward Sync
- **Objective:** Verify session summary screen, total XP calculation, accuracy percentage, and wallet deposit.
- **Flavors:** Student
- **Preconditions:** Completing question 10 of 10 in a session.
- **Steps:**
  1. Answer the final question.
  2. Observe transition to `_StudyCompleteView`.
  3. Inspect summary metrics:
     - Questions Answered (e.g., 10/10)
     - Accuracy (e.g., 90%)
     - Total XP Earned (e.g., +250 XP)
     - Screen Time Earned (e.g., +15 mins)
  4. Tap "Return to Home".
- **Expected Results:**
  - Summary screen displays celebratory mascot animation and XP breakdown.
  - Home screen reflects updated XP, updated Daily Goal ring, and incremented Screen Time wallet.

---

### Suite 07: 3D Flashcards & Spaced Repetition

#### TC-IOS-FLSH-01 [P0] Flashcard Deck Selection & Card Loading
- **Objective:** Verify loading flashcard deck and displaying front of first card.
- **Flavors:** Student
- **Preconditions:** Workspace with uploaded documents and generated flashcards.
- **Steps:**
  1. Navigate to Flashcards tab.
  2. Tap on a topic deck (e.g., "Cell Biology").
  3. Observe card loading.
- **Expected Results:**
  - Card 1 appears centered with topic tag, difficulty pill, and front prompt text.
  - Deck counter shows e.g. "Card 1 of 15".
  - Hint text reads: *"Tap card to flip"*.

#### TC-IOS-FLSH-02 [P0] 3D Card Flip Gesture & Animation
- **Objective:** Verify 3D card flip animation along the Y-axis.
- **Flavors:** Student
- **Preconditions:** Flashcard front visible.
- **Steps:**
  1. Tap anywhere on the flashcard body.
  2. Observe the 3D flip animation.
  3. Inspect back of card: definition, explanation, key concepts.
  4. Tap the card again to flip back to front.
- **Expected Results:**
  - Card flips smoothly 180 degrees with realistic 3D perspective transform (`Matrix4.rotationY`).
  - Text does not appear mirrored or backwards during or after flip.
  - Haptic tick confirms flip (`HapticFeedback.selectionClick()`).

#### TC-IOS-FLSH-03 [P0] Self-Rating Recall (Easy, Medium, Hard)
- **Objective:** Verify self-assessment recall rating and submission.
- **Flavors:** Student
- **Preconditions:** Card flipped to the back.
- **Steps:**
  1. With back of card visible, inspect the three bottom rating buttons:
     - **Hard** (Red outline, revisit soon)
     - **Medium** (Orange outline, standard interval)
     - **Easy** (Green outline, long interval)
  2. Tap "Easy".
- **Expected Results:**
  - Rating submits via `POST /flashcards/{fcId}/rate`.
  - Card slides off-screen to the left or right with smooth swipe animation.
  - Card 2 slides into view.

#### TC-IOS-FLSH-04 [P1] Swipe Gestures on Flashcards
- **Objective:** Verify horizontal drag/swipe gestures to navigate or rate cards.
- **Flavors:** Student
- **Preconditions:** Flashcard deck active.
- **Steps:**
  1. Drag card horizontally to the right; observe tilt angle and green tint overlay ("Mastered").
  2. Release to confirm swipe right.
  3. On next card, drag horizontally to the left; observe red tint overlay ("Review").
  4. Release to confirm swipe left.
- **Expected Results:**
  - Card tracks finger movement accurately with realistic drag resistance.
  - Swiping right records positive recall; swiping left records negative recall.

#### TC-IOS-FLSH-05 [P1] End of Deck Recap & Mastery Recalculation
- **Objective:** Verify deck completion summary and spaced repetition scheduling.
- **Flavors:** Student
- **Preconditions:** Last card rated in deck.
- **Steps:**
  1. Rate the 15th of 15 cards.
  2. Observe deck completion screen.
  3. Inspect summary: Cards Mastered vs Cards to Review, XP earned.
  4. Tap "Practice Weak Cards" or "Finish Deck".
- **Expected Results:**
  - Summary accurately counts cards marked Hard vs Easy.
  - Topic mastery score updates in knowledge state.
  - Tapping "Finish Deck" returns to deck selector.

---

### Suite 08: Revision Mode (Bounded Session)

#### TC-IOS-REVN-01 [P1] Launching Bounded Revision Session
- **Objective:** Verify starting revision mode combining mixed questions and flashcards.
- **Flavors:** Student
- **Preconditions:** Topics with sub-80% mastery exist in workspace.
- **Steps:**
  1. Tap the "Revision" tab or Home banner "Quick Revision".
  2. Select session size (e.g., 10 items / 5 mins).
  3. Tap "Begin Revision".
- **Expected Results:**
  - Session initializes with weak topics prioritized.
  - Top header displays a segmented progress bar indicating item count and type (question icon vs card icon).

#### TC-IOS-REVN-02 [P1] Seamless Interleaving of Questions & Flashcards
- **Objective:** Verify smooth transition between an MCQ question and a flashcard within the same session.
- **Flavors:** Student
- **Preconditions:** Revision session running.
- **Steps:**
  1. Complete question #1 (MCQ).
  2. Tap Next; observe item #2 (Flashcard).
  3. Flip and rate flashcard #2.
  4. Tap Next; observe item #3 (True/False question).
- **Expected Results:**
  - View transitions cleanly between question layout and flashcard layout without UI jumping.
  - Single consolidated progress bar tracks overall revision progress.

#### TC-IOS-REVN-03 [P1] Revision Exit & Resume
- **Objective:** Verify pause and resume handling in revision mode.
- **Flavors:** Student
- **Preconditions:** Item 4 of 10 completed.
- **Steps:**
  1. Background the app, wait 10 seconds, foreground.
  2. Tap Back button; observe pause confirmation.
  3. Resume session.
- **Expected Results:**
  - Current item state is preserved.
  - Timer pauses during background or pause modal.

#### TC-IOS-REVN-04 [P2] Revision Mastery Boost Summary
- **Objective:** Verify mastery score improvements highlighted on revision completion.
- **Flavors:** Student
- **Preconditions:** Session completed.
- **Steps:**
  1. Complete final item in revision.
  2. Inspect completion report:
     - Topics reviewed (e.g., "Cell Division: 45% ➔ 62%").
     - Screen time minutes earned.
- **Expected Results:**
  - Visual delta (before ➔ after) clearly communicates student progress.

---

### Suite 09: Gamification, Badges & Leaderboards

#### TC-IOS-GAME-01 [P0] Real-Time XP Accumulation & Level-Up Animation
- **Objective:** Verify XP accrual and celebratory level-up full-screen modal.
- **Flavors:** Student
- **Preconditions:** Student is within 10 XP of reaching Level 3.
- **Steps:**
  1. Complete an interaction that awards +25 XP.
  2. Observe screen transition.
- **Expected Results:**
  - XP counter animates upwards with rolling number effect.
  - Level-up modal triggers:
    - Glowing badge animation.
    - Title: *"LEVEL UP! You reached Level 3!"*
    - Haptic celebratory vibration (`HapticFeedback.heavyImpact()`).
  - Dismissing modal updates level pill across all screens.

#### TC-IOS-GAME-02 [P1] Badges Screen (15+ Badges Display)
- **Objective:** Verify viewing all 15+ available, in-progress, and earned badges.
- **Flavors:** Student
- **Preconditions:** User on Profile or Home; tap "Badges" (`/student/badges/:workspaceId/:userId`).
- **Steps:**
  1. Open Badges screen.
  2. Scroll through badge grid.
  3. Inspect an **Earned Badge** (e.g., "First 100 Questions", full color, unlocked date).
  4. Inspect an **In-Progress Badge** (e.g., "7-Day Streak", progress bar 5/7 days).
  5. Inspect a **Locked Badge** (grayscale icon, lock overlay, unlock criteria).
  6. Tap on any badge to view the detailed modal.
- **Expected Results:**
  - All 15+ badges render with distinct icons and descriptions.
  - Earned badges show date achieved (e.g., "Earned Sep 14, 2026").
  - Locked badges clearly state requirements without spoiler bugs.

#### TC-IOS-GAME-03 [P0] Streak Counter Maintenance & Streak Freeze
- **Objective:** Verify streak tracking, daily goal completion, and streak protection.
- **Flavors:** Student
- **Preconditions:** Student has an active 3-day streak.
- **Steps:**
  1. Check streak counter displays `3 Days 🔥`.
  2. Complete today's daily minimum study goal.
  3. Verify streak flame pulses and advances to `4 Days 🔥`.
  4. If a "Streak Freeze" item exists in profile, verify it displays as equipped/available.
- **Expected Results:**
  - Flame counter updates immediately upon completing daily goal.
  - Local push notification for daily streak reminder is canceled or rescheduled for tomorrow.

#### TC-IOS-GAME-04 [P1] Workspace Leaderboard (Rankings & Highlighting)
- **Objective:** Verify workspace-scoped leaderboard rankings, privacy names, and self-highlight.
- **Flavors:** Student
- **Preconditions:** Workspace has leaderboard enabled by admin.
- **Steps:**
  1. Open Leaderboard screen (`/student/leaderboard/:workspaceId`).
  2. Locate current student in the list.
  3. Inspect top 3 ranks (Gold, Silver, Bronze podium badges).
  4. Pull down to refresh rankings.
- **Expected Results:**
  - Current user is pinned or highlighted with distinct background color and "You" badge.
  - Display names respect privacy settings (anonymized if configured by admin).
  - Leaderboard is strictly workspace-scoped (no global cross-tenant leakage).

#### TC-IOS-GAME-05 [P2] Leaderboard Disabled State Handling
- **Objective:** Verify clean UI state when admin disables the leaderboard for a workspace.
- **Flavors:** Student
- **Preconditions:** Admin has toggled `leaderboard_visibility: false` in workspace settings.
- **Steps:**
  1. Attempt to open Leaderboard tab or tap leaderboard card.
- **Expected Results:**
  - Screen displays empty/disabled illustration: *"Leaderboard is currently turned off for this class"*.
  - No crash, error codes, or blank screens.

---

### Suite 10: Study Documents & In-App Viewer (Student)

#### TC-IOS-DOCS-01 [P1] Student Document Library Browsing
- **Objective:** Verify student viewing study materials uploaded to their workspace.
- **Flavors:** Student
- **Preconditions:** Admin has uploaded and processed 3 documents (PDF, notes).
- **Steps:**
  1. Open Documents tab (`/student/documents/:workspaceId`).
  2. Scroll through document list.
  3. Inspect card metadata: Title, File Type chip (PDF, TXT), Topic Count, Date Added.
- **Expected Results:**
  - All processed documents appear with status "Ready".
  - Flagged or processing documents are hidden from students.

#### TC-IOS-DOCS-02 [P1] In-App PDF Document Viewing & Pinch-to-Zoom
- **Objective:** Verify reading a study PDF within the iOS app with smooth zooming.
- **Flavors:** Student
- **Preconditions:** Tap on a PDF document in the list.
- **Steps:**
  1. Tap a PDF item.
  2. Verify in-app viewer opens.
  3. Perform pinch-to-zoom gesture on the text.
  4. Scroll vertically through multi-page document.
- **Expected Results:**
  - PDF loads and renders crisp vectors/fonts.
  - Pinch-to-zoom is smooth and centers on touch anchor.
  - Page indicator (e.g. "Page 3 of 12") updates as user scrolls.

#### TC-IOS-DOCS-03 [P2] Extracted Topics View from Document
- **Objective:** Verify tapping a document shows the AI-extracted topics covered.
- **Flavors:** Student
- **Preconditions:** Document details open.
- **Steps:**
  1. Expand "Topics in this Document" section.
  2. Tap a topic chip (e.g., "Mitochondria").
- **Expected Results:**
  - Topic chips display mastery status and complexity level.
  - Tapping a chip initiates a study session focused on that specific topic.

---

### Suite 11: Apple Push Notifications (APNs) & Deep Linking

#### TC-IOS-NOTF-01 [P0] APNs Device Token Registration with Backend
- **Objective:** Verify that iOS APNs device token registers with the backend API on launch.
- **Flavors:** Both
- **Preconditions:** App installed on physical iPhone. User logged in.
- **Steps:**
  1. Launch app on physical device.
  2. Grant notification permission when prompted.
  3. Inspect backend `notification_tokens` collection in Cosmos DB (or API logs).
- **Expected Results:**
  - Device token is posted to `POST /api/v1/users/me/notification-tokens`.
  - Platform field records `ios`, with valid `installation_id` and `last_seen_at` timestamp.

#### TC-IOS-NOTF-02 [P0] Receiving Push Notification in Background & Banner Display
- **Objective:** Verify receiving and displaying a push notification while app is in background or locked.
- **Flavors:** Both
- **Preconditions:** App sent to background. Device locked.
- **Steps:**
  1. Trigger a push notification via backend test script (`test_active_push.py`) or admin scheduler.
  2. Observe iPhone Lock Screen / Notification Center.
- **Expected Results:**
  - Banner drops down with title and expandable description text.
  - System sound / vibration plays according to device ringer setting.
  - App badge counter increments if configured.

#### TC-IOS-NOTF-03 [P0] Tapping Notification When App is Killed (Cold Deep Link)
- **Objective:** Verify tapping notification when app is terminated cold-boots the app and routes directly to the target screen.
- **Flavors:** Both
- **Preconditions:** App force-closed from App Switcher. Notification delivered.
- **Steps:**
  1. Tap the notification banner on the Lock Screen.
  2. Observe cold launch and route resolution.
- **Expected Results:**
  - App cold-boots through splash screen.
  - Deep link handler parses payload `data: {"workspace_id": "...", "type": "study_reminder"}`.
  - Router navigates directly to `/student/session/:workspaceId` (or target route).
  - User lands on target screen without getting stuck on login or home.

#### TC-IOS-NOTF-04 [P0] Tapping Notification When App is in Background (Warm Deep Link)
- **Objective:** Verify tapping notification while app is suspended in background brings it forward and routes.
- **Flavors:** Both
- **Preconditions:** App sitting in background.
- **Steps:**
  1. Send push notification.
  2. Tap banner from iPhone Notification Center.
- **Expected Results:**
  - App resumes immediately to foreground.
  - `onTap: (RemoteMessage message)` triggers; `GoRouter` pushes target route.

#### TC-IOS-NOTF-05 [P1] Foreground Notification Banner Presentation
- **Objective:** Verify foreground presentation options for general study reminders and achievements.
- **Flavors:** Both
- **Preconditions:** User actively using the app on Home screen.
- **Steps:**
  1. Send a "Badge Unlocked" or "Study Reminder" push notification.
  2. Observe top of screen.
- **Expected Results:**
  - Native banner drops down while inside the app (`[.banner, .sound, .badge]`).
  - Banner dismisses automatically after 4 seconds or on upward swipe.
  - Tapping banner opens the relevant screen.

#### TC-IOS-NOTF-06 [P1] Notification Token Revocation on Logout
- **Objective:** Verify push token is deregistered when user logs out so notifications do not leak to another user.
- **Flavors:** Both
- **Preconditions:** User logged in with registered token.
- **Steps:**
  1. Log out of the app.
  2. Trigger a push notification to that user ID.
- **Expected Results:**
  - Backend marks token as soft-deleted or unregistered.
  - Physical iPhone does NOT receive the notification after logout.

---

### Suite 12: Admin App — Workspaces, Roster & Invite Codes

#### TC-IOS-ADMN-01 [P0] First-Launch Admin Onboarding Wizard
- **Objective:** Verify the Day-1 onboarding wizard for a new admin with zero workspaces.
- **Flavors:** Admin
- **Preconditions:** Newly created admin account with no existing workspaces.
- **Steps:**
  1. Log in to the Admin App (`Social Studying Admin`).
  2. Observe redirection to `/admin/onboarding`.
  3. Complete step 1: Organization / School / Family Name.
  4. Complete step 2: Create First Workspace (Name: "Grade 10 Biology", Description: "Fall 2026").
  5. Tap "Create Workspace & Continue".
- **Expected Results:**
  - Wizard prevents entering the dashboard with an empty tenant state.
  - Workspace is created via `POST /tenants/{tenantId}/workspaces`.
  - Redirect stops firing and admin lands on Admin Dashboard.

#### TC-IOS-ADMN-02 [P0] Workspace Switcher & Multi-Workspace Management
- **Objective:** Verify creating, viewing, and switching between multiple workspaces.
- **Flavors:** Admin
- **Preconditions:** Admin has 2 workspaces created.
- **Steps:**
  1. Tap the Workspace dropdown selector in the top AppBar.
  2. Select "Grade 11 Chemistry".
  3. Verify all dashboard statistics, documents, and student counts switch to Chemistry.
  4. Tap "Create New Workspace"; enter details and submit.
- **Expected Results:**
  - Switching workspace re-scopes all queries immediately.
  - New workspace appears in the dropdown list and can be made active.

#### TC-IOS-ADMN-03 [P0] Generating & Copying 6-Character Student Invite Code
- **Objective:** Verify generating a workspace invite code and copying to iOS clipboard.
- **Flavors:** Admin
- **Preconditions:** Active workspace selected.
- **Steps:**
  1. In workspace settings or roster, tap "Invite Students".
  2. Tap "Generate Code".
  3. Observe the displayed 6-character code (e.g., `BIO789`).
  4. Tap the "Copy to Clipboard" icon.
  5. Open iPhone Notes app; long-press and tap **Paste**.
- **Expected Results:**
  - Code generates via `POST /workspaces/{id}/invite-codes`.
  - Copy action triggers iOS haptic click and toast: *"Code copied to clipboard"*.
  - Pasted text matches the exact 6-character code.

#### TC-IOS-ADMN-04 [P1] Workspace User Roster & Student Details
- **Objective:** Verify viewing enrolled students, join dates, and roles.
- **Flavors:** Admin
- **Preconditions:** 3 students enrolled in workspace.
- **Steps:**
  1. Navigate to Users tab (`users_screen.dart`).
  2. Inspect user list: Display Name, Email/ID, Role badge (Student vs Workspace Admin), Last Active.
  3. Tap on a student row.
- **Expected Results:**
  - Roster displays accurate student information.
  - Tapping a student navigates to `AdminStudentProgressScreen` (`/admin/students/:workspaceId/:userId/progress`).

#### TC-IOS-ADMN-05 [P1] Role Promotion, Demotion & Student Removal
- **Objective:** Verify promoting a user to Workspace Admin or removing a student from roster.
- **Flavors:** Admin
- **Preconditions:** Admin viewing user options.
- **Steps:**
  1. Tap the three-dot menu on a student row.
  2. Tap "Promote to Workspace Admin"; confirm dialog.
  3. Verify role badge updates to "Admin".
  4. Tap menu on a test student; tap "Remove from Workspace"; confirm.
- **Expected Results:**
  - Role update sends `PUT /workspaces/{wId}/users/{uId}/role` and invalidates Redis cache.
  - Removal soft-deletes user relationship; student disappears from active roster.

---

### Suite 13: Admin App — Document Ingestion, Camera & Photo Library

#### TC-IOS-UPLD-01 [P0] Document Upload via iOS File Picker (PDF / TXT)
- **Objective:** Verify picking and uploading a PDF document from the iOS Files app or iCloud Drive.
- **Flavors:** Admin
- **Preconditions:** Valid study PDF stored in iCloud Drive / iPhone Files app.
- **Steps:**
  1. On Documents tab, tap the "+" Floating Action Button or "Upload Document".
  2. Select "Browse Files".
  3. Observe native iOS Document Picker sheet.
  4. Select a PDF file (e.g., `chapter1_biology.pdf`, 3.5 MB).
  5. Tap **Upload**.
- **Expected Results:**
  - File picker opens cleanly with iCloud Drive / On My iPhone roots.
  - Document uploads via `POST /workspaces/{id}/documents/upload`.
  - New document row appears in list with status `queued` / `extracting`.

#### TC-IOS-UPLD-02 [P0] Native iOS Camera Capture for Study Materials
- **Objective:** Verify capturing a study document/notes using the iPhone physical camera (`NSCameraUsageDescription`).
- **Flavors:** Admin
- **Preconditions:** Camera permission not yet requested OR granted.
- **Steps:**
  1. Tap "Upload Document" > select "Take Photo / Scan".
  2. If first time, observe native iOS permission dialog: *"We need access to the camera so you can capture images"*; tap **OK**.
  3. Take a photo of a textbook page.
  4. Tap **Use Photo** (or Retake if blurry).
  5. Tap **Upload**.
- **Expected Results:**
  - Native iOS camera viewfinder opens full-screen.
  - Photo is captured in high resolution and compressed properly for upload.
  - Document record is created with `file_type: image/jpeg` and queued for OCR extraction.

#### TC-IOS-UPLD-03 [P0] iOS Photo Library Picker (`NSPhotoLibraryUsageDescription`)
- **Objective:** Verify selecting textbook photos from the iOS Photo Library.
- **Flavors:** Admin
- **Preconditions:** Photos exist in iPhone Photos app.
- **Steps:**
  1. Tap "Upload Document" > select "Choose from Photos".
  2. If first time, observe permission dialog: *"We need access to your photo library so you can upload images"*; tap **Allow Access to All Photos** (or Select Photos).
  3. Select an image from the camera roll.
  4. Tap **Done** and proceed with upload.
- **Expected Results:**
  - Photo picker opens smoothly without memory spikes.
  - Image is selected and successfully transmitted to Azure Blob storage.

#### TC-IOS-UPLD-04 [P0] Document Processing Status Polling Lifecycle
- **Objective:** Verify real-time status updates as document progresses through async AI pipeline.
- **Flavors:** Admin
- **Preconditions:** Document uploaded and processing in background.
- **Steps:**
  1. Tap on the newly uploaded document in the list to open `adminDocumentPolling` screen.
  2. Observe the step-by-step pipeline tracker:
     - Stage 1: `extracting` (Azure Document Intelligence OCR)
     - Stage 2: `analyzing` (Content safety + Topic extraction)
     - Stage 3: `vectorizing` (Chunking + AI Search embedding)
     - Stage 4: `ready` (Available for student questions)
- **Expected Results:**
  - UI polls `/documents/{docId}/status` every 2-3 seconds.
  - Progress bar and stage badges update dynamically.
  - Terminal status `ready` displays green badge and lists extracted topics.

#### TC-IOS-UPLD-05 [P0] Flagged Document & Content Moderation Quarantine
- **Objective:** Verify document containing inappropriate content is quarantined.
- **Flavors:** Admin
- **Preconditions:** Upload a test document containing text that triggers content safety (e.g. hate speech test text).
- **Steps:**
  1. Upload the test document.
  2. Monitor processing status.
- **Expected Results:**
  - Pipeline transitions to status `flagged`.
  - Document row displays orange/red "Flagged" banner.
  - Notification / link points admin to Moderation Dashboard for review.
  - Content is quarantined: students CANNOT generate questions from this document.

#### TC-IOS-UPLD-06 [P1] Soft-Deleting a Document & Cascading Cleanup
- **Objective:** Verify deleting a document removes it from active list and vector store.
- **Flavors:** Admin
- **Preconditions:** Document in "Ready" status.
- **Steps:**
  1. Swipe left on document card or tap three dots > "Delete".
  2. Confirm delete modal.
- **Expected Results:**
  - Delete call issues `DELETE /workspaces/{id}/documents/{docId}`.
  - Document disappears from active list (`deleted_at` timestamp set).
  - Associated chunks are removed from search index asynchronously.

---

### Suite 14: Admin App — AI Taxonomy Viewer & Editor

#### TC-IOS-TAXO-01 [P1] Interactive Topic Tree Visualization
- **Objective:** Verify visual representation of AI-generated workspace taxonomy.
- **Flavors:** Admin
- **Preconditions:** At least 2 documents processed, generating 5+ topics with hierarchy.
- **Steps:**
  1. Open Taxonomy Viewer (`/admin/taxonomy/:workspaceId`).
  2. Inspect the topic tree: Root topics, Subtopics, Prerequisites arrows, Complexity tags.
  3. Tap a topic node to expand / collapse children.
- **Expected Results:**
  - Hierarchy renders clearly without overlapping text or tangled node lines.
  - Complexity indicators (Beginner, Intermediate, Advanced) reflect accurate levels.

#### TC-IOS-TAXO-02 [P1] Editing Topic Names & Complexity Levels
- **Objective:** Verify admin override capabilities on AI-extracted topics.
- **Flavors:** Admin
- **Preconditions:** Taxonomy editor open (`/admin/taxonomy/:workspaceId/edit`).
- **Steps:**
  1. Tap on topic "Photosynthetic Reactions".
  2. Change name to "Light-Dependent Photosynthesis".
  3. Change complexity from 2 to 3.
  4. Tap "Save Changes".
- **Expected Results:**
  - Changes save via `PUT /workspaces/{workspaceId}/taxonomy`.
  - Updated name displays across Admin and Student apps immediately.

#### TC-IOS-TAXO-03 [P0] Circular Dependency Prevention in Topic Graph
- **Objective:** Verify validation logic preventing circular prerequisite loops.
- **Flavors:** Admin
- **Preconditions:** Topic A is parent/prerequisite of Topic B.
- **Steps:**
  1. In taxonomy editor, select Topic A.
  2. Attempt to assign Topic B as a prerequisite for Topic A.
  3. Tap "Save Changes".
- **Expected Results:**
  - Client and backend validation block the action.
  - Error dialog displays: *"Cannot create prerequisite: Circular dependency detected (Topic A ➔ Topic B ➔ Topic A)"*.
  - Graph state does not corrupt.

#### TC-IOS-TAXO-04 [P2] Triggering Full Taxonomy Regeneration
- **Objective:** Verify triggering asynchronous AI re-analysis of all workspace study materials.
- **Flavors:** Admin
- **Preconditions:** Multiple documents uploaded.
- **Steps:**
  1. In Taxonomy view, tap AppBar action menu > "Regenerate Taxonomy".
  2. Read confirmation warning: *"This will re-analyze all documents and rebuild the topic hierarchy"*.
  3. Confirm action.
- **Expected Results:**
  - Request sends `POST /workspaces/{id}/taxonomy/regenerate`.
  - Banner shows: *"Taxonomy regeneration in progress..."*.
  - Student mastery mappings are preserved for overlapping canonical topics.

---

### Suite 15: Admin App — Content Moderation & Workspace Settings

#### TC-IOS-MODR-01 [P0] Moderation Dashboard & Flagged Content Review
- **Objective:** Verify reviewing quarantined uploads and AI outputs.
- **Flavors:** Admin
- **Preconditions:** Flagged items exist in workspace.
- **Steps:**
  1. Open Moderation Dashboard (`/admin/moderation/:workspaceId`).
  2. Inspect flagged item card: Source (Upload vs AI Output), Severity Scores (Hate, SelfHarm, Sexual, Violence: 0-7 scale).
  3. Tap item to inspect flagged snippet.
- **Expected Results:**
  - Severity categories display color-coded risk tags.
  - Quarantined snippet is clearly readable by admin.

#### TC-IOS-MODR-02 [P0] Admin Resolution: Approve (False Positive) vs Reject
- **Objective:** Verify admin resolving flagged content.
- **Flavors:** Admin
- **Preconditions:** Flagged item pending resolution.
- **Steps:**
  1. On item 1, tap **Approve (Override)**; enter reason: *"Educational historical context"*. Confirm.
  2. On item 2, tap **Reject / Remove**. Confirm.
- **Expected Results:**
  - Item 1 transitions to approved; document unquarantines and resumes ingestion.
  - Item 2 is permanently discarded.
  - Action is permanently logged in `moderation_log` audit trail.

#### TC-IOS-MODR-03 [P1] Workspace Study Settings Configuration
- **Objective:** Verify configuring daily study goals, question frequency, and pacing.
- **Flavors:** Admin
- **Preconditions:** Workspace settings screen open (`/admin/settings/:workspaceId`).
- **Steps:**
  1. Adjust Daily Question Goal from 10 to 15.
  2. Adjust Screen Time Reward Rate (e.g. 1 min earned per 2 questions).
  3. Toggle Leaderboard Visibility ON/OFF.
  4. Tap "Save Settings".
- **Expected Results:**
  - Settings persist via `PUT /workspaces/{id}/settings`.
  - Student apps reflect new daily target and reward rate upon next launch or refresh.

#### TC-IOS-MODR-04 [P1] Moderation Sensitivity Profiles (Strict vs Educational)
- **Objective:** Verify switching moderation profile between Strict (Standard) and Educational Lenient.
- **Flavors:** Admin
- **Preconditions:** Workspace settings open.
- **Steps:**
  1. Select "Educational Mode" (allows historical conflict/war content).
  2. Save settings.
- **Expected Results:**
  - Backend updates Azure Content Safety threshold profile (Violence threshold 2 ➔ 4).

---

### Suite 16: Admin App — Student Progress & Analytics Dashboards

#### TC-IOS-ANLY-01 [P1] Workspace Aggregate Analytics Dashboard
- **Objective:** Verify cohort metrics, active student counts, and overall accuracy.
- **Flavors:** Admin
- **Preconditions:** Students have completed sessions in workspace.
- **Steps:**
  1. Open Workspace Analytics (`/admin/analytics/:workspaceId`).
  2. Inspect key KPI cards: Total Questions Answered, Average Mastery %, Daily Active Students, Top Struggling Topics.
  3. Toggle time filter: 7 Days / 30 Days / All Time.
- **Expected Results:**
  - Analytics cards render with clean typography and trend graphs.
  - Filtering by time range updates metrics accurately.

#### TC-IOS-ANLY-02 [P1] Per-Student Progress Detail View
- **Objective:** Verify drill-down into an individual student's topic mastery and attempt history.
- **Flavors:** Admin
- **Preconditions:** Roster screen open.
- **Steps:**
  1. Tap student name "Alex Miller".
  2. Observe `AdminStudentProgressScreen`.
  3. Inspect topic mastery bars (e.g., Photosynthesis: 88%, Genetics: 42%).
  4. Inspect attempt count and success rate per difficulty.
- **Expected Results:**
  - Student name displays in AppBar title via query parameter.
  - Mastery radar/bars render accurately matching Cosmos DB knowledge state.

#### TC-IOS-ANLY-03 [P2] Exporting Progress Report (CSV / PDF)
- **Objective:** Verify sharing/exporting workspace progress data via iOS Share Sheet.
- **Flavors:** Admin
- **Preconditions:** Analytics screen open.
- **Steps:**
  1. Tap "Export Report" in top menu.
  2. Select "Export CSV".
  3. Observe native iOS Share Sheet (`UIActivityViewController`).
  4. Select AirDrop, Save to Files, or Mail.
- **Expected Results:**
  - CSV file is generated with clean headers and student data.
  - iOS Share Sheet presents standard share targets.

#### TC-IOS-ANLY-04 [P2] Low Mastery Topic Alerts
- **Objective:** Verify highlighting topics where the cohort average is below 60%.
- **Flavors:** Admin
- **Preconditions:** Cohort average on "Cellular Respiration" is 48%.
- **Steps:**
  1. Check "Needs Attention" section on analytics dashboard.
- **Expected Results:**
  - Low-performing topics are flagged with alert icons.
  - Action button offers: *"Generate Targeted Practice Set"*.

---

### Suite 17: Admin App — Stripe Subscription Paywall & Checkout

#### TC-IOS-SUBS-01 [P0] Admin Subscription Paywall Screen & Plan Tiers
- **Objective:** Verify presentation of pricing tiers, feature lists, and billing periods.
- **Flavors:** Admin
- **Preconditions:** Admin without active subscription navigating to paywall (`/admin/subscription`).
- **Steps:**
  1. Open Subscription screen from Admin settings or paywall trigger.
  2. Inspect plan cards:
     - **Family Plan**: Up to 5 children, all AI learning features, Screen Time integration.
     - **School / Teacher Plan**: Unlimited workspaces, up to 100 students, full analytics.
  3. Toggle between Monthly and Annual billing.
- **Expected Results:**
  - Pricing cards update accurately (annual discount reflected).
  - No text truncation or misaligned CTA buttons.

#### TC-IOS-SUBS-02 [P0] Stripe Checkout Launch via ASWebAuthenticationSession / Safari
- **Objective:** Verify initiating Stripe checkout and launching secure web payment session.
- **Flavors:** Admin
- **Preconditions:** Paywall open.
- **Steps:**
  1. Tap "Subscribe Now" on the Family Plan.
  2. Observe system dialog: *"Social Studying wants to use 'stripe.com' to Sign In / Check Out"*; tap **Continue**.
  3. Inspect Stripe hosted checkout page.
- **Expected Results:**
  - Secure Safari / `ASWebAuthenticationSession` sheet opens.
  - Plan name, currency ($ USD), and amount match selected tier.

#### TC-IOS-SUBS-03 [P0] Payment Success & Deep Link Return (`/payment-success`)
- **Objective:** Verify completing checkout and returning to the app via custom deep link.
- **Flavors:** Admin
- **Preconditions:** In Stripe checkout with test card credentials (`4242 4242...`).
- **Steps:**
  1. Enter test card details, expiration, and CVC.
  2. Tap "Pay $14.99".
  3. Confirm successful payment page.
  4. Wait for redirect back to app (`socialstudy://payment-success`).
- **Expected Results:**
  - Browser dismisses automatically upon redirect.
  - App routes to `PaymentSuccessScreen`.
  - Celebratory visual confirms: *"Subscription Active! Thank you for subscribing."*
  - Admin features unlock immediately.

#### TC-IOS-SUBS-04 [P1] Payment Cancellation / Abandonment (`/payment-cancelled`)
- **Objective:** Verify behavior when user cancels checkout or taps Done in browser.
- **Flavors:** Admin
- **Preconditions:** In Stripe checkout.
- **Steps:**
  1. Tap "Cancel and return to Social Studying" on Stripe page, OR tap "Cancel" on the Safari sheet navigation bar.
- **Expected Results:**
  - Browser closes cleanly.
  - App routes to `PaymentCancelledScreen` or returns to paywall.
  - Friendly message appears: *"Payment was not completed. You can upgrade anytime."*
  - No crash or frozen UI state.

#### TC-IOS-SUBS-05 [P1] Active Subscription Management & Portal Link
- **Objective:** Verify viewing active subscription status, renewal date, and customer portal.
- **Flavors:** Admin
- **Preconditions:** Admin with active subscription.
- **Steps:**
  1. Open Subscription settings.
  2. Inspect status card: Current Plan, Next Renewal Date, Payment Method.
  3. Tap "Manage Subscription".
- **Expected Results:**
  - Opens Stripe Customer Portal to manage cards or cancel subscription.

---

### Suite 18: iOS Hardware, System UX, Accessibility & Edge Cases

#### TC-IOS-EDGE-01 [P0] Offline / Airplane Mode Graceful Degradation
- **Objective:** Verify app stability and user feedback when internet drops.
- **Flavors:** Both
- **Preconditions:** App open on Home screen.
- **Steps:**
  1. Turn ON Airplane Mode in iOS Control Center.
  2. Tap on a feature requiring network (e.g., Start Session or Upload Document).
  3. Turn OFF Airplane Mode. Tap "Try Again".
- **Expected Results:**
  - User-friendly error banner or screen appears: *"No Internet Connection. Check your Wi-Fi or cellular network."*
  - App does not crash, throw unhandled exceptions, or freeze.
  - Tapping "Try Again" re-establishes connection and loads data.

#### TC-IOS-EDGE-02 [P0] Screen Rotation & Device Orientation Locking
- **Objective:** Verify app maintains portrait orientation lock on iPhones as intended.
- **Flavors:** Both
- **Preconditions:** iPhone auto-rotate unlocked.
- **Steps:**
  1. Rotate iPhone 90 degrees to landscape while on Home, Questions, Flashcards, or Admin screens.
- **Expected Results:**
  - Phone app stays locked in Portrait orientation (`UIInterfaceOrientationPortrait`) per `Info.plist` specifications.
  - No awkward sideways rendering or distorted aspect ratios.

#### TC-IOS-EDGE-03 [P1] iOS Dynamic Type / System Font Scaling Accessibility
- **Objective:** Verify layout resilience when user enlarges system text size in iOS Accessibility.
- **Flavors:** Both
- **Preconditions:** In iPhone Settings > Accessibility > Display & Text Size > Larger Text, slide font scale to 150%.
- **Steps:**
  1. Re-open Social Studying app.
  2. Inspect Home screen, Question screen, and Admin dashboard.
- **Expected Results:**
  - Text scales proportionally for readability.
  - Cards and containers expand vertically without clipping text or throwing yellow-and-black RenderFlex overflow errors.

#### TC-IOS-EDGE-04 [P1] Taptic Engine Haptic Feedback Across Operations
- **Objective:** Verify tactile haptic responses on physical iPhone Taptic Engine.
- **Flavors:** Student
- **Preconditions:** iPhone with Haptics enabled in Settings > Sounds & Haptics.
- **Steps:**
  1. Answer question correctly (observe medium success haptic).
  2. Answer question incorrectly (observe light double-tap haptic).
  3. Flip flashcard (observe subtle selection click).
  4. Unlock a badge (observe heavy celebration haptic).
- **Expected Results:**
  - All haptic responses feel crisp and aligned with visual transitions.
  - No delayed or missing vibrations.

#### TC-IOS-EDGE-05 [P0] iPhone SE (4.7" Compact Screen) Layout Validation
- **Objective:** Verify that compact screen sizes do not experience UI overflow.
- **Flavors:** Both
- **Preconditions:** Testing on iPhone SE (3rd generation) or simulator.
- **Steps:**
  1. Walk through all 4 tabs on Student and Admin apps.
  2. Open Question screen and Flashcard screen.
- **Expected Results:**
  - Zero `RenderFlex overflowed by X pixels` errors.
  - Primary action buttons remain accessible via vertical scrolling when needed.

#### TC-IOS-EDGE-06 [P1] Low Power Mode Impact & Animation Throttling
- **Objective:** Verify app performance when iPhone is in Low Power Mode (60Hz cap, background restrictions).
- **Flavors:** Both
- **Preconditions:** Enable Low Power Mode in iPhone Settings > Battery.
- **Steps:**
  1. Launch app and navigate through Study Sessions and Flashcards.
  2. Background app for 5 minutes; resume.
- **Expected Results:**
  - Animations (confetti, card flip, mascot bounce) remain smooth without crashes.
  - App handles background throttling without dropping session data.

#### TC-IOS-EDGE-07 [P0] Rapid Multi-Tapping & Monkey Testing (Double-Submit Prevention)
- **Objective:** Verify that rapidly tapping submit or navigation buttons does not trigger duplicate API calls or duplicate XP rewards.
- **Flavors:** Both
- **Preconditions:** On Question submit button or Document Upload button.
- **Steps:**
  1. Select an answer; tap "Submit Answer" 5 times in rapid succession (<500ms).
  2. Tap "Upload Document" 5 times rapidly.
- **Expected Results:**
  - Submit button disables on the very first tap.
  - Only one API request is dispatched to the backend.
  - User receives XP only once; no duplicate interaction records created.

#### TC-IOS-EDGE-08 [P1] iOS App Switcher Snapshot Privacy
- **Objective:** Verify that sensitive data is not exposed in the iOS App Switcher snapshot.
- **Flavors:** Both
- **Preconditions:** App running.
- **Steps:**
  1. Swipe up from bottom and pause to enter the iOS App Switcher.
  2. Inspect the app thumbnail preview.
- **Expected Results:**
  - App thumbnail renders cleanly without glitching or exposing sensitive credentials.

---

## 5. Defect Reporting Standard & Template

When logging defects discovered during iPhone testing, QA testers must utilize the following structured format to ensure rapid triage by mobile engineering:

```markdown
### [BUG-IOS-XXXX] Brief Descriptive Title (e.g., Native Shield fails to appear on Instagram when available minutes reach 0)

- **App Flavor:** [ ] Student App (`Social Studying AI`)  /  [ ] Admin App (`Social Studying Admin`)
- **Severity:** [ ] P0 - Blocker  /  [ ] P1 - Major  /  [ ] P2 - Minor
- **Device Model:** (e.g., iPhone 15 Pro, Model A3102)
- **iOS Version:** (e.g., iOS 17.5.1)
- **Build / Commit:** (e.g., TestFlight v0.1.0 (4), Commit 72d282e)
- **Preconditions:** (e.g., Screen Time permission approved, Instagram selected in picker, wallet = 0m)

#### Steps to Reproduce:
1. Open Social Studying AI app.
2. Verify wallet shows 0 minutes available.
3. Exit to iPhone Home Screen.
4. Tap the Instagram app icon.

#### Expected Result:
Native Apple Shield overlay ("Study Session Needed") should appear over Instagram preventing access.

#### Actual Result:
Instagram opens directly to the feed; no shield is applied.

#### Supporting Artifacts:
- Screen recording attached: `RPReplay_Final1717529402.mp4`
- Xcode / Console log snippet:
  `[ManagedSettings] Failed to set shield for application: Error Domain=NSCocoaErrorDomain Code=4099...`
```

---

## 6. QA Tester Sign-Off Checklist

Before any iOS build is promoted from Staging to App Store Review submission, the QA Lead must verify and check off every category below:

- [ ] **Build Integrity:** Both schemes (`Runner` Student and `Runner` Admin) archive without errors from `ios/Runner.xcworkspace`.
- [ ] **App Store Mandatory Requirements:** Sign in with Apple functioning with Face ID; Privacy Policy & Terms links active and opening in-app Safari.
- [ ] **Apple Screen Time & FamilyControls:** Native permission prompt, `FamilyActivityPicker` selection, shield application, and shield removal verified on a physical iPhone.
- [ ] **Push Notifications:** APNs token registration, background banner display, and interactive "Study Now ➔" button deep link verified.
- [ ] **Adaptive Study & AI Questions:** Latency < 3.0s, MCQ/Math/Text questions, confetti animation, and Taptic feedback verified.
- [ ] **Admin Ingestion & Media:** PDF upload, native iPhone Camera capture, and Photo Library access validated with correct permission prompt descriptions.
- [ ] **Crash-Free Metric:** 0 crashes observed across a continuous 60-minute test run on physical iPhone hardware.

---
*End of Document. Maintained by Mobile QA Engineering.*
