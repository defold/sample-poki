components {
  id: "gameplay"
  component: "/game/scripts/mission/gameplay.script"
}
components {
  id: "audio_reaction"
  component: "/game/scripts/mission/audio/audio_reaction.script"
}
components {
  id: "vfx_reaction"
  component: "/game/scripts/mission/vfx_reaction.script"
}
embedded_components {
  id: "asteroid_1_factory"
  type: "factory"
  data: "prototype: \"/game/objects/mission/asteroid/asteroid_1.go\"\n"
  ""
}
embedded_components {
  id: "asteroid_2_factory"
  type: "factory"
  data: "prototype: \"/game/objects/mission/asteroid/asteroid_2.go\"\n"
  ""
}
embedded_components {
  id: "asteroid_3_factory"
  type: "factory"
  data: "prototype: \"/game/objects/mission/asteroid/asteroid_3.go\"\n"
  ""
}
embedded_components {
  id: "asteroid_4_factory"
  type: "factory"
  data: "prototype: \"/game/objects/mission/asteroid/asteroid_4.go\"\n"
  ""
}
embedded_components {
  id: "enemy_factory"
  type: "factory"
  data: "prototype: \"/game/objects/mission/enemy/enemy.go\"\n"
  ""
}
embedded_components {
  id: "ammo_factory"
  type: "factory"
  data: "prototype: \"/game/objects/mission/ammo/ammo.go\"\n"
  ""
}
embedded_components {
  id: "projectile_factory"
  type: "factory"
  data: "prototype: \"/game/objects/mission/projectile/projectile.go\"\n"
  ""
}
embedded_components {
  id: "planet_factory"
  type: "factory"
  data: "prototype: \"/game/objects/world/planet.go\"\n"
  ""
}
