"""Download CC0 models and textures from Poly Haven into assets/.

Models  -> assets/models/<id>/<id>.gltf (+ bin + textures)
Textures -> assets/textures/<id>/<id>_{diff,nor_gl,rough}.jpg
Usage: python fetch_polyhaven.py
"""
import json
import os
import sys
import concurrent.futures as cf
import requests

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
API = "https://api.polyhaven.com/files/"

MODELS_2K = ["service_pistol", "bolt_action_rifle_7_62"]
MODELS_1K = """
Sofa_01 sofa_02 ArmChair_01 mid_century_lounge_chair Ottoman_01 CoffeeTable_01 coffee_table_round_01
Television_01 vintage_radio_transceiver tea_set_01 vintage_electric_kettle electric_stove vintage_microwave
WoodenTable_01 dining_chair_02 WoodenChair_01 vintage_day_bed old_bed_frame ClassicNightstand_01 painted_wooden_nightstand
alarm_clock_01 mantel_clock_01 vintage_grandfather_clock_01 fancy_picture_frame_01 fancy_picture_frame_02
hanging_picture_frame_01 hanging_picture_frame_02 hanging_picture_frame_03 standing_picture_frame_01
potted_plant_01 potted_plant_02 potted_plant_04 decorative_book_set_01 book_encyclopedia_set_01 wooden_bookshelf_worn
vintage_cabinet_01 drawer_cabinet painted_wooden_cabinet side_table_01 modern_ceiling_lamp_01 desk_lamp_arm_01
throw_pillows_01 ornate_mirror_01 vintage_telephone_wall_clock croissant food_apple_01 bananas lemon
carrot_cake wooden_cutting_board jug_01 ceramic_vase_01 ceramic_vase_03 wicker_basket_01 chess_set vintage_suitcase
postcard_set_01 Ukulele_01 rubber_duck_toy vintage_oil_lamp wooden_bowl_01 pot_enamel_01 wine_bottles_01
pine_tree_01 fir_tree_01 island_tree_01 island_tree_02 jacaranda_tree tree_small_02 shrub_01 shrub_02 shrub_03 shrub_04
grass_medium_01 grass_medium_02 dandelion_01 fern_02 nettle_plant moss_01
street_lamp_01 street_lamp_02 fire_hydrant modular_electricity_poles covered_car concrete_road_barrier metal_trash_can
wooden_picnic_table outdoor_table_chair_set_01 garden_gnome painted_wooden_bench planter_box_01 water_manhole_cover
utility_box_01 rock_moss_set_01 boulder_01 coast_rocks_01 coastal_cliff_01 dead_tree_trunk tree_stump_01 old_tyre
rusted_wheel_rim_01 cardboard_box_01 wooden_crate_01 wooden_crate_02 Barrel_01 trashbag modular_chainlink_fence
lateral_sea_marker lifebuoy ocean_buoy watering_can_metal_01 garden_sprinkler_01
steel_frame_shelves_01 metal_office_desk mounted_fluorescent_lights industrial_caged_sconce caged_hanging_light
old_military_crate wooden_military_crate medical_box ammo_box long_life_food old_gas_mask metal_jerrycan power_box_01
fire_alarm korean_fire_extinguisher_01 metal_tool_chest clipboard binder_notebook office_notepads retro_multimeter
WetFloorSign_01 portable_searchlight vintage_flashlight metal_stool_01 security_light industrial_wall_lamp
russian_food_cans_01 can_rusted plastic_bottle_gallon medical_tape vintage_lighter pocket_watch binoculars
round_spectacles cassette_player crowbar_01 baseball_bat signal_flashlight hanging_industrial_lamp
""".split()

TEXTURES_2K = []
TEXTURES_1K = """
herringbone_parquet wood_floor_worn old_linoleum_flooring_01 painted_plaster_wall beige_wall_001 ceiling_interior
decrepit_wallpaper weathered_plank_siding white_planks_clean red_brick_03 whitewashed_brick roof_tiles grey_roof_tiles
clay_roof_tiles leafy_grass sparse_grass forest_ground_04 asphalt_02 road_damaged concrete_pavement patterned_paving
dirt coast_sand_01 rock_face cliff_side concrete_wall_008 concrete_floor_worn_001 painted_concrete rusty_metal_02
metal_plate corrugated_iron overgrown_concrete_pavers mossy_cobblestone worn_mossy_plasterwall withered_grass
dry_decay_leaves kitchen_wood wood_table dark_wood fabric_pattern_05 curly_teddy_natural floral_jacquard gingham_check
damaged_concrete_floor rusty_metal_sheet white_rough_plaster brown_planks_03 stone_wall worn_planks square_tiles
""".split()


def get(url, dest):
    if os.path.exists(dest) and os.path.getsize(dest) > 0:
        return 0
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    r = requests.get(url, timeout=120)
    r.raise_for_status()
    with open(dest, "wb") as f:
        f.write(r.content)
    return len(r.content)


def fetch_model(mid, res):
    files = requests.get(API + mid, timeout=60).json()
    g = files["gltf"].get(res) or files["gltf"]["1k"]
    g = g["gltf"]
    out = os.path.join(ROOT, "assets", "models", mid)
    n = get(g["url"], os.path.join(out, os.path.basename(g["url"])))
    for rel, info in g.get("include", {}).items():
        n += get(info["url"], os.path.join(out, rel))
    return mid, n


def fetch_texture(tid, res):
    files = requests.get(API + tid, timeout=60).json()
    out = os.path.join(ROOT, "assets", "textures", tid)
    n = 0
    for key, short in (("Diffuse", "diff"), ("nor_gl", "nor_gl"), ("Rough", "rough")):
        if key not in files:
            continue
        r = files[key].get(res) or files[key]["1k"]
        n += get(r["jpg"]["url"], os.path.join(out, f"{tid}_{short}.jpg"))
    return tid, n


def main():
    jobs = []
    with cf.ThreadPoolExecutor(8) as ex:
        for m in MODELS_2K:
            jobs.append(ex.submit(fetch_model, m, "2k"))
        for m in MODELS_1K:
            jobs.append(ex.submit(fetch_model, m, "1k"))
        for t in TEXTURES_2K:
            jobs.append(ex.submit(fetch_texture, t, "2k"))
        for t in TEXTURES_1K:
            jobs.append(ex.submit(fetch_texture, t, "1k"))
        total = 0
        for j in cf.as_completed(jobs):
            try:
                name, n = j.result()
                total += n
                print(f"ok {name} {n/1e6:.1f}MB", flush=True)
            except Exception as e:  # keep going; report at end
                print(f"FAIL {e}", flush=True)
    print(f"done {total/1e6:.0f}MB")


if __name__ == "__main__":
    sys.exit(main())
