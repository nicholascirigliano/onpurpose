# OnPurpose

A joke chain-text app. You "purpose" your friends on a schedule, and they're supposed to purpose you back:

> 🚨 YOU GOT PURPOSED 🚨
>
> Nick wants you to have a good day on purpose ✋
>
> Purpose them back within 3 hr or face mild consequences.

The "have a good day" part is swappable (touch grass, eat a vegetable, parallel park flawlessly…) or write your own.
Set your name with the ✍️ button on the Today tab.

## What works now (iPhone, no server)

- **People**: add someone with a name, phone number and emoji.
- **Schedules**: pick a phrase (or write your own), set it to Once, Daily, Weekdays or Weekly, and choose a time.
  When it's time, you get a notification. Tap it and the Messages composer opens with the text filled in.
- **Reply reminder**: each schedule sets how long the recipient has to reply before they're nudged.
- **Inbox**: messages sent to you. If you don't reply in time, you get a "you haven't replied" notification.
  Until there's a backend, the ✨ menu in the Inbox fakes an incoming message (reminder after 1 minute).
- **Today**: what's ready to send, what's coming up, and who hasn't replied yet.

Data is saved on the device (`Documents/onpurpose.json`).

## Run it

Open `OnPurpose.xcodeproj` in Xcode and run on a simulator or your iPhone.
Texting only works on a real phone; the simulator logs the message as sent instead.

## What needs a backend

iOS doesn't let apps send texts without you tapping Send, and an app can't nudge someone who doesn't have it.
For fully automatic sending and for nudging the recipient, both people need the app plus a server
(for example Firebase or CloudKit): accounts, messages delivered in the app, and push notifications for reply reminders.
`Store.receiveSample` and `Store.recordSend` are where that service would connect.
