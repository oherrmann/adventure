# 
# game_loadsave.rb
# 
# 
module Adventure
	
	class Game
	
		def save_game_file( text )
			text = Time.now.to_s[0..18].gsub(/[-: ]/,"") + "_" + SecureRandom.alphanumeric(20) + ".rb"
			print( "  Saving file ",text,"\n" )
			tab = "\t"; cr = "\n"; tabs = tab * 3
			sio = StringIO.new
			io = File.open( "gf/" + text, "w" )
			io.write( write_header_stuff(sio) )
			sio << "module Adventure\n\tclass Game\n\t\tdef loaded_file\n"
			sio << tabs + "@timer = GTime.new(#{@timer.to_i})\n"
			sio << tabs + "@gamefile = \"#{@gamefile}\"\n"
			sio << tabs + "@moves = #{@moves}\n"
			sio << tabs + "@id = \"#{@id}\"\n"
			sio << tabs + "@location = \"#{@location}\"\n"
			sio << tabs + "@last_location = \"#{@last_location}\"\n"
			sio << tabs + "@game_location = \"#{@game_location}\"\n"
			sio << tabs + "@room_path = [\n"
			q = 0
			@room_path.each do |ele|
				o = tab*4 + "\"" + ele + "\""
				q += 1
				if q < @room_path.size then o += ",\n" else o += "\n" end
				sio << o
			end
			sio << tabs + "]\n"
			
			io.write( sio.string )
			sio.truncate(0)
			sio.rewind

			io.write save_player_data( sio, tabs )      # @players
			io.write save_object_file( sio, tabs )      # @object_file
			io.write save_doors_data( sio, tabs )       # @doors
			io.write save_food_file( sio, tabs )        # @food
			io.write save_monster_data( sio, tabs )     # @monsters
			io.write save_rooms_data( sio, tabs )       # @rooms
			#io.write save_room_exits( sio, tabs )       # @room_exits
			
			sio << tabs + "puts(\"Done. \\n\\n\")\n"
			sio << "\t\tend\n\tend\nend\n"
			io.write( sio.string )
		rescue Exception => error
			error_message( "Save Game Failure!", error )
		ensure
			io.close
			sio.close
		end
		
		def write_header_stuff( sio )
			sio << "# #{@players[0].name}\n" # lines[0][2..-1]
			sio << "# #{Time.now.asctime}\n" # lines[1][2..-1]
			# eval("%w{" + line[2..] + "}")
			sio << "# #{@id} #{@moves} \n"
			ss = sio.string.dup
			sio.truncate(0)
			sio.rewind
			return ss
		end

		
		def save_player_data( sio, tabs = "\t" ) 
			sio << tabs + "# PLAYER DATA\n"
			g = @players[0]
			sio << tabs + "@players = []\n" 
			sio << tabs + "x = GPlayer.new(\"#{g.name}\")\n"
			sio << tabs + "x.location = \"#{g.location}\"\n"
			sio << tabs + "x.last_location = \"#{g.last_location}\"\n"
			sio << tabs + "x.last_direction = \"#{g.last_direction}\"\n"
			sio << tabs + "x.experience = #{g.experience}\n"
			sio << tabs + "x.energy = #{g.energy}\n"
			sio << tabs + "x.stamina = #{g.stamina}\n"
			sio << tabs + "x.thirst = #{g.thirst}\n"
			sio << tabs + "x.hunger = #{g.hunger}\n"
			sio << tabs + "x.damaged = #{g.damaged}\n"
			sio << tabs + "h = GTime.new(#{g.next_sleep.to_i})\n"
			sio << tabs + "x.next_sleep = h\n"
			g.inventory.each {|gobj| write_game_object( gobj, sio, tabs )
				sio << tabs + "x.take( obj )\n" }
			g.hands.each {|gobj| write_game_object( gobj, sio, tabs )
				sio << tabs + "x.take( obj, true )\n" }
			sio << tabs + "@players << x\n"
			ss = sio.string.dup
			sio.truncate(0)
			sio.rewind
			return ss
		end
		
		def write_game_object( gobj, sio, tabs = "\t" )
			# Write the lines to create an object
			case gobj
			when GKey
				sio << tabs + "obj = GKey.new(\"#{gobj.id}\")\n"
				sio << tabs + "obj.doors = #{gobj.doors.inspect}\n"
			when GFood
				sio << tabs + "obj = GFood.new(\"#{gobj.type}\",#{gobj.quantity},\"#{gobj.effect}\",\"#{gobj.grow}\")\n" 
				sio << tabs + "obj.tox = #{gobj.tox}\n" if gobj.tox
				sio << tabs + "obj.original_q = #{gobj.original_q}\n"
				ref = gobj.refresh
				if gobj.refresh.nil? || gobj.refresh == false then ref = "false" else ref = "\"ref\"" end
				sio << tabs + "obj.ref = #{ref}\n"
			when GWeapon
				sio <<  tabs + "obj = GWeapon.new(\"#{gobj.id}\",\"#{gobj.name}\",\"#{gobj.description}\")\n"
				if gobj.effect.length > 0
					sio << tabs + "obj.effect = \"#{gobj.effect}\"\n"
				end
				if gobj.hidden_text.length > 0
					sio << tabs + "obj.hidden_text = \"#{gobj.hidden_text}\"\n"
				end
			when Room          # TODO
			when Container     # TODO
			when GDoor         # TODO
			when GObject
				sio <<  tabs + "obj = GObject.new(\"#{gobj.name}\",\"#{gobj.description}\")\n" 
			end
			# Write the item's attributes.
			gobj.each_attr do |key|
				unless ['hidden_text'].include?(key)
					val = gobj.get_attr(key)
					sio << tabs + "obj.set_attr(#{key.inspect},#{val.inspect})\n" 
				end
			end
			# Write data common to all objects
			sio << tabs + "obj.seen, obj.hidden, obj.moveable = "
			sio << "[#{gobj.seen},#{gobj.hidden},#{gobj.moveable}]\n" 
			sio << tabs + "obj.damaged = #{gobj.damaged}\n"
			return nil
		end
		
		
		
		def save_object_file( sio, tabs ) 
			# Object file is a Hash, the keys are the room names, and the contents 
			# are Room objects, which are containers that contain an array of 
			# game object objects. 
			sio << tabs + "# OBJECT FILE\n"
			sio << tabs + "@object_file = {\n"
			tabs += "\t"
			t = 0
			u = @object_file.size
			@object_file.each_pair do |key,val|
				sio << tabs + "\"" + key + "\" => "
				sio << "Room.new(\"#{val.name}\",\"#{val.description}\")"
				t += 1
				sio << (t == u ? " }\n" : ",\n")
			end
			tabs = tabs[0...-1]
			@object_file.each_pair do |key,val|
				val.each {|gobj|
					write_game_object( gobj, sio, tabs )
					sio << tabs + "@object_file[\"#{key}\"].add( obj )\n"
				}
			end
			ss = sio.string.dup
			sio.truncate(0)
			sio.rewind
			return ss
		end
		
		
		
		def save_doors_data( sio, tabs )  
			# Door file is a Hash, the keys are the door id (an integer) and the value
			# is a door object, which really just tracks the door's state (open, closed,
			# locked).
			sio << tabs + "# DOOR DATA\n"
			sio << tabs + "@doors = {}\n" 
			tabs += "\t"
			@doors.each_pair {|id,door|
				# Creating the door object should be part of #write_game_object method as
				# GDoors are a GObject... there might be subscriptions, or damage, etc.
				sio << tabs + "x = GDoor.new(#{id},\"#{door.description}\"\n"
				sio << tabs + "x.state = \"#{door.state}\"\n"
				sio << tabs + "@doors[#{id}] = x\n"
			}
			tabs = tabs[0...-1]
			ss = sio.string.dup
			sio.truncate(0)
			sio.rewind
			return ss
		end
		
		
		
		def save_food_file( sio, tabs ) 
			# Food file is just like the object file, but it is sparse; there are no
			# rooms listed that do not have food in them. 
			sio << tabs + "# FOOD FILE\n"
			sio << tabs + "@food = {}\n" 
			#tabs += "\t"
			@food.each_pair {|key,val|
				sio << tabs + "@food[#{key.inspect}] = "
				sio << "Room.new(\"#{val.name}\",\"#{val.description}\")\n"
			}
			@food.each_pair {|key,val|
				val.each {|gobj|
					write_game_object( gobj, sio, tabs )
					sio << tabs + "@food[\"#{key}\"].add( obj )\n"
				}
			}
			#tabs = tabs[0...-1]
			ss = sio.string.dup
			sio.truncate(0)
			sio.rewind
			return ss
		end
		
		
		
		def save_monster_data( sio, tabs )
			# Not implemented yet; probably similar to the @players file.
			sio << tabs + "# MONSTER DATA\n"
			sio << tabs + "@monsters = []\n" 
			tabs += "\t"
			sio << tabs + "#Monster data not implemented yet.\n"
			tabs = tabs[0...-1]
			ss = sio.string.dup
			sio.truncate(0)
			sio.rewind
			return ss
		end
		
		
		
		def save_rooms_data( sio, tabs )  
			# Complicated; it is a Hash, where the key is the room id (game file + room)
			# and the value is a 3-element array. Element 0 is an array of the text for the 
			# room. Element 1 is hash of room attributes, like the type of room and the 
			# ambient light. Element 2 is a Hash of GDirections, where the key is an array of
			# the direction and counter, and the values are GDirection objects. 
			# 
			sio << tabs + "# ROOM DATA\n"
			sio << tabs + "@rooms = {}\n" 
			#tabs += "\t"
			@rooms.each { |key,val| 
				sio << tabs + "@rooms[:'#{key}'] = [[],{},{}]\n" # initial setup of each room
				sio << tabs + "@rooms[:'#{key}'][0] = #{@rooms[key][0].inspect}\n"
				@rooms[key][1].each { |key1,val1|
					sio << tabs + "@rooms[:'#{key}'][1]['#{key1}'] = #{val1.inspect}\n"
				}
				@rooms[key][2].each { |key1,val1|
					sio << tabs + "x = GDirection.new(#{val1.type.inspect},#{val1.direction.inspect},#{val1.destination.inspect},#{val1.text.inspect})\n"
					unless val1.file.empty? then sio << tabs + "x.file = #{val1.file.inspect}\n" end
					unless val1.effect.empty? then sio << tabs + "x.effect = #{val1.effect.inspect}\n" end 
					unless val1.door_id.empty? then sio << tabs + "x.door_id = #{val1.door_id.inspect}\n" end
					sio << tabs + "@rooms[:'#{key}'][2][#{key1.inspect}] = x\n"
				}
			}
			#tabs = tabs[0...-1]
			ss = sio.string.dup
			sio.truncate(0)
			sio.rewind
			return ss
		end
