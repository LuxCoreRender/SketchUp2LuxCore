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

class LuxrenderMaterialEditor

	attr_accessor :current, :matname_changed, :materials_skp_lux, :material_editor_dialog
    attr_reader :material_editor_dialog
	
	def initialize(scene_id, lrs, model = Sketchup.active_model)
        puts "initializing material editor"
		startTime_material_editor = Time.new
		
        @scene_id = scene_id
		@model = model
		@lrs = lrs
        @materials_skp_lux = Hash.new
		@matname_changed = false
        filename = File.basename(Sketchup.active_model.path)
        if (filename == "")
            windowname = "SU2LUX Material Editor"
        else
            windowname = "SU2LUX Material Editor - " + filename
        end
		@material_editor_dialog = UI::WebDialog.new(windowname, true, "LuxrenderMaterialEditor", 424, 700, 960, 10, true)
		material_editor_dialog_path = Sketchup.find_support_file("materialeditor.html", File.join("Plugins", "su2lux"))
		@material_editor_dialog.max_width = 800
        @material_editor_dialog.max_height = 3000
		@material_editor_dialog.set_file(material_editor_dialog_path)
	    @collectedmixmaterials = []
        @collectedmixmaterials_i = 0
        
        @color_picker = UI::WebDialog.new("Color Picker - material", false, "ColorPicker", 410, 200, 200, 350, true)
        color_picker_path = Sketchup.find_support_file("colorpicker.html", File.join("Plugins", "su2lux"))
        @color_picker.set_file(color_picker_path)
		@texture_editor_data = {}
        
        @numberOfLuxMaterials = 0
        
		#puts "material editor initialisation processing materials:"
        for mat in Sketchup.active_model.materials
			#puts mat.name
            luxmat = self.find(mat.name) # adds material to materials_skp_lux
            get_skp_color(mat, luxmat)
			get_skp_texture(mat, luxmat)
        end
        
		elapsed_seconds = (Time.new - startTime_material_editor).to_int
        puts "material editor initialised in " + elapsed_seconds.to_s + ' seconds'
		
		@material_editor_dialog.add_action_callback('param_generate') {|dialog, params|
            SU2LUX.dbg_p "callback: param_generate"
			parameters = string_to_hash(params) # converts data passed by webdialog to hash

			material = Sketchup.active_model.materials.current
			lux_material = @current
			parameters.each{ |k, v|
				if (lux_material.respond_to?(k))
                    #puts "setting " + k.to_s + " to " + v.to_s + " for " + @current.to_s
					method_name = k + "="
					if (v.to_s.downcase == "true")
						v = true
					end
					if (v.to_s.downcase == "false")
						v = false
					end
					lux_material.send(method_name, v) # updates values in material
					case
						when (k.match(/^kd_.$/) and !material.texture) # changing diffuse color, updating SketchUp material colour accordingly
                            #puts "updating diffuse color"
                            # puts "lux_material.color: ", lux_material.color # debugging
							red = (lux_material['kd_R'].to_f * 255.0).to_i
                            green = (lux_material['kd_G'].to_f * 255.0).to_i
                            blue = (lux_material['kd_B'].to_f * 255.0).to_i
                            material.color = Sketchup::Color.new(red, green, blue)
                        when (k.match(/_R/) || k.match(/_G/) || k.match(/_B/))
                            puts "updating color channel"
                            update_swatches()
					end
                end
                if (v == "imagemap")
                    puts "updating text"
                    textype = k.dup
                    textype.slice!("_texturetype")
                    update_texture_name(lux_material, textype)
                end 
			}
                
			parameter_name = params.split('=')[0]
			if(parameter_name.include? "_texturetype")
				if (@lrs.proceduralTextureNames != nil && @lrs.proceduralTextureNames.size > 0)
					# check material's procedural texture; if it doesn't have one, set it to the first texture in the list
					procedural_texture_dropdown_name = parameter_name.sub("_texturetype", "") + "_imagemap_proctex"
					if(@current[procedural_texture_dropdown_name] == nil || @current[procedural_texture_dropdown_name] == "")		
					@current.send(procedural_texture_dropdown_name + "=", @lrs.proceduralTextureNames[0])
				end
				
				# set right procedural texture in dropdown for active channel in material editor
				cmd = "$('#procedural_texture_dropdown_name').val('" + @current[procedural_texture_dropdown_name] + "');"
				@material_editor_dialog.execute_script(cmd)		
				end
			end
		}
		
		@material_editor_dialog.add_action_callback("clear_IES") {|dialog, params|
			puts "clear callback responding"
			# set IES value 	
			@current.send("ies_path=", "")
			# update IES value in material interface
            cmd = "$('#ies_path').val('');"
            @material_editor_dialog.execute_script(cmd)				
		}
		
		#@material_editor_dialog.add_action_callback("set_procedural_texture"){|dialog, parameter_name|
		#	# note: parameter_name contains name of "parent" dialog, e.g. "set_procedural_texture"
		#	# if we have procedural textures, set dropdown to the right one
		#	puts "set_procedural_texture callback"
		#	if (@lrs.proceduralTextureNames != nil && @lrs.proceduralTextureNames.size > 0)
		#		puts "set_procedural_texture: setting procedural texture"
		#		# check material's procedural texture; if it doesn't have one, set it to the first texture in the list
		#		procedural_texture_dropdown_name = parameter_name.sub("_texturetype", "") + "_imagemap_proctex"
		#		if(@current[procedural_texture_dropdown_name] == nil || @current[procedural_texture_dropdown_name] == "")		
		#			puts "set_procedural_texture: no previous texture set"
		#			@current.send(procedural_texture_dropdown_name + "=", @lrs.proceduralTextureNames[0])
		#		end
		#		
		#		# set right procedural texture in dropdown for active channel in material editor
        #	     cmd = "$('#procedural_texture_dropdown_name').val('" + @current[procedural_texture_dropdown_name] + "');"
        #	     @material_editor_dialog.execute_script(cmd)		
		#	end
		#}
	
		@material_editor_dialog.add_action_callback("select_IES") {|dialog, params|
			puts "select_IES callback responding"
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
				@current.send("ies_path=", newIESpath)
				# update IES value in material interface
                cmd = "$('#ies_path').val('" + newIESpath + "');"
                @material_editor_dialog.execute_script(cmd)				
			end
		}
		
		@material_editor_dialog.add_action_callback("open_dialog") {|dialog, params|
            SU2LUX.dbg_p "callback: open_dialog"
			data = params.to_s
			material = Sketchup.active_model.materials.current
			lux_material = @current
			SU2LUX.load_image("Open image", lux_material, data, '')
		} #end action callback open_dialog
        
		@material_editor_dialog.add_action_callback("material_changed") { |dialog, material_name|
            materials = Sketchup.active_model.materials
            puts ("callback: material_changed, changing from material " + materials.current.name + " to " + material_name)
			
			# find material object for selected material
			existingluxmat = "none"
			@materials_skp_lux.values.each {|value| 
				# puts "checking material name ", value.name
				if value.name == material_name #.delete("[<>]")
					existingluxmat = value
				end
			}
			
			# set current material to found material, or if no material object was found, to a new material object
			if existingluxmat == "none"
				puts "LuxRender material not found, creating new material"
				@current = self.find(material_name) ### use only this line if testing fails
			else
				puts "reusing LuxRender material"
				@current = existingluxmat
			end
			
			# if no material is selected in SketchUp, set a material as the active material 
			# note: should this be set to the selected material instead of the first material in the list?
			if(materials.current == nil || materials.current == false)
				materials.current = materials[0]
			end
			
			# reload existing material preview image
			#puts "attempting to reload material preview image"
			load_preview_image()
            #puts @current.name
			
			# update material parameters
			sendDataFromSketchup() # updates parameter values
			# get material type, set relevant fields through javascript
            @material_editor_dialog.execute_script('show_fields("' + @current.type + '")')
			# update swatches, texture names
			update_swatches()
			showhide_fields
            set_texturefields(@current.name)
			update_texture_names(@current)
			
		}
        
        def set_texturefields(skpmatname) # shows and hides texture load buttons, based on material properties
            puts "updating texture fields"
            luxmat = getluxmatfromskpname(skpmatname)
            channels = luxmat.texturechannels
            #puts channels
            for channelname in channels
                textypename = channelname + "_texturetype" # for example "kd_texturetype"\
                # hide texture fields
                cmd = "$('#" + textypename + "').nextAll('span').hide();"
                @material_editor_dialog.execute_script(cmd)
                cmd = "$('#" + textypename + "').nextAll('div').hide();"
                @material_editor_dialog.execute_script(cmd)
                # show active texture fields
                activetexturetype = luxmat.send(textypename)
                cmd = "$('#" + textypename + "').nextAll('." + activetexturetype + "').show()";
                @material_editor_dialog.execute_script(cmd)
                
                # set colorize checkboxes
                colorizename = channelname + "_imagemap_colorize" # for example kd_imagemap_colorize
                colorizeon = (@current.send(colorizename))? "true":"false"
                cmd = "$('." + colorizename + "\').attr('checked', " + colorizeon + ");"
                @material_editor_dialog.execute_script(cmd)
            end
            
            # hide carpaint diffuse section for presets
            if (@current.type == "carpaint" && @current.carpaint_name != "")
                puts "hiding carpaint diffuse field"
                hidediffusecommand = "$('#diffuse').hide();"
                @material_editor_dialog.execute_script(hidediffusecommand)
            end
            
            # show proper auto alpha values
            if (@current.aa_texturetype=="imagealpha" || @current.aa_texturetype=="imagecolor")
                #puts "SHOWING AUTO ALPHA BUTTONS"
                cmd = '$("#autoalpha_image_field").show()';
                @material_editor_dialog.execute_script(cmd)
