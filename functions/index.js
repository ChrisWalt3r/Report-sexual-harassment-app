const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');
const { defineString, defineSecret } = require('firebase-functions/params');

// Initialize Firebase Admin SDK
admin.initializeApp();

// Define params (modern replacement for functions.config())
const gmailEmail = defineString('GMAIL_EMAIL');
const gmailPassword = defineSecret('GMAIL_PASSWORD');
const configuredAshcEmail = defineString('ASHC_EMAIL');

// Helper function to create email transporter
function createTransporter() {
  const email = gmailEmail.value();
  const password = gmailPassword.value();
  
  if (!email || !password) {
    return null;
  }
  
  return nodemailer.createTransport({
    service: 'gmail',
    auth: {
      user: email,
      pass: password, // Use app password, not your actual password
    },
  });
}

async function getAshcChairpersonContact() {
  const collectionNames = ['official_contacts', 'official contacts'];

  for (const collectionName of collectionNames) {
    const collectionRef = admin.firestore().collection(collectionName);

    const byFixedId = await collectionRef.doc('ashc_1').get();
    if (byFixedId.exists) {
      const data = byFixedId.data();
      if (data?.email) {
        return { ...data, sourceCollection: collectionName };
      }
    }

    const byCategory = await collectionRef
      .where('category', '==', 'ashc')
      .where('isActive', '==', true)
      .limit(10)
      .get();

    if (!byCategory.empty) {
      const contact = byCategory.docs
        .map((doc) => doc.data())
        .find((item) => !!item?.email);
      if (contact) {
        return { ...contact, sourceCollection: collectionName };
      }
    }

    const allContacts = await collectionRef.where('isActive', '==', true).limit(50).get();
    if (!allContacts.empty) {
      const matching = allContacts.docs
        .map((doc) => doc.data())
        .find((item) => {
          const name = (item?.name || '').toString().toLowerCase();
          const title = (item?.title || '').toString().toLowerCase();
          const category = (item?.category || '').toString().toLowerCase();
          const hasAshc = name.includes('ashc') || title.includes('anti-sexual harassment') || category === 'ashc';
          const isChair = name.includes('chair') || title.includes('chair');
          return hasAshc && isChair && !!item?.email;
        });

      if (matching) {
        return { ...matching, sourceCollection: collectionName };
      }
    }
  }

  return null;
}

/**
 * Cloud Function: Send email notification to ASHC Chairperson when a report is submitted
 * Triggers on new document creation in 'reports' collection
 */
