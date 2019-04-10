class OSSpecific

	attr_reader :variables
	alias_method :get_variables, :variables
	
	##
	#
	##
	def initialize
		@variables = {
			"default_save_folder" => ENV["USERPROFILE"].gsub(File::ALT_SEPARATOR,File::SEPARATOR),
			"luxrender_filename" => "luxrender.exe",
            "luxconsole_filename" => "luxconsole.exe",
			"path_separator" => "\\",
			"material_preview_path" => File.join(ENV['APPDATA'], "LuxRender").gsub(File::ALT_SEPARATOR,File::SEPARATOR),
            "settings_path" => File.join(ENV['APPDATA'],"LuxRender","LuxRender_settings_presets").gsub(File::ALT_SEPARATOR,File::SEPARATOR)
		}
	end
	
	##
	#
	##
	def search_multiple_installations
		return nil
	end

end