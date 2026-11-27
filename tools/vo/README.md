# Voice-over generator (VO1)

AI text-to-speech with Kokoro-82M (Apache-2.0, commercial use OK). Casting lives in `data/vo_cast.json`
(speaker -> `{en, hi}` -> `voice`, `speed`, `pitch`; pitch below 1 is deeper). `shloka` is the Sanskrit recitation.

```
/home/sameer/git/game-factory/tools/tts/.venv/bin/python tools/vo/generate_vo.py            # incremental
/home/sameer/git/game-factory/tools/tts/.venv/bin/python tools/vo/generate_vo.py --only DLG_PRO_JAM_001
/home/sameer/git/game-factory/tools/tts/.venv/bin/python tools/vo/generate_vo.py --force
```

Output: `assets/vo/en/<TEXT_KEY>.ogg`, `assets/vo/hi/<TEXT_KEY>.ogg`, `assets/vo/sa/<shloka_id>.ogg`.
`assets/vo/manifest.json` holds a hash of text + cast entry per clip, so only changed lines are re-rendered.
Surrounding quotes are stripped; lines fully in parentheses (stage directions) are not voiced. Choices are not voiced.
Needs ffmpeg with libvorbis. Open the project in Godot afterwards so the new clips are imported.
