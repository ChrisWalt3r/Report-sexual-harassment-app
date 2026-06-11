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
const groqApiKey = defineSecret('GROQ_API_KEY');

// Helper function to create email transporter
function createTransporter(senderEmailOverride = '') {
  const email = _normalizeText(senderEmailOverride) || gmailEmail.value();
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

function _normalizeText(value) {
  return (value || '').toString().trim();
}

function _toArray(value) {
  if (Array.isArray(value)) {
    return value.filter((x) => x !== null && x !== undefined).map((x) => x.toString().trim()).filter(Boolean);
  }
  const text = _normalizeText(value);
  if (!text) return [];
  return text.split(',').map((x) => x.trim()).filter(Boolean);
}

function _deriveCriticalityLevel(score) {
  if (score >= 85) return 'critical';
  if (score >= 65) return 'high';
  if (score >= 40) return 'medium';
  return 'low';
}

function _triageSlaHours(level) {
  switch (level) {
    case 'critical':
      return 1;
    case 'high':
      return 6;
    case 'medium':
      return 24;
    default:
      return 72;
  }
}

function _levelEmoji(level) {
  switch (level) {
    case 'critical':
      return '🚨';
    case 'high':
      return '⚠️';
    case 'medium':
      return '🟡';
    default:
      return '🟢';
  }
}

function _heuristicCriticalityAnalysis(reportData) {
  const description = _normalizeText(reportData.description).toLowerCase();
  const location = _normalizeText(reportData.location).toLowerCase();
  const incidentTypes = _toArray(reportData.incidentTypes || reportData.incidentType).map((x) => x.toLowerCase());
  const perpetratorInfo = _normalizeText(reportData.perpetratorInfo).toLowerCase();

  const signals = [];
  let score = 20;

  const criticalKeywords = [
    'immediate danger', 'danger', 'threat', 'threaten', 'weapon', 'assault', 'rape',
    'forced', 'violence', 'beating', 'kill', 'suicide', 'cannot escape', 'happening now',
  ];
  const highKeywords = [
    'stalking', 'blackmail', 'coercion', 'retaliation', 'forced touch', 'physical',
    'drugged', 'abduction', 'unsafe', 'fear for my safety',
  ];

  if (criticalKeywords.some((k) => description.includes(k))) {
    score += 40;
    signals.push('critical danger language in description');
  }

  if (highKeywords.some((k) => description.includes(k))) {
    score += 25;
    signals.push('high-risk language in description');
  }

  const highRiskTypeKeywords = [
    'sexual assault',
    'quid pro quo',
    'dating violence',
    'stalking',
    'hostile environment',
    'sexual exploitation',
  ];
  if (incidentTypes.some((t) => highRiskTypeKeywords.some((kw) => t.includes(kw)))) {
    score += 18;
    signals.push('high-risk incident type');
  }

  if (reportData.audioUrls?.length || reportData.videoUrls?.length) {
    score += 10;
    signals.push('audio/video evidence attached');
  } else if (reportData.imageUrls?.length) {
    score += 6;
    signals.push('image evidence attached');
  }

  if (perpetratorInfo.includes('lecturer') || perpetratorInfo.includes('staff') || perpetratorInfo.includes('supervisor')) {
    score += 8;
    signals.push('power-imbalance indicator (staff/supervisor)');
  }

  if (location.includes('hostel') || location.includes('night') || location.includes('off campus')) {
    score += 6;
    signals.push('potentially unsafe location context');
  }

  score = Math.max(0, Math.min(100, score));
  const level = _deriveCriticalityLevel(score);
  return {
    score,
    level,
    signals,
    rationale: `Heuristic triage detected ${signals.length} risk signal(s).`,
  };
}

function _extractFirstJsonObject(text) {
  const content = (text || '').trim();
  const first = content.indexOf('{');
  const last = content.lastIndexOf('}');
  if (first < 0 || last <= first) return null;
  return content.slice(first, last + 1);
}

async function _aiCriticalityAnalysis(reportData, overrideGroqKey = '') {
  let key = overrideGroqKey || '';
  if (!key) {
    try {
      key = groqApiKey.value() || '';
    } catch (_) {
      key = '';
    }
  }
  if (!key) {
    return null;
  }

  const evidenceCount = {
    images: reportData.imageUrls?.length || 0,
    videos: reportData.videoUrls?.length || 0,
    audios: reportData.audioUrls?.length || 0,
  };

  const payload = {
    description: _normalizeText(reportData.description),
    incidentTypes: _toArray(reportData.incidentTypes || reportData.incidentType),
    location: _normalizeText(reportData.location),
    date: _normalizeText(reportData.date),
    time: _normalizeText(reportData.time),
    perpetratorInfo: _normalizeText(reportData.perpetratorInfo),
    witnesses: _normalizeText(reportData.witnesses),
    complainantResponse: _normalizeText(reportData.complainantResponse),
    isAnonymous: !!reportData.isAnonymous,
    evidenceCount,
  };

  const systemPrompt = [
    'You are a triage classifier for sexual harassment reports in a university safety system.',
    'Classify urgency as one of: low, medium, high, critical.',
    'Return STRICT JSON only with keys: level, score, rationale, signals.',
    'score must be an integer from 0-100.',
    'signals must be a short array of concrete risk indicators.',
    'Be conservative: immediate danger, violence, ongoing threat, or severe coercion should push to high/critical.',
  ].join(' ');

  const userPrompt = `Report payload:\n${JSON.stringify(payload, null, 2)}`;

  try {
    const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${key}`,
      },
      body: JSON.stringify({
        model: 'llama-3.1-8b-instant',
        temperature: 0.1,
        max_tokens: 220,
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: userPrompt },
        ],
      }),
    });

    if (!response.ok) {
      const errBody = await response.text();
      throw new Error(`Groq request failed: ${response.status} ${errBody}`);
    }

    const data = await response.json();
    const content = data?.choices?.[0]?.message?.content;
    const parsedJsonText = _extractFirstJsonObject(content);
    if (!parsedJsonText) {
      throw new Error('AI response did not contain JSON object');
    }

    const parsed = JSON.parse(parsedJsonText);
    const aiScore = Number.isFinite(parsed?.score) ? Math.round(parsed.score) : null;
    const aiLevel = _normalizeText(parsed?.level).toLowerCase();
    const allowedLevels = new Set(['low', 'medium', 'high', 'critical']);

    if (aiScore === null || aiScore < 0 || aiScore > 100 || !allowedLevels.has(aiLevel)) {
      throw new Error('AI response had invalid score/level');
    }

    return {
      score: aiScore,
      level: aiLevel,
      rationale: _normalizeText(parsed?.rationale) || 'AI triage rationale unavailable.',
      signals: _toArray(parsed?.signals).slice(0, 8),
    };
  } catch (error) {
    console.warn('AI criticality analysis failed, falling back to heuristics:', error.message);
    return null;
  }
}

async function analyzeReportCriticality(reportData, overrideGroqKey = '') {
  const heuristic = _heuristicCriticalityAnalysis(reportData);
  const ai = await _aiCriticalityAnalysis(reportData, overrideGroqKey);

  let finalScore = heuristic.score;
  let source = 'heuristic';
  let rationale = heuristic.rationale;
  let signals = [...heuristic.signals];

  if (ai) {
    source = 'ai+heuristic';
    finalScore = Math.round(heuristic.score * 0.35 + ai.score * 0.65);
    finalScore = Math.max(0, Math.min(100, finalScore));
    rationale = ai.rationale || heuristic.rationale;
    signals = [...new Set([...heuristic.signals, ...(ai.signals || [])])].slice(0, 10);
  }

  const level = _deriveCriticalityLevel(finalScore);
  const slaHours = _triageSlaHours(level);

  return {
    level,
    score: finalScore,
    source,
    rationale,
    signals,
    slaHours,
    requiresImmediateAttention: level === 'critical' || level === 'high',
    analyzedAt: new Date().toISOString(),
    model: ai ? 'llama-3.1-8b-instant' : null,
  };
}

async function getUrgencyAdminEmails() {
  const snapshot = await admin
    .firestore()
    .collection('admins')
    .limit(200)
    .get();

  if (snapshot.empty) {
    return [];
  }

  const escalationRoles = new Set([
    'superAdmin',
    'chairperson',
    'committeeMember',
    'reviewer',
    'moderator',
    'devTeam',
  ]);

  const all = snapshot.docs
    .map((doc) => doc.data())
    .filter((x) => x?.email)
    .filter((x) => x?.isActive !== false && x?.active !== false)
    .map((x) => ({
      email: x.email.toString().trim(),
      role: _normalizeText(x.shcRole || x.role),
    }));

  const prioritized = all.filter((x) => escalationRoles.has(x.role));
  const selected = prioritized.length > 0 ? prioritized : all;
  return [...new Set(selected.map((x) => x.email).filter(Boolean))];
}

async function getEmailConfig() {
  try {
    const doc = await admin.firestore().collection('app_config').doc('email_settings').get();
    if (doc.exists) {
      const data = doc.data();
      return {
        gmailEmail: _normalizeText(data?.gmailEmail) || gmailEmail.value(),
        ashcChairpersonEmail: _normalizeText(data?.ashcChairpersonEmail) || configuredAshcEmail.value(),
        groqApiKey: _normalizeText(data?.groqApiKey) || '',
      };
    }
  } catch (error) {
    console.warn('Failed to load email config from Firestore:', error.message);
  }
  // Fallback to environment variables
  return {
    gmailEmail: gmailEmail.value(),
    ashcChairpersonEmail: configuredAshcEmail.value(),
    groqApiKey: '',
  };
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
  .runWith({ secrets: [gmailPassword, groqApiKey] })
  .region('europe-west1') // Use appropriate region for your app
  .firestore.document('reports/{reportId}')
  .onCreate(async (snap, context) => {
    try {
      const reportData = snap.data();
      const reportId = context.params.reportId;

      // Log for monitoring
      console.log(`New report submitted: ${reportId}`, reportData);

      // Load email configuration from Firestore
      const emailConfig = await getEmailConfig();

      // Create email transporter
      const transporter = createTransporter(emailConfig.gmailEmail);
      
      // Check if email is configured
      if (!transporter) {
        console.warn('Email service not configured. Skipping email notification.');
        console.log('To enable emails, set GMAIL_EMAIL and GMAIL_PASSWORD parameters');
        return null;
      }

      // Get ASHC Chairperson contact
      const ashcContact = await getAshcChairpersonContact();
      const ashcEmail = ashcContact?.email || emailConfig.ashcChairpersonEmail;
      const ashcName = ashcContact?.name || 'ASHC Chairperson';

      if (!ashcEmail) {
        console.error('ASHC Chairperson email not configured');
        return null;
      }

      if (!ashcContact) {
        console.warn('ASHC Chairperson contact not found in database. Falling back to configured ASHC email.');
      }

      // Analyze urgency/criticality using AI (with heuristic fallback)
      const criticality = await analyzeReportCriticality(reportData, emailConfig.groqApiKey);
      await snap.ref.set(
        {
          criticalityLevel: criticality.level,
          criticalityScore: criticality.score,
          requiresImmediateAttention: criticality.requiresImmediateAttention,
          triageSlaHours: criticality.slaHours,
          triageLastAnalyzedAt: admin.firestore.FieldValue.serverTimestamp(),
          aiCriticality: criticality,
        },
        { merge: true }
      );

      const recipientSet = new Set([ashcEmail]);
      if (criticality.requiresImmediateAttention) {
        const urgencyRecipients = await getUrgencyAdminEmails();
        urgencyRecipients.forEach((email) => recipientSet.add(email));
      }
      const recipients = [...recipientSet].filter(Boolean);
      const primaryRecipient = recipients[0];
      const bccRecipients = recipients.slice(1);

      // Prepare email content
      const incidentTypes = reportData.incidentTypes || reportData.incidentType || 'Not specified';
      const location = reportData.location || 'Not specified';
      const timestamp = reportData.timestamp ? new Date(reportData.timestamp.toDate()).toLocaleString('en-US') : 'Just now';

      const criticalityLabel = criticality.level.toUpperCase();
      const levelEmoji = _levelEmoji(criticality.level);
      const emailSubject = `${levelEmoji} [${criticalityLabel}] NEW REPORT - Tracking ID: ${reportId.substring(0, 8).toUpperCase()}`;

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
                <p>Dear <strong>${ashcName}</strong>,</p>
                
                <p style="color: #c41e3a; font-weight: bold;">A new sexual harassment report has been submitted and requires your attention.</p>

                <div class="section">
                  <div class="section-title">🚦 AI Criticality Triage</div>
                  <div class="field">
                    <span class="label">Urgency Level:</span>
                    <span class="value"><strong>${criticalityLabel}</strong></span>
                  </div>
                  <div class="field">
                    <span class="label">Risk Score:</span>
                    <span class="value"><strong>${criticality.score}/100</strong></span>
                  </div>
                  <div class="field">
                    <span class="label">Target SLA:</span>
                    <span class="value">Review within <strong>${criticality.slaHours} hour(s)</strong></span>
                  </div>
                  <div class="field">
                    <span class="label">Signals:</span>
                    <span class="value">${criticality.signals?.length ? criticality.signals.join(', ') : 'No strong signals detected'}</span>
                  </div>
                  <div class="field">
                    <span class="label">Rationale:</span>
                    <span class="value">${criticality.rationale}</span>
                  </div>
                </div>

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
        from: emailConfig.gmailEmail,
        to: primaryRecipient,
        bcc: bccRecipients.length ? bccRecipients.join(',') : undefined,
        cc: '', // Can add more recipients here if needed
        subject: emailSubject,
        html: emailHtml,
        replyTo: emailConfig.gmailEmail,
      };

      const result = await transporter.sendMail(mailOptions);
      console.log(`Email sent successfully to ${recipients.length} recipient(s). Message ID: ${result.messageId}`);

      // Log the notification in Firestore for auditing
      await admin.firestore()
        .collection('notifications_archive')
        .add({
          type: 'ashc_report_submitted',
          reportId: reportId,
          recipientEmail: primaryRecipient,
          recipientCount: recipients.length,
          recipientName: ashcName,
          criticalityLevel: criticality.level,
          criticalityScore: criticality.score,
          triageSlaHours: criticality.slaHours,
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

      const emailConfig = await getEmailConfig();

      // Create email transporter
      const transporter = createTransporter(emailConfig.gmailEmail);
      
      if (!transporter) {
        console.warn('Email service not configured. Skipping status change notification.');
        return null;
      }

      // Notify ASHC of status change
      const ashcContact = await getAshcChairpersonContact();
      const ashcEmail =
        ashcContact?.email || emailConfig.ashcChairpersonEmail || configuredAshcEmail.value();
      const ashcName = ashcContact?.name || 'ASHC Chairperson';
      if (ashcEmail) {

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
                <p>Dear ${ashcName},</p>
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
          from: emailConfig.gmailEmail || gmailEmail.value(),
          to: ashcEmail,
          subject: `📋 Report Status Update: ${reportId.substring(0, 8).toUpperCase()} - ${after.status}`,
          html: emailHtml,
        };

        await transporter.sendMail(mailOptions);
        console.log(`Status change notification sent to ${ashcEmail}`);
      } else {
        console.error('ASHC Chairperson email not configured for status notification');
        return { success: false, error: 'ASHC email missing' };
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

// --- Admin Invite Email Function ---
exports.sendAdminInviteEmail = functions.firestore
  .document('admin_invites/{inviteId}')
  .onCreate(async (snap, context) => {
    const data = snap.data();
    const email = data.email;
    const token = data.token;
    const role = data.role;
    const invitedBy = data.invitedBy;
    const link = `https://your-app.com/invite-accept?token=${token}`;
    const transporter = createTransporter();
    if (!transporter) {
      console.error('Email transporter not configured.');
      return null;
    }
    const mailOptions = {
      from: gmailEmail.value(),
      to: email,
      subject: 'Admin Invitation',
      html: `<p>You have been invited as <b>${role}</b> by ${invitedBy}.<br>
        Click <a href="${link}">here</a> to accept your invitation.</p>`
    };
    try {
      await transporter.sendMail(mailOptions);
      console.log('Invite email sent to', email);
    } catch (err) {
      console.error('Failed to send invite email:', err);
    }
    return null;
  });
