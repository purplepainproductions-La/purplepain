# LTX-2.3 LoRA: fast two-character interaction (AI Toolkit on RunPod)

A concept LoRA that teaches **positions, contact, and the pace of movement**
between two people. It isn't meant to learn who the people are.

```
config/ltx23_two_char_motion.yaml   training config (keys checked against ostris/ai-toolkit main)
scripts/prep_clips.sh               raw footage -> 24 fps, exactly 49-frame clips
scripts/check_dataset.py            pre-flight: frames, fps, captions
scripts/runpod_setup.sh             manual install (only if not using the template)
captions/CAPTIONING.md              caption structure, vocab, examples, VLM prompt
```

---

## 1. Pod

| | Recommended | Budget |
|---|---|---|
| GPU | **H100 80GB** or **RTX PRO 6000 96GB** | L40S / A6000 48GB |
| Config change | none | `low_vram: true`, `layer_offloading: true`; ~2x slower |
| Volume | **200 GB network volume** at `/workspace` | same |

24 and 32 GB cards are out: AI Toolkit's own tests note the quantized 22B
stack doesn't fit in 32 GB.

**Easiest path: the official AI Toolkit template**
(`console.runpod.io/deploy?template=0fqzfjy6f3`, linked from the AI Toolkit README).
When you deploy:
- Attach the network volume.
- Env vars: `AI_TOOLKIT_AUTH=<password>`, `HF_TOKEN=<hf read token>`,
  `HF_HOME=/workspace/hf_cache`.
- Open the UI through **Connect → HTTP 8675**.
- In the UI, go to **Settings** and point **Training Folder** to `/workspace/output` and
  **Datasets Folder** to `/workspace/datasets`. The template's app lives in
  `/app`, which is wiped when the pod stops.

**Manual path:** plain RunPod PyTorch pod (CUDA 13 driver), then
`AI_TOOLKIT_AUTH=... HF_TOKEN=... bash scripts/runpod_setup.sh`.

The first run downloads the 22B dev checkpoint plus the Gemma-3 12B text
encoder (~70 GB) into `HF_HOME`. Keeping that on the volume means you only
download it once.

## 2. Dataset

**Size:** 30–60 clips. Variety matters more than count.

**Mix:**
- ~70% two-person interactions (strikes, grabs, shoves, throws, dance spins, catches,
  handoffs, chases). Use different people, outfits, places and camera angles.
- ~20% the same kinds of interaction at a **slower or mixed** pace (pauses, holds,
  wind-ups). Without these, the model learns "everything is fast".
- ~10% single-person fast motion (sprints, spins), as anchors.

**Footage quality:**
- Use real-time footage only: no slow-mo, speed ramps, or frame interpolation.
  Any of those teaches the wrong pace.
- Use a fast shutter where you can. Motion blur gets trained in.
- Avoid hard cuts inside a clip. One continuous shot per clip.
- Keep both people fully in frame for most of the clip.

**Cut the clips:** set start times in a CSV so each 2-second window holds a
whole action:

```bash
# cuts.csv:  file,start_seconds
bash scripts/prep_clips.sh raw/ /workspace/datasets/two_char_motion cuts.csv
```

Output: constant 24 fps, **exactly 49 frames** (2.04 s), short side 576 px, no audio.
For longer exchanges, use `FRAMES=73` or `FRAMES=97` and set `num_frames` in
the YAML to match. Both values must always be equal.

> **Why exactly 49 frames?** AI Toolkit's `shrink_video_to_frames` squeezes a
> longer clip into `num_frames` by skipping frames, so a 4 s clip trained at 49
> frames plays back at **2x speed**. Pre-cutting to the exact count keeps
> the real pace, and pace is half of what this LoRA is for. `fps: 24` must also match the clips,
> because LTX-2.3 conditions on frame rate.

## 3. Captions

Follow `captions/CAPTIONING.md`. In short:
`[trigger]` → shot/camera → person A + position → actions in order with pace
words → person B + reaction → end positions → setting.

Use plain visible traits ("the man in the red hoodie"), never ID tokens. Then run the check:

```bash
python3 scripts/check_dataset.py /workspace/datasets/two_char_motion
```

Fix everything marked FAIL before you train.

## 4. Train

**UI:** New Job → **Advanced**, paste `config/ltx23_two_char_motion.yaml`,
then Save and Start. Or **CLI** (inside tmux):

```bash
cd /workspace/ai-toolkit && source venv/bin/activate
python run.py /workspace/ltx23-motion-lora/config/ltx23_two_char_motion.yaml
```

What the settings do and why:

| Setting | Value | Why |
|---|---|---|
| `arch` / model | `ltx2.3`, `ltx-2.3-22b-dev` | Train on the **dev** (non-distilled) checkpoint |
| rank / alpha | 32 / 32 | Enough for motion and contact; raise to 64 only if it underfits |
| `ignore_if_contains: [audio]` | — | LoRA skips the audio branch, so audio quality isn't damaged (a known LTX LoRA problem) |
| `do_audio` | false | This LoRA is about motion; the clips are silent |
| `lr` | 0.0001, adamw8bit | AI Toolkit default for LTX |
| steps | 3000, save/sample every 250 | Expect the best checkpoint around **1500–2500** |
| `caption_dropout_rate` | 0.05 | Teaches some motion without relying on the prompt |
| `cache_latents_to_disk` | true | Encodes each clip once instead of every step |

Expect roughly 4–6 s per step on an H100 at 768 px / 49 frames, so about 4–5 hours
for 3000 steps (rough estimate; check the speed shown in the UI).

## 5. Pick the checkpoint

The sample prompts use **new people and new settings**, swap left and right,
and include one **slow** scene. At each 250-step sample, check:

1. **Pace:** do the fast actions look fast but physically believable? Does the slow scene stay slow?
   - If the slow scene starts moving fast, it's overfitting. Use an earlier checkpoint.
2. **Positions:** does "on the left" end up on the left? Do the people swap correctly when the prompt says so?
3. **Contact:** do hands and bodies actually connect, or pass through each other or merge?
4. **Identity leak:** do the outputs start looking like people from your dataset?
   - If yes, the LoRA is overfit, or the dataset needs more variety.
5. **Detail:** look for melting limbs or smear during fast moments.
   - Early on: the dataset may have too much blur.
   - Late: overfit.

Pick the **earliest** checkpoint that gets 1–3 right. Then download it from
`/workspace/output/ltx23_two_char_motion_v1/`. AI Toolkit saves LTX LoRAs
with ComfyUI-style keys. In ComfyUI, load it on the LTX-2.3 dev model at
strength 0.8–1.0, and for the distilled model try 0.6–0.8.

## Troubleshooting

| Symptom | Fix |
|---|---|
| CUDA OOM | `resolution: [512]` first, then `low_vram: true`, then `layer_offloading: true` |
| Motion looks sped up | Clips aren't exactly `num_frames`, or `fps` doesn't match. Re-run `check_dataset.py` |
| The two people merge or swap features | Write more specific captions (distinct clothing, explicit sides); add more varied clips |
| Everything comes out frantic | Add more slow/mixed-pace clips; use an earlier checkpoint |
| Audio degraded | Make sure `ignore_if_contains: [audio]` is set and `do_audio: false` |
| Gated model / 401 | Accept the license at `huggingface.co/Lightricks/LTX-2.3`; check `HF_TOKEN` |
