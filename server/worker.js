// Het scorebord van 10 Tickets naar Vrijheid: een Cloudflare Worker met één
// Workers KV-namespace (binding `SCORES`). Geen dependencies.
//
// Wat hier staat is bewust klein en saai. De beloftes aan collega's staan in
// README.md; de code hieronder is de plek waar je kunt nakijken dat ze kloppen:
//   - er wordt nergens gelezen: IP, User-Agent, cookies. Er is geen console.*.
//   - de sleutel van de speler wordt gehasht en dan weggegooid.
//   - alles wat niet exact past, wordt geweigerd.

// ---- Instellingen -----------------------------------------------------------

/** Alleen deze websites mogen het scorebord vanuit een browser gebruiken. */
export const TOEGESTANE_ORIGINS = [
  "https://daanbbd.github.io",
  "http://localhost:8060",
  "http://127.0.0.1:8060",
];

const TOP = 20; // zo veel regels per dag per maand
const MAX_BODY = 4096; // bytes
const DAGEN = 5; // dag 0..4
const MINUUT_MIN = 600; // 10:00; niemand is eerder klaar
const MINUUT_MAX = 1800;
const NAAM_MAX = 12;
const PORTRET_LENGTE = 32 * 40; // zie scripts/rush/rush_pixel.gd

// Een maand-sleutel verdwijnt uit KV op de 10e van de maand erna. Een regel
// leeft dus 10 tot 41 dagen, nooit langer.
const EXTRA_DAGEN_NA_MAAND = 10;

// De zes rollen van een zelfgemaakt personage (RushProfiel.ROL_NAAM) en de
// rollen van de zeven vaste personages (data/characters.json, veld `role`).
export const ROLLEN = [
  "Developer",
  "Design",
  "Sales",
  "Support",
  "Operations",
  "Consultant",
  "Product Owner",
  "CRO-specialist",
  "Frontend developer",
  "Backend developer",
  "Client Lead",
  "Backend / AI & automatisering",
];

// Een spam-rem, geen filter. Bewust kort. Hele woorden (`WOORDEN`) worden alleen
// geweigerd als ze los in de naam staan, zodat "Lulu" door mag. Langere,
// ondubbelzinnige scheldwoorden (`DELEN`) zijn ook geweigerd als stukje van een naam.
const WOORDEN = ["kut", "lul", "hoer", "slet", "nazi", "pik", "kloot", "eikel", "flikker", "kkr", "tbc"];
const DELEN = ["kanker", "tering", "tyfus", "mongool", "hitler", "fuck", "shit", "cunt", "nigger", "nigga", "bitch", "whore"];

// ---- Valideren --------------------------------------------------------------

const TOEGESTANE_VELDEN = ["dag", "naam", "rol", "minuut", "ontsnap", "portret", "sleutel"];
const NAAM_PATROON = /^[\p{Script=Latin}0-9 _-]+$/u;
const PORTRET_PATROON = /^[0-9a-v]*$/;
const SLEUTEL_PATROON = /^[0-9a-f]{32}$/;

/** Sterren uit de eindtijd, dezelfde regels als `RushData.sterren_voor()`. */
export function sterrenVoor(minuut) {
  if (minuut <= 17 * 60) return 3;
  if (minuut <= 18 * 60 + 30) return 2;
  return 1;
}

function isDag(d) {
  return Number.isInteger(d) && d >= 0 && d < DAGEN;
}

function rond(n) {
  return Math.round(n * 10) / 10;
}

function vereenvoudig(naam) {
  return naam
    .normalize("NFD")
    .replace(/\p{M}/gu, "")
    .toLowerCase()
    .replace(/0/g, "o")
    .replace(/1/g, "i")
    .replace(/3/g, "e")
    .replace(/4/g, "a")
    .replace(/5/g, "s")
    .replace(/7/g, "t");
}

/** True als de naam op de korte scheldlijst staat. */
export function naamGeblokkeerd(naam) {
  const schoon = vereenvoudig(naam);
  const losse = schoon.split(/[ _-]+/).filter(Boolean);
  const aaneen = losse.join("");
  // Ook uitgespeld ("k u t") telt: dan is de samengevoegde naam het woord.
  if (losse.some((w) => WOORDEN.includes(w)) || WOORDEN.includes(aaneen)) return true;
  return DELEN.some((d) => aaneen.includes(d));
}

