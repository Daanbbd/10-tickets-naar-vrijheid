// Tests voor het scorebord. Draai met: node --test server/
// Geen dependencies: Node heeft Request, Response en WebCrypto zelf, en Workers
// KV is hier een Map met dezelfde get/put/delete.
import { test } from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";

import { verwerk, sterrenVoor, naamGeblokkeerd, ROLLEN, TOEGESTANE_ORIGINS } from "./worker.js";

const HIER = "https://daanbbd.github.io";
const OKTOBER = new Date(Date.UTC(2026, 9, 12, 10, 0, 0));
const NOVEMBER = new Date(Date.UTC(2026, 10, 3, 10, 0, 0));
const PORTRET = "0123456789abcdefghijklmnopqrstuv".repeat(40);
const sleutel = (n = 1) => n.toString(16).padStart(32, "0");

class MockKV {
  constructor() { this.data = new Map(); this.opties = new Map(); this.puts = 0; }
  async get(k, type) {
    const v = this.data.get(k);
    if (v === undefined) return null;
    return type === "json" ? JSON.parse(v) : v;
  }
  async put(k, v, opties = {}) { this.puts++; this.data.set(k, v); this.opties.set(k, opties); }
  async delete(k) { this.data.delete(k); this.opties.delete(k); }
}

function nieuweOmgeving() { return { SCORES: new MockKV() }; }

function geldig(extra = {}) {
  return { dag: 1, naam: "Victor", rol: "Frontend developer", minuut: 1000, ontsnap: -1,
    portret: PORTRET, sleutel: sleutel(), ...extra };
}

async function vraag(env, methode, pad, body, { headers = {}, nu = OKTOBER, ruw = false } = {}) {
  const init = { method: methode, headers: { ...headers } };
  if (body !== undefined) {
    init.body = ruw ? body : JSON.stringify(body);
    if (!("Content-Type" in init.headers)) init.headers["Content-Type"] = "application/json";
  }
  const res = await verwerk(new Request(`https://scorebord.example${pad}`, init), env, () => nu);
  const tekst = await res.text();
  let json = null;
  try { json = JSON.parse(tekst); } catch { /* geen json, bv. 204 */ }
  return { status: res.status, json, headers: res.headers };
}

const post = (env, body, o) => vraag(env, "POST", "/scores", body, o);
const haal = (env, dag, o) => vraag(env, "GET", `/scores?dag=${dag}`, undefined, o);

// ---- Sterren ----------------------------------------------------------------

test("sterren: dezelfde grenzen als RushData.sterren_voor()", () => {
  assert.equal(sterrenVoor(600), 3);
  assert.equal(sterrenVoor(1020), 3); // 17:00
  assert.equal(sterrenVoor(1020.1), 2);
  assert.equal(sterrenVoor(1110), 2); // 18:30
  assert.equal(sterrenVoor(1110.1), 1);
  assert.equal(sterrenVoor(1800), 1);
});

test("sterren komen van de server, niet van de client", async () => {
  const env = nieuweOmgeving();
  await post(env, geldig({ minuut: 1000 }));
  await post(env, geldig({ minuut: 1100, sleutel: sleutel(2) }));
  await post(env, geldig({ minuut: 1200, sleutel: sleutel(3) }));
  const { json } = await haal(env, 1);
  assert.deepEqual(json.scores.map((r) => r.sterren), [3, 2, 1]);
  // en meesturen mag niet
  assert.equal((await post(env, geldig({ sterren: 3 }))).status, 400);
});

// ---- Validatie --------------------------------------------------------------

test("een geldige score wordt aangenomen", async () => {
  const env = nieuweOmgeving();
  const r = await post(env, geldig());
  assert.equal(r.status, 200);
  assert.deepEqual(r.json, { plek: 1 });
});

test("een lege portret en ontsnap tussen 8 en 300 mogen", async () => {
  const env = nieuweOmgeving();
  assert.equal((await post(env, geldig({ portret: "", ontsnap: 8 }))).status, 200);
  assert.equal((await post(env, geldig({ ontsnap: 300, sleutel: sleutel(2) }))).status, 200);
  assert.equal((await post(env, geldig({ ontsnap: 42.5, sleutel: sleutel(3) }))).status, 200);
});

