// Het scorebord van 10 Tickets naar Vrijheid: een Cloudflare Worker met één
// Workers KV-namespace (binding `SCORES`). Geen dependencies.
//
// Wat hier staat is bewust klein en saai. De beloftes aan collega's staan in
// README.md; de code hieronder is de plek waar je kunt nakijken dat ze kloppen:
//   - er wordt nergens gelezen: IP, User-Agent, cookies. Er is geen console.*.
//   - de sleutel van de speler wordt gehasht en dan weggegooid.
//   - alles wat niet exact past, wordt geweigerd.
//   - er gaat alleen iets de deur uit als jij de Slack-webhook zelf hebt aangezet
//     (secret `SLACK_WEBHOOK`): één regel tekst, zonder portret of sleutel.

// ---- Instellingen -----------------------------------------------------------

/** Alleen deze websites mogen het scorebord vanuit een browser gebruiken. */
export const TOEGESTANE_ORIGINS = [
  "https://daanbbd.github.io",
  "http://localhost:8060",
  "http://127.0.0.1:8060",
];

const TOP = 20; // zo veel regels per dag per sprint (week)
const MAX_BODY = 4096; // bytes
const DAGEN = 5; // dag 0..4
const MINUUT_MIN = 600; // 10:00; niemand is eerder klaar
const MINUUT_MAX = 1800;
const NAAM_MAX = 12;
const PORTRET_LENGTE = 32 * 40; // zie scripts/rush/rush_pixel.gd

const DAG_MS = 24 * 60 * 60 * 1000;
const DAGNAMEN = ["maandag", "dinsdag", "woensdag", "donderdag", "vrijdag"]; // dag 0..4

// Waar de Slack-melding naar verwijst.
const SPEL_ADRES = "https://daanbbd.github.io/10-tickets-naar-vrijheid/";

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

const TOEGESTANE_VELDEN = ["dag", "naam", "rol", "minuut", "ontsnap", "punten", "portret", "sleutel"];
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

/**
 * De bovengrens van `punten` bij deze eindtijd en ontsnaptijd. Het is de
 * formule uit het spel, op zijn gunstigst: basis 1000, een tijdbonus van 5 per
 * minuut vóór 17:00 (1020), reeks, spoedtickets en dubbel-punten samen hooguit
 * ~2500, en een ontsnapbonus van 10 per seconde onder de 40 s (alleen als je
 * ontsnapte). Naar beneden afgerond.
 *
 * Dit is geen anti-cheat: wie `curl` gebruikt kan nog steeds precies de grens
 * invullen. Het is een zeef tegen onzin (negatieve punten, een miljoen punten,
 * een tikfout), meer niet; zie "Valsspelen gaat op vertrouwen" in README.md.
 */
export function maxPunten(minuut, ontsnap) {
  const tijdbonus = Math.max(0, 1020 - minuut) * 5;
  const ontsnapbonus = ontsnap >= 0 ? Math.max(0, 40 - ontsnap) * 10 : 0;
  return Math.floor(1000 + tijdbonus + 2500 + ontsnapbonus);
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

  if (!Number.isInteger(b.punten) || b.punten < 0 || b.punten > maxPunten(minuut, ontsnap)) {
    return { fout: "punten" };
  }

  if (typeof b.portret !== "string" ||
      !(b.portret === "" || (b.portret.length === PORTRET_LENGTE && PORTRET_PATROON.test(b.portret)))) {
    return { fout: "portret" };
  }

  if (typeof b.sleutel !== "string" || !SLEUTEL_PATROON.test(b.sleutel)) return { fout: "sleutel" };

  return {
    sleutel: b.sleutel,
    dag: b.dag,
    regel: { naam, rol: b.rol, minuut, sterren: sterrenVoor(minuut), ontsnap, punten: b.punten, portret: b.portret },
  };
}

// ---- Hulpjes ----------------------------------------------------------------

/** SHA-256 van de sleutel, als hex. Alleen dit wordt bewaard. */
export async function hash(sleutel) {
  const bytes = new TextEncoder().encode(sleutel);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return [...new Uint8Array(digest)].map((x) => x.toString(16).padStart(2, "0")).join("");
}

/**
 * "2026-W42": de huidige sprint, een ISO-week (UTC). Een week loopt van maandag
 * tot en met zondag en hoort bij het jaar waarin haar donderdag valt; zo is
 * 2026-12-31 nog 2026-W53 en 2020-12-31 ook W53 van 2020.
 */
export function sprintVan(datum) {
  const donderdag = new Date(Date.UTC(datum.getUTCFullYear(), datum.getUTCMonth(), datum.getUTCDate()));
  donderdag.setUTCDate(donderdag.getUTCDate() + 3 - ((donderdag.getUTCDay() + 6) % 7));
  const jaar = donderdag.getUTCFullYear();
  const dagVanJaar = Math.round((donderdag.getTime() - Date.UTC(jaar, 0, 1)) / DAG_MS);
  const week = Math.floor(dagVanJaar / 7) + 1;
  return `${jaar}-W${String(week).padStart(2, "0")}`;
}

