// Synthetic HEAD endpoints and Google-compatible DNS JSON, following
// https://developers.google.com/speed/public-dns/docs/doh/json
// No ad creative, publisher tag, account, or impression is involved.
const http = require('http');
http.createServer((req, res) => {
  const url = new URL(req.url, 'http://localhost');
  if (url.pathname === '/hang') return;
  if (url.pathname === '/dns') {
    const name = url.searchParams.get('name');
    const type = url.searchParams.get('type') === 'AAAA' ? 28 : 1;
    if (name === 'unreadable.example') {
      res.writeHead(200, {'Content-Type': 'text/html'});
      return res.end('<html>Captive portal</html>');
    }
    res.writeHead(200, {'Content-Type': 'application/json'});
    return res.end(JSON.stringify({
      Status: name === 'retired.example' ? 3 : 0,
      Answer: name === 'ipv6.example' && type === 28
        ? [{type: 28, data: '2606:4700::1111'}] : [],
    }));
  }
  if (req.method !== 'HEAD') { res.writeHead(501); return res.end(); }
  const status = {'/healthy': 204, '/error': 503, '/missing': 404,
    '/redirect': 302}[url.pathname];
  res.writeHead(status || 501, status === 302 ? {Location: '/healthy'} : {});
  res.end();
}).listen(process.env.PORT);
