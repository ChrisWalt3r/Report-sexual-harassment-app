# Quick Setup Reference - Email Notifications

## 🚀 Deploy in 5 Minutes

### Step 1: Check Prerequisites
```bash
# Verify Node.js installed
node --version  # Should be 18+

# Verify Firebase CLI installed
firebase --version
```

### Step 2: Install Dependencies
```bash
cd functions
npm install
cd ..
```

### Step 3: Upgrade Firebase to Blaze Plan
1. Go to https://console.firebase.google.com
2. Select your project
3. Settings > Billing > Upgrade to Blaze
4. Create budget alert (optional but recommended)

### Step 4: Generate Gmail App Password
1. Go to https://myaccount.google.com (login to your Gmail)
2. Security (left menu) > Turn on 2-Step Verification if not enabled
3. App passwords (left menu)
4. Select "Mail" and "Windows Computer"
5. Google generates 16-character password
6. **Copy the password** (e.g., `abcd efgh ijkl mnop`)

### Step 5: Set Firebase Configuration
Replace with YOUR EMAIL and PASSWORD:
```bash
firebase functions:config:set gmail.email="YOUR-EMAIL@gmail.com" gmail.password="YOUR-16-CHAR-PASSWORD"
```

Example:
```bash
firebase functions:config:set gmail.email="reports@must.ac.ug" gmail.password="abcd efgh ijkl mnop"
```

### Step 6: Deploy Cloud Functions
```bash
firebase deploy --only functions
```

Wait for deployment to complete (1-2 minutes).

### Step 7: Verify Deployment
```bash
firebase functions:list
```

Should show:
```
notifyASHCOnReportSubmission  http triggered
notifyOnReportStatusChange    Triggering on Firestore document update
healthCheck                   http triggered
```

✅ **Done!** Email system is now active

---

## 🧪 Test the System

### Option 1: Test via Firebase Console (Easiest)

1. Open Firebase Console: https://console.firebase.google.com
2. Select your project
3. Firestore Database
4. Click "+ Start collection"
5. Collection: `reports`
6. Auto ID, then add fields:

```json
{
  "description": "Test report",
  "location": "Test location",
  "date": "2026-03-09",
  "incidentTypes": ["Test Incident"],
  "isAnonymous": true,
  "status": "pending",
  "imageUrls": [],
  "videoUrls": [],
  "audioUrls": [],
  "timestamp": new Date()
}
```

7. Save
8. Check ASHC email inbox (wait 5-30 seconds)

### Option 2: Test via Mobile App

1. Open Report Harassment app
2. Tap "Report Incident"
3. Fill in details
4. Submit
5. Check ASHC email

### Option 3: Monitor in Real-Time
```bash
firebase functions:log --follow
```

Then submit a test report. You'll see:
```
notifyASHCOnReportSubmission ... Report created
notifyASHCOnReportSubmission ... Email sent successfully
```

---

## 📊 Monitor & Troubleshoot

### View Real-Time Logs
```bash
firebase functions:log --follow
```

### Stop Log Monitoring
Press `Ctrl+C`

### Check Email Configuration
```bash
firebase functions:config:get
```

Should show your email (not password for security).

### If Email Not Configured
```bash
firebase functions:config:set gmail.email="email@gmail.com" gmail.password="password"
firebase deploy --only functions
```

### If Gmail Authentication Failed
- Make sure you're using **App Password**, not regular Gmail password
- Generate new App Password at https://myaccount.google.com/apppasswords

### If Function Errors Show "ASHC Contact Not Found"
1. Go to Firebase Console > Firestore
2. Check `official_contacts` collection
3. Verify document `ashc_1` exists with email field
4. Or add it via Admin Dashboard (Contacts Management)

---

## 💡 Common Tasks

### Change ASHC Email Address
Option 1 (Recommended): Admin Dashboard
- Open Admin Panel
- Contacts Management
- Edit ASHC Chairperson
- Update email
- Save

Option 2: Firebase Console
- Firestore > `official_contacts` > `ashc_1`
- Edit `email` field
- Publish

### View Email Delivery History
1. Firebase Console > Firestore
2. Collections > `notifications_archive`
3. View all sent emails with timestamps

### Change Sender Email Address
If you want emails from a different address:
```bash
firebase functions:config:set gmail.email="new-email@gmail.com" gmail.password="app-password"
firebase deploy --only functions
```

### Test Status Change Notifications
1. Create/find a report in Firestore
2. Edit the `status` field
3. Change: `pending` → `under_investigation`
4. Check ASHC email for status update

---

## 🆘 Quick Troubleshooting

| Problem | Solution |
|---------|----------|
| "Email service not configured" | Run: `firebase functions:config:set gmail.email="..." gmail.password="..."` then `firebase deploy --only functions` |
| "Invalid login" | Use App Password from https://myaccount.google.com/apppasswords, not your Gmail password |
| "ASHC contact not found" | Verify `official_contacts/ashc_1` exists in Firestore |
| Email not received | Check spam folder, wait 30 seconds, check logs with `firebase functions:log --follow` |
| Function won't deploy | Check internet connection, verify Firebase CLI logged in with `firebase auth:login` |
| Node modules huge | This is normal, just don't commit to Git (in .gitignore) |

---

## 📚 Full Documentation

For detailed information, see:
- `CLOUD_FUNCTIONS_SETUP.md` - Complete function documentation
- `EMAIL_NOTIFICATIONS_GUIDE.md` - Email system guide
- `functions/README.md` - Function-specific details
- `functions/index.js` - Source code with comments

---

## ✅ Deployment Checklist

- [ ] Firebase Blaze plan active
- [ ] 2-Step Verification enabled on Gmail
- [ ] App Password generated
- [ ] Firebase config set with email & password
- [ ] `npm install` completed in functions folder
- [ ] `firebase deploy --only functions` completed successfully
- [ ] `firebase functions:list` shows 3 functions
- [ ] Test email received by ASHC address
- [ ] Logs monitored: `firebase functions:log --follow`

---

**Questions?** Check `EMAIL_NOTIFICATIONS_GUIDE.md` or `CLOUD_FUNCTIONS_SETUP.md`