test("alle rollen uit het spel zijn toegestaan", async () => {
  const env = nieuweOmgeving();
  let n = 10;
  for (const rol of ROLLEN) {
    assert.equal((await post(env, geldig({ rol, sleutel: sleutel(n++) }))).status, 200, rol);
  }
  // de rollen uit characters.json staan er allemaal in
  const personages = JSON.parse(readFileSync(new URL("../data/characters.json", import.meta.url), "utf8"));
  for (const p of personages) assert.ok(ROLLEN.includes(p.role), `rol ontbreekt: ${p.role}`);
});

const SLECHT = {
  "dag -1": { dag: -1 },
  "dag 5": { dag: 5 },
  "dag 1.5": { dag: 1.5 },
  "dag als tekst": { dag: "1" },
  "naam leeg": { naam: "" },
  "naam alleen spaties": { naam: "   " },
  "naam te lang (13)": { naam: "A".repeat(13) },
  "naam met punt": { naam: "Vic.tor" },
  "naam met html": { naam: "<b>x</b>" },
  "naam met emoji": { naam: "Vic😀" },
  "naam met cyrillisch": { naam: "Виктор" },
  "naam met nul-byte": { naam: "a\u0000b" },
  "naam met nieuwe regel": { naam: "a\nb" },
  "naam geen tekst": { naam: 12 },
  "scheldwoord": { naam: "KuT" },
  "rol onbekend": { rol: "Hacker" },
  "rol leeg": { rol: "" },
  "minuut 599": { minuut: 599 },
  "minuut 1801": { minuut: 1801 },
  "minuut als tekst": { minuut: "1000" },
  "minuut null": { minuut: null },
  "ontsnap 7": { ontsnap: 7 },
  "ontsnap 301": { ontsnap: 301 },
  "ontsnap 0": { ontsnap: 0 },
  "ontsnap -2": { ontsnap: -2 },
  "portret 1279 tekens": { portret: PORTRET.slice(1) },
  "portret 1281 tekens": { portret: PORTRET + "0" },
  "portret met w": { portret: "w" + PORTRET.slice(1) },
  "portret hoofdletter": { portret: "A" + PORTRET.slice(1) },
  "portret geen tekst": { portret: null },
  "sleutel te kort": { sleutel: "abc" },
  "sleutel 33 tekens": { sleutel: "a".repeat(33) },
  "sleutel geen hex": { sleutel: "g".repeat(32) },
  "sleutel hoofdletters": { sleutel: "A".repeat(32) },
  "onbekend veld": { wie: "victor" },
  "onbekend veld gebeld": { gebeld: true },
};

for (const [naam, wijziging] of Object.entries(SLECHT)) {
  test(`weigert: ${naam}`, async () => {
    const env = nieuweOmgeving();
    const r = await post(env, geldig(wijziging));
    assert.equal(r.status, 400);
    assert.equal(env.SCORES.puts, 0, "er is niets bewaard");
  });
}

for (const veld of ["dag", "naam", "rol", "minuut", "ontsnap", "portret", "sleutel"]) {
  test(`weigert: veld ${veld} ontbreekt`, async () => {
    const b = geldig();
    delete b[veld];
    assert.equal((await post(nieuweOmgeving(), b)).status, 400);
  });
}

test("weigert een body die geen object is", async () => {
  const env = nieuweOmgeving();
  for (const b of ["[]", "null", "42", '"tekst"', "{kapot", ""]) {
    assert.equal((await post(env, b, { ruw: true })).status, 400, b);
  }
});

test("naam wordt getrimd en mag accenten en - _ en cijfers bevatten", async () => {
  const env = nieuweOmgeving();
  assert.equal((await post(env, geldig({ naam: "  Zoë-Ann_9 " }))).status, 200);
  const { json } = await haal(env, 1);
  assert.equal(json.scores[0].naam, "Zoë-Ann_9");
});

test("minuut wordt op een tiende afgerond", async () => {
  const env = nieuweOmgeving();
  await post(env, geldig({ minuut: 1020.1000000000001 }));
  assert.equal((await haal(env, 1)).json.scores[0].minuut, 1020.1);
});