/**
 * Controleert een POST-body. Geeft `{regel, sleutel}` terug, of `{fout}`.
 * Wat niet exact past wordt geweigerd; onbekende velden ook.
 */
export function valideerScore(b) {
  if (b === null || typeof b !== "object" || Array.isArray(b)) return { fout: "geen object" };
  for (const k of Object.keys(b)) {
    if (!TOEGESTANE_VELDEN.includes(k)) return { fout: "onbekend veld" };
  }
  for (const k of TOEGESTANE_VELDEN) {
    if (!(k in b)) return { fout: `ontbreekt: ${k}` };
  }
  if (!isDag(b.dag)) return { fout: "dag" };

  if (typeof b.naam !== "string") return { fout: "naam" };
  const naam = b.naam.normalize("NFC").trim();
  if ([...naam].length < 1 || [...naam].length > NAAM_MAX || !NAAM_PATROON.test(naam)) {
    return { fout: "naam" };
  }
  if (naamGeblokkeerd(naam)) return { fout: "naam niet toegestaan" };

  if (typeof b.rol !== "string" || !ROLLEN.includes(b.rol)) return { fout: "rol" };

  if (typeof b.minuut !== "number" || !Number.isFinite(b.minuut) ||
      b.minuut < MINUUT_MIN || b.minuut > MINUUT_MAX) {
    return { fout: "minuut" };
  }
  const minuut = rond(b.minuut);

  if (typeof b.ontsnap !== "number" || !Number.isFinite(b.ontsnap) ||
      !(b.ontsnap === -1 || (b.ontsnap >= 8 && b.ontsnap <= 300))) {
    return { fout: "ontsnap" };
  }
  const ontsnap = b.ontsnap === -1 ? -1 : rond(b.ontsnap);

  if (typeof b.portret !== "string" ||
      !(b.portret === "" || (b.portret.length === PORTRET_LENGTE && PORTRET_PATROON.test(b.portret)))) {
    return { fout: "portret" };
  }

  if (typeof b.sleutel !== "string" || !SLEUTEL_PATROON.test(b.sleutel)) return { fout: "sleutel" };

  return {
    sleutel: b.sleutel,
    dag: b.dag,
    regel: { naam, rol: b.rol, minuut, sterren: sterrenVoor(minuut), ontsnap, portret: b.portret },
  };
}

// ---- Hulpjes ----------------------------------------------------------------

/** SHA-256 van de sleutel, als hex. Alleen dit wordt bewaard. */
export async function hash(sleutel) {
  const bytes = new TextEncoder().encode(sleutel);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)].map((x) => x.toString(16).padStart(2, "0")).join("");
}

/** "2026-10": de huidige sprint (kalendermaand, UTC). */
export function sprintVan(datum) {
  return `${datum.getUTCFullYear()}-${String(datum.getUTCMonth() + 1).padStart(2, "0")}`;
}

function vorigeSprint(datum) {
  return sprintVan(new Date(Date.UTC(datum.getUTCFullYear(), datum.getUTCMonth() - 1, 1)));
}

const sleutelNaam = (sprint, dag) => `scores:${sprint}:${dag}`;

/** Unix-seconden waarop de maand-sleutel uit KV verdwijnt. */
function verlooptOp(datum) {
  const volgendeMaand = Date.UTC(datum.getUTCFullYear(), datum.getUTCMonth() + 1, 1 + EXTRA_DAGEN_NA_MAAND);
  return Math.floor(volgendeMaand / 1000);
}

function corsHeaders(origin) {
  if (!origin || !TOEGESTANE_ORIGINS.includes(origin)) return {};
  return {
    "Access-Control-Allow-Origin": origin,
    "Access-Control-Allow-Methods": "GET, POST, DELETE, OPTIONS",
    "Access-Control-Allow-Headers": "Content-Type",
    "Access-Control-Max-Age": "86400",
    Vary: "Origin",
  };
}

