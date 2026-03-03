# Push Notifications Setup Guide

## Overview
This app now uses Firebase Cloud Functions to send push notifications across devices. When a caretaker creates a reminder for a senior, the senior's device receives a push notification even if the caretaker's device is off.

## Setup Steps

### 1. Install Firebase CLI
```bash
npm install -g firebase-tools
```

### 2. Login to Firebase
```bash
firebase login
```

### 3. Initialize Firebase Functions (if not already done)
```bash
cd /Users/yousiflm/IdeaProjects/AlarmingApp
firebase init functions
# Select your Firebase project
# Choose JavaScript
# Install dependencies: Yes
```

### 4. Deploy Cloud Functions
```bash
cd firebase-functions
npm install
firebase deploy --only functions
```

### 5. Configure APNs (Apple Push Notification service)
1. Go to Firebase Console → Project Settings → Cloud Messaging
2. Upload your APNs Authentication Key (.p8 file)
3. Enter your Key ID and Team ID

### 6. Test
1. Caretaker creates reminder for senior
2. Senior's device receives push notification at scheduled time
3. If senior doesn't complete, caretaker receives notification after delay

## How It Works

1. **Reminder Created/Modified**: Firestore trigger fires in Cloud Functions
2. **Cloud Function Schedules**: Creates entry in `scheduledNotifications` collection
3. **Cron Job**: Runs every minute, sends notifications that are due
4. **Push Notification**: Sent to device via FCM token
5. **Device Receives**: iOS shows notification with sound/badge

## Architecture Benefits

✅ **Cross-device**: Works even if creator's device is off
✅ **Reliable**: Firebase infrastructure handles delivery
✅ **Scalable**: Supports unlimited users and reminders
✅ **No local scheduling**: Devices don't need to be online to schedule

## Firestore Collections

- `users/{uid}/reminders/{reminderId}` - Reminder data
- `scheduledNotifications` - Pending notifications (auto-deleted after sending)
- `users/{uid}` - Contains `fcmToken` for push delivery

## Cost

Firebase Cloud Functions free tier:
- 2M invocations/month
- 400K GB-seconds/month
- 200K CPU-seconds/month

This should cover most use cases. Monitor usage in Firebase Console.