/** Dezelfde tijd een week eerder: waar de vorige sprint te vinden is. */
function weekEerder(datum) {
  return new Date(datum.getTime() - 7 * DAG_MS);
}

const sleutelNaam = (sprint, dag) => `scores:${sprint}:${dag}`;

/**
 * Unix-seconden waarop de sleutel van de sprint van `datum` uit KV verdwijnt:
 * het einde van de week erna, dus de maandag 00:00 UTC twee weken na de maandag
 * van deze sprint. Een sleutel leeft zo 7 tot 14 dagen, nooit langer.
 */
function verlooptOp(datum) {
  const dag0 = Date.UTC(datum.getUTCFullYear(), datum.getUTCMonth(), datum.getUTCDate());
  const maandag = dag0 - ((new Date(dag0).getUTCDay() + 6) % 7) * DAG_MS;
  return Math.floor((maandag + 14 * DAG_MS) / 1000);
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

/**
 * De rangschikking: negatief als `a` boven `b` hoort. Meer punten eerst; bij
 * gelijke punten de lagere `minuut`, dan de snellere `ontsnap` (-1, niet
 * ontsnapt, telt als de langzaamste).
 */
function vergelijk(a, b) {
  if (a.punten !== b.punten) return b.punten - a.punten;
  if (a.minuut !== b.minuut) return a.minuut - b.minuut;
  const sa = a.ontsnap === -1 ? Infinity : a.ontsnap;
  const sb = b.ontsnap === -1 ? Infinity : b.ontsnap;
  if (sa === sb) return 0;
  return sa < sb ? -1 : 1;
}

/** Sorteert op `vergelijk`; bij een volledig gelijke stand blijft de oudste voor (stabiel). */
function sorteer(lijst) {
  return lijst.sort(vergelijk);
}

/** Wat een speler te zien krijgt. Zonder `h`: de hash van de sleutel verlaat de server nooit. */
function openbaar({ naam, rol, minuut, sterren, ontsnap, punten, portret }) {
  return { naam, rol, minuut, sterren, ontsnap, punten, portret };
}

// ---- Slack ------------------------------------------------------------------

/** 2340 wordt "2.340". Zonder toLocaleString: dat hangt af van de ICU-data van de host. */
function metPunten(n) {
  return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, ".");
}

/** Slack leest `&`, `<` en `>` als opmaak. */
function slackEscape(tekst) {
  return tekst.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

/**
 * De melding voor een nieuwe nummer 1. Alleen bijnaam, dag, punten en tijd:
 * geen portret, geen rol, geen sleutel of hash.
 */
export function slackBericht(regel, dag) {
  const uur = Math.floor(regel.minuut / 60);
  const min = Math.floor(regel.minuut % 60);
  const tijd = `${String(uur).padStart(2, "0")}:${String(min).padStart(2, "0")}`;
  return `\u{1F3C6} *${slackEscape(regel.naam)}* staat nu #1 op ${DAGNAMEN[dag]} met ` +
    `${metPunten(regel.punten)} punten (thuis om ${tijd}). Wie gaat erover? ${SPEL_ADRES}`;
}

/**
 * Eén POST naar de webhook. Fouten worden bewust genegeerd en niets wordt
 * gelogd: de melding is een extraatje, de score is al bewaard.
 */
async function stuurSlack(webhook, regel, dag, netwerk) {
  try {
    await netwerk(webhook, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ text: slackBericht(regel, dag) }),
    });
  } catch {
    // genegeerd
  }
}

// ---- De routes --------------------------------------------------------------

async function haalScores(url, env, nu, origin) {
  const ruw = url.searchParams.get("dag");
  if (ruw === null || !/^\d$/.test(ruw) || !isDag(Number(ruw))) return fout(400, "dag", origin);
  const sprint = sprintVan(nu);
  const lijst = sorteer(await leesLijst(env, sprint, Number(ruw))).slice(0, TOP);
  return antwoord(200, { sprint, scores: lijst.map(openbaar) }, origin);
}

/** De nummer 1 van elke dag in één antwoord: vijf reads, `null` voor een lege dag. */
async function haalKoplopers(env, nu, origin) {
  const sprint = sprintVan(nu);
  const lijsten = await Promise.all(Array.from({ length: DAGEN }, (_, dag) => leesLijst(env, sprint, dag)));
  const dagen = lijsten.map((lijst) => {
    const eerste = sorteer(lijst)[0];
    return eerste ? openbaar(eerste) : null;
  });
  return antwoord(200, { sprint, dagen }, origin);
}