function antwoord(status, data, origin, extra = {}) {
  return new Response(data === null ? null : JSON.stringify(data), {
    status,
    headers: {
      ...(data === null ? {} : { "Content-Type": "application/json; charset=utf-8" }),
      "Cache-Control": "no-store",
      "X-Content-Type-Options": "nosniff",
      ...corsHeaders(origin),
      ...extra,
    },
  });
}

const fout = (status, tekst, origin, extra) => antwoord(status, { fout: tekst }, origin, extra);

/** Leest de body met een harde bovengrens, ook als Content-Length ontbreekt of liegt. */
async function leesBody(request) {
  const lengte = Number(request.headers.get("Content-Length"));
  if (Number.isFinite(lengte) && lengte > MAX_BODY) return null;
  if (!request.body) return "";
  const lezer = request.body.getReader();
  const stukken = [];
  let totaal = 0;
  for (;;) {
    const { done, value } = await lezer.read();
    if (done) break;
    totaal += value.byteLength;
    if (totaal > MAX_BODY) {
      await lezer.cancel();
      return null;
    }
    stukken.push(value);
  }
  const alles = new Uint8Array(totaal);
  let pos = 0;
  for (const s of stukken) {
    alles.set(s, pos);
    pos += s.byteLength;
  }
  return new TextDecoder("utf-8", { fatal: true }).decode(alles);
}

async function leesJson(request, origin) {
  const type = (request.headers.get("Content-Type") || "").toLowerCase();
  if (!type.startsWith("application/json")) return { antwoord: fout(415, "geen json", origin) };
  let tekst;
  try {
    tekst = await leesBody(request);
  } catch {
    return { antwoord: fout(400, "geen geldige tekst", origin) };
  }
  if (tekst === null) return { antwoord: fout(413, "te groot", origin) };
  try {
    return { body: JSON.parse(tekst) };
  } catch {
    return { antwoord: fout(400, "geen geldige json", origin) };
  }
}

async function leesLijst(env, sprint, dag) {
  const lijst = await env.SCORES.get(sleutelNaam(sprint, dag), "json");
  return Array.isArray(lijst) ? lijst : [];
}

/** Op minuut oplopend; bij gelijke tijd blijft de oudste voor (stabiele sortering). */
function sorteer(lijst) {
  return lijst.sort((a, b) => a.minuut - b.minuut);
}

// ---- De drie routes ---------------------------------------------------------

async function haalScores(url, env, nu, origin) {
  const ruw = url.searchParams.get("dag");
  if (ruw === null || !/^\d$/.test(ruw) || !isDag(Number(ruw))) return fout(400, "dag", origin);
  const lijst = sorteer(await leesLijst(env, sprintVan(nu), Number(ruw))).slice(0, TOP);
  // Zonder `h`: de hash van de sleutel verlaat de server nooit.
  const scores = lijst.map(({ naam, rol, minuut, sterren, ontsnap, portret }) =>
    ({ naam, rol, minuut, sterren, ontsnap, portret }));
  return antwoord(200, { scores }, origin);
}

async function zetScore(request, env, nu, origin) {
  const gelezen = await leesJson(request, origin);
  if (gelezen.antwoord) return gelezen.antwoord;
  const v = valideerScore(gelezen.body);
  if (v.fout) return fout(400, v.fout, origin);

  const h = await hash(v.sleutel);
  const sprint = sprintVan(nu);
  const lijst = await leesLijst(env, sprint, v.dag);
  const nieuw = { h, ...v.regel };

  const bestaand = lijst.findIndex((r) => r.h === h);
  if (bestaand >= 0) {
    const oud = lijst[bestaand];
    const beter = nieuw.minuut < oud.minuut ||
      (nieuw.minuut === oud.minuut && nieuw.ontsnap !== -1 && (oud.ontsnap === -1 || nieuw.ontsnap < oud.ontsnap));
    if (!beter) {
      // Je oude regel blijft staan; je hoort waar die staat.
      return antwoord(200, { plek: sorteer(lijst).indexOf(oud) + 1 }, origin);
    }
    lijst.splice(bestaand, 1);
  }

  lijst.push(nieuw);
  const top = sorteer(lijst).slice(0, TOP);
  const plek = top.indexOf(nieuw) + 1;
  if (plek === 0 && bestaand < 0) {
    // Haalt de top niet en verdrong niets: er hoeft niets bewaard te worden.
    return antwoord(200, { plek: 0 }, origin);
  }
  await env.SCORES.put(sleutelNaam(sprint, v.dag), JSON.stringify(top), { expiration: verlooptOp(nu) });
  return antwoord(200, { plek }, origin);
}

