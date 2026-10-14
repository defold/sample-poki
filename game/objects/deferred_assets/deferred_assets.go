components {
  id: "loader"
  component: "/app/scripts/assets/pack_proxies.script"
  properties { id: "owner" value: "main:/app/controller#app" type: PROPERTY_TYPE_URL }
}
embedded_components {
  id: "fa_font"
  type: "collectionproxy"
  data: "collection: \"/game/collections/fonts/lang_fa.collection\"\n"
  "exclude: true\n"
  ""
}embedded_components {
  id: "cyrillic_font"
  type: "collectionproxy"
  data: "collection: \"/game/collections/fonts/lang_cyrillic.collection\"\n"
  "exclude: true\n"
  ""
}embedded_components {
  id: "cjk_font"
  type: "collectionproxy"
  data: "collection: \"/game/collections/fonts/lang_cjk.collection\"\n"
  "exclude: true\n"
  ""
}embedded_components {
  id: "deferred_audio"
  type: "collectionproxy"
  data: "collection: \"/game/collections/deferred_audio/deferred_audio.collection\"\n"
  "exclude: true\n"
  ""
}
