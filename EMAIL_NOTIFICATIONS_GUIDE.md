# Email Notification System - Implementation Summary

## ✅ What's Been Set Up

The Sexual Harassment Report Management app now has **automated email notifications** to the ASHC Chairperson when reports are submitted.

### Cloud Functions Created

**Location**: `/functions/` directory

**Files**:
- `functions/package.json` - Node.js dependencies
- `functions/index.js` - Cloud Functions code (3 functions)
- `functions/README.md` - Detailed function documentation
- `functions/.env.example` - Environment variable template
- `functions/.gitignore` - Git ignore rules

### Email Notification Flow

```
┌─────────────────────────┐
│  User Submits Report    │
│  (ReportFormScreen)     │
└────────────┬────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│  Report saved to Firestore          │
│  (reports collection)               │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│  Cloud Function Triggered           │
│  notifyASHCOnReportSubmission       │
└────────────┬────────────────────────┘
             │
     ┌───────┴───────┐
     │               │
     ▼               ▼
┌─────────┐    ┌─────────────────────┐
│ Fetch   │    │ Build Professional  │
│ ASHC    ├───▶│ Email with Report   │
│ Email   │    │ Details & Evidence  │
└─────────┘    └────────────┬────────┘
                            │
                            ▼
                ┌──────────────────────┐
                │ Send via Gmail SMTP  │
                │ (nodemailer)         │
                └────────────┬─────────┘
                             │
                ┌────────────┴────────────┐
                │                         │
                ▼                         ▼
        ┌──────────────┐         ┌──────────────────┐
        │ ✉️  Email    │         │ 📋 Log Delivery  │
        │ Delivered to │         │ in Firestore     │
        │ ASHC         │         │ (archive)        │
        └──────────────┘         └──────────────────┘
```

## 📋 What Happens When Report is Submitted

### 1. Report Creation
User submits report with details:
- Description
- Location
- Date & time
- Incident types
- Evidence (images, videos, audio)
- Anonymous flag
- Witness/perpetrator info

### 2. Firestore Storage
Report saved to `reports` collection with:
- Auto-generated ID (e.g., "ABC123XYZ...")
- User ID (if authenticated)
- Status: "pending"
- Timestamp

### 3. Cloud Function Triggers
`notifyASHCOnReportSubmission` function automatically runs:
- Retrieves ASHC Chairperson contact from `official_contacts/ashc_1`
- Extracts email: `ashc@must.ac.ug`
- Builds professional HTML email

### 4. Email Sent
Professional email sent to ASHC Chairperson containing:
- 🆔 Report ID (for tracking)
- ⏰ Submission time
- 🏷️ Incident types
- 📍 Location
- 📎 Evidence summary (counts of images, videos, audio)
- ✅ Current status (PENDING)
- ⚠️ Policy reminder

### 5. Delivery Logged
Success recorded in `notifications_archive` collection:
- Recipient email
- Delivery timestamp
- Gmail Message ID
- Status: "sent"

### 6. Admin Dashboard
ASHC Chairperson:
- Receives email with report summary
- Logs into Admin Dashboard
- Reviews full report with evidence
- Updates report status
- Automatically triggers status change notification

## 🔧 Setup Requirements

### Before Deploying

1. **Firebase Blaze Plan** (required)
   - Cloud Functions only work on Blaze (pay-as-you-go) plan
   - Set budget alert to avoid surprise charges
   - Usually FREE (well under quota for small deployments)

2. **Gmail Account** (for sending emails)
   - Can be personal, institutional, or app-specific
   - Requires 2-Step Verification enabled
   - Need to generate App Password (16-character)

3. **Node.js 18+** (for local development)
   - Already required if using Firebase CLI

### Deployment Steps

```bash
# Step 1: Install dependencies
cd functions
npm install
cd ..

# Step 2: Set Google Account configuration
firebase functions:config:set \
  gmail.email="your-email@gmail.com" \
  gmail.password="your-16-char-app-password"

# Step 3: Deploy functions
firebase deploy --only functions

# Step 4: Verify deployment
firebase functions:list

# Step 5: Monitor logs
firebase functions:log --follow
```

## 📧 Email Configuration

### Gmail Setup (Recommended)

1. **Enable 2-Step Verification**:
   - Go to https://myaccount.google.com/security
   - Enable 2-Step Verification

2. **Generate App Password**:
   - Go to https://myaccount.google.com/apppasswords
   - Select "Mail" and "Windows Computer"
   - Google generates 16-character password
   - Copy password (remove spaces when setting config)

3. **Set Firebase Config**:
   ```bash
   firebase functions:config:set \
     gmail.email="app-email@gmail.com" \
     gmail.password="xxxx xxxx xxxx xxxx"
   ```

### Alternative Email Services

The code is designed to work with Gmail via nodemailer, but can be extended for:
- SendGrid (API-based)
- Mailgun (API-based)
- AWS SES
- Office 365

Edit `functions/index.js` to add support.