test("body groter dan 4 KB: 413, ook zonder eerlijke Content-Length", async () => {
  const env = nieuweOmgeving();
  const groot = JSON.stringify(geldig({ naam: "x", extra: "y".repeat(5000) }));
  assert.equal((await post(env, groot, { ruw: true })).status, 413);
  // een stream zonder lengte
  const stroom = new ReadableStream({ start(c) { c.enqueue(new TextEncoder().encode(groot)); c.close(); } });
  const res = await verwerk(new Request("https://x.example/scores", {
    method: "POST", body: stroom, duplex: "half", headers: { "Content-Type": "application/json" },
  }), env);
  assert.equal(res.status, 413);
  assert.equal(env.SCORES.puts, 0);
});

test("content-type moet json zijn", async () => {
  const env = nieuweOmgeving();
  const r = await post(env, JSON.stringify(geldig()), { ruw: true, headers: { "Content-Type": "text/plain" } });
  assert.equal(r.status, 415);
});

test("GET: dag ontbreekt of is ongeldig", async () => {
  const env = nieuweOmgeving();
  for (const pad of ["/scores", "/scores?dag=5", "/scores?dag=-1", "/scores?dag=x", "/scores?dag=1.5", "/scores?dag=01"]) {
    assert.equal((await vraag(env, "GET", pad)).status, 400, pad);
  }
});

test("onbekend pad is 404, onbekende methode is 405", async () => {
  const env = nieuweOmgeving();
  assert.equal((await vraag(env, "GET", "/")).status, 404);
  assert.equal((await vraag(env, "GET", "/scores/x")).status, 404);
  assert.equal((await vraag(env, "PUT", "/scores", {})).status, 405);
});

// ---- Scheldwoorden ----------------------------------------------------------

test("naam-blokkade: kort, en zonder de Scunthorpe-valkuil", () => {
  for (const n of ["kut", "KUT", "K u t", "kanker", "Kankerlijer", "Fucker", "sh1t", "h1tler", "n4zi", "Zoë Lul", "kut-piet"]) {
    assert.equal(naamGeblokkeerd(n), true, n);
  }
  for (const n of ["Lulu", "Victor", "Hoeksema", "Pikachu", "Nazira", "Kutay", "Sheila", "Tijs", "Daan", "Koen"]) {
    assert.equal(naamGeblokkeerd(n), false, n);
  }
});

// ---- Rangschikking ----------------------------------------------------------

test("GET geeft de top 20, op minuut oplopend, zonder id's of tijdstempels", async () => {
  const env = nieuweOmgeving();
  for (let i = 0; i < 25; i++) {
    // omgekeerd inleveren, zodat sorteren echt iets moet doen
    const r = await post(env, geldig({ naam: `Sp${i}`, minuut: 1000 + (24 - i), sleutel: sleutel(100 + i) }));
    assert.equal(r.status, 200);
  }
  const { json } = await haal(env, 1);
  assert.equal(json.scores.length, 20);
  const minuten = json.scores.map((r) => r.minuut);
  assert.deepEqual(minuten, [...minuten].sort((a, b) => a - b));
  assert.equal(minuten[0], 1000);
  assert.equal(minuten[19], 1019);
  for (const r of json.scores) {
    assert.deepEqual(Object.keys(r).sort(), ["minuut", "naam", "ontsnap", "portret", "rol", "sterren"]);
  }
});

test("de 21e regel haalt de top niet: plek 0 en er wordt niets bewaard", async () => {
  const env = nieuweOmgeving();
  for (let i = 0; i < 20; i++) await post(env, geldig({ minuut: 1000 + i, sleutel: sleutel(100 + i) }));
  const puts = env.SCORES.puts;
  const r = await post(env, geldig({ minuut: 1500, sleutel: sleutel(999) }));
  assert.deepEqual(r.json, { plek: 0 });
  assert.equal(env.SCORES.puts, puts);
  assert.equal((await haal(env, 1)).json.scores.length, 20);
});

test("een snellere regel verdringt de langzaamste uit een volle lijst", async () => {
  const env = nieuweOmgeving();
  for (let i = 0; i < 20; i++) await post(env, geldig({ minuut: 1000 + i, sleutel: sleutel(100 + i) }));
  const r = await post(env, geldig({ minuut: 900, sleutel: sleutel(999) }));
  assert.deepEqual(r.json, { plek: 1 });
  const { scores } = (await haal(env, 1)).json;
  assert.equal(scores.length, 20);
  assert.equal(scores[0].minuut, 900);
  assert.equal(scores[19].minuut, 1018);
});

