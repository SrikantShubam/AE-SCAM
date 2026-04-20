# Guardian Onboarding Flow & Home Pages

## Revised Onboarding Architecture

### Flow Overview

```
Welcome
  ↓
Consent (DPDPA Privacy)
  ↓
Role Select (Child / Parent)
  ├→ Parent selected
  │   ↓
  │   Parent Disclosure (Accessibility - parent-optimized)
  │   ↓
  │   First Payment Check
  │   ↓
  │   Parent Home Screen
  │
  └→ Child selected
      ↓
      Child Disclosure (Accessibility - technical)
      ↓
      First Payment Check
      ↓
      Child Home Screen
```

## Key Improvements

### 1. Welcome Screen (`welcome_screen.dart`)
- **Purpose:** Introduces Guardian warmly
- **Features:**
  - Feature highlights (medication, payment protection, alerts, health)
  - Large, welcoming typography
  - Clear CTA to get started
  - Sets expectation before privacy/consent

### 2. Consent Screen (existing)
- **Step 1 of 4**
- **Purpose:** DPDPA privacy and data collection consent
- **No changes** to existing flow

### 3. Role Select Screen (improved)
- **Step 2 of 4** (moved earlier than accessibility)
- **Purpose:** Determine if device is for parent or child
- **Improvement:** Now routes to role-specific disclosure screens

### 4. Role-Specific Disclosure

#### Parent Disclosure (`parent_disclosure_screen.dart`)
- **Step 3 of 4**
- **Optimized for elderly parents:**
  - Larger text (18px+ throughout)
  - Simple, reassuring language
  - "What we'll do with this" (not technical)
  - "You stay in control" reassurance
  - Simple 3-step process instead of long explanations
  - Focus on protection benefit, not technical capability

#### Child Disclosure (existing `disclosure_screen.dart`)
- **Step 3 of 4** (if child role selected)
- **Optimized for adult children:**
  - More detailed technical explanation
  - Family alert escalation context
  - Privacy and legal boundaries

### 5. First Payment Check (`first_payment_check_screen.dart`)
- **Step 4 of 4**
- **Purpose:** Validate that accessibility is working
- **Improvement:** Now routes to role-specific home screens

## Home Screen Architecture

### Parent Home Screen (`parent_home_screen.dart`)
- **Audience:** Elderly users
- **Design principles:**
  - Large text (body: 18px, headlines: 24-30px)
  - Minimal cognitive load
  - Clear status indicators
  - Simple action buttons
  
- **Key sections:**
  1. **Payment Safety Header** - gradient card with main message
  2. **Status Card** - large, color-coded status ("Not on", "Ready", "Warning", "Stop")
  3. **Actions** - based on current status
     - If inactive: "Turn on Guardian" button
     - If active: "What to watch for" checklist (3 simple items)
  4. **Help Section** - link access to FAQ, privacy, settings

- **Colors:** Warm, accessible palette with clear status signals
- **Spacing:** Generous padding, large touch targets (56px+ buttons)

### Child Home Screen (`child_home_screen.dart`)
- **Audience:** Adult children / caregivers
- **Design principles:**
  - Dashboard overview of parent's protection
  - Alert and activity visibility
  - Quick stats and family setup
  
- **Key sections:**
  1. **Parent Status Overview** - quick health check
  2. **Recent Activity** - alerts, warnings, pauses
  3. **This Week Stats** - transactions, warnings, protection percentage
  4. **Family Setup** - manage connected parents

- **Color:** Data-forward, professional palette
- **Spacing:** Standard Material Design (18px body text)

## Routing Logic

### After Onboarding Complete

```
User stored role in SharedPreferences
  ↓
Next app open → Router checks user_role
  ├→ 'parent' → /home/parent
  └→ 'child' → /home/child
```

### Backward Compatibility

- Old `/protection` route still exists (shows generic ProtectionHomeScreen)
- Can be deprecated after role-based screens are validated

## File Structure

```
lib/features/
├── onboarding/screens/
│   ├── welcome_screen.dart (NEW)
│   ├── consent_screen.dart (existing)
│   ├── role_select_screen.dart (updated)
│   ├── parent_disclosure_screen.dart (NEW)
│   ├── disclosure_screen.dart (existing, for child)
│   └── first_payment_check_screen.dart (updated)
│
└── protection/screens/
    ├── parent_home_screen.dart (NEW)
    ├── child_home_screen.dart (NEW)
    └── protection_home_screen.dart (existing, generic)
```

## Accessibility Permissions Flow - Seamless Integration

The key improvement is **moving accessibility disclosure after role selection**:

1. Parent doesn't need to understand technical "Accessibility Service" language upfront
2. Disclosure matches the user's context (parent vs child)
3. Parent sees "Guardian needs one permission" with simple explanation
4. First-time flow feels coherent: Welcome → Privacy → Who are you → What we need → Test it → Use it

## Design References

All component implementations follow patterns from the **21st.dev premium UI library**:
- Alert badges and status indicators (parent/child status cards)
- Dashboard metric cards with trend indicators (child home screen)
- Permission request pattern (accessibility disclosure)
- Animated onboarding and welcome screens

See `docs/21ST_DEV_REFERENCE.md` for the complete 21st.dev pattern catalog and recommendations for future phases.

## Future Enhancements

- [ ] Toast notifications (Alert component from 21st.dev)
- [ ] Admonition callouts for educational content
- [ ] Analytics: Track where users drop off in onboarding
- [ ] Skip capability for accessibility (allow non-interruption mode)
- [ ] Reconnect flow for returning users
- [ ] Parent-side data display in child dashboard
- [ ] Notification bridging between devices
- [ ] Timer display for payment cooldown (21st.dev pattern)
- [ ] Profile selector for multiple parents (Phase 2 feature)
