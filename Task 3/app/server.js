const http = require('http');

const PORT = process.env.PORT || 3000;
const VERSION = process.env.APP_VERSION || 'dev';

const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'ok', version: VERSION, timestamp: new Date().toISOString() }));
    return;
  }
  res.writeHead(200, { 'Content-Type': 'text/html' });
  res.end(`
    <html>
      <body style="font-family:sans-serif;text-align:center;padding:50px">
        <h1>🚀 GitLab CI/CD Demo App</h1>
        <p>Version: <strong>${VERSION}</strong></p>
        <p>Environment: <strong>${process.env.ENVIRONMENT || 'local'}</strong></p>
      </body>
    </html>
  `);
});

server.listen(PORT, () => {
  console.log(`Server running on port ${PORT} (version: ${VERSION})`);
});
