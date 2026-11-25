#!/usr/bin/env python3
"""Generates levels/*.json (DESIGN §5, schema in levels/SCHEMA.md). Written by the design agent; edit and re-run:
    python3 dev/levelgen/make_levels.py
Enemy spawn kinds use the ids from data/enemies.json (guard_spear, guard_archer, kinkara) or boss_*/npc ids."""
import json, os, random

OUT = os.path.join(os.path.dirname(__file__), "..", "..", "levels")
T = 2.0  # tile size in metres

class Level:
    def __init__(self, lid, w, h, base="ground", step=0):
        self.id, self.w, self.h = lid, w, h
        self.tiles = {(x, z): {"x": x, "z": z, "type": base, "step": step} for x in range(w) for z in range(h)}
        self.props, self.spawns, self.triggers, self.shrines = [], [], [], []
        self.rng = random.Random(lid)
    def rect(self, x0, z0, x1, z1, type_, step=None):
        for x in range(max(0, x0), min(self.w, x1 + 1)):
            for z in range(max(0, z0), min(self.h, z1 + 1)):
                t = self.tiles[(x, z)]; t["type"] = type_
                if step is not None: t["step"] = step
    def border(self, type_="wall"):
        for x in range(self.w):
            self.tiles[(x, 0)]["type"] = type_; self.tiles[(x, self.h - 1)]["type"] = type_
        for z in range(self.h):
            self.tiles[(0, z)]["type"] = type_; self.tiles[(self.w - 1, z)]["type"] = type_
    def c(self, x, z):  # tile centre in metres
        return [x * T + 1.0, z * T + 1.0]
    def prop(self, kind, tx, tz, size, rot=0, flammable=False, protected=False, seed=None):
        self.props.append({"kind": kind, "pos": self.c(tx, tz), "rot": rot, "seed": self.rng.randint(1, 9999) if seed is None else seed,
                           "size": size, "opts": {"flammable": flammable, "protected": protected}})
    def spawn(self, sid, kind, tx, tz, facing=0, **meta):
        s = {"id": sid, "kind": kind, "pos": self.c(tx, tz), "facing": facing}
        s.update(meta); self.spawns.append(s)
    def trigger(self, tid, tx, tz, w, h, event, once=True):
        self.triggers.append({"id": tid, "shape": "box", "size": [w * T, 3.0, h * T], "pos": self.c(tx, tz), "on_enter": event, "once": once})
    def shrine(self, sid, tx, tz):
        self.shrines.append({"id": sid, "pos": self.c(tx, tz)})
    def save(self):
        d = {"id": self.id, "nav": True, "tiles": sorted(self.tiles.values(), key=lambda t: (t["z"], t["x"])),
             "props": self.props, "spawns": self.spawns, "triggers": self.triggers, "shrines": self.shrines}
        with open(os.path.join(OUT, self.id + ".json"), "w", encoding="utf-8") as f:
            json.dump(d, f, ensure_ascii=False, indent=1)
        print(f"{self.id}: {len(d['tiles'])} tiles, {len(self.props)} props, {len(self.spawns)} spawns, {len(self.triggers)} triggers")

def mahendra():
    L = Level("mahendra", 24, 24, "grass")
    L.rect(0, 0, 23, 2, "water"); L.rect(0, 3, 23, 4, "sand")             # southern sea and shore
    L.rect(14, 14, 23, 23, "ground", 1); L.rect(17, 17, 23, 23, "ground", 2); L.rect(20, 20, 23, 23, "stone_floor", 3)  # the climb
    L.rect(0, 5, 0, 23, "wall"); L.rect(0, 23, 23, 23, "wall"); L.rect(23, 5, 23, 22, "wall")
    for i, (x, z) in enumerate([(4, 8), (6, 9), (8, 8)]): L.prop("rock", x, z, [1.5, 1.2, 1.5])   # training rocks
    for x, z in [(3, 14), (5, 18), (10, 20), (12, 12), (2, 10), (18, 9)]: L.prop("shimshapa_tree", x, z, [3, 6, 3])
    for x, z in [(16, 13), (19, 16), (21, 19)]: L.prop("rock", x, z, [2.5, 2, 2.5])
    L.prop("cliff", 22, 22, [4, 6, 4])
    L.spawn("hanuman_start", "player", 6, 6, 0)
    L.spawn("jambavan", "npc_jambavan", 9, 6, 270); L.spawn("angada", "npc_angada", 10, 7, 270)
    for i, (x, z) in enumerate([(12, 5), (13, 7), (11, 9), (14, 9)]): L.spawn(f"vanara_{i}", "npc_vanara", x, z, 180)
    L.trigger("t_jambavan", 9, 6, 3, 3, "dialogue:pro_jambavan")
    L.trigger("t_training_done", 6, 8, 5, 3, "objective:training", once=False)
    L.trigger("t_leap", 21, 21, 2, 2, "dialogue:pro_leap")
    L.shrine("shrine_mahendra", 4, 12)
    L.save()

