# Guardian — Feature Completion Report

Prepared for Codex. Senior-engineer review of the two features currently shipped in `guardian_app/`. For each feature: a technical completion assessment, a plain-English ("layman") summary, and concrete gaps that must be closed before this is a real elder-care product.

Scope reviewed:
- `lib/features/protection/**`, `android/app/src/main/kotlin/.../GuardianAccessibilityService.kt`, `AndroidManifest.xml`
- `lib/features/medication/**`, `lib/features/dashboard/**`
- `lib/router/app_router.dart`, onboarding flow

---

## Feature 1 — Payment Protection (UPI pre-transaction overlay)

### What is implemented (technical)

- `GuardianAccessibilityService` binds to Android AccessibilityService and observes `TYPE_WINDOW_STATE_CHANGED / WINDOW_CONTENT_CHANGED / VIEW_TEXT_CHANGED / WINDOWS_CHANGED` for a hardcoded allowlist of 5 UPI apps (GPay, PhonePe, Paytm, BHIM, CRED).
- Screen-text collection via DFS of `AccessibilityNodeInfo` tree (depth ≤6, ≤120 chunks), combined with `event.text` and `contentDescription`.
- Signal extraction: regex-based amount parsing (₹/Rs/INR), UPI-ID regex, recipient inference via labels ("pay to", "recipient", "beneficiary") + inline regex.
- Heuristic classifier produces states: `inactive | monitoring | amber | red`. Promotion rules: collect-request language, ≥2 suspicious signals, raw-UPI recipient + suspicious language, recipient change vs. last flow, unseen recipient.
- `TYPE_ACCESSIBILITY_OVERLAY` overlay with "Review / Stop-and-verify" title+body, details, flags, a red-state cooldown countdown (8s amber / 30s red), Safe-exit and Continue buttons.
- Approved-recipient learning list (last 8 confirmed recipients, persisted in `SharedPreferences`).
- Escalation event recording (`KEY_LAST_ESCALATION_*`) that the Flutter `ParentHomeScreen` reads via `PaymentProtectionBridge` MethodChannel for the "Family follow-up" card.
- Play-Store-compliant AccessibilityService disclosure flow (`ParentDisclosureScreen`, `/disclosure/accessibility` deep-linkable).

### In plain English

When your parent opens a UPI app and reaches a payment screen, Guardian reads what's on the screen, tries to pick out the amount / recipient / UPI ID, decides whether the situation looks risky, and if it does, it pops up a big card over the top of the payment screen telling them to stop, with a timer before they can tap "continue." It also remembers people they've paid before, so trusted recipients don't trigger false alarms.

### Gaps / what a senior engineer would flag

**Detection correctness (highest risk):**
1. **English-only heuristics.** `PAYMENT_ACTION_PATTERNS`, `SUSPICIOUS_SCREEN_PATTERNS`, recipient labels are all English. Target users speak Hindi / Tamil / Telugu / Marathi / Bengali / Kannada. This will miss on >50% of real screens. Need multi-lingual keyword packs + transliteration-aware matching.
2. **No per-app semantic anchors.** Everything is a global text-scrape. UPI apps have stable view IDs (`amount_text`, `vpa_edit_text`, etc.) — we should maintain per-package selectors alongside the text heuristics so detection doesn't silently break when a UPI app reskins.
3. **No confidence score, only hard states.** Collapsing everything into amber/red is brittle. Recommend a weighted score with documented thresholds so tuning is explicit and testable.
4. **High false-positive surface.** `customer care`, `support`, `refund`, `reward`, `otp` — all flagged as suspicious. These appear on legitimate screens (refund status, reward-point redemption). Will train elders to tap through warnings.
5. **High false-negative surface for the actual scam vector.** Scammers now use screen-share + voice coaching; visible screen text is often the legitimate UPI app. We catch collect-requests but not impersonation/social-engineering flows. No signal from call state, screen-share packages (AnyDesk/TeamViewer), or SMS context — all of which are legally permissible to inspect.

**Platform / lifecycle:**
6. No watchdog for service disconnection. Android can kill an AccessibilityService silently; there's no heartbeat, no re-enable nudge on `ParentHomeScreen`, only a stale snapshot.
7. `SharedPreferences` is used as the cross-process event queue between the service and Flutter. For anything beyond the last-event cache this will race. Move escalation history to SQLite (`LocalDb` already exists) or DataStore.
8. `MainActivity.kt` was not reviewed but `isAccessibilityServiceEnabled` comes from a MethodChannel — verify it actually inspects `Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES` and doesn't just return the last cached value.
9. Overlay is always bottom-anchored and `MATCH_PARENT` — on devices with gesture bars + full-screen UPI keyboards this can be occluded or dismissed. Add window-insets handling and a "stuck overlay" kill-switch.
10. No A11y for the overlay itself (no `contentDescription` on buttons, no TalkBack order). Ironic given the service channel.