test("plekken: gelijke tijd komt achter wie er eerder was", async () => {
  const env = nieuweOmgeving();
  assert.deepEqual((await post(env, geldig({ minuut: 1000, sleutel: sleutel(1) }))).json, { plek: 1 });
  assert.deepEqual((await post(env, geldig({ minuut: 1000, sleutel: sleutel(2) }))).json, { plek: 2 });
  assert.deepEqual((await post(env, geldig({ minuut: 900, sleutel: sleutel(3) }))).json, { plek: 1 });
});

test("dagen staan los van elkaar", async () => {
  const env = nieuweOmgeving();
  await post(env, geldig({ dag: 0 }));
  await post(env, geldig({ dag: 3, minuut: 1200 }));
  assert.equal((await haal(env, 0)).json.scores.length, 1);
  assert.equal((await haal(env, 2)).json.scores.length, 0);
  assert.equal((await haal(env, 3)).json.scores[0].minuut, 1200);
});

// ---- Eén regel per sleutel per dag ------------------------------------------

test("een betere tijd vervangt je oude regel; een slechtere doet niets", async () => {
  const env = nieuweOmgeving();
  await post(env, geldig({ minuut: 1100, naam: "Oud" }));
  assert.deepEqual((await post(env, geldig({ minuut: 1000, naam: "Nieuw" }))).json, { plek: 1 });
  let { scores } = (await haal(env, 1)).json;
  assert.equal(scores.length, 1);
  assert.equal(scores[0].naam, "Nieuw");
  const puts = env.SCORES.puts;
  assert.deepEqual((await post(env, geldig({ minuut: 1300, naam: "Slechter" }))).json, { plek: 1 });
  assert.equal(env.SCORES.puts, puts, "een slechtere tijd schrijft niets");
  ({ scores } = (await haal(env, 1)).json);
  assert.equal(scores.length, 1);
  assert.equal(scores[0].naam, "Nieuw");
  assert.equal(scores[0].minuut, 1000);
});

test("bij een slechtere tijd hoor je de plek van je bestaande regel", async () => {
  const env = nieuweOmgeving();
  await post(env, geldig({ minuut: 900, sleutel: sleutel(2) }));
  await post(env, geldig({ minuut: 1000 }));
  assert.deepEqual((await post(env, geldig({ minuut: 1500 }))).json, { plek: 2 });
});

test("gelijke tijd met een snellere ontsnapping telt als beter", async () => {
  const env = nieuweOmgeving();
  await post(env, geldig({ minuut: 1000, ontsnap: -1 }));
  await post(env, geldig({ minuut: 1000, ontsnap: 60 }));
  await post(env, geldig({ minuut: 1000, ontsnap: 90 }));
  const { scores } = (await haal(env, 1)).json;
  assert.equal(scores.length, 1);
  assert.equal(scores[0].ontsnap, 60);
});

test("verschillende sleutels op dezelfde dag zijn verschillende regels", async () => {
  const env = nieuweOmgeving();
  await post(env, geldig({ sleutel: sleutel(1) }));
  await post(env, geldig({ sleutel: sleutel(2) }));
  assert.equal((await haal(env, 1)).json.scores.length, 2);
});

// ---- Wissen -----------------------------------------------------------------

test("DELETE wist al jouw regels op alle dagen, en alleen die", async () => {
  const env = nieuweOmgeving();
  for (let dag = 0; dag < 5; dag++) {
    await post(env, geldig({ dag, sleutel: sleutel(1) }));
    await post(env, geldig({ dag, sleutel: sleutel(2), naam: "Ander", minuut: 1200 }));
  }
  const r = await vraag(env, "DELETE", "/scores", { sleutel: sleutel(1) });
  assert.equal(r.status, 200);
  assert.deepEqual(r.json, { verwijderd: 5 });
  for (let dag = 0; dag < 5; dag++) {
    const { scores } = (await haal(env, dag)).json;
    assert.equal(scores.length, 1);
    assert.equal(scores[0].naam, "Ander");
  }
});

