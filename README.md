<p align="center">
  <img src="RoomHub/Assets.xcassets/logopng.imageset/logopng.png" height="90" alt="RoomHub logo">
</p>

<h1 align="center">RoomHub</h1>
<p align="center"><b>Shared living, simplified.</b><br>
Split expenses, settle up and keep chores on track — together with your roommates.</p>

<p align="center">
  <img src="https://img.shields.io/badge/iOS-17%2B-black?logo=apple" alt="iOS 17+">
  <img src="https://img.shields.io/badge/Swift-5-orange?logo=swift" alt="Swift">
  <img src="https://img.shields.io/badge/SwiftUI-blue" alt="SwiftUI">
  <img src="https://img.shields.io/badge/Firebase-Auth%20%7C%20Firestore-FFCA28?logo=firebase" alt="Firebase">
</p>

---

## Features

**Expenses**
- Log shared expenses in 50+ currencies, with category, date and who paid
- Split **equally** (cent-exact rounding) or by **exact amounts**
- Monthly overview, per-category and per-roommate insights with a donut chart
- Each expense stores the exchange rate at the time it was added, so balances don't drift when rates change

**Settle up**
- Automatic debt simplification — the fewest payments needed to settle the whole house
- Record full or partial payments, see payment history and undo mistakes

**Chores**
- Assign chores to one or more roommates, with daily / weekly / monthly repeats
- The next occurrence is created automatically when a chore is completed
- Overdue and due-today highlighting, quick-add presets

**House**
- Create a house or join with a 6-character invite code (share sheet, regenerate code)
- Roles: owner, admins, members — transfer ownership, remove members
- Live sync for everyone via Firestore listeners

**Account**
- Email / password auth, password reset, email verification, change password
- Profile photo, in-app account deletion and privacy policy (App Store requirements)

## Tech stack

| Area | Choice |
|---|---|
| UI | SwiftUI (iOS 17+), MVVM |
| Backend | Firebase Authentication, Cloud Firestore (free Spark plan) |
| State | `ObservableObject` stores with live Firestore snapshot listeners |
| Exchange rates | [open.er-api.com](https://open.er-api.com) (free, no API key), cached on device |
| Security | Firestore Security Rules with role and field validation ([`firestore.rules`](firestore.rules)) |

## Architecture

```
RoomHub/
├── Models/          Codable models (Expense, Settlement, Chore, House, AppUser, Currency)
├── Services/        FirebaseService, ExchangeRateService, ImageProcessor, FriendlyError, toasts
├── ViewModels/
│   ├── AuthViewModel    Auth state + live user document
│   ├── HouseStore       Single source of truth for one house (members, expenses,
│   │                    settlements, chores) shared by all tabs
│   ├── HouseViewModel   Create / join house (atomic batched writes)
│   └── DebtCalculator   Pure functions: debt simplification, cent-exact splitting
└── Views/           SwiftUI screens and reusable components
```

**Data model (Firestore)**

```
users/{uid}
invites/{code}                       → { houseId }   (get-only, cannot be listed)
houses/{houseId}                     → members, admins, owner, base currency
houses/{houseId}/expenses/{id}
houses/{houseId}/settlements/{id}
houses/{houseId}/chores/{id}
```

Some design decisions:
- **Security rules first.** Only house members can read or write a house's data. Joining requires the current invite code, members can't promote themselves, and only the owner can transfer ownership.
- **Money is stored in the house currency.** Expenses in other currencies keep the converted amount from the moment they were added.
- **No paid services.** Photos are resized to small JPEGs and stored in Firestore instead of Cloud Storage, which requires a paid plan.

## Getting started

1. Clone the repo and open `RoomHub.xcodeproj` in Xcode 26+.
2. Create a Firebase project, add an iOS app with your bundle ID and download `GoogleService-Info.plist` into the `RoomHub/` folder. Use `GoogleService-Info.example.plist` as a reference for the format.
3. In Firebase: enable **Authentication → Email/Password** and create a **Cloud Firestore** database.
4. Paste the contents of [`firestore.rules`](firestore.rules) into **Firestore → Rules** and publish.
5. Build and run (⌘R).

## Screenshots

_Coming soon._

## Privacy

See the [privacy policy](docs/privacy.html).

## Author

**Fatih Emre Derici**, Software Developer based in Łódź, Poland · [LinkedIn](https://www.linkedin.com/in/fatihemrederici)

© 2026 Fatih Emre Derici. All rights reserved.
