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


class LuxrenderSceneSettingsEditor

	attr_reader :scene_settings_dialog
	alias_method :scene_settings_editor, :scene_settings_dialog
	##
	#
	##
	def initialize(scene_id, lrs)
        puts "initializing scene settings editor"
        @scene_id = scene_id
        filename = File.basename(Sketchup.active_model.path)
        if (filename == "")
            windowname = "SU2LUX Scene Settings Editor"
            else
            windowname = "SU2LUX Scene Settings Editor - " + filename
        end
		@scene_settings_dialog = UI::WebDialog.new(windowname, true, "LuxrenderSceneSettingsEditor", 450, 600, 10, 10, true)
        @scene_settings_dialog.max_width = 700
		@scene_settings_dialog.max_height = 3000
		setting_html_path = Sketchup.find_support_file("scene_settings.html", File.join("Plugins", SU2LUX::PLUGIN_FOLDER))
		@scene_settings_dialog.set_file(setting_html_path)
        @lrs = lrs
        #puts "finished initializing scene settings editor"
        
		##
		#
		##
		@scene_settings_dialog.add_action_callback("param_generate") {|dialog, params|
				SU2LUX.dbg_p "settings editor param_generate"
				pair = params.split("=")
				key = pair[0]		   
				value = pair[1]
                #puts key
                #puts value
				case key
					#when "fov"
					#	Sketchup.active_model.active_view.camera.fov = value.to_f
					#when "focal_length"
					#	Sketchup.active_model.active_view.camera.focal_length = value.to_f
					when "fleximage_xresolution"
						@lrs.fleximage_xresolution=value.to_i
                        update_resolutions(key,value.to_i)
					when "fleximage_yresolution"
						@lrs.fleximage_yresolution=value.to_i
                        update_resolutions(key,value.to_i)
					when "export_luxrender_path"
						puts "LuxRender path modified, updating"
						SU2LUX.change_luxrender_path(value)
						@lrs.send(key + "=", value.dump.tr('"', ''))
						
                    else 
						if (@lrs.respond_to?(key))
                            #puts "@lrs responding"
							method_name = key + "="
							if (value.to_s.downcase == "true")
								value = true
                                #puts "value will be set to true"
							end
							if (value.to_s.downcase == "false")
								value = false
                                #puts "value will be set to false"
							end
							@lrs.send(method_name, value)
						else
							# UI.messagebox "Parameter " + key + " does not exist. Please inform the developers."
							SU2LUX.dbg_p "Parameter " + key + " does not exist. Please report on the LuxRender forum."
						end
				end
		} #end action callback param_generatate  
        
 		##
		#   RESOLUTION LOGIC
		##
		@scene_settings_dialog.add_action_callback("resolution_update_skp") { |dialog, params|
            #puts "updating resolution values"
            @lrs.aspectratio_type = "aspectratio_sketchup_view"
            cam = Sketchup.active_model.active_view.camera
            view = Sketchup.active_model.active_view
            cam.aspect_ratio = 0.0 # remove aspect ratio
            aspectratio = view.vpwidth.to_f/view.vpheight.to_f # get view proportion
            
            # calculate y resolution based on x resolution
            yres = (@lrs.fleximage_xresolution.to_i / aspectratio).round
            @lrs.fleximage_yresolution = yres
            
            # update y resolution field
            setyfield = '$("#fleximage_yresolution").val(' + yres.to_s + ');'
            dialog.execute_script(setyfield)
		}
        
        ##
		#   RESOLUTION LOGIC
		##
		@scene_settings_dialog.add_action_callback("remove_frame") { |dialog, params|
            cam = Sketchup.active_model.active_view.camera
            cam.aspect_ratio = 0.0 # remove aspect ratio
		}
        
        ##
        #   RESOLUTION LOGIC
        ##
        @scene_settings_dialog.add_action_callback("flip_aspect_ratio") { |dialog, orientation|
            # swap values
            @lrs.fleximage_xresolution, @lrs.fleximage_yresolution = [@lrs.fleximage_yresolution,@lrs.fleximage_xresolution]
            @lrs.aspectratio_numerator, @lrs.aspectratio_denominator = [@lrs.aspectratio_denominator,@lrs.aspectratio_numerator]
            
            # update values in interface
            setxfield = '$("#fleximage_xresolution").val(' + @lrs.fleximage_xresolution.to_s + ');'
            dialog.execute_script(setxfield)
            setyfield = '$("#fleximage_yresolution").val(' + @lrs.fleximage_yresolution.to_s + ');'
            dialog.execute_script(setyfield)
            setaspect1 = '$("#aspectratio_numerator").val(' + @lrs.aspectratio_numerator.to_s + ');'
            dialog.execute_script(setaspect1)
            setaspect2 = '$("#aspectratio_denominator").val(' + @lrs.aspectratio_denominator.to_s + ');'
            dialog.execute_script(setaspect2)
            
            # update aspect ratio
            cam = Sketchup.active_model.active_view.camera
            cam.aspect_ratio = @lrs.fleximage_xresolution.to_f/@lrs.fleximage_yresolution.to_f
		}
        
        ##
        #   RESOLUTION LOGIC
        ##
        @scene_settings_dialog.add_action_callback("swap_portrait_landscape") { |dialog, orientation|
            @lrs.aspectratio_fixed_orientation = orientation
            # swap values in @lrs
            @lrs.fleximage_xresolution, @lrs.fleximage_yresolution = [@lrs.fleximage_yresolution,@lrs.fleximage_xresolution]
            
            # update values in interface
            setxfield = '$("#fleximage_xresolution").val(' + @lrs.fleximage_xresolution.to_s + ');'
            dialog.execute_script(setxfield)
            setyfield = '$("#fleximage_yresolution").val(' + @lrs.fleximage_yresolution.to_s + ');'
            dialog.execute_script(setyfield)
            
            # update aspect ratio
            cam = Sketchup.active_model.active_view.camera
            cam.aspect_ratio = @lrs.fleximage_xresolution.to_f/@lrs.fleximage_yresolution.to_f
		}

        ##
		#   RESOLUTION LOGIC
		##
		@scene_settings_dialog.add_action_callback("resolution_update_free") { |dialog, params|
            @lrs.aspectratio_type = "aspectratio_free"
            cam = Sketchup.active_model.active_view.camera
            cam.aspect_ratio = 0.0 # remove aspect ratio
		}
        
        
        ##
		#   RESOLUTION LOGIC
		##
		@scene_settings_dialog.add_action_callback("set_frame") { |dialog, params|
            Sketchup.active_model.active_view.camera.aspect_ratio = @lrs.fleximage_xresolution.to_f/@lrs.fleximage_yresolution.to_f
		}
        
        ##
		#   RESOLUTION LOGIC
		##
		@scene_settings_dialog.add_action_callback("resolution_update_fixed") { |dialog, params|
            #puts "updating resolution values, fixed"
            #puts params
            @lrs.aspectratio_type = "aspectratio_fixed"
            @lrs.aspectratio_fixed_ratio = params.to_f
            cam = Sketchup.active_model.active_view.camera
            view = Sketchup.active_model.active_view
            
            if @lrs.aspectratio_fixed_orientation=="ratio_portrait"
                aspectratio = params.to_f
                xres = (@lrs.fleximage_yresolution.to_i * aspectratio).round
                @lrs.fleximage_xresolution = xres
                # update x resolution field
                setxfield = '$("#fleximage_xresolution").val(' + xres.to_s + ');'
                dialog.execute_script(setxfield)
                
            else # landscape
                aspectratio = 1/params.to_f
                # calculate y resolution based on x resolution
                yres = (@lrs.fleximage_xresolution.to_i / aspectratio).round
                @lrs.fleximage_yresolution = yres
                # update y resolution field
                setyfield = '$("#fleximage_yresolution").val(' + yres.to_s + ');'
                dialog.execute_script(setyfield)
            end
            cam.aspect_ratio = aspectratio
		}
        
        ##
		#
		##
		@scene_settings_dialog.add_action_callback("resolution_update_custom") { |dialog, params|
            #puts "updating resolution values, custom"
            @lrs.aspectratio_type = "aspectratio_custom"
            cam = Sketchup.active_model.active_view.camera
            view = Sketchup.active_model.active_view
            # note: using custom settings, a ratio of 2:3 is understood as a landscape orientation ratio
            aspectratio = @lrs.aspectratio_denominator.to_f/@lrs.aspectratio_numerator.to_f
            yres = (@lrs.fleximage_xresolution.to_i / aspectratio).round
            @lrs.fleximage_yresolution = yres
            # update y resolution field
            setyfield = '$("#fleximage_yresolution").val(' + yres.to_s + ');'
            dialog.execute_script(setyfield)
            cam.aspect_ratio = aspectratio
		}
        
		##
		#
		##
		@scene_settings_dialog.add_action_callback("camera_change") { |dialog, cameratype|
            # puts "previous camera type:"
            # puts @lrs.camera_type
            @lrs.camera_type = cameratype

            #if (cameratype != "environment")
            #    Sketchup.active_model.active_view.camera.perspective = (cameratype=='perspective')
            #end
		}
        
		##
		#
		##
		@scene_settings_dialog.add_action_callback("open_dialog") {|dialog, params|
			case params.to_s
				when "new_export_file_path"
					newPath = SU2LUX.new_export_file_path
					if(newPath)
						puts "new lxs path set"
						cmd = '$("#export_file_path").val("' + @lrs.export_file_path + '");'
						puts cmd
						@scene_settings_dialog.execute_script(cmd)
					end
				when "load_env_image"
					SU2LUX.load_env_image
                when "change_luxpath"
                    SU2LUX.change_luxrender_path
			end #end case
		} #end action callback open_dialog


        @scene_settings_dialog.add_action_callback("set_runtype") {|dialog, params|
            #puts params
            @lrs.runluxrender = params
            Sketchup.write_default("SU2LUX", "runluxrender", params.unpack('H*')[0])
        }
		
		@scene_settings_dialog.add_action_callback("reset_to_default") {|dialog, params|
			@lrs.reset
			self.close
			UI.start_timer(0.5, false) { self.show }
			# self.show
		}
		
		@scene_settings_dialog.add_action_callback("set_focal_distance"){|dialog, params|
			puts "running focus tool from scene settings editor"
			focusTest = FocusTool.new(@scene_id, @lrs)
			Sketchup.active_model.select_tool(focusTest)
			#puts "done running focus tool"
		}
        
        @scene_settings_dialog.add_action_callback("scene_setting_loaded"){|dialog,params|
            sendDataFromSketchup
        }
        
	end # END initialize

    ##
    #
    ##
    def update_resolutions(givenresolution,resolution)
        puts "calculating and updating resolution"
        cam = Sketchup.active_model.active_view.camera
        view = Sketchup.active_model.active_view
        dialog = @scene_settings_dialog
        case @lrs.aspectratio_type
            when "aspectratio_sketchup_view"
                #puts "aspectratio sketchup view"
                aspectratio = view.vpwidth.to_f/view.vpheight.to_f # get view proportion
                if givenresolution=="fleximage_xresolution"
                    yres = (@lrs.fleximage_xresolution.to_i / aspectratio).round
                    @lrs.fleximage_yresolution = yres
                    # update y resolution field
                    setyfield = '$("#fleximage_yresolution").val(' + yres.to_s + ');'
                    dialog.execute_script(setyfield)
                else
                    xres = (@lrs.fleximage_yresolution.to_i * aspectratio).round
                    @lrs.fleximage_xresolution = xres
                    # update x resolution field
                    setxfield = '$("#fleximage_xresolution").val(' + xres.to_s + ');'
                    dialog.execute_script(setxfield)
                end
            when "aspectratio_custom"
                #puts "custom aspect ratio"
                aspectratio = @lrs.aspectratio_numerator.to_f/@lrs.aspectratio_denominator.to_f
                if givenresolution=="fleximage_xresolution"
                    yres = (@lrs.fleximage_xresolution.to_i * aspectratio).round
                    @lrs.fleximage_yresolution = yres
                    # update y resolution field
                    setyfield = '$("#fleximage_yresolution").val(' + yres.to_s + ');'
                    dialog.execute_script(setyfield)
                else
                    xres = (@lrs.fleximage_yresolution.to_i /   aspectratio).round
                    @lrs.fleximage_xresolution = xres
                    # update y resolution field
                    setxfield = '$("#fleximage_xresolution").val(' + xres.to_s + ');'
                    dialog.execute_script(setxfield)
                end
            when "aspectratio_fixed"
                #puts "fixed aspect ratio"
                # get proportion
                aspectratio = 1.0
                if @lrs.aspectratio_fixed_orientation=="ratio_portrait"
                    aspectratio = @lrs.aspectratio_fixed_ratio
                else
                    aspectratio = 1.0/@lrs.aspectratio_fixed_ratio
                end
                puts aspectratio
                # main fixed aspect ratio code
                if givenresolution=="fleximage_xresolution"
                    yres = (@lrs.fleximage_xresolution.to_i / aspectratio).round
                    @lrs.fleximage_yresolution = yres
                    # update y resolution field
                    setyfield = '$("#fleximage_yresolution").val(' + yres.to_s + ');'
                    dialog.execute_script(setyfield)
                else
                    xres = (@lrs.fleximage_yresolution.to_i / aspectratio).round
                    @lrs.fleximage_xresolution = xres
                    # update x resolution field
                    setxfield = '$("#fleximage_xresolution").val(' + xres.to_s + ');'
                    dialog.execute_script(setxfield)
                end
            when "aspectratio_free"
                #puts "free aspect ratio"
                cam.aspect_ratio = @lrs.fleximage_xresolution/@lrs.fleximage_yresolution
        end
    end

	##
	#
	##
	def show
		@scene_settings_dialog.show{sendDataFromSketchup()}
	end # END show

	##
	#set parameters in inputs of scene_settings.html
	##
	def sendDataFromSketchup()
        puts "running sendDataFromSketchup from scene settings editor"
		@lrs.fleximage_xresolution = Sketchup.active_model.active_view.vpwidth unless @lrs.fleximage_xresolution
		@lrs.fleximage_yresolution = Sketchup.active_model.active_view.vpheight unless @lrs.fleximage_yresolution
		settings = @lrs.get_names_scene
		settings.each { |setting|
            #puts ""
            #puts setting
            #puts @lrs.send(setting)
            updateSettingValue(setting) # gets setting from @lrs
		}
        #  update interface for resolution section
        updateResolutionGUI()
        if (@lrs.aspectratio_type == "aspectratio_fixed")
            setFixedResValue(@lrs.aspectratio_fixed_ratio)
        end
        
        # update subsections based on active dropdown values
        @scene_settings_dialog.execute_script('update_subfield("environment_light_type")')
        @scene_settings_dialog.execute_script('update_boxfield("use_environment_infinite_sun")')
        @scene_settings_dialog.execute_script('update_subfield("fleximage_colorspace_wp_preset")')
        @scene_settings_dialog.execute_script('update_subfield("fleximage_tonemapkernel")')
        @scene_settings_dialog.execute_script('update_subfield("fleximage_render_time")')
        
        
	end # END sendDataFromSketchup
	
    def updateResolutionGUI()
        puts "updating resolution interface"
        resolution_fields = ["aspectratio_sketchup_view","aspectratio_custom","aspectratio_fixed"]
        resolution_fields.each {|currentfield|
            hide_resolution_field = '$("#' + currentfield + '").hide();'
            @scene_settings_dialog.execute_script(hide_resolution_field)
        }
        case @lrs.aspectratio_type
        when "aspectratio_sketchup_view"
            show_resolution_field = '$("#aspectratio_sketchup_view").show();'
            @scene_settings_dialog.execute_script(show_resolution_field)
            if @lrs.aspectratio_skp_res_type=="aspectratio_skp_view"
                hide_resolution_field = '$("#aspectratio_resolution_interface").hide();'
                @scene_settings_dialog.execute_script(hide_resolution_field)
            end
        when "aspectratio_custom"
            show_resolution_field = '$("#aspectratio_custom").show();'
            @scene_settings_dialog.execute_script(show_resolution_field)
        when "aspectratio_free"
        else # fixed aspect ratio
            show_resolution_field = '$("#aspectratio_fixed").show();'
            @scene_settings_dialog.execute_script(show_resolution_field)
        end
        #puts "finished running sendDataFromSketchup (from settings editor)"
    end
    
    def setFixedResValue(proportion)
        #puts "UPDATING SETTINGS WINDOW RESOLUTION ASPECT RATIO TYPE"
        set_dropdown = '$("#aspectratio_type").val("' + proportion.to_s + '");'
        #puts set_dropdown
        @scene_settings_dialog.execute_script(set_dropdown)
    end
    
    
	##
	#
	##
	#def is_a_checkbox?(id)#much better to use objects for settings?!
	#	if @lrs[id] == true or @lrs[id] == false # or @lrs[id] == "true" or @lrs[id] == "false"
	#		return id
	#	end
	#end # END is_a_checkbox?

	##
	#
	##
	def setValue(id,value) # update parameter values in scene settings dialog
        # puts "setting value in scene settings interface"
		new_value=value.to_s
		if (id == "export_file_path")
            #SU2LUX.dbg_p new_value
			new_value.gsub!(/\\\\/, '/') #bug with sketchup not allowing \ characters
			new_value.gsub!(/\\/, '/') if new_value.include?('\\')
			cmd="$('##{id}').val('#{new_value}');" #different asignment method
			# SU2LUX.dbg_p cmd
			@scene_settings_dialog.execute_script(cmd)
		elsif (@lrs.send(id) == true or @lrs.send(id) == false) # check box
            #puts "updating checkbox: " + id + " is "
            #puts value.class
			cmd="$('##{id}').attr('checked', #{value});" #different asignment method
			#SU2LUX.dbg_p cmd
			@scene_settings_dialog.execute_script(cmd)
			cmd="checkbox_expander('#{id}');"
			# SU2LUX.dbg_p cmd
			@scene_settings_dialog.execute_script(cmd)
		elsif  (id == "export_luxrender_path")
			puts "luxrender path: " + value
			#puts value.dump.tr('"', '')
			cmd="$('##{id}').val('#{value.dump.tr('"', '')}');" #syntax jquery
			@scene_settings_dialog.execute_script(cmd)
		else
            #puts "updating other: " + id + " is "
            #puts value.class
			cmd="$('##{id}').val('#{new_value}');" #syntax jquery
			# SU2LUX.dbg_p cmd
			@scene_settings_dialog.execute_script(cmd)
			#Horror coding?
			if(id == "camera_type")
				cmd="$('##{id}').change();" #syntax jquery
				@scene_settings_dialog.execute_script(cmd)
			end
		end
	end # END setValue

	##
	#
	##
	def updateSettingValue(id)
        # puts "updating setting: " + id
		setValue(id, @lrs[id])
	end # END updateSettingValue

	def close
		@scene_settings_dialog.close
	end #END close
	
	def visible?
		return @scene_settings_dialog.visible?
	end #END visible?
	
end # # END class LuxrenderSceneSettingsEditor