test("DELETE ruimt ook de vorige maand op, en een lege dag verdwijnt uit KV", async () => {
  const env = nieuweOmgeving();
  await post(env, geldig({ dag: 2 }), { nu: OKTOBER });
  assert.ok(env.SCORES.data.has("scores:2026-10:2"));
  await vraag(env, "DELETE", "/scores", { sleutel: sleutel(1) }, { nu: NOVEMBER });
  assert.equal(env.SCORES.data.size, 0);
});

test("DELETE weigert een slechte sleutel of extra velden", async () => {
  const env = nieuweOmgeving();
  for (const b of [{}, { sleutel: "abc" }, { sleutel: sleutel(), meer: 1 }, { sleutel: 5 }, []]) {
    assert.equal((await vraag(env, "DELETE", "/scores", b)).status, 400, JSON.stringify(b));
  }
});

test("DELETE met een onbekende sleutel is gewoon 0 verwijderd", async () => {
  const env = nieuweOmgeving();
  await post(env, geldig());
  const r = await vraag(env, "DELETE", "/scores", { sleutel: sleutel(77) });
  assert.deepEqual(r.json, { verwijderd: 0 });
  assert.equal((await haal(env, 1)).json.scores.length, 1);
});

// ---- Sprints en bewaartermijn -----------------------------------------------

test("een nieuwe maand begint met een leeg bord", async () => {
  const env = nieuweOmgeving();
  await post(env, geldig(), { nu: OKTOBER });
  assert.equal((await haal(env, 1, { nu: OKTOBER })).json.scores.length, 1);
  assert.equal((await haal(env, 1, { nu: NOVEMBER })).json.scores.length, 0);
  // in november kan dezelfde sleutel weer een regel zetten
  assert.deepEqual((await post(env, geldig({ minuut: 1200 }), { nu: NOVEMBER })).json, { plek: 1 });
});

test("KV-sleutel is scores:<jjjj-mm>:<dag> en verloopt de 11e van de maand erna", async () => {
  const env = nieuweOmgeving();
  await post(env, geldig({ dag: 4 }), { nu: OKTOBER });
  const k = "scores:2026-10:4";
  assert.ok(env.SCORES.data.has(k));
  const exp = env.SCORES.opties.get(k).expiration;
  assert.equal(exp, Date.UTC(2026, 10, 11) / 1000);
  const dagen = (exp * 1000 - OKTOBER.getTime()) / 864e5;
  assert.ok(dagen > 28 && dagen < 41, `bewaartermijn ${dagen} dagen`);
});

// ---- Privacy ----------------------------------------------------------------

test("wat KV bewaart: alleen de gedocumenteerde velden, en hash in plaats van sleutel", async () => {
  const env = nieuweOmgeving();
  const s = sleutel(0xabcdef);
  await post(env, geldig({ sleutel: s, ontsnap: 100 }), {
    headers: {
      "CF-Connecting-IP": "203.0.113.77",
      "X-Forwarded-For": "203.0.113.77",
      "User-Agent": "GeheimeBrowser/9.9",
      Cookie: "sessie=geheim",
      Referer: "https://daanbbd.github.io/10-tickets-naar-vrijheid/",
      Origin: HIER,
    },
  });
  const alles = JSON.stringify([...env.SCORES.data.entries()]) + JSON.stringify([...env.SCORES.opties.entries()]);
  for (const verboden of [s, "203.0.113.77", "GeheimeBrowser", "sessie", "geheim"]) {
    assert.ok(!alles.includes(verboden), `KV bevat "${verboden}"`);
  }
  const lijst = JSON.parse(env.SCORES.data.get("scores:2026-10:1"));
  assert.equal(lijst.length, 1);
  assert.deepEqual(Object.keys(lijst[0]).sort(), ["h", "minuut", "naam", "ontsnap", "portret", "rol", "sterren"]);
  assert.equal(lijst[0].h, createHash("sha256").update(s).digest("hex"));
  // een tijdstempel of id zit er nergens in
  assert.ok(!/"(t|ts|tijd|datum|id|ip|ua)"/.test(env.SCORES.data.get("scores:2026-10:1")));
  // en alleen de score-sleutels, niets anders
  assert.deepEqual([...env.SCORES.data.keys()], ["scores:2026-10:1"]);
});

