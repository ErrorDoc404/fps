# Development Roadmap

| Milestone | Scope | Status |
|---|---|---|
| M0 Research & planning | Asset audit, engine + networking evaluation, architecture, repo layout, build pipeline | **Done** |
| M1 FPS foundation | First-person camera, movement states, stamina, input map, camera settings, arms + view model, procedural animation, HUD | **Done (graybox art)** |
| M2 Combat foundation | 5 weapons (data-driven), switching, reload, ADS, fire modes, ammo, health/armor, damage feedback, 4 AI types | **Done** |
| M3 Dedicated multiplayer | ENet dedicated server, auth, spawning, snapshots, prediction/reconciliation, server-authoritative damage, disconnect + reconnect slot | **Done (LAN-verified)** |
| M4 Cooperative systems | Squad lobby, leader transfer, 4 classes, shared objectives, downed/revive, squad HUD, extraction rules | **Done** |
| M5 First mission | OP-01 First Contact map, briefing, objectives (2 primary, 2 optional, extraction), enemy groups/reinforcements, results, rewards, persistence | **Done (graybox)** |
| M6 Campaign & progression | OP-02…OP-07, environments, weather, mission variations, outfits/insignias, purchases | Not started (data stubs exist) |
| M7 Polish & release | Real art (characters, weapons, environments), audio assets, animation rigs, voice chat, Steam (GodotSteam), server fleet allocation, accessibility, controller UI navigation, profiling, closed test | Not started |

Priority after this build: replace graybox art (character + weapon models with skeletal animation), add real audio,
WAN testing with latency/packet-loss simulation, then OP-02.
