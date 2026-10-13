// Tests voor het scorebord. Draai met: node --test server/
// Geen dependencies: Node heeft Request, Response en WebCrypto zelf, en Workers
// KV is hier een Map met dezelfde get/put/delete.
import { test } from "node:test";
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";

import {
  verwerk, sterrenVoor, naamGeblokkeerd, sprintVan, maxPunten, slackBericht, ROLLEN, TOEGESTANE_ORIGINS,
} from "./worker.js";

const HIER = "https://daanbbd.github.io";
// Maandagen om 10:00 UTC: 2026-W42, W43 en W44.
const OKTOBER = new Date(Date.UTC(2026, 9, 12, 10, 0, 0));
const WEEK_NA = new Date(Date.UTC(2026, 9, 19, 10, 0, 0));
const WEEK_DAARNA = new Date(Date.UTC(2026, 9, 26, 10, 0, 0));
const WEBHOOK = "https://hooks.slack.example/services/T0/B0/geheim";
const PORTRET = "0123456789abcdefghijklmnopqrstuv".repeat(40);
const sleutel = (n = 1) => n.toString(16).padStart(32, "0");

class MockKV {
  constructor() { this.data = new Map(); this.opties = new Map(); this.puts = 0; this.reads = 0; }
  async get(k, type) {
    this.reads++;
    const v = this.data.get(k);
    if (v === undefined) return null;
    return type === "json" ? JSON.parse(v) : v;
  }
  async put(k, v, opties = {}) { this.puts++; this.data.set(k, v); this.opties.set(k, opties); }
  async delete(k) { this.data.delete(k); this.opties.delete(k); }
}

function nieuweOmgeving() { return { SCORES: new MockKV() }; }

function geldig(extra = {}) {
  return { dag: 1, naam: "Victor", rol: "Frontend developer", minuut: 1000, ontsnap: -1, punten: 2000,
    portret: PORTRET, sleutel: sleutel(), ...extra };
}

