This is a simple yet non-trivial board game and AI system. The main objective is to demonstrate AI in a non-trivial environment.
How to play: Select a map (a grid of square tiles, each tile corresponding to some terrain). You and the enemy AI will each be allocated a random set of soldiers.
Each soldier is premade (as are each map) and given some cost; the game will automatically balance your forces and the enemy AI forces to be roughly equal to each other.
Once you and the enemy AI have gotten your soldiers, the game will initialize with each soldier in a random tile.
Each player takes turn selecting one soldier. He will have an ability (for example traveling to a tile, attacking an adjacent tile, making a ranged attack into further tiles, calling in artillery to change some tiles, or passive abilities like ignoring suppression) and some current active status effects (for example being suppressed). Do that ability, the pass turn to the other player.
There are certain objective tiles on the map. Capture all objective tiles and make sure the enemy does not capture any of them back for 3 turns to win.