#           else # sketchup texture
#               puts "HIDING AUTO ALPHA BUTTONS"
#               #       $('#aa').nextAll(".imagemap").hide();
#               #cmd = '$("#aa").nextAll(".autoalpha_image").hide()';
#               cmd = '$("#autoalpha_image_field").hide()';
#               @material_editor_dialog.execute_script(cmd)
            end
            
        end
        
        
        @material_editor_dialog.add_action_callback('open_color_picker') { |dialog, param|
            SU2LUX.dbg_p "creating color picker window"
            #puts param
            @lrs.colorpicker=param
            @color_picker.show
        }
		
		@color_picker.add_action_callback('provide_color') { |dialog, passedcolor|
			puts "material editor callback passing colour to colour picker init_color command"
			swatchrgb = get_swatch_rgb()
			
			# set values in colorpicker RGB fields
			rval =  @current.send(@lrs.send(@lrs.colorpicker)[0])
			gval =  @current.send(@lrs.send(@lrs.colorpicker)[1])
			bval =  @current.send(@lrs.send(@lrs.colorpicker)[2])
			cmd1 = "init_rgb_fields(\"#{rval}\",\"#{gval}\",\"#{bval}\")"
            @color_picker.execute_script(cmd1)
			
			# set value for hidden field in color picker
			cmd2 = "init_color(\"#{swatchrgb}\")"
            @color_picker.execute_script(cmd2)
		}
		
		@color_picker.add_action_callback('colorfield_red_update') { |dialog, colorvalue|
			#puts "updating red for"
			#puts @lrs.colorpicker
			@current.send(@lrs.send(@lrs.colorpicker)[0]+"=",colorvalue)
            update_swatches()
		}
		
		@color_picker.add_action_callback('colorfield_green_update') { |dialog, colorvalue|
			#puts "updating green for"
			#puts @lrs.colorpicker
			@current.send(@lrs.send(@lrs.colorpicker)[1]+"=",colorvalue)
            update_swatches()
		}	
		
		@color_picker.add_action_callback('colorfield_blue_update') { |dialog, colorvalue|
			#puts "updating blue for"
			#puts @lrs.colorpicker
			@current.send(@lrs.send(@lrs.colorpicker)[2]+"=",colorvalue)
            update_swatches()
		}
		
        
        @color_picker.add_action_callback('pass_color') { |dialog, passedcolor| # passedcolor is in #ffffff form
            passedcolor="#000000" if passedcolor.length != 7 # color picker may return NaN when mouse is dragged outside window
            SU2LUX.dbg_p "passed color received"
			@colorpicker_triggered = true
            #puts "picked color is ", passedcolor
            colorswatch = @lrs.colorpicker
			rvalue = (passedcolor[1, 2].to_i(16).to_f*1000000/255.0).round/1000000.0 # ruby 1.8 doesn't support round(6)
            gvalue = (passedcolor[3, 2].to_i(16).to_f*1000000/255.0).round/1000000.0
            bvalue = (passedcolor[5, 2].to_i(16).to_f*1000000/255.0).round/1000000.0
            if ((@lrs.colorpicker=="diffuse_swatch" or (@current.type == "glass" and  @lrs.colorpicker=="transmission_swatch")) and !Sketchup.active_model.materials.current.texture)
                Sketchup.active_model.materials.current.color = [rvalue,gvalue,bvalue] # material observer will update kd_R,G,B values
            end
			
            #puts "updating swatch:", colorswatch
			@current.send(@lrs.send(colorswatch)[0]+"=",rvalue)
			@current.send(@lrs.send(colorswatch)[1]+"=",gvalue)
			@current.send(@lrs.send(colorswatch)[2]+"=",bvalue)
			
            updateSettingValue(@lrs.send(colorswatch)[0])
            updateSettingValue(@lrs.send(colorswatch)[1])
            updateSettingValue(@lrs.send(colorswatch)[2])
            update_swatches()
        }
        
		@material_editor_dialog.add_action_callback('start_refresh') { |dialog, param|
            SU2LUX.dbg_p "refresh called through javascript"
			refresh()
		}
        
		@material_editor_dialog.add_action_callback('start_refresh_and_update') { |dialog, param|
            SU2LUX.dbg_p "refresh called through javascript"
			refresh()
            @materialtype = @current.type
			javascriptcommand = "$('#type').nextAll('.' + '" + @materialtype + "').show();"
            SU2LUX.dbg_p javascriptcommand
			dialog.execute_script(javascriptcommand)
		}
        

		@material_editor_dialog.add_action_callback('active_mat_type') { |dialog, param| # shows the appropriate material editor panels for current material type
            SU2LUX.dbg_p "callback: active_mat_type"
            puts @current
			@materialtype = @current.type
			javascriptcommand = "$('#type').nextAll('.' + '" + @materialtype + "').show();"
            SU2LUX.dbg_p javascriptcommand
			dialog.execute_script(javascriptcommand)
		}
		
		@material_editor_dialog.add_action_callback('type_changed') { |dialog, material_type|
            SU2LUX.dbg_p "callback: type changed"
			print "current material: ", material_type, "\n"
            update_texture_names(@current)
            if (material_type == "mix") # check if mix materials have been set
                if (@current.material_list1 == '')
                    matname0 = Sketchup.active_model.materials[0].name #.delete("[<>]")
                    puts "COMPARING NAMES:"
                    puts matname0
                    puts @current.name
                    if (@current.name != matname0)
                        @current.material_list1 = matname0
                        @current.material_list2 = matname0
                    else
                        @current.material_list1 = Sketchup.active_model.materials[1].name #.delete("[<>]")
                        @current.material_list2 = Sketchup.active_model.materials[1].name #.delete("[<>]")
                    end
                    cmd = "$('#material_list1 option').filter(function(){return ($(this).text() == '" + @current.material_list1 + "');}).attr('selected', true);"
                    @material_editor_dialog.execute_script(cmd)
                    cmd = "$('#material_list2 option').filter(function(){return ($(this).text() == '" + @current.material_list2 + "');}).attr('selected', true);"
                    @material_editor_dialog.execute_script(cmd)
                end
            end
            @current.send("type=", material_type)
            # update_swatches()
		}
		
		@material_editor_dialog.add_action_callback('get_diffuse_color') {|dialog, param|
            SU2LUX.dbg_p "callback: get_diffuse_color"
			lux_material = @current
			lux_material.specular = lux_material.color
			updateSettingValue("ks_R")
			updateSettingValue("ks_G")
			updateSettingValue("ks_B")
		}
		
		@material_editor_dialog.add_action_callback("reset_to_default") {|dialog, params|
            puts "callback: reset_to_default"
			luxmat = getluxmatfromskpname(Sketchup.active_model.materials.current.name)
            # copy settings to be saved
            kdr, kdg, kdb = [luxmat.kd_R, luxmat.kd_G, luxmat.kd_B]
            mattype = luxmat.type
            textype = "none"
            #if (luxmat.has_texture?('kd'))
            if luxmat.respond_to?(:kd_texturetype)
                puts "TEXTURE"
                textype = luxmat.kd_texturetype
            else
                PUTS "NO TEXTURE"
            end
            # reset material
            puts "resetting material " + luxmat.name
            luxmat.reset
            
            # paste settings to be saved
            luxmat.kd_R = kdr
            luxmat.kd_G = kdg
            luxmat.kd_B = kdb
            luxmat.type = mattype
            
            # use jquery to set dropdown to right texture type, after that, set texture_name
            puts "TEXTYPE: " + textype
            if textype == "sketchup"
                cmd = '$("#kd_texturetype").val(\'' + textype + '\')'
                luxmat.kd_texturetype = textype
                @material_editor_dialog.execute_script(cmd)
            end
            
            # refresh material editor
            refresh
		}
        
		@material_editor_dialog.add_action_callback("update_material_preview") {|dialog, params|
            puts "callback: update_material_preview"
			
			# prepare file paths
			os = OSSpecific.new
            preview_path = os.get_variables["material_preview_path"]
            path_separator = os.get_variables["path_separator"]
            
            active_luxmat = @materials_skp_lux.index(@current)
			active_material_name = SU2LUX.sanitize_path(active_luxmat.name)
			
			# todo: make sure folder exists, path exists
			
			
            
			# generate preview lxm file and export bitmap images
			lxm_path = File.join(preview_path, SU2LUX.sanitize_path(active_material_name)+".lxm")
			puts "lxm path is " + lxm_path
			base_file = File.join(preview_path, "ansi.txt")
			FileUtils.copy_file(base_file,lxm_path)
			generated_lxm_file = File.new(lxm_path,"a")
			generated_lxm_file << "MakeNamedMaterial \"SU2LUX_helper_null\" \n"
			generated_lxm_file << "	\"string type\" [\"null\"]"
			generated_lxm_file << "\n"
			
			texture_subfolder = "LuxRender_luxdata/textures"
			
			previewExport = LuxrenderExport.new(preview_path, path_separator, @lrs, self, Sketchup.active_model) # preview path should define where preview files will be stored 
			previewExport.export_procedural_textures(generated_lxm_file)
			previewExport.export_volumes(generated_lxm_file)
			
            collect_mix_materials(@current) # check if the current material is a mix material; if so, recursively gather submaterials
            for prmat in @collectedmixmaterials
                activeMat = @materials_skp_lux.index(prmat)
                activeMat_name = SU2LUX.sanitize_path(activeMat.name) # following LuxrenderMaterial.rb convention
                previewExport.export_preview_material(preview_path, generated_lxm_file, activeMat_name, activeMat, texture_subfolder,prmat)				
            end
            @collectedmixmaterials = []
            @collectedmixmaterials_i = 0
            
			generated_lxm_file.close
			puts "finished texture output for material preview"
			
			# generate preview lxs file
			lxs_path = File.join(preview_path, SU2LUX.sanitize_path(Sketchup.active_model.title) + "_" + active_material_name + ".lxs")
			
			base_file_2 = File.join(preview_path, "ansi.txt")
			FileUtils.copy_file(base_file_2, lxs_path)
			generated_lxs_file = File.new(lxs_path, "a")
            
			lxs_section_1 = File.readlines(File.join(preview_path, "preview.lxs01"))
            lxs_section_2 = File.readlines(File.join(preview_path, "preview.lxs02"))
            lxs_section_3 = File.readlines(File.join(preview_path, "preview.lxs03"))
            generated_lxs_file.puts lxs_section_1
            
            generated_lxs_file.puts("\t\"integer xresolution\" [" + @lrs.preview_size.to_s + "]")
            generated_lxs_file.puts("\t\"integer yresolution\" [" + @lrs.preview_size.to_s + "]")
            generated_lxs_file.puts("\t\"integer halttime\" [" + @lrs.preview_time.to_s + "]")
            generated_lxs_file.puts("\t\"string filename\" \[\""+SU2LUX.sanitize_path(Sketchup.active_model.title)+"_"+active_material_name+"\"]")
            generated_lxs_file.puts("")
            generated_lxs_file.puts("WorldBegin")
			generated_lxs_file.puts("Include \"" + active_material_name+".lxm\"")
            generated_lxs_file.puts(lxs_section_2)
            previewExport.output_material(generated_lxs_file, @current, active_material_name) # writes "NamedMaterial #active_material_name.." or light definition
            generated_lxs_file.puts(lxs_section_3)
            previewExport.export_displacement_textures(generated_lxs_file, @current, active_material_name)
            generated_lxs_file.puts("AttributeEnd")
            generated_lxs_file.puts("WorldEnd")
			generated_lxs_file.close
            
			# start rendering preview using luxconsole
			@filename = File.join(preview_path, SU2LUX.sanitize_path(Sketchup.active_model.title) + "_" + active_material_name + ".png")
			luxconsole_path = SU2LUX.get_luxrender_console_path()
			@time_out = @lrs.preview_time.to_f + 5
			@retry_interval = 0.5
			@luxconsole_options = " -x "
			pipe = IO.popen("\"" + luxconsole_path + "\"" + @luxconsole_options + " \"" + lxs_path + "\"","r") # start rendering
            puts ("\"" + luxconsole_path + "\"" + @luxconsole_options + " \"" + lxs_path + "\"")
			
			# wait for rendering to get ready, then update image
			@times_waited = 0.0
			@d = UI.start_timer(@lrs.preview_time.to_f + 1, false){ 		# sets timer one second longer than rendering time
				file_exists = File.file? @filename
				while (!file_exists && (@times_waited < @time_out)) 	# if no image is found, wait for file to be rendered
					print("no image found, timing out in ", @time_out-@times_waited, " seconds\n")
					file_exists = File.file? @filename
					sleep 0.2
					@times_waited += 0.2
				end	
				while (file_exists && ((Time.now() - File.mtime(@filename)) > @lrs.preview_time.to_f) && (@times_waited < @time_out))
					puts("old preview found, waiting for update...")				# if an old image is found, wait for update
					sleep 1
					@times_waited += 1
				end	
				if (@times_waited > (@time_out))						# if the waiting has surpassed the time out limit, give up
					puts("preview is taking too long, aborting")
					# UI.messagebox("The preview rendering process is taking longer than expected.")
				end
				if (@times_waited <= @time_out && (Time.now()-File.mtime(@filename)) < (@lrs.preview_time.to_f + @time_out))
					puts("updating preview")
					# the file name on the following line includes ?timestamp, forcing the image to be refreshed as the link has changed
                    filename = @filename.gsub('\\', '\\\\\\\\')
                    filename.gsub!(/\#/, '	%23')
                    puts ('loading file ' + filename)
					cmd = 'document.getElementById("preview_image").src = "' + filename + '\?' + File.mtime(@filename).to_s + '"'
					@material_editor_dialog.execute_script(cmd)
				end
			}
		}
        
        @material_editor_dialog.add_action_callback("previewsize") {|dialog, params|
            puts "setting preview size to " + params
            @lrs.preview_size = params
            # update image size in interface
            setdivheightcmd = 'setpreviewheight(' + @lrs.preview_size + ')'
            #puts setdivheightcmd
            @material_editor_dialog.execute_script(setdivheightcmd)
        }
        
        @material_editor_dialog.add_action_callback("previewtime") {|dialog, params|
            puts "setting preview time to " + params
            @lrs.preview_time = params
            
        }
		
		@material_editor_dialog.add_action_callback("show_continued") {|dialog, params|
            @material_editor_dialog.execute_script('startactivemattype()')
		}
		
		@material_editor_dialog.add_action_callback("texture_editor") {|dialog, params|
            puts "callback: texture_editor for " + params.to_s

			lux_material = @current
            data = params.to_s # for example ks
			method_name = data + '_texturetype'
			texture_type = lux_material.send(method_name)
            if (data=="aa") # autoalpha does not have a single imagemap entry, but does store its texture under that name
                texture_type = "imagemap"
            end
			
			prefix = data + '_' + texture_type + '_'
			@texture_editor_data['texturetype'] = lux_material.send(method_name)
        
            #properties_export = ['wrap', 'channel', 'filename', 'gamma', 'gain', 'filtertype', 'mapping', 'uscale', 'vscale', 'udelta', 'vdelta', 'maxanisotropy', 'discardmipmaps']
            properties_export =	['filename', 'uscale', 'vscale', 'udelta', 'vdelta', 'gamma', 'filtertype']
            properties_export.each {|par|
				@texture_editor_data[texture_type + '_' + par] = lux_material.send(prefix + par) if (lux_material.respond_to?(prefix+par))
			}
            
            @texture_editor = LuxrenderTextureEditor.new(@texture_editor_data, data, @scene_id)

            #puts "sending data to texture editor:"
            #@texture_editor_data.each{|item| puts item}
            #puts data
            
			@texture_editor.show()
		}
	end # end initialize
    
    def collect_mix_materials(active_material)
        if (@collectedmixmaterials_i > 4) # 4 levels of recursion is considered maximum sensible amount
            puts "recursive mix material detected, aborting"
        elsif (active_material.type=="mix")
            @collectedmixmaterials_i = @collectedmixmaterials_i + 1
            submaterial1 = getluxmatfromskpname(active_material.material_list1)
            submaterial2 = getluxmatfromskpname(active_material.material_list2)
            collect_mix_materials(submaterial1)
            collect_mix_materials(submaterial2)
            @collectedmixmaterials << active_material
        else
            @collectedmixmaterials << active_material
        end
    end
    
    def getluxmatfromskpname(passedmatname)
        for mat in @materials_skp_lux.values
            if (mat.name == passedmatname)
                return mat
            elsif (mat.original_name == passedmatname)
                return mat
            end
        end
        return nil
    end
	
	def load_preview_image()		
		os = OSSpecific.new
		filename = File.join(os.get_variables["material_preview_path"], Sketchup.active_model.title + "_" + @current.name + ".png") #.delete("[<>]")
		filename = filename.gsub('\\', '/')
		puts "running load_preview_image function, looking for file " + filename	
		if (File.exists?(filename))
			puts "preview image exists, loading " + filename
            filename.gsub!(/\#/, '	%23')
            cmd = 'document.getElementById("preview_image").src = "' + filename + '"'
		else
			puts "material preview file doesn't exist for this material, showing default image instead"
			cmd = 'document.getElementById("preview_image").src = "empty_preview.png"'
		end
		@material_editor_dialog.execute_script(cmd)
	end
	
    def showhideIOR()
        if @current.use_architectural == false
            cmd = '$("#IOR_interface").show()'
        else
            cmd = '$("#IOR_interface").hide()'
        end
		@material_editor_dialog.execute_script(cmd)
    end
                           
    def showhide_carpaint()
        if @current.type == "carpaint"
            if @current.carpaint_name == nil
                cmd = '$("#diffuse").show();'
            else
                cmd = '$("#diffuse").hide();'
            end
            @material_editor_dialog.execute_script(cmd)
        end
    end
                           
    def showhide_spectrum()
        #puts "updating spectrum fields"
                           #cmd0 = '$(".light_L").hide()'
        if @current.light_L == "emit_color"
           cmd1 = '$("#emit_color").show()'
           cmd2 = '$("#blackbody").hide()'
           cmd3 = '$("#emit_preset").hide()'
        elsif @current.light_L == "blackbody"
           cmd1 = '$("#emit_color").hide()'
           cmd2 = '$("#blackbody").show()'
           cmd3 = '$("#emit_preset").hide()'
        else
           cmd1 = '$("#emit_color").hide()'
           cmd2 = '$("#blackbody").hide()'
           cmd3 = '$("#emit_preset").show()'
        end
                           #@material_editor_dialog.execute_script(cmd0)
        @material_editor_dialog.execute_script(cmd1)
        @material_editor_dialog.execute_script(cmd2)
        @material_editor_dialog.execute_script(cmd3)
    end
	
    def showhide_displacement()
        if @current.dm_scheme == "loop"
           cmd1 = '$("#loop").show()'
           cmd2 = '$("#microdisplacement").hide()'
       else
           cmd1 = '$("#loop").hide()'
           cmd2 = '$("#microdisplacement").show()'
       end
       @material_editor_dialog.execute_script(cmd1)
       @material_editor_dialog.execute_script(cmd2)
    end
                           
    def showhide_specularIOR()
        if @current.specular_scheme == "specular_scheme_IOR"
           cmd1 = '$("#specular_scheme_IOR").show()'
           cmd2 = '$("#specular_scheme_color").hide()'
           cmd3 = '$("#specular_scheme_preset").hide()'
       elsif @current.specular_scheme == "specular_scheme_color"
           cmd1 = '$("#specular_scheme_IOR").hide()'
           cmd2 = '$("#specular_scheme_color").show()'
           cmd3 = '$("#specular_scheme_preset").hide()'
       else
           cmd1 = '$("#specular_scheme_IOR").hide()'
           cmd2 = '$("#specular_scheme_color").hide()'
           cmd3 = '$("#specular_scheme_preset").show()'
       end
       @material_editor_dialog.execute_script(cmd1)
       @material_editor_dialog.execute_script(cmd2)
       @material_editor_dialog.execute_script(cmd3)
    end


	def sanitize_path(original_path)
		if (ENV['OS'] =~ /windows/i)
			sanitized_path = original_path.unpack('U*').pack('C*') # converts string to ISO-8859-1
		else
			sanitized_path = original_path
		end
	end
    
    def update_swatches() # sets the right color for current material's material editor swatches
        puts "updating swatches"
		swatches = @lrs.swatch_list
        swatches.each do |swatch|
            colorswatch = @lrs.send(swatch) # returns ['k#_R','k#_G','k#_B']
            rchannel = "%.2x" % ((@current.send(colorswatch[0]).to_f)*255).to_i
            gchannel = "%.2x" % ((@current.send(colorswatch[1]).to_f)*255).to_i
            bchannel = "%.2x" % ((@current.send(colorswatch[2]).to_f)*255).to_i
            swatchcolor = "#" + rchannel + gchannel + bchannel
            changecolorswatch = "$('#" + swatch + "').css('background-color', '" + swatchcolor + "');"
            @material_editor_dialog.execute_script(changecolorswatch)
        end
    end
    
    def get_swatch_rgb()
		current_r =  @current.send(@lrs.send(@lrs.colorpicker)[0]).to_f
		current_g =  @current.send(@lrs.send(@lrs.colorpicker)[1]).to_f
		current_b =  @current.send(@lrs.send(@lrs.colorpicker)[2]).to_f
		r_hex = "%02x" %("0x"+((current_r*255).to_i.to_s(16)))
		g_hex = "%02x" %("0x"+((current_g*255).to_i.to_s(16)))
		b_hex = "%02x" %("0x"+((current_b*255).to_i.to_s(16)))
		rgbstring = "#" + r_hex + g_hex + b_hex
		return rgbstring
	end
    
	##
	# Takes a string like "key1=value1,key2=value2" and creates a hash.
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
	def find(name)
        mat = Sketchup.active_model.materials[name]
        if (getluxmatfromskpname(name)) # LuxRender material exists, return existing material
            return getluxmatfromskpname(name)
        elsif (mat) # create new LuxRender material
            @numberOfLuxMaterials += 1
            newluxmat = LuxrenderMaterial.new(mat, self)
            @materials_skp_lux[mat] = newluxmat
            return newluxmat
        else
            puts "MaterialEditor.find could not find SketchUp material:"
			puts name
			return nil
		end
	end 

	##
	#
	##	
	def show
        SU2LUX.dbg_p "running show function"
		@material_editor_dialog.show{}
		
	end	
	
	##
	#
	##	
	def hide
		@material_editor_dialog.close{}
	end
    
    ##
    #
    ##
    def get_skp_color(skpmat, luxmat)
		#puts "getting color from sketchup material:"
		#puts skpmat
		luxmat.color = skpmat.color
	end
	
	    ##
    #
    ##
    def get_skp_texture(skpmat, luxmat)
		if skpmat.texture
			# puts "setting texture information"
			texture_name = SU2LUX.sanitize_path(skpmat.texture.filename)
			#texture_name.gsub!(/\\\\/, '/') #bug with SketchUp not allowing \ characters # should be dealt with by SU2LUX.sanitize_path
			#texture_name.gsub!(/\\/, '/') if texture_name.include?('\\')
			luxmat.kd_imagemap_Sketchup_filename = texture_name
			luxmat.kd_texturetype = 'sketchup'
		end
	end


	##
	#
	##
	def refresh()
		SU2LUX.dbg_p "running material editor refresh function"
        #UI.messagebox (Sketchup.active_model.materials.length)
		materials = Sketchup.active_model.materials
		if(materials.current == nil)
			materials.current = materials[0]
		end
        
		## check if LuxRender materials exist, if not, create them
		for mat in materials
			if !@materials_skp_lux.include?(mat) # test if LuxRender material has been created, if not, create one
				#UI.messagebox(mat)
                luxmat = find(mat.name) # creates LuxRender material
				puts "adding material #{mat.name} to material hash, creating LuxRender material"
                @materials_skp_lux[mat] = luxmat
                get_skp_color(mat, luxmat)
                get_skp_texture(mat, luxmat)
            #else
            #    puts "material #{mat.name} found in material hash, skipping LuxRender material creation"
			end
		end
		
		## set @current
		if @materials_skp_lux.include?(materials.current)
			@current = @materials_skp_lux[materials.current]
			puts "current material has been set"
		else
			@current = @materials_skp_lux.values[0]
			puts "setting material[0] as current material"
		end
		
		## update material editor contents
        set_material_lists # dropdowns for materials, mix submaterials and volumes
        sendDataFromSketchup() # material values
        load_preview_image # material preview image
        set_current(@current.name) # active material in material dropdown
        update_texture_names(@current) # image texture paths
        set_texturefields(@current.name) # shows and hides texture load buttons
        showhide_fields() # show/hide specularIOR, displacement, emission spectrum, carpaint custom channel, specular IOR preset
        
        # set preview section height
        setdivheightcmd = 'setpreviewheight(' + @lrs.preview_size.to_s + ',' + @lrs.preview_time.to_s + ')'
        @material_editor_dialog.execute_script(setdivheightcmd)
		
		# add procedural textures to dropdown
		if(@lrs.proceduralTextureNames != nil)
			puts "LuxRenderMaterialEditor.rb adding " + @lrs.proceduralTextureNames.size.to_s + " procedural textures to texture dropdown menus"
			for texName in @lrs.proceduralTextureNames
				# get texture name, then texture type
				texChannelType = LuxrenderProceduralTexture.getChannelType(texName)
				@material_editor_dialog.execute_script('addToProcTextList("' + texName + '","' + texChannelType + '")')
			end   	
		end	
		
		# set right procedural textures
		@current.texturechannels.each{|channelname|
			# get procedural texture field and value
			proctex_field = channelname + '_imagemap_proctex'
			proctex_value = @current.send(proctex_field)
			# call javascript function with dropdown name and value
			if(proctex_value != nil && proctex_value != "")
				@material_editor_dialog.execute_script('setProcTextList("#' + proctex_field + '","' + proctex_value + '")')
			end
		}	
	end
    
    def showhide_fields()
        showhide_specularIOR # specular definition interface
        showhide_displacement # displacement interface
        showhide_spectrum # emission spectrum
        showhide_carpaint # carpaint custom channel
        update_spec_IOR() # specular IOR preset
    end

    ##
    #
    ##
    
    def update_texture_names(luxmat)
        for textype in luxmat.texturechannels
            update_texture_name(luxmat, textype)
        end
    end
    
    def update_texture_name(luxmat, textype)
        filepath = File.basename(luxmat.send(textype+'_imagemap_filename'))
        cmd = 'show_load_buttons(\'' + textype + '\',\'' + filepath + '\')'
        # puts cmd
        @material_editor_dialog.execute_script(cmd)
    end
    
    
    ##
    #
    ##
    def set_material_lists()
        puts "updating material dropdown lists"
        set_material_list("material_name")  # main material list
        set_material_list("material_list1") # mix material 1
        set_material_list("material_list2") # mix material 2
        set_material_list("lightbase") # emitter base material
		# volumes
		if(@lrs.volumeNames != nil)
			for volumeName in @lrs.volumeNames
				# add volume to interior and exterior dropdown
				dropdown_add_interior = "$('#volume_interior').append( $('<option></option>').val('" + volumeName + "').html('" + volumeName + "'))"
				dropdown_add_exterior = "$('#volume_exterior').append( $('<option></option>').val('" + volumeName + "').html('" + volumeName + "'))"
				@material_editor_dialog.execute_script(dropdown_add_interior)
				@material_editor_dialog.execute_script(dropdown_add_exterior)
			end
		end
    end
    
	
	##
	#
	##
	def set_current(passedname)
		#SU2LUX.dbg_p "call to set_current: #{passedname}"
        if (@current) # prevent update_swatches function from running before a luxmaterial has been created
            update_swatches()
        end
        #passedname = passedname.delete("[<>]")
        # show right material in material editor dropdown menu
        puts "setting active material in SU2LUX material editor dropdown"
        cmd = "$('#material_name option').filter(function(){return ($(this).text() == \"#{passedname}\");}).attr('selected', true);"
		@material_editor_dialog.execute_script(cmd)
        
	end
	
    ##
	#
	##
	def set_material_list(dropdownname)
        #puts "updating material dropdown list in LuxRender Material Editor, " + dropdownname
		cmd = "$('#" + dropdownname + "').empty()"
		@material_editor_dialog.execute_script(cmd)
        if (dropdownname == "lightbase")
            #defcmd1 = "$('#lightbase').append($('<option></option>').val('default').html('default'))"
            #@material_editor_dialog.execute_script(defcmd1)
            defcmd2 = "$('#lightbase').append($('<option></option>').val('invisible').html('invisible'))"
            @material_editor_dialog.execute_script(defcmd2)
        end
                           
		cmd = "$('#" + dropdownname +"').append( $('"
		materials = Sketchup.active_model.materials.sort
		for mat in materials
			luxrender_mat = @materials_skp_lux[mat]
			cmd = cmd + "<option value=\"" + SU2LUX.html_friendly(mat.name) + "\">" + SU2LUX.html_friendly(mat.name) + "</option>" # <option value="matname">matname</option>
		end
		cmd = cmd + "'));"
		@material_editor_dialog.execute_script(cmd)
	end
    
	##
	#set parameters in inputs of settings.html
	##
	def sendDataFromSketchup()
        puts  "running sendDataFromSketchup for " + @current.name
		materialproperties = @current.get_names # returns all settings from LuxrenderMaterial @@settings
		materialproperties.each { |setting| updateSettingValue(setting)}
        # update interface based on dropdown menus
                           
                           
                           
                           
		# SU2LUX.dbg_p "just ran sendDataFromSketchup@LuxrenderMaterialEditor"
	end # END sendDataFromSketchup
                           
    ##
    #
    ##
    def update_spec_IOR()
        cmd = "$('#spec_IOR_preset_value').text(" + @current.specular_preset.to_s +  ".toFixed(3));"
        @material_editor_dialog.execute_script(cmd)
    end
                           
	
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
		new_value = value.to_s
		
		# update boolean values
		if(@current[id] == true or @current[id] == false)
			self.fire_event("##{id}", "attr", "checked=#{value}")
			cmd = "checkbox_expander('#{id}');"
			@material_editor_dialog.execute_script(cmd)
			cmd = "$('##{id}').next('div.collapse').find('select').change();"
			@material_editor_dialog.execute_script(cmd)
			
		# update all other parameter values
		else
			self.fire_event("##{id}", "val", new_value)
			# cmd="$('##{id}').val('#{new_value}');"
			# @material_editor_dialog.execute_script(cmd)
		end
	end # END setValue

	##
	#
	##
	def updateSettingValue(id)
		lux_material = @current
		setValue(id, lux_material[id])
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
					cmd << "$('#{object}').attr('#{key}', #{value});"
				}
		end
		@material_editor_dialog.execute_script(cmd)
	end
	
	def closeColorPicker
		if (@color_picker.visible?)
			@color_picker.close
		end
	end

	def close
		@material_editor_dialog.close
	end
	
	def visible?
		return @material_editor_dialog.visible?
	end
	
end #end class LuxrenderMaterialEditor