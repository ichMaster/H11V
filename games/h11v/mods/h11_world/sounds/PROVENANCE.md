# Audio provenance — `h11_world_music.ogg`

Written in v0.9 (review finding L33). No gate touches audio: `check_assets.py` reads PNGs, and
nothing in `tools/` opens a sound file. So this document is the whole record, and it is only as good
as the next person keeps it.

## The two files

| | |
| --- | --- |
| ships | `games/h11v/mods/h11_world/sounds/h11_world_music.ogg` — Ogg Vorbis, 44.1 kHz stereo, 169.032 s, 1 646 584 bytes, `sha256 a137512a…58cbe192` |
| source | `specification/art/SilentBeeps.mp3` — MP3, 169.032 s, 3 900 689 bytes, `sha256 758e6a88…87347588` |

Both arrived on 13 September 2026: the mp3 in `29c0c76`, the ogg in `50ea673` (*"0.7.1: gamepad
keymap, background music, and a deploy race that ate configs"*). **Neither commit message says where
the audio came from.** The mp3 in particular landed inside a commit about font sizes and tree
density, which is how an asset arrives without anyone deciding to accept it.

## What the files themselves say

Read out of the tags, not inferred. Both carry the same four:

```
title        Silent Beeps
artist       lili_jinx
description  made with suno; created=…; id=5cb1b5fe-e47f-42a4-83f6-7625fa7ffa54
lyrics-eng   [Instrumental]
```

The mp3 carries three things the ogg does not:

- `WOAS` — `https://suno.com/song/5cb1b5fe-e47f-42a4-83f6-7625fa7ffa54`, the same id as the tag.
- An `APIC` cover image.
- A **signed C2PA manifest** (`GEOB`, `application/c2pa`). Its assertions are `c2pa.actions.v2` with
  action `c2pa.created` and `digitalSourceType` = IPTC `trainedAlgorithmicMedia`; and
  `com.suno.provenance` with `providerName "Suno, Inc."`, `systemName "Suno"`, `systemVersion
  "chirp-hawk-engine-b"`, `createdAt 2026-09-13T09:18:27Z`, and the same content id. The claim is
  signed by *Suno Content Credentials* under a *Suno C2PA Root CA*, RFC-3161 countersigned by
  DigiCert at `2026-09-13T17:18:48Z`.

The ogg is a local transcode of that mp3 — same id, same title and artist, same duration to the
millisecond — and the transcode **dropped the C2PA manifest**: the Vorbis comment block carries the
four text tags and nothing else. That is the reason to keep the mp3 in `specification/art/`: the
signed credential exists only there, and the shipped file can no longer prove anything about itself.
The encoder tags are consistent with the reading (`Lavf60.16.100` stamped on the mp3, `Lavf61.7.102`
on the ogg), so the mp3 is the download and the ogg is what this repository made from it.

## Verdict: origin established, licence **not** established

**Established, with a cryptographic signature behind it:** the track is machine-generated audio
produced by Suno, on 13 September 2026, and downloaded through an account displaying as `lili_jinx`.

**Not established, and not establishable from anything in this repository:**

1. **Whether `lili_jinx` is this project's author.** The repository's git identity is `ichland`
   (`ichMaster` on GitHub). Nothing here connects the two names, and a Suno display name is not
   evidence of anything.
2. **Under which Suno plan the track was generated, and therefore which output licence applies to
   it.** That is a fact about an account, not about a file, and no file can carry it.
3. **Consequently, whether the track satisfies `CLAUDE.md`'s "self-made or CC0" rule.** Generated on
   a third-party service, it is not obviously either: not self-made in the ordinary sense, and not
   CC0 by default.

**So the honest state is: unknown, and it needs the author to confirm it.** Two answers close it —
*is the `lili_jinx` account yours, and on what plan was this generated* — and the answer belongs in
`docs/decisions.md`, with this file pointing at it. Until then, no licence should be asserted for
this track anywhere in the repository, and it should not be treated as cleared for redistribution.

This is deliberately not a `LICENSE` file. Writing one would mean choosing a licence, and choosing
one is exactly what nobody in this repository is currently in a position to do.
