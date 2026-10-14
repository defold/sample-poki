components {
  id: "particlefx"
  component: "/game/resources/particlefx/engine_trail.particlefx"
  position {
    y: 0.3
    z: 0.9
  }
}
components {
  id: "explosion"
  component: "/game/resources/particlefx/explosion.particlefx"
}
components {
  id: "autoplay_particlefx"
  component: "/game/scripts/mission/autoplay_particlefx.script"
}
components {
  id: "player_reaction"
  component: "/game/scripts/player/player_reaction.script"
}
components {
  id: "model"
  component: "/game/resources/models/player/ship_speeder.model"
  position {
    x: -2.0
    z: -1.5
  }
}
components {
  id: "model_interceptor"
  component: "/game/resources/models/player/ship_interceptor.model"
  position {
    x: -2.0
    z: -1.6
  }
}
components {
  id: "model_comet"
  component: "/game/resources/models/player/ship_comet.model"
  position {
    x: -2.0
    z: -1.5
  }
}
embedded_components {
  id: "collision_scout"
  type: "collisionobject"
  data: "type: COLLISION_OBJECT_TYPE_TRIGGER\n"
  "mass: 0.0\n"
  "friction: 0.0\n"
  "restitution: 0.0\n"
  "group: \"player\"\n"
  "mask: \"actor\"\n"
  "mask: \"pickup\"\n"
  "mask: \"enemy_shot\"\n"
  "embedded_collision_shape {\n"
  "  shapes {\n"
  "    shape_type: TYPE_BOX\n"
  "    position {\n"
  "    }\n"
  "    rotation {\n"
  "    }\n"
  "    index: 0\n"
  "    count: 3\n"
  "    id: \"hull\"\n"
  "  }\n"
  "  data: 0.4\n"
  "  data: 0.5\n"
  "  data: 0.5\n"
  "}\n"
  ""
}
embedded_components {
  id: "collision_interceptor"
  type: "collisionobject"
  data: "type: COLLISION_OBJECT_TYPE_TRIGGER\n"
  "mass: 0.0\n"
  "friction: 0.0\n"
  "restitution: 0.0\n"
  "group: \"player\"\n"
  "mask: \"actor\"\n"
  "mask: \"pickup\"\n"
  "mask: \"enemy_shot\"\n"
  "embedded_collision_shape {\n"
  "  shapes {\n"
  "    shape_type: TYPE_BOX\n"
  "    position {\n"
  "    }\n"
  "    rotation {\n"
  "    }\n"
  "    index: 0\n"
  "    count: 3\n"
  "    id: \"hull\"\n"
  "  }\n"
  "  data: 0.5\n"
  "  data: 0.5\n"
  "  data: 0.6\n"
  "}\n"
  ""
}
embedded_components {
  id: "collision_comet"
  type: "collisionobject"
  data: "type: COLLISION_OBJECT_TYPE_TRIGGER\n"
  "mass: 0.0\n"
  "friction: 0.0\n"
  "restitution: 0.0\n"
  "group: \"player\"\n"
  "mask: \"actor\"\n"
  "mask: \"pickup\"\n"
  "mask: \"enemy_shot\"\n"
  "embedded_collision_shape {\n"
  "  shapes {\n"
  "    shape_type: TYPE_BOX\n"
  "    position {\n"
  "    }\n"
  "    rotation {\n"
  "    }\n"
  "    index: 0\n"
  "    count: 3\n"
  "    id: \"hull\"\n"
  "  }\n"
  "  data: 0.6\n"
  "  data: 0.5\n"
  "  data: 0.75\n"
  "}\n"
  ""
}