## 🧪 Testing the System

### Test 1: Manual Firestore Entry
```javascript
// In Firebase Console > Firestore
db.collection('reports').add({
  description: "Test incident description",
  location: "Test location", 
  date: "2026-03-09",
  incidentTypes: ["Test Type"],
  isAnonymous: true,
  status: "pending",
  imageUrls: [],
  videoUrls: [],
  audioUrls: [],
  timestamp: new Date()
})
```

### Test 2: Via Mobile App
1. Open Report Harassment app
2. Fill "Report Incident" form
3. Submit report
4. Check ASHC email inbox (may take 5-30 seconds)

### Test 3: Check Logs
```bash
firebase functions:log --follow
```

Expected output on success:
```
notifyASHCOnReportSubmission 2026-03-09 10:30:45.123 Report created
notifyASHCOnReportSubmission 2026-03-09 10:30:47.456 Email sent successfully to ashc@must.ac.ug
```

## 📊 Monitoring & Maintenance

### Daily Monitoring
```bash
# Check function health
firebase functions:log --follow

# Check delivery records in Firestore
# Collections > notifications_archive
```

### Weekly Checks
- [ ] Review function logs for errors
- [ ] Verify ASHC is receiving notifications
- [ ] Check `notifications_archive` for delivery records
- [ ] Monitor Firebase Functions execution metrics

### Monthly Maintenance
- [ ] Review cost (should be $0 for most usage)
- [ ] Archive old notifications (optional)
- [ ] Update ASHC email if changed
- [ ] Test with sample report

## 🔐 Security Considerations

✅ **What's Secure**:
- App Password stored in Firebase config (encrypted)
- Not in source code or repository
- Email address visible only to admin
- Deliver logs auditable

⚠️ **Important**:
- Do NOT commit `functions/node_modules` (in .gitignore)
- Do NOT commit `.env` file with real passwords
- Do NOT share Firebase config values in chat/email
- Only admins should access notifications_archive

## 📋 Notification Details

### Report Submitted Email

**To**: ashc@must.ac.ug  
**Subject**: 🚨 NEW REPORT SUBMITTED - Tracking ID: ABC12345

**Body Contains**:
- Report ID
- Submission timestamp
- Incident type(s)
- Location
- Anonymous status
- Evidence summary (images, videos, audio count)
- Direct link to Admin Dashboard (optional)
- Policy reminder
- Instructions for next steps

### Status Change Notification

Triggers when report status changes:
- pending → under_investigation
- under_investigation → completed
- completed → closed
- Any status → resolved

Email includes:
- Previous status
- New status
- Status description
- Report ID
- Timestamp

## 🚀 Future Enhancements

Possible future additions:
- [ ] SMS notifications via Twilio
- [ ] Multiple recipient escalation
- [ ] Calendar integration for follow-ups
- [ ] Auto-generated investigation summaries
- [ ] Evidence thumbnail previews in email
- [ ] One-click action buttons in email
- [ ] Digest emails (daily/weekly summary)
- [ ] Notification preferences per admin

## 📞 Support & Troubleshooting

### Common Issues

**"Email service not configured"**
```
firebase functions:config:set gmail.email="..." gmail.password="..."
firebase deploy --only functions
```

**"Gmail authentication failed"**
- Use App Password, not regular Gmail password
- Generate new App Password at https://myaccount.google.com/apppasswords

**"ASHC contact not found"**
- Verify `official_contacts/ashc_1` exists with email field

**"Function never deployed"**
```
firebase deploy --only functions --debug
```

**"Email not received"**
- Check ASHC spam folder
- Check Firebase logs: `firebase functions:log --follow`
- Verify email configuration set correctly
- Wait 30 seconds (network latency)

### Debug Commands

```bash
# View real-time logs
firebase functions:log --follow

# View specific function logs
firebase functions:log --follow | grep notifyASHC

# List deployed functions
firebase functions:list

# Get current config
firebase functions:config:get

# View costs
firebase billing
```

### View Delivery Records

In Firebase Console:
1. Firestore > Collections > `notifications_archive`
2. View all delivery records:
   - Status: "sent" or "failed"
   - Timestamp of delivery
   - Message ID from Gmail
   - Error details (if failed)

## ✅ Checklist for Deployment

- [ ] Firebase upgraded to Blaze plan
- [ ] Gmail account has 2-Step Verification
- [ ] App Password generated and copied
- [ ] Config set: `firebase functions:config:set gmail.email="..." gmail.password="..."`
- [ ] Functions deployed: `firebase deploy --only functions`
- [ ] Functions visible: `firebase functions:list` shows 3 functions
- [ ] Test report created and email received
- [ ] ASHC email updated if different from default
- [ ] Logs monitored: `firebase functions:log --follow`
- [ ] Team notified of new notification system
- [ ] Documentation shared with admins

---

**Status**: Ready for Deployment  
**Created**: March 9, 2026  
**Last Updated**: March 9, 2026
