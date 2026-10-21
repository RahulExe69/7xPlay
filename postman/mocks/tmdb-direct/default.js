// Local connectivity fixture: an ISP block page, not a TMDB API error.
const http = require('http');
http.createServer((req, res) => {
  if (req.url.startsWith('/3/')) {
    res.writeHead(451, {'content-type': 'text/html'});
    return res.end('<html>Blocked by network</html>');
  }
  res.writeHead(501);
  res.end('Endpoint not modeled');
}).listen(process.env.PORT);
