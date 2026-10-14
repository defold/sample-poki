components {
  id: "visual"
  component: "/game/resources/models/enemy/enemy.model"
  position {
    x: -2.0
    y: -0.3
    z: -1.5
  }
}
components {
  id: "explosion"
  component: "/game/resources/particlefx/explosion.particlefx"
}
embedded_components {
  id: "collision_enemy"
  type: "collisionobject"
  data: "type: COLLISION_OBJECT_TYPE_TRIGGER\n"
  "mass: 0.0\n"
  "friction: 0.0\n"
  "restitution: 0.0\n"
  "group: \"actor\"\n"
  "mask: \"player\"\n"
  "mask: \"player_shot\"\n"
  "embedded_collision_shape {\n"
  "  shapes {\n"
  "    shape_type: TYPE_BOX\n"
  "    position {\n"
  "    }\n"
  "    rotation {\n"
  "    }\n"
  "    index: 0\n"
  "    count: 3\n"
  "    id: \"body\"\n"
  "  }\n"
  "  data: 1.0\n"
  "  data: 0.5\n"
  "  data: 1.05\n"
  "}\n"
  ""
}
embedded_components {
  id: "collision_boss"
  type: "collisionobject"
  data: "type: COLLISION_OBJECT_TYPE_TRIGGER\n"
  "mass: 0.0\n"
  "friction: 0.0\n"
  "restitution: 0.0\n"
  "group: \"actor\"\n"
  "mask: \"player\"\n"
  "mask: \"player_shot\"\n"
  "embedded_collision_shape {\n"
  "  shapes {\n"
  "    shape_type: TYPE_BOX\n"
  "    position {\n"
  "    }\n"
  "    rotation {\n"
  "    }\n"
  "    index: 0\n"
  "    count: 3\n"
  "    id: \"body\"\n"
  "  }\n"
  "  data: 2.0\n"
  "  data: 0.8\n"
  "  data: 1.4\n"
  "}\n"
  ""
}
