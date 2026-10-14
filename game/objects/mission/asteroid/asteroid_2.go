components {
  id: "visual"
  component: "/game/resources/models/asteroid/asteroid_2.model"
}
components {
  id: "explosion"
  component: "/game/resources/particlefx/explosion.particlefx"
}
embedded_components {
  id: "collision_asteroid"
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
  "    shape_type: TYPE_SPHERE\n"
  "    position {\n"
  "    }\n"
  "    rotation {\n"
  "    }\n"
  "    index: 0\n"
  "    count: 1\n"
  "    id: \"body\"\n"
  "  }\n"
  "  data: 1.2\n"
  "}\n"
  ""
}
