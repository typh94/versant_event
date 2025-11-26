// Minimal Express server to serve Flutter web build on Railway
const express = require('express');
const path = require('path');
const nodemailer = require('nodemailer');
const cors = require('cors');

const app = express();
const PORT = process.env.PORT || 3000;

// CORS (allow cross-origin when Flutter web is hosted separately)
app.use(cors({ origin: true }));

// Parse JSON bodies (increase limit for base64 PDFs)
app.use(express.json({ limit: '25mb' }));

const buildDir = path.join(__dirname, 'build');

// Static assets with sensible cache headers
app.use(
  express.static(buildDir, {
    extensions: ['html'],
    setHeaders: (res, filePath) => {
      // Cache hashed assets for a long time
      if (/\.(?:js|css|png|jpg|jpeg|gif|webp|svg|ico|woff2?)$/i.test(filePath)) {
        res.setHeader('Cache-Control', 'public, max-age=31536000, immutable');
      }
      // index.html should not be cached
      if (filePath.endsWith('index.html')) {
        res.setHeader('Cache-Control', 'no-store');
      }
    },
  })
);

// Nodemailer transporter factory
function createTransporter() {
  return nodemailer.createTransport({
    host: process.env.SMTP_HOST,
    port: Number(process.env.SMTP_PORT || 587),
    secure: String(process.env.SMTP_SECURE || 'false') === 'true',
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS,
    },
  });
}

// Health check for SMTP configuration
app.get('/email-health', async (req, res) => {
  try {
    const transporter = createTransporter();
    await transporter.verify();
    res.json({ ok: true });
  } catch (err) {
    console.error('SMTP verify failed:', err);
    res.status(500).json({ ok: false, error: 'SMTP verify failed' });
  }
});

// Email sending endpoint for Flutter Web
// Expects JSON: { to, cc, subject, body, filename, pdfBase64 }
app.post('/send-email', async (req, res) => {
  try {
    const { to, cc, subject, body, filename, pdfBase64 } = req.body || {};
    if (!to || !subject || !body || !filename || !pdfBase64) {
      return res.status(400).json({ ok: false, error: 'Missing required fields' });
    }

    // Configure SMTP transport via environment variables
    // Required: SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS
    // Optional: SMTP_SECURE ("true"/"false"), SMTP_FROM
    const transporter = nodemailer.createTransport({
      host: process.env.SMTP_HOST,
      port: Number(process.env.SMTP_PORT || 587),
      secure: String(process.env.SMTP_SECURE || 'false') === 'true',
      auth: {
        user: process.env.SMTP_USER,
        pass: process.env.SMTP_PASS,
      },
    });

    const from = process.env.SMTP_FROM || process.env.SMTP_USER;
    const info = await transporter.sendMail({
      from,
      to,
      cc,
      subject,
      text: body,
      attachments: [
        {
          filename,
          content: Buffer.from(pdfBase64, 'base64'),
          contentType: 'application/pdf',
        },
      ],
    });

    return res.json({ ok: true, messageId: info.messageId });
  } catch (err) {
    console.error('Email send failed:', err);
    return res.status(500).json({ ok: false, error: 'Email send failed' });
  }
});

// SPA fallback to index.html
app.get('*', (req, res) => {
  res.sendFile(path.join(buildDir, 'index.html'));
});

app.listen(PORT, () => {
  console.log(`Server started on port ${PORT}`);
});
