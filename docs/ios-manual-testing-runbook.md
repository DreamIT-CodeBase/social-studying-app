# Social Studying App — iPhone Manual Testing Runbook (Hands-On Step-by-Step Guide)

> **For Manual QA Testers & Reviewers**  
> This guide is a chronological, human-readable runbook. Follow these exact steps sequentially on your iPhone to thoroughly test the app from start to finish.

---

## 📋 Pre-Test Checklist (Before You Start)

Make sure you have:
1. **Physical iPhone** running iOS 16.0 or higher (iPhone 12, 13, 14, 15, or 16 recommended).
2. **Face ID / Passcode enabled** on the iPhone (Settings > Face ID & Passcode).
3. **At least 1-2 social/entertainment apps installed** to test app blocking (e.g., Instagram, YouTube, TikTok, or Reddit).
4. **Both App Builds installed** via TestFlight or Xcode:
   - 🎓 **Student App:** `Social Studying AI`
   - 🛠️ **Admin App:** `Social Studying Admin`
5. **Wi-Fi or Cellular Data** active.

---

## 🚀 Step-by-Step Testing Flow (Total Duration: ~30-45 mins)

```
[Phase 1: Admin Setup] ──> [Phase 2: Student Onboarding] ──> [Phase 3: Verify App Lock]
         │                                                            │
         ▼                                                            ▼
[Phase 6: Admin Dashboard] <── [Phase 5: Verify App Unlock] <── [Phase 4: Study & Earn Time]
```

---

### PHASE 1: Admin Setup & Material Ingestion (5 mins)
*Goal: Create a classroom/study group and upload study material so questions can be generated.*

#### Step 1.1 — Launch Admin App & Sign In
1. Open the **Social Studying Admin** app on your iPhone.
2. Tap **"Sign In with Email / Microsoft"** or **"Continue with Google"**.
3. Complete sign in.
4. If this is a new admin, the **Setup Wizard** will appear:
   - Enter Organization/Family Name: `Test High School`
   - Enter First Workspace Name: `Grade 10 Biology`
   - Description: `Fall Semester 2026`
   - Tap **"Create Workspace & Continue"**.

#### Step 1.2 — Upload Study Material via iPhone Camera
1. Tap the **"Documents"** tab at the bottom.
2. Tap the blue **"+" (Upload Document)** button.
3. Select **"Take Photo / Scan"**.
4. When iOS asks: *"We need access to the camera so you can capture images"*, tap **OK**.
5. Take a clear photo of any textbook page or printed study notes.
6. Tap **"Use Photo"**, then tap **"Upload"**.

#### Step 1.3 — Observe the AI Ingestion Pipeline
1. Tap on the document you just uploaded.
2. Watch the live status progress bar move through:
   - `extracting` ➔ `analyzing` ➔ `vectorizing` ➔ `ready` (Green checkmark).
3. Tap **"View Extracted Topics"** to confirm the AI discovered topics (e.g., Photosynthesis, Cell Structure).

#### Step 1.4 — Copy Student Invite Code
1. Tap the **"Settings"** or **"Users"** tab.
2. Tap **"Invite Students"** and tap **"Generate Code"**.
3. You will see a 6-character code (e.g., `BIO789`).
4. Tap the **Copy** icon (you will use this code in the Student App).
5. Exit the Admin app.

---

### PHASE 2: Student Onboarding & Screen Time Permissions (5 mins)
*Goal: Enroll as a student and give iOS permissions to lock distracting apps during study hours.*

#### Step 2.1 — Launch Student App & Sign In
1. Open the **Social Studying AI** app on your iPhone.
2. Tap **"Sign In with Apple"** (or Google / Email).
3. If using Apple, authenticate using your **Face ID**.
4. On the "Join Classroom" screen, enter the **6-character code** from Step 1.4 (e.g., `BIO789`).
5. Tap **"Join"**. Verify you enter `Grade 10 Biology`.

#### Step 2.2 — Onboarding Carousel
1. Swipe left through the 3 feature intro slides.
2. Tap **"Get Started"**.

#### Step 2.3 — Push Notification Permission
1. The permission setup screen will appear.
2. Tap **"Enable Notifications"**.
3. When the native iOS dialog appears: *"Social Studying AI Would Like to Send You Notifications"*, tap **Allow**.
4. Verify a green checkmark appears on the card.

#### Step 2.4 — Apple Screen Time Permission (Face ID Prompt)
1. Tap **"Authorize Screen Time"**.
2. A native Apple popup will appear: *"Social Studying AI Wants to Manage Screen Time"*.
3. Look at your phone to authenticate with **Face ID** (or enter device passcode).
4. Verify the permission status changes to **Approved** with a green checkmark.

#### Step 2.5 — Select Distracting Apps to Block
1. Tap **"Select Apps to Block"**.
2. The native Apple **FamilyActivityPicker** sheet will slide up.
3. Tap on **"Social"** or search for apps: select **Instagram**, **TikTok**, or **YouTube**.
4. Tap **Done** in the top right corner.
5. Verify the screen says: *"X apps selected for protection"*.