**Product / safety:**
11. **Continue button permanently suppresses the same signature for 15s** and adds the recipient to the approved list after one tap. An elder under coercion will tap through once; we've now whitelisted the scammer. Approval should require a second factor — child-device confirmation, PIN, or a cool-down verified 10+ minutes later.
12. **No child-side notification on escalation.** The whole pitch is "1 child : 1 elder remote care" but escalations live in `SharedPreferences`. There is no FCM push, no Firestore write, no server. The child dashboard reads only local state on the parent device, which is useless unless child and parent share a device.
13. **No post-payment telemetry.** We only intervene pre-payment. If the overlay is dismissed or missed, we don't log "payment completed at Rs X to Y" for the child to review. `NotificationListenerService` + `UsageStatsManager` tier from the plan memory is not yet wired.
14. **No "why did Guardian pause" explanation an elder can understand.** Reason strings currently include phrases like "raw UPI recipient" and "collect-request or receive-money trick" — the target persona will not parse this.

**Testing / observability:**
15. No unit tests for `GuardianAccessibilityService` analyzer. All thresholds (`HIGH_AMOUNT_THRESHOLD`, cooldowns, promotion rules) are free parameters with no regression coverage. Extract `analyzeScreen` / `maybePromoteForRecipientChange` / `applyRecipientHistoryAndEscalation` into a pure `PaymentInterventionClassifier` class and snapshot-test against a corpus of captured screens.
16. No on-device log/debug surface. When a false positive/negative happens in the field the child has no way to see why. Add a hidden diagnostics screen (signals, matched keywords, extracted amount/recipient, state, timestamp) gated behind a long-press.

---

## Feature 2 — Medication Reminders

### What is implemented (technical)

- `MedicationSchedule` CRUD (SQLite via `LocalDb`) with active/inactive archiving, per-schedule days-of-week and list of HH:mm times.
- `MedicationReminderService` computes dose occurrences in a window and produces a two-stage `ReminderPlan` (Level 1 in-app reminder at `scheduledAt`, Level 3 full-screen alarm at `scheduledAt + 30m`).
- `MedicationReminderOrchestrator` drives a `MedicationNotificationGateway` abstraction; the concrete `PlatformMedicationNotificationGateway` calls `MedicationAlarmPlatformBridge` (MethodChannel) to set Android `AlarmManager` alarms.
- `MedicationAlarmReceiver` + full-screen `MedicationAlarmActivity` (declared `showWhenLocked`, `turnScreenOn`) handle the Level 3 alarm UX.
- `didChangeAppLifecycleState(resumed)` on `ParentHomeScreen` calls `_primeMedicationReminders()` which re-schedules the next 48h window.
- Child dashboard surfaces adherence summary, today's status card, alert feed, and protection activity via Riverpod providers fed by the same local DB.

### In plain English

The child adds medicines with times and days. At the right time a reminder appears in the app; if the parent hasn't confirmed within 30 minutes, a full-screen alarm wakes the phone. The child's dashboard shows whether doses were taken, skipped, or missed.

### Gaps / what a senior engineer would flag

**Scheduling correctness:**
1. **Reminders only schedule when `ParentHomeScreen` is resumed.** If the app is never opened for a day, no alarms get set past the 48h window. This is the single biggest reliability bug. Needs a boot-completed receiver + periodic `WorkManager` job that re-primes the window.
2. **No `RECEIVE_BOOT_COMPLETED` handling.** After a phone restart, all `AlarmManager` alarms are lost. No manifest entry, no re-scheduling on boot.
3. **`SCHEDULE_EXACT_ALARM` is declared but `USE_EXACT_ALARM` is not**, and on Android 13+ `SCHEDULE_EXACT_ALARM` is revocable by the user and not grantable from settings for most apps — you need `USE_EXACT_ALARM` (healthcare/reminders is an allowed use case) or a documented fallback to `setAndAllowWhileIdle`. Currently there's no runtime check, no permission request, no fallback — hence the `catch (_)` silent-drop comment at `parent_home_screen.dart:78`.
4. **No battery-optimization / Doze handling.** On Xiaomi, Oppo, Vivo, Samsung the OEM-layer restrictions kill alarms regardless of Android state. Need an onboarding step to open the OEM-specific battery-whitelist screen and a diagnostic that detects when alarms didn't fire.
5. **Level 2 escalation is missing.** The plan in memory describes an escalation ladder (`level1 in-app` → level 2 → `level3 alarm`) but the code jumps straight to Level 3 at +30m. There is no SMS/push to the child at any point. The "escalation to family" promise is unfulfilled.
6. **No timezone safety.** `DateTime` arithmetic is local-time; if the parent crosses a DST boundary or timezone (common for NRIs + visiting elders) reminders skew by an hour.
7. **`occurrenceId` keyed on `millisecondsSinceEpoch`** makes idempotency across time-shifts fragile. Consider `medicationId:YYYY-MM-DD:HH:mm` so the identity is deterministic regardless of when you compute it.

