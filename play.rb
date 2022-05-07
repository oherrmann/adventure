# 
# 
# play the game
# 
$LOAD_PATH.push(`cd`.gsub('\\','/').chomp() )
require './game'
module Adventure
Game.new("lostcave.xml").play
end