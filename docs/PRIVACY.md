# Mileage personal-beta privacy

Mileage stores trip start/end times, category, purpose, notes, GPS samples and accuracy, measured and corrected distances, and recording/review issues on your iPhone. It does not require an account or operate a cloud backend. There are no advertising, analytics or third-party SDKs in this version.

Location is requested when you start a trip. Mileage uses Apple's background-location mode to continue that explicitly started trip while locked or while you use another app. Recording stops when you finish the trip. There is no automatic drive detection or all-day background monitoring.

Apple Core Location provides location fixes. Maps use Apple's MapKit and its network services when available. Apple services and iPhone backup behavior are governed by your device settings and Apple's terms; Mileage does not control them.

The trip file is written atomically with protection that remains available after the first unlock following boot. This allows recording to save data while the screen is locked. On a file-read error, the app preserves the existing file and blocks edits rather than silently starting over.

Exports leave the app only when you choose a destination in the share sheet. CSV contains trip details and start/end coordinates. Full JSON backups include detailed route samples. Treat both as sensitive. Temporary export files remain in the app's temporary storage until iOS clears them or a subsequent export overwrites them.

Use the per-trip Delete action to remove a completed trip from local records. Deleting the app removes its local records; exported copies and device backups are managed separately. Backup restore/import and cloud synchronization are not implemented.