# x = GDirection.new("direction","north-1","X1","You are on stairs leading up")
# x.file = "lostcave.xml"
# x.effect = "experience+5"
# x.door_id = ""

		def save_room_exits( sio, tabs )  
			# Room exits file is a "last values" file; in other words the exits for the
			# particular room we're in. Might not be needed since it just comes from 
			# the room data file.
			sio << tabs + "# ROOM EXITS\n"
			sio << tabs + "@room_exits = {}\n" 
			tabs += "\t"
			sio << tabs + "# Room exits not currently saved.\n"
			tabs = tabs[0...-1]
			ss = sio.string.dup
			sio.truncate(0)
			sio.rewind
			return ss
		end
		
=begin
RCA> & @rooms.each_key {|k| print(k,"\n"); @rooms[k][2].each_pair {|k1,v1| print("\t",k1,"=",v1,"\n")}}; nil
lostcave.xml/Intro
        ["north", 0]=#<Adventure::GDirection:0x0000018fa014b910>
lostcave.xml/A
        ["north", 0]=#<Adventure::GDirection:0x0000018fa04176a8>
        ["south", 0]=#<Adventure::GDirection:0x0000018fa04167f8>
lostcave.xml/B
        ["south", 0]=#<Adventure::GDirection:0x0000018fa04d2bd8>
        ["west", 1]=#<Adventure::GDirection:0x0000018fa04d1d28>
        ["west", 2]=#<Adventure::GDirection:0x0000018fa04cbf18>