def lanka_gate():
    L = Level("lanka_gate", 20, 20, "stone_floor")
    L.border()
    L.rect(1, 1, 18, 3, "ground")                                     # approach road
    L.rect(8, 15, 11, 19, "stone_floor", 1)                           # gate steps
    L.prop("gopuram", 9, 18, [6, 12, 4], protected=True)
    for x in (4, 15):
        for z in (6, 10, 14): L.prop("pillar", x, z, [1, 5, 1])
    for x, z in [(2, 8), (17, 8), (2, 13), (17, 13)]: L.prop("wall", x, z, [2, 3, 6], rot=90)
    L.spawn("hanuman_start", "player", 9, 2, 180)
    L.spawn("lankini", "boss_lankini", 9, 12, 0)
    L.trigger("t_lankini", 9, 8, 8, 2, "dialogue:ch2_lankini")
    L.trigger("t_gate_open", 9, 16, 4, 2, "level:lanka_streets")
    L.shrine("shrine_gate", 2, 3)
    L.save()

def lanka_streets():
    L = Level("lanka_streets", 48, 48, "stone_floor")
    L.border()
    blocks = []
    for bx in range(2, 46, 9):                                        # city blocks between 3-tile-wide streets
        for bz in range(2, 46, 9):
            if bx + 5 < 47 and bz + 5 < 47: blocks.append((bx, bz))
    houses_idx = 0
    for (bx, bz) in blocks:
        L.rect(bx, bz, bx + 5, bz + 5, "wall")
        L.rect(bx + 2, bz - 0, bx + 2, bz + 5, "stone_floor")          # a narrow gap through some blocks
        L.prop("tier_house", bx + 1, bz + 1, [4, 6, 4]); L.prop("tier_house", bx + 4, bz + 4, [4, 7, 4])
        houses_idx += 2
    for i, (x, z) in enumerate([(7, 20), (25, 7), (34, 29), (16, 38), (41, 16)]): L.prop("pillar", x, z, [1, 5, 1])
    # Ravana's palace in the north-east
    L.rect(36, 36, 46, 46, "stone_floor", 1); L.prop("gopuram", 41, 44, [8, 14, 6], protected=True)
    L.spawn("hanuman_start", "player", 2, 2, 180, size_state="small")
    patrol = [((7, 2), (7, 40)), ((16, 7), (40, 7)), ((25, 10), (25, 44)), ((34, 16), (34, 40)), ((10, 25), (44, 25)), ((16, 34), (44, 34))]
    for i, ((x0, z0), (x1, z1)) in enumerate(patrol):
        L.spawn(f"guard_{i}", "guard_spear" if i % 3 else "guard_archer", x0, z0, 0, patrol=[L.c(x0, z0), L.c(x1, z1)])
    for i, (x, z, ev) in enumerate([(20, 20, "search:mansions"), (40, 40, "search:palace"), (12, 43, "search:pushpaka")]):
        L.trigger(f"t_search_{i}", x, z, 3, 3, ev)
    L.trigger("t_despair", 44, 4, 3, 3, "dialogue:ch2_despair")
    L.trigger("t_vatika", 45, 2, 2, 3, "level:ashoka_vatika")
    for x, z in [(2, 24), (24, 2), (44, 12)]: L.shrine(f"shrine_streets_{x}_{z}", x, z)
    L.save()

