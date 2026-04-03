# Cloud Functions Configuration

This directory contains Firebase Cloud Functions for the Sexual Harassment Report Management system.

## Functions

### 1. `notifyASHCOnReportSubmission`
- **Trigger**: New report created in `reports` collection
- **Action**: Sends email notification to ASHC Chairperson with report details
- **Status**: Pending - Requires email configuration

### 2. `notifyOnReportStatusChange`
- **Trigger**: Existing report document updated (status change)
- **Action**: Notifies ASHC Chairperson when report status changes
- **Statuses**: pending → under_investigation → completed → closed/resolved

### 3. `healthCheck`
- **Trigger**: HTTP GET request
- **Action**: Returns health status and email configuration status

## Setup Instructions

### Prerequisites
- Node.js 18 or higher
- Firebase CLI: `npm install -g firebase-tools`
- Firebase project initialized: `firebase init functions`

### Step 1: Install Dependencies

```bash
cd functions
npm install
```

### Step 2: Configure Email Service (Gmail)

#### Option A: Using Firebase CLI (Recommended)

1. **Create a Gmail App Password** (NOT your regular password):
   - Go to https://myaccount.google.com/apppasswords
   - Select "Mail" and "Windows Computer" (or your device)
   - Google will generate a 16-character password
   - Copy this password

2. **Set Environment Variables**:
   ```bash
   firebase functions:config:set gmail.email="your-email@gmail.com" gmail.password="your-16-char-password"
   ```

3. **Verify Configuration**:
   ```bash
   firebase functions:config:get
   ```

### Step 3: Deploy Functions

```bash
firebase deploy --only functions
```

Or if deploying from the root directory:

```bash
firebase deploy --only functions --project sexual-harassment-management
```

### Step 4: Monitor Logs

```bash
firebase functions:log
```

Or in real-time:

```bash
firebase functions:log --follow
```

## Testing the Functions

### Test via Firebase Console

1. Go to Firebase Console > Functions
2. Click on `notifyASHCOnReportSubmission`
3. Click "Testing" tab
4. Create a test report in Firestore:

```javascript
// In Firestore Console
db.collection('reports').add({
  description: 'Test report',
  location: 'Test location',
  date: '2026-03-09',
  incidentTypes: ['Test incident'],
  isAnonymous: true,
  status: 'pending',
  timestamp: new Date(),
  imageUrls: [],
  videoUrls: [],
  audioUrls: [],
})
```

### Check Email Delivery

1. Monitor the Functions logs in Firebase Console
2. Check the ASHC Chairperson's email inbox
3. Check `notifications_archive` collection in Firestore for delivery records

## Troubleshooting

### Email Not Sending

**Problem**: Email configuration shows as not configured
```
Email service not configured. Skipping email notification.
```

**Solution**: 
```bash
firebase functions:config:set gmail.email="your-email@gmail.com" gmail.password="your-password"
firebase deploy --only functions
```

### Gmail Authentication Failed

**Problem**: `Error: Invalid login: 535-5.7.8 Username and password not accepted`

**Solution**:
- Make sure you're using Google App Password, NOT your regular Gmail password
- Generate new app password at https://myaccount.google.com/apppasswords
- App passwords only work with 2-Step Verification enabled

### Report Created but Email Not Sent

**Problem**: Report is created successfully but no email is sent

**Causes**:
1. Email not configured - check Firebase Console Functions logs
2. ASHC contact not found - verify `official_contacts` collection has `ashc_1` document
3. Gmail authentication failed - check app password and 2FA

**Debug**:
```bash
firebase functions:log --follow
```

Look for error messages like:
- "Email service not configured"
- "ASHC Chairperson contact not found"
- "Error sending email notification:"

### Function Timeout

**Problem**: Function takes too long and times out

**Solution**:
1. Increase timeout in `firebase.json`:
   ```json
   {
     "functions": {
       "timeout": 540,
       "memory": "512MB"
     }
   }
   ```
2. Redeploy: `firebase deploy --only functions`

## Security Notes

⚠️ **Important**: 
- DO NOT commit email credentials to Git - use Firebase CLI to set them
- App passwords are more secure than regular passwords
- Consider using environment variables in `.env` for local development
- Add `.env` to `.gitignore`

## Environment Variables (Local Development)

For local testing with Firebase Emulator:

1. Create `.env` file:
```
GMAIL_EMAIL=your-email@gmail.com
GMAIL_PASSWORD=your-app-password
```

2. In `index.js`, you can add:
```javascript
require('dotenv').config();
```

3. Update config:
```javascript
const gmailEmail = process.env.GMAIL_EMAIL || functions.config().gmail?.email;
const gmailPassword = process.env.GMAIL_PASSWORD || functions.config().gmail?.password;
```

## Future Enhancements

- [ ] Add SMS notifications using Twilio
- [ ] Support multiple email recipients (escalation path)
- [ ] Add notification templates in Firestore
- [ ] Implement retry logic for failed emails
- [ ] Add calendar integration for ASHC meetings
- [ ] Auto-generate report summaries
- [ ] Store notification delivery receipts

## Support

For issues or questions:
1. Check Firebase Console > Functions > Logs
2. Review troubleshooting section above
3. Run `firebase functions:log --follow` for real-time debugging
4. Check `notifications_archive` collection for delivery history
