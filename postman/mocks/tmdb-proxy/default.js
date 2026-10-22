// Minimum responses consumed by the existing configuration and catalog parsers.
// No external network calls, authentication or paid proxy usage.
const http = require('http');
http.createServer((req, res) => {
  const url = new URL(req.url, 'http://localhost');
  let destination;
  try { destination = new URL(url.searchParams.get('destination')); } catch (_) {}
  if (!destination) {
    res.writeHead(400);
    return res.end('{}');
  }
  res.setHeader('content-type', 'application/json');
  if (destination.pathname.endsWith('/3/configuration')) {
    return res.end(JSON.stringify({images: {secure_base_url: 'https://image.tmdb.org/t/p/'}}));
  }
  if (/\/3\/(search\/(movie|tv|person)|movie\/(popular|top_rated)|tv\/popular|trending\/(movie|tv)\/(day|week))$/.test(destination.pathname)) {
    return res.end(JSON.stringify({page: 1, total_pages: 1, total_results: 1,
      results: [{id: 1, title: destination.searchParams.get('query') || 'Fixture title',
        name: destination.searchParams.get('query') || 'Fixture title'}]}));
  }
  res.writeHead(501);
  res.end(JSON.stringify({error: 'Endpoint not modeled'}));
}).listen(process.env.PORT);
