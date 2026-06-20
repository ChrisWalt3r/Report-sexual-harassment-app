const functions = require('firebase-functions');
const admin = require('firebase-admin');
const nodemailer = require('nodemailer');
require('dotenv').config();
const { defineString, defineSecret } = require('firebase-functions/params');

// Initialize Firebase Admin SDK
admin.initializeApp();

// Define params (modern replacement for functions.config())
const gmailEmail = defineString('GMAIL_EMAIL');
const gmailPassword = defineSecret('GMAIL_PASSWORD');
const groqApiKey = defineSecret('GROQ_API_KEY');

function _getEnv(name, fallback = '') {
  const value = _normalizeText(process.env[name]);
  return value || fallback;
}

function _getBoolEnv(name, fallback = false) {
  const value = _normalizeText(process.env[name]).toLowerCase();
  if (!value) return fallback;
  return value === 'true' || value === '1' || value === 'yes';
}

function _getMailFromAddress(emailOverride = '') {
  const email =
    _normalizeText(emailOverride) ||
    _getEnv('MAIL_FROM') ||
    _getEnv('SMTP_USER') ||
    _getEnv('GMAIL_EMAIL') ||
    gmailEmail.value();
  const name = _getEnv(
    'MAIL_FROM_NAME',
    'MUST Sexual Harassment Response Team',
  );
  return name ? `"${name}" <${email}>` : email;
}

