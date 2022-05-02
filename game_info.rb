# 
# 
# 
# Ruby Caves Info Document
# 
# 
# 
# game is currently played this way:
# > load 'game.rb'
# > g = Game::Game.new( <filename> )
# > g.play
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
# 
=begin
# Testing adding an item to the player's inventory
load 'game.rb'
g = Game::GPlayer.new("Owein")
torch = Game::GObject.new("torch","a torch to see by")
g.take(torch)
g.inventory.
=end
=begin
#Testing namespaces... there was a conflict having a Game module and a Game class. Renamed Game module to Adventure
# and this issue was resolved.
g = Game.new("cave4.dat")
puts "Adventure:: methods"
(Adventure::methods - Object.methods).sort.each{|x| puts x}
peval{"[sep]"}
puts "Game methods"
(g.methods - Object.methods).sort.each{|x| puts x}
=end