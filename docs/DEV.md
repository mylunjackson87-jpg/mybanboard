# Sync Verification (SwiftData + CloudKit)

## Required Setup

1. Use a paid Apple Developer team for signing.
2. In Apple Developer portal, ensure:
   - App ID `MYJ.MyBanBoard` has iCloud capability enabled.
   - CloudKit container `iCloud.MYJ.MyBanBoard` exists.
3. In Xcode Signing & Capabilities for `MyBanBoard`:
   - iCloud capability is enabled.
   - CloudKit is selected.
   - Container `iCloud.MYJ.MyBanBoard` is attached.
4. Sign in to the same iCloud account on both test devices (Mac + iPad).
5. Build and run from branch with Task 2.2+ changes.

## How To Test Sync

1. Launch app on Mac.
2. Create a new board from sidebar `+`.
3. Open the board and add one card and one column.
4. Wait 5-30 seconds.
5. Launch app on iPad with the same iCloud account.
6. Confirm board, card, and column appear automatically.
7. Edit board title on iPad.
8. Wait 5-30 seconds and confirm title updates on Mac.
9. Delete card on Mac and confirm deletion appears on iPad.

Expected result:
- No manual refresh required.
- Same entities update (no duplicate records).

## What To Check In Logs

- Save operations should log via `Persistence` category.
- If CloudKit setup is invalid, startup logs show fallback to local store:
  - `CloudKit model container init failed... Falling back to local store.`

## Simulator / Local Limitations

1. Personal Team signing does not support iCloud capability provisioning for macOS.
2. Simulator tests may be less reliable for CloudKit timing and background delivery.
3. First sync can be delayed after app reinstall or simulator reset.
4. If CloudKit is unavailable/misconfigured, app intentionally falls back to local storage to avoid crash.