lostcave.xml/B-1
        ["east", 0]=#<Adventure::GDirection:0x0000018fa0468d78>
				



RCA> & @rooms.each_key {|k| print(k,"\n",@rooms[k][2].pretty) }; nil
lostcave.xml/Intro
{
  ['north', 0] =>
  <Adventure::GDirection:60
    @type:direction
    @direction:north
    @destination:A
    @door_id:
  >
}
lostcave.xml/A
{
  ['north', 0] =>
  <Adventure::GDirection:80
    @type:direction
    @direction:north
    @destination:B
    @door_id:
  >,
  ['south', 0] =>
  <Adventure::GDirection:100
    @type:direction
    @direction:south
    @destination:Intro
    @door_id:
  >
}
lostcave.xml/B
{
  ['south', 0] =>
  <Adventure::GDirection:120
    @type:direction
    @direction:south
    @destination:A
    @door_id:
  >,
  ['west', 1] =>
  <Adventure::GDirection:140
    @type:direction
    @direction:west-1
    @destination:C
    @door_id:
  >,
  ['west', 2] =>
  <Adventure::GDirection:160
    @type:direction
    @direction:west-2
    @destination:B-1
    @door_id:
  >
}
lostcave.xml/B-1
{
  ['east', 0] =>
  <Adventure::GDirection:180
    @type:direction
    @direction:east
    @destination:B
    @door_id:
  >
}


=end
		
		
		######################################################################################################
		#                                                                                                   #
		#                                                                                                   #
		######################################################################################################
		
		def load_game_file( text )
			load "gf/" + text
			loaded_file()
		rescue Exception => e
			error_message( "Load Error!", e )
		end
		
	end # Game class
	
end # Adventure module