async function vraag(env, methode, pad, body, { headers = {}, nu = OKTOBER, ruw = false, ctx, netwerk } = {}) {
  const init = { method: methode, headers: { ...headers } };
  if (body !== undefined) {
    init.body = ruw ? body : JSON.stringify(body);
    if (!("Content-Type" in init.headers)) init.headers["Content-Type"] = "application/json";
  }
  const res = await verwerk(new Request(`https://scorebord.example${pad}`, init), env, () => nu, ctx, netwerk);
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
  "punten -1": { punten: -1 },
  "punten 1.5": { punten: 1.5 },
  "punten als tekst": { punten: "2000" },
  "punten null": { punten: null },
  "punten Infinity (wordt null in JSON)": { punten: Infinity },
  "punten boven de grens": { punten: 3601 },
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

for (const veld of ["dag", "naam", "rol", "minuut", "ontsnap", "punten", "portret", "sleutel"]) {
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

test("GET geeft de top 20, op punten aflopend, zonder id's of tijdstempels", async () => {
  const env = nieuweOmgeving();
  for (let i = 0; i < 25; i++) {
    // oplopend inleveren, zodat sorteren echt iets moet doen
    const r = await post(env, geldig({ naam: `Sp${i}`, punten: 1000 + i, sleutel: sleutel(100 + i) }));
    assert.equal(r.status, 200);
  }
  const { json } = await haal(env, 1);
  assert.equal(json.sprint, "2026-W42");
  assert.equal(json.scores.length, 20);
  const punten = json.scores.map((r) => r.punten);
  assert.deepEqual(punten, [...punten].sort((a, b) => b - a));
  assert.equal(punten[0], 1024);
  assert.equal(punten[19], 1005);
  for (const r of json.scores) {
    assert.deepEqual(Object.keys(r).sort(), ["minuut", "naam", "ontsnap", "portret", "punten", "rol", "sterren"]);
  }
});

test("bij gelijke punten wint de lagere minuut, dan de snellere ontsnapping", async () => {
  const env = nieuweOmgeving();
  await post(env, geldig({ naam: "Laat", minuut: 1100, punten: 2000, sleutel: sleutel(1) }));
  await post(env, geldig({ naam: "ZonderOnt", minuut: 1000, punten: 2000, ontsnap: -1, sleutel: sleutel(2) }));
  await post(env, geldig({ naam: "Traag", minuut: 1000, punten: 2000, ontsnap: 90, sleutel: sleutel(3) }));
  await post(env, geldig({ naam: "Snel", minuut: 1000, punten: 2000, ontsnap: 60, sleutel: sleutel(4) }));
  await post(env, geldig({ naam: "Meer", minuut: 1200, punten: 2001, sleutel: sleutel(5) }));
  const { scores } = (await haal(env, 1)).json;
  assert.deepEqual(scores.map((r) => r.naam), ["Meer", "Snel", "Traag", "ZonderOnt", "Laat"]);
});

test("de 21e regel haalt de top niet: plek 0 en er wordt niets bewaard", async () => {
  const env = nieuweOmgeving();
  for (let i = 0; i < 20; i++) await post(env, geldig({ punten: 2000 - i, sleutel: sleutel(100 + i) }));
  const puts = env.SCORES.puts;
  const r = await post(env, geldig({ punten: 500, sleutel: sleutel(999) }));
  assert.deepEqual(r.json, { plek: 0 });
  assert.equal(env.SCORES.puts, puts);
  assert.equal((await haal(env, 1)).json.scores.length, 20);
});

test("meer punten verdringt de laagste uit een volle lijst", async () => {
  const env = nieuweOmgeving();
  for (let i = 0; i < 20; i++) await post(env, geldig({ punten: 2000 - i, sleutel: sleutel(100 + i) }));
  const r = await post(env, geldig({ punten: 3000, sleutel: sleutel(999) }));
  assert.deepEqual(r.json, { plek: 1 });
  const { scores } = (await haal(env, 1)).json;
  assert.equal(scores.length, 20);
  assert.equal(scores[0].punten, 3000);
  assert.equal(scores[19].punten, 1982);
});

test("plekken: een volledig gelijke stand komt achter wie er eerder was", async () => {
  const env = nieuweOmgeving();
  assert.deepEqual((await post(env, geldig({ sleutel: sleutel(1) }))).json, { plek: 1 });
  assert.deepEqual((await post(env, geldig({ sleutel: sleutel(2) }))).json, { plek: 2 });
  assert.deepEqual((await post(env, geldig({ punten: 2500, sleutel: sleutel(3) }))).json, { plek: 1 });
});

test("dagen staan los van elkaar", async () => {
  const env = nieuweOmgeving();
  await post(env, geldig({ dag: 0 }));
  await post(env, geldig({ dag: 3, minuut: 1200 }));
  assert.equal((await haal(env, 0)).json.scores.length, 1);
  assert.equal((await haal(env, 2)).json.scores.length, 0);
  assert.equal((await haal(env, 3)).json.scores[0].minuut, 1200);
});

// ---- Plausibiliteit van punten ----------------------------------------------

test("de puntengrens: basis 1000 + 5 per minuut voor 17:00 + 2500 + 10 per seconde onder de 40 s", () => {
  assert.equal(maxPunten(1020, -1), 3500);
  assert.equal(maxPunten(1800, -1), 3500); // te laat voor een tijdbonus
  assert.equal(maxPunten(1000, -1), 3600);
  assert.equal(maxPunten(900, 20), 1000 + 600 + 2500 + 200);
  assert.equal(maxPunten(1020, 40), 3500); // geen ontsnapbonus vanaf 40 s
  assert.equal(maxPunten(1020, 300), 3500);
  assert.equal(maxPunten(1019.5, -1), 3502); // 3502,5 naar beneden
  assert.equal(maxPunten(600, 8), 1000 + 2100 + 2500 + 320);
});

test("precies op de grens is goed, één erboven is 400", async () => {
  const gevallen = [
    { minuut: 1020, ontsnap: -1 }, // 3500
    { minuut: 1000, ontsnap: -1 }, // 3600
    { minuut: 1500, ontsnap: -1 }, // 3500
    { minuut: 900, ontsnap: 20 }, // 4300
    { minuut: 1019.5, ontsnap: -1 }, // 3502 (afgerond van 3502,5)
    { minuut: 1500, ontsnap: 39.5 }, // 3505
  ];
  for (const g of gevallen) {
    const grens = maxPunten(g.minuut, g.ontsnap);
    const env = nieuweOmgeving();
    assert.equal((await post(env, geldig({ ...g, punten: grens }))).status, 200, JSON.stringify(g));
    const erboven = await post(nieuweOmgeving(), geldig({ ...g, punten: grens + 1 }));
    assert.equal(erboven.status, 400, JSON.stringify(g));
    assert.deepEqual(erboven.json, { fout: "punten" });
  }
  // zonder ontsnapping geen ontsnapbonus, ook al zou -1 "onder de 40" lijken
  assert.equal((await post(nieuweOmgeving(), geldig({ minuut: 1020, ontsnap: -1, punten: 3501 }))).status, 400);
  assert.equal((await post(nieuweOmgeving(), geldig({ punten: 0 }))).status, 200);
});

// ---- Eén regel per sleutel per dag ------------------------------------------

test("meer punten vervangt je oude regel; minder doet niets", async () => {
  const env = nieuweOmgeving();
  await post(env, geldig({ punten: 1500, naam: "Oud" }));
  assert.deepEqual((await post(env, geldig({ punten: 2500, naam: "Nieuw" }))).json, { plek: 1 });
  let { scores } = (await haal(env, 1)).json;
  assert.equal(scores.length, 1);
  assert.equal(scores[0].naam, "Nieuw");
  const puts = env.SCORES.puts;
  assert.deepEqual((await post(env, geldig({ punten: 1000, naam: "Slechter" }))).json, { plek: 1 });
  assert.equal(env.SCORES.puts, puts, "minder punten schrijft niets");
  ({ scores } = (await haal(env, 1)).json);
  assert.equal(scores.length, 1);
  assert.equal(scores[0].naam, "Nieuw");
  assert.equal(scores[0].punten, 2500);
});

test("meer punten telt ook als de tijd slechter is", async () => {
  const env = nieuweOmgeving();
  await post(env, geldig({ minuut: 900, punten: 2000 }));
  await post(env, geldig({ minuut: 1300, punten: 2100 }));
  const { scores } = (await haal(env, 1)).json;
  assert.equal(scores.length, 1);
  assert.equal(scores[0].minuut, 1300);
  assert.equal(scores[0].punten, 2100);
});

test("bij minder punten hoor je de plek van je bestaande regel", async () => {
  const env = nieuweOmgeving();
  await post(env, geldig({ punten: 3000, sleutel: sleutel(2) }));
  await post(env, geldig({ punten: 2000 }));
  assert.deepEqual((await post(env, geldig({ punten: 100 }))).json, { plek: 2 });
});

test("gelijke punten: de beste volgens de tiebreak vervangt, anders blijft de oude", async () => {
  const env = nieuweOmgeving();
  await post(env, geldig({ minuut: 1000, ontsnap: -1, punten: 2000 }));
  // lagere minuut is beter
  await post(env, geldig({ minuut: 990, ontsnap: -1, punten: 2000 }));
  assert.equal((await haal(env, 1)).json.scores[0].minuut, 990);
  // zelfde minuut, snellere ontsnapping is beter
  await post(env, geldig({ minuut: 990, ontsnap: 90, punten: 2000 }));
  await post(env, geldig({ minuut: 990, ontsnap: 60, punten: 2000 }));
  assert.equal((await haal(env, 1)).json.scores[0].ontsnap, 60);
  // slechter of gelijk: niets
  const puts = env.SCORES.puts;
  await post(env, geldig({ minuut: 990, ontsnap: 70, punten: 2000 }));
  await post(env, geldig({ minuut: 1100, ontsnap: 10, punten: 2000 }));
  await post(env, geldig({ minuut: 990, ontsnap: 60, punten: 2000, naam: "Zelfde" }));
  assert.equal(env.SCORES.puts, puts);
  const { scores } = (await haal(env, 1)).json;
  assert.equal(scores.length, 1);
  assert.equal(scores[0].naam, "Victor");
});

test("verschillende sleutels op dezelfde dag zijn verschillende regels", async () => {
  const env = nieuweOmgeving();
  await post(env, geldig({ sleutel: sleutel(1) }));
  await post(env, geldig({ sleutel: sleutel(2) }));
  assert.equal((await haal(env, 1)).json.scores.length, 2);
});

// ---- Koplopers --------------------------------------------------------------

test("GET /koplopers: lege dagen zijn null, de rest is de nummer 1", async () => {
  const env = nieuweOmgeving();
  let r = await vraag(env, "GET", "/koplopers");
  assert.equal(r.status, 200);
  assert.deepEqual(r.json, { sprint: "2026-W42", dagen: [null, null, null, null, null] });

  await post(env, geldig({ dag: 0, naam: "Maan", punten: 1800, sleutel: sleutel(1) }));
  await post(env, geldig({ dag: 0, naam: "Eerste", punten: 2900, sleutel: sleutel(2) }));
  await post(env, geldig({ dag: 3, naam: "Donder", punten: 2100, sleutel: sleutel(3) }));
  env.SCORES.reads = 0;
  r = await vraag(env, "GET", "/koplopers");
  assert.equal(env.SCORES.reads, 5, "vijf reads, één antwoord");
  assert.equal(r.json.dagen.length, 5);
  assert.equal(r.json.dagen[0].naam, "Eerste");
  assert.equal(r.json.dagen[3].naam, "Donder");
  assert.equal(r.json.dagen[1], null);
  assert.equal(r.json.dagen[2], null);
  assert.equal(r.json.dagen[4], null);
  assert.deepEqual(Object.keys(r.json.dagen[0]).sort(),
    ["minuut", "naam", "ontsnap", "portret", "punten", "rol", "sterren"]);
  assert.equal(r.json.dagen[0].portret, PORTRET);
});

test("/koplopers lekt geen hash, is niet gecachet en volgt de CORS-regels", async () => {
  const env = nieuweOmgeving();
  const s = sleutel(5);
  await post(env, geldig({ sleutel: s }));
  const r = await vraag(env, "GET", "/koplopers", undefined, { headers: { Origin: HIER } });
  assert.equal(r.status, 200);
  assert.ok(!JSON.stringify(r.json).includes(createHash("sha256").update(s).digest("hex")));
  assert.equal(r.headers.get("Cache-Control"), "no-store");
  assert.equal(r.headers.get("Access-Control-Allow-Origin"), HIER);
  const pre = await vraag(env, "OPTIONS", "/koplopers", undefined, { headers: { Origin: HIER } });
  assert.equal(pre.status, 204);
  assert.equal(pre.headers.get("Access-Control-Allow-Origin"), HIER);
  assert.equal((await vraag(env, "GET", "/koplopers", undefined, { headers: { Origin: "https://evil.example" } })).status, 403);
  assert.equal((await vraag(env, "POST", "/koplopers", {})).status, 405);
  assert.equal((await vraag(env, "DELETE", "/koplopers", {})).status, 405);
});

test("/koplopers gebruikt de huidige week", async () => {
  const env = nieuweOmgeving();
  await post(env, geldig(), { nu: OKTOBER });
  assert.equal((await vraag(env, "GET", "/koplopers", undefined, { nu: OKTOBER })).json.dagen[1].naam, "Victor");
  const volgende = (await vraag(env, "GET", "/koplopers", undefined, { nu: WEEK_NA })).json;
  assert.equal(volgende.sprint, "2026-W43");
  assert.deepEqual(volgende.dagen, [null, null, null, null, null]);
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

test("DELETE ruimt ook de vorige week op, maar niet die daarvoor, en een lege dag verdwijnt uit KV", async () => {
  const env = nieuweOmgeving();
  await post(env, geldig({ dag: 2 }), { nu: OKTOBER });
  assert.ok(env.SCORES.data.has("scores:2026-W42:2"));
  // twee weken later is W42 buiten bereik
  await vraag(env, "DELETE", "/scores", { sleutel: sleutel(1) }, { nu: WEEK_DAARNA });
  assert.ok(env.SCORES.data.has("scores:2026-W42:2"));
  // een week later is het de vorige sprint: gewist, en de sleutel verdwijnt
  const r = await vraag(env, "DELETE", "/scores", { sleutel: sleutel(1) }, { nu: WEEK_NA });
  assert.deepEqual(r.json, { verwijderd: 1 });
  assert.equal(env.SCORES.data.size, 0);
});

test("DELETE wist over de jaargrens heen: 2027-W01 kijkt terug naar 2026-W53", async () => {
  const env = nieuweOmgeving();
  await post(env, geldig({ dag: 0 }), { nu: new Date(Date.UTC(2026, 11, 31, 12)) });
  assert.ok(env.SCORES.data.has("scores:2026-W53:0"));
  const r = await vraag(env, "POST", "/scores/wis", { sleutel: sleutel(1) }, { nu: new Date(Date.UTC(2027, 0, 5, 12)) });
  assert.deepEqual(r.json, { verwijderd: 1 });
  assert.equal(env.SCORES.data.size, 0);
});

test("DELETE met een rest bewaart de rest met de verloopdatum van die week", async () => {
  const env = nieuweOmgeving();
  await post(env, geldig({ sleutel: sleutel(1), punten: 2500 }), { nu: OKTOBER });
  await post(env, geldig({ sleutel: sleutel(2), naam: "Ander" }), { nu: OKTOBER });
  await vraag(env, "DELETE", "/scores", { sleutel: sleutel(1) }, { nu: WEEK_NA });
  const k = "scores:2026-W42:1";
  assert.equal(JSON.parse(env.SCORES.data.get(k)).length, 1);
  assert.equal(env.SCORES.opties.get(k).expiration, Date.UTC(2026, 9, 26) / 1000);
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

test("POST /scores/wis doet hetzelfde als DELETE /scores", async () => {
  const env = nieuweOmgeving();
  await post(env, geldig({ dag: 1, sleutel: sleutel(1) }));
  await post(env, geldig({ dag: 1, sleutel: sleutel(2), naam: "Ander", minuut: 1200 }));
  const r = await vraag(env, "POST", "/scores/wis", { sleutel: sleutel(1) });
  assert.equal(r.status, 200);
  assert.deepEqual(r.json, { verwijderd: 1 });
  assert.equal((await haal(env, 1)).json.scores.length, 1);
  assert.equal((await vraag(env, "GET", "/scores/wis")).status, 405);
  assert.equal((await vraag(env, "POST", "/scores/wis", { sleutel: "abc" })).status, 400);
});

// ---- Sprints en bewaartermijn -----------------------------------------------

test("sprintVan: ISO-weken, met de jaargrens goed", () => {
  const w = (j, m, d, u = 12) => sprintVan(new Date(Date.UTC(j, m - 1, d, u)));
  assert.equal(w(2026, 10, 12), "2026-W42");
  assert.equal(w(2026, 10, 18, 23), "2026-W42"); // zondagavond
  assert.equal(w(2026, 10, 19, 0), "2026-W43"); // maandag middernacht
  assert.equal(w(2026, 1, 1), "2026-W01"); // donderdag: week 1 van 2026
  assert.equal(w(2025, 12, 29), "2026-W01"); // maandag ervóór hoort al bij 2026
  assert.equal(w(2026, 12, 31), "2026-W53");
  assert.equal(w(2027, 1, 1), "2026-W53");
  assert.equal(w(2027, 1, 3), "2026-W53");
  assert.equal(w(2027, 1, 4), "2027-W01");
  assert.equal(w(2020, 12, 31), "2020-W53");
  assert.equal(w(2021, 1, 3), "2020-W53");
  assert.equal(w(2021, 1, 4), "2021-W01");
  assert.equal(w(2024, 12, 30), "2025-W01");
  assert.equal(w(2018, 12, 31), "2019-W01");
  assert.equal(w(2016, 1, 1), "2015-W53");
  assert.equal(w(2025, 1, 1), "2025-W01");
  assert.equal(w(2026, 2, 28), "2026-W09");
  assert.equal(w(2024, 2, 29), "2024-W09"); // schrikkeldag
});

test("een nieuwe week begint met een leeg bord", async () => {
  const env = nieuweOmgeving();
  await post(env, geldig(), { nu: OKTOBER });
  assert.equal((await haal(env, 1, { nu: OKTOBER })).json.scores.length, 1);
  assert.equal((await haal(env, 1, { nu: WEEK_NA })).json.scores.length, 0);
  assert.equal((await haal(env, 1, { nu: WEEK_NA })).json.sprint, "2026-W43");
  // in de nieuwe week kan dezelfde sleutel weer een regel zetten, ook met minder punten
  assert.deepEqual((await post(env, geldig({ punten: 100 }), { nu: WEEK_NA })).json, { plek: 1 });
});

test("KV-sleutel is scores:<jjjj-Www>:<dag> en verloopt aan het einde van de week erna", async () => {
  const env = nieuweOmgeving();
  await post(env, geldig({ dag: 4 }), { nu: OKTOBER });
  const k = "scores:2026-W42:4";
  assert.ok(env.SCORES.data.has(k));
  const exp = env.SCORES.opties.get(k).expiration;
  assert.equal(exp, Date.UTC(2026, 9, 26) / 1000); // maandag 26 oktober 00:00 UTC
  const dagen = (exp * 1000 - OKTOBER.getTime()) / 864e5;
  assert.ok(dagen > 7 && dagen <= 14, `bewaartermijn ${dagen} dagen`);
});

test("de verloopdatum is voor de hele week dezelfde, van maandag tot zondag", async () => {
  const verwacht = Date.UTC(2026, 9, 26) / 1000;
  for (const nu of [new Date(Date.UTC(2026, 9, 12, 0, 0, 0)), new Date(Date.UTC(2026, 9, 15, 13)),
                    new Date(Date.UTC(2026, 9, 18, 23, 59, 59))]) {
    const env = nieuweOmgeving();
    await post(env, geldig(), { nu });
    assert.equal(env.SCORES.opties.get("scores:2026-W42:1").expiration, verwacht, nu.toISOString());
  }
});

test("over de jaargrens: 2026-W53 verloopt op maandag 11 januari 2027", async () => {
  const env = nieuweOmgeving();
  await post(env, geldig(), { nu: new Date(Date.UTC(2026, 11, 31, 12)) });
  assert.equal(env.SCORES.opties.get("scores:2026-W53:1").expiration, Date.UTC(2027, 0, 11) / 1000);
});

// ---- Slack ------------------------------------------------------------------

/** Een omgeving met webhook, een nep-fetch en een nep-ctx; `klaar()` wacht op wat er achter de rug om gebeurt. */
function slackOpstelling(opties = {}) {
  const webhook = "webhook" in opties ? opties.webhook : WEBHOOK;
  const env = nieuweOmgeving();
  if (webhook !== undefined) env.SLACK_WEBHOOK = webhook;
  const meldingen = [];
  const beloftes = [];
  const ctx = { waitUntil: (p) => beloftes.push(p) };
  const netwerk = async (url, init) => { meldingen.push({ url, init, tekst: JSON.parse(init.body).text }); return new Response("ok"); };
  const zet = (body, o = {}) => post(env, body, { ctx, netwerk, ...o });
  const klaar = () => Promise.all(beloftes);
  return { env, meldingen, ctx, netwerk, zet, klaar };
}

test("Slack: een nieuwe nummer 1 door iemand anders geeft precies \u00e9\u00e9n bericht", async () => {
  const { zet, meldingen, klaar } = slackOpstelling();
  await zet(geldig({ naam: "Eerste", punten: 1500, sleutel: sleutel(1) }));
  await klaar();
  meldingen.length = 0;
  const r = await zet(geldig({ naam: "Danny", minuut: 942, punten: 2340, sleutel: sleutel(2) }));
  assert.deepEqual(r.json, { plek: 1 });
  await klaar();
  assert.equal(meldingen.length, 1);
  const m = meldingen[0];
  assert.equal(m.url, WEBHOOK);
  assert.equal(m.init.method, "POST");
  assert.equal(m.init.headers["Content-Type"], "application/json");
  assert.deepEqual(Object.keys(JSON.parse(m.init.body)), ["text"]);
  assert.equal(m.tekst,
    "\u{1F3C6} *Danny* staat nu #1 op dinsdag met 2.340 punten (thuis om 15:42). " +
    "Wie gaat erover? https://daanbbd.github.io/10-tickets-naar-vrijheid/");
});

test("Slack: de allereerste inzending van de dag is ook een nieuwe nummer 1", async () => {
  const { zet, meldingen, klaar } = slackOpstelling();
  await zet(geldig({ dag: 0 }));
  await klaar();
  assert.equal(meldingen.length, 1);
  assert.match(meldingen[0].tekst, /op maandag met 2\.000 punten/);
});

test("Slack: niet als je je eigen nummer 1 verbetert", async () => {
  const { zet, meldingen, klaar } = slackOpstelling();
  await zet(geldig({ punten: 2000 }));
  await klaar();
  assert.equal(meldingen.length, 1);
  await zet(geldig({ punten: 2400 }));
  await klaar();
  assert.equal(meldingen.length, 1, "verbetering van je eigen #1 meldt niets");
  // en ook niet bij een gelijke tiebreak-verbetering
  await zet(geldig({ punten: 2400, minuut: 990 }));
  await klaar();
  assert.equal(meldingen.length, 1);
});

test("Slack: niet als je geen nummer 1 wordt, ook niet bij gelijke stand met de huidige", async () => {
  const { zet, meldingen, klaar } = slackOpstelling();
  await zet(geldig({ punten: 2500, sleutel: sleutel(1) }));
  await klaar();
  meldingen.length = 0;
  await zet(geldig({ punten: 2000, sleutel: sleutel(2) })); // plek 2
  await zet(geldig({ punten: 2500, sleutel: sleutel(3) })); // gelijk: achter de oudste
  await zet(geldig({ punten: 100, sleutel: sleutel(4) }));
  await klaar();
  assert.equal(meldingen.length, 0);
});

test("Slack: wie van plek 2 naar 1 stijgt, meldt zich wel", async () => {
  const { zet, meldingen, klaar } = slackOpstelling();
  await zet(geldig({ naam: "Een", punten: 2500, sleutel: sleutel(1) }));
  await zet(geldig({ naam: "Twee", punten: 2000, sleutel: sleutel(2) }));
  await klaar();
  meldingen.length = 0;
  await zet(geldig({ naam: "Twee", punten: 2600, sleutel: sleutel(2) }));
  await klaar();
  assert.equal(meldingen.length, 1);
  assert.match(meldingen[0].tekst, /\*Twee\* staat nu #1/);
});

test("Slack: de dagen hebben hun eigen nummer 1 en hun eigen naam", async () => {
  const { zet, meldingen, klaar } = slackOpstelling();
  for (let dag = 0; dag < 5; dag++) await zet(geldig({ dag }));
  await klaar();
  const dagen = meldingen.map((m) => m.tekst.match(/op (\w+) met/)[1]);
  assert.deepEqual(dagen, ["maandag", "dinsdag", "woensdag", "donderdag", "vrijdag"]);
});

test("Slack: zonder secret (of een lege) gebeurt er niets", async () => {
  for (const webhook of [undefined, "", "   ", "http://onveilig.example/hook"]) {
    const { zet, meldingen, klaar } = slackOpstelling({ webhook });
    const r = await zet(geldig());
    assert.equal(r.status, 200);
    await klaar();
    assert.equal(meldingen.length, 0, `webhook ${JSON.stringify(webhook)}`);
  }
});

test("Slack: een geweigerde of niet-bewaarde inzending meldt niets", async () => {
  const { zet, meldingen, klaar } = slackOpstelling();
  assert.equal((await zet(geldig({ punten: 99999 }))).status, 400);
  await klaar();
  assert.equal(meldingen.length, 0);
});

test("Slack: de naam wordt ge-escaped (&, <, >)", () => {
  const tekst = slackBericht({ naam: "A&B<c>", minuut: 1000, punten: 1234567 }, 2);
  assert.ok(tekst.includes("*A&amp;B&lt;c&gt;*"), tekst);
  assert.ok(!tekst.includes("<") && !tekst.includes(">"));
  assert.ok(tekst.includes("1.234.567 punten"));
});

test("Slack: getallen en tijden: duizendtallen met punt, tijd als uu:mm", () => {
  assert.match(slackBericht({ naam: "X", minuut: 600, punten: 999 }, 0), /met 999 punten \(thuis om 10:00\)/);
  assert.match(slackBericht({ naam: "X", minuut: 1019.9, punten: 1000 }, 0), /met 1\.000 punten \(thuis om 16:59\)/);
  assert.match(slackBericht({ naam: "X", minuut: 1020, punten: 3500 }, 4), /op vrijdag met 3\.500 punten \(thuis om 17:00\)/);
});

test("Slack: geen portret, sleutel, hash of rol in het bericht", async () => {
  const { zet, meldingen, klaar } = slackOpstelling();
  const s = sleutel(0xabc123);
  await zet(geldig({ sleutel: s, ontsnap: 30, rol: "Backend / AI & automatisering" }));
  await klaar();
  assert.equal(meldingen.length, 1);
  const alles = JSON.stringify(meldingen[0].init) + meldingen[0].tekst;
  for (const verboden of [PORTRET, PORTRET.slice(0, 40), s, createHash("sha256").update(s).digest("hex"),
                          "Backend", "automatisering", "ontsnap"]) {
    assert.ok(!alles.includes(verboden), `bericht bevat "${verboden}"`);
  }
});

test("Slack: een storing in Slack raakt de speler niet", async () => {
  const env = nieuweOmgeving();
  env.SLACK_WEBHOOK = WEBHOOK;
  const beloftes = [];
  const ctx = { waitUntil: (p) => beloftes.push(p) };
  for (const netwerk of [async () => { throw new Error("slack ligt eruit"); },
                         () => { throw new Error("sync stuk"); },
                         async () => new Response("nope", { status: 500 })]) {
    const r = await post(env, geldig({ punten: 100 + beloftes.length, sleutel: sleutel(beloftes.length + 1) }), { ctx, netwerk });
    assert.equal(r.status, 200);
  }
  const uitkomsten = await Promise.allSettled(beloftes);
  assert.equal(uitkomsten.length, 3);
  assert.ok(uitkomsten.every((u) => u.status === "fulfilled"), "fouten worden opgevangen");
});

test("Slack: het antwoord aan de speler wacht niet op Slack", async () => {
  const env = nieuweOmgeving();
  env.SLACK_WEBHOOK = WEBHOOK;
  let aangeroepen = 0;
  const netwerk = () => { aangeroepen++; return new Promise(() => {}); }; // komt nooit terug
  const ctx = { waitUntil() {} };
  const r = await post(env, geldig(), { ctx, netwerk });
  assert.equal(r.status, 200);
  assert.equal(aangeroepen, 1);
});

test("Slack: zonder ctx werkt het ook (het bericht gaat dan los de deur uit)", async () => {
  const { env, meldingen, netwerk } = slackOpstelling();
  const r = await post(env, geldig(), { netwerk });
  assert.equal(r.status, 200);
  await new Promise((klaar) => setImmediate(klaar));
  assert.equal(meldingen.length, 1);
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
  const lijst = JSON.parse(env.SCORES.data.get("scores:2026-W42:1"));
  assert.equal(lijst.length, 1);
  assert.deepEqual(Object.keys(lijst[0]).sort(), ["h", "minuut", "naam", "ontsnap", "portret", "punten", "rol", "sterren"]);
  assert.equal(lijst[0].h, createHash("sha256").update(s).digest("hex"));
  // een tijdstempel of id zit er nergens in
  assert.ok(!/"(t|ts|tijd|datum|id|ip|ua)"/.test(env.SCORES.data.get("scores:2026-W42:1")));
  // en alleen de score-sleutels, niets anders
  assert.deepEqual([...env.SCORES.data.keys()], ["scores:2026-W42:1"]);
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
