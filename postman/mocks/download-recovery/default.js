// API responses follow openapi.json. Media fixtures are synthetic HLS payloads;
// the downloader caches them without decoding video.
const http = require('http');
const base = 'http://127.0.0.1:4928/downloads';
http.createServer((req, res) => {
  const url = new URL(req.url, base);
  const send = (code, body, type = 'application/json', headers = {}) => {
    const data = Buffer.from(typeof body === 'string' ? body : JSON.stringify(body));
    res.writeHead(code, {'Content-Type': type, 'Content-Length': data.length, ...headers});
    res.end(data);
  };
  if (url.pathname === '/api/v2/stream-movie' || url.pathname === '/api/v2/stream-tv') {
    if (url.searchParams.get('provider') !== 'original') return send(400, {success:false, error:'Invalid provider'});
    const id = Number(url.searchParams.get('tmdbId'));
    if (id === 49 && url.searchParams.get('full')) return send(400, {success:false, error:'Full stream collection is disabled'});
    if (id === 48) return send(500, '<html>Unavailable</html>', 'text/html');
    if (id === 50) return send(200, '<html>Broken response</html>', 'text/html');
    let links = [{server:id === 46 ? 'other' : 'original-server', url:base + '/fresh.m3u8',
      quality:id === 43 ? '1080p' : '720p', isM3U8:id !== 47, isDASH:id === 47,
      headers:{'X-Stream-Generation':'fresh'}, subtitles:[]}];
    if (id === 45) links.push({...links[0], url:base+'/ambiguous.m3u8'});
    return send(200, {success:true, provider:id === 44 ? 'other' : 'original', links});
  }
  if (url.pathname === '/old.m3u8' || url.pathname === '/fresh.m3u8') {
    return send(200, '#EXTM3U\n#EXT-X-TARGETDURATION:10\n#EXT-X-MEDIA-SEQUENCE:0\n#EXTINF:10,\n' + base + '/one.ts\n#EXTINF:10,\n' + base + '/two.ts\n#EXT-X-ENDLIST\n', 'application/vnd.apple.mpegurl');
  }
  if (url.pathname === '/one.ts') {
    const mode = url.searchParams.get('mode');
    const fresh = req.headers['x-stream-generation'] === 'fresh';
    let data = 'verified-segment-one'.repeat(2048);
    let etag = mode === 'noetag' ? null : mode === 'weak' ? 'W/"one-v1"' : '"one-v1"';
    if (fresh && mode === 'changed') { data = 'modified-segment-one'.repeat(2048); etag = '"one-v2"'; }
    if (fresh && mode === 'length') data += 'new bytes';
    return send(200, data, 'video/mp2t', etag ? {ETag:etag} : {});
  }
  if (url.pathname === '/two.ts') {
    if (req.headers['x-stream-generation'] !== 'fresh') return send(403, {error:'Token expired'});
    return send(200, 'fresh-segment-two'.repeat(2048), 'video/mp2t', {ETag:'"two-v1"'});
  }
  return send(501, {error:'Endpoint not modeled'});
}).listen(process.env.PORT);