#### Step 2.6 — Choose Theme & Enter Dashboard
1. Choose **"Match System"** (or Light/Dark).
2. Tap **"Finish Setup"**.
3. You land on the **Student Home Dashboard**!

---

### PHASE 3: Testing the Native App Lock / Shield (3 mins)
*Goal: Confirm that the selected social apps are physically locked right now.*

#### Step 3.1 — Check the Wallet Balance
1. Look at the top card on the Student Home screen:
   - It should say: **"0 min Available"** and **"Apps Protected 🛡️"**.

#### Step 3.2 — Attempt to Open a Blocked App
1. Swipe up from the bottom of your iPhone to go to your **Home Screen**.
2. Tap on the app you chose to block (e.g., **Instagram**).
3. **Observe the result:**
   - Instagram does **NOT** open.
   - A dark full-screen Apple Shield appears with:
     - 🛡️ Title: **"Study Session Needed"**
     - Subtitle: *"To gain access to your app, let’s create a study session."*
     - Button: **"Close"**
4. Tap **"Close"**. You are returned to the Home Screen.  
   *(Success! The app lock is fully working).*

---

### PHASE 4: Study Session & Earning Screen Time (5-7 mins)
*Goal: Complete questions, experience AI feedback, animations, and earn screen time.*

#### Step 4.1 — Start Adaptive Study Session
1. Re-open the **Social Studying AI** app.
2. On the Home screen, tap the big blue button: **"Start Study Session"**.
3. Within **< 3 seconds**, Question #1 will appear on screen.

#### Step 4.2 — Test a Multiple Choice Question (MCQ)
1. Read the question.
2. Tap on **Option A** — notice the blue highlight ring.
3. Tap on **Option B** — notice the selection shifts cleanly.
4. Tap **"Submit Answer"**:
   - **If Correct:** Green card animation, confetti bursts across screen, iPhone gives a crisp celebratory vibration (Taptic Engine), and shows: *"+25 XP, +3 min earned"*.
   - **If Incorrect:** Red card animation, mild vibration, and a helpful AI explanation explaining the right answer.
5. Tap **"Next Question"**. Notice Question #2 loads instantly (pre-fetched in background).

#### Step 4.3 — Complete the 5-Question Session
1. Answer the remaining questions.
2. On Question #5, after submitting, tap **"View Results"**.
3. Observe the **Session Summary Screen**:
   - Total XP earned (e.g., `+125 XP`)
   - Accuracy score (e.g., `80%`)
   - ⏱️ Screen Time Earned: **"+15 Minutes"**!
4. Tap **"Return to Home"**.

---

### PHASE 5: Testing Shield Unlock & Free App Access (3 mins)
*Goal: Confirm that your newly earned 15 minutes unlocked your blocked apps.*

#### Step 5.1 — Verify Home Wallet Update
1. On the Student Home screen, look at the Screen Time card:
   - It now shows: **"15 min Available"**!

#### Step 5.2 — Open the Previously Blocked App
1. Swipe up to return to your iPhone **Home Screen**.
2. Tap the exact same app you blocked earlier (e.g., **Instagram**).
3. **Observe the result:**
   - The shield is completely **GONE**!
   - Instagram opens immediately to its normal feed without any blockage!  
   *(Success! Studying directly earned real device screen time).*

---

### PHASE 6: Testing 3D Flashcards & Spaced Repetition (4 mins)
*Goal: Test tactile card flipping and self-recall rating.*

1. Return to the **Social Studying AI** app.
2. Tap the **"Flashcards"** tab at the bottom.
3. Tap on a deck (e.g., *"Cell Biology Flashcards"*).
4. **Test the 3D Flip:**
   - Tap anywhere on the front of the card.
   - Watch the card smoothly flip **180 degrees** along its Y-axis with a subtle haptic click.
   - The back displays the definition. Tap again to flip back.
5. **Test Self-Rating:**
   - While viewing the back, look at the bottom 3 buttons: **Hard**, **Medium**, **Easy**.
   - Tap **"Easy"**.
   - The card slides away smoothly, and card #2 appears.
6. Rate 3 cards to complete the quick review.

---

### PHASE 7: Testing Revision Mode & Mascot (3 mins)
*Goal: Test mixed study mode and companion mascot reactions.*

#### Step 7.1 — Test Study Mascot
1. Tap the **"Home"** tab.
2. Locate the cute study mascot character near your streak counter.
3. **Tap directly on the mascot:**
   - Watch it perform a happy bounce animation.
   - A speech bubble pops up with an encouraging study tip.
   - Your iPhone gives a light haptic tick.

#### Step 7.2 — Test Revision Mode
1. Tap the **"Revision"** tab.
2. Tap **"Quick 5-Item Revision"**.
3. Notice that it mixes **one question**, then **one flashcard**, back-to-back.
4. Tap the **"X"** in top left corner to test early exit:
   - A dialog asks: *"Exit revision session early?"*
   - Tap *"Keep Studying"* to resume, or *"Exit"* to save and leave.

---

### PHASE 8: Testing Badges & Leaderboard (3 mins)
*Goal: Verify gamification, achievements, and peer rankings.*