test("GET lekt de hash niet", async () => {
  const env = nieuweOmgeving();
  const s = sleutel(5);
  await post(env, geldig({ sleutel: s }));
  const res = await haal(env, 1);
  const h = createHash("sha256").update(s).digest("hex");
  assert.ok(!JSON.stringify(res.json).includes(h));
});

test("de broncode leest geen IP of User-Agent en logt niets", () => {
  const bron = readFileSync(new URL("./worker.js", import.meta.url), "utf8")
    .split("\n").filter((r) => !r.trim().startsWith("//")).join("\n");
  assert.ok(!/console\./.test(bron), "console.* gevonden");
  for (const naam of ["CF-Connecting-IP", "X-Forwarded-For", "User-Agent", "request.cf", "Cookie", "Referer"]) {
    assert.ok(!bron.toLowerCase().includes(naam.toLowerCase()), `${naam} komt voor in worker.js`);
  }
});

test("wrangler.toml zet observability uit", () => {
  const toml = readFileSync(new URL("./wrangler.toml", import.meta.url), "utf8");
  assert.match(toml, /\[observability\]\s*\n\s*enabled\s*=\s*false/);
  assert.match(toml, /logpush\s*=\s*false/);
});

// ---- CORS -------------------------------------------------------------------

test("CORS: toegestane origins krijgen hun eigen origin terug", async () => {
  const env = nieuweOmgeving();
  for (const origin of TOEGESTANE_ORIGINS) {
    const r = await haal(env, 1, { headers: { Origin: origin } });
    assert.equal(r.status, 200);
    assert.equal(r.headers.get("Access-Control-Allow-Origin"), origin);
    assert.equal(r.headers.get("Vary"), "Origin");
  }
  assert.deepEqual(TOEGESTANE_ORIGINS, ["https://daanbbd.github.io", "http://localhost:8060", "http://127.0.0.1:8060"]);
});

test("CORS: een andere origin wordt geweigerd, ook voor schrijven", async () => {
  const env = nieuweOmgeving();
  for (const origin of ["https://evil.example", "https://daanbbd.github.io.evil.example", "http://daanbbd.github.io", "null"]) {
    const r = await post(env, geldig(), { headers: { Origin: origin } });
    assert.equal(r.status, 403, origin);
    assert.equal(r.headers.get("Access-Control-Allow-Origin"), null);
  }
  assert.equal(env.SCORES.puts, 0);
});

test("CORS: preflight van het spel", async () => {
  const env = nieuweOmgeving();
  const r = await vraag(env, "OPTIONS", "/scores", undefined, {
    headers: { Origin: HIER, "Access-Control-Request-Method": "DELETE", "Access-Control-Request-Headers": "content-type" },
  });
  assert.equal(r.status, 204);
  assert.equal(r.headers.get("Access-Control-Allow-Origin"), HIER);
  assert.match(r.headers.get("Access-Control-Allow-Methods"), /DELETE/);
  assert.match(r.headers.get("Access-Control-Allow-Methods"), /POST/);
  assert.match(r.headers.get("Access-Control-Allow-Headers"), /Content-Type/i);
  const slecht = await vraag(env, "OPTIONS", "/scores", undefined, { headers: { Origin: "https://evil.example" } });
  assert.equal(slecht.status, 403);
});

test("zonder Origin (desktop, curl) werkt het, zonder CORS-headers", async () => {
  const env = nieuweOmgeving();
  const r = await post(env, geldig());
  assert.equal(r.status, 200);
  assert.equal(r.headers.get("Access-Control-Allow-Origin"), null);
});

test("fouten krijgen ook de CORS-headers, zodat het spel de foutcode kan lezen", async () => {
  const env = nieuweOmgeving();
  const r = await post(env, geldig({ dag: 9 }), { headers: { Origin: HIER } });
  assert.equal(r.status, 400);
  assert.equal(r.headers.get("Access-Control-Allow-Origin"), HIER);
});

test("antwoorden worden niet gecachet", async () => {
  const r = await haal(nieuweOmgeving(), 1);
  assert.equal(r.headers.get("Cache-Control"), "no-store");
});
