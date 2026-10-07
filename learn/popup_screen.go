components {
  id: "screen_proxy"
  component: "/monarch/screen_proxy.script"
  properties { id: "screen_proxy" value: "#learn_popup" type: PROPERTY_TYPE_URL }
  properties { id: "screen_id" value: "learn_popup" type: PROPERTY_TYPE_HASH }
  properties { id: "popup" value: "true" type: PROPERTY_TYPE_BOOLEAN }
  properties { id: "popup_on_popup" value: "true" type: PROPERTY_TYPE_BOOLEAN }
}
embedded_components { id: "learn_popup" type: "collectionproxy" data: "collection: \"/learn/popup.collection\"\n" "" }
