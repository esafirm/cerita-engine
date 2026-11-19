#!/usr/bin/env node
// Voice lines for Last Seen with Gemini TTS through treg (spec §6.1). Adapted from menolakngantor's gemini-voice.mjs.
//
//   node samples/last_seen/tools/voice.mjs [--dry-run] [--only vo_p_dinda_01,vo_p_dinda_02] [--locale id] [--retake]
//
// Reads `cerita_tools tts-manifest` (or --manifest <file>), renders each missing line and writes
// assets/story/music/<id>.<locale>.mp3, which the player picks before a shared <id>.mp3.
//
// - No API key here: `treg call` injects it server side.
// - The voice comes from voices.json, per character, the same for every locale. A line's `delivery` goes into
//   speechMetadata.style, never into the spoken text. `tts_text` (if set) is spoken in place of the displayed text.
// - Raw takes live in tools/.takes/ (git-ignored) and are never overwritten. The take name is the cache key:
//   <id>.<locale> first, then <id>.<locale>.r2, .r3... with --retake.
// - A line whose text or voice changed since its take is reported as stale and skipped: re-render it with --retake.
// - Leading and trailing silence is trimmed with ffmpeg, and loudness is normalized. No word timing pass.
import { existsSync, mkdirSync, readFileSync, writeFileSync, readdirSync } from 'node:fs';
import { spawnSync, execFileSync } from 'node:child_process';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const ENDPOINT = 'google-ai.voice-gen.gemini-3-8-flash-tts';
const here = dirname(fileURLToPath(import.meta.url));
const app = resolve(here, '..');
const repo = resolve(app, '../..');
const takesDir = join(here, '.takes');
const outDir = join(app, 'assets/story/music');

export function parseArgs(argv) {
  const opts = { dryRun: false, retake: false, only: null, locale: null, manifest: null };
  for (let i = 0; i < argv.length; i++) {
    const a = argv[i];
    if (a === '--dry-run') opts.dryRun = true;
    else if (a === '--retake') opts.retake = true;
    else if (a === '--only') opts.only = argv[++i].split(',').map((s) => s.trim()).filter(Boolean);
    else if (a === '--locale') opts.locale = argv[++i];
    else if (a === '--manifest') opts.manifest = argv[++i];
    else throw new Error(`Unknown option ${a}`);
  }
  return opts;
}

// The voice and style for one manifest line. A character missing from voices.json is an error, not a default voice.
export function resolveVoice(voices, line) {
  const key = voices.aliases?.[line.speaker] ?? line.speaker;
  const cast = voices.cast[key];
  if (!cast) throw new Error(`${line.id}: no voice for speaker '${line.speaker}' in voices.json`);
  const style = [voices.style, cast.style, line.delivery && `Delivery: ${line.delivery}.`].filter(Boolean).join(' ');
  return { voice: cast.voice, style };
}

export function buildRequest(text, voice, style) {
  return {
    contents: [{ parts: [{ text, speechMetadata: { style } }] }],
    generationConfig: { responseModalities: ['AUDIO'], speechConfig: { voiceConfig: { prebuiltVoiceConfig: { voiceName: voice } } } },
  };
}

// The takes of one line, oldest first: <id>.<locale>.json, then .r2.json, .r3.json...
function takesOf(base) {
  if (!existsSync(takesDir)) return [];
  const rank = (name) => Number(name.slice(base.length).match(/^\.r(\d+)\.json$/)?.[1] ?? 1);
  return readdirSync(takesDir)
    .filter((f) => f === `${base}.json` || /^\.r\d+\.json$/.test(f.slice(base.length)) && f.startsWith(base))
    .sort((a, b) => rank(a) - rank(b))
    .map((f) => ({ name: f.slice(0, -'.json'.length), ...JSON.parse(readFileSync(join(takesDir, f), 'utf8')) }));
}

function nextTakeName(base, takes) {
  return takes.length === 0 ? base : `${base}.r${takes.length + 1}`;
}

