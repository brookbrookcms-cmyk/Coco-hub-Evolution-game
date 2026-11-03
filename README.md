# Coco hub — Evolution game

For [Evolution game](https://www.roblox.com/games/74931828101115/Evolution-game).

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/brookbrookcms-cmyk/Coco-hub-Evolution-game/main/loadscript.lua"))()
```

Run once in the game with an executor that supports `game:HttpGet` and `queue_on_teleport`. The script visits each joinable public server in the initial server list, reads replicated height values, and returns to the server with the tallest player it observed. It then resets the character after age 18 until it sees either 8'4 at age 1 or 20'0 at age 18.

The server search is a snapshot. Full servers and players whose heights are not replicated to clients cannot be compared. The game's live stat layout has not been verified; if its height or age values are unavailable to the client, the script stops with a diagnostic message.