async function zetScore(request, env, nu, origin, ctx, netwerk) {
  const gelezen = await leesJson(request, origin);
  if (gelezen.antwoord) return gelezen.antwoord;
  const v = valideerScore(gelezen.body);
  if (v.fout) return fout(400, v.fout, origin);

  const h = await hash(v.sleutel);
  const sprint = sprintVan(nu);
  const lijst = await leesLijst(env, sprint, v.dag);
  const nieuw = { h, ...v.regel };
  const vorigeNummerEen = sorteer([...lijst])[0];

  const bestaand = lijst.findIndex((r) => r.h === h);
  if (bestaand >= 0) {
    const oud = lijst[bestaand];
    if (vergelijk(nieuw, oud) >= 0) {
      // Je oude regel blijft staan (even goed telt niet als beter); je hoort waar die staat.
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

  // Alleen als er een webhook is ingesteld, jij nummer 1 werd en dat eerst
  // iemand anders was (of niemand): één bericht, waar de speler niet op wacht.
  const webhook = typeof env.SLACK_WEBHOOK === "string" ? env.SLACK_WEBHOOK.trim() : "";
  if (webhook.startsWith("https://") && plek === 1 && (!vorigeNummerEen || vorigeNummerEen.h !== h)) {
    const bericht = stuurSlack(webhook, nieuw, v.dag, netwerk);
    if (ctx && typeof ctx.waitUntil === "function") ctx.waitUntil(bericht);
  }
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
  // Door de vaste verloopdatum bestaan er hooguit twee weken tegelijk.
  for (const moment of [nu, weekEerder(nu)]) {
    const sprint = sprintVan(moment);
    for (let dag = 0; dag < DAGEN; dag++) {
      const naam = sleutelNaam(sprint, dag);
      const lijst = await leesLijst(env, sprint, dag);
      const rest = lijst.filter((r) => r.h !== h);
      if (rest.length === lijst.length) continue;
      verwijderd += lijst.length - rest.length;
      const exp = verlooptOp(moment);
      // KV eist minstens een minuut vooruit; zo kort voor het verlopen is weggooien genoeg.
      if (rest.length === 0 || exp * 1000 - nu.getTime() < 120000) await env.SCORES.delete(naam);
      else await env.SCORES.put(naam, JSON.stringify(rest), { expiration: exp });
    }
  }
  return antwoord(200, { verwijderd }, origin);
}

// ---- Ingang -----------------------------------------------------------------

const voorvlucht = (origin) =>
  new Response(null, { status: 204, headers: { "Cache-Control": "no-store", ...corsHeaders(origin) } });

/**
 * De hele afhandeling. `nu` is een functie zodat tests de klok kunnen vastzetten;
 * `ctx` is de ExecutionContext van Workers (voor `waitUntil`, optioneel); `netwerk`
 * is de fetch voor de Slack-melding, zodat tests niets echt versturen.
 */
export async function verwerk(request, env, nu = () => new Date(), ctx = undefined,
    netwerk = (...args) => fetch(...args)) {
  const origin = request.headers.get("Origin");
  // Een browser van een andere website komt er niet in. Zonder Origin (curl,
  // het spel op desktop) is er niets om te toetsen; dat is bewust.
  if (origin !== null && !TOEGESTANE_ORIGINS.includes(origin)) return fout(403, "origin", null);

  const url = new URL(request.url);
  // `POST /scores/wis` doet hetzelfde als `DELETE /scores`: niet elke
  // HTTP-client (Godot op het web) stuurt een body mee bij DELETE.
  if (url.pathname === "/scores/wis") {
    if (request.method === "OPTIONS") return voorvlucht(origin);
    if (request.method !== "POST") return fout(405, "methode", origin, { Allow: "POST, OPTIONS" });
    try {
      return await wisScores(request, env, nu(), origin);
    } catch {
      return fout(500, "er ging iets mis", origin);
    }
  }
  if (url.pathname === "/koplopers") {
    if (request.method === "OPTIONS") return voorvlucht(origin);
    if (request.method !== "GET") return fout(405, "methode", origin, { Allow: "GET, OPTIONS" });
    try {
      return await haalKoplopers(env, nu(), origin);
    } catch {
      return fout(500, "er ging iets mis", origin);
    }
  }
  if (url.pathname !== "/scores") return fout(404, "onbekend", origin);

  if (request.method === "OPTIONS") return voorvlucht(origin);
  try {
    const nuDatum = nu();
    if (request.method === "GET") return await haalScores(url, env, nuDatum, origin);
    if (request.method === "POST") return await zetScore(request, env, nuDatum, origin, ctx, netwerk);
    if (request.method === "DELETE") return await wisScores(request, env, nuDatum, origin);
    return fout(405, "methode", origin, { Allow: "GET, POST, DELETE, OPTIONS" });
  } catch {
    // Bewust geen log: ook een foutmelding kan een naam of tijd bevatten.
    return fout(500, "er ging iets mis", origin);
  }
}

export default {
  fetch(request, env, ctx) {
    return verwerk(request, env, undefined, ctx);
  },
};