exports.notifyASHCOnReportSubmission = functions
  .runWith({ secrets: [gmailPassword] })
  .region('europe-west1') // Use appropriate region for your app
  .firestore.document('reports/{reportId}')
  .onCreate(async (snap, context) => {
    try {
      const reportData = snap.data();
      const reportId = context.params.reportId;

      // Log for monitoring
      console.log(`New report submitted: ${reportId}`, reportData);

      // Create email transporter
      const transporter = createTransporter();
      
      // Check if email is configured
      if (!transporter) {
        console.warn('Email service not configured. Skipping email notification.');
        console.log('To enable emails, set GMAIL_EMAIL and GMAIL_PASSWORD parameters');
        return null;
      }

      // Get ASHC Chairperson contact
      const ashcContact = await getAshcChairpersonContact();

      if (!ashcContact) {
        console.error('ASHC Chairperson contact not found in database');
        return null;
      }
      const ashcEmail = ashcContact.email || configuredAshcEmail.value();

      if (!ashcEmail) {
        console.error('ASHC Chairperson email not configured');
        return null;
      }

      // Prepare email content
      const incidentTypes = reportData.incidentTypes || reportData.incidentType || 'Not specified';
      const location = reportData.location || 'Not specified';
      const timestamp = reportData.timestamp ? new Date(reportData.timestamp.toDate()).toLocaleString('en-US') : 'Just now';

      const emailSubject = `🚨 NEW REPORT SUBMITTED - Tracking ID: ${reportId.substring(0, 8).toUpperCase()}`;

      const emailHtml = `
        <html>
          <head>
            <style>
              body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
              .container { max-width: 600px; margin: 0 auto; padding: 20px; background: #f9f9f9; border-radius: 8px; }
              .header { background: linear-gradient(135deg, #003d82 0%, #1a5fa0 100%); color: white; padding: 20px; border-radius: 8px 8px 0 0; text-align: center; }
              .header h1 { margin: 0; font-size: 24px; }
              .content { background: white; padding: 20px; }
              .section { margin-bottom: 20px; }
              .section-title { font-weight: bold; color: #003d82; border-bottom: 2px solid #f4c430; padding-bottom: 8px; margin-bottom: 10px; }
              .field { margin-bottom: 12px; }
              .label { font-weight: bold; color: #555; display: inline-block; width: 140px; }
              .value { color: #333; }
              .warning { background: #fff3cd; padding: 12px; border-left: 4px solid #ffc107; margin: 15px 0; border-radius: 4px; }
              .footer { background: #f0f0f0; padding: 15px; text-align: center; font-size: 12px; color: #666; border-radius: 0 0 8px 8px; }
              .action-button { display: inline-block; background: #003d82; color: white; padding: 12px 24px; text-decoration: none; border-radius: 4px; margin-top: 15px; }
            </style>
          </head>
          <body>
            <div class="container">
              <div class="header">
                <h1>⚠️ SEXUAL HARASSMENT REPORT NOTIFICATION</h1>
              </div>
              <div class="content">
                <p>Dear <strong>${ashcContact.name}</strong>,</p>
                
                <p style="color: #c41e3a; font-weight: bold;">A new sexual harassment report has been submitted and requires your attention.</p>

                <div class="section">
                  <div class="section-title">📋 Report Details</div>
                  <div class="field">
                    <span class="label">Report ID:</span>
                    <span class="value"><strong>${reportId}</strong></span>
                  </div>
                  <div class="field">
                    <span class="label">Submitted:</span>
                    <span class="value">${timestamp}</span>
                  </div>
                  <div class="field">
                    <span class="label">Status:</span>
                    <span class="value"><strong>PENDING</strong> (Awaiting investigation)</span>
                  </div>
                </div>

                <div class="section">
                  <div class="section-title">🔍 Incident Information</div>
                  <div class="field">
                    <span class="label">Type(s):</span>
                    <span class="value">${Array.isArray(incidentTypes) ? incidentTypes.join(', ') : incidentTypes}</span>
                  </div>
                  <div class="field">
                    <span class="label">Location:</span>
                    <span class="value">${location}</span>
                  </div>
                  <div class="field">
                    <span class="label">Anonymous Report:</span>
                    <span class="value">${reportData.isAnonymous ? 'Yes' : 'No'}</span>
                  </div>
                </div>

                <div class="section">
                  <div class="section-title">📎 Evidence Attached</div>
                  <div class="field">
                    <span class="label">Images:</span>
                    <span class="value">${(reportData.imageUrls?.length || 0)} file(s)</span>
                  </div>
                  <div class="field">
                    <span class="label">Videos:</span>
                    <span class="value">${(reportData.videoUrls?.length || 0) } file(s)</span>
                  </div>
                  <div class="field">
                    <span class="label">Audio:</span>
                    <span class="value">${(reportData.audioUrls?.length || 0)} file(s)</span>
                  </div>
                </div>

                <div class="warning">
                  <strong>⚠️ Important:</strong> This is an automated notification. Please log in to the Admin Dashboard to review the complete report details, evidence, and take appropriate action per MUST Sexual Harassment Policy.
                </div>

                <div style="text-align: center;">
                  <p style="color: #999; font-size: 12px;">
                    Per MUST Sexual Harassment Policy, reports are confidential and should be handled with utmost care. 
                    Ensure all due process procedures are followed.
                  </p>
                </div>
              </div>
              <div class="footer">
                <p>This is an automated notification from the MUST Sexual Harassment Report System</p>
                <p>Do not reply to this email - Use the admin dashboard for official communications</p>
              </div>
            </div>
          </body>
        </html>
      `;

      // Send email
      const mailOptions = {
        from: gmailEmail,
        to: ashcEmail,
        cc: '', // Can add more recipients here if needed
        subject: emailSubject,
        html: emailHtml,
        replyTo: gmailEmail,
      };

      const result = await transporter.sendMail(mailOptions);
      console.log(`Email sent successfully to ${ashcEmail}. Message ID: ${result.messageId}`);

      // Log the notification in Firestore for auditing
      await admin.firestore()
        .collection('notifications_archive')
        .add({
          type: 'ashc_report_submitted',
          reportId: reportId,
          recipientEmail: ashcEmail,
          recipientName: ashcContact.name,
          sentAt: admin.firestore.FieldValue.serverTimestamp(),
          status: 'sent',
          messageId: result.messageId,
        });

      return { success: true, messageId: result.messageId };

    } catch (error) {
      console.error('Error sending email notification:', error);
      
      // Log error for debugging
      await admin.firestore()
        .collection('notifications_archive')
        .add({
          type: 'ashc_report_submitted_error',
          reportId: context.params.reportId,
          error: error.message,
          errorStack: error.stack,
          failedAt: admin.firestore.FieldValue.serverTimestamp(),
          status: 'failed',
        });

      // Don't throw - let the function complete so the report is still created
      return { success: false, error: error.message };
    }
  });

