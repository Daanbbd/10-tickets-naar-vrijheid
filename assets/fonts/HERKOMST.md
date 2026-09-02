# Fonts

`ark-pixel-10px-proportional-latin.ttf`
`ark-pixel-12px-proportional-latin.ttf`
`ark-pixel-16px-proportional-latin.ttf`

Ark Pixel Font, release 2026.09.01, van https://github.com/TakWolf/ark-pixel-font

Licentie: SIL Open Font License 1.1, zie `OFL.txt`. Onbewerkt overgenomen, dus
geen Modified Version en geen naamswijziging nodig.

Waarom deze: proportioneel, en volledige dekking van Latin-1 Supplement en
Latin Extended-A, dus alle Nederlandse diakrieten. Op een canvas van 192 px
breed levert de 10px-snit ongeveer 39 tekens per regel; een monospace pixelfont
haalde er 27 en dat is te weinig voor Nederlands.

## Waarom drie bestanden en niet één

Een pixelfont is per ontwerpmaat getekend. `font_size` op één TTF *schaalt* die
snit, dus de 10px-snit op 12 px is geen 12px-letter maar een uitgerekte
10px-letter met halve pixels erin. Wie een typografische ladder wil, heeft dus
een bestand per maat nodig.

De ladder in `UiKit` is 10 / 12 / 16 / 20 / 30:

| maat | snit | waarom |
|---|---|---|
| 10 | 10px | bijschrift, legenda |
| 12 | 12px | lopende tekst, knoplabels |
| 16 | 16px | tussenkop |
| 20 | 10px | 2x — een heel veelvoud blijft scherp |
| 30 | 10px | 3x — idem |

20 en 30 hebben daarom geen eigen bestand nodig. 12 en 16 wel: dat zijn geen
veelvouden van 10.

## Importinstellingen

Importeer alle drie met antialiasing, hinting en subpixel-positionering uit en
MSDF uit. Anders is een pixelfont juist waziger dan een gewone vectorfont. In
`.import`-termen: `antialiasing=0`, `hinting=0`, `subpixel_positioning=0`,
`multichannel_signed_distance_field=false`.

## Vervangen of bijwerken

De losse `-latin.ttf` zit in de per-maat zipbestanden van de release, bv.
`ark-pixel-font-12px-proportional-ttf-v2026.09.01.zip`. Pak alleen het
`-latin`-bestand uit; de volledige zip bevat ook CJK-snitten die dit project
niet gebruikt.
