components {
  id: "visual"
  component: "/game/resources/models/ammo/ammo.model"
  position {
    x: -2.0
    y: -0.15
    z: -1.5
  }
}
components {
  id: "particlefx"
  component: "/game/resources/particlefx/ammo.particlefx"
}
components {
  id: "pickup_particlefx"
  component: "/game/resources/particlefx/pickup.particlefx"
}
components {
  id: "autoplay_particlefx"
  component: "/game/scripts/mission/autoplay_particlefx.script"
}
embedded_components {
  id: "collision_ammo"
  type: "collisionobject"
  data: "type: COLLISION_OBJECT_TYPE_TRIGGER\n"
  "mass: 0.0\n"
  "friction: 0.0\n"
  "restitution: 0.0\n"
  "group: \"pickup\"\n"
  "mask: \"player\"\n"
  "embedded_collision_shape {\n"
  "  shapes {\n"
  "    shape_type: TYPE_SPHERE\n"
  "    position {\n"
  "    }\n"
  "    rotation {\n"
  "    }\n"
  "    index: 0\n"
  "    count: 1\n"
  "    id: \"pickup\"\n"
  "  }\n"
  "  data: 1.5\n"
  "}\n"
  ""
}
