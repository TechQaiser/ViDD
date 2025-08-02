// =========================
// VIDD Proxy Server for Railway
// =========================

const express = require("express");
const cors = require("cors");
const fetch = require("node-fetch"); // For proxying requests

const app = express();

// Enable CORS for all requests
app.use(cors());
app.use(express.json());

// Railway gives a dynamic port via process.env.PORT
const PORT = process.env.PORT || 8080;

// ===== Root Route (Fixes "Not Found") =====
app.get("/", (req, res) => {
  res.send("✅ VIDD Proxy Server is running on Railway!");
});

// ===== Example Proxy Endpoint =====
// Use: /proxy?url=https://example.com
app.get("/proxy", async (req, res) => {
  const targetUrl = req.query.url;

  if (!targetUrl) {
    return res.status(400).json({ error: "Missing ?url= parameter" });
  }

  try {
    const response = await fetch(targetUrl);
    const data = await response.text();

    // Forward the response to the client
    res.send(data);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// ===== Start Server =====
app.listen(PORT, () => {
  console.log(`🚀 VIDD Proxy Server is running on port ${PORT}`);
});
