# OnPurpose

A joke chain-text app. You "purpose" your friends on a schedule, and they're supposed to purpose you back:

> 🚨 YOU GOT PURPOSED 🚨
>
> Nick wants you to have a good day on purpose ✋
>
> Purpose them back within 3 hr or face mild consequences.
>
> Purpose back 👉 https://nicholascirigliano.github.io/onpurpose/?p=…

The "have a good day" part is swappable (touch grass, eat a vegetable, parallel park flawlessly…) or write your own.

## How it works

1. **You send it from your own phone.** The app creates the purpose in Firebase, then opens Messages with the text and link filled in.
2. **They tap the link.** A web page (`docs/`, on GitHub Pages) shows the purpose and a **Purpose back** button. No app or account needed.
3. **You find out.** The app listens to Firebase and moves them to "They purposed you back".
4. **They're late?** Hit **Nag** for a "🚨 FINAL NOTICE" text with the same link.

## What's in here

| Path | What |
| --- | --- |
| `OnPurpose/`, `OnPurpose.xcodeproj` | SwiftUI iPhone app (iOS 17+). `Cloud.swift` is the Firebase part. |
| `docs/index.html` | The page the link opens. Plain HTML; Firebase loads from Google's CDN. |
| `firestore.rules` | Who can do what in the database. |
| `firebase-tests/` | Tests for the rules. |

Data lives in one Firestore collection, `purposes`. The random document id is the secret in the link: anyone with a link can read that one purpose and purpose back once, only the app can create purposes, and nobody can list other people's.
`GoogleService-Info.plist` and the web config are safe to publish; the rules are what protect the data.

## Local development

Everything runs against Firebase's emulator, so nothing touches the real database:

```bash
firebase emulators:start --only auth,firestore
```
```bash
python3 -m http.server 5050 --bind 127.0.0.1 --directory docs
```

Then run the app with the `-useEmulator` launch argument (Xcode: Product → Scheme → Edit Scheme → Run → Arguments). Links point at `http://localhost:5050/` instead of GitHub Pages.

Rules tests:

```bash
(cd firebase-tests && npm install) && firebase emulators:exec --only firestore "npm --prefix firebase-tests test"
```

## Going live

1. Firebase console: Authentication → turn on **Anonymous**; create the **Firestore** database (production mode).
2. Deploy the rules: `firebase deploy --only firestore:rules`
3. GitHub → repo Settings → Pages → Deploy from branch → `main`, folder `/docs`.
4. In Xcode, pick your team under Signing & Capabilities and run on your iPhone.

Everything above stays on free plans (Firebase Spark, GitHub Pages on a public repo).
