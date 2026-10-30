# Generated 2D art — AFTERBLOOM

All files in this folder are **original** procedural illustrations generated with Python + Pillow + numpy by the
scripts in `tools/art/` (fixed seeds — rerun `tools/.venv/Scripts/python.exe tools/art/build_all.py` to rebuild
everything, or `build_all.py <module>` for one group). Fonts are the stock Windows fonts (Georgia, Palatino,
Impact, Arial Black, Franklin Gothic, Bahnschrift, Segoe Script, Ink Free, Courier, Times).

Palette: cream `#F3E6C8`, teal `#2F7F7A`, coral `#E07A5F`, mustard `#E3B23C`, navy `#23395B`, warm red `#C8553D`;
Bloom violet `#9B5CFF` is reserved for Bloom-related things (comet tail hint, crystal flowers, spore specks, dust/cloud).
`*_aged` variants are the 1978 versions (faded, yellowed, stained, torn/rusted, overgrown with violet crystal flowers).

Shared code: `common.py` (supersampled Canvas, fonts, tileable noise, halftone, print finish, paper/sign aging),
`illus.py` (Tuppence, rockets, lighthouses, comets, houses, TV set, shelter portal, Halcyon emblem/lockup,
Civil Defense emblem, ribbons, bursts). `contact.py` makes contact sheets for review.

Alpha notes: logos, icons, compass strip and aged paper items (torn edges) are RGBA — use alpha-scissor or
alpha-blend materials. Wallpapers, `ui_paper`, `ui_leather` tile seamlessly (seam-checked).


## Magazine covers  (`tools/art/magazines.py`)

| File | Size | What it is | Where it goes in game |
|---|---|---|---|
| `mag_steady_hand.png` | 768x1024 | Magazine cover: Steady Hand Sportsman (marksmanship) | Collectible magazine pickup / journal Mags tab; perk: steadier aim |
| `mag_tinker.png` | 768x1024 | Magazine cover: Tinker & Spanner (robot repair hobbyists) | Collectible magazine; perk: Tuppence repair/zap bonus |
| `mag_pantry.png` | 768x1024 | Magazine cover: Gentleman's Pantry (cooking) | Collectible magazine; perk: food heals more |
| `mag_astounding.png` | 768x1024 | Magazine cover: Astounding Tomorrow (sci-fi pulp, comet + rocket) | Collectible magazine; perk: SureShot/Focus |
| `mag_outdoorsman.png` | 768x1024 | Magazine cover: Outdoorsman's Almanac (hiking) | Collectible magazine; perk: sprint stamina |
| `mag_hearth.png` | 768x1024 | Magazine cover: Halcyon Home & Hearth (Halcyon house magazine) | Collectible magazine; living room coffee table (Ch.1) |
| `mag_detective.png` | 768x1024 | Magazine cover: Pulp Detective Weekly (noir) | Collectible magazine; perk: crit/loot finding |
| `mag_lighthouse.png` | 768x1024 | Magazine cover: Coastal Keeper (lighthouses & sea) | Collectible magazine; lighthouse cottage |

## Posters & billboard  (`tools/art/posters.py`)

| File | Size | What it is | Where it goes in game |
|---|---|---|---|
| `poster_starlight_tv.png` | 1024x1536 | Halcyon ad poster: Starlight console television | House living room / showroom / diner walls (1967) |
| `poster_starlight_tv_aged.png` | 1024x1536 RGBA | Aged/torn Starlight poster (1978) | Same spots in ruined Larkhaven |
| `poster_valet_mk2.png` | 1024x1536 | Halcyon ad poster: Valet Mk II robot butler (Tuppence model) | Showroom, kitchen, Gull Lane |
| `poster_valet_mk2_aged.png` | 1024x1536 RGBA | Aged/torn Valet Mk II poster | Ruined showroom / streets (1978) |
| `poster_shelter.png` | 1024x1536 | Halcyon Assured Shelters: 'Sleep Soundly.' (Shelter No. 9) | Bus stop, CD post, showroom, shelter lobby |
| `poster_shelter_aged.png` | 1024x1536 RGBA | Aged/torn shelter poster | Shelter No. 9 interior after waking, ruined town |
| `poster_comet_picnic.png` | 1024x1536 | Town flyer: Larkspur Comet Night picnic on the bluff, Oct 13 | Diner, general store, noticeboards |
| `poster_comet_picnic_aged.png` | 1024x1536 RGBA | Aged/torn comet picnic flyer | Noticeboards in 1978 |
| `poster_civil_defense.png` | 1024x1536 | Civil Defense info poster: Know Your Shelter | CD post, town hall, shelter corridor |
| `poster_civil_defense_aged.png` | 1024x1536 RGBA | Aged/torn civil defense poster | CD post (rifle pickup), shelter (1978) |
| `billboard_halcyon.png` | 2048x1024 | 2048x1024 Halcyon billboard: Tomorrow, Made Gentle. | Billboard frame on the bluff road / harbor |
| `billboard_halcyon_aged.png` | 2048x1024 | Sun-bleached, peeling, overgrown billboard | Same billboard in 1978 |

