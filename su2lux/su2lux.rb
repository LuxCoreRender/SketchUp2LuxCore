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
# Name         : su2lux.rb
# Description  : Model exporter and material editor for LuxRender http://www.luxrender.net
# Menu Item    : Plugins\LuxRender Exporter
# Authors      : Abel Groenewolt
#                Alexander Smirnov (aka Exvion)  e-mail: exvion@gmail.com
#                Mimmo Briganti (aka mimhotep)
#                Initially based on SU exporters: SU2KT by Tomasz Marek, Stefan Jaensch,Tim Crandall, 
#                SU2POV by Didier Bur and OGRE exporter by Kojack
# Usage        : Copy script to PLUGINS folder in SketchUp folder, run SketchUp, go to Plugins\LuxRender exporter
# Type         : Exporter

require 'sketchup.rb'

if (Sketchup::version.split(".")[0].to_f >= 14)
    require 'su2lux/fileutils_ruby20.rb'
else
    require 'su2lux/fileutils_ruby19.rb' # versions older than 2014 use Ruby 1.9
end

module SU2LUX

    # Module constants
    SU2LUX_VERSION = "0.45a"
    SU2LUX_DATE = "6 January 2016"
	DEBUG = true
	PLUGIN_FOLDER = "su2lux"
    GEOMETRYFOLDER = "geometry"
    TEXTUREFOLDER = "textures"
	SCENE_EXTENSION = ".lxs"
	SUFFIX_MATERIAL = "-materials.lxm"
	SUFFIX_OBJECT = "-geometry.lxo"
	SUFFIX_VOLUME = "-volumes.lxv"
	SUFFIX_DIST = "_dist"
    SUFFIX_DATAFOLDER = "_luxdata"

	##
	# prints a message in the Ruby console only when in debug mode
	##
	if (DEBUG)
		def SU2LUX.dbg_p(message)
			p message
		end
	else
		def SU2LUX.dbg_p(message)
		end
	end

	##
	#
	##
	def SU2LUX.create_observers(model)
		#$SU2LUX_view_observer = SU2LUX_view_observer.new
		#model.active_view.add_observer($SU2LUX_view_observer)
		#$SU2LUX_rendering_options_observer = SU2LUX_rendering_options_observer.new
		#model.rendering_options.add_observer($SU2LUX_rendering_options_observer)
		$SU2LUX_selection_observer = SU2LUX_selection_observer.new
		model.selection.add_observer($SU2LUX_selection_observer)		
		$SU2LUX_materials_observer = SU2LUX_materials_observer.new
		model.materials.add_observer($SU2LUX_materials_observer)
        $SU2LUX_model_observer = SU2LUX_model_observer.new
        model.add_observer($SU2LUX_model_observer)
	end

	##
	#
	##
	def SU2LUX.remove_observers(model)
		model.active_view.remove_observer $SU2LUX_view_observer
		#model.rendering_options.remove_observer $SU2LUX_rendering_options_observer
		model.selection.remove_observer($SU2LUX_selection_observer)
		model.materials.remove_observer $SU2LUX_materials_observer
		model.remove_observer $SU2LUX_model_observer
	end
	
	##
	#
	##
	def SU2LUX.get_os
        if (Object::RUBY_PLATFORM =~ /darwin/i)
            return :mac
        else
            return :windows
        end
	end # END get_os


	##
	# initialize variables
	##
	def SU2LUX.initialize_variables
		os = OSSpecific.new
		@os_specific_vars = os.get_variables
        @lrs_hash = {}
        @sceneedit_hash = {}
        @lampedit_hash = {}
        @volumeedit_hash = {}
		@proctexture_hash = {}
        @renderedit_hash = {}
        @matedit_hash = {}
        
		@luxrender_filename = @os_specific_vars["luxrender_filename"]
        @luxconsole_executable = @os_specific_vars["luxconsole_filename"]
		@os_separator = @os_specific_vars["path_separator"]
        @material_preview_path = @os_specific_vars["material_preview_path"]
		
        # create folder and files needed for material preview
        Dir.mkdir(@material_preview_path) unless File.exists?(@material_preview_path)
		required_files = ["preview.lxs01", "preview.lxs02", "preview.lxs03", "ansi.txt"]
		folder_path = File.dirname(File.expand_path(__FILE__))
		if folder_path.respond_to?(:force_encoding)
		  folder_path.force_encoding("UTF-8")
		end  
        for required_file_name in required_files
            old_path = File.join(folder_path, required_file_name)
            new_path = File.join(os.get_variables["material_preview_path"], required_file_name)
            FileUtils.copy_file(old_path, new_path) unless File.exists?(new_path)
        end
        
        # create folder for settings files, copy settings files
        @settings_path = @os_specific_vars["settings_path"]
        Dir.mkdir(@settings_path) unless File.exists?(@settings_path)
        settings_source_folder = File.join(SU2LUX::PLUGIN_FOLDER, "presets_render_settings")
        puts "copying preset files"
        settingsfilesstring = File.join(Sketchup.find_support_file("Plugins"),settings_source_folder,"/*.lxp")
        #puts settingsfilesstring
        Dir.glob(settingsfilesstring) do |presetfile|
            settings_target_file = File.join(os.get_variables["settings_path"], File.basename(presetfile))
            puts settings_target_file
            FileUtils.copy_file(presetfile,settings_target_file) unless File.exists?(settings_target_file)
        end
        #puts "finished copying preset files"
        
	end # END initialize_variables

	##
	# resetting values of all instance variables
	##
	def SU2LUX.reset_variables
		@texturewriter = Sketchup.create_texture_writer
		@selected = false
		@model_name = ""
	end # END reset_variables
  
	##
	#	run focus script
	##
	
	def SU2LUX.focus
		puts "running focus tool"
		focusTest = FocusTool.new(Sketchup.active_model.definitions.entityID)
		Sketchup.active_model.select_tool(focusTest)
		#focusTest.activate()
		#puts "done running focus tool"
	end
  
	##
	# exporting geometry, lights, materials and settings to a LuxRender file
	##
	def SU2LUX.export
		Sketchup.active_model.start_operation("SU2LUX export", true, false, false)
		Sketchup.set_status_text('SU2LUX export: initializing')
		
		# add undo step
		#Sketchup.active_model.start_operation("SU2LUX: prepare export", true, false, false)
		
		SU2LUX.reset_variables
		model = Sketchup.active_model
        scene_id = Sketchup.active_model.definitions.entityID
        @material_editor = SU2LUX.get_editor(scene_id,"material")
        lrs = SU2LUX.get_lrs(scene_id)
		lrs.export_luxrender_path = SU2LUX.get_luxrender_path(lrs) # path to LuxRender executable

        # check if export folder exists, if not, set lrs.export_file_path to provided path
		if (lrs.export_file_path == nil || !File.directory?(File.dirname(lrs.export_file_path)))
			lrs.export_file_path = UI.openpanel("Please select output file name", "", Sketchup.active_model.name.chomp(".skp") + ".lxs")			
		end 
		
		# remove .skp extension from export file path
		lrs.export_file_path = lrs.export_file_path.split(".skp")[0]

		# make sure export file path has the right extension
		if File.extname(lrs.export_file_path) != ".lxs"
            lrs.export_file_path = lrs.export_file_path + ".lxs"
        end
		# fix slash direction
		lrs.export_file_path = lrs.export_file_path.gsub(/\\\\/, '/') 
		lrs.export_file_path = lrs.export_file_path.gsub(/\\/, '/') if lrs.export_file_path.include?('\\')
		
        exportpath = File.join(File.dirname(lrs.export_file_path), SU2LUX.sanitize_path(File.basename(lrs.export_file_path))) #SU2LUX.sanitize_path(lrs.export_file_path)
		
		# create LuxrenderExport object
		le = LuxrenderExport.new(exportpath, @os_separator, lrs, @material_editor, model)
		le.reset

		file_basename = File.basename(exportpath, SCENE_EXTENSION)
		file_dirname = File.dirname(exportpath)
		file_fullname = File.join(file_dirname, file_basename) # was: string + @os_separator + string
        file_datafolder = file_fullname + SU2LUX::SUFFIX_DATAFOLDER + @os_separator
		filepath_textures = File.join(file_fullname + SU2LUX::SUFFIX_DATAFOLDER, TEXTUREFOLDER)
		
        # create scene data folder
        if !FileTest.exist?(file_fullname+SU2LUX::SUFFIX_DATAFOLDER)
            Dir.mkdir(file_fullname+SU2LUX::SUFFIX_DATAFOLDER)
            Dir.mkdir(filepath_textures)
        end
        
		# export geometry
		puts 'exporting geometry'
		lxo_file = File.new(file_datafolder + file_basename  + SUFFIX_OBJECT, "w")
		le.export_mesh(lxo_file, model)
		lxo_file.close

		Sketchup.set_status_text('SU2LUX export: materials and volumes')
		
		
		# prepare lxm file
		lxm_file = File.new(file_datafolder + file_basename + SUFFIX_MATERIAL, "w")
		lxm_file << "MakeNamedMaterial \"SU2LUX_helper_null\" \n" # add helper null material
		lxm_file << "	\"string type\" [\"null\"]"
		lxm_file << "\n\n"
		
		# add volumes
		puts 'exporting volumes'
		le.export_volumes(lxm_file)
		
		# export all textures and materials
		puts 'exporting materials'
        relative_datafolder = file_basename + SU2LUX::SUFFIX_DATAFOLDER
		le.export_procedural_textures(lxm_file)
		le.export_used_materials(model.materials, lxm_file, lrs.texexport, relative_datafolder) # LuxRender materials for all SketchUp materials
		if(lrs.exp_distorted)
			le.export_distorted_materials(lxm_file, relative_datafolder) # materials created in LuxrenderExport for distorted textures
		end
		le.export_component_materials(lxm_file)
		
		lxm_file.close
		
		Sketchup.set_status_text('SU2LUX export: settings')
        # write lxs file
		puts 'exporting settings'
		#puts 'export path:'
		#puts exportpath
		lrs.export_file_path = exportpath
		lxs_file = File.new(exportpath, "w")
		le.export_global_settings(lxs_file)
		le.export_renderer(lxs_file)
		puts 'SU2LUX exporting camera'
		le.export_camera(model.active_view, lxs_file)
		le.export_film(lxs_file, file_basename)
		puts 'exporting render settings'
		le.export_render_settings(lxs_file)
		lxs_file.puts 'WorldBegin'
		lxs_file.puts "Include \"" + file_basename + SU2LUX::SUFFIX_DATAFOLDER + '/' + file_basename + SUFFIX_MATERIAL + "\"\n\n"
		lxs_file.puts "Include \"" + file_basename + SU2LUX::SUFFIX_DATAFOLDER + '/' + file_basename + SUFFIX_OBJECT + "\"\n\n"
		le.export_light(lxs_file) # sun/environment lights
		lxs_file.puts 'WorldEnd'
		lxs_file.close
		
		
		
		Sketchup.set_status_text('SU2LUX export: textures')
        # write texture files
		le.export_textures(filepath_textures)
		Sketchup.active_model.commit_operation()
	end # END export

	##
	#	 showing the export dialog box
	##
	def SU2LUX.export_dialog(render = true)
        #'render' is a boolean indicating if LuxRender should be run
		
		start_time = Time.new
		
        puts "LuxRender export started"
        
		SU2LUX.remove_observers(Sketchup.active_model)
		SU2LUX.reset_variables
		
        file_path_exists = false
		# check whether file path has been set (default path is "")
        lrs = SU2LUX.get_lrs(Sketchup.active_model.definitions.entityID)
		if (lrs.export_file_path == "")
            puts "no export file path set"
			saved = SU2LUX.new_export_file_path
			if (saved)
                file_path_exists = true
                puts "export_file_path set"
            end
        else # file path was defined already
            file_path_exists = true
        end
        
        # export and run
        if (file_path_exists==true)
            start_time = Time.new
			
			#Sketchup.active_model.start_operation("SU2LUX export", true, false, false)
            SU2LUX.export
			#Sketchup.active_model.commit_operation()
            
			if(render==true)
                if lrs.runluxrender == "yes"
					Sketchup.set_status_text('SU2LUX export: starting LuxRender')
                    puts "launching LuxRender"
                    SU2LUX.launch_luxrender
                elsif lrs.runluxrender == "ask"
                    puts "asking user if LuxRender should be launched"
                    result = SU2LUX.report_window(start_time, ask_render=true)
                    SU2LUX.launch_luxrender if result == 6
                else
                    puts "files exported, not launching LuxRender"
                    SU2LUX.report_window(start_time, ask_render=false)
                end
            end
        end
		elapsed_seconds = (Time.new - start_time).to_int
		Sketchup.set_status_text('SU2LUX export: export finished in ' + elapsed_seconds.to_s + (elapsed_seconds == 1 ? ' second' : ' seconds'))
		
		
        SU2LUX.create_observers(Sketchup.active_model)
	end # END export_dialog
	
	##
	# exporting the LuxRender file without asking for rendering
	##
	def SU2LUX.export_copy
        lrs = SU2LUX.get_lrs(Sketchup.active_model.definitions.entityID)
		old_export_file_path = lrs.export_file_path
		
		SU2LUX.new_export_file_path
		SU2LUX.export_dialog(render=false) # don't render
		
		lrs.export_file_path = old_export_file_path
	end # END export_copy

