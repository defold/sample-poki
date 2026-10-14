components {
  id: "screen_proxy"
  component: "/monarch/screen_proxy.script"
  properties {
    id: "screen_proxy"
    value: "#mothership"
    type: PROPERTY_TYPE_URL
  }
  properties {
    id: "screen_id"
    value: "mothership"
    type: PROPERTY_TYPE_HASH
  }
}
embedded_components {
  id: "mothership"
  type: "collectionproxy"
  data: "collection: \"/game/collections/screens/shop/shop.collection\"\n"
  ""
}
