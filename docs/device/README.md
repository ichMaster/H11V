# Device measurements

fps notes and screenshots per graphics profile, written by v0.7.
Each set is only valid with the GPU preflight green — see ../decisions.md.

## The screenshots are v0-theme artefacts, and they stay that way

All five PNGs here were captured on the **retired v0 meadow textures** — green turf, brown dirt, bark
trunks, green canopy. The colony retheme (`dc0eff6`, 14 September) replaced every node texture the
next day, so **nothing in this directory shows what the game currently looks like**. Nor is there a
colony frame anywhere else in the repository: no screenshot has been committed since the retheme.

They are kept because they are the v0.7 session's *evidence*, not an illustration of the game. The
fps, drawtime and view-range figures in [../decisions.md](../decisions.md) were read off these
frames; deleting them would leave those numbers with nothing behind them.

| file | what it is | commit |
| --- | --- | --- |
| `low.png` `mid.png` `high.png` | the three profiles at their shipping caps; the debug overlay in each is where the recorded fps and drawtime come from | `9ef754e` — `mid.png` re-captured in `29c0c76` |
| `mid-16px.png` | the 16x16 trial, built and reverted the same day | `94ddff3` |
| `probe-mid.png` | terraces and sea at mid range, pulled while chasing the spawn-emerge bug | `40a0bdf` |

**One recorded judgement rests entirely on these textures.** `../decisions.md` settles *"32x32 reads
correctly at 3.5 inches"* on a look at v0 turf, bark and leaves beside their 16x16 halvings. The
colony pack — bone regolith, lilac spires, violet crowns, machined hull — has never been looked at
under that question, and it is the pack that ships. The verdict stands as recorded, on v0 art; a
re-look belongs to a device pass, not to a desk.

Four of the five frames also carry the evidence for review finding M25, which is the reason they were
worth re-reading in v0.9: the engine's zoom magnifier at the right edge and the raw `Aux1` label
below it are plainly visible in `low`, `high`, `mid-16px` and `probe-mid`. `mid.png` has the pause
menu over that corner.
