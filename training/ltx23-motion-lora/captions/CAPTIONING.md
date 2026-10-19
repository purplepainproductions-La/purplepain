# Captioning guide: two-character fast-motion concept LoRA

One `.txt` per clip, same file stem (`clip_0007.mp4` → `clip_0007.txt`).

## The rule that matters most

This is a **concept** LoRA, not a character LoRA. Describe the two people with
**plain, visible traits** ("the man in the red hoodie", "the shorter woman")
and **change the people across clips**. Don't give them made-up tokens like
`char_alpha` / `char_beta`. Those tokens tie the motion to two specific people,
which is the opposite of what you want.

What the LoRA should learn (positions, contact, timing) goes in the caption
explicitly, so you can steer it at inference. `[trigger]` carries the overall
"fast, sharp, physical interaction" feel.

## Caption order (keep it the same in every clip)

1. `[trigger]` + shot type + camera (static / handheld / tracking / pan)
2. **Person A**: look + **where they are** (left/right/center, near/far, facing)
3. **The action, in time order**, with pace words and contact points
4. **Person B**: look + position + **reaction**
5. **End state**: where both are when the clip ends
6. Setting + lighting (short)

## Pace vocabulary (pick what's true for the clip)

| Pace | Words |
|---|---|
| Very fast | in a split second, explosive, whip-fast, snaps, instantly |
| Fast | quickly, rapid, in one fluid motion, burst, darts |
| Medium | steadily, in a controlled motion |
| Slow / hold | slowly, pauses, holds still, freezes for a beat |

Use **counts and sequence** where you can: "two quick jabs then a hook",
"steps in, grabs, and throws in under a second", "pauses, then lunges".
Include the slow beats. If every caption says "fast", the model can't tell
fast from slow.

## Position vocabulary

- Frame side: `on the left`, `on the right`, `center frame`
- Depth: `in the foreground`, `closer to camera`, `in the background`
- Spacing: `an arm's length apart`, `chest to chest`, `a few steps apart`
- Facing: `facing each other`, `facing camera`, `with his back to camera`
- Changes: `closes the distance`, `circles to the right`, `they swap sides`

## Examples

```
[trigger] medium shot, static camera. A man in a black hoodie stands on the left facing a woman in a white tank top on the right, about an arm's length apart. He throws two quick jabs at her face; she slips the first to her left and parries the second with her right hand, then steps in and drives her shoulder into his chest in one fast motion. He staggers back two steps toward the left edge of frame while she stays planted at center. Concrete warehouse, hard overhead light.
```

```
[trigger] wide shot, handheld camera tracking right. Two teenagers sprint side by side, the taller boy in a green jacket closer to camera and the girl in a denim vest just behind him on the far side. She grabs the back of his jacket and yanks him to a stop in a split second; he swings around to face her, both breathing hard, now face to face at center frame. Night street, orange streetlights.
```

```
[trigger] full body shot, static camera. A dancer in a red dress on the right holds her partner's hand; the man in a grey shirt on the left pauses for a beat, then spins her under his arm twice, very fast, and catches her in a low dip. They freeze in the dip, her head toward the left of frame. Dance studio, soft window light.
```

## Do / don't

- **Do** describe only what's visible in *this* 2-second window.
- **Do** say who starts the action and who reacts, every time.
- **Do** keep wording consistent across clips (same position terms, same order).
- **Don't** describe the general "style" or quality ("cinematic, 4k, masterpiece").
- **Don't** name real people, brands or film titles.
- **Don't** write the same caption for many clips. Variety is what lets it generalize.

## Drafting with a vision model

Auto-captioners skip timing and positions unless you ask for them. Give your
VLM (Gemini, Qwen-VL, GPT, etc.) the clip and this prompt, then **edit every
result by hand**:

```
Describe this 2-second video clip for training a video model, in one paragraph
of 50-90 words. Start with "[trigger]", then the shot type and camera movement.
Describe the two people by visible appearance only (clothing, build, hair), never
names. State where each person is in frame (left/right/center, near/far, facing
direction) at the start. Then describe the actions in the exact order they
happen, who initiates and who reacts, the contact points, and the speed of each
action using words like "in a split second", "quickly", "pauses", "slowly".
State where both people are at the end. End with the setting and lighting in
under 10 words. Do not describe style, quality or mood.
```
