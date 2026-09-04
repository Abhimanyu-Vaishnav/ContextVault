# ContextVault ⚡
> **Type Less. Context More.**  
> A commercial-grade, offline-first productivity snippet vault built with Flutter, SQLite, and RevenueCat.

![Flutter](https://img.shields.io/badge/Flutter-3.12+-02569B?logo=flutter)
![RevenueCat](https://img.shields.io/badge/Monetization-RevenueCat-FF4800)
![Database](https://img.shields.io/badge/Database-SQLite%20(AES--256)-003B57)
![Security](https://img.shields.io/badge/Security-Android%20KeyStore-3DDC84)

---

## 🚀 What Problem Does ContextVault Solve?

Modern professionals (developers, agency founders, support teams, growth marketers) waste **hundreds of hours each year** retyping the same client proposals, bug reports, UTM links, and meeting notes.

ContextVault turns static snippets into **smart, interactive context templates**.

### 🌟 Key Features
- ⚡ **Dynamic Forms Engine (`{input:Name}`)**: Fill multi-field prompts on the fly with real-time live preview before copying.
- 📋 **Multi-Step Repeating Lists (`{list:Steps}`)**: Expandable dynamic list blocks with 1-tap `+ Add Step` UI.
- 🕒 **System Tokens**: Auto-evaluates `{date}`, `{time}`, and `{clipboard}`.
- 🔒 **Hardware-Backed AES-256 Storage**: Master encryption key stored safely inside the Android KeyStore.
- 📱 **Floating Edge Quick-Access**: Persistent Android notification bar for instant snippet searching and copying over any app.
- 📚 **150+ Curated Template Vault**: Pre-built starter superpacks for Developers, Freelancers, Support, and Founders.
- 💳 **RevenueCat Subscriptions**: Dynamic paywalls, localized store currencies, and entitlement gating.

---

## 🛠️ Tech Stack & Architecture

- **Core**: Flutter / Dart
- **Database**: SQLite (`sqflite`) + Hardware-Backed `flutter_secure_storage` KeyStore
- **Monetization**: RevenueCat SDK (`purchases_flutter` 10.x) with strict cryptographic signature verification
- **Biometrics**: `local_auth` (Fingerprint, Face ID, Device PIN)
- **State & Theme**: Dark Slate Aesthetic (`#0D1117`, `#161B22`, `#30363D`, `#58A6FF`)

---

## 🛠️ RevenueCat Shipathon Judge & Sandbox Override

For evaluation during the **RevenueCat Shipathon**, ContextVault includes a built-in **Judge Sandbox Override**:

1. Open the app and tap the **Pro Bolt Icon** (⚡) in the top right of the AppBar.
2. In `PaywallSheet`, **double-tap the "ContextVault Pro" title** OR tap **"🛠️ Judge / Demo Mode Sandbox Unlock"** in the footer.
3. This activates **Judge Mode (Pro Status ACTIVE)** instantly with persistent `SharedPreferences` state, unlocking unlimited snippet storage, 150+ templates, and AES-256 backup exports.

---

## 🎬 60-Second Video Demo Script

| Timestamp | Screen / Visual | Voiceover / Script |
| :--- | :--- | :--- |
| **0:00 - 0:15** | Typing a long email manually on Android device | "Ever get tired of retyping the exact same client proposals, bug reports, and invoice notes every single day?" |
| **0:15 - 0:35** | Tapping "Quick Client Proposal" in ContextVault, filling dynamic inputs `{input:ClientName}`, `{input:ProjectScope}`, adding steps in `{list:Steps}`, live output updates | "With ContextVault, tap any snippet. Our Dynamic Input Engine automatically builds forms and dynamic numbered lists, rendering final text in real time with haptic feedback!" |
| **0:35 - 0:50** | Reaching 15 snippets -> `PaywallSheet` pops up with RevenueCat comparison table | "Free users get 15 snippets. Upgrading to ContextVault Pro via RevenueCat unlocks unlimited storage, 150+ curated templates, and encrypted backups." |
| **0:50 - 1:00** | One-tap paste into Gmail/Slack | "Copy rendered context in one tap, and paste anywhere. ContextVault — Type Less. Context More." |

---

## 🛡️ License
Copyright © 2026 Abhimanyu Vaishnav. All rights reserved.