async function wisScores(request, env, nu, origin) {
  const gelezen = await leesJson(request, origin);
  if (gelezen.antwoord) return gelezen.antwoord;
  const b = gelezen.body;
  if (b === null || typeof b !== "object" || Array.isArray(b) ||
      Object.keys(b).length !== 1 || typeof b.sleutel !== "string" || !SLEUTEL_PATROON.test(b.sleutel)) {
    return fout(400, "sleutel", origin);
  }
  const h = await hash(b.sleutel);
  let verwijderd = 0;
  // Door de vaste verloopdatum bestaan er hooguit twee maanden tegelijk.
  for (const sprint of [sprintVan(nu), vorigeSprint(nu)]) {
    for (let dag = 0; dag < DAGEN; dag++) {
      const naam = sleutelNaam(sprint, dag);
      const lijst = await leesLijst(env, sprint, dag);
      const rest = lijst.filter((r) => r.h !== h);
      if (rest.length === lijst.length) continue;
      verwijderd += lijst.length - rest.length;
      const exp = verlooptOp(sprintDatum(sprint));
      // KV eist minstens een minuut vooruit; zo kort voor het verlopen is weggooien genoeg.
      if (rest.length === 0 || exp * 1000 - nu.getTime() < 120000) await env.SCORES.delete(naam);
      else await env.SCORES.put(naam, JSON.stringify(rest), { expiration: exp });
    }
  }
  return antwoord(200, { verwijderd }, origin);
}

/** De eerste dag van een sprint "JJJJ-MM", om de verloopdatum van die maand te vinden. */
function sprintDatum(sprint) {
  const [j, m] = sprint.split("-").map(Number);
  return new Date(Date.UTC(j, m - 1, 1));
}

// ---- Ingang -----------------------------------------------------------------

/** De hele afhandeling; `nu` is een functie zodat tests de klok kunnen vastzetten. */
export async function verwerk(request, env, nu = () => new Date()) {
  const origin = request.headers.get("Origin");
  // Een browser van een andere website komt er niet in. Zonder Origin (curl,
  // het spel op desktop) is er niets om te toetsen; dat is bewust.
  if (origin !== null && !TOEGESTANE_ORIGINS.includes(origin)) return fout(403, "origin", null);

  const url = new URL(request.url);
  // `POST /scores/wis` doet hetzelfde als `DELETE /scores`: niet elke
  // HTTP-client (Godot op het web) stuurt een body mee bij DELETE.
  if (url.pathname === "/scores/wis") {
    if (request.method === "OPTIONS") {
      return new Response(null, { status: 204, headers: { "Cache-Control": "no-store", ...corsHeaders(origin) } });
    }
    if (request.method !== "POST") return fout(405, "methode", origin, { Allow: "POST, OPTIONS" });
    try {
      return await wisScores(request, env, nu(), origin);
    } catch {
      return fout(500, "er ging iets mis", origin);
    }
  }
  if (url.pathname !== "/scores") return fout(404, "onbekend", origin);

  if (request.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: { "Cache-Control": "no-store", ...corsHeaders(origin) } });
  }
  try {
    const nuDatum = nu();
    if (request.method === "GET") return await haalScores(url, env, nuDatum, origin);
    if (request.method === "POST") return await zetScore(request, env, nuDatum, origin);
    if (request.method === "DELETE") return await wisScores(request, env, nuDatum, origin);
    return fout(405, "methode", origin, { Allow: "GET, POST, DELETE, OPTIONS" });
  } catch {
    // Bewust geen log: ook een foutmelding kan een naam of tijd bevatten.
    return fout(500, "er ging iets mis", origin);
  }
}

export default {
  fetch(request, env) {
    return verwerk(request, env);
  },
};