function loadManifest(opts) {
  if (opts.manifest) return JSON.parse(readFileSync(opts.manifest, 'utf8'));
  const r = spawnSync('dart', ['run', 'cerita_tools', 'tts-manifest', join(app, 'story')], { cwd: repo, encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
  if (r.status !== 0) throw new Error(`tts-manifest failed:\n${r.stderr}`);
  if (r.stderr.trim()) process.stderr.write(r.stderr);
  return JSON.parse(r.stdout);
}

function render(raw, out) {
  // Trim silence at both ends (reverse, trim the start, reverse back), then normalize to -16 LUFS.
  const trim = 'silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.06';
  execFileSync('ffmpeg', ['-y', '-v', 'error', '-i', raw, '-af', `${trim},areverse,${trim},areverse,loudnorm=I=-16:TP=-1.5:LRA=11`,
    '-ar', '24000', '-ac', '1', '-c:a', 'libmp3lame', '-q:a', '4', out]);
}

async function main() {
  const opts = parseArgs(process.argv.slice(2));
  const voices = JSON.parse(readFileSync(join(here, 'voices.json'), 'utf8'));
  const lines = loadManifest(opts).lines.filter((l) => (!opts.only || opts.only.includes(l.id)) && (!opts.locale || l.locale === opts.locale));

  const todo = [];
  const seen = new Set();
  for (const line of lines) {
    const base = `${line.id}.${line.locale}`;
    // A clip played in two scenes (vo_unsent_01 on Days 1 and 4) is one take, not two.
    if (seen.has(base)) continue;
    seen.add(base);
    const out = join(outDir, line.file);
    const text = line.tts_text ?? line.text;
    const { voice, style } = resolveVoice(voices, line);
    const takes = takesOf(base);
    const last = takes.at(-1);
    if (!opts.retake) {
      if (last && (last.text !== text || last.voice !== voice)) {
        console.log(`stale  ${line.file}: ${last.voice !== voice ? `voice ${last.voice} -> ${voice}` : 'text changed'}. Use --retake --only ${line.id}`);
        continue;
      }
      // A committed clip without a local take is done: it was rendered elsewhere.
      if (existsSync(out)) continue;
    }
    todo.push({ line, base, out, text, voice, style, takes });
  }

  const chars = todo.reduce((n, t) => n + t.text.length, 0);
  console.log(`${todo.length} takes, ${chars} characters. Past charges: about $0.001 to $0.002 per short take.`);
  if (opts.dryRun) {
    for (const t of todo) console.log(`[dry] ${t.line.file} [${t.voice}] "${t.text}" (${t.style})`);
    return;
  }

  mkdirSync(takesDir, { recursive: true });
  mkdirSync(outDir, { recursive: true });
  for (const t of todo) {
    // A take with the same text and voice but no clip (say, a deleted mp3) is rendered again from its raw take.
    const reuse = !opts.retake && t.takes.at(-1);
    const name = reuse ? reuse.name : nextTakeName(t.base, t.takes);
    const raw = join(takesDir, `${name}.wav`);
    let take = reuse;
    if (!reuse) {
      if (existsSync(raw)) throw new Error(`${name}: raw take exists without its JSON. Move it aside, never overwrite it.`);
      const reqPath = join(takesDir, `${name}.request.json`);
      writeFileSync(reqPath, JSON.stringify(buildRequest(t.text, t.voice, t.style), null, 2));
      const r = spawnSync('treg', ['call', ENDPOINT, '--method', 'POST', '--query', `model=${voices.model}`, '--file', reqPath, '--timeout', '120'],
        { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 });
      if (r.status !== 0) throw new Error(`${name} failed: ${(r.stderr || r.stdout).slice(0, 400)}`);
      const part = JSON.parse(r.stdout).candidates?.[0]?.content?.parts?.find((p) => p.inlineData);
      if (!part) throw new Error(`${name}: no audio in the response`);
      const audio = Buffer.from(part.inlineData.data, 'base64');
      // Gemini returns either a WAV or bare 24 kHz 16-bit mono PCM.
      if (audio.toString('ascii', 0, 4) === 'RIFF') writeFileSync(raw, audio);
      else execFileSync('ffmpeg', ['-y', '-v', 'error', '-f', 's16le', '-ar', '24000', '-ac', '1', '-i', 'pipe:0', raw], { input: audio });
      take = {
        id: t.line.id, locale: t.line.locale, text: t.text, voice: t.voice, style: t.style, model: voices.model,
        cost_usd: Number((r.stderr.match(/charged \$([0-9.]+)/) || [])[1] ?? NaN),
        call_id: (r.stderr.match(/call id ([0-9a-f]+)/) || [])[1] ?? null,
        source: t.line.source,
      };
      writeFileSync(join(takesDir, `${name}.json`), JSON.stringify(take, null, 2));
    }
    render(raw, t.out);
    console.log(`${t.line.file} <- ${name} [${t.voice}] $${take.cost_usd}`);
  }
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  main().catch((e) => {
    console.error(e.message);
    process.exit(1);
  });
}
