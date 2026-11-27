#!/usr/bin/env python3
"""VO1: render AI text-to-speech voice-over (Kokoro-82M, Apache-2.0) for every voiced dialogue line and shloka.

Usage (from the repo root):
  /home/sameer/git/game-factory/tools/tts/.venv/bin/python tools/vo/generate_vo.py [--only KEY] [--force]

Outputs assets/vo/en/<TEXT_KEY>.ogg, assets/vo/hi/<TEXT_KEY>.ogg, assets/vo/sa/<shloka_id>.ogg.
Incremental: assets/vo/manifest.json stores a hash of (text + cast entry) per clip; unchanged clips are skipped.
"""
import argparse
import csv
import glob
import hashlib
import json
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "assets", "vo")
MANIFEST = os.path.join(OUT, "manifest.json")
SAMPLE_RATE = 24000


def clean_text(text):
    """Strip surrounding quotes. Returns '' for a stage direction (a line fully in parentheses): not voiced."""
    t = text.strip()
    if t.startswith("(") and t.endswith(")"):
        return ""
    t = t.strip('"“”').strip()
    t = re.sub(r"\([^)]*\)", " ", t)  # inline stage directions
    return re.sub(r"\s+", " ", t).strip()


def collect_jobs():
    cast = json.load(open(os.path.join(ROOT, "data", "vo_cast.json"), encoding="utf-8"))
    rows = {r["keys"]: r for r in csv.DictReader(open(os.path.join(ROOT, "i18n", "strings.csv"), encoding="utf-8"))}
    jobs = []  # (relative path, text, cast entry)
    for path in sorted(glob.glob(os.path.join(ROOT, "data", "dialogue", "*.json"))):
        nodes = json.load(open(path, encoding="utf-8")).get("nodes", {})
        for node in nodes.values():
            key = node.get("text_key")
            if not key or "speaker" not in node:
                continue
            speaker = node["speaker"]
            if speaker not in cast:
                sys.exit("no cast entry for speaker '%s' (%s)" % (speaker, key))
            for lang in ("en", "hi"):
                text = clean_text(rows[key][lang])
                if text:
                    jobs.append(("%s/%s.ogg" % (lang, key), text, cast[speaker][lang]))
    shlokas = json.load(open(os.path.join(ROOT, "data", "shlokas.json"), encoding="utf-8"))["shlokas"]
    for sh in shlokas:
        text = re.sub(r"\s+", " ", sh["devanagari"].replace("\n", " ").replace("।", "।")).strip()
        jobs.append(("sa/%s.ogg" % sh["id"], text, cast["shloka"]["hi"]))
    seen = set()
    unique = []
    for job in jobs:
        if job[0] not in seen:
            seen.add(job[0])
            unique.append(job)
    return unique


def job_hash(text, entry):
    return hashlib.sha1((text + "|" + json.dumps(entry, sort_keys=True)).encode("utf-8")).hexdigest()


def synth(pipes, text, entry, dest):
    import numpy as np
    import soundfile as sf
    from kokoro import KPipeline
    voice = entry["voice"]
    lang = "h" if voice.startswith("h") else voice[0]
    if lang not in pipes:
        pipes[lang] = KPipeline(lang_code=lang)
    chunks = [a for _, _, a in pipes[lang](text, voice=voice, speed=entry["speed"])]
    audio = np.concatenate([np.asarray(c) for c in chunks])
    pitch = entry["pitch"]
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        wav = os.path.join(tmp, "x.wav")
        sf.write(wav, audio, SAMPLE_RATE)
        af = "anull" if pitch == 1.0 else "asetrate=%d,aresample=%d,atempo=%.4f" % (int(SAMPLE_RATE * pitch), SAMPLE_RATE, 1.0 / pitch)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-af", af, "-c:a", "libvorbis", "-q:a", "5", dest], check=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", help="render only this text key / shloka id")
    ap.add_argument("--force", action="store_true", help="re-render even when unchanged")
    args = ap.parse_args()
    manifest = {}
    if os.path.exists(MANIFEST):
        manifest = json.load(open(MANIFEST, encoding="utf-8"))
    pipes = {}
    done = skipped = 0
    for rel, text, entry in collect_jobs():
        stem = os.path.splitext(os.path.basename(rel))[0]
        if args.only and args.only != stem:
            continue
        dest = os.path.join(OUT, rel)
        h = job_hash(text, entry)
        if not args.force and manifest.get(rel) == h and os.path.exists(dest):
            skipped += 1
            continue
        synth(pipes, text, entry, dest)
        manifest[rel] = h
        done += 1
        print("rendered", rel, flush=True)
        os.makedirs(OUT, exist_ok=True)
        json.dump(manifest, open(MANIFEST, "w", encoding="utf-8"), indent=1, sort_keys=True)
    os.makedirs(OUT, exist_ok=True)
    json.dump(manifest, open(MANIFEST, "w", encoding="utf-8"), indent=1, sort_keys=True)
    print("summary: %d rendered, %d unchanged, %d total in manifest" % (done, skipped, len(manifest)))


if __name__ == "__main__":
    main()
