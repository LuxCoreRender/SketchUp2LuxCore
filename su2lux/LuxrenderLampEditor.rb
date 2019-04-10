# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU Lesser General Public License as published by the Free Software
# Foundation; either version 2 of the License, or (at your option) any later
# version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License along with
# this program; if not, write to the Free Software Foundation, Inc., 59 Temple
# Place - Suite 330, Boston, MA 02111-1307, USA, or go to
# http://www.gnu.org/copyleft/lesser.txt.
#-----------------------------------------------------------------------------
# This file is part of su2lux.
#
# Authors      : Abel Groenewolt

class LuxrenderLampEditor

	attr_reader :lamp_dialog, :lamp_names
	attr_writer :lamp_names
	##
	#
	##
	def initialize(lrs, model)
		@lampCollection = {} # hash containing lamp component definitions and SU2LUX lamp objects # componentDefinition => SU2LUX_LampObject
		@lampsByName = {} # hash containing lamp names and objects
		@lampNames = []
		@activeLamp = nil
        @lrs = lrs
		@model = model
		
        puts "initializing lamp editor"
        filename = File.basename(model.path)
        if (filename == "")
            windowname = "SU2LUX Lamp Editor"
        else
            windowname = "SU2LUX Lamp - " + filename
        end
		
		@lamp_dialog = UI::WebDialog.new(windowname, true, "LuxrenderLampEditor", 450, 600, 10, 10, true)
        @lamp_dialog.max_width = 700
        @lamp_dialog.max_height = 3000
		setting_html_path = Sketchup.find_support_file("LampEditor.html" , File.join("Plugins", SU2LUX::PLUGIN_FOLDER))
		@lamp_dialog.set_file(setting_html_path)
		
		@color_picker = UI::WebDialog.new("Color Picker - lamp", false, "ColorPicker", 410, 200, 200, 350, true)
        color_picker_path = Sketchup.find_support_file("colorpicker.html", File.join("Plugins", "su2lux"))
        @color_picker.set_file(color_picker_path)
		
        puts "finished initializing lamp editor"
		
		@definitions_containing_lamps = []
		@definitions_not_containing_lamps = []

	   # callbacks for javascript functions

		##
		#	create new lamp by pressing 'new' button	
		##	
		
		@lamp_dialog.add_action_callback('create_lamp') {|dialog|
			puts "creating new lamp"
			
			# ask for name, proposing one that is free
			generatedName = ""
			nameFree = false
			volNumber = 0
			while(nameFree == false)
				volNumber += 1
				generatedName = "lamp_" + volNumber.to_s
				if(@lampsByName[generatedName] == nil)
					nameFree = true
				end
			end			
			lampName = UI.inputbox(["lamp name"], [generatedName], "Enter new lamp name")
			
			if(lampName != false)
				# check if name exists
				nameExists = false
				if (@lampsByName[lampName[0]] != nil)
					nameExists = true
				end
				
				# create lamp object, or warn user of duplicate name
				if(!nameExists)
					puts "creating lamp with name " + lampName[0]
					
					# create a lamp component
					# create component definition
					lamp_component_definition = @model.definitions.add("SU2LUX_lamp")
					
					#
					#
					#
					
					# create component instance with provided name (SU2LUX_lamp_#lampName
					lamp_default_transformation = Geom::Transformation.new
					lamp_instance = @model.active_entities.add_instance(lamp_component_definition, lamp_default_transformation)
					lamp_instance.name = "SU2LUX_" + lampName[0]
					
					# add initial lamp parameters to lamp component's attribute dictionary
					lamp_component_definition.set_attribute "LuxRender", "lamp_type", ["spot"].pack("m")
					
					# create a lamp object
					lampObject = LuxRenderLamp.new(true, self, @lrs, lampName[0], lamp_instance)
					@activeLamp = lampObject
								
					# add lamp to dropdown 
					addToListCommand = 'addToLampListAndSet("' + lampName[0] + '")'
					
					#puts addToListCommand
					@lamp_dialog.execute_script(addToListCommand)
					
					# show lamp type chooser in interface
					@lamp_dialog.execute_script('$("#lamp_type_area").show()')			
				
					# show relevant parameters in interface
					@lamp_dialog.execute_script('$("#lamp_type").val("spot")')	
					@lamp_dialog.execute_script('showParameterSections("spot")')
					updateSwatch("ffffff")
					@lamp_dialog.execute_script("$('#light_group').val('');")	
					
					# get parameter values from object and show in interface
					updateParams(lampObject)
					
					
				else
					UI.messagebox("lamp name exists already, please choose a different name")
				end
			end
		}
		
		##
		#	select IES file
		##
		@lamp_dialog.add_action_callback("select_IES") {|dialog, params|
			puts "lamp editor: select_IES callback responding"
			# get path
			newIESpath = UI.openpanel("Select IES file", "", "")
			if(newIESpath)
				# escape path
				newIESpath.gsub!(/\\\\/, '/') 
				newIESpath.gsub!(/\\/, '/') if newIESpath.include?('\\')
				# feedback
				puts "new IES path:"
				puts newIESpath
				# set IES value 	
				@activeLamp.setValue("iesname", newIESpath)
				# update IES value in material interface
                cmd = "$('#iesname').val('" + newIESpath + "');"
                @lamp_dialog.execute_script(cmd)				
			end
		}
		
		
		##
		#	clear IES file
		##
		@lamp_dialog.add_action_callback("clear_IES") {|dialog, params|
			puts "lamp editor: clear callback responding"
			# set IES value 	
				@activeLamp.setValue("iesname", "")
			# update IES value in material interface
            cmd = "$('#iesname').val('');"
            @lamp_dialog.execute_script(cmd)				
		}
		
		
				
		##
		#	select map file
		##
		@lamp_dialog.add_action_callback("select_map") {|dialog, params|
			puts "lamp editor: select projection map callback responding"
			# get path
			newmappath = UI.openpanel("Select projection map file", "", "")
			if(newmappath)
				# escape path
				newmappath.gsub!(/\\\\/, '/') 
				newmappath.gsub!(/\\/, '/') if newmappath.include?('\\')
				# feedback
				puts "new map path: " + newmappath
				# set IES value 	
				@activeLamp.setValue("mapname", newmappath)
				# update IES value in material interface
                cmd = "$('#mapname').val('" + newmappath + "');"
                @lamp_dialog.execute_script(cmd)				
			end
		}
		
		
		##
		#	clear map file
		##
		@lamp_dialog.add_action_callback("clear_map") {|dialog, params|
			puts "lamp editor: projection map clear callback responding"
			@activeLamp.setValue("mapname", "")
			# update projection map value in material interface
            cmd = "$('#mapname').val('');"
            @lamp_dialog.execute_script(cmd)				
		}
		
		##
		#	show information in GUI after opening it
		##
		
		@lamp_dialog.add_action_callback('update_GUI') {|dialog, paramString|
			#puts "update_GUI callback"
			update_GUI()
		}

		##
		#	pass on changed parameter from interface to dictionary
		##
		@lamp_dialog.add_action_callback('set_param') {|dialog, paramString|
            #SU2LUX.dbg_p "callback: set_param"
			#puts paramString # lampName|parameterName|parameterValue
			params = paramString.split('|')
			lampObject = @lampsByName[params[0]]
			lampObject.setValue(params[1],params[2])
		}

		##
		#	update lamp type: update lamp type in dictionary and get values from dictionary
		##
		@lamp_dialog.add_action_callback('update_lamp_type') {|dialog, paramString|
            SU2LUX.dbg_p "callback: update lamp type"
			#puts paramString # homogeneous|lamp01
			
			params = paramString.split('|')
			lampObject = @lampsByName[params[1]]
			puts "lampObject is " + lampObject.to_s
			
			# store texture type in material
			puts "storing lamp type"
			lampObject.setValue("lamp_type",params[0])
			puts "getTexType " + lampObject.getValue("lamp_type")
			
			# get values from object, show in interface
			puts "updating parameters in interface"
			updateParams(lampObject)
		}

		@lamp_dialog.add_action_callback('display_lamp') {|dialog, paramString|
			#puts "lamp selected, displaying interface for #{paramString}"
			# get lamp object
			lampObject = @lampsByName[paramString]
			# set as active lamp
			if lampObject != @activeLamp
				set_active_lamp(lampObject)
			
				# set texture type dropdown
				lampType = lampObject.getValue("lamp_type")
				puts "setting dropdown to " + lampType
				@lamp_dialog.execute_script("$('#lamp_type').val('" + lampType +"');")
			
				# show relevant parameters in interface
				@lamp_dialog.execute_script('showParameterSections("' + lampType  +  '")')
			
				# get parameter values from object and show in interface
				updateParams(lampObject)
			end
		}
		
		@lamp_dialog.add_action_callback('open_color_picker') { |dialog, param|
            SU2LUX.dbg_p "opening color picker window for lamp editor"
            # @colorpicker_lamp = param
			updateColorPicker() # for OS X
            @color_picker.show
        }
		
		@color_picker.add_action_callback('provide_color') { |dialog, passedcolor|
			#puts "lamp editor callback passing colour to colour picker init_color command"		
			if(@activeLamp)
				updateColorPicker() # for Windows
			end
		}
		
		##
		#	react to colour picker colour changes		
        ##
        @color_picker.add_action_callback('pass_color') { |dialog, passedColor| # passedcolor is in #ffffff form
			puts "lamp editor color picker callback: pass_color"
            passedColor="#000000" if passedColor.length != 7 # color picker may return NaN when mouse is dragged outside window
			updateSwatch(passedColor)
			
			# convert #RRGGBB to three float values in range 0 - 1
			rvalue = (passedColor[1, 2].to_i(16).to_f*1000000/255.0).round/1000000.0 # ruby 1.8 doesn't support round(6)
            gvalue = (passedColor[3, 2].to_i(16).to_f*1000000/255.0).round/1000000.0
            bvalue = (passedColor[5, 2].to_i(16).to_f*1000000/255.0).round/1000000.0
			
			# update value in lamp object
			@activeLamp.setValue("color_r", rvalue)
			@activeLamp.setValue("color_g", gvalue)
			@activeLamp.setValue("color_b", bvalue)
			
        }
		
		@color_picker.add_action_callback('colorfield_red_update') { |dialog, colorValue|
			#puts "lamp editor callback: updating red channel"
			@activeLamp.setValue("color_r", colorValue.to_f)
			channelColor = [@activeLamp.getValue("color_r").to_f, @activeLamp.getValue("color_g").to_f, @activeLamp.getValue("color_b").to_f] 
			updateSwatch(toHex(channelColor))
		}
		
		@color_picker.add_action_callback('colorfield_green_update') { |dialog, colorValue|
			#puts "lamp editor callback: updating green channel"
			@activeLamp.setValue("color_g", colorValue.to_f)
			channelColor = [@activeLamp.getValue("color_r").to_f, @activeLamp.getValue("color_g").to_f, @activeLamp.getValue("color_b").to_f] 
			updateSwatch(toHex(channelColor))
		}	
		
		@color_picker.add_action_callback('colorfield_blue_update') { |dialog, colorValue|
			#puts "lamp editor callback: updating blue channel"
			@activeLamp.setValue("color_b", colorValue.to_f)
			channelColor = [@activeLamp.getValue("color_r").to_f, @activeLamp.getValue("color_g").to_f, @activeLamp.getValue("color_b").to_f] 
			updateSwatch(toHex(channelColor))
		}

	end # END initialize

	
	def load_lamps_from_file()
		# first, collect all component definitions that are a lamp
		lamp_definitions = []
		@model.definitions.each do |comp_def|
			if (comp_def.attribute_dictionary("LuxRender") != nil)
				lamp_definitions << comp_def
			end
		end
		
		# for all collected definitions, get all instances and create lamp objects for them
		lamp_definitions.each do |lamp_def|
			lamp_def.instances.each do |lamp_def_instance|
				# create object
				name = lamp_def.attribute_dictionaries["LuxRender"]["name"].unpack("m")[0]
				lampObject = LuxRenderLamp.new(false, self, @lrs, name, lamp_def_instance)
				
				# note: lamp will be addded to drop down menu in update_GUI method
			end
		end
		
		# set an active lamp
		if(@lampCollection.size > 0)
			@activeLamp = @lampCollection.values[0]
			update_GUI(@activeLamp)
		end
	end
	
		
	
	def update_GUI(lampObject = nil)
		puts 'running update_GUI'
		puts 'valid lamp object provided? ' + (lampObject == nil ?  "no" : ("yes, : " + lampObject.name)) 
		
		@lamp_dialog.execute_script('clearLampList()')
		
		for existingLampObject in @lampCollection.values
			puts "adding " + existingLampObject.name + " to lamp editor's lamp list"
			cmd = 'addToLampList("' + existingLampObject.name + '")'
			@lamp_dialog.execute_script(cmd)
		end
		
		if(@lampCollection.values.size > 0)
			# make sure we have a lamp object; if it wasn't provided, pick the first one		
			if(lampObject == nil)
				if(@activeLamp == nil)
					@activeLamp = @lampCollection.values[0]
				end
				lampObject = @activeLamp
			end
			
			puts 'updating lamp editor interface for ' + lampObject.name
			
			# set object name in dropdown
			@lamp_dialog.execute_script('$("#lamps_in_model").val("' + lampObject.name + '");')
			
			# show lamp type area
			@lamp_dialog.execute_script('$("#lamp_type_area").show();')
			
			# set type
			@lamp_dialog.execute_script('$("#lamp_type").val("' + lampObject.lampType() + '")')
			
			# show parameters areas
			# load parameters
			@lamp_dialog.execute_script('showParameterSections("' + lampObject.lampType()  +  '")')
			
			# get parameter values from object and show in interface
			updateParams(lampObject)
			
			#update colour swatch
			updateSwatch()
		end
	end
	
	def update_GUI_safe(lampObject) # update GUI without modifying anything
		#puts 'updating lamp editor interface (safe)' 
		if(lampObject != nil)
			# set object name in dropdown
			@lamp_dialog.execute_script('$("#lamps_in_model").val("' + lampObject.name + '");')
			
			# show lamp type area
			@lamp_dialog.execute_script('$("#lamp_type_area").show();')
			
			# set type
			set_type_command = '$("#lamp_type").val("' + lampObject.lampType() + '")'
			#puts "trying to set type: " + set_type_command
			@lamp_dialog.execute_script(set_type_command)
			
			# show parameters areas
			@lamp_dialog.execute_script('showParameterSections("' + lampObject.lampType()  +  '")')
			
			# get parameter values from object and show in interface
			updateParams(lampObject)
		end		
	end

	def updateSwatch(hexColor = nil)
		if(hexColor == nil)
			hexColor = toHex([@activeLamp.getValue("color_r").to_f, @activeLamp.getValue("color_g").to_f, @activeLamp.getValue("color_b").to_f])
		end
	
		updateSwatchCmd = "$('#lamp_color_swatch').css('background-color', '" + hexColor + "');"			
		@lamp_dialog.execute_script(updateSwatchCmd)
	end
	
	
	def toHex(listRGB)
		puts "toHex in:"
		puts listRGB
		rval = (listRGB[0]*255).to_i.to_s(16)
		gval = (listRGB[1]*255).to_i.to_s(16)
		bval = (listRGB[2]*255).to_i.to_s(16)
		if (rval.length == 1)
			rval = "0" + rval
		end
		if (gval.length == 1)
			gval = "0" + gval
		end
		if (bval.length == 1)
			bval = "0" + bval
		end
		puts "toHex out:"
		puts ("#" + rval + gval + bval)
		return ("#" + rval + gval + bval)
	end


	##
	#	update parameters in interface
	##
	
	def updateParams(lampObject)
		varValues = lampObject.getValueHash()
		varValues.each do |key, value|
			# update parameter in interface using jQuery command
			real_value = lampObject.getValue(key)
			cmd = '$("#' + key + '").val("' + real_value.to_s + '")'
			puts cmd
			@lamp_dialog.execute_script(cmd)
		end
		
		# set colour swatch
		updateSwatch(toHex([@activeLamp.getValue("color_r").to_f, @activeLamp.getValue("color_g").to_f, @activeLamp.getValue("color_b").to_f]))			
	end
	
	def updateColorPicker()
		# get r, g, b values from current lamp object
		swatchColor = [@activeLamp.getValue("color_r").to_f, @activeLamp.getValue("color_g").to_f, @activeLamp.getValue("color_b").to_f] 
		swatchRRGGBB = toHex(swatchColor)			
						
		# set values in colorpicker RGB fields
		cmd1 = "init_rgb_fields(\"#{swatchColor[0]}\",\"#{swatchColor[1]}\",\"#{swatchColor[2]}\")"
        @color_picker.execute_script(cmd1)
			
		# set value for hidden field in color picker
		cmd2 = "init_color(\"#{swatchRRGGBB}\")"
        @color_picker.execute_script(cmd2)
	end

	def set_active_lamp(passedLamp)
		@activeLamp = passedLamp
	end

	def getLampCollection()
		return @lampCollection
	end
	
	def getLampObject(componentDefinition)
		# todo: make method also accept instances?
		# if componentDefinition.is_a? Sketchup::ComponentInstance
		#	componentDefinition = componentDefinition.definition
		# end
		return @lampCollection[componentDefinition]
	end

	def showLampDialog
		@lamp_dialog.show{} # note: code inserted in the show block will run when the dialog is initialized
		# note: interface will be updated by code that is called when the lamp editor html is loaded
	end

	def addLamp(componentDefinition, su2luxLampObject)
		puts "ADDING lamp #{su2luxLampObject.name} to lampCollection"
		puts componentDefinition
		@lampCollection[componentDefinition] = su2luxLampObject
		@lampsByName[su2luxLampObject.name] = su2luxLampObject
		for key in @lampsByName.keys
			print("@lampsByName key: " + key.to_s)
		end
	end
	
	def closeColorPicker
		if (@color_picker.visible?)
			@color_picker.close
		end
	end

	def close
		@lamp_dialog.close
	end
	
	def visible?
		return @lamp_dialog.visible?
	end
	

	
end # # END class LuxrenderLampEditor