// Helper function to create email transporter
function createTransporter(senderEmailOverride = '') {
  const email =
    _normalizeText(senderEmailOverride) ||
    _getEnv('SMTP_USER') ||
    _getEnv('GMAIL_EMAIL') ||
    gmailEmail.value();
  const password = _getEnv('SMTP_PASS') || _getEnv('GMAIL_PASSWORD') || gmailPassword.value();
  const host = _getEnv('SMTP_HOST', 'smtp.gmail.com');
  const port = Number.parseInt(_getEnv('SMTP_PORT', '587'), 10);
  const secure = _getBoolEnv('SMTP_SECURE', false);
  
  if (!email || !password) {
    return null;
  }
  
  return nodemailer.createTransport({
    host,
    port: Number.isFinite(port) ? port : 587,
    secure,
    auth: {
      user: email,
      pass: password,
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
        gmailEmail:
          _normalizeText(data?.gmailEmail) ||
          _getEnv('MAIL_FROM') ||
          _getEnv('SMTP_USER') ||
          _getEnv('GMAIL_EMAIL') ||
          gmailEmail.value(),
        ashcChairpersonEmail:
          _normalizeText(data?.ashcChairpersonEmail),
        groqApiKey: _normalizeText(data?.groqApiKey) || '',
      };
    }
  } catch (error) {
    console.warn('Failed to load email config from Firestore:', error.message);
  }
  // Fallback to environment variables
  return {
    gmailEmail:
      _getEnv('MAIL_FROM') ||
      _getEnv('SMTP_USER') ||
      _getEnv('GMAIL_EMAIL') ||
      gmailEmail.value(),
    ashcChairpersonEmail: '',
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

function _escapeHtml(value) {
  return _normalizeText(value)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function _renderTemplate(template, replacements) {
  let output = _normalizeText(template);
  Object.entries(replacements).forEach(([key, value]) => {
    const token = new RegExp(`{{\\s*${key}\\s*}}`, 'g');
    output = output.replace(token, _normalizeText(value));
  });
  return output;
}

function _plainTextToHtml(text) {
  return _escapeHtml(text).replace(/\n/g, '<br>');
}

function _buildReportSubmissionEmail({
  reportId,
  ashcName,
  criticalityLabel,
  criticality,
  incidentTypes,
  location,
  reportData,
  timestamp,
}) {
  return `
    <html>
      <head>
        <style>
          body { margin: 0; padding: 24px; background: #f3f6f8; font-family: Arial, sans-serif; line-height: 1.6; color: #24323d; }
          .container { max-width: 720px; margin: 0 auto; background: #ffffff; border: 1px solid #dbe3e8; border-radius: 14px; overflow: hidden; }
          .header { background: linear-gradient(135deg, #0f5d35 0%, #1f7a48 100%); color: white; padding: 24px 28px; }
          .eyebrow { font-size: 12px; letter-spacing: 0.08em; text-transform: uppercase; opacity: 0.88; margin-bottom: 8px; }
          .header h1 { margin: 0; font-size: 24px; font-weight: 700; }
          .header p { margin: 10px 0 0; color: rgba(255,255,255,0.92); font-size: 14px; }
          .content { padding: 28px; }
          .intro { margin: 0 0 18px; font-size: 15px; }
          .summary { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 12px; margin: 0 0 22px; }
          .summary-card { background: #f7faf8; border: 1px solid #dbe7df; border-radius: 12px; padding: 14px; }
          .summary-label { font-size: 11px; text-transform: uppercase; letter-spacing: 0.05em; color: #64707d; margin-bottom: 6px; }
          .summary-value { font-size: 18px; font-weight: 700; color: #0f5d35; }
          .section { margin-bottom: 22px; }
          .section-title { font-size: 15px; font-weight: 700; color: #16364f; margin: 0 0 12px; padding-bottom: 8px; border-bottom: 1px solid #dbe3e8; }
          .field-table { width: 100%; border-collapse: collapse; }
          .field-table td { padding: 10px 0; vertical-align: top; border-bottom: 1px solid #eef2f5; }
          .field-table td:first-child { width: 180px; color: #5e6b77; font-weight: 600; padding-right: 16px; }
          .notice { background: #fff8e6; border: 1px solid #f0d37a; border-radius: 12px; padding: 14px 16px; color: #5d4a09; }
          .footer { background: #f7f9fb; border-top: 1px solid #dbe3e8; padding: 18px 28px; font-size: 12px; color: #5e6b77; }
          .footer p { margin: 0 0 6px; }
          @media only screen and (max-width: 640px) {
            body { padding: 12px; }
            .content { padding: 20px; }
            .summary { grid-template-columns: 1fr; }
            .field-table td:first-child { width: 120px; }
          }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <div class="eyebrow">SafeReport Notification</div>
            <h1>New Report Requiring Committee Review</h1>
            <p>An official SafeReport submission has been received and routed for ASHC attention.</p>
          </div>
          <div class="content">
            <p class="intro">Dear <strong>${ashcName}</strong>,</p>
            <p class="intro">A new sexual harassment report has been submitted through SafeReport. Please review the case details and proceed in accordance with MUST policy and committee procedure.</p>

            <div class="summary">
              <div class="summary-card">
                <div class="summary-label">Urgency Level</div>
                <div class="summary-value">${criticalityLabel}</div>
              </div>
              <div class="summary-card">
                <div class="summary-label">Risk Score</div>
                <div class="summary-value">${criticality.score}/100</div>
              </div>
              <div class="summary-card">
                <div class="summary-label">Target Review Window</div>
                <div class="summary-value">${criticality.slaHours} hr</div>
              </div>
            </div>

            <div class="section">
              <div class="section-title">Triage Summary</div>
              <table class="field-table" role="presentation">
                <tr>
                  <td>Assessment source</td>
                  <td>${criticality.source || 'System triage'}</td>
                </tr>
                <tr>
                  <td>Risk indicators</td>
                  <td>${criticality.signals?.length ? criticality.signals.join(', ') : 'No strong indicators detected'}</td>
                </tr>
                <tr>
                  <td>Rationale</td>
                  <td>${criticality.rationale}</td>
                </tr>
              </table>
            </div>

            <div class="section">
              <div class="section-title">Report Record</div>
              <table class="field-table" role="presentation">
                <tr>
                  <td>Report ID</td>
                  <td><strong>${reportId}</strong></td>
                </tr>
                <tr>
                  <td>Tracking ID</td>
                  <td><strong>${reportId.substring(0, 8).toUpperCase()}</strong></td>
                </tr>
                <tr>
                  <td>Submitted</td>
                  <td>${timestamp}</td>
                </tr>
                <tr>
                  <td>Status</td>
                  <td><strong>PENDING</strong> - Awaiting investigation</td>
                </tr>
              </table>
            </div>

            <div class="section">
              <div class="section-title">Incident Information</div>
              <table class="field-table" role="presentation">
                <tr>
                  <td>Type(s)</td>
                  <td>${Array.isArray(incidentTypes) ? incidentTypes.join(', ') : incidentTypes}</td>
                </tr>
                <tr>
                  <td>Location</td>
                  <td>${location}</td>
                </tr>
                <tr>
                  <td>Anonymous report</td>
                  <td>${reportData.isAnonymous ? 'Yes' : 'No'}</td>
                </tr>
              </table>
            </div>

            <div class="section">
              <div class="section-title">Evidence Summary</div>
              <table class="field-table" role="presentation">
                <tr>
                  <td>Images</td>
                  <td>${(reportData.imageUrls?.length || 0)} file(s)</td>
                </tr>
                <tr>
                  <td>Videos</td>
                  <td>${(reportData.videoUrls?.length || 0)} file(s)</td>
                </tr>
                <tr>
                  <td>Audio</td>
                  <td>${(reportData.audioUrls?.length || 0)} file(s)</td>
                </tr>
              </table>
            </div>

            <div class="notice">
              <strong>Action required:</strong> Please sign in to the SafeReport Admin Dashboard to review the full case record, attached evidence, and required next steps. Handle all information in confidence and in line with MUST Sexual Harassment Policy.
            </div>
          </div>
          <div class="footer">
            <p>This is an automated communication from the MUST Sexual Harassment Response Team via SafeReport.</p>
            <p>Please do not reply directly to this email. Use the official dashboard and approved university channels for committee action.</p>
            <p>All report information must be handled confidentially and with due process.</p>
          </div>
        </div>
      </body>
    </html>
  `;
}

function _buildReportAssignmentEmail({
  reportId,
  assigneeName,
  assignerName,
  assignedRole,
  status,
  incidentTypes,
  location,
  reportData,
}) {
  return `
    <html>
      <head>
        <style>
          body { margin: 0; padding: 24px; background: #f3f6f8; font-family: Arial, sans-serif; line-height: 1.6; color: #24323d; }
          .container { max-width: 720px; margin: 0 auto; background: #ffffff; border: 1px solid #dbe3e8; border-radius: 14px; overflow: hidden; }
          .header { background: linear-gradient(135deg, #16364f 0%, #245a7b 100%); color: white; padding: 24px 28px; }
          .eyebrow { font-size: 12px; letter-spacing: 0.08em; text-transform: uppercase; opacity: 0.88; margin-bottom: 8px; }
          .header h1 { margin: 0; font-size: 24px; font-weight: 700; }
          .header p { margin: 10px 0 0; color: rgba(255,255,255,0.92); font-size: 14px; }
          .content { padding: 28px; }
          .intro { margin: 0 0 18px; font-size: 15px; }
          .summary { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 12px; margin: 0 0 22px; }
          .summary-card { background: #f7f9fb; border: 1px solid #dbe3e8; border-radius: 12px; padding: 14px; }
          .summary-label { font-size: 11px; text-transform: uppercase; letter-spacing: 0.05em; color: #64707d; margin-bottom: 6px; }
          .summary-value { font-size: 17px; font-weight: 700; color: #16364f; }
          .section { margin-bottom: 22px; }
          .section-title { font-size: 15px; font-weight: 700; color: #16364f; margin: 0 0 12px; padding-bottom: 8px; border-bottom: 1px solid #dbe3e8; }
          .field-table { width: 100%; border-collapse: collapse; }
          .field-table td { padding: 10px 0; vertical-align: top; border-bottom: 1px solid #eef2f5; }
          .field-table td:first-child { width: 180px; color: #5e6b77; font-weight: 600; padding-right: 16px; }
          .notice { background: #eef6ff; border: 1px solid #bfd7f2; border-radius: 12px; padding: 14px 16px; color: #16364f; }
          .footer { background: #f7f9fb; border-top: 1px solid #dbe3e8; padding: 18px 28px; font-size: 12px; color: #5e6b77; }
          .footer p { margin: 0 0 6px; }
        </style>
      </head>
      <body>
        <div class="container">
          <div class="header">
            <div class="eyebrow">SafeReport Assignment</div>
            <h1>Report Assignment Notification</h1>
            <p>A case has been assigned to you for review and handling within the SafeReport workflow.</p>
          </div>
          <div class="content">
            <p class="intro">Dear <strong>${assigneeName}</strong>,</p>
            <p class="intro">You have been assigned a SafeReport case by <strong>${assignerName}</strong>. Please review the record and take the next appropriate action in line with your committee role and MUST policy.</p>

            <div class="summary">
              <div class="summary-card">
                <div class="summary-label">Assigned Role</div>
                <div class="summary-value">${assignedRole}</div>
              </div>
              <div class="summary-card">
                <div class="summary-label">Tracking ID</div>
                <div class="summary-value">${reportId.substring(0, 8).toUpperCase()}</div>
              </div>
              <div class="summary-card">
                <div class="summary-label">Current Status</div>
                <div class="summary-value">${status}</div>
              </div>
            </div>

            <div class="section">
              <div class="section-title">Case Summary</div>
              <table class="field-table" role="presentation">
                <tr>
                  <td>Report ID</td>
                  <td><strong>${reportId}</strong></td>
                </tr>
                <tr>
                  <td>Assigned by</td>
                  <td>${assignerName}</td>
                </tr>
                <tr>
                  <td>Incident type(s)</td>
                  <td>${Array.isArray(incidentTypes) ? incidentTypes.join(', ') : incidentTypes}</td>
                </tr>
                <tr>
                  <td>Location</td>
                  <td>${location}</td>
                </tr>
                <tr>
                  <td>Anonymous report</td>
                  <td>${reportData.isAnonymous ? 'Yes' : 'No'}</td>
                </tr>
              </table>
            </div>

            <div class="notice">
              <strong>Action required:</strong> Please sign in to the SafeReport Admin Dashboard to review the full report, supporting evidence, and process history. Handle the case confidentially and follow approved committee procedure.
            </div>
          </div>
          <div class="footer">
            <p>This is an automated communication from the MUST Sexual Harassment Response Team via SafeReport.</p>
            <p>Please do not reply directly to this email. Use the official dashboard and approved university channels for case handling.</p>
          </div>
        </div>
      </body>
    </html>
  `;
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
      const emailSubject = `[${criticalityLabel}] New SafeReport Submission - ${reportId.substring(0, 8).toUpperCase()}`;

      const emailHtml = _buildReportSubmissionEmail({
        reportId,
        ashcName,
        criticalityLabel,
        criticality,
        incidentTypes,
        location,
        reportData,
        timestamp,
      });
      const mailOptions = {
        from: _getMailFromAddress(emailConfig.gmailEmail),
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
        ashcContact?.email || emailConfig.ashcChairpersonEmail;
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
          from: _getMailFromAddress(emailConfig.gmailEmail),
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

exports.notifyOnReportAssignment = functions
  .runWith({ secrets: [gmailPassword] })
  .region('europe-west1')
  .firestore.document('reports/{reportId}')
  .onUpdate(async (change, context) => {
    try {
      const before = change.before.data();
      const after = change.after.data();
      const reportId = context.params.reportId;

      const beforeAssignee = _normalizeText(before.assignedToUid || before.assignedToEmail);
      const afterAssignee = _normalizeText(after.assignedToUid || after.assignedToEmail);
      if (!afterAssignee || beforeAssignee === afterAssignee) {
        return null;
      }

      const assigneeEmail = _normalizeText(after.assignedToEmail);
      if (!assigneeEmail) {
        console.warn(`Report ${reportId} was assigned but no assignee email was found.`);
        return null;
      }

      const emailConfig = await getEmailConfig();
      const transporter = createTransporter(emailConfig.gmailEmail);
      if (!transporter) {
        console.warn('Email service not configured. Skipping assignment notification.');
        return null;
      }

      const assigneeName = _normalizeText(after.assignedToName) || 'Committee Member';
      const assignerName =
        _normalizeText(after.assignedByName) ||
        _normalizeText(after.assignedByEmail) ||
        'ASHC Chairperson';
      const assignedRole = _normalizeText(after.assignedToRole) || 'Committee Member';
      const currentStatus = _normalizeText(after.status) || 'submitted';
      const incidentTypes = after.incidentTypes || after.incidentType || 'Not specified';
      const location = after.location || 'Not specified';

      const emailHtml = _buildReportAssignmentEmail({
        reportId,
        assigneeName,
        assignerName,
        assignedRole,
        status: currentStatus.replaceAll('_', ' ').toUpperCase(),
        incidentTypes,
        location,
        reportData: after,
      });

      const mailOptions = {
        from: _getMailFromAddress(emailConfig.gmailEmail),
        to: assigneeEmail,
        subject: `Report Assignment - ${reportId.substring(0, 8).toUpperCase()}`,
        html: emailHtml,
        replyTo: emailConfig.gmailEmail,
      };

      const result = await transporter.sendMail(mailOptions);

      await admin.firestore().collection('notifications_archive').add({
        type: 'report_assignment',
        reportId,
        recipientEmail: assigneeEmail,
        recipientName: assigneeName,
        assignedRole,
        assignedBy: assignerName,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        status: 'sent',
        messageId: result.messageId,
      });

      return { success: true, messageId: result.messageId };
    } catch (error) {
      console.error('Error sending report assignment notification:', error);
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

exports.processCommunicationQueue = functions
  .runWith({ secrets: [gmailPassword] })
  .region('europe-west1')
  .firestore.document('communication_queue/{messageId}')
  .onCreate(async (snap, context) => {
    const data = snap.data() || {};
    const type = _normalizeText(data.type);
    if (type !== 'invitation_email') {
      return null;
    }

    const recipients = _toArray(data.recipients);
    if (!recipients.length) {
      await snap.ref.set(
        {
          status: 'failed',
          error: 'No recipients supplied',
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      return null;
    }

    const emailConfig = await getEmailConfig();
    const transporter = createTransporter(emailConfig.gmailEmail);
    if (!transporter) {
      await snap.ref.set(
        {
          status: 'failed',
          error: 'Email transporter not configured',
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
      return null;
    }

    await snap.ref.set(
      {
        status: 'processing',
        startedAt: admin.firestore.FieldValue.serverTimestamp(),
      },
      { merge: true },
    );

    const subject = _normalizeText(data.subject);
    const messageTemplate = _normalizeText(data.messageTemplate);
    const footer = _normalizeText(data.footer);
    const senderName = _normalizeText(data.senderName) || 'MUST Sexual Harassment Response Team';
    const senderEmail = _normalizeText(data.senderEmail) || emailConfig.gmailEmail;
    const replyToEmail = _normalizeText(data.replyToEmail) || senderEmail;
    const chairpersonName = _normalizeText(data.chairpersonName) || 'ASHC Chairperson';
    const includePlayStoreLink = !!data.includePlayStoreLink;
    const includeWebPortalLink = !!data.includeWebPortalLink;
    const playStoreUrl = _normalizeText(data.playStoreUrl);
    const webPortalUrl = _normalizeText(data.webPortalUrl);
    const mode = _normalizeText(data.mode) || 'bulk';

    let deliveredCount = 0;
    const deliveryLog = [];

    for (const recipient of recipients) {
      const replacements = {
        recipientName: recipient,
        senderName,
        playStoreUrl,
        webPortalUrl,
        chairpersonName,
      };
      const renderedBody = _renderTemplate(messageTemplate, replacements);
      const renderedSubject = _renderTemplate(subject, replacements);

      const linkLines = [
        includePlayStoreLink && playStoreUrl
          ? `Play Store: ${playStoreUrl}`
          : '',
        includeWebPortalLink && webPortalUrl
          ? `Web Portal: ${webPortalUrl}`
          : '',
      ].filter(Boolean);

      const htmlSections = [
        `<p>${_plainTextToHtml(renderedBody)}</p>`,
        linkLines.length
          ? `<p>${linkLines.map((line) => _escapeHtml(line)).join('<br>')}</p>`
          : '',
        footer ? `<p style="color:#666;font-size:12px;">${_plainTextToHtml(footer)}</p>` : '',
      ].filter(Boolean);

      try {
        const result = await transporter.sendMail({
          from: _getMailFromAddress(senderEmail),
          to: recipient,
          subject: mode === 'test' ? `[Test] ${renderedSubject}` : renderedSubject,
          html: `
            <div style="font-family:Arial,sans-serif;max-width:640px;margin:0 auto;padding:24px;background:#ffffff;border:1px solid #e5e7eb;border-radius:12px;">
              <h2 style="color:#0F5D35;margin-top:0;">SafeReport Communication</h2>
              ${htmlSections.join('\n')}
            </div>
          `,
          replyTo: replyToEmail,
        });
        deliveredCount += 1;
        deliveryLog.push({
          email: recipient,
          status: 'sent',
          messageId: result.messageId,
          sentAt: new Date().toISOString(),
        });
      } catch (error) {
        deliveryLog.push({
          email: recipient,
          status: 'failed',
          error: error.message,
          failedAt: new Date().toISOString(),
        });
      }
    }

    const finalStatus = deliveredCount === recipients.length
      ? 'sent'
      : deliveredCount > 0
        ? 'partial'
        : 'failed';

    await snap.ref.set(
      {
        status: finalStatus,
        deliveredCount,
        failedCount: recipients.length - deliveredCount,
        processedAt: admin.firestore.FieldValue.serverTimestamp(),
        deliveryLog,
      },
      { merge: true },
    );

    await admin.firestore().collection('notifications_archive').add({
      type: 'invitation_email',
      queueId: context.params.messageId,
      mode,
      recipientCount: recipients.length,
      deliveredCount,
      createdByEmail: _normalizeText(data.createdByEmail),
      status: finalStatus,
      processedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return null;
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
      from: _getMailFromAddress(),
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