#### Step 8.1 — Check 15+ Badges
1. Tap the **"Profile"** tab, then tap **"Badges & Achievements"**.
2. Scroll through the badges:
   - **Unlocked Badges** (full color with date earned, e.g., *"First Study Session"*).
   - **In-Progress Badges** (progress bar showing e.g., 3/7 days).
   - **Locked Badges** (grayed out with lock icon).
3. Tap on any badge to open its detailed achievement modal.

#### Step 8.2 — Check Workspace Leaderboard
1. Tap the **"Leaderboard"** icon or tab.
2. Verify:
   - Top 3 students show Gold, Silver, and Bronze podium icons.
   - Your own account is highlighted with a blue background and a **"You"** badge.
   - Only students from your workspace are listed (no random strangers).

---

### PHASE 9: Push Notifications & "Study Now" Deep Link (4 mins)
*Goal: Verify real-time alerts and one-tap return to study mode.*

1. Press the iPhone Power button to **lock your iPhone**.
2. Wait for a scheduled study reminder OR trigger a test push notification from backend.
3. Look at your iPhone Lock Screen:
   - Banner appears: **"🔔 Study Session Needed"**
   - Subtitle: *"Your social time has expired. Complete a session to unlock more time!"*
4. Long-press or pull down on the notification to reveal the action button: **"Study Now ➔"**.
5. Tap **"Study Now ➔"**.
6. **Observe the result:**
   - The iPhone unlocks.
   - The app opens directly into an active question session ready to study.

---

### PHASE 10: Admin Real-Time Progress Verification (3 mins)
*Goal: Confirm that the student's study work is instantly visible to the teacher/parent.*

1. Open the **Social Studying Admin** app.
2. Tap the **"Users"** tab.
3. Tap on the student name who just finished studying.
4. Inspect the **Student Progress Detail Screen**:
   - Total questions answered updated in real-time.
   - Mastery percentage bar moved up (e.g., from 0% to 65%).
   - Accuracy breakdown (Easy/Medium/Hard) is displayed.

---

### PHASE 11: Hardware, Reboot & Edge-Case Checks (5 mins)
*Goal: Verify app resilience against phone reboots, dark mode, and connection drops.*

#### Step 11.1 — Phone Reboot Shield Test
1. Set available minutes to 0 (or wait for time to elapse so Instagram is shielded).
2. **Restart your iPhone completely** (Power off and turn back on).
3. Do **NOT** open the Social Studying app.
4. Immediately tap Instagram on the Home screen.
5. **Verify:** The shield is still active! (Shielding survives device reboots).

#### Step 11.2 — System Dark Mode Toggle
1. Swipe down from top-right corner to open **iOS Control Center**.
2. Long-press the Brightness slider; toggle **Dark Mode ON / OFF**.
3. Return to Social Studying app:
   - Verify all backgrounds, cards, texts, and navigation bars instantly adapt without flickering or restart.

#### Step 11.3 — Airplane Mode / Offline Graceful Test
1. Open Control Center and turn **ON Airplane Mode**.
2. Tap "Start Study Session".
3. Verify an informative banner appears: *"No Internet Connection"*, with a *"Retry"* button (no app crash or freeze).
4. Turn Airplane Mode **OFF** and tap *"Retry"*. Verify session loads normally.

---

## ✅ Tester Summary Sign-Off Sheet

| # | Test Area | Expected Result | Pass / Fail | Notes |
|---|---|---|---|---|
| 1 | **Admin Setup & Camera** | Photo captured via iPhone camera, uploaded & analyzed into topics | [ ] PASS  [ ] FAIL | |
| 2 | **Student Permissions** | Face ID approved Screen Time; Push notifications enabled | [ ] PASS  [ ] FAIL | |
| 3 | **App Lock (Shield)** | Blocked apps show "Study Session Needed" shield when time = 0m | [ ] PASS  [ ] FAIL | |
| 4 | **Question & Confetti** | Answering correct gives confetti explosion + haptic vibration | [ ] PASS  [ ] FAIL | |
| 5 | **App Unlock** | Earning 15 mins immediately removes shield from Instagram/TikTok | [ ] PASS  [ ] FAIL | |
| 6 | **3D Flashcards** | Cards flip 180° in 3D perspective on tap; Easy/Hard rating works | [ ] PASS  [ ] FAIL | |
| 7 | **Badges & Leaderboard** | 15+ badges display; current user highlighted on leaderboard | [ ] PASS  [ ] FAIL | |
| 8 | **Push "Study Now ➔"** | Notification action deep-links directly into question session | [ ] PASS  [ ] FAIL | |
| 9 | **Reboot Persistence** | Shielding stays locked even after iPhone reboot | [ ] PASS  [ ] FAIL | |
| 10| **Dark Mode & Offline** | Seamless theme adapt; offline shows friendly retry banner | [ ] PASS  [ ] FAIL | |

---
*Tester Name:* ___________________  
*iPhone Model & iOS Version:* ___________________  
*Date Tested:* ___________________  
*Sign-Off:* [ ] APPROVED FOR RELEASE  /  [ ] REJECTED (BUGS FOUND)
