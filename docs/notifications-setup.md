# Push Notifications Setup (Sprint 5.6)

Cross-platform push delivery for the Social Study App goes through
Azure Notification Hubs (ANH), which proxies to FCM (Android + Flutter
fallback) and APNs (iOS). The ANH namespace + hub are provisioned by
`infra/bicep/modules/notification-hub.bicep`. Wiring ANH to Google's
FCM and Apple's APNs requires steps in the Firebase console and Apple
Developer portal that **must** be done by a human — they involve UI
flows in third-party consoles that don't have a sensible API surface
for Bicep / Terraform.

This document walks through those steps. Run them after the Bicep
deploy completes and you can see the new hub in the Azure portal.

## Status

* **Azure side**: provisioned via Bicep. Connection string lands in
  Key Vault as `notification-hub-connection-string`; the API +
  scheduler Container Apps mount it as
  `NOTIFICATION_HUB_CONNECTION_STRING`.
* **FCM side (Firebase)**: human-only setup below.
* **APNs side (Apple)**: deferred to the iOS submission sprint.

Until the FCM step is complete, the backend's notification service
runs in `LoggingSender` mode — every "would have sent" is logged and
nothing is dispatched. The app boots fine in that state.

## Prerequisites

* Azure resources from `main.bicep` deployed (see
  `infra/scripts/deploy.sh`).
* Owner-level access to the Firebase project (or permission to create
  one).
* Owner-level access to the Azure subscription that holds the
  `nh-ns-ssa-<env>-...` namespace.

## Step 1 — Create / pick a Firebase project

1. Open <https://console.firebase.google.com> and either create a new
   project (`social-study-app-<env>`) or select the existing one.
2. Add an Android app:
   * Package name: `com.stephens.socialstudyapp` (matches
     `flutter_app/android/app/build.gradle` → `applicationId`)
   * Nickname: `Social Study App (Android)`
   * Download `google-services.json` and save it to
     `flutter_app/android/app/google-services.json`. **Do not commit
     this file.** `flutter_app/.gitignore` already excludes it; verify
     before pushing.
3. (Deferred to iOS sprint) Add an iOS app the same way and grab
   `GoogleService-Info.plist`.

## Step 2 — Get the FCM server key

ANH needs the FCM server key (a long-lived secret) so it can call the
FCM REST API on your behalf.

1. In Firebase console → ⚙ → Project settings → **Cloud Messaging**.
2. Under **Cloud Messaging API (Legacy)**, click the three-dot menu →
   **Manage API in Google Cloud Console** → enable the legacy API.
3. Back in the Firebase tab, the **Server key** value will appear.
   Copy it.

> **Note.** Google deprecated the legacy server key in favour of HTTP
> v1 + service account JSON. As of mid-2024 ANH still accepts the
> legacy key for FCM. When ANH adds HTTP v1 support, swap the key for
> the service account JSON; the integration on our side
> (`AzureNotificationHubSender`) doesn't change — only ANH's Google
> credentials blade does.

## Step 3 — Paste the FCM key into ANH

1. Azure portal → search for `nh-ns-ssa-<env>` → open the
   `study-app-<env>` hub.
2. Settings → **Google (GCM/FCM)** → paste the server key from Step 2
   → **Save**.

That's it. The next time the backend dispatches a push,
`AzureNotificationHubSender` will hit the ANH REST API, ANH will hand
it off to FCM, FCM will deliver it to the device.

## Step 4 — Verify

A quick smoke test from a dev machine:

```powershell
# Reads the conn string from Key Vault and sends a test push to every
# registered Android device on the hub.
cd backend
python -m scripts.send_test_notification --tag test
```

(Test script lives in `backend/scripts/send_test_notification.py`.)

On a registered device you should see:

* **Foreground**: the in-app banner from
  `flutter_app/lib/shared/services/notification_service.dart` (5.8).
* **Background**: a system notification.

## Step 5 — APNs (deferred)

When the iOS build is ready for store submission:

1. Apple Developer portal → Certificates → create a new Apple Push
   Notification service SSL (Sandbox + Production) certificate for the
   bundle id.
2. Export the certificate as a `.p12` from Keychain.
3. Azure portal → hub → Settings → **Apple (APNS)** → upload the
   `.p12` (token-auth via `.p8` is also supported and recommended).

## Troubleshooting

* **`401 Unauthorized` from the backend's ANH call** — the connection
  string mounted from Key Vault is stale or wrong. Re-run the Bicep
  deploy; the secret is re-minted on each run.
* **Token registration succeeds but no push arrives** — most likely
  the FCM server key in ANH is missing or expired. Re-paste from
  Firebase console.
* **`LoggingSender` keeps firing in prod** — the
  `NOTIFICATION_HUB_CONNECTION_STRING` env var is empty on the
  Container App. Check the Key Vault secret reference + the app's env
  binding.

## What this enables

Once Step 3 completes, the following Sprint 5.7 notification paths
become live:

* **Study reminder** (`type=study_reminder`) — fires daily at the
  workspace's configured time when the student hasn't answered today.
* **Streak warning** (`type=streak_warning`) — fires once per day at
  20:00 local time when the student has an active streak (`> 0`) and
  hasn't studied today.
* **Milestone alert** (`type=milestone`) — fires imperatively on
  level-up or badge unlock (from `services/gamification.py`).
* **Unanswered re-prompt** (`type=unanswered_reprompt`) — Sprint 5.12,
  re-surfaces a skipped question after the cool-down.