**Data model & adherence:**
8. No "taken / skipped / snoozed" action from the Level 3 full-screen alarm is reviewed in this pass — verify `MedicationAlarmActivity` actually writes back to `MedicationDoseEvent` (the bridge exists but the round-trip was not inspected; high risk of silent data loss).
9. Medication model has no `PRN` / as-needed, no dose range, no inventory / refill tracking, and no stop-date. Memory notes pharmacy-affiliate monetization — that requires at least inventory.
10. No caregiver-authored notes per medication ("take with food"), no photo of the pill for recognition.

**Child-side integrity:**
11. Child dashboard reads from the **parent device's** local SQLite. There is no sync, no shared Firestore, no pairing code. "1 child : 1 elder remote care" is architecturally not yet possible — today it only works if child and parent share the same physical device.
12. No adherence alert push to the child when a dose is missed.

**Testing:**
13. `MedicationReminderService.computeOccurrences` and `evaluateEscalation` are pure and trivially testable — no tests exist. These should be the first unit tests because the escalation window logic is user-safety-critical.

---

## Cross-cutting gaps (both features)

1. **No backend.** Firebase dependencies are in `pubspec.yaml` and initialized defensively in `main.dart`, but there is no `google-services.json` wiring, no `FirebaseAuth` state, no Firestore schema, no FCM topic. Without this, nothing crosses devices.
2. **No pairing flow.** There is a role selector (parent/child) but no link between a specific parent device and a specific child account.
3. **`.env.example` is loaded as the real env file** (`main.dart:18`). Any LLM keys / endpoints will need a real `.env` + asset exclusion + runtime check.
4. **No crash/analytics reporting.** For an app whose failure mode is "elder was scammed and we didn't warn," silent field failures are unacceptable. Crashlytics + a minimal events pipeline are P0.
5. **Router redirect logic in `_onboardingRedirect` has four nested branches with partial overlaps** — covered only by manual testing. Extract to a state machine and unit-test it.
6. **Accessibility (the UX kind).** Body text is 18px — good. But color-only status encoding (teal/amber/red pills) and the custom overlay's button contrast need a formal a11y pass (WCAG AA contrast, TalkBack labels, font-scale resilience up to 200%).
7. **No Hindi / regional-language i18n.** `l10n.yaml` exists and `flutter_localizations` is in pubspec but no ARBs are checked in beyond English. Target users will not read English-only safety warnings.

---

## Recommended execution order for Codex

Priority = (user-safety impact) × (blast radius) / (effort).

1. **Medication: boot receiver + WorkManager re-prime + `USE_EXACT_ALARM` + OEM battery-whitelist onboarding.** Without this, medication reminders silently don't fire — the feature is worse than not shipping it.
2. **Medication: round-trip the Level-3 alarm acknowledgement into `MedicationDoseEvent`** and add the Level-2 child-notification step (requires FCM, so pairs with #4).
3. **Payment Protection: Hindi + 2 regional language keyword packs** for `PAYMENT_ACTION_PATTERNS` and `SUSPICIOUS_SCREEN_PATTERNS`, plus per-app view-ID anchors for GPay/PhonePe/Paytm.
4. **Backend: Firebase Auth + Firestore + FCM + a pairing code flow**, then move escalation events and dose events to Firestore so the child dashboard is actually remote.
5. **Payment Protection: harden the Continue flow** — require a child-side confirmation or a 10-minute-delay re-prompt before adding a recipient to the approved list.
6. **Extract `analyzeScreen` into a pure classifier + build a snapshot-test corpus** of captured UPI screens (with PII redacted). Every rule change should be gated on this corpus.
7. **Service-health watchdog** (AccessibilityService heartbeat + ParentHome banner if disabled or silently killed).
8. **Post-payment tier** (NotificationListenerService + UsageStatsManager) as a defense-in-depth layer for when the overlay is missed.

Everything above #4 assumes the single-device architecture of today; once a backend lands, items 2/5 become straightforward.
