# Guardian Play Console Accessibility Packet

Purpose: one place for the Play Console Accessibility declaration answers, the reviewer video reference, and the exact in-app surfaces that support those claims.

Status: ready to attach alongside the newly recorded consent video and the next Android App Bundle submission.

## Build for this submission

- App: `Guardian`
- Package: `com.guardian.guardian`
- Planned upload artifact: `build\app\outputs\bundle\release\app-release.aab`
- Flutter version in this submission: `1.0.0+2`

## Reviewer video

- Video status: recorded
- Recommended label in Play Console notes: `Guardian Accessibility consent and enablement flow`
- What the video shows:
  - cold launch into onboarding
  - parent role selection
  - in-app disclosure before permission grant
  - jump to Android Accessibility settings
  - enablement of `Guardian payment protection`
  - return to app with live protection enabled
  - disclosure re-opened from home via `Privacy and permissions`

## Core functionality requiring Accessibility

Use this answer in Play Console:

> Guardian is an elder-safety app that helps older users pause before sending money in risky UPI payment flows. Guardian uses Android Accessibility only to detect when a supported payment app is open and when a real payment screen contains visible payment details such as amount, recipient, or UPI ID. If Guardian detects a risky payment context, it shows a prominent on-screen review warning so the user can slow down, verify the payment, or back out before money is sent.

## Does the app use Accessibility to help users with disabilities?

Use this answer in Play Console:

> Yes. Guardian is designed for older adults who may have age-related cognitive decline, reduced vision, slower digital comprehension, or limited digital literacy. The Accessibility-based payment warning flow is used as a safety aid so these users get a clear, high-visibility pause-and-review step before completing a risky payment.

## Data accessed through Accessibility

Use this answer in Play Console:

> Guardian accesses:
> 1. the package name of the foreground app, only to know when a supported payment app is open;
> 2. on supported payment screens only, visible payment details such as amount, recipient name, UPI ID, and payment note;
> 3. visible on-screen wording on those payment screens that may indicate urgent, suspicious, or scam-like payment requests.
>
> Guardian does not read photos, contacts, or unrelated apps outside supported payment screens. Guardian does not send money, press the pay button, or complete a transaction for the user. Data is used for the immediate on-device safety review flow and is not used for advertising.

## How consent is obtained

Use this answer in Play Console:

> Before requesting Android Accessibility permission, Guardian shows a dedicated in-app disclosure screen that explains what data is accessed, why it is needed, what Guardian never does, and how the user can turn the permission off later. The user must explicitly proceed from that disclosure before Android Accessibility settings are opened. The disclosure remains available later from the app through the `Privacy and permissions` screen so the user can review the permission again after setup.

## In-app evidence that supports the declaration

- Parent onboarding disclosure:
  - screen title: `Guardian needs one permission`
  - path: `lib/features/onboarding/screens/parent_disclosure_screen.dart`
- Standalone disclosure:
  - screen title: `Permissions & privacy`
  - path: `lib/features/onboarding/screens/accessibility_disclosure_screen.dart`
- Re-entry from home:
  - card label: `Privacy and permissions`
  - path: `lib/features/protection/screens/parent_home_screen.dart`
- Android manifest declaration:
  - `android/app/src/main/AndroidManifest.xml`
- Accessibility implementation:
  - `android/app/src/main/kotlin/com/guardian/guardian/GuardianAccessibilityService.kt`

## Suggested reviewer notes

Paste this into the Play Console reviewer notes if needed:

> The attached video shows the full in-app disclosure flow before permission grant, the Android system Accessibility enablement step for `Guardian payment protection`, return to the app with live protection enabled, and the post-setup `Privacy and permissions` entry point where the disclosure can be reviewed again.

## Upload checklist

- Upload the new `.aab`
- Upload or link the recorded permission video
- Use the declaration answers above
- Ensure the privacy policy URL shown in-app is live
- Double-check that the app content answers match the current UI labels, not the older README wording