/**
 * Cloud Function: Send email when report status changes
 * Notifies ASHC and complainant (if email on file) of status updates
 */
exports.notifyOnReportStatusChange = functions
  .runWith({ secrets: [gmailPassword] })
  .region('europe-west1')
  .firestore.document('reports/{reportId}')
  .onUpdate(async (change, context) => {
    try {
      const before = change.before.data();
      const after = change.after.data();
      const reportId = context.params.reportId;

      // Only process if status changed
      if (before.status === after.status) {
        return null;
      }

      console.log(`Report ${reportId} status changed from ${before.status} to ${after.status}`);

      // Create email transporter
      const transporter = createTransporter();
      
      if (!transporter) {
        console.warn('Email service not configured. Skipping status change notification.');
        return null;
      }

      // Notify ASHC of status change
      const ashcContact = await getAshcChairpersonContact();
      if (ashcContact) {
        const ashcEmail = ashcContact.email || configuredAshcEmail.value();
        if (!ashcEmail) {
          console.error('ASHC Chairperson email not configured for status notification');
          return { success: false, error: 'ASHC email missing' };
        }

        const statusMessages = {
          'pending': 'Pending - Awaiting investigation',
          'under_investigation': 'Under Investigation - Case is being reviewed',
          'completed': 'Investigation Completed - Findings processed',
          'closed': 'Closed - All procedures completed',
          'resolved': 'Resolved - Case resolution finalized',
        };

        const emailHtml = `
          <html>
            <body style="font-family: Arial, sans-serif;">
              <div style="max-width: 600px; margin: 0 auto; padding: 20px; background: #f9f9f9;">
                <h2 style="color: #003d82;">Report Status Update</h2>
                <p>Dear ${ashcContact.name},</p>
                <p>The status of report <strong>${reportId}</strong> has been updated.</p>
                <div style="background: white; padding: 15px; border-left: 4px solid #003d82; margin: 15px 0;">
                  <p><strong>Previous Status:</strong> ${before.status}</p>
                  <p><strong>New Status:</strong> ${after.status}</p>
                  <p><strong>Status Description:</strong> ${statusMessages[after.status] || after.status}</p>
                </div>
                <p style="color: #666; font-size: 12px;">This is an automated notification from the MUST Sexual Harassment Report System</p>
              </div>
            </body>
          </html>
        `;

        const mailOptions = {
          from: gmailEmail,
          to: ashcEmail,
          subject: `📋 Report Status Update: ${reportId.substring(0, 8).toUpperCase()} - ${after.status}`,
          html: emailHtml,
        };

        await transporter.sendMail(mailOptions);
        console.log(`Status change notification sent to ${ashcEmail}`);
      }

      return { success: true };

    } catch (error) {
      console.error('Error sending status change notification:', error);
      return { success: false, error: error.message };
    }
  });

// Health check function
exports.healthCheck = functions
  .runWith({ secrets: [gmailPassword] })
  .region('europe-west1')
  .https.onRequest((req, res) => {
    const transporter = createTransporter();
    res.json({
      status: 'ok',
      emailConfigured: !!transporter,
      timestamp: new Date().toISOString(),
    });
  });
