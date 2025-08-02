const express = require("express");
const cors = require("cors");
const fetch = require("node-fetch");

const app = express();
app.use(cors());

const PORT = process.env.PORT || 8080;

// Root check
app.get("/", (req, res) => {
  res.send("✅ Proxy Server Active");
});

// Streaming endpoint for RapidAPI links
app.get("/stream", async (req, res) => {
  const fileUrl = req.query.url;

  if (!fileUrl) return res.status(400).send("Missing ?url=");

  try {
    // Fetch with browser headers to bypass 403
    const response = await fetch(fileUrl, {
      headers: {
        "User-Agent":
          "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
        "Accept": "*/*",
        "Accept-Language": "en-US,en;q=0.9",
        "Referer": "https://www.youtube.com/",
        "Origin": "https://www.youtube.com/",
      },
    });

    // Forward status & headers
    res.status(response.status);
    response.body.pipe(res);
  } catch (err) {
    res.status(500).send("Error: " + err.message);
  }
});

app.listen(PORT, () => console.log(`🚀 Proxy running on port ${PORT}`));
