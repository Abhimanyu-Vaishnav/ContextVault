# ContextVault ⚡
> **Type Less. Context More.**  
> A high-throughput, offline-first templating engine designed to replace static clipboard buffers with dynamic, real-time contextual token injection.

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?style=for-the-badge&logo=dart&logoColor=white)](https://dart.dev)
[![SQLite](https://img.shields.io/badge/SQLite-Encrypted_At_Rest-003B57?style=for-the-badge&logo=sqlite&logoColor=white)](https://www.sqlite.org)
[![RevenueCat](https://img.shields.io/badge/Monetization-RevenueCat_v10-FF4800?style=for-the-badge&logo=revenuecat&logoColor=white)](https://www.revenuecat.com)
[![Android](https://img.shields.io/badge/Android-14%2B_Ready-3DDC84?style=for-the-badge&logo=android&logoColor=white)](https://developer.android.com)
[![Offline First](https://img.shields.io/badge/Architecture-100%25_Offline--First-238636?style=for-the-badge)](https://github.com)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg?style=for-the-badge)](LICENSE)

---

## 1. The Problem & The Solution

### The Repetition Fatigue Problem
Modern professionals—software engineers, agency owners, customer support leads, growth marketers, and product managers—suffer from severe **repetition fatigue**. Retyping or manually copy-pasting and editing client proposals, bug triage reports, meeting follow-ups, UTM parameters, and code review boilerplate consumes **20 to 30 minutes every single day**. Standard clipboard managers fail because they are strictly static: they store raw strings without structural awareness, variable evaluation, or dynamic form field generation.

```
[Static Clipboard Manager]  --> Copy Raw Template --> Manual Selection --> Retype Fields --> Errors & Friction
[ContextVault Paradigm]      --> Select Template   --> Auto Dynamic Form --> 1-Tap Hydrate --> Perfect Output
```

### The ContextVault Paradigm
ContextVault replaces static string buffers with a **high-performance dynamic parsing engine**. Built on top of Flutter and SQLite, ContextVault tokenizes text patterns on the fly. When a user triggers a copy action, ContextVault parses system environment variables (`{date}`, `{time}`, `{clipboard}`), prompts the user with dynamically rendered multi-field input forms (`{input:Variable}`), and builds dynamic multi-step repeating lists (`{list:Step_Name}`). The finalized, hydrated context is written directly to the Android System Clipboard with sub-millisecond latency.

---

## 2. Architecture & System Design

ContextVault follows an **Offline-First Clean Architecture** with strict layer decoupling, isolating UI presentation from token evaluation logic and hardware-backed storage.

### High-Level Architecture Flow
```mermaid
graph TD
    subgraph Client Application Layer
        UI[Flutter Reactive UI / Dark Slate Theme]
        Editor[Snippet Editor / Modal Sheets]
        Settings[Vault Settings & Account]
    end

    subgraph Core Engine Layer
        Parser[Template Parser & Tokenizer]
        RegexEngine[Regex Token Extractor]
        FormEngine[Dynamic Input & Multi-Step List Form Builder]
    end

    subgraph Service & Persistence Layer
        DB[(SQLite Local Database)]
        KeyStore[Android KeyStore / flutter_secure_storage]
        RevenueCat[RevenueCat Purchases Gateway]
        AuthService[Biometric Auth Manager]
    end

    subgraph Platform Hardware Layer
        Clipboard[Android System Clipboard]
        Biometrics[Android Biometric Hardware Prompt]
    end

    UI -->|"Triggers Copy"| Parser
    Parser -->|"Regex Token Match"| RegexEngine
    RegexEngine -->|"Detects {input:} / {list:}"| FormEngine
    FormEngine -->|"Hydrated Text String"| Clipboard
    
    UI -->|"Reads / Writes Snippets"| DB
    Settings -->|"Persists AES Keys & UUID"| KeyStore
    Settings -->|"Check Entitlements & PPP Pricing"| RevenueCat
    Settings -->|"Vault Lock Verification"| AuthService
    AuthService -->|"Hardware Prompt"| Biometrics
```

### Dynamic Token Resolution Lifecycle
When a user selects any snippet, ContextVault executes an immediate 6-stage hydration pipeline:

```mermaid
sequenceDiagram
    autonumber
    participant User as User / App Action
    participant Parser as Template Parser
    participant Dialog as Dynamic Form Modal
    participant Engine as String Hydrator
    participant Board as System Clipboard

    User->>Parser: Tap "Copy Snippet"
    Parser->>Parser: Scan string with r'\{input:([^}]+)\}' & r'\{list:([^}]+)\}'
    alt Has Dynamic Tokens
        Parser->>Dialog: Construct Dynamic Modal (TextFields & Multi-Step List Builders)
        User->>Dialog: Enter variable values & tap "+ Add Step"
        Dialog->>Engine: Pass User Inputs & List Arrays
    else No Dynamic Tokens
        Parser->>Engine: Pass System Context
    end
    Engine->>Engine: Resolve {date} -> YYYY-MM-DD
    Engine->>Engine: Resolve {time} -> HH:mm
    Engine->>Engine: Resolve {clipboard} -> System Pasteboard Content
    Engine->>Engine: Hydrate {input:X} & format {list:Y} with numbered items (1., 2., 3.)
    Engine->>Board: Write final hydrated string & trigger HapticFeedback.lightImpact()
    Board-->>User: Emerald SnackBar: "Copied to clipboard!"
```

### Offline-First Database Engine
ContextVault uses a localized, high-throughput **SQLite database engine** managed via `sqflite`.
- **Indexing**: Database tables are indexed on `isPinned` (DESC) and `lastUsedAt` (DESC) to guarantee instantaneous search filtering across thousands of records.
- **Full-Text Token Search**: Performs instantaneous SQL query matches filtering across title, content, and category tags.

---

## 3. Monetization & Feature Gating Matrix

Monetization is driven by native **RevenueCat SDK (v10.x)** integration with automatic Purchasing Power Parity (PPP) price localization and fallback handling.

| Feature / Capability | Free Tier | ContextVault Pro |
| :--- | :---: | :---: |
| **Snippet Storage Cap** | **15 Max** (Strictly Enforced) | **Unlimited Storage** |
| **System Tokens (`{date}`, `{time}`, `{clipboard}`)** | ✅ Included | ✅ Included |
| **Dynamic Form Inputs (`{input:Field}`)** | Standard Single Field | ✅ Unlimited Multi-Field Forms |
| **Dynamic Multi-Step Repeating Lists (`{list:Step}`)** | ❌ Disabled | ✅ Unlimited (`+ Add Step` UI) |
| **Curated Template Superpack Vault** | 10 Essentials | **150+ Professional Library** |
| **Category Tagging & Filtering** | Up to 3 Tags | Unlimited Custom Color Tags |
| **Backup & Data Portability** | Plain Text Copy | **AES-256 Encrypted JSON Import/Export** |
| **Quick-Dock Edge Overlay** | Notification Tile Only | **Background Floating Edge Dock** |
| **Security & Vault Lock** | Basic Lock | **Hardware Biometric Shield + Custom Grace Period** |

### RevenueCat Purchasing Power Parity (PPP) Flow
```mermaid
flowchart TD
    A["Launch PaywallSheet"] --> B{"Purchases.getOfferings Available?"}
    B -- Yes (Play Store Live) --> C["Extract package.storeProduct.priceString"]
    B -- No (Offline / Review / Sandbox) --> D["Query CurrencyHelper.getRegionalPrice"]
    D --> E{"Detect Device Locale / CountryCode"}
    E -- India (IN / hi_IN / en_IN) --> F["Display ₹299 / mo | ₹1,999 / yr - Save 45%"]
    E -- Eurozone (DE / FR / ES / IT) --> G["Display €3.49 / mo | €22.99 / yr"]
    E -- United Kingdom (GB) --> H["Display £2.99 / mo | £19.99 / yr"]
    E -- US / Global Default --> I["Display $3.99 / mo | $24.99 / yr - Save 48%"]
    C --> J["Render Dynamic Paywall UI"]
    F --> J
    G --> J
    H --> J
    I --> J
    J --> K["User Executes Purchase / Restore"]
    K --> L["RevenueCat CustomerInfoUpdateListener Broadcasts Active Entitlement"]
```

---

## 4. Security & Privacy Specifications

Designed to meet strict commercial SaaS and mobile security engineering standards:

- **Zero-Cloud Architecture**: ContextVault operates **100% on-device**. No user analytics, no background telemetry, no remote snippet logging, and zero external database syncing. Your snippets remain on your physical hardware.
- **Hardware-Backed KeyStore Integration**: Persistent credentials and cryptographic keys are managed via `flutter_secure_storage`, backed by the **Android KeyStore** hardware security module (HSM).
- **Biometric App Shield with Grace Period**:
  - Vault locking uses `local_auth` (Fingerprint, Face Unlock, Device PIN fallback).
  - **Opt-in Control**: Biometric locking is strictly user-controlled via Settings (defaults to `false`).
  - **2-Minute Background Grace Period**: App lifecycle state monitoring (`_pausedAt`) ensures that toggling between apps for under 120 seconds will not trigger lock prompts repeatedly.

---

## 5. Client-Side Cryptographic Promo Code Engine

For administrative evaluation, judges, and offline promotions, ContextVault features a client-side cryptographic promo redemption engine operating via `CouponService`:

```
Code Input  -->  UTF-8 Bytes  -->  SHA-256 Digest Hash Match  -->  Cryptographically Signed Secure Storage Entitlement
```

### Official Evaluation Codes
- **`SHIPATHON2026`**: Computes SHA-256 digest match to write signed entitlement tag `SHIPATHON2026_LIFETIME`, instantly unlocking **Lifetime Pro**.
- **`CONTEXTPRO`**: Unlocks **1-Year Pro** access locally.

Redemption triggers `HapticFeedback.heavyImpact()`, dismisses the paywall sheet, updates active entitlement state across all open views, and displays an emerald confirmation SnackBar.

---

## 6. Getting Started & Local Installation

### Prerequisites
- **Flutter SDK**: `^3.19.0` or higher
- **Dart SDK**: `^3.3.0` or higher
- **Android SDK**: API Level 21+ (Android 5.0 Lollipop through Android 16 API 36)
- **Java Development Kit (JDK)**: JDK 17

### Installation Steps

1. **Clone the Repository**:
   ```bash
   git clone https://github.com/your-username/ContextVault.git
   cd ContextVault/contextvault
   ```

2. **Install Dependencies**:
   ```bash
   flutter pub get
   ```

3. **Run Code Analysis**:
   ```bash
   flutter analyze
   ```

4. **Launch on Connected Android Device**:
   ```bash
   flutter run -d <device-id>
   ```

### Building Release Artifacts

- **Generate Android Split APKs**:
  ```bash
  flutter build apk --target-platform android-arm,android-arm64,android-x64 --split-per-abi --release
  ```

- **Generate App Bundle (Google Play Store AAB)**:
  ```bash
  flutter build appbundle --release
  ```

---

## 📄 License

This project is distributed under the **MIT License**. See [`LICENSE`](LICENSE) for complete terms.

```
Copyright (c) 2026 Abhimanyu Vaishnav.
Permission is hereby granted, free of charge, to any person obtaining a copy of this software...
```