## Signs  (`tools/art/signs.py`)

| File | Size | What it is | Where it goes in game |
|---|---|---|---|
| `sign_diner.png` | 1024x256 | Marlow's Diner enamel storefront sign (script, coffee cup, starburst) | Harbor Square diner facade, above door |
| `sign_general.png` | 1024x256 | Harbor General Store painted wooden sign with anchors | Harbor Square general store facade |
| `sign_cd_post.png` | 1024x256 | Larkhaven Civil Defense Post enamel sign with CD-style emblem | Civil Defense post (rifle pickup), Harbor Square |
| `sign_showroom.png` | 1024x256 | Halcyon Showroom sign (navy, chrome edge, Halcyon lockup) | Halcyon showroom storefront, Harbor Square |
| `sign_radio.png` | 1024x256 | Larkhaven Free Radio - 1340 AM hand-painted wooden board | Lighthouse keeper's cottage, by the door |
| `sign_shelter9.png` | 1024x256 | HALCYON ASSURED SHELTER No. 9 stencil on olive steel, hazard stripes | Above Shelter No. 9 gate in the bluff |
| `sign_gull_lane.png` | 512x128 | Gull Lane green-enamel street sign (512x128) | Street sign post at Gull Lane corner |
| `sign_shelter_arrow.png` | 512x128 | SHELTER No. 9 -> directional arrow sign (512x128) | Posts along Gull Lane / bluff road (dash to the shelter) |
| `sign_welcome.png` | 1024x512 | Welcome to Larkhaven - Pop. 2,140 - Gateway to the Sea painted billboard (1024x512) | Coast road town entrance |
| `sign_road_closed.png` | 512x256 | ROAD CLOSED barricade sign by order of Civil Defense (512x256) | Barricades on coast road / blocked streets |
| `sign_diner_aged.png` | 1024x256 | Marlow's Diner enamel storefront sign (script, coffee cup, starburst) - 1978 weathered: faded, rusted/chipped, overgrown with violet Bloom flowers | Harbor Square diner facade, above door (Ch.4, 11 years later) |
| `sign_general_aged.png` | 1024x256 | Harbor General Store painted wooden sign with anchors - 1978 weathered: faded, rusted/chipped, overgrown with violet Bloom flowers | Harbor Square general store facade (Ch.4, 11 years later) |
| `sign_cd_post_aged.png` | 1024x256 | Larkhaven Civil Defense Post enamel sign with CD-style emblem - 1978 weathered: faded, rusted/chipped, overgrown with violet Bloom flowers | Civil Defense post (rifle pickup), Harbor Square (Ch.4, 11 years later) |
| `sign_showroom_aged.png` | 1024x256 | Halcyon Showroom sign (navy, chrome edge, Halcyon lockup) - 1978 weathered: faded, rusted/chipped, overgrown with violet Bloom flowers | Halcyon showroom storefront, Harbor Square (Ch.4, 11 years later) |
| `sign_radio_aged.png` | 1024x256 | Larkhaven Free Radio - 1340 AM hand-painted wooden board - 1978 weathered: faded, rusted/chipped, overgrown with violet Bloom flowers | Lighthouse keeper's cottage, by the door (Ch.4, 11 years later) |
| `sign_shelter9_aged.png` | 1024x256 | HALCYON ASSURED SHELTER No. 9 stencil on olive steel, hazard stripes - 1978 weathered: faded, rusted/chipped, overgrown with violet Bloom flowers | Above Shelter No. 9 gate in the bluff (Ch.4, 11 years later) |
| `sign_gull_lane_aged.png` | 512x128 | Gull Lane green-enamel street sign (512x128) - 1978 weathered: faded, rusted/chipped, overgrown with violet Bloom flowers | Street sign post at Gull Lane corner (Ch.4, 11 years later) |
| `sign_shelter_arrow_aged.png` | 512x128 | SHELTER No. 9 -> directional arrow sign (512x128) - 1978 weathered: faded, rusted/chipped, overgrown with violet Bloom flowers | Posts along Gull Lane / bluff road (dash to the shelter) (Ch.4, 11 years later) |
| `sign_welcome_aged.png` | 1024x512 | Welcome to Larkhaven - Pop. 2,140 - Gateway to the Sea painted billboard (1024x512) - 1978 weathered: faded, rusted/chipped, overgrown with violet Bloom flowers | Coast road town entrance (Ch.4, 11 years later) |
| `sign_road_closed_aged.png` | 512x256 | ROAD CLOSED barricade sign by order of Civil Defense (512x256) - 1978 weathered: faded, rusted/chipped, overgrown with violet Bloom flowers | Barricades on coast road / blocked streets (Ch.4, 11 years later) |

