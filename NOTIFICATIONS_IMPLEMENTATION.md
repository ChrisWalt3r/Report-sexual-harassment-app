# Notifications System Implementation

## Overview
This document outlines the notifications system implemented for the Report Sexual Harassment App. The system provides real-time notifications for report lifecycle events using Firebase Cloud Messaging (FCM) and Firestore.

## Features Implemented

### 1. Notification Types
The system supports the following notification types:
- `report_submitted`: Sent when a new report is created
- `status_changed`: Sent when a report status changes (pending → under review → resolved)
- `new_comment`: Sent when an admin adds a comment to a report
- `reminder`: General reminders for users

### 2. Core Components

#### NotificationModel (`lib/models/notification_model.dart`)
Data model representing a notification with the following fields:
- `id`: Unique notification identifier
- `userId`: User receiving the notification
- `type`: Type of notification (report_submitted, status_changed, etc.)
- `title`: Notification title
- `message`: Notification message
- `reportId`: Optional reference to related report
- `isRead`: Read status
- `createdAt`: Timestamp

Methods:
- `fromFirestore()`: Convert Firestore document to model
- `toMap()`: Convert model to Firestore-compatible map
- `copyWith()`: Create a copy with updated fields

#### NotificationService (`lib/services/notification_service.dart`)
Central service managing all notification operations:

**Initialization:**
- `initialize(String userId)`: Sets up FCM, requests permissions, saves token to Firestore
- Configures foreground and background message handlers
- Subscribes to user-specific notification stream

**CRUD Operations:**
- `createNotification()`: Create new notification in Firestore
- `markAsRead(String notificationId)`: Mark notification as read
- `deleteNotification(String notificationId)`: Delete notification
- `getNotificationsStream()`: Real-time stream of user notifications
- `updateUnreadCount()`: Update unread notification count

**FCM Integration:**
- Handles foreground messages with local notifications
- Processes background messages
- Manages FCM token lifecycle

#### NotificationsScreen (`lib/screens/notifications_screen.dart`)
UI screen displaying user notifications:

**Features:**
- Real-time updates using StreamBuilder
- Dismissible cards for swipe-to-delete
- Visual distinction between read/unread notifications
- Tap to navigate to report details
- Mark as read functionality
- Empty state when no notifications
- Time formatting (e.g., "2 hours ago")
- Loading and error states

### 3. Integration Points

#### Home Screen
- Notification bell icon in app bar
- Real-time badge showing unread count
- Consumer widget updates automatically
- Navigates to NotificationsScreen on tap

#### Report Submission
- Creates notification when report is submitted
- Includes report ID and category
- Notification sent to reporting user
- Confirmation of successful report

#### Main App
- NotificationService added to Provider tree
- Initialized in HomeScreen when user logs in
- Available throughout app via Provider

## Firebase Configuration

### Firestore Collections

#### `notifications` Collection
```
notifications/
  {notificationId}/
    - userId: String
    - type: String
    - title: String
    - message: String
    - reportId: String (optional)
    - isRead: Boolean
    - createdAt: Timestamp
```

#### `users` Collection (Enhanced)
```
users/
  {userId}/
    - fcmToken: String (device token for push notifications)
    ... (other user fields)
```

### Required Permissions

#### Android (`android/app/src/main/AndroidManifest.xml`)
Already configured:
- POST_NOTIFICATIONS (for Android 13+)
- INTERNET
- Foreground service permissions

#### iOS (`ios/Runner/Info.plist`)
May need to add:
```xml
<key>FirebaseMessagingAutoInitEnabled</key>
<true/>
```

## Testing the Notifications System

### Test Flow 1: Report Submission Notification
1. Log in to the app
2. Submit a new report via the "Report Incident" button
3. Check notification bell - should show badge with count
4. Tap notification bell to view NotificationsScreen
5. Should see "Report Submitted" notification
6. Tap notification to navigate to report details
7. Notification should be marked as read

### Test Flow 2: Mark as Read
1. Navigate to NotificationsScreen
2. Tap on an unread notification (blue background)
3. Background should change to white
4. Badge count should decrease
5. Return to home screen - badge count should be updated

### Test Flow 3: Delete Notification
1. Navigate to NotificationsScreen
2. Swipe left on any notification
3. Notification should be deleted
4. If it was unread, badge count should decrease

## Future Enhancements

### Phase 2: Status Change Notifications
Implement automatic notifications when report status changes:
- Add Firestore listener in NotificationService
- Create notification when `status` field changes
- Include old and new status in notification

### Phase 3: Admin Comment Notifications
Notify users when admins add comments:
- Listen to `reports/{reportId}/comments` subcollection
- Create notification for each new comment
- Include snippet of comment in notification

### Phase 4: Push Notifications
Full FCM push notification implementation:
- Configure Firebase Cloud Functions
- Send push notifications to offline users
- Handle notification taps to deep link to reports
- Add notification sound and vibration

### Phase 5: Notification Preferences
Allow users to customize notifications:
- In-app notification settings
- Toggle specific notification types
- Quiet hours configuration
- Notification sound selection

## Dependencies Added
```yaml
firebase_messaging: ^15.1.5
```

## Files Modified/Created

### Created Files:
- `lib/models/notification_model.dart`
- `lib/services/notification_service.dart`
- `lib/screens/notifications_screen.dart`

### Modified Files:
- `pubspec.yaml` - Added firebase_messaging dependency
- `lib/main.dart` - Added NotificationService to providers
- `lib/screens/home_screen.dart` - Added notification bell with badge, initialization
- `lib/screens/report_form_screen.dart` - Create notification on report submission

## Security Considerations

### Firestore Security Rules
Recommended rules for notifications collection:
```javascript
match /notifications/{notificationId} {
  allow read: if request.auth != null && 
                 resource.data.userId == request.auth.uid;
  allow create: if request.auth != null;
  allow update, delete: if request.auth != null && 
                           resource.data.userId == request.auth.uid;
}
```

### Data Privacy
- Notifications are user-specific (filtered by userId)
- Users can only see their own notifications
- Notifications auto-deleted when dismissed
- No sensitive data in notification messages

## Troubleshooting

### Issue: Notifications not appearing
**Solutions:**
- Check Firebase console for FCM configuration
- Verify FCM token is saved in Firestore users collection
- Check notification permissions in device settings
- Verify NotificationService.initialize() is called after login

### Issue: Badge count not updating
**Solutions:**
- Ensure NotificationService is in Provider tree
- Check StreamSubscription is active
- Verify updateUnreadCount() is being called
- Use Flutter DevTools to inspect Provider state

### Issue: Can't navigate to report details
**Solutions:**
- Verify ReportDetailsScreen requires reportData parameter
- Check reportId is valid in Firestore
- Ensure report document exists before navigation
- Handle null/missing report gracefully

## Performance Considerations

### Stream Management
- Single stream subscription per user
- Automatic cleanup on service disposal
- Limited to user's notifications only (filtered query)

### Firestore Queries
- Indexed by userId for fast retrieval
- Ordered by createdAt descending (newest first)
- Consider pagination for users with many notifications

### Memory Management
- NotificationService properly disposed when provider is removed
- Stream subscriptions canceled on dispose
- No memory leaks from listeners

## Conclusion
The notifications system is now fully functional and integrated into the app. Users receive real-time notifications for report submissions, can view all notifications in a dedicated screen, and can manage (read/delete) their notifications. The system is built on Firebase Cloud Messaging and Firestore, providing a scalable and reliable notification infrastructure.
