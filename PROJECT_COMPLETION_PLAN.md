EV Smart Companion: Complete Project Plan for Claude Code
One document. Give it to Claude Code and it takes the project from its current state to finished:
Part A: fix the front-end bugs (Login, Sign Up, vehicle selection, Bluetooth, live telemetry)
Part B: make the front end secure
Part C: build the backend and the MongoDB database, step by step
Part D: connect the app to the new backend
Part E: deploy, test on a real phone, and finish with zero errors
It is written for two readers:
You, the students. You don't need backend experience. You only do the steps marked 🧑‍🎓 STUDENT ACTION: installing tools, creating accounts, pasting keys into files, testing on your phone and laptop.
Claude Code, the AI agent. It writes all the code, runs all the commands, and stops to guide you whenever it needs something from you.
---
How to start (students, read this first)
Do Phase 0 yourself (install tools). Claude Code can't install them for you.
Open the project folder (`C:\ev-smart-companion`) in VS Code.
Open Claude Code and send it exactly this:
> Read `PROJECT_COMPLETION_PLAN.md` in this repository and execute it, starting from the first phase that is not ticked in the Progress Log at the bottom. Follow every rule in "Rules for the agent". Stop and guide me step by step whenever you reach a STUDENT ACTION.
When Claude Code shows you a STUDENT ACTION, do it, then reply `done` (or describe what went wrong).
If you close Claude Code and come back later, send the same message again. The Progress Log tells it where it stopped.
> **Never paste passwords, API keys or database connection strings into the Claude Code chat.** Claude Code will tell you which file to paste them into.
---
Rules for the agent (Claude Code: follow these at all times)
Working style
You write all the code. Students never write code. Students only do 🧑‍🎓 STUDENT ACTION steps.
Go phase by phase, in order. Don't start a phase until the previous phase's ✅ Checkpoint passes.
At a 🧑‍🎓 STUDENT ACTION, stop. Explain it in simple numbered steps for someone who has never done it before: which website, what to click, what they should see. Wait for `done`.
Explain before acting. One or two plain sentences before each major step, so the students learn.
Windows + VS Code terminal (PowerShell). Give commands that work there. Use `$env:NAME="value"` for environment variables.
Update the Progress Log at the bottom of this file at the end of every phase: tick the phase and add one line about anything notable.
Safety
Never discard the students' work. No `git reset --hard`, `git clean`, `git checkout -- <file>` or force-push. Before Phase 1, record `git status`. If there are uncommitted changes, commit them on a safety branch first (see Phase 1).
Git: work on the branch `project-completion`. Commit after each checkpoint with the message `Phase N: <title>`. Never push. Pushing is the students' decision (Phase 15 explains how).
Secrets:
Never ask a student to paste a secret into the chat. Tell them which file and which line.
Never print, `cat`, `type`, `Get-Content` or `echo` a `.env` file or any secret value. To check secrets, use `npm run check-env` (Phase 8), which prints only `present` or `missing`.
Never commit `.env`. Check `git status` before every commit.
If a student pastes a secret into the chat anyway: don't repeat it, tell them to put it in the right file, and recommend they regenerate that key later.
Quality and honesty
Smallest safe change. Don't redesign screens, don't refactor working code just to make it look cleaner, don't add packages unless they're needed. If you add one, record why in the Progress Log.
Never delete functionality or tests to make things pass. Fix root causes. Don't add `// ignore:` comments or turn lint rules off unless the Progress Log records a clear reason.
Be honest about verification. Never claim something works unless you ran it. Physical Bluetooth can only be marked working after a real phone + Chrome test (Phase 13). Otherwise write NOT VERIFIED. Never fabricate results.
No errors at the end. Every checkpoint must pass with no errors, failures or analyzer issues.
Architecture rules (do not break)
Login stays on Firebase Authentication (email/password, Google, password reset). Don't replace it.
Live vehicle measurements come only from Bluetooth (BLE). Battery, speed, range, charging, doors and every other live measurement come from the simulator over BLE, through the existing decoder and validation, into the single shared `VehicleBleClient.shared`, and from there to every screen. Never use mock, random, hardcoded, cached-as-current or database values for live measurements, in production or as a fallback. If the simulator doesn't send a value, show N/A. The new backend does not store or serve telemetry.
Don't change the BLE protocol: UUIDs, service filters, framing, chunking, field definitions, central/peripheral roles. Don't create a second BLE connection. Don't move the connection into a single screen.
Use the existing code as the reference. The old Firebase backend (`functions/index.js`, `functions/card_backend.js`, `functions/learning_assistant.js`, `functions/test/*`) and `firestore.rules` contain the business rules. Port the same behaviour to the new backend. Don't invent different rules.
---
The big picture
Current state of the project
Front end: Flutter app in `lib/`. All screens exist.
Login: Firebase Auth. Stays.
Data: Firebase Firestore + Cloud Functions (`functions/`). Replaced by `backend/` + MongoDB in Parts C–D.
Car data: `vehicle_simulator/` (an Android app) acts as the car and sends data over BLE to the main app. Chrome on a laptop uses Web Bluetooth. Stays.
Maps, chargers, routes, weather: free public APIs (OpenStreetMap, Overpass, OSRM, Nominatim, Photon, Open-Meteo). Stay.
Known front-end bugs (from the team's review document): Login sometimes never appears, the vehicle selection / Bluetooth chooser disappears, and BLE + live telemetry must keep working across screens. Fixed in Part A.
Final architecture
```
                    login token (Firebase ID token)
 ┌──────────────────────┐ ───── HTTPS + JSON ─────▶ ┌──────────────────────────┐      ┌────────────────┐
 │ Flutter app (lib/)   │                            │ backend/  (Node.js API)  │ ───▶ │ MongoDB Atlas  │
 │ Chrome / Android     │ ◀───────────────────────── │ hosted on Render         │      │ (database)     │
 └──┬───────────────┬───┘                            └──────┬─────────────┬─────┘      └────────────────┘
    │ login only    │ live car data (BLE only)              │             │
    ▼               ▼                                       ▼             ▼
┌───────────────┐ ┌───────────────────────┐          ┌────────────┐ ┌────────────────┐
│ Firebase Auth │ │ vehicle_simulator     │          │ Gemini AI  │ │ PayPal Sandbox │
└───────────────┘ │ (Android phone, BLE)  │          └────────────┘ └────────────────┘
                  └───────────────────────┘
```
Why the app never talks to MongoDB directly: the database password would be inside the app, and anyone can extract it from an APK. The backend keeps every secret.
Chosen stack (decided, don't change)
Part	Choice
Database	MongoDB Atlas free M0 (document database like Firestore, 512 MB free, supports transactions)
Backend	Node.js 22 LTS + TypeScript + Express 5
DB library	Mongoose
Validation	Zod (strict schemas on every request)
Login check	firebase-admin `verifyIdToken` (needs only the project ID, no service-account key)
Security	helmet, cors, express-rate-limit, Mongoose `sanitizeFilter`
Logging	pino (secrets redacted)
Backend tests	Vitest + Supertest + mongodb-memory-server (`MongoMemoryReplSet`, needed for transactions)
Hosting	Render free web service, Singapore region
Flutter HTTP	the existing `http` package
Folder layout at the end
```
ev-smart-companion/
├── backend/                  ← NEW: everything server-side lives and runs here
│   ├── src/
│   │   ├── app.ts            ← builds the Express app (used by server + tests)
│   │   ├── server.ts         ← starts the server
│   │   ├── config/env.ts     ← validates environment variables
│   │   ├── db/connect.ts     ← MongoDB connection
│   │   ├── models/           ← one Mongoose model per collection
│   │   ├── middleware/       ← auth, validation, errors, rate limits
│   │   ├── routes/           ← one file per feature
│   │   ├── services/         ← business logic (vehicles, cards, paypal, gemini)
│   │   └── scripts/          ← seed.ts, check-env.ts
│   ├── test/
│   ├── .env.example          ← variable names only
│   ├── .env                  ← real secrets (NEVER committed)
│   ├── render.yaml
│   └── package.json
├── lib/                      ← Flutter app
│   └── services/api/         ← NEW: ApiClient
├── vehicle_simulator/        ← BLE simulator (unchanged)
├── packages/vehicle_ble_protocol/  ← BLE protocol (unchanged)
└── PROJECT_COMPLETION_PLAN.md
```
---
PART 0: SETUP
Phase 0: Install the tools (students only, before starting Claude Code)
🧑‍🎓 STUDENT ACTION 0.1: Install software (accept defaults)
Git: https://git-scm.com/download/win
Node.js 22 LTS: https://nodejs.org (the "LTS" button, version 22.x)
Flutter SDK (stable): https://docs.flutter.dev/get-started/install/windows/mobile
Extract to `C:\flutter` (not inside Program Files) and add `C:\flutter\bin` to PATH.
(If `C:\flutter` already exists on this laptop, just add `C:\flutter\bin` to PATH.)
Android Studio: https://developer.android.com/studio. Open it once and let it install the Android SDK. Then More Actions → SDK Manager → SDK Tools → tick Android SDK Command-line Tools → Apply.
Google Chrome (needed for Web Bluetooth).
VS Code + the Flutter and Dart extensions.
Firebase CLI, which the old backend needs until Part D. In a terminal: `npm install -g firebase-tools`, then `firebase login`.
🧑‍🎓 STUDENT ACTION 0.2: Turn on Windows Developer Mode
Flutter needs it for plugins on Windows.
Press Win + R, type `ms-settings:developers`, press Enter.
Turn Developer Mode ON and confirm.
🧑‍🎓 STUDENT ACTION 0.3: Check everything
Close and reopen VS Code, open Terminal → New Terminal, and run:
```powershell
git --version
node --version        # must start with v22
flutter --version     # Dart must be 3.12.2 or newer
flutter doctor --android-licenses   # answer y to everything
flutter doctor        # Flutter, Android toolchain, Chrome, VS Code must show ✓
firebase --version
```
"Visual Studio" may show ✗. That's fine.
🧑‍🎓 STUDENT ACTION 0.4: Hardware for the Bluetooth demo
You need these for Parts A and E:
A laptop with Bluetooth turned on, running Chrome.
An Android phone (Android 8+, ideally the Samsung used before) for the simulator, with a USB cable.
On the phone: Settings → About phone → tap Build number 7 times, then Developer options → USB debugging ON.
---
PART A: FIX THE FRONT-END BUGS (do this first)
Goal: this journey must work end to end:
App launch → Login → (Sign Up if needed) → successful login → Vehicle connection screen → Connect Vehicle → Chrome's Bluetooth chooser → real BLE connection → live data on every screen → Logout → Login.
This is a recovery, not a rewrite. Keep Firebase Auth, Firestore (until Part D), the BLE implementation and the shared telemetry.
Phase 1: Protect the work and audit
Agent steps:
Confirm the repository root (`git rev-parse --show-toplevel`) and current branch.
Run `git status` and `git log --oneline -15`. Record the uncommitted changes in the Progress Log.
Protect uncommitted work: if there are uncommitted changes, run `git checkout -b project-completion`, then `git add -A` (excluding any `.env`), then `git commit -m "Phase 1: snapshot of existing work before recovery"`. Otherwise just `git checkout -b project-completion`.
Run `flutter pub get`, `flutter analyze` and `flutter test`. Record the counts as the baseline.
Read these files fully before changing anything:
`lib/main.dart` (splash `EVHomePage` → `AuthGate`; in debug, Cloud Functions point to the local emulator on port 5001)
`lib/screens/auth_gate.dart`, `login_page.dart`, `signup_page.dart`, `vehicle_details_page.dart`, `profile_page.dart` (sign-out)
`lib/services/auth_service.dart`
`lib/screens/bluetooth_scanning_page.dart` (the Vehicle connection screen)
`lib/services/vehicle_ble_client.dart`, `vehicle_ble_web_adapter_*.dart`, `web/vehicle_ble_bridge.js`, `packages/vehicle_ble_protocol/`
`lib/widgets/vehicle_ble_state_view.dart`, and every screen that reads `VehicleBleClient.shared`
`docs/vehicle-ble-demo.md`
tests: `test/auth_gate_test.dart`, `test/vehicle_ble_client_test.dart`, `test/bluetooth_scanning_page_test.dart`
Write a regression map in the Progress Log: for Login, Sign Up, auth guard, vehicle connection screen, device chooser, GATT connection, live telemetry and shared state, record the current behaviour, the last known working behaviour (from `git log -p`), the root cause and the repair. Trace the real code. Don't guess.
✅ Checkpoint 1: baseline recorded, regression map written, work protected on `project-completion`.
Phase 2: Restore Login, Sign Up, auth guard and logout
Known root cause (confirmed in an earlier audit)
`AuthGate` is correct (it shows a loader until Firebase reports, Login when there's no user, and the protected flow only for a real user). But an account whose registration didn't finish gets trapped:
Sign Up creates the Firebase user, then calls the `verifyAndCreateUserProfile` Cloud Function. If that call fails (for example, the Functions emulator isn't running in a debug build), the Firebase user is not rolled back.
On every launch Firebase restores that session, and `AuthGate` routes to `SignUpPage(authenticatedOnboarding: true)` ("Complete Your Profile"). That page hides the Log In link and has no sign-out, so Login never appears again.
The `_DestinationLoadError` screen ("We could not load your saved vehicle details") offered only Retry, which is another dead end.
Required fix (check first; it may already be applied)
Search for `signOutAction` in `lib/screens/auth_gate.dart` and `lib/screens/signup_page.dart`. If it's already there, verify it matches the following and move on. If not, implement it:
`auth_gate.dart`:
Add `typedef SignOutAction = Future<void> Function();` and an optional `final SignOutAction? signOutAction;` constructor parameter on `AuthGate`.
Pass `widget.signOutAction ?? () => AuthService().signOut()` down to `_AuthenticatedDestination`. Create `AuthService` lazily inside the closure, because tests have no Firebase.
`_DestinationLoadError` gets an `onSignOut` callback and shows a `TextButton('Sign out')` under Retry.
Signing out makes the auth stream emit `null`, so `AuthGate` shows Login on its own. No extra navigation is needed.
`signup_page.dart`:
Add an optional `signOutAction`. In authenticated onboarding mode, show a `TextButton` "Sign out and use another account" where the "Already have an account? Log In" row normally is. It calls `signOutAction ?? AuthService().signOut()`, shows an error dialog on failure, and disables itself while loading.
`AuthService.signOut()` already calls `VehicleBleClient.shared.disconnect()` before signing out. Keep that.
Also verify (fix only confirmed defects)
Fresh unauthenticated launch: splash → Login. No protected screen flashes.
Failed login stays on Login and shows the error. Successful login navigates through `AuthGate` (`LoginPage` itself must not push protected pages).
Sign Up → "Log In" link returns to Login. Failed sign-up stays on Sign Up with the error.
Logout from Profile goes to `AuthGate` → Login, and the BLE session is disconnected.
A restored Firebase session may skip Login (that's the product policy). A cached vehicle record, a BLE connection or a stored boolean must never count as authentication.
Nothing calls `requestDevice` / `VehicleBleClient.start` before login.
Debug-build requirement (document it, don't remove it)
In debug builds `main.dart` sends Cloud Functions calls to the local emulator. Until Part D replaces Cloud Functions, Sign Up in debug needs the emulator running (Phase 3 shows how). Keep this behaviour. Part D removes it.
Tests (add or confirm in `test/auth_gate_test.dart`)
unauthenticated launch shows the loader, then Login (`Welcome Back`), with no protected screen
Sign Up is reachable and "Log In" returns to Login
successful login (via `emailLoginAction` + auth stream) reaches the destination
failed login stays on Login with the error
a signed-in account whose destination fails to load can tap "Sign out" and reach Login (use `signOutAction` to emit `null` on the test stream)
logout (auth stream → `null`) returns to Login
✅ Checkpoint 2: `flutter analyze` → No issues found!; `flutter test` → all pass.
Phase 3: Restore the vehicle connection screen, device chooser and BLE
Known root cause (confirmed in an earlier audit)
`lib/services/vehicle_ble_web_adapter_web.dart` stores the chosen device in `_device` for the life of the browser tab and never clears it. `VehicleBleClient._startWebAttempt` asked for a device only when none was stored (`requestDevice: !adapter.hasSelectedDevice`). So after Disconnect, logout → login, or switching vehicles, Connect Vehicle skipped Chrome's chooser and silently retried the old device. Switching EV001 → EV002 reused EV-Simulator-01 and always caused an identity mismatch.
Required fix (check first; it may already be applied)
Search for `_requireDeviceSelection` in `lib/services/vehicle_ble_client.dart`. If it's present, verify it and move on. If not, implement it:
Add a field `bool _requireDeviceSelection = false;` with a short comment explaining why.
In `disconnect()`, when in web mode, set `_requireDeviceSelection = true` (logout and vehicle switching both go through `disconnect()`).
In `_startWebAttempt()`: `final requestDevice = _requireDeviceSelection || !adapter.hasSelectedDevice;`. Use it for the initial phase (`selectingDevice` if true, otherwise `connecting`) and pass it to `adapter.connect(requestDevice: ...)`. In `onStage`, when the stage is `'DEVICE_SELECTED'`, set `_requireDeviceSelection = false`.
In the generic `catch` of `_startWebAttempt`, schedule a reconnect only if `adapter.hasSelectedDevice && !_requireDeviceSelection`, so a cancelled chooser never reconnects the old device.
`selectedDeviceName` returns `null` in web mode while `_requireDeviceSelection` is true.
Don't change link-loss auto-reconnect (it keeps reusing the selected device), the UUIDs, the service filter or the protocol.
Tests (`test/vehicle_ble_client_test.dart`)
Add `Object? chooserError` to `_FakeWebAdapter`. When `requestDevice` is true and it's set, throw it before selecting.
The vehicle-switch test (`'reuses no stale vehicle identity when switching selected records'`) must expect `requestDeviceArguments` == `[true, true]`. The old `[true, false]` encoded the bug.
New: "Connect after a manual disconnect or sign-out opens the chooser again" → `[true, true]`, 2 connections, connected, `selectedDeviceName` null after disconnect.
New: "cancelling the chooser does not reconnect the previous device" → after disconnect, set `chooserError` to a `DEVICE_REQUEST: NotFoundError` cancellation, call start, wait 2.2 s → phase `error`, message contains "did not select a matching device", only 1 connection.
Keep all existing BLE tests: no BLE before auth, GATT stage errors, identity mismatch, awaiting telemetry, no duplicate connections, link-loss reconnect, manual disconnect stops reconnects.
Vehicle connection screen (`bluetooth_scanning_page.dart`), so verify:
It shows the vehicle model and BLE name, Bluetooth support status, progress for each stage, clear errors, and Retry.
"Connect Vehicle" calls `VehicleBleClient.shared.start(vehicle.id)` only from a button tap (Chrome requires a user gesture).
"Connected · receiving live vehicle state" appears only after a valid snapshot for the selected vehicle ID. While waiting it shows "Connected — waiting for vehicle data".
Identity mismatch explains both IDs. A missing service or characteristic reports the right stage.
✅ Checkpoint 3: `flutter analyze` clean, `flutter test` all pass.
Phase 4: Shared live telemetry and real-data-only
Agent steps (verify, and fix only confirmed defects):
Confirm there is exactly one BLE client: `VehicleBleClient.shared`. Search `lib/` for `VehicleBleClient(`. Only the `shared` instance and test constructors are allowed.
Confirm every screen that shows live measurements (Home/dashboard, Controls, Vehicle Health, Charging map, Trip planner, Maintenance, Profile/Vehicle details, Learn) reads `VehicleBleClient.shared.snapshot` (directly or through `vehicle_ble_state_view.dart`) and rebuilds when it changes.
Confirm no screen reads live measurements from Firestore: `watchVehicleTelemetry`, `watchVehicleBatteryPercentage` and `getVehicleBatteryPercentage` must not be used by screens. They're deleted in Part D.
Confirm a missing measurement shows N/A, and that on disconnect the snapshot is cleared and every screen shows unavailable or stale values. After reconnect, nothing shows as live until a new valid message arrives.
Confirm navigating between screens never starts or duplicates a connection.
If tests are missing, add widget tests: Dashboard, Controls, Health, Charging, Trip and Maintenance show values from a shared snapshot set on a test client; clearing the snapshot shows unavailable values; navigating doesn't create a connection. Use fakes only in tests.
✅ Checkpoint 4: `flutter analyze` clean, `flutter test` all pass, and `flutter build web --release` succeeds.
Phase 5: First real-device check of Part A
🧑‍🎓 STUDENT ACTION 5.1: Run the three programs (the agent guides you)
Each in its own VS Code terminal (Terminal → New Terminal), from the project folder:
```powershell
# Terminal 1: Firebase Functions emulator (needed for Sign Up until Part D)
cd functions; npm install; cd ..
firebase emulators:start --only functions --project smart-ev-learning-companion

# Terminal 2: simulator on the phone (connect the phone by USB first)
cd vehicle_simulator
flutter devices                 # copy your phone's ID
flutter run -d <your-phone-id>

# Terminal 3: main app in Chrome
flutter run -d chrome --web-hostname localhost --web-port 5100
```
In the simulator app: enter the vehicle ID `EV001` (the vehicle document ID, not the registration number) and tap Start advertising. Allow the Bluetooth permissions.
🧑‍🎓 STUDENT ACTION 5.2: Tick each item and tell the agent the results
[ ] 1. Fresh start shows Login (use a Chrome Incognito window to be sure you're logged out)
[ ] 2. Open Sign Up, then "Log In" goes back
[ ] 3. Log in, and the Vehicle connection screen appears
[ ] 4. Click Connect Vehicle, and Chrome's Bluetooth chooser opens
[ ] 5. `EV-Simulator-01` is listed. Select it and click Pair.
[ ] 6. The status moves through connecting → discovering → "Connected — waiting for vehicle data" → "Connected · receiving live vehicle state"
[ ] 7. The dashboard shows the battery % from the simulator. Move the simulator's battery slider, and the app updates.
[ ] 8. Open Controls, Health, Charging, Trip planner and Maintenance, and they all show the same live values
[ ] 9. Stop advertising on the phone, and the app shows disconnected or reconnecting everywhere
[ ] 10. Start advertising again → reconnect → fresh values
[ ] 11. Disconnect, then Connect Vehicle, and the chooser opens again
[ ] 12. Log out from Profile, and Login appears. Log in again → Connect Vehicle opens the chooser (it doesn't silently reconnect).
The agent records each item as VERIFIED or NOT VERIFIED (with the reason) in the Progress Log. Failures must be fixed and retested before Part B.
✅ Checkpoint 5: every item verified, or each unverifiable item honestly marked NOT VERIFIED with its reason.
---
PART B: FRONT-END SECURITY
Phase 6: Front-end security audit and fixes
Agent steps (fix each, tick it in the Progress Log):
Committed `node_modules`. Over 5,000 files from `tools/firestore_seed/node_modules` are in git. Run `git rm -r --cached tools/firestore_seed/node_modules` and add `node_modules/` to the root `.gitignore`.
`.gitignore` must contain: `.env`, `*.env`, `!.env.example`, `backend/.env`, `node_modules/`, `backend/dist/`, `*.keystore`, `*.jks`, `key.properties`.
Search for secrets in `lib/`, `android/`, `web/` and `ios/` (patterns: `AIza`, `secret`, `password =`, `Bearer `, `sk-`, `client_secret`).
Firebase `apiKey` values in `lib/firebase_options.dart` and `android/app/google-services.json` are public identifiers, not secrets. Leave them, but do 🧑‍🎓 6.A.
Any real secret (Gemini key, PayPal secret) must be moved out of the app.
Card data. `registerChargingCard` currently receives a full `cardNumber`. Change the app so only the last 4 digits and the masked number (`XXXX XXXX XXXX 1234`) ever leave the device. Never send or store a full card number, CVV, PIN or payment password. If any screen asks for CVV or PIN, remove that field.
Logs. Remove or redact `print` / `debugPrint` calls that output tokens, emails, phone numbers, card or payment details, or full API responses. The BLE stage logs are fine (no personal data).
External links. `url_launcher` may open only `https:` URLs. PayPal approval URLs may open only on hosts ending in `paypal.com`.
Android permissions. Remove `BLUETOOTH_ADVERTISE` from the main app's `AndroidManifest.xml` (only the simulator advertises). Make sure `usesCleartextTraffic="true"` isn't set for release.
Form validation. Signup, login, profile, maintenance and card forms: every field has a length limit and sensible validation (email format, phone digits, numbers ≥ 0). Don't change the look.
Profile photo. Only JPEG/PNG, resized to ≤ 512×512 (`image_picker`: `maxWidth`, `maxHeight`, `imageQuality`).
Dependencies. Run `flutter pub outdated`. Upgrade anything with a security advisory if the build stays green.
Known limitation (record only): the simulator accepts commands from any connected device. Acceptable for the demo. Don't change the protocol.
🧑‍🎓 STUDENT ACTION 6.A: Restrict the Firebase API keys (about 5 minutes)
https://console.cloud.google.com → project smart-ev-learning-companion → APIs & Services → Credentials.
Android key → Application restrictions: Android apps → add package `com.example.flutter_application_2` + your debug SHA-1. The agent shows you how: `cd android; ./gradlew signingReport`.
Browser key → Websites → add `http://localhost:*` (and your hosted web URL later).
API restrictions for both: only Identity Toolkit API and Token Service API.
If you're not an owner of this Firebase project, ask the owner (repo owner Reshma925) to do it or to make you an Editor.
✅ Checkpoint 6: `flutter analyze` clean, `flutter test` all pass, every item ticked.
---
PART C: BACKEND + DATABASE (MongoDB)
Phase 7: Create accounts and get keys (students)
🧑‍🎓 STUDENT ACTION 7.1: MongoDB Atlas database (about 10 minutes)
Sign up at https://www.mongodb.com/cloud/atlas/register (Google sign-in is fine).
Create a cluster: plan M0 Free, provider AWS, region Singapore (ap-southeast-1) (or Mumbai (ap-south-1) if Singapore isn't free), name `ev-companion`.
Database user (Security → Database Access → Add New Database User): username `ev_app`, Autogenerate Secure Password → Copy and save it in a password manager or a private note (not in the chat). Role: Read and write to any database.
Network access (Security → Network Access → Add IP Address): click Add Current IP Address. Then also add `0.0.0.0/0`, because Render's free plan has no fixed IP. The strong password protects the database.
Connection string (Database → Connect → Drivers → Node.js): copy the string that looks like
`mongodb+srv://ev_app:<db_password>@ev-companion.xxxxx.mongodb.net/?retryWrites=true&w=majority&appName=ev-companion`
Keep it for 7.5.
🧑‍🎓 STUDENT ACTION 7.2: Gemini API key (about 3 minutes)
https://aistudio.google.com/apikey → Create API key → copy it and keep it for 7.5.
🧑‍🎓 STUDENT ACTION 7.3: PayPal Sandbox (test money only, about 5 minutes)
https://developer.paypal.com → log in or sign up.
Apps & Credentials → select Sandbox → Create App → name `EV Smart Companion`, type Merchant.
Copy the Client ID and Secret and keep them for 7.5.
Testing Tools → Sandbox Accounts: note the Personal test account's email and password (you'll "pay" with it).
🧑‍🎓 STUDENT ACTION 7.4: Firebase Auth check
https://console.firebase.google.com → smart-ev-learning-companion → Authentication → Sign-in method: Email/Password and Google must be Enabled. Settings → Authorized domains must include `localhost`. If you can't open the project, ask the owner to add you as Editor.
> Agent note: the backend needs only the Firebase **project ID** `smart-ev-learning-companion`. Don't ask for a service-account key.
Agent steps
Create `backend/` and `backend/.env.example` (placeholders only):
```
   NODE_ENV=development
   PORT=8081
   MONGODB_URI=mongodb+srv://ev_app:REPLACE_ME@REPLACE_ME.mongodb.net/?retryWrites=true&w=majority
   MONGODB_DB_NAME=ev_companion
   FIREBASE_PROJECT_ID=smart-ev-learning-companion
   CORS_ORIGINS=http://localhost:5100,http://localhost:5000
   GEMINI_API_KEY=REPLACE_ME
   GEMINI_MODEL=<copy the model used in functions/learning_assistant.js>
   PAYPAL_CLIENT_ID=REPLACE_ME
   PAYPAL_CLIENT_SECRET=REPLACE_ME
   PAYPAL_API_BASE=https://api-m.sandbox.paypal.com
   DEMO_INR_PER_USD=<copy the value used in functions/card_backend.js>
   ```
Add any other variable the old functions use.
Copy it to `backend/.env` and confirm it's ignored with `git check-ignore backend/.env`.
🧑‍🎓 STUDENT ACTION 7.5: Put your secrets in `backend/.env`
Open `backend/.env` in VS Code. Replace each `REPLACE_ME`: `MONGODB_URI` (put your real DB password in place of `<db_password>`; if the password has `@ # / :`, the agent will tell you how to encode it), `GEMINI_API_KEY`, `PAYPAL_CLIENT_ID` and `PAYPAL_CLIENT_SECRET`. Save. Reply `done`. Don't paste the values in the chat.
✅ Checkpoint 7: after Phase 8 adds the script, `npm run check-env` shows every variable as `present`, and `git status` doesn't list `backend/.env`.
Phase 8: Backend skeleton
Agent steps:
In `backend/`: `npm init -y`, then set `"type": "module"`, `"private": true` and `"engines": { "node": ">=22" }`.
Install the latest stable versions:
deps: `express mongoose zod firebase-admin helmet cors express-rate-limit pino pino-http`
devDeps: `typescript tsx @types/node @types/express @types/cors vitest supertest @types/supertest mongodb-memory-server eslint @eslint/js typescript-eslint prettier`
`tsconfig.json`: `strict`, `noUncheckedIndexedAccess`, target ES2022, module/moduleResolution `NodeNext`, `rootDir: src`, `outDir: dist`.
Scripts:
```json
   "dev": "tsx watch --env-file=.env src/server.ts",
   "build": "tsc -p tsconfig.json",
   "start": "node dist/server.js",
   "typecheck": "tsc --noEmit",
   "lint": "eslint .",
   "format": "prettier --write .",
   "test": "vitest run",
   "check-env": "tsx --env-file=.env src/scripts/check-env.ts",
   "seed": "tsx --env-file=.env src/scripts/seed.ts"
   ```
`src/config/env.ts`: validate every variable with Zod at startup. On a missing variable, exit with a message that names the variable and never prints its value.
`src/scripts/check-env.ts`: print `NAME: present` or `NAME: missing` only.
`src/db/connect.ts`: Mongoose connect with `dbName`. Set `mongoose.set('strictQuery', true)` and `mongoose.set('sanitizeFilter', true)` (blocks `{"$gt": ""}` injection). Log a clear error on failure.
`src/app.ts` exports `createApp()`:
`disable('x-powered-by')`, `helmet()`, `express.json({ limit: '1mb' })`
`cors` allowing only `CORS_ORIGINS` (also allow requests with no Origin, which is what the mobile app sends)
`pino-http` redacting `authorization` and `cookie` headers
a global rate limit (300 requests / 15 min / IP)
`GET /health` → `{ "status": "ok" }` (no auth, no DB)
feature routes under `/v1`
a 404 handler and a central error handler returning `{ "error": { "code", "message" } }`. No stack traces or internal messages in production.
`src/server.ts`: env → DB → `createApp()` → `listen(PORT)` → clean shutdown on SIGTERM.
`src/middleware/auth.ts` → `requireAuth`: read `Authorization: Bearer <Firebase ID token>`, verify with firebase-admin (`initializeApp({ projectId })`, `getAuth().verifyIdToken`), and set `req.user = { uid, email, emailVerified }`. Missing or invalid token → `401`. The verifier must be injectable for tests.
`src/middleware/validate.ts`: Zod for body, params and query with `.strict()` (unknown fields → `400`, friendly message).
ESLint + Prettier config, and `backend/README.md` (how to run, test and seed).
Tests: a shared setup with `MongoMemoryReplSet`; health → 200; no token → 401; bad token → 401; fake valid token → passes.
✅ Checkpoint 8 (in `backend/`): `npm run check-env` (all present), `npm run lint`, `npm run typecheck`, `npm test` and `npm run build` all pass. Run `npm run dev`, then open http://localhost:8081/health → `{"status":"ok"}`. Stop it with Ctrl+C.
Phase 9: Database design (MongoDB collections)
Rules: use `timestamps: true`; trimmed strings with `maxlength`; money stored as whole paise (₹1 = 100), converted to rupees in API responses (the Flutter models use `double`); never store full card numbers, CVV, PIN or passwords; build indexes on startup in development. No telemetry collection, because live data is BLE-only (Rule 15).
Collection	`_id`	Fields (match the Flutter models in `lib/models/`)	Indexes and rules
`users`	Firebase UID	name, email, phone, city, dateOfBirth, profileImageUrl, preferredDrivingMode, preferredChargingMode, notificationPreference, distanceUnit, notificationsEnabled, locationEnabled, connectedVehicleId, vehicleRegistrationNumber	email index
`vehicles`	vehicle ID, e.g. `EV001`	registrationNumber (normalised: uppercase, no spaces), model, ownerName, vin (uppercase), bluetoothDeviceId, bluetoothDeviceName, isActive, batteryCapacityKwh, maximumRangeKm, connectorType, ownerUid (null until claimed)	unique registrationNumber; unique vin; index ownerUid. One owner per vehicle, claimed atomically with `findOneAndUpdate({ _id, ownerUid: null, isActive: true }, { ownerUid })` (replaces `vehicleClaims`)
`maintenanceRecords`	ObjectId	vehicleId, createdByUid, serviceType, category, serviceDate, nextServiceDate, odometerKm, costPaise, serviceCenter, notes, status `Completed`, source `user_entered`	`{ vehicleId: 1, serviceDate: -1 }`
`controlsPreferences`	`${uid}:${vehicleId}`	uid, vehicleId, preferences (same keys and limits as `validVehicleControlsPreferences` in `firestore.rules`: ≤ 20 passenger profiles, ≤ 50 alerts, ≤ 32 active alert keys)	
`chargingCards`	ObjectId	uid, vehicleId, cardType, maskedCardNumber (`^XXXX XXXX XXXX [A-Za-z0-9]{4}$`), cardLastFour, cardHolderName, expiryDate, balancePaise ≥ 0, currency `INR`, status `ACTIVE`, vehicleModel, vehicleRegistrationNumber, vehicleVin, lastRechargePaise, lastRechargeAt	unique `{ uid, vehicleId }`
`cardTransactions`	ObjectId	cardId, uid, vehicleId, type `RECHARGE`/`DEBIT`, amountPaise, balanceBeforePaise, balanceAfterPaise, status, description, stationId, stationName, operator, sessionReferenceId, paymentProvider, paymentMethod, paypalOrderId, paypalCaptureId, paypalAmountCents, paypalCurrency, conversionType, demoExchangeRate	`{ cardId: 1, createdAt: -1 }`; unique sparse paypalOrderId and paypalCaptureId (no double credit)
`paypalOrders`	PayPal order ID	uid, vehicleId, cardId, amountPaise, usdAmountCents, status `CREATED` → `CAPTURED`, capturedAt	
`chargingSessions`	session ID	uid, vehicleId, stationId, stationName, operator, energyKwh, amountPaise, status `CONFIRMED` → `DEBITED`, debitedAt	mirror `debitConfirmedChargingSession` in `functions/card_backend.js`
`profilePhotos`	Firebase UID	contentType (`image/jpeg` or `image/png`), data (Binary, ≤ 300 KB)	replaces Firebase Storage
Agent steps: one model file per collection in `src/models/`, plus `test/models.test.ts` (duplicates rejected, negative balance rejected, bad masked number rejected).
✅ Checkpoint 9: lint, typecheck and test all pass.
Phase 10: API endpoints
All routes except `/health` use `requireAuth`. Every route with a `vehicleId` must check `vehicle.ownerUid === req.user.uid`, through one shared helper `requireOwnedVehicle`. Return `404` for someone else's vehicle. This replaces `firestore.rules`.
Old (Firestore or Cloud Function)	New endpoint	Notes
`verifyAndCreateUserProfile`	`POST /v1/me/profile`	Sign-up: verify the vehicle (same checks as `card_backend.js`), claim it and create the user, in one transaction
`getUserProfile`, `watchUserProfile`	`GET /v1/me`	
`updateUserProfile`	`PATCH /v1/me`	Only the fields allowed in `firestore.rules`. Email comes from the token.
photo upload (Firebase Storage) + `updateProfileImageUrl`	`PUT /v1/me/photo` `{contentType, base64}` (≤ 300 KB), `GET /v1/me/photo`	Check the real file type from the first bytes (JPEG/PNG magic numbers)
`linkVerifiedVehicle`	`POST /v1/me/vehicles`	Verify and claim an extra vehicle
`watchLinkedVehicles`	`GET /v1/me/vehicles`	
`setConnectedVehicle`	`PUT /v1/me/connected-vehicle` `{vehicleId}`	Must be the user's own vehicle
`watchConnectedVehicle`, `getCurrentUserVehicle`	`GET /v1/me/connected-vehicle`	
`verifyConnectedVehicleDetails`	`POST /v1/vehicles/verify`	Port the same checks
`getVehicleById`, `getVehicleRecordById`, `watchVehicleById`	`GET /v1/vehicles/:vehicleId`	Vehicle metadata only, not live measurements
`updateVehicleConfiguration`	`PATCH /v1/vehicles/:vehicleId/configuration`	Only maximumRangeKm > 0, batteryCapacityKwh > 0 and connectorType. Also updates the card's vehicle snapshot fields (replaces the `syncVehicleChargingCardDetails` trigger).
`watchVehicleMaintenanceRecords` / `addVehicleMaintenanceRecord`	`GET` / `POST /v1/vehicles/:vehicleId/maintenance`	Same rules as `firestore.rules`
`get/saveVehicleControlsPreferences`	`GET` / `PUT /v1/vehicles/:vehicleId/controls-preferences`	GET returns defaults if none are saved
`getChargingCard`, `watchChargingCard`	`GET /v1/vehicles/:vehicleId/charging-card`	`null` if there's no card
`registerChargingCard`	`POST /v1/vehicles/:vehicleId/charging-card`	Body: `cardLastFour` + `maskedCardNumber` only. A full `cardNumber` → `400`. Balance starts at 0.
`updateChargingCardDetails`	`PATCH /v1/vehicles/:vehicleId/charging-card`	Can't change balance, status or currency
`watchChargingTransactions`	`GET /v1/vehicles/:vehicleId/charging-card/transactions?limit=50`	Newest first
`createPayPalRechargeOrder`	`POST /v1/vehicles/:vehicleId/charging-card/paypal-orders` `{amountInr}`	Port the amount checks, INR→USD demo conversion and PayPal calls exactly. Return what the app needs (order ID, approval URL, public client ID).
`capturePayPalRechargeOrder`	`POST /v1/vehicles/:vehicleId/charging-card/paypal-orders/:orderId/capture`	Verify `COMPLETED` and the amount with PayPal, then one transaction: credit the balance, insert the transaction, mark `CAPTURED`. Calling it twice must not credit twice.
`debitConfirmedChargingSession`	`POST /v1/charging-sessions/:sessionId/debit`	Port exactly, in one transaction. Insufficient balance → clear error, balance unchanged.
`askEvLearningAssistant`	`POST /v1/assistant/ask`	Port `learning_assistant.js` (same prompt, model, limits). 20 requests/min per user. Limit question length.
`getLegacyChargingCardSummary`, `migrateLegacyChargingCard`	removed	Old Firestore migration helpers. Remove them in the app and simplify their call sites.
`watchVehicleTelemetry`, `watchVehicleBatteryPercentage`, `getVehicleBatteryPercentage`	removed	Live data is BLE-only (Rule 15). Delete them in the app.
Agent steps:
Routes in `src/routes/`, logic in `src/services/`, and a strict Zod schema for every request.
JSON field names must match the Flutter `fromMap` / `toMap` (camelCase). Dates are ISO-8601 strings.
Use `mongoose.startSession()` + `withTransaction()` for sign-up/claim, PayPal capture and debit.
PayPal and Gemini calls get a 15 s timeout. Map errors the way `functions/index.js` does, and never forward raw provider errors.
Port the old tests from `functions/test/*.test.js` to Vitest (mock `fetch`). Add route tests for: the success path of every endpoint; `401` without a token; `404` when user A accesses user B's vehicle; `400` for bad bodies or extra fields; the same PayPal capture twice → credited once; debit with insufficient funds → error with the balance unchanged; claiming an already-claimed vehicle → error; sending a full `cardNumber` → `400`.
✅ Checkpoint 10: lint, typecheck, test and build pass. Give the students a short plain-English summary of every endpoint.
Phase 11: Seed the database
Agent steps:
`src/scripts/seed.ts` upserts (never overwrites a claimed vehicle's `ownerUid`):
`EV001`: registration `TN01AB1234`, model `EV Smart X1`, owner `Registered Vehicle Owner 1`, VIN `EVVIN001`, BLE `EV-SIM-001` / `EV-Simulator-01`, active
`EV002`: `TN02CD5678`, `EV Smart X2`, `Registered Vehicle Owner 2`, `EVVIN002`, `EV-SIM-002` / `EV-Simulator-02`, active
Sensible `maximumRangeKm`, `batteryCapacityKwh` and `connectorType` (from the app's existing defaults, e.g. `ev_range_service.dart`)
One `CONFIRMED` charging session per vehicle only if the app's UI uses sessions
No telemetry documents.
The script prints what it created or skipped. Run `npm run seed`.
🧑‍🎓 STUDENT ACTION 11.1: Look at your data
https://cloud.mongodb.com → your cluster → Browse Collections → database `ev_companion` → `vehicles`. You should see `EV001` and `EV002`. Reply `done`.
✅ Checkpoint 11: running the seed twice in a row works (the second run creates nothing).
---
PART D: CONNECT THE APP TO THE NEW BACKEND
Phase 12: Flutter migration
Strategy: screens keep calling the same method names. Only the data layer changes. Don't touch the BLE code, except to delete the unused Firestore telemetry readers.
Agent steps:
`lib/services/api/api_config.dart`:
```dart
   const String apiBaseUrl = String.fromEnvironment(
     'API_BASE_URL',
     defaultValue: 'http://localhost:8081',
   );
   ```
Release builds must use `https://`. Add a startup check that warns in release if they don't.
`lib/services/api/api_client.dart`: injectable `http.Client` and token provider (default `FirebaseAuth.instance.currentUser?.getIdToken()`); `get` / `post` / `put` / `patch` / `delete` adding `Authorization: Bearer` + JSON headers; 20 s timeout with one retry (Render wakes slowly); on `401`, refresh the token once (`getIdToken(true)`) and retry; `ApiException(statusCode, code, message)` with friendly messages ("No internet connection", "Server is waking up, please try again", "You don't have access to this vehicle"); never log tokens or bodies.
Rename `lib/services/firestore_service.dart` → `lib/services/data_service.dart` and `FirestoreService` → `DataService`, and update every import in `lib/` and `test/`. Rewrite each method to call its Phase 10 endpoint. Delete the legacy-card and Firestore-telemetry methods and simplify their callers.
Replace the Firestore real-time streams. Each `watchX` still returns a `Stream`: fetch immediately; refetch every 15 s only while listened to; refetch right after any app write (a broadcast "changes" stream inside `DataService`); no duplicate emissions; cancel timers when the listener cancels; emit errors to the stream and keep retrying. Add pull-to-refresh only on list screens, in the existing style.
Sign-up (`vehicle_details_page.dart`): after Firebase creates the account, call `POST /v1/me/profile`. Keep the existing rollback (delete the fresh Firebase user if profile creation wasn't attempted) and keep the Phase 2 sign-out escape hatch.
Profile photo (`profile_page.dart`): replace Firebase Storage with `PUT /v1/me/photo`. Display it via `GET /v1/me/photo` (bytes through `ApiClient`, then `Image.memory`).
Learning assistant: `POST /v1/assistant/ask` instead of `httpsCallable`.
PayPal: use the new create and capture endpoints. Keep the web popup flow. Update `docs/paypal-checkout.md`.
`main.dart`: remove the Cloud Functions emulator block (Functions are gone) and the `cloud_functions` import.
Anything that uses `FirebaseFirestore.instance` directly (e.g. `vehicle_controls_page.dart`) must go through `DataService`.
`pubspec.yaml`: remove `cloud_firestore`, `cloud_functions`, `firebase_storage` and `fake_cloud_firestore`. Keep `firebase_core`, `firebase_auth`, `google_sign_in` and all BLE packages. Run `flutter pub get`. Searching `lib/` and `test/` for those removed package names must return nothing.
Tests: replace `fake_cloud_firestore` with `MockClient` (`package:http/testing.dart`) + a fake token provider, keeping each test's intent. Add `ApiClient` tests (header attached, 401 refresh, timeout message, error mapping) and one `watchX` stream test (emits, refetches after a write, stops on cancel). All Part A tests must still pass unchanged.
Update `docs/vehicle-ble-demo.md`: the Functions emulator is no longer needed; the backend runs with `cd backend; npm run dev`.
✅ Checkpoint 12: `flutter pub get`, `flutter analyze` (No issues found!) and `flutter test` (all pass).
Phase 13: Full local test (backend + app + real BLE)
Agent steps
Terminal 1: `cd backend; npm run dev`
Terminal 2: `cd vehicle_simulator; flutter run -d <phone-id>`
Terminal 3: `flutter run -d chrome --web-hostname localhost --web-port 5100 --dart-define=API_BASE_URL=http://localhost:8081`
Fix any error in any terminal or in the Chrome console (F12).
🧑‍🎓 STUDENT ACTION 13.1: Full checklist (report every result)
Account and data (new backend):
[ ] Sign up a new account with registration `TN01AB1234` (a second account uses `TN02CD5678`)
[ ] Log out and log in again. Forgot password sends an email. Google sign-in works.
[ ] Profile: edit name, phone and city → reload → still saved. Photo upload → reload → still shown.
[ ] Vehicle details show EV001
[ ] Maintenance: add a record and it appears in the list
[ ] Controls: change a preference → reload → kept
[ ] Charging card: register it (only the last 4 digits are shown)
[ ] Top up ₹100 with PayPal Sandbox (log in with the sandbox personal account) → balance +₹100 exactly once → the transaction appears
[ ] Learn: ask the chatbot a question and get an answer
[ ] Charging map shows chargers; the trip planner gives a result
Bluetooth (repeat all 12 items from Phase 5.2), then also:
[ ] Health, Charging and Trip pages show N/A or unavailable (not old database numbers) when BLE is disconnected
Security:
[ ] Logged in as the EV002 account, the agent sends a test request for EV001's data → it must return not found
The agent records VERIFIED / NOT VERIFIED for each item in the Progress Log.
✅ Checkpoint 13: every item verified, or failures fixed and retested.
Phase 14: Remove the old Firebase backend
Agent steps:
Delete `functions/`, `firestore.rules` and `tools/firestore_seed/`.
In `firebase.json`, remove the `firestore`, `functions` and Firestore/Functions emulator sections. Keep the `flutter` section (Firebase Auth config).
Rewrite `README.md`: what the app is, the architecture diagram, how to run the backend + simulator + app, and how to seed (`npm run seed`). Remove the old Firestore seeding text.
Search the repo for `Firestore`, `Cloud Functions`, `firebase deploy` and `emulators:start`, and update any docs that are now outdated.
🧑‍🎓 Optional later: in the Firebase console you can delete the Firestore database and Functions. Keep Authentication. Ask the project owner first.
✅ Checkpoint 14: the Phase 10 and Phase 12 checks still pass.
---
PART E: DEPLOY, MOBILE, FINAL CHECKS
Phase 15: Deploy the backend to Render
Agent steps
`backend/render.yaml`: web service, `rootDir: backend`, runtime node, region `singapore`, plan `free`, build `npm ci && npm run build`, start `npm start`, health check `/health`, and every env var from `.env.example` with `sync: false` (values go in the dashboard, never in the file).
The server uses `process.env.PORT`. Commit.
🧑‍🎓 STUDENT ACTION 15.1: Push your branch
```powershell
git push -u origin project-completion
```
No permission to push to `Reshma925/ev-smart-companion`? Ask the owner to add you as a collaborator, or fork the repo and push to your fork (the agent will help).
🧑‍🎓 STUDENT ACTION 15.2: Create the Render service (about 10 minutes)
https://render.com → sign up with GitHub.
New → Blueprint → pick the repo and the branch `project-completion`.
Enter each environment variable, copied one by one from `backend/.env`, except: `NODE_ENV` = `production` and `CORS_ORIGINS` = `http://localhost:5100` (add your hosted web URL later).
Apply, then wait for Live. Copy the URL (e.g. `https://ev-companion-api.onrender.com`). The URL isn't a secret, so you can paste it in the chat.
Open `<URL>/health` → `{"status":"ok"}`.
> **Free plan:** it sleeps after 15 minutes idle and takes about 50 s to wake. **Before any demo, open `/health` first and wait.** A paid plan removes the sleep.
✅ Checkpoint 15: `/health` on Render works, and the app in Chrome with `--dart-define=API_BASE_URL=https://<render-url>` can log in and load the profile.
Phase 16: Make the mobile app solid (Android)
Agent steps:
Focus on Android. iOS needs a Mac + a paid Apple account, so skip it unless the students have both.
Set the app label in `AndroidManifest.xml` to `EV Smart Companion`. If the students have an icon image, use `flutter_launcher_icons` (dev dependency).
Package name `com.example.flutter_application_2` is rejected by Google Play. Change it only if the students will publish. That needs a new Android app in Firebase + a new `google-services.json` + the SHA-1 (as a STUDENT ACTION). Otherwise, record it as a known limitation.
Every screen that loads backend data shows a loading state, a friendly error with Retry, and an empty state.
After login, call `GET /health` in the background so Render starts waking early.
Bluetooth and location permissions are requested only when the feature is opened, with a short explanation. Denying one shows a helpful message, never a crash.
Release build: `isMinifyEnabled = true` and `isShrinkResources = true`, with ProGuard keep rules for Firebase and BLE. If the release APK breaks, turn minify off and record it.
Release signing: guide the students (STUDENT ACTION) to create an upload keystore with `keytool`, stored outside the repo, referenced from the git-ignored `android/key.properties`.
Run on small and large phone emulators and fix any overflow (yellow/black stripes).
🧑‍🎓 STUDENT ACTION 16.1: Test the app on your phone
With the phone connected by USB, the agent runs:
```powershell
flutter run --release --dart-define=API_BASE_URL=https://<your-render-url>
```
Repeat the Phase 13 account-and-data checklist on the phone. (In this project the Bluetooth demo runs in Chrome on the laptop, with the phone as the simulator.)
✅ Checkpoint 16: `flutter build apk --release --dart-define=API_BASE_URL=https://<render-url>` succeeds, and the APK (`build\app\outputs\flutter-apk\app-release.apk`) works on the phone.
Phase 17: Final security review
Backend:
[ ] `npm audit --omit=dev`: no high or critical issues
[ ] A test loops over every route and checks `401` without a token (except `/health`)
[ ] Cross-user tests prove ownership checks on every vehicle route
[ ] Strict Zod on every request; unknown fields rejected
[ ] `sanitizeFilter` on; no queries built from raw user objects
[ ] Rate limits: global, assistant
[ ] CORS allows only listed origins
[ ] Production errors contain no stack traces
[ ] Logs redact `Authorization`; no secrets or card/payment data in logs
[ ] Money in integer paise; PayPal capture and debit are transactional and idempotent
[ ] A full card number, CVV or PIN is never accepted or stored
[ ] Photo upload checks the real type and the size
[ ] `git log --all --full-history -- backend/.env` returns nothing
Front end:
[ ] No secrets in `lib/`, `android/`, `web/`
[ ] Release builds use an `https://` API URL
[ ] Firebase API keys restricted (6.A)
[ ] No logs of tokens or personal data
[ ] Only `https:` links are opened
[ ] Live measurements come only from BLE; no database or mock fallback (search for any reintroduced telemetry reads)
[ ] All Phase 6 items still hold
Whole repo:
[ ] Install `gitleaks` (`winget install gitleaks`) and run `gitleaks detect --source . --verbose`. Firebase public `apiKey`s are expected. For any real leaked secret, the students must regenerate that key on the provider's website, then update `backend/.env` and Render.
Phase 18: Final verification ("definition of done")
The agent runs all of these. Every one must pass.
```powershell
# Backend
cd backend
npm ci
npm run lint
npm run typecheck
npm test
npm run build
npm audit --omit=dev
cd ..

# Main app
flutter clean
flutter pub get
flutter analyze        # No issues found!
flutter test           # all passed
flutter build web --release --dart-define=API_BASE_URL=https://<render-url>
flutter build apk --release --dart-define=API_BASE_URL=https://<render-url>

# Simulator and protocol
cd vehicle_simulator
flutter pub get
flutter analyze
flutter test
cd ..\packages\vehicle_ble_protocol
dart pub get
dart test
cd ..\..
```
Then confirm `git status` is clean (no `.env` files) and commit.
Final report (the agent writes this in chat AND at the end of the Progress Log)
Root cause of the missing Login page, and the fix
Root cause of the missing vehicle option / device chooser, and the fix
Files changed and why (front end and backend)
Commands to run everything (backend, simulator, app)
Test and build results (counts)
Real Bluetooth hardware results, item by item, marked VERIFIED or NOT VERIFIED
Remaining blockers and known limitations
How to merge: `git checkout main; git merge project-completion; git push`, or open a Pull Request on GitHub
---
If time is short: priority order
Priority	What
Must	Part A (Phases 1–5): Login, chooser, BLE and shared telemetry working and verified on hardware
Must	Phases 7–13: MongoDB backend for users, vehicles, maintenance, controls preferences, chatbot, connected to the app
Must	Phase 18 final verification
Should	Phase 6 security fixes, charging card + PayPal, Render deploy, release APK
Nice	Profile photo, app icon, release signing, minify, package rename
Anything skipped goes under "Known limitations" in the Progress Log.
---
Troubleshooting (for the agent when helping students)
Problem	Fix
Login never shows; stuck on "Complete Your Profile"	Use "Sign out and use another account" (Phase 2). Delete the half-created user in Firebase Console → Authentication, or finish onboarding.
Sign Up fails at the vehicle step (before Part D)	The Functions emulator isn't running. Start Terminal 1 from Phase 5.1.
Chrome chooser doesn't open	Use desktop Chrome on `localhost` or HTTPS, not inside an iframe. Laptop Bluetooth must be on. Check the Phase 3 fix is present.
Chooser opens but the simulator isn't listed	The simulator isn't advertising, Bluetooth permissions were denied on the phone, or the phone is too far away. Restart advertising.
"Identity mismatch"	The simulator's Vehicle ID must be the vehicle document ID (`EV001`), not the registration number.
"Connected — waiting for vehicle data" never changes	The simulator isn't sending state. Restart advertising, check the vehicle ID, then Retry.
`Building with plugins requires symlink support`	Turn on Windows Developer Mode (0.2).

`MongoServerSelectionError` / timeout	IP not in Atlas Network Access, or special characters in the password need URL-encoding (`@`→`%40`, `#`→`%23`, `/`→`%2F`, `:`→`%3A`).
`bad auth : authentication failed`	Wrong DB user or password. Reset it in Atlas → Database Access and update `.env`.
Transactions fail in tests	Use `MongoMemoryReplSet`, not `MongoMemoryServer`.
Every API call returns 401	Token missing, the Firebase project differs from `FIREBASE_PROJECT_ID`, or the PC clock is wrong.
CORS error in Chrome	The web port (5100) isn't in `CORS_ORIGINS`.
Phone can't reach `localhost`	`localhost` on a phone means the phone itself. Use the Render URL.
First request takes about 50 s	Render free plan waking up. Open `/health` first.
`flutter` not recognised	`C:\flutter\bin` isn't on PATH. Fix it and restart VS Code.
Dart SDK version error	Run `flutter upgrade`.
PayPal "order not approved"	The popup was closed early, or a real PayPal account was used instead of the sandbox personal account.
Gemini 400/403	Bad key. Create a new one, then update `.env` and Render.
Google sign-in fails on Android	Add the debug SHA-1 in Firebase → Project settings → Android app (`cd android; ./gradlew signingReport`).
---
Progress Log (the agent updates this after every phase)
Baseline (Phase 1, 2026-10-21): repo root `C:\Users\pradh\ev-smart-companion-fresh` (not `C:\ev-smart-companion`). Started on `main` at 90035f8, working tree clean, so no snapshot commit was needed; branch `project-completion` created. `flutter analyze`: No issues found. `flutter test`: 108 passed, 0 failed. Tools: Git 2.54, Node v24.15 (LTS, satisfies `>=22`; kept instead of v22), Flutter 3.44.6 / Dart 3.12.2, Firebase CLI 15.33. Note: the plan was first pasted into `README.md` by mistake; it was moved here and README restored from HEAD.
Regression map (Phase 1):
- Login / auth guard. Current: `AuthGate` (stream-based since 90035f8) shows a loader until Firebase reports, Login for no user, the protected flow only for a real user. Correct. Last working: b769709 resolved `authStateChanges().first` once (no logout reaction). Root cause of "Login never appears": not the gate itself, see Sign Up. Repair: Phase 2 sign-out escape hatches.
- Sign Up. Current: `vehicle_details_page.dart` creates the Firebase user, sets `profileProvisioningAttempted = true`, then calls `verifyAndCreateUserProfile`; on failure (e.g. Functions emulator not running in debug, `main.dart` points Functions at 127.0.0.1:5001) the rollback is skipped, the user stays signed in with no profile. On every launch `AuthGate._loadDestination` returns `SignUpPage(authenticatedOnboarding: true)`, which hides the Log In link and has no sign-out, so Login never appears again. `_DestinationLoadError` offers only Retry (same dead end in b769709). Repair: Phase 2 `signOutAction` on `AuthGate`, `_DestinationLoadError` and `SignUpPage`.
- Logout. Current: `AuthService.signOut()` disconnects `VehicleBleClient.shared`, then Firebase; stream emits null, Login shows. Works.
- Vehicle connection screen. Current: `bluetooth_scanning_page.dart` calls `VehicleBleClient.shared.start(vehicle.id)` from a button. Works; verify in Phase 3.
- Device chooser. Current: `vehicle_ble_web_adapter_web.dart` keeps `_device` for the tab lifetime; `_startWebAttempt` passes `requestDevice: !adapter.hasSelectedDevice` (since aea966c, when Web Bluetooth was added, so there was no earlier working version). After Disconnect, logout/login or a vehicle switch, Connect skips the chooser and reuses the old device (EV002 then hits identity mismatch with EV-Simulator-01). A cancelled chooser leaves the old `_device`, and the generic `catch` schedules a reconnect to it. Repair: Phase 3 `_requireDeviceSelection`.
- GATT connection. Current: stage-by-stage logging and errors, 15 s timeouts, identity check. No defect found.
- Live telemetry / shared state. Current: only `VehicleBleClient.shared` exists (the only other constructor call is the class itself); no screen calls `watchVehicleTelemetry`, `watchVehicleBatteryPercentage` or `getVehicleBatteryPercentage` (only defined in `firestore_service.dart`). Verify screen-by-screen in Phase 4.
Phase	Status	Notes
0. Tools + hardware	☑	Tools verified by agent (Node v24 instead of v22). Developer Mode and phone setup not checked by agent; confirmed at Phase 5.
1. Protect + audit	☑	Baseline 108 tests pass, analyzer clean. Neither the Phase 2 nor the Phase 3 fix was present.
2. Login / Sign Up / auth guard / logout	☑	Added `signOutAction` to AuthGate, `_DestinationLoadError` ("Sign out") and onboarding SignUpPage ("Sign out and use another account"). New test for load-error sign-out; 109 tests pass, analyzer clean. Onboarding button has no widget test: SignUpPage reads FirebaseAuth.instance in onboarding initState, so it cannot render without Firebase; verify on device in Phase 5.
3. Vehicle screen + chooser + BLE	☑	Added `_requireDeviceSelection` to `VehicleBleClient`: set on web disconnect (covers logout and vehicle switch), cleared on DEVICE_SELECTED; cancelled chooser no longer reconnects the old device. Vehicle-switch test now expects [true, true]; 2 new tests. 111 tests pass, analyzer clean. Scanning page already met all checks; no change. Protocol, UUIDs and link-loss reconnect untouched.
4. Shared telemetry, real-data-only	☑	Verified: one client (`VehicleBleClient.shared`); Dashboard, Controls, Health, Charging, Trip, Maintenance, Profile, Vehicle details and Learn read it and match the snapshot vehicle ID; no screen uses Firestore telemetry readers or `Vehicle.batteryPercentage`/`health`. Fixed: Controls showed hardcoded 21 °C, fan 1, 80 % target and "Not charging" with no BLE state; now shows "—" (that page's existing unavailable marker). No widget tests yet for Dashboard/Controls/Charging/Trip: they read `FirebaseAuth.instance`/`FirestoreService()` directly; add them in Phase 12 once `DataService` is injectable. 111 tests pass; `flutter build web --release` OK.
5. Real-device check (Part A)	☑	2026-10-21, students, on Firebase (Functions emulator + simulator on Android phone RZCW71C8QNZ + Chrome localhost:5100). VERIFIED: 1 fresh start shows Login (Incognito); 2 Sign Up -> Log In returns; 3 login -> Vehicle connection screen; 4 Connect opens chooser; 5 EV-Simulator-01 listed and paired; 6 status reaches "Connected · receiving live vehicle state"; 7 dashboard battery % follows simulator slider; 8 Controls/Health/Charging/Trip/Maintenance show same live values; 9 stop advertising -> disconnected/reconnecting; 10 restart -> reconnect with fresh values; 11 Disconnect -> Connect reopens chooser; 12 logout -> Login, login -> chooser reopens. NOT VERIFIED: onboarding "Sign out and use another account" button (no account got stuck on Complete Your Profile, so it was not exercised). Phase 0 hardware and Developer Mode confirmed by these runs.
6. Front-end security	☑	6.A: pending – Punita will do it at the end (she has owner access). Until Phase 14 removes Firestore/Storage, the API restriction must also allow Cloud Firestore API and Cloud Storage for Firebase API; after Phase 14, only Identity Toolkit API and Token Service API. Android key SHA-1 (laptop debug keystore): 6C:8A:36:A7:29:C4:DA:A1:E9:4A:F1:19:2B:74:E2:1F:9E:4A:63:8C. [x] Untracked 5,103 files in tools/firestore_seed/node_modules; .gitignore now has node_modules/, .env, *.env, !.env.example, backend/.env, backend/dist/, *.keystore, *.jks, key.properties. [x] Secret scan of lib/android/web/ios: only Firebase public apiKeys (firebase_options.dart, google-services.json); no Gemini/PayPal secrets in the app. [x] Card form now passes only `cardLastFour` to the data layer (registerChargingCard/updateChargingCardDetails no longer take cardNumber); no CVV/PIN fields exist; new test. Legacy `cardNumber` read/cleanup in FirestoreService/ChargingCard stays until Part D removes legacy helpers. [x] Removed 17 debug logs printing email, UID, registration, model, UID paths and card document data (firestore_service.dart); remaining logs are error/status only. [x] Station website links: only https (http upgraded, other schemes rejected); PayPal approval already restricted to https sandbox.paypal.com; tel: phone button kept (app-built, not a URL; removing it would delete a feature). [x] Removed BLUETOOTH_ADVERTISE from main app manifest; no usesCleartextTraffic; network_security_config allows cleartext only to localhost/127.0.0.1. [x] Length limits via LengthLimitingTextInputFormatter (no visual change) on signup/login/forgot/profile/maintenance/vehicle config/card fields; signup phone now 10-15 digits; numbers >= 0 already enforced. [x] Profile photo: maxWidth/maxHeight 512, quality 85, JPEG/PNG checked by magic bytes. [x] `flutter pub outdated --json`: no package affected by an advisory, discontinued or retracted; no upgrade. Known limitation: simulator accepts commands from any connected device. 112 tests pass, analyzer clean.
7. Accounts + secrets	☑	Atlas M0 cluster `ev-companion`, Gemini key, PayPal Sandbox app created by students. `backend/.env.example` added; `backend/.env` git-ignored and never read by the agent. `npm run check-env`: all 12 variables present. Deviation: the demo rate is named `DEMO_EXCHANGE_RATE_INR_TO_USD=0.012` (USD per INR, exactly as functions/card_backend.js) instead of `DEMO_INR_PER_USD`, whose name implies the inverse. GEMINI_MODEL=gemini-flash-latest (from learning_assistant.js). Students pasted keys into the chat once; agent did not reuse them and they regenerated the MongoDB password, Gemini key and PayPal secret. DB user is now `ev_app` (the first `_db_user` failed auth; students may delete it).
8. Backend skeleton	☑	Express 5.3, Mongoose 9.11, Zod 4.6, firebase-admin 14.5, TypeScript 6.0, Vitest 5.0, ESLint 10 (latest stable at install; npm audit 0 vulnerabilities). helmet, CORS allow-list (+ no-Origin), pino redaction, 300 req/15 min global limit, strict Zod `validate()` storing results on `req.valid` (Express 5 req.query is read-only), JSON errors without stack traces in production, injectable Firebase token verifier (project ID only), sanitizeFilter + strictQuery. `trust proxy` = 1 only in production (Render). lint, typecheck (includes tests via tsconfig.test.json), 11 tests, build all pass; `npm run dev` connected to Atlas and /health returned {"status":"ok"}.
9. Database models	☑	9 Mongoose models in backend/src/models (users, vehicles, maintenanceRecords, controlsPreferences, chargingCards, cardTransactions, paypalOrders, chargingSessions, profilePhotos); no telemetry collection. Money in whole paise. Deviations to match the old code/Flutter (plan rule: port, don't invent): user's connected vehicle field is `vehicleId` (Flutter UserModel), not connectedVehicleId; transaction `type` is credit/debit with status completed (card_backend.js), not RECHARGE/DEBIT; sessions keep status `confirmed` + `debitStatus` pending/completed; PayPal orders PENDING -> COMPLETED with amountPaise/currency + paypalAmountCents/paypalCurrency/conversionType/demoExchangeRate. Extra safety: chargingCards schema uses strict 'throw' (a cardNumber/cvv field is rejected, not silently dropped); unique sparse sessionReferenceId on transactions (no double debit). 21 model tests; lint, typecheck, 32 tests pass.
10. API endpoints	☑	All Phase 10 endpoints in backend/src/routes (me, vehicles, chargingCard, assistant) with logic in backend/src/services; strict Zod on every body/params/query; one `requireOwnedVehicle` helper (404 for others' vehicles, also checked first on PayPal capture). Transactions (`connection.transaction`) for sign-up claim+profile, PayPal credit and session debit; duplicate-key retry returns the already-completed result. PayPal and Gemini calls time out at 15 s (old Gemini was 25 s; plan says 15). Provider errors are logged with safe fields only; the app gets generic messages (old code returned PayPal issue details). Mongoose ValidationError/CastError -> 400. GET /v1/me returns 404 `profile_not_found` when no profile exists (app maps to null in Phase 12). PayPal create takes `{amountInr}` (card must be INR). Photo stored via document save (update validators mis-read Buffers). Not ported (features removed by the plan): legacy card migration tests and Firestore-rules-only tests. 106 tests: 401 sweep over all routes, 404 sweep over all vehicle routes, success paths, double capture (sequential and 3 concurrent) credits once, insufficient funds leaves balance unchanged, already-claimed vehicle, full cardNumber/cvv/pin -> 400, ported PayPal and Gemini tests. lint, typecheck, build pass; npm audit --omit=dev 0 vulnerabilities.
11. Seed data	☐	
12. Flutter migration	☐	
13. Full local test	☐	
14. Old Firebase backend removed	☐	
15. Render deploy	☐	
16. Mobile hardening	☐	
17. Security review	☐	
18. Final verification + report	☐	
Known limitations:
The BLE simulator accepts commands from any connected device (demo only).
PayPal runs in Sandbox (test) mode.
Render's free plan sleeps after 15 minutes idle.

