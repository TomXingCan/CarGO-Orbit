local _, ns = ...

ns.defaults = {
    profile = {
        debug = false,
        infoBar = {
            enabled = false,
            position = "BOTTOM",
            width = 0,
            height = 30,
            spacing = 20,
            visibility = "ALWAYS",
            background = { enabled = true, alpha = 0.25 },
            layout = {
                preset = "toxi",
                slots = {
                    left = { "MicroMenu", "", "Durability" },
                    center = { "Travel", "Time", "Spec" },
                    right = { "XPRep", "Currency", "System" },
                },
            },
            providers = {
                Time = { localTime = true, twentyFour = true, fontSize = 32, offsetY = 1 },
            },
        },
        enhancedResourceBars = {
            enabled = false,
        },
    },
    meta = {
        schemaVersion = 2,
    },
}