## Logos  (`tools/art/logos.py`)

| File | Size | What it is | Where it goes in game |
|---|---|---|---|
| `logo_halcyon.png` | 2048x640 RGBA | Halcyon Electric Co. lockup (kingfisher emblem + wordmark + tagline), white on transparent | UI overlays, TV idents, decals on Tuppence / props (tint in shader) |
| `logo_halcyon_color.png` | 2048x640 RGBA | Halcyon lockup in brand colours (navy/mustard/cream), transparent | Menus, loading screens, decals |
| `logo_title.png` | 2048x512 RGBA | AFTERBLOOM game title logo, 2048x512, transparent; violet crystal-flower O | Title screen / cold-open title card |
| `logo_lfr.png` | 1024x1024 RGBA | Larkhaven Free Radio roundel (lighthouse + radio waves, 1340 AM), transparent | Radio UI, journal Radio tab, lighthouse decals |

## Tileable wallpapers  (`tools/art/wallpapers.py`)

| File | Size | What it is | Where it goes in game |
|---|---|---|---|
| `wallpaper_living.png` | 1024x1024 | Tileable wallpaper: muted warm atomic/floral (tulips, starbursts, boomerangs) | Living room walls, 1967 house (Ch.1) |
| `wallpaper_living_aged.png` | 1024x1024 | Tileable wallpaper: living room pattern faded, stained, peeling at strip seams | Living room walls, 1978 overgrown house (Ch.4) |
| `wallpaper_bedroom.png` | 1024x1024 | Tileable wallpaper: soft teal stripes with small rosebuds | Player bedroom / June's room, 1967 |
| `wallpaper_bedroom_aged.png` | 1024x1024 | Tileable wallpaper: bedroom pattern faded, stained, peeling | Bedrooms, 1978 |
| `wallpaper_kitchen.png` | 1024x1024 | Tileable wallpaper: teapots, cups and lemons on faint gingham check | Kitchen walls, 1967 |
| `wallpaper_kitchen_aged.png` | 1024x1024 | Tileable wallpaper: kitchen pattern faded, grease/water stained, peeling | Kitchen walls, 1978 |

## Newspaper & notes  (`tools/art/docs.py`)

| File | Size | What it is | Where it goes in game |
|---|---|---|---|
| `newspaper_ledger.png` | 1024x1400 | The Larkhaven Ledger, Sat. Oct 14 1967: COMET PASSES TONIGHT / Halcyon opens Shelter No. 9 | Kitchen table / porch (Ch.1), readable close-up |
| `newspaper_ledger_aged.png` | 1024x1400 RGBA | Same paper, yellowed, folded, torn, stained (1978) | Ruined town, diner, shelter |
| `note_june.png` | 768x1024 RGBA | June's handwritten note on lined paper ('Follow the music... I'll leave the light on. — J.') | On June's empty bunk in Shelter No. 9 (Ch.3), journal close-up |
| `note_registrar.png` | 1024x640 RGBA | Halcyon Assured shelter registration card, typed, Resident #31 | Given by Registrar 9 at the door (Ch.1); journal item |

## Framed photos  (`tools/art/photos.py`)

| File | Size | What it is | Where it goes in game |
|---|---|---|---|
| `photo_beach.png` | 768x576 | Framed photo: two siblings at the beach at sunset, seen from behind (768x576) | Living room mantel / player's bedroom |
| `photo_lighthouse.png` | 768x576 | Framed photo: Larkhaven Light and keeper's cottage with radio mast (768x576) | Hallway wall; lighthouse cottage |
| `photo_june.png` | 576x768 | Framed photo: stylized portrait of June, the player's sister (576x768) | Player's bedroom nightstand; journal |
| `photo_tuppence.png` | 768x576 | Framed photo: Tuppence 'Employee of the Month', Sept 1967 (768x576) | Kitchen wall / Halcyon showroom |
| `photo_parents.png` | 576x768 | Framed photo: parents' wedding, sepia silhouettes in an oval vignette (576x768) | Living room side table |

