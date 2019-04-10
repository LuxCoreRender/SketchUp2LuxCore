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
# Authors:      Abel Groenewolt (aka pistepilvi)
#               Alexander Smirnov (aka Exvion)  e-mail: exvion@gmail.com
#               Mimmo Briganti (aka mimhotep)


class LuxrenderRenderSettingsEditor

	attr_reader :render_settings_dialog
	alias_method :render_settings_editor, :render_settings_dialog
	##
	#
	##
	def initialize(scene_id, lrs)
        puts "initializing render settings editor"
        filename = File.basename(Sketchup.active_model.path)
        if (filename == "")
            windowname = "SU2LUX Render Settings Editor"
            else
            windowname = "SU2LUX Render Settings Editor - " + filename
        end
		@render_settings_dialog = UI::WebDialog.new(windowname, true, "LuxrenderEngineSettingsEditor", 450, 600, 480, 10, true)
        @render_settings_dialog.max_width = 800
        @render_settings_dialog.max_height = 3000
		setting_html_path = Sketchup.find_support_file("render_settings.html", File.join("Plugins", SU2LUX::PLUGIN_FOLDER))
		@render_settings_dialog.set_file(setting_html_path)
        @scene_id = scene_id
        @lrs = lrs
        @rendersettingkeys = @lrs.rendersettingkeys
        puts "finished initializing render settings editor"
        
		##
		#
		##
		@render_settings_dialog.add_action_callback("param_generate") {|dialog, params|
				#SU2LUX.dbg_p "param_generate run by render settings editor"
				pair = params.split("=")
				key = pair[0]		   
				value = pair[1]
                #puts key
                #puts value
				case key
                    when "renderpreset"
                        puts "render preset selected from dropdown"
                        @lrs.send('renderpreset=', value)
                        if (value!='custom')
                            @render_settings_dialog.execute_script('load_active_settings()')
                        end
                    else
						if (@lrs.respond_to?(key))
							# process key and new value
							method_name = key + "="
							if (value.to_s.downcase == "true")
								value = true
							end
							if (value.to_s.downcase == "false")
								value = false
							end
							@lrs.send(method_name, value)
						else
							# UI.messagebox "Parameter " + key + " does not exist. Please inform the developers."
							SU2LUX.dbg_p "Parameter " + key + " does not exist. Please report on the LuxRender forum."
						end
                    # set dropdown to custom
                    dialog.execute_script('$("#renderpreset").val("custom");')
				end	
		} #end action callback param_generatate

        ##
        #   SETTINGS FILE - OVERWRITE
        ##
        @render_settings_dialog.add_action_callback("overwrite_settings"){ |settingseditor, presetname|
            puts "exporting settings to existing file"
            settings_folder = SU2LUX.get_settings_folder
            settings_path = settings_folder + presetname +  ".lxp"
            outputfile = File.new(settings_path, "w") # "a" adds to file, "w" writes new file content
            @rendersettingkeys.each {|settingname|
                if (settingname==@rendersettingkeys.last)
                    outputfile << settingname + "," + @lrs.send(settingname).to_s
                    else
                    outputfile << settingname + "," + @lrs.send(settingname).to_s + "\n"
                end
            }
            outputfile.close
        }

        ##
        #   SETTINGS FILE - SAVE
        ##
        @render_settings_dialog.add_action_callback("export_settings"){ |settingseditor, params|
            puts "exporting settings to file"
            settings_folder = SU2LUX.get_settings_folder
            settings_path = UI.savepanel("Save as", settings_folder, ".lxp")
            outputfile = File.new(settings_path, "w") # "a" adds to file, "w" writes new file content
            @rendersettingkeys.each {|settingname|
                if (settingname==@rendersettingkeys.last)
                    outputfile << settingname + "," + @lrs.send(settingname).to_s
                else
                    outputfile << settingname + "," + @lrs.send(settingname).to_s + "\n"
                end
            }
            outputfile.close
            # add to dropdown
            settingsname = File.basename(settings_path,".lxp")
            addtodropdown = 'add_to_dropdown(\'' + settingsname + '\');'
            settingseditor.execute_script(addtodropdown)
            # set active
            setactivesettingsname = '$("#renderpreset").val("' + settingsname + '");'
            settingseditor.execute_script(setactivesettingsname)
        }

        ##
        #   SETTINGS FILE - LOAD
        ##
        @render_settings_dialog.add_action_callback("load_settings"){ |dialog, presetfile|
            puts "running load_settings"
            if (presetfile == "custom")
                next # break; nothing needs to be changed as custom is a temporary setting
            elsif (!presetfile || presetfile==false || presetfile=="false")
                # get file
                settings_folder = SU2LUX.get_settings_folder
                filepath = UI.openpanel("Open LuxRender settings file (.lxp)", settings_folder, "*")
                if(filepath)
                    inputfile = File.open(filepath, "r")
                else
                    next # break
                end
            else
                # use file as defined by dropdown
                filepath = File.join(SU2LUX.get_settings_folder, File.basename(presetfile)+".lxp")
                inputfile = File.open(filepath, "r")
            end
            puts "loading settings from file: " + presetfile
            # set value in @lrs
            inputfile.each_line do |line|
                cleanline = line.gsub(/\r/,"")
                cleanline = cleanline.gsub(/\n/,"")
                property = cleanline.split(",").first
                value = cleanline.split(",").last
                if (value == "true")
                    value = true
                end
                if (value == "false")
                    value = false
                end
                @lrs.send(property+"=",value)
            end
            inputfile.close
            
            # set value in dropdown menu, update settings interface values
            javascriptcommand = 'update_settings_dropdown("' + File.basename(filepath,".lxp") + '")'
            SU2LUX.dbg_p javascriptcommand
			dialog.execute_script(javascriptcommand)
        }

        ##
        #   SETTINGS FILE - DELETE
        ##
        @render_settings_dialog.add_action_callback("delete_settings"){ |dialog, presetfile|
            if (presetfile != "custom")
                puts "delete settings file"
                puts presetfile
                puts ""
                # delete file
                filepath = File.join(SU2LUX.get_settings_folder, File.basename(presetfile)+".lxp")
                File.delete(filepath)
                # remove value from dropdown menu, set to custom instead
                removecommand = '$("#renderpreset option:selected").remove();'
                puts dialog
                dialog.execute_script(removecommand)
                updatecommand = 'update_settings_dropdown("custom")'
                dialog.execute_script(updatecommand)
            else
                puts "custom settings selected, nothing to delete"
            end
        }

        ##
        #
        ##
        @render_settings_dialog.add_action_callback("display_loaded_presets") {|dialog, params|
            puts "running display_loaded_presets"
            self.sendDataFromSketchup
        }
		
		@render_settings_dialog.add_action_callback("reset_to_default") {|dialog, params|
			@lrs.reset
			self.close
			UI.start_timer(0.5, false) { self.show }
			# self.show
		}
        
        @render_settings_dialog.add_action_callback("render_setting_loaded") {|dialog, params|
            puts "adding preset files to dropdown menu"
            settings_folder = SU2LUX.get_settings_folder
            Dir.foreach(settings_folder) do |settingsfile|
                if File.extname(settingsfile)==".lxp"
                    settingsfile2 = File.basename(settingsfile, ".lxp").to_s
                    addtodropdown = 'add_to_dropdown(\'' + settingsfile2 + '\');'
                    dialog.execute_script(addtodropdown)
                end
            end
            
            # update interface according to saved values
            puts "loading render settings values"
            sendDataFromSketchup
            
        }
		
	end # END initialize

	##
	#
	##
	def show
		@render_settings_dialog.show{sendDataFromSketchup()}
	end # END show

	##
	#set parameters in inputs of engine_settings.html
	##
	def sendDataFromSketchup()
        puts "running sendDataFromSketchup from render settings editor"
		settings = @lrs.get_names_render
		settings.each { |setting|
            #puts ""
            #puts setting
            #puts @lrs.send(setting)
            #updateSettingValue(setting) 
			setValue(setting, @lrs[setting]) # gets setting from @lrs
			
		}
        # set setting areas based on dropdown settings
        subfield_categories = ["sampler_type", "sintegrator_type", "pixelfilter_type", "accelerator_type"]
        subfield_categories.each{|fieldname|
            update_subfield = 'update_subfield("' + fieldname + '")'
            #puts update_subfield
            @render_settings_dialog.execute_script(update_subfield)
        }
        # show/hide SPPM integrator field
        if (@lrs.renderer=="sppm")
            showintegrator='$("#sppm").show();'
            hideintegrator='$("#integratorsection").hide();'
        else
            showintegrator='$("#integratorsection").show();'
            hideintegrator='$("#sppm").hide();'
        
        end
        @render_settings_dialog.execute_script(hideintegrator)
        @render_settings_dialog.execute_script(showintegrator)
        
        # show preset name in dropdown value
        setdropdown = '$("#renderpreset").val("' + @lrs.renderpreset + '");'
        @render_settings_dialog.execute_script(setdropdown)

        
	end # END sendDataFromSketchup
	
	##
	#
	##
	#def is_a_checkbox?(id)#much better to use objects for settings?!
	#	#if @lrs[id] == true or @lrs[id] == false # or @lrs[id] == "true" or @lrs[id] == "false"
	#	if @lrs[id] == true or @lrs[id] == false # or @lrs[id] == "true" or @lrs[id] == "false"
	#		return id
	#	end
	#end # END is_a_checkbox?

	##
	#
	##
	def setValue(id,value) #extend to encompass different types (textbox, anchor, slider)
		# puts "updating value in render settings interface"
        new_value=value.to_s
		if(@lrs.send(id) == true or @lrs.send(id) == false)
		    #puts "updating checkbox: " + id + " is "
            #puts value.class
			cmd="$('##{id}').attr('checked', #{value});" #different asignment method
			# SU2LUX.dbg_p cmd
			@render_settings_dialog.execute_script(cmd)
			cmd="checkbox_expander('#{id}');"
			# SU2LUX.dbg_p cmd
			@render_settings_dialog.execute_script(cmd)
		######### -- other -- #############
		else
            #puts "updating other: " + id + " is "
            #puts value.class
			cmd="$('##{id}').val('#{new_value}');" #syntax jquery
			# SU2LUX.dbg_p cmd
			# cmd = "document.getElementById('#{id}').value=\"#{new_value}\""
			# SU2LUX.dbg_p cmd
			@render_settings_dialog.execute_script(cmd)
			#Horror coding?
			if(id == "camera_type")
				cmd="$('##{id}').change();" #syntax jquery
				@render_settings_dialog.execute_script(cmd)
			end
		end
		#############################
		
	end # END setValue

	##
	#
	##
	def updateSettingValue(id)
        #puts "updating setting: " + id
		setValue(id, @lrs[id])
	end # END updateSettingValue

	##
	#
	##
	def setCheckbox(id,value)
		#TODO
	end # END setCheckbox

	def close
		@render_settings_dialog.close
	end #END close
	
	def visible?
		return @render_settings_dialog.visible?
	end #END visible?
	
end # # END class LuxrenderRenderSettingsEditor