// Minimal Express server to serve Flutter web build on Railway
const express = require('express');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 3000;

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

// SPA fallback to index.html
app.get('*', (req, res) => {
  res.sendFile(path.join(buildDir, 'index.html'));
});

app.listen(PORT, () => {
  console.log(`Server started on port ${PORT}`);
});