## TV graphics (640x480, shown under the CRT shader)  (`tools/art/tv.py`)

| File | Size | What it is | Where it goes in game |
|---|---|---|---|
| `tv_larkhaven_morning.png` | 640x480 | TV title card: 'Larkhaven Morning' with Hal Brightwater (sunrise over the bay) | Starlight TV screen, Ch.1 morning show intro |
| `tv_anchor.png` | 640x480 | TV: anchor Hal Brightwater at his desk, cheerful, 'Larkhaven Morning' backdrop | Starlight TV screen, Ch.1 news segments |
| `tv_anchor_grave.png` | 640x480 | TV: Hal Brightwater, grave, dim red 'Civil Defense' backdrop | Starlight TV screen, Ch.1 when news turns grave |
| `tv_weather_map.png` | 640x480 | TV: cartoon coastal weather map (sun/cloud icons, temps) | Starlight TV screen, weather segment |
| `tv_comet.png` | 640x480 | TV: last night's Larkspur Comet over the bluff, tiny picnickers | Starlight TV screen, news segment |
| `tv_harbor_dust.png` | 640x480 | TV: fishing boats in the harbour, shimmering violet dust on the water | Starlight TV screen, news turns strange |
| `tv_cloud.png` | 640x480 | TV: studio-window view of a towering violet Bloom cloud rolling over the bay | Starlight TV screen, just before the emergency broadcast |
| `tv_ad_starlight.png` | 640x480 | TV ad: Halcyon Starlight console television | Starlight TV screen, ad break |
| `tv_ad_valet.png` | 640x480 | TV ad: Halcyon Valet Mk II robot butler | Starlight TV screen, ad break |
| `tv_ad_sweetcorn.png` | 640x480 | TV ad: Sunny Crunch breakfast cereal | Starlight TV screen, ad break |
| `tv_emergency.png` | 640x480 | TV: CIVIL DEFENSE EMERGENCY — proceed calmly to your assigned shelter | Starlight TV screen, Ch.2 emergency broadcast |
| `tv_test_pattern.png` | 640x480 | TV: original Halcyon/KLHV-6 test pattern | Starlight TV screen, off-air / idle |
| `tv_please_stand_by.png` | 640x480 | TV: PLEASE STAND BY card with flustered Tuppence | Starlight TV screen, signal interruption |

## UI  (`tools/art/ui.py`)

| File | Size | What it is | Where it goes in game |
|---|---|---|---|
| `ui_paper.png` | 1024x1024 | Tileable aged notebook paper, cream with faint blue rules | Journal page background (Tab menu), note/quest panels |
| `ui_leather.png` | 1024x1024 | Tileable dark brown pebbled leather | Journal cover / frame, pause menu backing |
| `icon_quests.png` | 128x128 RGBA | 128px ink-stamp icon: pennant flag on a scroll | Journal tab: Quests |
| `icon_items.png` | 128x128 RGBA | 128px ink-stamp icon: buckled satchel | Journal tab: Items/inventory |
| `icon_mags.png` | 128x128 RGBA | 128px ink-stamp icon: magazine with starburst | Journal tab: Magazines |
| `icon_radio.png` | 128x128 RGBA | 128px ink-stamp icon: pocket transistor radio | Journal tab: Radio |
| `icon_map.png` | 128x128 RGBA | 128px ink-stamp icon: folded map with route + X | Journal tab: Map |
| `icon_settings.png` | 128x128 RGBA | 128px ink-stamp icon: gear | Journal tab: Settings |
| `compass_strip.png` | 2048x64 RGBA | 2048x64 transparent compass tape, N/NE/E... + ticks; seamless horizontally; x = heading/360*2048 (N at x=0) | HUD compass bar (scroll UV by heading) |

## Product labels  (`tools/art/labels.py`)

| File | Size | What it is | Where it goes in game |
|---|---|---|---|
| `label_pep_tonic.png` | 512x256 | Bottle label: Halcyon Pep Tonic (healing tonic) | Aid item: healing tonic bottle (pickup + journal Items icon) |
| `label_sardines.png` | 512x256 | Tin label: Sea Biscuit Sardines | Aid/food item: sardine tin |
| `label_beans.png` | 512x256 | Can wrap label: Gull Brand Pork & Beans | Aid/food item: bean can (wrap around cylinder) |
| `label_ammo_pistol.png` | 512x256 | Ammo box face: .38 Halcyon Defense cartridges | Ammo pickup for service pistol |
| `label_ammo_rifle.png` | 512x256 | Ammo box face: .30 Marksman cartridges | Ammo pickup for bolt-action rifle |
