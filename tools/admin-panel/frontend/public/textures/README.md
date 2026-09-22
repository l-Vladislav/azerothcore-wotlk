# Forged iron

`forged-iron.png` is an original UI material generated with the built-in imagegen tool.
Used locally by the Warcraft theme; no external asset requests are required.

Prompt:

Create a seamless tileable square 1024x1024 material texture for a Warcraft-inspired medieval fantasy
game admin UI. Straight-on orthographic close-up of ancient dark charcoal hammered iron mixed with
worn slate, very fine grain, restrained scratches and tiny pits, faint warm bronze patina. Even
subdued lighting, low contrast, no bright areas, no vignette. Entire image uniform continuous
material across all four edges, no frame, no objects, no rivets, no lettering, no symbols, no logos,
no watermark. This is a reusable background texture beneath readable UI text, not a screenshot or
illustration. Save the generated asset and return its local file path.


# Frame and stone (generated)

С 2026-09-19 камень под страницей берётся со стайлгайда
(`public/ui/textures/`, см. соседний README), поэтому `stone-panel.png`
больше никем не используется - файл оставлен, чтобы скрипт ниже продолжал
собираться как раньше. В деле остались `frame-gold.png` (кромка панелей в
`warcraft.scss`) и `forged-iron.png` (шапка каталога).

`frame-gold.png` and `stone-panel.png` are drawn by
`tools/admin-panel/scripts/make_ui_textures.py` - run it after changing the
colours or the edge width there. Nothing is downloaded at build time or at
runtime; both files are ours.

The palette they use is measured, not guessed: the numbers come from the
CLASSIC interface textures mirrored at `Gethe/wow-ui-textures` (branch
`classic`) - `UI-DialogBox-Gold-Border` and `UI-DialogBox-Gold-Corner` for the
frame, `UI-Panel-Button-Up` for the button colours in `styles/theme.scss`,
`UI-DialogBox-Background-Dark` for "a classic panel is black". Those textures
are Blizzard's and are NOT copied into this repository - only the colour
values were read off them.
