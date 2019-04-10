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

class LuxrenderVolumeEditor

	attr_reader :volume_dialog
	##
	#
	##
	def initialize(mat_editor, lrs)
		@volumeDictionary = LuxrenderAttributeDictionary.new(Sketchup.active_model)
		@volumeCollection = {} # hash containing volume names and objects
		@activeVolume = nil
        @lrs = lrs
		@material_editor = mat_editor
		
        puts "initializing volume editor"
        filename = File.basename(Sketchup.active_model.path)
        if (filename == "")
            windowname = "LuxRender Volume Editor"
        else
            windowname = "LuxRender Volume - " + filename
        end
		
		if(@lrs.volumeNames != nil)
			#puts "processing " + @lrs.volumeNames.size.to_s + " volumes"
			for volumeName in @lrs.volumeNames
				#puts "volume found in @lrs: " + volumeName
				volume = LuxrenderVolume.new(false, self, @material_editor, @lrs, volumeName)
			end	
		end		
		
		@volume_dialog = UI::WebDialog.new(windowname, true, "LuxrenderVolumeEditor", 450, 600, 10, 10, true)
        @volume_dialog.max_width = 700
        @volume_dialog.max_height = 3000
		setting_html_path = Sketchup.find_support_file("VolumeEditor.html", File.join("Plugins", SU2LUX::PLUGIN_FOLDER))
		@volume_dialog.set_file(setting_html_path)
		
		#puts "adding volumes to GUI"
		for volume in @volumeCollection.values
			volume.addToGUI()
		end		
		
		

		@color_picker = UI::WebDialog.new("Color Picker - volume", false, "ColorPicker", 410, 200, 200, 350, true)
        color_picker_path = Sketchup.find_support_file("colorpicker.html", File.join("Plugins", "su2lux"))
        @color_picker.set_file(color_picker_path)
		
        #puts "finished initializing volume editor"

	   # callbacks for javascript functions

		##
		#	create new volume by pressing 'new' button	
		##	
		
		@volume_dialog.add_action_callback('create_volume') {|dialog|
			puts "creating new volume"
			
			# ask for name, proposing one that is free
			generatedName = ""
			nameFree = false
			volNumber = 0
			while(nameFree == false)
				volNumber += 1
				generatedName = "volume_" + volNumber.to_s
				if(@volumeCollection[generatedName] == nil)
					nameFree = true
				end
			end
			
			volumeName = UI.inputbox(["volume name"], [generatedName], "Enter new volume name")
			
			if(volumeName != false)
				# check if name exists
				nameExists = false
				if (@volumeCollection[volumeName[0]] != nil)
					nameExists = true
				end
				
				# create volume object, or warn user of duplicate name
				if(!nameExists)
					puts "creating volume with name " + volumeName[0]
					# create a volume object
					volumeObject = LuxrenderVolume.new(true, self, @material_editor, @lrs, volumeName[0])
				
					# add volume to dropdown 
					@volume_dialog.execute_script('addToVolumeList("' + volumeName[0] + '")')
				
					# show volume type chooser in interface	
					@volume_dialog.execute_script('$("#volume_type_area").show()')			
				
					# show relevant parameters in interface
					@volume_dialog.execute_script('showParameterSections("' + volumeObject.getValue("volume_type")  +  '")')
					volumeObject.addToGUI
				
					# get parameter values from object and show in interface
					updateParams(volumeObject)
				else
					UI.messagebox("Volume name exists already, please choose a different name")
				end
			end
		}
		
		##
		#	show information in GUI after opening it
		##
		
		@volume_dialog.add_action_callback('update_GUI') {|dialog, paramString|
			#puts "update_GUI callback"
			update_GUI()
		}

		##
		#	pass on changed parameter from interface to dictionary
		##
		@volume_dialog.add_action_callback('set_param') {|dialog, paramString|
            SU2LUX.dbg_p "callback: set_param"
			#puts paramString # volumeName|parameterName|parameterValue
			params = paramString.split('|')
			volObject = @volumeCollection[params[0]]
			volObject.setValue(params[1],params[2])
		}

		##
		#	update texture type: update texture type in dictionary and get values from dictionary
		##
		@volume_dialog.add_action_callback('update_volume_type') {|dialog, paramString|
            SU2LUX.dbg_p "callback: update volume type"
			#puts paramString # homogeneous|volume01
			
			params = paramString.split('|')
			volumeObject = @volumeCollection[params[1]]
			#puts "volumeObject is " + volumeObject.to_s
			
			# store texture type in material
			puts "storing volume type"
			volumeObject.setValue("volume_type",params[0])
			puts "getTexType " + volumeObject.getValue("volume_type")
			
			# get values from object, show in interface
			puts "updating parameters in interface"
			updateParams(volumeObject)
		}

		@volume_dialog.add_action_callback('display_volume') {|dialog, paramString|
			#puts "volume selected, displaying interface"
			# get volume object
			volumeObject = @volumeCollection[paramString]
			# set as active volume
			setActiveVolume(volumeObject)
			
			# set texture type dropdown
			volumeType = volumeObject.getValue("volume_type")
			puts "setting dropdown to " + volumeType
			@volume_dialog.execute_script("$('#volume_type').val('" + volumeType +"');")
			
			# show relevant parameters in interface
			@volume_dialog.execute_script('showParameterSections("' + volumeType  +  '")')
			
			# get parameter values from object and show in interface
			updateParams(volumeObject)
		}
		
		@volume_dialog.add_action_callback('open_color_picker') { |dialog, param|
            SU2LUX.dbg_p "opening color picker window for volume editor"
            @lrs.colorpicker_volume = param
			updateColorPicker() # for OS X
            @color_picker.show
        }
		
		@color_picker.add_action_callback('provide_color') { |dialog, passedcolor|
			#puts "volume editor callback passing colour to colour picker init_color command"		
			if(@activeVolume)
				updateColorPicker() # for Windows
			end
		}
		
		##
		#	react to colour picker colour changes		
        ##
        @color_picker.add_action_callback('pass_color') { |dialog, passedColor| # passedcolor is in #ffffff form
			#puts "volume editor color picker callback: pass_color"
            passedColor="#000000" if passedColor.length != 7 # color picker may return NaN when mouse is dragged outside window
			updateSwatch(passedColor)
			
			# convert #RRGGBB to three float values in range 0 - 1
			rvalue = (passedColor[1, 2].to_i(16).to_f*1000000/255.0).round/1000000.0 # ruby 1.8 doesn't support round(6)
            gvalue = (passedColor[3, 2].to_i(16).to_f*1000000/255.0).round/1000000.0
            bvalue = (passedColor[5, 2].to_i(16).to_f*1000000/255.0).round/1000000.0
			
			# update value in volume object
			@activeVolume.setValue(@lrs.colorpicker_volume, [rvalue,gvalue,bvalue])
        }
		
		@color_picker.add_action_callback('colorfield_red_update') { |dialog, colorValue|
			#puts "volume editor callback: updating red channel"
			# get value from object, then reconstruct
			channelColor = @activeVolume.getValue(@lrs.colorpicker_volume)
			channelColor[0] = colorValue.to_f
			updateSwatch(toHex(channelColor))
			@activeVolume.setValue(@lrs.colorpicker_volume, channelColor)
		}
		
		@color_picker.add_action_callback('colorfield_green_update') { |dialog, colorValue|
			#puts "volume editor callback: updating green channel"
			# get value from object, then reconstruct
			channelColor = @activeVolume.getValue(@lrs.colorpicker_volume)
			channelColor[1] = colorValue.to_f
			updateSwatch(toHex(channelColor))
			@activeVolume.setValue(@lrs.colorpicker_volume, channelColor)
		}	
		
		@color_picker.add_action_callback('colorfield_blue_update') { |dialog, colorValue|
			#puts "volume editor callback: updating blue channel"
			# get value from object, then reconstruct
			channelColor = @activeVolume.getValue(@lrs.colorpicker_volume)
			channelColor[2] = colorValue.to_f
			updateSwatch(toHex(channelColor))
			@activeVolume.setValue(@lrs.colorpicker_volume, channelColor)
		}

	end # END initialize


	def update_GUI()
		for volumeName in @volumeCollection.keys
			#puts "adding " + volumeName
			@volume_dialog.execute_script('addToVolumeList("' + volumeName + '")')
		end
		
		if(@volumeCollection.keys.size > 0)
			#puts 'updating volume editor interface'
			# pick a volume object
			displayVolumeName = @volumeCollection.keys[0]
			displayVolumeObject = @volumeCollection[displayVolumeName]
			displayVolumeType = displayVolumeObject.getValue("volume_type")
			
			#puts displayVolumeType
			
			# set object name in dropdown
			@volume_dialog.execute_script('$("#volumes_in_model").val("' + displayVolumeName + '");')
			
			# show volume type area
			@volume_dialog.execute_script('$("#volume_type_area").show();')
			
			# set type
			@volume_dialog.execute_script('$("#volume_type").val("' + displayVolumeType + "')")
			
			# show parameters areas
			# load parameters
			@volume_dialog.execute_script('showParameterSections("' + displayVolumeType  +  '")')
			
			# get parameter values from object and show in interface
			updateParams(displayVolumeObject)
		end
		
	end

	def updateSwatch(hexColor)
		updateSwatchCmd = "$('#" + @lrs.colorpicker_volume + "').css('background-color', '" + hexColor + "');"			
		@volume_dialog.execute_script(updateSwatchCmd)
	end
	
	
	def toHex(listRGB)
		#puts "toHex in:"
		#puts listRGB
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
		#puts "toHex out:"
		#puts ("#" + rval + gval + bval)
		return ("#" + rval + gval + bval)
	end


	##
	#	update parameters in interface
	##
	
	def updateParams(volumeObject)
		varValues = volumeObject.getValueHash()
		varValues.each do |key, value|
			# update parameter in interface using jQuery command
			cmd = '$("#' + key + '").val("' + value[1].to_s + '")'
			#puts cmd
			@volume_dialog.execute_script(cmd)
		end
		
		if(varValues["volume_type"][1] != "clear")
			# set scattering swatch
			@lrs.colorpicker_volume = "vol_scattering_swatch"
			#puts varValues
			swatchColor = varValues["vol_scattering_swatch"][1]
			updateSwatch(toHex(swatchColor))
		end
		
		# set absorption swatch
		@lrs.colorpicker_volume = "vol_absorption_swatch"
		swatchColor = varValues["vol_absorption_swatch"][1]
		updateSwatch(toHex(swatchColor))
			
	end
	
	def updateColorPicker()
		# get r, g, b values from current swatch
		swatchColor = @activeVolume.getValue(@lrs.colorpicker_volume)
		swatchRRGGBB = toHex(swatchColor)			
			
		# set values in colorpicker RGB fields
		cmd1 = "init_rgb_fields(\"#{swatchColor[0]}\",\"#{swatchColor[1]}\",\"#{swatchColor[2]}\")"
        @color_picker.execute_script(cmd1)
			
		# set value for hidden field in color picker
		cmd2 = "init_color(\"#{swatchRRGGBB}\")"
        @color_picker.execute_script(cmd2)
	end

	def setActiveVolume(passedVolume)
		@activeVolume = passedVolume
	end
	
	def getVolumeDictionary()
		return @volumeDictionary
	end

	def getVolumeCollection()
		return @volumeCollection
	end
	
	def getVolumeObject(objectName)
		return @volumeCollection[objectName]
	end

	def showVolumeDialog
		#puts "number of volumes in model: " + @volumeCollection.length.to_s
		@volume_dialog.show{} # note: code inserted in the show block will run when the dialog is initialized
		#puts "number of volumes in model: " + @volumeCollection.length.to_s
		# note: interface will be updated by code that is called when the volume editor html is loaded
	end

	def addVolume(name, volumeObject)
		#puts "ADDING VOLUME TO volumeCollection"
		#puts name
		#puts volumeObject
		@volumeCollection[name] = volumeObject
	end
	
	def closeColorPicker
		if (@color_picker.visible?)
			@color_picker.close
		end
	end

	def close
		@volume_dialog.close
	end
	
	def visible?
		return @volume_dialog.visible?
	end
	

	
end # # END class LuxrenderSceneSettingsEditor