# Loota Mobile: Application Design & Visual Specification

## 1. App Purpose
**Loota Mobile** is a high-fidelity, iOS-native Augmented Reality (AR) treasure hunting platform. It transforms the physical world into a digital playground where users discover, track, and "summon" virtual assets (Loot) to earn real-world rewards. The app bridges the gap between digital gaming and physical exploration through precise geolocation and proximity-based mechanics.

---

## 2. Visual Identity & Design Language
The app employs a **"Futuristic Glassmorphic HUD"** aesthetic. It combines the sleekness of modern iOS design (translucency and blur) with the high-energy visuals of a sci-fi interface (neon glows and tactical overlays).

### Core Style Elements:
*   **Glassmorphism:** Heavy use of `.ultraThinMaterial` with multi-layered specular highlights and subtle inner borders to create a "frosted glass" look.
*   **Neon & Glow:** Critical UI elements (buttons, scores, focus targets) emit soft, atmospheric glows using a "bloom" effect.
*   **Tactical HUD:** The interface is designed to feel like a high-tech scanner or "treasure-hunting visor."
*   **Typography:** Rounded, heavy sans-serif fonts (System Rounded) for a friendly yet high-tech feel.
*   **Color Palette:**
    *   **Cosmic Purple:** `#3F77B9` (Primary Brand)
    *   **Neon Cyan:** `#44B5C9` (Action/Tracking)
    *   **Golden Highlight:** `#FAD07E` (Loot/Rewards)
    *   **Dark Slate:** `#1A293D` (Primary Text)

---

## 3. Core Visual Functions & Screens

### A. The AR Exploration View (Primary Interface)
The main screen is a full-screen AR camera feed with a non-intrusive tactical overlay.
*   **3D Loot Entities:** Custom USDZ models (Golden Coins, Gift Cards) that feature:
    *   **Idle Animation:** Continuous gentle bobbing (y-axis) and smooth spinning.
    *   **Billboard Labels:** Floating text labels above objects that always face the user, showing "Marker #[ID]" and distance in feet.
    *   **Focus Halo:** A pulsing glow appears around an object when it enters the center of the user's "field of view."
*   **Spatial Horizon Line:** A semi-transparent, thin cyan line at the absolute 0-latitude/horizon to provide spatial orientation.

### B. The Navigation HUD (Upper/Lower Overlays)
*   **Loot Progress Card (Top Left):** A glassmorphic pill showing:
    *   An animated, glowing loot icon (e.g., a spinning gold coin).
    *   "Collected" vs. "Remaining" counts.
    *   **Feedback:** When loot is collected, the "Collected" number pulses and scales with a spring animation.
*   **3D Compass HUD (Bottom Center):** A sophisticated navigation tool:
    *   **Base:** A flattened, glowing elliptical HUD projected at the bottom of the screen.
    *   **The Arrow:** A 3D-shaded, dual-tone arrow (Cyan/Purple) that rotates in real-time to point toward the nearest loot.
    *   **Nearest Loot Label:** A small floating pill above the compass showing the distance to the closest target.
*   **Summoning Interface (Contextual):** Appears when an object is within "Focus Range" (20ft).
    *   **The Summon Button:** A large circular button with a "Magic Wand" icon. It features a heavy outer glow and a gradient fill.
    *   **Edge Glow:** The entire screen border pulses with a neon gradient (Cyan to Purple) when the user is in a state where they can "Summon" loot.

### C. Interaction & Feedback Systems
*   **Hand Gesture Recognition:** The app detects the user's hand pose via the camera. When a hand is detected, "Summoning" logic is triggered.
*   **Summoning Animation:** When triggered (via button or gesture), the virtual loot physically detaches from its coordinates and "flies" toward the user's screen over a 10-second staged animation, scaling up as it arrives.
*   **Collection Burst:** Upon collection, the 3D model disappears with a visual "pop" and a golden flash, accompanied by a "Coin Punch" sound effect.

### D. User Flow Modals
*   **Splash Screen:** A high-contrast introduction with a pulsating logo and a deep gradient background.
*   **Hunt Join Confirmation:** A centered, glassmorphic card that appears over the AR feed. It includes:
    *   Hunt title and description.
    *   Skeuomorphic "Inset" text fields for name and phone number.
    *   A prominent "Confirm" button with a heavy drop shadow.
*   **Hunt Completion (Victory Screen):** A celebratory full-screen overlay:
    *   Animated "Confetti" or sparkle effects.
    *   Large 3D Trophy icon.
    *   Winner summary (Time taken, Loot collected).
    *   Actionable contact chips (Call/Text/Email) for claiming prizes.

---

## 4. Technical Visual Data (For Implementation)
*   **AR Alignment:** Gravity and Heading (Magnetic North).
*   **Distance Units:** Feet (converted from meters).
*   **UI Hierarchy:**
    1.  AR View (Background)
    2.  3D Entities & Billboards
    3.  HUD Overlays (Top/Bottom)
    4.  Interaction Glows (Screen Space)
    5.  Modals/Popups (Foreground)
