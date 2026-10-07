components {
  id: "mesh"
  component: "/game/resources/models/projectile/projectile.model"
  position {
    z: 0.3
  }
}
embedded_components {
  id: "collision_projectile"
  type: "collisionobject"
  data: "type: COLLISION_OBJECT_TYPE_TRIGGER\n"
  "mass: 0.0\n"
  "friction: 0.0\n"
  "restitution: 0.0\n"
  "group: \"player_shot\"\n"
  "mask: \"actor\"\n"
  "mask: \"player\"\n"
  "embedded_collision_shape {\n"
  "  shapes {\n"
  "    shape_type: TYPE_BOX\n"
  "    position {\n"
  "    }\n"
  "    rotation {\n"
  "    }\n"
  "    index: 0\n"
  "    count: 3\n"
  "  }\n"
  "  data: 0.2\n"
  "  data: 0.2\n"
  "  data: 0.5\n"
  "}\n"
  ""
}
