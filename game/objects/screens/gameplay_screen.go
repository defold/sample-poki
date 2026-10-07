components {
  id: "screen_proxy"
  component: "/monarch/screen_proxy.script"
  properties {
    id: "screen_proxy"
    value: "#gameplay"
    type: PROPERTY_TYPE_URL
  }
  properties {
    id: "screen_id"
    value: "gameplay"
    type: PROPERTY_TYPE_HASH
  }
  properties {
    id: "timestep_below_popup"
    value: "-1.0"
    type: PROPERTY_TYPE_NUMBER
  }
}
embedded_components {
  id: "gameplay"
  type: "collectionproxy"
  data: "collection: \"/game/collections/mission/gameplay.collection\"\n"
  ""
}
