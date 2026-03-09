# Cloud Functions & Email Notifications Setup

## Overview

When a sexual harassment report is submitted, the **ASHC Chairperson** (Anti-Sexual Harassment Committee Chairperson) is automatically notified via email. This uses Firebase Cloud Functions to:

1. ✉️ Send professional email with report details to ASHC Chairperson
2. 📋 Track notification delivery in `notifications_archive` collection
3. 📊 Notify on report status changes (pending → investigation → completed → closed)
4. 🔐 Maintain audit trail of all communications

## Quick Start

### 1. Install Dependencies

```bash
cd functions
npm install
cd ..
```

### 2. Upgrade Firebase Project to Blaze Plan (Required)

Cloud Functions require Firebase's **Blaze Plan** (pay-as-you-go):

1. Go to Firebase Console: https://console.firebase.google.com
2. Select your project
3. Go to **Settings** > **Billing**
4. Upgrade to **Blaze Plan**
5. Set a budget to avoid unexpected charges (Cloud Functions are usually free under quota)

### 3. Configure Gmail for Email Sending

#### Create Gmail App Password

1. Go to your Google Account: https://myaccount.google.com/
2. Enable **2-Step Verification** if not already enabled
3. Go to **App passwords**: https://myaccount.google.com/apppasswords
4. Select "Mail" and "Windows Computer"
5. Google generates a 16-character password
6. **Copy the password** (without spaces)

#### Set Firebase Configuration

```bash
firebase functions:config:set gmail.email="your-email@gmail.com" gmail.password="YOUR-16-CHAR-PASSWORD"
```

Example:
```bash
firebase functions:config:set gmail.email="reports@must.ac.ug" gmail.password="abcd efgh ijkl mnop"
```

### 4. Deploy Cloud Functions

```bash
firebase deploy --only functions
```

Expected output:
```
> functions@1.0.0 deploy
> firebase deploy --only functions

...
✔  Deploy complete!

Project Console: https://console.firebase.google.com/project/sexual-harassment-management/overview
Function details: https://console.firebase.google.com/project/sexual-harassment-management/functions/list
```

### 5. Verify Deployment

Check if functions are running:

```bash
firebase functions:list
```

You should see:
- `notifyASHCOnReportSubmission`
- `notifyOnReportStatusChange`
- `healthCheck`

## How It Works

### When a Report is Submitted

1. **User fills report form** → Submits via ReportFormScreen
2. **Firebase stores report** in `reports` collection
3. **Cloud Function triggers** `notifyASHCOnReportSubmission`
4. **Function fetches**:
   - Report details from Firestore
   - ASHC Chairperson contact from `official_contacts/ashc_1`
5. **Function sends email** with:
   - Report ID (for tracking)
   - Incident types
   - Location
   - Evidence count
   - Evidence download links (if available)
6. **Logs delivery**:
   - Success recorded in `notifications_archive` collection
   - Message ID saved for tracking
   - Timestamp recorded

### Email Format

The ASHC Chairperson receives a professional email with:

```
Subject: 🚨 NEW REPORT SUBMITTED - Tracking ID: ABC12345

From: [Configured Gmail Address]
To: ashc@must.ac.ug

Body:
├─ Report ID
├─ Submission Time
├─ Status (PENDING)
├─ Incident Types
├─ Location
├─ Anonymous Report (Yes/No)
└─ Evidence Summary (Images, Videos, Audio)
```

### Report Status Change Notifications

When an admin changes report status in the system:

```
pending → under_investigation → completed → closed/resolved
```

The ASHC Chairperson gets a status update email automatically.

## Testing

### Test 1: Manual Firestore Entry

1. Go to Firebase Console > Firestore
2. Create new document in `reports` collection with:

```javascript
{
  description: "Test report for email notification",
  location: "Test Location",
  date: "2026-03-09",
  incidentTypes: ["Test Incident Type"],
  isAnonymous: true,
  status: "pending",
  timestamp: new Date(),
  imageUrls: [],
  videoUrls: [],
  audioUrls: []
}
```

3. Check:
   - ASHC email inbox for notification
   - Firebase Functions logs: `firebase functions:log --follow`
   - `notifications_archive` collection for delivery record

### Test 2: Via Mobile App

1. Open the Report Harassment app
2. Go to "Report Incident" screen
3. Fill in report details and submit
4. Wait 5-10 seconds for cloud function execution
5. Check ASHC email and logs

### Test 3: Status Change Notification

1. In Firestore, find a report document
2. Change the status field: `pending` → `under_investigation`
3. Check ASHC email for status change notification
4. Check Firebase Functions logs

## Monitoring

### View Real-Time Logs

```bash
firebase functions:log --follow
```

This shows:
- Function execution start/end
- Email sent confirmations
- Errors and debugging info
- Latency metrics

### View Function Metrics

Firebase Console > Functions:
- Execution count
- Average execution time
- Error rate
- Memory usage

### Check Delivery Records

1. Firebase Console > Firestore
2. Go to `notifications_archive` collection
3. View delivery history:

```javascript
{
  type: "ashc_report_submitted",
  reportId: "ABC123XYZ",
  recipientEmail: "ashc@must.ac.ug",
  recipientName: "ASHC Chairperson",
  sentAt: Timestamp,
  status: "sent",
  messageId: "Gmail message ID"
}
```

## Troubleshooting

### Issue: "Email service not configured"

**Error Message**:
```
Email service not configured. Skipping email notification.
```

**Cause**: Gmail configuration not set

**Fix**:
```bash
firebase functions:config:set gmail.email="your-email@gmail.com" gmail.password="your-app-password"
firebase deploy --only functions
```

### Issue: Gmail Authentication Failed

**Error Message**:
```
Error: Invalid login: 535-5.7.8 Username and password not accepted
```

**Cause**: Using regular Gmail password instead of App Password

**Fix**:
1. Open https://myaccount.google.com/apppasswords
2. Ensure 2-Step Verification is enabled
3. Generate new App Password
4. Set it: `firebase functions:config:set gmail.password="new-password"`

### Issue: ASHC Contact Not Found

**Error Message**:
```
ASHC Chairperson contact not found in database
```

**Cause**: Missing `ashc_1` document in `official_contacts` collection

**Fix**:
1. Open Admin Panel
2. Go to Contacts Management
3. Ensure ASHC Chairperson exists with:
   - ID: `ashc_1`
   - Email: `ashc@must.ac.ug` (or correct email)

### Issue: No Email Received

**Possible Causes**:
1. Function failed - check logs: `firebase functions:log --follow`
2. Email blocked by university - check spam folder
3. Firestore operation slow - test with 10 second delay
4. Function not deployed - run: `firebase deploy --only functions`

**Debug Steps**:
1. Check `notifications_archive` collection - was it recorded?
2. Run: `firebase functions:log --follow`
3. Look for error stack traces
4. Check Firebase Console > Functions > Logs tab

### Issue: Need to Update ASHC Email

The ASHC Chairperson email is stored in Firestore at `official_contacts/ashc_1`. To update:

1. **Via Admin Panel**:
   - Open Admin Panel
   - Go to Contacts Management
   - Find and edit ASHC Chairperson
   - Update email
   - Save

2. **Via Firebase Console**:
   - Firestore > `official_contacts` collection
   - Click `ashc_1` document
   - Edit the `email` field
   - Publish

## Advanced Configuration

### Change Function Region

Edit `functions/index.js` if needed in different region:

```javascript
exports.notifyASHCOnReportSubmission = functions
  .region('asia-southeast1') // Change region here
  .firestore.document('reports/{reportId}')
  .onCreate(...)
```

Then redeploy: `firebase deploy --only functions`

### Add Multiple Recipients

Edit `functions/index.js` in the Cloud Function to CC additional email addresses:

```javascript
const mailOptions = {
  from: gmailEmail,
  to: ashcEmail,
  cc: 'admin@must.ac.ug, dos@must.ac.ug', // Add here
  subject: emailSubject,
  html: emailHtml,
};
```

### Customize Email Template

All email HTML is in `functions/index.js`. You can:
- Change colors
- Add/remove sections
- Update text
- Add logos
- Change styling

After editing, redeploy:
```bash
firebase deploy --only functions
```

### Add Notifications for Other Roles

You can duplicate the `notifyASHCOnReportSubmission` function for other contacts:
- Dean of Students
- University Secretary
- Department Heads

Example for Dean of Students:
```javascript
exports.notifyDOSOnReportSubmission = functions
  .firestore.document('reports/{reportId}')
  .onCreate(async (snap, context) => {
    // Same logic but reference 'dos_1' instead of 'ashc_1'
    const dosDoc = await admin.firestore()
      .collection('official_contacts')
      .doc('dos_1')
      .get();
    // ... send email logic
  });
```

## Cost Considerations

**Cloud Functions Pricing** (as of 2026):
- **First 2M invocations/month**: FREE
- **Additional invocations**: $0.40 per million calls
- **Execution time**: First 400,000 GB-seconds/month FREE
- **Network**: Egress data charged separately

**Estimate**:
- 100 reports/day = 3,000/month = **FREE** (within free tier)
- 1,000 reports/day = 30,000/month = **FREE** (within free tier)
- 10,000 reports/day = 300,000/month = **$0.04/month**

To minimize costs:
1. Set Firebase billing budget alert
2. Monitor function execution frequency
3. Optimize notification logic
4. Archive old notifications periodically

## Next Steps

1. ✅ Set up Gmail App Password
2. ✅ Deploy Cloud Functions
3. ✅ Test with sample report
4. ✅ Monitor logs for issues
5. ✅ Configure additional recipients (optional)
6. ✅ Set up backup email addresses
7. ✅ Document ASHC email notifications in procedures

## Support & Resources

- Firebase Cloud Functions: https://firebase.google.com/docs/functions
- Firestore Triggers: https://firebase.google.com/docs/functions/firestore-events
- Nodemailer: https://nodemailer.com/
- Gmail App Passwords: https://support.google.com/accounts/answer/185833

---

**Status**: Ready for deployment  
**Last Updated**: March 9, 2026  
**Maintained By**: Development Team
