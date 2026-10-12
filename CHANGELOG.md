# Changelog

All notable changes to Tidy Nest. It works on any server: installing it on the server too is optional.

## 1.0.0 (2026-10-12)

First release.

**Added**
- **Sort buttons** above the top-right corner of your inventory, chests, double chests, barrels, ender chests, chest minecarts and boats, and shulker boxes. One click sorts that grid.
- **Sort order:** stacks merged; gear first (weapons and tools by type, then armour head to feet, then other gear), best material and least worn first; then blocks, food and potions, materials, other items, and storage (shulker boxes and bundles) last. Within each group the item you have most of comes first, biggest stacks first.
- **Your hotbar, armour and off hand never move.**
- **Shortcuts:** double-click an empty slot (empty hand) or middle-click a slot to sort its grid (middle-click in survival only). An optional key, *Sort the area under the mouse*, can be set in Controls → Inventory.
- **Works on any server.** With Tidy Nest on the server (and in singleplayer), the server sorts in one step; without it, your game sorts with ordinary clicks and stops safely if anything doesn't match.
- **Update notice:** when a newer version is out, the game says so once on the title screen and once in chat. Turn it off with `"check_for_updates": false` in `config/tidynest.json`.
- **Updater** for Windows (`tidynest-updater.zip`), which only installs jars signed by afkbird.
