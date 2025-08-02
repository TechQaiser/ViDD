import express from 'express';
import fetch from 'node-fetch';
import HttpsProxyAgent from 'https-proxy-agent';

const app = express();
const PORT = process.env.PORT || 3000;

// Your paid proxy (username:password@IP:port)
const proxy = 'http://jvgSsvhgOjvDWSD:jYWDFWfSWuzbqDW@207.135.200.39:48594';

app.get('/', async (req, res) => {
  const url = req.query.url;
  if (!url) return res.status(400).send('Missing ?url parameter');

  try {
    const agent = new HttpsProxyAgent(proxy);
    const response = await fetch(url, { agent });

    // Stream the response directly to browser
    res.status(response.status);
    response.body.pipe(res);
  } catch (err) {
    console.error(err);
    res.status(500).send('Proxy fetch error');
  }
});

app.listen(PORT, () => console.log(`Proxy server running on port ${PORT}`));