#### Some Dialogs (colour select, browse file path, etc..)###########
#####################################################################

	##
	#
	##
	def SU2LUX.new_export_file_path # browses for a new export file path and sets it in the lxs settings
		puts 'running new_export_file_path'
		model = Sketchup.active_model
		model_filename = File.basename(model.path)
        lrs = SU2LUX.get_lrs(Sketchup.active_model.definitions.entityID)
		export_filename = "Untitled.lxs"
		if !model_filename.empty?
			export_filename = (File.basename(model_filename)).chomp(".skp")
			export_filename << SCENE_EXTENSION
		end

		default_folder = SU2LUX.find_default_folder
		export_folder = default_folder
		export_folder = File.dirname(model.path) if !model.path.empty?
		
		user_input = UI.savepanel("Save lxs file", export_folder, export_filename)
		#check whether user has pressed cancel
		if user_input
			#puts user_input
			user_input.gsub!(/\\\\/, '/') #bug with sketchup not allowing \ characters
			user_input.gsub!(/\\/, '/') if user_input.include?('\\')
			# set file path in lrs
			lrs.export_file_path = File.join(File.dirname(user_input), File.basename(user_input, '.skp'))
				
			# add extension
			if lrs.export_file_path == lrs.export_file_path.chomp(SCENE_EXTENSION)
				lrs.export_file_path << SCENE_EXTENSION
				lrs.export_luxrender_path = SU2LUX.get_luxrender_path(lrs)
			end
			
			return (lrs.export_luxrender_path == nil ? false : true) # user may have selected a path
		end
		return false #user has not selected a path
	end # END new_export_file_path

	##
	#
	##
	def SU2LUX.load_env_image
		
		model = Sketchup.active_model
		model_filename = File.basename(model.path)
		# if model_filename.empty?
			# export_filename = SCENE_NAME
		# else
			# dot_position = model_filename.rindex(".")
			# export_filename = model_filename.slice(0..(dot_position - 1))
			# export_filename << SCENE_EXTENSION
		# end
		default_folder = SU2LUX.find_default_folder
		export_folder = default_folder
		export_folder = File.dirname(model.path) if ! model.path.empty?
		
		user_input = UI.openpanel("Open environment image", export_folder, "*")
		
		#check whether user has pressed cancel
		if user_input
			user_input.gsub!(/\\\\/, '/') #bug with sketchup not allowing \ characters
			user_input.gsub!(/\\/, '/') if user_input.include?('\\')
			#store file path for quick exports
            lrs = SU2LUX.get_lrs(Sketchup.active_model.definitions.entityID)
			lrs.environment_infinite_mapname = user_input
			
			return true #user has selected a path
		end
		return false #user has not selected a path
	end

	##
	#
	##
	def SU2LUX.load_image(title, object, method, prefix)
		
		model = Sketchup.active_model
		model_filename = File.basename(model.path)
		default_folder = SU2LUX.find_default_folder
		export_folder = default_folder
		export_folder = File.dirname(model.path) if ! model.path.empty?
		
		user_input = UI.openpanel(title, export_folder, "*")
		
		#check whether user has pressed cancel
		if user_input
			user_input.gsub!(/\\\\/, '/') #bug with sketchup not allowing \ characters
			user_input.gsub!(/\\/, '/') if user_input.include?('\\')
			#store file path for quick exports
			if(prefix.empty?)
				object.send(method+"=", user_input)
			else
				object.send(prefix + '_' + method + "=", user_input)
			end
			return true #user has selected a path
		end
		return false #user has not selected a path
	end

	##
	#   get LuxRender path, prompt user if it hasn't been defined
	##
	def SU2LUX.get_luxrender_path(lrs)
		storedpath = Sketchup.read_default("SU2LUX", "luxrenderpath")
		# check if we have a path in lrs
		if(lrs.export_luxrender_path != "" && lrs.export_luxrender_path != nil)
			return lrs.export_luxrender_path
		end
		
		if (storedpath.nil?)
			# prompt user for path
			storedpath = UI.openpanel("Please locate LuxRender", "", "")
			if(storedpath)
				Sketchup.write_default("SU2LUX", "luxrenderpath", storedpath.unpack('H*')[0])
			else
				UI.messagebox("LuxRender not found, SU2LUX will not be able to launch LuxRender after exporting scene files.")
			end
        else
            # convert path back to usable form
            storedpath = Array(storedpath).pack('H*')
		end
		return storedpath # note: can be nil if user cancels the file selection prompt
	end #END get_luxrender_path

	##
	#
	##
	def SU2LUX.change_luxrender_path(passedPath = nil) 
        lrs = SU2LUX.get_lrs(Sketchup.active_model.definitions.entityID)
		if(passedPath)
			providedpath = passedPath
		else # ask user for path
			providedpath = UI.openpanel("Please locate LuxRender", "", "")
			if(providedpath)
				providedpath = providedpath.dump.tr('"', '')
			end
		end
		# provide feedback in popup window
		if SU2LUX.luxrender_path_valid?(providedpath)
			lrs.export_luxrender_path = providedpath
			Sketchup.write_default("SU2LUX", "luxrenderpath", providedpath.dump.tr('"', '').unpack('H*')[0])
			puts "new path for LuxRender is " + lrs.export_luxrender_path.to_s
		else
			UI.messagebox("LuxRender could not be found. SU2LUX can still export LuxRender files, but will not be able to launch LuxRender.", MB_OK)
		end	
        # update path in settings window
		if(lrs.export_luxrender_path && !passedPath)
			puts "setting LuxRender path to " + lrs.export_luxrender_path
			cmd = "document.getElementById('export_luxrender_path').value='" + lrs.export_luxrender_path + '"'
			scenesettingseditor = get_editor(Sketchup.active_model.definitions.entityID,"scenesettings")
			scenesettingseditor.scene_settings_dialog.execute_script(cmd)
		end
	end

	
	def SU2LUX.sanitize_path(original_path)
		if (ENV['OS'] =~ /windows/i && RUBY_VERSION >= "1.9")
			#sanitized_path = original_path.unpack('U*').pack('C*') # converts string to ISO-8859-1
			#sanitized_path.gsub!(/[^0-9A-Za-z.\-]/, '_')
			sanitized_path = ''
			for pos in 0..original_path.length-1
				if original_path[pos].ord > 127
					sanitized_path += '&'+ original_path[pos].ord.to_s
				else
					sanitized_path += original_path[pos]
				end
			end
			return sanitized_path.delete("[<>]")
		elsif (ENV['OS'] =~ /windows/i) # ruby 1.8 does not support the 'ord' method
			original_path = File.join(original_path.split('\\')) # changes backslashes into slashes
			return original_path.dump.gsub!(/[^0-9A-Za-z.\/\:\-\_]/, '')
		else # on OS X, all seems to be fine
			return original_path
		end
	end
	
	##
	#  convert single and double quotes to their equivalent html characters, so that strings can be safely passed to jQuery
	##
	
	def SU2LUX.html_friendly(string)
		convertedString = string.gsub(/'/, '&#39;') # single quote to &#39;
		convertedString.gsub!(/"/, '&quot;')
		return convertedString
	end
	
	##
	#
	##
	def SU2LUX.find_default_folder
		folder = @os_specific_vars["default_save_folder"]
		return folder
	end # END find_default_folder

    ##
    #
    ##
    def SU2LUX.get_settings_folder
        settings_folder = @os_specific_vars["settings_path"]
        # puts "returning folder: " + settings_folder
        return settings_folder
    end # END find_default_folder

    ##
    # access LuxRender settings from within the plugin
    ##
    def SU2LUX.get_lrs(model_id)
        return @lrs_hash[model_id]
    end

	##
    # access LuxRender properties from the Ruby console
    ##
    def SU2LUX.settings()
        return @lrs_hash[Sketchup.active_model.definitions.entityID]
    end
	
	def SU2LUX.this_lrs()
        return @lrs_hash[Sketchup.active_model.definitions.entityID]
    end
	
	def SU2LUX.lamps()
		return @lampedit_hash[Sketchup.active_model.definitions.entityID]
	end
	
	def SU2LUX.volumes()
		return @volumeedit_hash[Sketchup.active_model.definitions.entityID]
	end
	
	def SU2LUX.textures()
		return @proctexture_hash[Sketchup.active_model.definitions.entityID]
	end
	
	def SU2LUX.materials()
		return @matedit_hash[Sketchup.active_model.definitions.entityID]
	end
	
	
    ##
    #
    ##
    def SU2LUX.add_lrs(lrs,model_id)
        @lrs_hash[model_id] = lrs
    end


	##
	#
	##
	def SU2LUX.report_window(start_time, ask_render=true)
		#SU2LUX.dbg_p "SU2LUX.report_window"
		end_time = Time.new
		elapsed = end_time-start_time
		time = " exported in "
			(time = time+"#{(elapsed/3600).floor}h ";elapsed-=(elapsed/3600).floor*3600) if (elapsed/3600).floor>0
			(time = time+"#{(elapsed/60).floor}m ";elapsed-=(elapsed/60).floor*60) if (elapsed/60).floor>0
			time = time+"#{elapsed.round}s. "

		export_text = "Model & Lights saved to file:\n"
        
        lrs = SU2LUX.get_lrs(Sketchup.active_model.definitions.entityID)
		if ask_render
			result = UI.messagebox(export_text + lrs.export_file_path +  " \n\nOpen exported model in LuxRender?",MB_YESNO)
		else
			result = UI.messagebox(export_text + lrs.export_file_path,MB_OK)
		end
        
		return result
	end # END report_window

    ##
    #
    ##
    def SU2LUX.luxrender_path_valid?(luxrender_path)
        (! luxrender_path.nil?  and (File.basename(luxrender_path).upcase.include?("LUXRENDER"))) # and File.exist?(eval(luxrender_path))
    end #END luxrender_path_valid?
  
	##
	#
	##
	def SU2LUX.launch_luxrender
		lrs = SU2LUX.get_lrs(Sketchup.active_model.definitions.entityID)
		if(lrs.export_luxrender_path == "" || lrs.export_luxrender_path == nil)
			lrs.export_luxrender_path = SU2LUX.get_luxrender_path(lrs)
			if(lrs.export_luxrender_path == "" || lrs.export_luxrender_path == nil)
				return
			end
        end

		Dir.chdir(File.dirname(lrs.export_luxrender_path))
		export_path = File.join(File.dirname(lrs.export_file_path), SU2LUX.sanitize_path(File.basename(lrs.export_file_path))) # SU2LUX.sanitize_path("#{lrs.export_file_path}")
		export_path = File.join(export_path.split(@os_separator))
		#puts export_path
		if (ENV['OS'] =~ /windows/i)
			command_line = "start \"max\" \/#{lrs.priority} \"#{lrs.export_luxrender_path}\" \"#{export_path}\""
			puts command_line
			system(command_line)
        else
            fullpath = File.join(lrs.export_luxrender_path, @os_specific_vars["file_appendix"])
			Thread.new do
				system("#{fullpath} \"#{export_path}\"")
			end
		end
	end # END launch_luxrender

	##
	#
	##
	def SU2LUX.get_luxrender_console_path
		lrs = SU2LUX.get_lrs(Sketchup.active_model.definitions.entityID)
		path = SU2LUX.get_luxrender_path(lrs)
        # puts "get_luxrender_path returned:"
        # puts path
		return nil if not path
		root=File.dirname(path)
		c_path=File.join(root,@luxconsole_executable)
        # puts "c_path is:"
        # puts c_path
		if FileTest.exist?(c_path)
			return c_path
		else
            UI.messagebox("cannot find luxconsole")
			return nil
		end
	end # END get_luxrender_console_path

	##
	# send text to status bar
	##
	def SU2LUX.status_bar(stat_text)
		statbar = Sketchup.set_status_text stat_text
	end # END status_bar

	##
	#
	##
	def SU2LUX.show_material_editor(scene_id)
		if @matedit_hash[scene_id]
            SU2LUX.dbg_p "using existing material editor"
        else
            SU2LUX.dbg_p "creating new material editor"
			@matedit_hash[scene_id] = LuxrenderMaterialEditor.new(scene_id, SU2LUX.this_lrs, Sketchup.active_model)
		end
        @matedit_hash[scene_id].set_material_lists
        if @matedit_hash[scene_id].visible?
			#puts "hiding material editor"
			@matedit_hash[scene_id].hide
            #@material_editor_dialog.close
		else
			puts "showing material editor"
			@matedit_hash[scene_id].show
            @matedit_hash[scene_id].refresh
		end
		# set preview section height (OS X; for Windows this gets done in refresh function)
		lrs = SU2LUX.get_lrs(Sketchup.active_model.definitions.entityID)
		setdivheightcmd = 'setpreviewheight(' + lrs.preview_size.to_s + ',' + lrs.preview_time.to_s + ')'
		#puts setdivheightcmd
		@matedit_hash[scene_id].material_editor_dialog.execute_script(setdivheightcmd)
	end # END show_material_editor

	##
	#
	##
	def SU2LUX.create_material_editor(scene_id, lrs)
		#if not @matedit_hash[scene_id]
			@matedit_hash[scene_id] = LuxrenderMaterialEditor.new(scene_id, lrs, Sketchup.active_model)
		#end
		return @matedit_hash[scene_id]
	end # END create_material_editor

    ##
    #
    ##
    def SU2LUX.create_scene_settings_editor(model_id, lrs)
        @sceneedit_hash[model_id] = LuxrenderSceneSettingsEditor.new(model_id, lrs)
        return @sceneedit_hash[model_id]
    end

	##
    #
    ##
    def SU2LUX.create_lamp_editor(model_id, lrs)
        @lampedit_hash[model_id] = LuxrenderLampEditor.new(lrs, Sketchup.active_model)
        return @lampedit_hash[model_id]
    end
	
	##
    #
    ##
    def SU2LUX.create_volume_editor(model_id, material_editor, lrs)
        @volumeedit_hash[model_id] = LuxrenderVolumeEditor.new(material_editor, lrs)
        return @volumeedit_hash[model_id]
    end

    ##
    #
    ##
    def SU2LUX.create_procedural_textures_editor(model_id, material_editor, lrs)
        @proctexture_hash[model_id] = LuxrenderProceduralTexturesEditor.new(material_editor, lrs)
        return @proctexture_hash[model_id]
    end
	
	##
    #
    ##
    def SU2LUX.create_render_settings_editor(scene_id, lrs)
        @renderedit_hash[scene_id] = LuxrenderRenderSettingsEditor.new(scene_id, lrs)
        return @renderedit_hash[scene_id]
    end
	
    ##
    #
    ##
    #def SU2LUX.set_toolbar(toolbar)
    #    @toolbar = toolbar
    #end

    def SU2LUX.reset_hashes()
        @lrs_hash = Hash.new
        @sceneedit_hash = Hash.new
        @renderedit_hash = Hash.new
        @matedit_hash = Hash.new
		@proctexture_hash = Hash.new
		@volumeedit_hash = Hash.new
    end


    ##
    #
    ##
    #def SU2LUX.get_button(buttonname)
    #    puts "returning toolbar button"
    #    if buttonname=="render"
    #        return @toolbar.entries[0]
    #    elsif buttonname=="materialeditor"
    #        return @toolbar.entries[1]
    #    elsif buttonname=="scenesettings"
    #        return @toolbar.entries[2]
    #    elsif buttonname=="rendersettings"
    #        return @toolbar.entries[3]
    #    end
    #end

	##
	#
	##
	def SU2LUX.show_scene_settings_editor(scene_id)
        puts "running show scene settings editor"
        #puts @sceneedit_hash[scene_id]
		if not @sceneedit_hash[scene_id]
			return
		end
        if @sceneedit_hash[scene_id].visible?
            @sceneedit_hash[scene_id].close
        else
            @sceneedit_hash[scene_id].show
        end
    end # END show_scene_settings_editor

	##
	#
	##
	def SU2LUX.show_lamp_editor(scene_id)
		if not @lampedit_hash[scene_id]
			puts "no lamp editor found, aborting"
		end
        if @lampedit_hash[scene_id].visible?
			puts "hiding lamp editor"
            @lampedit_hash[scene_id].close
        else
			puts "showing existing lamp editor: " +  @lampedit_hash[scene_id].to_s
            @lampedit_hash[scene_id].showLampDialog
        end
	end
	
	##
	#
	##
	def SU2LUX.show_volume_editor(scene_id)
		if not @volumeedit_hash[scene_id]
			puts "no volume editor found, aborting"
		end
        if @volumeedit_hash[scene_id].visible?
			puts "hiding volume editor"
            @volumeedit_hash[scene_id].close
        else
			puts "showing existing volume editor: " +  @volumeedit_hash[scene_id].to_s
            @volumeedit_hash[scene_id].showVolumeDialog
        end
		
	end
	
	##
	#
	##
	def SU2LUX.show_procedural_textures_editor(scene_id)
		if not @proctexture_hash[scene_id]
			puts "no procedural texture editor found, aborting"
		end
        if @proctexture_hash[scene_id].visible?
			puts "hiding procedural texture editor"
            @proctexture_hash[scene_id].close
        else
			puts "showing existing procedural texture editor: " +  @proctexture_hash[scene_id].to_s
            @proctexture_hash[scene_id].showProcTexDialog
        end
		
	end
	
	##
	#
	##
	def SU2LUX.show_render_settings_editor(scene_id)
        puts "running show render settings editor"
        #puts @renderedit_hash[scene_id]
		if not @renderedit_hash[scene_id]
			return
		end
        if @renderedit_hash[scene_id].visible?
            #puts "hiding render settings editor"
            @renderedit_hash[scene_id].close
        else
            #puts "showing render settings editor"
            @renderedit_hash[scene_id].show
        end
		
    end # END show_scene_settings_editor
                      
    ##
    #
    ##
    def SU2LUX.about
		lrs = SU2LUX.get_lrs(Sketchup.active_model.definitions.entityID)
		if(!lrs.version_set)
			# get version number and date from SU2LUX
			about_path = File.join(Sketchup.find_support_file("Plugins"), "su2lux", "about.html")
			about_html_lines = File.readlines(about_path)
			about_html_lines[38] = SU2LUX_VERSION + "\n"
			about_html_lines[40] = SU2LUX_DATE + "\n"
			generated_about_file = File.new(about_path, "w")
			about_html_lines.each{|line|
				generated_about_file.write(line)
			}
			generated_about_file.close
			lrs.version_set = true
		end
	
		# open window
		@about_dialog = UI::WebDialog.new("about SU2LUX", false, "aboutSU2LUX", 450, 546, 300, 100, false)
		about_dialog_dialog_path = Sketchup.find_support_file("about.html", File.join("Plugins", "su2lux"))
		@about_dialog.max_width = 450
		@about_dialog.set_file(about_dialog_dialog_path)
		@about_dialog.set_size(450,546)
		@about_dialog.show
    end

    ##
    #
    ##
    def SU2LUX.get_global_values(lrs)
        puts "looking for LuxRender path"
        if (Sketchup.read_default("SU2LUX","luxrenderpath"))
            lrs.export_luxrender_path = Array(Sketchup.read_default("SU2LUX","luxrenderpath")).pack('H*') # copy stored executable path to settings
        end
        puts "getting 'run luxrender' value"
        if (Sketchup.read_default("SU2LUX","runluxrender"))
            lrs.runluxrender = Array(Sketchup.read_default("SU2LUX","runluxrender")).pack('H*')
        else
            # write runluxrender: ask
            defaultruntype = "ask"
            Sketchup.write_default("SU2LUX","runluxrender",defaultruntype.unpack('H*')[0])
        end
    end
    
              

	##
	#
	##
	def SU2LUX.get_editor(scene_id,type)
		case type
			when "scenesettings"
                if @sceneedit_hash[scene_id]
                    editor = @sceneedit_hash[scene_id]
                else
                    puts "scene settings editor not initialized"
					return nil
                end
            when "material"
                if @matedit_hash[scene_id]
                    editor = @matedit_hash[scene_id]
                else
                    UI.messagebox "SU2LUX.get_editor did not find material editor - please report this issue on the forum"
                    return  nil
                end
			when "lamp"
			    if @lampedit_hash[scene_id]
                    editor = @lampedit_hash[scene_id]
                else
                    UI.messagebox "SU2LUX.get_editor did not find lamp editor - please report this issue on the forum"
                    return nil
                end	
			when "volume"
			    if @volumeedit_hash[scene_id]
                    editor = @volumeedit_hash[scene_id]
                else
                    UI.messagebox "SU2LUX.get_editor did not find volume editor - please report this issue on the forum"
                    return nil
                end			
            when "rendersettings"
                if @renderedit_hash[scene_id]
                    editor = @renderedit_hash[scene_id]
                else
                    UI.messagebox "SU2LUX.get_editor did not find settings editor - please report this issue on the forum"
                    return nil
                end
			when "proceduraltexture"	
				if @proctexture_hash[scene_id]
                    editor = @proctexture_hash[scene_id]
				else
					UI.messagebox "SU2LUX.get_editor did not find procedural texture editor - please report this issue on the forum"
                    return nil
				end				
            end
		return editor
	end # END get_editor
    
	
	def SU2LUX.get_current_editor(editor_name)
		return get_editor(Sketchup.active_model.definitions.entityID, editor_name)
	end
	
	##
	#
	##
	def SU2LUX.selected_face_has_texture?
		has_texture = false
		model = Sketchup.active_model
		selection = model.selection
		sel = selection.first
		if sel.valid? and sel.is_a? Sketchup::Face
			mesh = sel.mesh 5
			material = sel.material
			material = sel.back_material if material.nil?
			if material and material.materialType > 0
				has_texture = true
			end
		end
		return has_texture
	end
	
end # END module SU2LUX
                      

class SU2LUX_model_observer < Sketchup::ModelObserver
	# note: in order to prevent SketchUp asking to save changes of unmodified models, consider changing attribute saving logic

	# add onPreSaveModelSketchUp and onPostSaveModelSketchUp:
	def onPreSaveModel(model)
		#puts 'observer catching onPreSaveModel event'
		lrs = SU2LUX.get_lrs(Sketchup.active_model.definitions.entityID)
		# before saving, check if the export path equals the file path -> set variable in lrs
		skp_name = File.basename(model.path).chomp(".skp")
		lxs_name = File.basename(lrs.export_file_path).chomp(".lxs")
		#puts skp_name
		#puts lxs_name
		#puts skp_name == lxs_name
		if(skp_name == lxs_name)
			puts 'lxs name matched skp name'
			lrs.synchronised_names = true
		else
			lrs.synchronised_names = false
		end
	end
	
	def onPostSaveModel(model)
		puts 'SU2LUX observer catching onPostSaveModel event'
		lrs = SU2LUX.get_lrs(Sketchup.active_model.definitions.entityID)
		# after saving, check variable inf lrs; if true, update file path to reflect model name
		#if(lrs.synchronised_names) # note: commented out, as it caused crashes on OS X
		#	# get file name, get export folder
		#	puts 'updating lxs path'
		#	old_lxs_name = lrs.export_file_path.chomp(".lxs")
		#	old_folder_name = File.dirname(old_lxs_name)
		#	old_file_name = File.basename(lrs.export_file_path).chomp(".lxs")
		#	save_timer = UI.start_timer(0.1, false){ # onPostSaveModel only provides the old file name, so we have to wait and get the name from the active model
		#		UI.stop_timer(save_timer)
		#		skp_name = File.basename(model.path).chomp(".skp")
		#		# combine and store as new export path
		#		new_lxs_name = File.join(old_folder_name, skp_name) + '.lxs'
		#		lrs.export_file_path = new_lxs_name	
		#	}
		#end
	end
end

#class SU2LUX_view_observer < Sketchup::ViewObserver
	#include SU2LUX
	#def onViewChanged(view)
        #puts "onViewChanged observer triggered" # note: floods the ruby console when adjusting view
        #scene_id = Sketchup.active_model.definitions.entityID
		#scene_settings_editor = SU2LUX.get_editor(scene_id,"scenesettings")
		#lrs = SU2LUX.get_lrs(scene_id)
        # if not environment:
        #if (lrs.camera_type != 'environment')
        #    if Sketchup.active_model.active_view.camera.perspective?
		#	    lrs.camera_type = 'perspective'
		#	    # camera_type = 'perspective'
		#    else
		#	    lrs.camera_type = 'orthographic'
		#	    # camera_type = 'orthographic'
        #	end
        #end
                      
		#if (scene_settings_editor)
		#	if (Sketchup.active_model.active_view.camera.perspective?)
		#		fov = Sketchup.active_model.active_view.camera.fov
		#		fov = format("%.2f", fov)
		#		lrs.fov = fov
		#		scene_settings_editor.setValue("fov", fov)
		#		focal_length = Sketchup.active_model.active_view.camera.focal_length
		#		focal_length = format("%.2f", focal_length)
		#		#lrs.focal_length = focal_length
		#		#scene_settings_editor.setValue("focal_length", focal_length)
		#	end
		#	scene_settings_editor.setValue("camera_type", lrs.camera_type)
		#end
	#end # END onViewChanged
#end # END class SU2LUX_view_observer

class SU2LUX_app_observer < Sketchup::AppObserver
	def onNewModel(model)
        puts "onNewModel observer triggered"
		SU2LUX.remove_observers(Sketchup.active_model)
        model_id = Sketchup.active_model.definitions.entityID
		
        # close editors, reset hashes on Windows; OS X has multiple editors in parallel
        if (SU2LUX.get_os == :windows)
			# note: model_id does not change between sessions, so even though we are using the new model_id, we are closing the old editors
            oldmateditor = SU2LUX.get_editor(model_id,"material")
            oldrendersettingseditor = SU2LUX.get_editor(model_id,"rendersettings")
            oldscenesettingseditor = SU2LUX.get_editor(model_id,"scenesettings")
			oldproceduraltextureeditor = SU2LUX.get_editor(model_id,"proceduraltexture")
			oldlampeditor = SU2LUX.get_editor(model_id,"lamp")
			oldvolumeeditor = SU2LUX.get_editor(model_id,"volume")
			if oldmateditor.visible?
				oldmateditor.closeColorPicker
				oldmateditor.close
            end
			if oldrendersettingseditor.visible?
				oldrendersettingseditor.close
            end
			if oldscenesettingseditor.visible?
				oldscenesettingseditor.close
			end			
			if oldlampeditor.visible?
				oldlampeditor.closeColorPicker
				oldlampeditor.close
			end
			if oldproceduraltextureeditor.visible?
				oldproceduraltextureeditor.close
			end
			if oldvolumeeditor.visible?
				oldvolumeeditor.closeColorPicker
				oldvolumeeditor.close
			end
            # reset hashes
            SU2LUX.reset_hashes
        end
        
        lrs = LuxrenderSettings.new(model_id)
        SU2LUX.add_lrs(lrs,model_id)
		#lrs.reset # on Windows, try to make sure we don't use parameters from the previous model
		#lrs.load_from_model
        lrs.reset_viewparams
		lrs.reset_volumes_and_textures()
        
		puts "about to create material editor"
        material_editor = SU2LUX.create_material_editor(model_id, lrs)
		if(Sketchup.active_model.materials.current == nil)
			Sketchup.active_model.materials.current = Sketchup.active_model.materials[0]
        end
		
        puts "onNewModel creating scene settings editor"
        scene_settings_editor = SU2LUX.create_scene_settings_editor(model_id, lrs)
		
		puts "onNewModel creating procedural textures editor"
		procEditor = SU2LUX.create_procedural_textures_editor(model_id, material_editor, lrs)
		
		puts "onNewModel creating lamp editor"
		volEditor = SU2LUX.create_lamp_editor(model_id, lrs)
		
		puts "onNewModel creating volume editor"
		volEditor = SU2LUX.create_volume_editor(model_id, material_editor, lrs)
		
        puts "onNewModel creating render settings editor"
        render_settings_editor = SU2LUX.create_render_settings_editor(model_id, lrs)
        
        SU2LUX.create_observers(model)
				
        puts "finished running onNewModel"
	end # END onNewModel

	def onOpenModel(model)
        puts "onOpenModel triggered"
        model_id = Sketchup.active_model.definitions.entityID
        
        # close material and settings windows on Windows
        if (SU2LUX.get_os == :windows)
            oldmateditor = SU2LUX.get_editor(model_id,"material")
            oldrendersettingseditor = SU2LUX.get_editor(model_id,"rendersettings")
            oldscenesettingseditor = SU2LUX.get_editor(model_id,"scenesettings")
			oldproceduraltextureeditor = SU2LUX.get_editor(model_id,"proceduraltexture")
			oldlampeditor = SU2LUX.get_editor(model_id,"lamp")
			oldvolumeeditor = SU2LUX.get_editor(model_id,"volume")
			if oldmateditor.visible?
				oldmateditor.closeColorPicker
				oldmateditor.close
            end
			if oldrendersettingseditor.visible?
				oldrendersettingseditor.close
            end
			if oldscenesettingseditor.visible?
				oldscenesettingseditor.close
			end
			if oldproceduraltextureeditor.visible?
				oldproceduraltextureeditor.close
			end
			if oldlampeditor.visible?
				oldlampeditor.closeColorPicker
				oldlampeditor.close
			end
			if oldvolumeeditor.visible?
				oldvolumeeditor.closeColorPicker
				oldvolumeeditor.close
			end
			
        end
        
        puts "onOpenModel creating lrs"
        lrs = LuxrenderSettings.new(model_id)
        SU2LUX.add_lrs(lrs,model_id)
        loaded = lrs.load_from_model # true if a (saved) SketchUp file is open, false if working with a new file
        lrs.reset unless loaded
        
        puts "onOpenModel creating render settings editor"
        render_settings_editor = SU2LUX.create_render_settings_editor(model_id, lrs)

        puts "onOpenModel creating material editor"          
        material_editor = SU2LUX.create_material_editor(model_id, lrs)
		
        material_editor.materials_skp_lux = Hash.new
        material_editor.current = nil
		
		matTime_start = Time.new
        for mat in model.materials
			#puts "processing material " + mat.name
			luxmat = material_editor.find(mat.name)
			#puts "loading material"
			loaded = luxmat.load_from_model
			# puts "resetting material if loading did not work"
            luxmat.reset unless loaded
			puts "adding material to materials_skp_lux"
            material_editor.materials_skp_lux[mat] = luxmat
		end
		elapsed_seconds = (Time.new - matTime_start).to_int
		puts "onOpenModel processed model.materials in " + elapsed_seconds.to_s + " seconds"
		
        puts "onOpenModel creating scene settings editor"
        scene_settings_editor = SU2LUX.create_scene_settings_editor(model_id, lrs)
		
		puts "onOpenModel creating lamp editor"
		lampEditor = SU2LUX.create_lamp_editor(model_id, lrs)
		lampEditor.load_lamps_from_file()
		
		puts "onOpenModel creating procedural textures editor"
		procEditor = SU2LUX.create_procedural_textures_editor(model_id, material_editor, lrs)
		procEditor.load_textures_from_file()
		if(procEditor.activeProcTex)
			procEditor.updateGUI()
		end
		
		# create volume editor
		puts "onOpenModel creating volume editor"  
        volume_editor = SU2LUX.create_volume_editor(model_id, material_editor, lrs)
		
		# refresh material editor only now, as it uses the procedural texture objects
		time_refresh = Time.new
        material_editor.refresh
		elapsed_seconds = (Time.new - time_refresh).to_int
        puts "onOpenModel refreshed material editor interface in " + elapsed_seconds.to_s + " seconds" 
		
        puts "finished running onOpenModel"
        SU2LUX.create_observers(model)
	end
	
end # END class SU2LUX_app_observer


class SU2LUX_LightObserver < Sketchup::EntityObserver
    def onChangeEntity(lampComponent)
		# check scale, set angle accordingly
        scene_id = Sketchup.active_model.definitions.entityID
		lamp_editor = SU2LUX.get_editor(scene_id, "lamp")
		
		# from lamp editor, get lamp object (using getLampObject(componentDefinition))
		lamp_object = lamp_editor.getLampObject(lampComponent.definition)
		#puts "lamp_object null? " + ((lamp_object == nil) ? "yes" : "no")
        
		# calculate spot/projector angle, update angle display
		angle_degrees = lamp_object.angle_from_scale()
		puts "calculated angle: " + angle_degrees.to_s + "degrees"
		
		# in lamp editor, set current lamp as active lamp
		lamp_editor.set_active_lamp(lamp_object)
		lamp_editor.update_GUI_safe(lamp_object)
		lamp_object.createGeometry(lamp_object.lampType())
		
     end
end # END class 

class SU2LUX_selection_observer < Sketchup::SelectionObserver
	def onSelectionBulkChange(selection)
		# check if the lamp editor is visible
		model = Sketchup.active_model
        scene_id = model.definitions.entityID
		lamp_editor = SU2LUX.get_editor(scene_id, "lamp")
		if(lamp_editor.visible?)
			# if it is, check if the selection contains a lamp object
			model.selection.each do |selected_item|
				if(selected_item.is_a?(Sketchup::ComponentInstance) && selected_item.definition.attribute_dictionary("LuxRender") != nil)
					# show this lamp object in the lamp editor
					lamp_object = lamp_editor.getLampObject(selected_item.definition)
					puts "selection observer triggered, lamp editor is visible, lamp found: " + lamp_object.name
					lamp_editor.set_active_lamp(lamp_object)
					lamp_editor.update_GUI(lamp_object)
					#lamp_editor.
					break
				end
			end
		end
		
	end
end



class SU2LUX_materials_observer < Sketchup::MaterialsObserver
	def onMaterialSetCurrent(materials, material)
        scene_id = Sketchup.active_model.definitions.entityID
		material_editor = SU2LUX.get_editor(scene_id, "material")
		SU2LUX.dbg_p "onMaterialSetCurrent triggered by material #{material.name}"
		current_mat = material #Sketchup.active_model.materials.current
		
		if (Sketchup.active_model.materials.include? current_mat)
			if material_editor.materials_skp_lux.include?(current_mat)
				material_editor.current = material_editor.materials_skp_lux[current_mat]
				puts "onMaterialSetCurrent reusing LuxRender material "
			else
				material_editor.refresh()
			end
			material_editor.set_current(material_editor.current.name) # sets name of current material in dropdown, updates swatches
			material_editor.sendDataFromSketchup
			material_editor.fire_event("#type", "change", "")
			material_editor.load_preview_image()
            material_editor.set_texturefields(current_mat.name)
            material_editor.showhide_fields()
		else
			puts "current material is not used"
		end
	end
	
    def onMaterialAdd(materials, material)
        puts "onMaterialAdd added material: " + material.name
		#puts materials.size
		
		# adding a material will set it current, onMaterialSetCurrent will take over
        # except on OS X, so we have to take some steps manually:
		# note: when pasting objects that contain materials that are not yet in the scene, materials get added, but they will not be set current, therefore amongst others, they do not get added to materials_skp_lux
        
		scene_id = Sketchup.active_model.definitions.entityID
        #if (SU2LUX.get_os == :mac || material != Sketchup.active_model.materials.current) # note: setting the material current may not have happened here yet, so this executes for any material
            puts "onMaterialAdd creating new LuxRender material"
            material_editor = SU2LUX.get_editor(scene_id, "material")
            newmaterial = material_editor.find(material.name)
            newmaterial.color = material.color
            if (material.texture)
                newmaterial.kd_texturetype = "sketchup"
            end
            material_editor.refresh()
        #end
	end

    def onMaterialRemove(materials, material)
        SU2LUX.dbg_p "onMaterialRemove triggered"
        model_id = Sketchup.active_model.definitions.entityID
        material_editor = SU2LUX.get_editor(model_id, "material")
        material_editor.materials_skp_lux.delete(material)
		material_editor.refresh() if (material_editor);
	end
	
	def onMaterialChange(materials, material)
        puts "SU2LUX material observer catching SketchUp material change"
		
		# undo
		Sketchup.active_model.start_operation("SU2LUX material observer", true, false, true)
		
        scene_id = Sketchup.active_model.definitions.entityID
		material_editor = SU2LUX.get_editor(scene_id,"material")
        if (material_editor && material_editor.materials_skp_lux.include?(material))
            # test if material name exists; if not, follow name_changed logic
            material_editor.matname_changed = true
            material_editor.materials_skp_lux.values.each{|luxmat|
                # puts luxmat.name_string, material.name, luxmat.name_string==material.name
                if luxmat.name_string == material.name
                  material_editor.matname_changed = false
                end
            }
            #puts "@matname_changed: ", material_editor.matname_changed
            
			## deal with material name change
            if (material_editor.matname_changed == true)
                puts "onMaterialChange triggered by material name change"
                material_editor.current.name_string = material.name.to_s
                material_editor.matname_changed = false
                material_editor.set_material_lists()
                material_editor.set_current(material_editor.current.name)
            else ## deal with other material changes
                puts "onMaterialChange triggered SU2LUX material editor or SketchUp material editor"
                luxmaterial = material_editor.materials_skp_lux[material]
                    
                # if color has changed significantly (>1/255), update luxmat colors
                skpR = material.color.red
                skpG = material.color.green
                skpB = material.color.blue
                luxR = 255.0 * luxmaterial.kd_R.to_f
                luxG = 255.0 * luxmaterial.kd_G.to_f
                luxB = 255.0 * luxmaterial.kd_B.to_f
                # puts skpR, skpG, skpB, luxR, luxG, luxB
                updateswatches = false
                if ((skpR-luxR).abs > 1 || (skpG-luxG).abs > 1 || (skpB-luxB).abs > 1)
                    luxmaterial.color = material.color
                    updateswatches = true
                    colorarray=[skpR/255.0,skpG/255.0,skpB/255.0]
                end

                if material.texture
                    puts "material has a texture"
                    texture_name = material.texture.filename
                    texture_name.gsub!(/\\\\/, '/') #bug with sketchup not allowing \ characters
                    texture_name.gsub!(/\\/, '/') if texture_name.include?('\\')
                    luxmaterial.kd_imagemap_Sketchup_filename = texture_name
                    luxmaterial.kd_texturetype = 'sketchup' if (luxmaterial.kd_texturetype != 'imagemap')
                else
                    luxmaterial.kd_imagemap_Sketchup_filename = ''
                    if (luxmaterial.kd_texturetype == 'sketchup')
                        luxmaterial.kd_texturetype = 'none'
                    end
                end
                      
                if material_editor.materials_skp_lux[material] == material_editor.current
                      puts "modified material is current"
                      material_editor.updateSettingValue("kd_imagemap_Sketchup_filename")
                      material_editor.updateSettingValue("kd_texturetype")
                      if (updateswatches == true)
                        material_editor.material_editor_dialog.execute_script("update_RGB('#kt_R','#kt_G','#kt_B','#{colorarray[0]}','#{colorarray[1]}','#{colorarray[2]}')")
                        material_editor.material_editor_dialog.execute_script("update_RGB('#kd_R','#kd_G','#kd_B','#{colorarray[0]}','#{colorarray[1]}','#{colorarray[2]}')")
                      end
                      material_editor.update_swatches()
                else
                      puts "modified material is not current"
                end
            end
        end
		
		# end undo
		Sketchup.active_model.commit_operation()
		
	end
	
end # end observer section


if( not file_loaded?(__FILE__))
    # runs whenever SketchUp is started, both when opening by double clicking a file and when starting SketchUp by itself
    puts "initializing SU2LUX"
    model = Sketchup.active_model
	
    # load platform specific code
    case SU2LUX.get_os
		when :mac
			load File.join(SU2LUX::PLUGIN_FOLDER, "MacSpecific.rb")
		when :windows
			load File.join(SU2LUX::PLUGIN_FOLDER, "WindowsSpecific.rb")
		when :other
			UI.messagebox("operating system not recognised, please contact the SU2LUX developers")
	end

    # load SU2LUX Ruby files
	load File.join(SU2LUX::PLUGIN_FOLDER, "LuxrenderAttributeDictionary.rb")
    load File.join(SU2LUX::PLUGIN_FOLDER, "LuxrenderSettings.rb")
    load File.join(SU2LUX::PLUGIN_FOLDER, "LuxrenderRenderSettingsEditor.rb")
    load File.join(SU2LUX::PLUGIN_FOLDER, "LuxrenderSceneSettingsEditor.rb")
	load File.join(SU2LUX::PLUGIN_FOLDER, "LuxrenderLamp.rb")
	load File.join(SU2LUX::PLUGIN_FOLDER, "LuxrenderLampEditor.rb")
	load File.join(SU2LUX::PLUGIN_FOLDER, "LuxrenderMaterial.rb")
	load File.join(SU2LUX::PLUGIN_FOLDER, "LuxrenderMaterialEditor.rb")
	load File.join(SU2LUX::PLUGIN_FOLDER, "LuxrenderVolume.rb")
	load File.join(SU2LUX::PLUGIN_FOLDER, "LuxrenderVolumeEditor.rb")
	load File.join(SU2LUX::PLUGIN_FOLDER, "LuxrenderProceduralTexture.rb")
    load File.join(SU2LUX::PLUGIN_FOLDER, "LuxrenderProceduralTexturesEditor.rb")
	load File.join(SU2LUX::PLUGIN_FOLDER, "LuxrenderTextureEditor.rb")
	#load File.join(SU2LUX::PLUGIN_FOLDER, "LuxrenderMeshCollector.rb")
	load File.join(SU2LUX::PLUGIN_FOLDER, "LuxrenderExport.rb")
    load File.join(SU2LUX::PLUGIN_FOLDER, "LuxrenderToolbar.rb")
	load File.join(SU2LUX::PLUGIN_FOLDER, "LuxrenderFocus.rb")
	load File.join(SU2LUX::PLUGIN_FOLDER, "SU2LUX_UV.rb")

    # initialize, set active material
	SU2LUX.initialize_variables
    puts "finished initializing variables"

    puts "setting active material"
    if (!Sketchup.active_model.materials.current)
        if (Sketchup.active_model.materials.length == 0)
            Sketchup.active_model.materials.add
        end
        Sketchup.active_model.materials.current = Sketchup.active_model.materials[0]
    end
    
    # create LuxrenderSettings
    puts "creating LuxRender settings for current model"
    model_id = Sketchup.active_model.definitions.entityID
    lrs = LuxrenderSettings.new(model_id)
    SU2LUX.add_lrs(lrs,model_id)
	loaded = lrs.load_from_model # true if a (saved) SketchUp file is open, false if working with a new file
  	lrs.reset_viewparams unless loaded
    
    # get LuxRender path (as stored within SketchUp) and other global values
    SU2LUX.get_global_values(lrs)
    
    # create/load LuxRender materials
    puts "loading material settings"
    material_editor = SU2LUX.create_material_editor(model_id, lrs)
    material_editor.materials_skp_lux = Hash.new
    material_editor.current = nil
    for mat in model.materials
        luxmat = material_editor.find(mat.name)
        loaded = luxmat.load_from_model
        #luxmat.reset unless loaded
        material_editor.materials_skp_lux[mat] = luxmat
    end
    
    # todo: load procedural textures
    
    puts "creating procedural textures editor"
    procEditor = SU2LUX.create_procedural_textures_editor(model_id, material_editor, lrs)
    procEditor.load_textures_from_file()
    if(procEditor.activeProcTex)
		procEditor.updateGUI()
	end
    
    
    puts "creating volume editor"
    SU2LUX.create_volume_editor(model_id, material_editor, lrs)
    puts "creating lamp editor"
    SU2LUX.create_lamp_editor(model_id, lrs)
    
    
    
    material_editor.refresh
    puts "finished loading material settings"

	# set observers
    puts "creating observers"
    $SU2LUX_app_observer = SU2LUX_app_observer.new
    Sketchup.add_observer($SU2LUX_app_observer)
	
	
    SU2LUX.create_observers(Sketchup.active_model)

    # create scene settings editor and render settings editor
    puts "creating scene settings editor"
    SU2LUX.create_scene_settings_editor(model_id, lrs)
    puts "creating render settings editor"
    SU2LUX.create_render_settings_editor(model_id, lrs)
	
    # dialog may not have fully loaded yet, therefore loading presets should happen later as reaction on DOM loaded
 
    # create toolbar
    toolbar = create_toolbar()
    #SU2LUX.set_toolbar(toolbar)

    puts "finished 'no file loaded' procedure in su2lux.rb"
end # end of no_file_loaded code

file_loaded(__FILE__)
