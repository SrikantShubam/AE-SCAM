# 21st.dev Component Library Reference

This document catalogs premium UI components from 21st.dev that have been evaluated for Guardian. Some are implemented, others are listed as references for future phases.

## ✅ Implemented from 21st.dev

### 1. **Alert Badge Pattern** (Status Indicators)
- **Location:** `child_home_screen.dart`, `parent_home_screen.dart`
- **Implementation:** Color-coded alert badges (Amber, Red, etc.)
- **Pattern Details:**
  - Inline colored badges with foreground/background contrast
  - Used for quick status indication (warning level, alert type)
  - Responsive to different severity levels

### 2. **Dashboard Metric Cards** (with Trends)
- **Location:** `child_home_screen.dart` (_StatCard widget)
- **Implementation:** Icon + Value + Label + Trend indicator
- **Features:**
  - Colored icon containers
  - Trend direction (up/down/neutral) with directional icons
  - Support for percentage/absolute values
  - Compact and accessible layout

### 3. **Status Card with Badge**
- **Location:** `parent_home_screen.dart` (_StatusCard widget)
- **Implementation:** Larger status indicator with inline badge
- **Features:**
  - Large icon + title + subtitle
  - Status badge (Off/Monitoring/Amber review/Red stop)
  - Color-coded background per status

---

## 📚 Not Yet Implemented (Reference for Future Phases)

### Navigation & Layout

#### **Circular/Vertical Navbar**
- **21st.dev Component:** Navbars (Circular Menu variant)
- **Use Case:** Bottom navigation for mobile Guardian (parent device)
- **Key Features:**
  - Icon buttons in circular container
  - Active state highlighting
  - Accessibility support with sr-only labels
- **When to Use:** If adding bottom navigation to parent home screen
- **Reference:** 21st.dev Navbars > Circular Navbar pattern

---

### Onboarding & Setup

#### **Onboarding Checklist with Video**
- **21st.dev Component:** Onboarding Checklist
- **Use Case:** Could enhance welcome_screen.dart or first_payment_check_screen.dart
- **Key Features:**
  - Animated checklist items with checkmarks
  - Video thumbnail with play overlay
  - Helper text and links for each item
  - Two-column layout (checklist + video)
- **Adaptation:** Would work well for medication setup or device setup checklists
- **Reference:** 21st.dev > Onboarding Checklist

#### **Animated Welcome Screen with Hero**
- **21st.dev Component:** Welcome Screen
- **Use Case:** Enhanced welcome_screen.dart with animated image
- **Key Features:**
  - Hero image with ellipse clip-path effect
  - Staggered animation for title/description
  - Spring animation for buttons
  - Framer Motion animations
- **Current Status:** welcome_screen.dart has simpler implementation; could be enhanced
- **Reference:** 21st.dev > Onboarding / Welcome Screen

#### **Permission Request Card (Camera/Accessibility)**
- **21st.dev Component:** Camera Permission Request Card
- **Use Case:** Parent disclosure screen for accessibility permissions
- **Key Features:**
  - App icon + title + description
  - Mock iOS/Android notification preview
  - Step-by-step guide in accordion
  - "Didn't get notification?" fallback button
- **Current Status:** parent_disclosure_screen.dart has simpler version
- **Adaptation:** Excellent pattern for accessibility permission request on parent device
- **Reference:** 21st.dev > Camera Permission Request Card

---

### Forms & Input

#### **Role Selection with Dropdown**
- **21st.dev Component:** Login & Signup (with role selector)
- **Use Case:** role_select_screen.dart already implemented differently
- **Key Features:**
  - Select menu with icons + labels
  - Grid or dropdown options
  - Form validation patterns
- **Current Status:** Already have LargeActionCard pattern (better for elderly)
- **Reference:** 21st.dev > Login & Signup

---

### Alerts & Notifications

#### **Alert Component (Success/Warning/Info/Error)**
- **21st.dev Component:** Alert
- **Use Case:** Notification system in both parent and child homes
- **Key Features:**
  - 5 variants: success, warning, info, error, default
  - Icon + title + description
  - Dismissible with animation
  - Dark mode support
  - Framer Motion for entrance/exit
- **When to Use:** Toast notifications, in-page alerts
- **Reference:** 21st.dev > Alert

#### **Admonition / Callout Boxes**
- **21st.dev Component:** Admonition
- **Use Case:** Educational callouts in onboarding or help screens
- **Key Features:**
  - 7 variants: note, tip, info, warning, success, caution, danger
  - Icon + title + content
  - Color-coded (blue, green, amber, red, etc.)
- **When to Use:** "Did you know?" sections, important notices
- **Reference:** 21st.dev > Admonition

