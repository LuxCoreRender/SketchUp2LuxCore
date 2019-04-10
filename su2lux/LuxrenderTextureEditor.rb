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
# Authors      : Alexander Smirnov (aka Exvion)  e-mail: exvion@gmail.com
#                Mimmo Briganti (aka mimhotep)

class LuxrenderTextureEditor

	
	def initialize(texture_data, lux_parameter, scene_id) # lux_parameter is texture type, for example "kd"
        puts "creating new texture editor"
		@texture_editor_dialog = UI::WebDialog.new("SU2LUX Texture Editor", true, "LuxrenderTextureEditor", 600, 322, 900, 400, true)
		texture_editor_dialog_path = Sketchup.find_support_file("TextureEditor.html", File.join("Plugins","su2lux"))
		@texture_editor_dialog.max_width = 800
		@texture_editor_dialog.max_height = 3000
		@texture_editor_dialog.set_file(texture_editor_dialog_path)

		@texture_data = texture_data
		@lux_parameter = lux_parameter
        @scene_id = scene_id
		material_editor = SU2LUX.get_editor(@scene_id,"material")
		@current = material_editor.current

		@texture_editor_dialog.add_action_callback('param_generate') {|dialog, params|
			# Get the data from the Webdialog.
			parameters = string_to_hash(params)
			lux_material = @current
			parameters.each{ |k, v|
					if (v.to_s.downcase == "true")
						v = true
					end
					if (v.to_s.downcase == "false")
						v = false
					end
					@texture_data[k] = v
					p k+v.to_s
			}
		}
				
		@texture_editor_dialog.add_action_callback("open_dialog") {|dialog, params|
			data = params.to_s
			material = Sketchup.active_model.materials.current
			lux_material = @current
			SU2LUX.load_image("Open image", lux_material, data, @lux_parameter)
			#puts "compound name:"
			#puts @lux_parameter
			#puts data
			@texture_data[data] = lux_material.send(@lux_parameter + '_' +  data)
			updateSettingValue(data, @lux_parameter) # removed  + '_'
			# UI.messagebox @texture_data[data]
			self.show_image(@texture_data[data])
			
		} #end action callback open_dialog
        
        
		
		@texture_editor_dialog.add_action_callback('material_changed') { |dialog, material_name|
			puts "material_changed triggered"
            materials = Sketchup.active_model.materials
			@current = self.find(material_name)
			#SU2LUX.dbg_p "texture editor reports that material has changed: #{materials.current.name}"
			if (material_name != materials.current.name)
				if(materials[material_name] == nil)
					puts "could not find LuxRender material named " + material_name
				else
					materials.current = materials[material_name] if ( ! @current.nil?)
				end
			end
		}
		
		@texture_editor_dialog.add_action_callback("reset_to_default") {|dialog, params|
			materials = Sketchup.active_model.materials
			for mat in materials
				luxmat = self.find(mat.name)
				luxmat.reset
			end
			self.close
			UI.start_timer(0.5, false) { self.show }
			# self.show
		}

		@texture_editor_dialog.add_action_callback("update_changes") {|dialog, params|
            puts "setting texture"
			lux_material = @current
			@texture_data.each {|method_name, value|
				lux_material.send(@lux_parameter + '_' + method_name + "=", value)
			}
			has_texture = ! (lux_material.send(@lux_parameter + '_' + 'imagemap_filename')).empty?
            
            # update image path text in material editor
            material_editor.update_texture_name(lux_material, @lux_parameter)
			self.close
		}
	
		@texture_editor_dialog.add_action_callback("cancel_changes") {|dialog, params|
			self.close
		}
	
	end # end initialize

	##
	# Takes a string like "key1=value1,key2=value2" and creates an hash.
	##
	def string_to_hash(string)
		hash = {}
		datapairs = string.split('|')
		datapairs.each { |datapair|
			data = datapair.split('=')
			hash[data[0]] = data[1]
		}
		return hash
	end

	##
	#
	##	
	def show
        SU2LUX.dbg_p "running texture editor show function"
		@texture_editor_dialog.show_modal{refresh()}
	end

	##
	#
	##
	def refresh()
        SU2LUX.dbg_p "running texture editor refresh function"
		self.sendDataFromSketchup()
	end
	
	##
	#set parameters in inputs of settings.html
	##
	def sendDataFromSketchup()
		@texture_data.each { |setting, value|
			updateSettingValue(setting, @lux_parameter + '_')
		}
		self.show_image(@texture_data['imagemap_filename'])
	end # END sendDataFromSketchup
	
	##
	#
	##
	#def is_a_checkbox?(id) #much better to use objects for settings?!
	#	lux_material = @current
	#	if lux_material[id] == true or lux_material[id] == false
	#		return id
	#	end
	#end # END is_a_checkbox?

	##
	#
	##
	def setValue(id, value) #extend to encompass different types (textbox, anchor, slider)
        #puts "setting value:"
        #puts id
        #puts value
		new_value=value.to_s
		if(@current[id] == true or @current[id] == false)
			# checkbox 
			self.fire_event("##{id}", "attr", "checked=#{value}")
			cmd="checkbox_expander('#{id}');"
			@texture_editor_dialog.execute_script(cmd)
			cmd = "$('##{id}').next('div.collapse').find('select').change();"
			@texture_editor_dialog.execute_script(cmd)	
		else
			# not a checkbox
			self.fire_event("##{id}", "val", new_value)
			# cmd="$('##{id}').val('#{new_value}');"
			# @texture_editor_dialog.execute_script(cmd)
		end
	end # END setValue

	##
	#
	##
	def updateSettingValue(id, prefix)
		lux_material = @current
		setValue(id, lux_material[prefix + id]) if lux_material.respond_to?(prefix + id)
	end # END updateSettingValue

	def fire_event(object, event, parameters)
		cmd = ""
		case event
			when "change"
				cmd = "$('#{object}').#{event}();"
			when "val"
				cmd = "$('#{object}').val('#{parameters}');"
			when "attr"
				params = string_to_hash(parameters)
				params.each{ |key, value|
					cmd << "$('#{object}').attr('#{key}', '#{value}');"
					# UI.messagebox cmd
				}
		end
		@texture_editor_dialog.execute_script(cmd)
	end

	##
	#
	##
	def show_image(path)
		self.fire_event("#texture_preview", "attr", "src=#{path}")
		
	end
	
	def close
		@texture_editor_dialog.close
	end
	
	def visible?
		return @texture_editor_dialog.visible?
	end
	
end #end class LuxrenderMaterialEditor