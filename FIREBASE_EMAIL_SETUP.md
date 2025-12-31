# Firebase Email Configuration Guide

## Why Password Reset Emails Might Not Arrive

If password reset emails are not being received, it's usually due to one of these reasons:

### 1. Firebase Email Templates Not Configured
Firebase needs to be properly configured to send emails.

### 2. Email Provider Blocking
Some university email systems (like @std.must.ac.ug) may block automated emails from Firebase.

### 3. Account Doesn't Exist
The email address must be registered in Firebase Authentication.

---

## Steps to Configure Firebase Email Templates

### Step 1: Access Firebase Console
1. Go to https://console.firebase.google.com/
2. Select your project: **sexual-harrasment-management**

### Step 2: Configure Email Templates
1. Click on **Authentication** in the left sidebar
2. Click on **Templates** tab
3. Click on **Password reset**

### Step 3: Customize Email Template
1. **From name**: Enter your app name (e.g., "MUST Report Harassment")
2. **From email**: This will be `noreply@sexual-harrasment-management.firebaseapp.com` (Firebase default)
3. **Subject**: Customize (e.g., "Reset your password")
4. **Email body**: You can customize the message
5. Click **Save**

### Step 4: Test Email Delivery
1. Try the forgot password feature with a test email
2. Check inbox AND spam folder
3. Email may take 2-10 minutes to arrive

---

## Alternative Solution: Use Gmail SMTP (Optional)

If Firebase emails are being blocked, you can set up custom email delivery:

### Option 1: Using Cloud Functions (Recommended for production)
```javascript
// This requires Firebase Cloud Functions (paid plan)
// Set up with SendGrid, Mailgun, or Gmail SMTP
```

### Option 2: Configure University Email Whitelist
Contact your university IT department to whitelist:
- `noreply@sexual-harrasment-management.firebaseapp.com`
- `@firebaseapp.com` domain

---

## Troubleshooting Checklist

### For Users
- [ ] Check spam/junk folder
- [ ] Wait 5-10 minutes for email to arrive
- [ ] Verify you're using the correct email address
- [ ] Confirm you've registered an account
- [ ] Ensure email is @std.must.ac.ug or @must.ac.ug format

### For Developers
- [ ] Verify Firebase Authentication is enabled
- [ ] Check Firebase Console > Authentication > Templates
- [ ] Verify email template is configured
- [ ] Check Firebase Console > Authentication > Users to confirm account exists
- [ ] Review Firebase Console > Authentication > Settings > Authorized domains
- [ ] Check terminal logs for Firebase errors

---

## Testing Email Delivery

### Quick Test
1. Go to Firebase Console > Authentication > Users
2. Find a test user
3. Click the three dots menu
4. Select "Send password reset email"
5. Check if email arrives

If Firebase Console test emails also don't arrive, the issue is likely:
- University email blocking Firebase emails
- Need to configure custom SMTP
- Firebase project email limits reached

---

## Debug Information

When password reset is triggered, check terminal logs for:
```
DEBUG: Attempting to send password reset email to: email@example.com
DEBUG: Sign-in methods for email@example.com: [password]
DEBUG: Password reset email sent successfully to email@example.com
```

If you see "Sign-in methods: []" (empty array), the account doesn't exist.

---

## Current App Configuration

- **Firebase Project**: sexual-harrasment-management
- **Package**: com.must.report_harassment
- **Allowed domains**: @std.must.ac.ug, @must.ac.ug
- **Default from email**: noreply@sexual-harrasment-management.firebaseapp.com

---

## Next Steps

1. **Immediate**: Check Firebase Console email templates
2. **Test**: Send password reset from Firebase Console directly
3. **If blocked**: Contact university IT about whitelisting Firebase emails
4. **Alternative**: Consider implementing custom SMTP with Cloud Functions
