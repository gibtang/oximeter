/**
 * Lightweight lead-capture API server for static landing sites.
 * Runs alongside nginx — nginx proxies /api/early-access here.
 */

import { MongoClient } from "mongodb";

const PORT = 3000;
const uri = process.env.MONGODB_URI;
if (!uri) {
  console.error("[server] MONGODB_URI is not configured");
  process.exit(1);
}

const client = new MongoClient(uri);
let db;

async function connect() {
  await client.connect();
  db = client.db();
  const signups = db.collection("signups");
  await signups.createIndex({ projectKey: 1, emailNormalized: 1 }, { unique: true });
  await signups.createIndex({ createdAt: -1 });
  console.log("[server] Connected to MongoDB");
}

function json(res, body, status = 200) {
  res.writeHead(status, {
    "Content-Type": "application/json",
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "POST, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
  });
  res.end(JSON.stringify(body));
}

function toStr(v) {
  return typeof v === "string" ? v.trim() : "";
}

async function handlePost(req, res) {
  try {
    const body = await new Promise((resolve, reject) => {
      let data = "";
      req.on("data", (chunk) => (data += chunk));
      req.on("end", () => {
        try {
          resolve(JSON.parse(data));
        } catch {
          reject(new Error("Invalid JSON"));
        }
      });
      req.on("error", reject);
    });

    const email = toStr(body.email).toLowerCase();
    const qualifier = toStr(body.qualifier || body.qualifierAnswer);
    const honeypot = toStr(body.honeypot);
    const consent = Boolean(body.consent || body.consentAccepted);
    const projectKey = toStr(body.projectKey) || "default";
    const projectName = toStr(body.projectName) || projectKey;
    const qualifierKey = toStr(body.qualifierKey) || "qualifier";
    const qualifierLabel = toStr(body.qualifierLabel) || "Interest";
    const source = toStr(body.source) || "landing";

    // Honeypot check
    if (honeypot) {
      return json(res, { message: "Thanks." }, 200);
    }

    // Consent required
    if (!consent) {
      return json(res, { message: "Consent is required." }, 400);
    }

    // Qualifier required
    if (!qualifier) {
      return json(res, { message: "Please make a selection before joining." }, 400);
    }

    // Basic email validation
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
      return json(res, { message: "Please enter a valid email address." }, 400);
    }

    const signups = db.collection("signups");
    const now = new Date();

    // Duplicate check
    const existing = await signups.findOne({ projectKey, emailNormalized: email });
    if (existing) {
      return json(res, { message: "You're already on the early access list." }, 200);
    }

    await signups.insertOne({
      projectKey,
      projectName,
      email,
      emailNormalized: email,
      qualifierKey,
      qualifierLabel,
      qualifier,
      consent: true,
      qualified: true,
      source,
      createdAt: now,
      updatedAt: now,
      userAgent: req.headers["user-agent"] || null,
      referer: req.headers["referer"] || null,
      ip: req.headers["x-forwarded-for"]?.split(",")[0]?.trim() || null,
    });

    return json(res, { message: "You're on the early access list." }, 201);
  } catch (error) {
    console.error("[early-access]", error);
    return json(
      res,
      { message: error instanceof Error ? error.message : "Something went wrong." },
      500,
    );
  }
}

const server = (await import("node:http")).createServer(async (req, res) => {
  if (req.method === "OPTIONS") {
    res.writeHead(204, {
      "Access-Control-Allow-Origin": "*",
      "Access-Control-Allow-Methods": "POST, OPTIONS",
      "Access-Control-Allow-Headers": "Content-Type",
    });
    return res.end();
  }

  if (req.method === "POST" && req.url === "/api/early-access") {
    return handlePost(req, res);
  }

  json(res, { message: "Not found." }, 404);
});

await connect();
server.listen(PORT, "127.0.0.1", () => {
  console.log(`[server] Listening on http://127.0.0.1:${PORT}`);
});