def ashoka_vatika():
    L = Level("ashoka_vatika", 32, 32, "grass")
    L.border()
    L.rect(13, 13, 18, 18, "ground")                                  # clearing around the shimshapa
    L.rect(1, 15, 30, 16, "sand"); L.rect(15, 1, 16, 30, "sand")      # garden paths
    L.rect(24, 24, 28, 28, "water")                                   # lotus pond
    L.prop("shimshapa_tree", 15, 17, [4, 9, 4], protected=True)        # Hanuman hides here; Sita sits beneath
    for i in range(26):
        x, z = L.rng.randint(2, 29), L.rng.randint(2, 29)
        if 11 <= x <= 20 and 11 <= z <= 20: continue
        if L.tiles[(x, z)]["type"] != "grass": continue
        L.prop("ashoka_tree", x, z, [2.5, 6, 2.5])                     # uprootable in Ch4 (breakable_large via gameplay)
    for x, z in [(4, 4), (27, 4), (4, 27)]: L.prop("pillar", x, z, [1, 4, 1])
    L.spawn("hanuman_start", "player", 2, 15, 90, size_state="small")
    L.spawn("sita", "npc_sita", 16, 15, 180, protected=True)
    L.spawn("trijata", "npc_trijata", 18, 13, 270)
    for i, (x, z) in enumerate([(12, 12), (20, 12), (12, 19), (20, 19)]): L.spawn(f"rakshasi_{i}", "npc_rakshasi", x, z, 0)
    L.trigger("t_grove_story", 14, 16, 3, 3, "dialogue:ch3_grove")
    # Chapter 4 arena waves (spawned by the encounter director from these markers)
    waves = [("kinkara", [(6, 6), (25, 6), (6, 25)]), ("guard_spear", [(10, 2), (21, 2), (2, 10), (29, 10)]),
             ("guard_archer", [(4, 20), (27, 20), (16, 29)]), ("boss_jambumali", [(16, 27)]), ("boss_akshaya", [(16, 2)])]
    for wi, (kind, pts) in enumerate(waves):
        for i, (x, z) in enumerate(pts): L.spawn(f"w{wi}_{i}", kind, x, z, 0, wave=wi, chapter=4)
    L.shrine("shrine_vatika", 3, 3)
    L.save()

def ravana_court():
    L = Level("ravana_court", 16, 24, "stone_floor")
    L.border()
    L.rect(5, 18, 10, 22, "stone_floor", 2); L.rect(6, 20, 9, 22, "stone_floor", 3)   # dais
    for z in range(4, 18, 3):
        L.prop("pillar", 3, z, [1, 7, 1]); L.prop("pillar", 12, z, [1, 7, 1])
    L.spawn("hanuman_start", "player", 7, 3, 180, bound=True)
    L.spawn("ravana", "npc_ravana", 7, 21, 0); L.spawn("vibhishana", "npc_vibhishana", 11, 17, 270); L.spawn("indrajit", "npc_indrajit", 4, 17, 90)
    for i, z in enumerate(range(6, 16, 3)):
        L.spawn(f"courtier_l{i}", "npc_courtier", 5, z, 90); L.spawn(f"courtier_r{i}", "npc_courtier", 10, z, 270)
    L.trigger("t_court", 7, 5, 4, 2, "dialogue:ch5_court")
    L.save()

def lanka_rooftops():
    L = Level("lanka_rooftops", 64, 64, "ground")
    L.border()
    L.rect(0, 0, 63, 3, "water")                                      # the ocean edge to the south (the exit)
    L.rect(1, 4, 62, 5, "sand")
    targets = 0
    for bx in range(4, 60, 7):
        for bz in range(8, 60, 7):
            if bx + 4 >= 48 and bz + 4 >= 50: continue                 # keep the Ashoka grove (Sita) clear of buildings
            step = 2 + ((bx * 7 + bz * 3) % 3)                         # rooftop heights of 1.0-2.0 m, leapable
            L.rect(bx, bz, bx + 4, bz + 4, "stone_floor", step)
            kind = (bx + bz) % 5
            if (bx, bz) == (39, 50):                                   # Vibhishana's house: never burns
                L.prop("tier_house", bx + 2, bz + 2, [7, 8, 7], protected=True); continue
            if kind in (0, 3):                                          # rakshasa armouries and palaces: marked targets
                L.prop("tier_house", bx + 2, bz + 2, [7, 8, 7], flammable=True); targets += 1
            else:                                                       # homes of ordinary people: never burn
                L.prop("rooftop", bx + 2, bz + 2, [7, 2, 7], protected=True)
    L.rect(50, 52, 58, 60, "grass"); L.prop("ashoka_tree", 54, 56, [3, 7, 3], protected=True)   # the grove with Sita: protected
    L.spawn("sita_safe", "npc_sita", 54, 55, 180, protected=True)
    L.spawn("hanuman_start", "player", 6, 60, 180, tail_fire=True)
    for i in range(10):
        L.spawn(f"guard_{i}", "guard_archer" if i % 2 else "guard_spear", 8 + i * 5, 30 + (i % 3) * 8, 0)
    L.trigger("t_dahan_start", 6, 59, 3, 3, "dialogue:ch5_dahan")
    L.trigger("t_grove_check", 54, 54, 6, 6, "dialogue:ch5_dahan#f1")
    L.trigger("t_ocean_exit", 32, 4, 30, 2, "chapter_complete:ch5")
    print(f"  rooftops flammable targets: {targets}")
    L.save()

if __name__ == "__main__":
    for f in (mahendra, lanka_gate, lanka_streets, ashoka_vatika, ravana_court, lanka_rooftops): f()
