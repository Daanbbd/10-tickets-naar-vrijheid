// Het scorebord lokaal proberen, zonder Cloudflare-account en zonder wrangler:
//   node server/lokaal.mjs        (luistert op http://localhost:8787)
// Alle routes werken, ook /koplopers en de sprints per week (ISO-week, UTC). De
// opslag zit in het geheugen en is weg zodra je stopt (het verloop uit
// `expiration` wordt hier niet nagebootst). Er is geen SLACK_WEBHOOK: lokaal gaat
// er nooit iets naar buiten. Zet in scripts/rush/rush_online.gd tijdelijk ADRES
// op "http://localhost:8787".
import { createServer } from "node:http";
import { verwerk } from "./worker.js";

const kv = new Map();
const env = {
  SCORES: {
    async get(k, type) { const v = kv.get(k); return v === undefined ? null : type === "json" ? JSON.parse(v) : v; },
    async put(k, v) { kv.set(k, v); },
    async delete(k) { kv.delete(k); },
  },
};

createServer(async (req, res) => {
  const delen = [];
  for await (const d of req) delen.push(d);
  const body = Buffer.concat(delen);
  const headers = new Headers();
  for (const [k, v] of Object.entries(req.headers)) headers.set(k, String(v));
  const init = { method: req.method, headers };
  if (body.length > 0) init.body = body;
  const antwoord = await verwerk(new Request(`http://localhost${req.url}`, init), env);
  res.writeHead(antwoord.status, Object.fromEntries(antwoord.headers));
  res.end(Buffer.from(await antwoord.arrayBuffer()));
}).listen(8787, () => process.stdout.write("Scorebord lokaal op http://localhost:8787\n"));