#### **Toast Notification / Success Notification**
- **21st.dev Component:** Success Toast Notification
- **Use Case:** Feedback when user completes actions
- **Key Features:**
  - Icon + headline + description
  - Inline action buttons
  - Dismissible with close button
- **Reference:** 21st.dev > Success Toast Notification

---

### Status & Monitoring

#### **Dashboard Overview with Metric Cards**
- **21st.dev Component:** Dashboard Overview
- **Use Case:** Child home screen could be enhanced
- **Key Features:**
  - Responsive grid of metric cards
  - Trend indicators (up/down/neutral)
  - Color-coded trends (green/red/gray)
  - Icon + value + trend + change percentage
  - Smooth animations
- **Current Status:** _StatCard in child_home_screen.dart is simpler version
- **Enhancement Potential:** Add percentage change, smooth animations
- **Reference:** 21st.dev > Dashboard Overview

#### **Timer / Countdown Display**
- **21st.dev Component:** Countdown Timer (Large Display variant)
- **Use Case:** Medication reminders countdown, payment confirmation cooldown display
- **Key Features:**
  - Large monospace digits (HH:MM:SS)
  - Play/Pause/Reset controls
  - Animated counter
- **When to Use:** Medication time remaining, red-stop cooldown countdown
- **Reference:** 21st.dev > Countdown Timer

---

### Profile & Selection

#### **Profile Selector / Avatar Selector**
- **21st.dev Component:** Select (Profile Selector variant)
- **Use Case:** Multiple parent management in child dashboard (Premium feature)
- **Key Features:**
  - Avatar + name + email + role display
  - Dropdown with search
  - Grouped items
  - Active state highlighting
- **When to Use:** If implementing 1 child : 2+ elders feature
- **Reference:** 21st.dev > Select (Profile Selector)

---

### Advanced Patterns

#### **Cookies/Privacy Notice**
- **21st.dev Component:** Cookies / Privacy Notice
- **Use Case:** Could enhance DPDPA consent screen
- **Key Features:**
  - Centered card with icon
  - Heading + description + links
  - Accept/Decline buttons
  - Modal pattern
- **Current Status:** consent_screen.dart has different approach (inline checklist)
- **Reference:** 21st.dev > Cookies

#### **Select Menu with Search**
- **21st.dev Component:** Select Menu (with search)
- **Use Case:** Payment app filtering, recipient selection in future features
- **Key Features:**
  - Searchable dropdown
  - Item groups
  - Icons in menu items
  - Active state indicator
- **Reference:** 21st.dev > Select Menu

---

## Implementation Strategy

### Phase 0 (Current)
- ✅ Alert badges (done)
- ✅ Dashboard metric cards with trends (done)
- ✅ Status cards with badges (done)

### Phase 1 (Next)
- [ ] Toast notifications (Alert component)
- [ ] Admonition callouts for help sections
- [ ] Enhanced animation on welcome screen
- [ ] Permission request card styling improvements

### Phase 2 (Premium Features)
- [ ] Timer for payment cooldown display
- [ ] Profile selector for multiple parents
- [ ] Circular navbar if adding bottom navigation
- [ ] Advanced dashboard with more metrics

### Phase 3+ (Long-term)
- [ ] Onboarding video integration
- [ ] Advanced form patterns
- [ ] Accessibility statement callouts

---

## Design Consistency

When implementing additional 21st.dev components, maintain:

1. **Color Palette:** Use Guardian's teal primary (#156B7A) as seed
2. **Typography:** 18px body text (parent device), 14-16px for child device
3. **Spacing:** Material 3 spacing units (8px base)
4. **Roundness:** 18-24px border radius (already in app_theme.dart)
5. **Icons:** Lucide icons (used in 21st.dev patterns)
6. **Animations:** Subtle, accessibility-friendly (no excessive motion)

---

## References & Links

- **21st.dev Library:** Available through MCP `mcp__magic__21st_magic_component_inspiration`
- **Component Categories:**
  - Onboarding: Welcome, Checklist, Permission requests
  - Forms: Selects, Inputs, Role selection
  - Alerts: Toast, Alert, Admonition, Badge
  - Dashboard: Metric cards, Status indicators, Charts
  - Navigation: Navbar, Menu, Profile selector
  - Premium: Animations, Advanced patterns

## Notes for Future Development

- Most 21st.dev patterns are React/Tailwind; conversions to Flutter maintain the core UX principles
- Animations should be tested for accessibility (prefers-reduced-motion equivalent)
- Large text (18px+) for parent device is non-negotiable for accessibility
- Color contrast ratios must meet WCAG AA minimum
- Focus states and keyboard navigation are critical for elderly users
