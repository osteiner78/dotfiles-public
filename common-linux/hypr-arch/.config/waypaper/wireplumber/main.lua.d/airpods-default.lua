rule = {
  matches = {
    {
      { "device.name", "equals", "bluez_card.40_DA_5C_76_CE_D7" },
    },
  },
  apply_properties = {
    ["bluez5.auto-connect"] = "[ a2dp_sink ]",
    ["bluez5.codec-priority"] = { ["aac"] = 100, ["sbc_xq"] = 90, ["sbc"] = 80 }
  }
}

table.insert(alsa_monitor.rules, rule)

