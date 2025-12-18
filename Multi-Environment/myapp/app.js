const http = require('http');
const port = 8080;

const server = http.createServer((req, res) => {
  res.statusCode = 200;
  res.setHeader('Content-Type', 'application/json');
  res.end(JSON.stringify({
    message: 'Hello from myapp!',
    environment: process.env.ENV || 'unknown',
    version: process.env.VERSION || 'dev'
  }));
});

server.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
