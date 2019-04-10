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
#                 Luke Frisken (aka lfrisken)

class LuxrenderSettings

	attr_reader :dict
	alias_method :dictionary_name, :dict
	
	# global lists contain default values; these are cloned to any particular instance of LuxrenderSettings
		
	@@default_settings_global = {
		#### render settings preset; saving it in @@default_settings_render causes it to be saved in preset files, causing confusion ###
		'renderpreset' => 'interior',
		############   Color Swatches   ############
		'swatch_list' => ['diffuse_swatch','specular_swatch','reflection_swatch','metal2_swatch','em_swatch','transmission_swatch','absorption_swatch','cl1kd_swatch','cl1ks_swatch','cl2kd_swatch','cl2ks_swatch'],
		'volume_swatch_list' => ['vol_absorption_swatch','vol_scattering_swatch'],
		'diffuse_swatch' => ['kd_R','kd_G','kd_B'],
		'specular_swatch'=> ['ks_R','ks_G','ks_B'],
		'reflection_swatch' => ['kr_R','kr_G','kr_B'],
		'transmission_swatch' => ['kt_R','kt_G','kt_B'],
		'absorption_swatch' => ['ka_R','ka_G','ka_B'],
		'metal2_swatch' => ['km2_R','km2_G','km2_B'],
		'em_swatch' => ['em_R','em_G','em_B'],
		'cl1kd_swatch' => ['cl1kd_R','cl1kd_G','cl1kd_B'],
		'cl1ks_swatch' => ['cl1ks_R','cl1ks_G','cl1ks_B'],
		'cl2kd_swatch' => ['cl2kd_R','cl2kd_G','cl2kd_B'],
		'cl2ks_swatch' => ['cl2ks_R','cl2ks_G','cl2ks_B'],
		'vol_absorption_swatch' => ['vol_abs_R','vol_abs_G','vol_abs_B'],
		'vol_scattering_swatch' => ['vol_scat_R','vol_scat_G','vol_scat_B'],
		'synchronised_names' => false,
		'version_set' => false,
	}
		
	@@default_settings_render = {
		'renderer' => 'sampler',
		############  Pixel filter  ############
		'pixelfilter_type' => 'blackmanharris',
		'pixelfilter_mitchell_optmode' => 'manual', #TODO: change to slider ##unused in Sketchup
		'pixelfilter_mitchell_xwidth' => 1.1,
		'pixelfilter_mitchell_ywidth' => 1.1,
		'pixelfilter_mitchell_B' => 1.0,
		'pixelfilter_mitchell_C' => 0.0,
		'pixelfilter_mitchell_supersample' => true,
		'pixelfilter_blackmanharris_xwidth' => 3.3,
		'pixelfilter_blackmanharris_ywidth' => 3.3,
		'pixelfilter_box_xwidth' => 0.5,
		'pixelfilter_box_ywidth' => 0.5,
		'pixelfilter_triangle_xwidth' => 2.0, 
		'pixelfilter_triangle_ywidth' => 2.0,
		'pixelfilter_sinc_xwidth' => 2.0, 
		'pixelfilter_sinc_ywidth' => 2.0,
		'pixelfilter_sinc_tau' => 2.0,
		'pixelfilter_gaussian_xwidth' => 2.0, 
		'pixelfilter_gaussian_ywidth' => 2.0,
		'pixelfilter_gaussian_alpha' => 2.0,

		############  Sampler   ############
		'sampler_type'=>'metropolis',
		'sampler_random_pixelsamples' => 4,
		'sampler_random_pixelsampler' => 'vegas',
		'sampler_lowdisc_pixelsamples' => 4,
		'sampler_lowdisc_pixelsampler' => 'vegas',
		'sampler_noiseaware' => true,
		'sampler_metropolis_largemutationprob' => 0.4,
		'sampler_metropolis_maxconsecrejects' => 512,
		'sampler_metropolis_usevariance'=> false,
		'sampler_erpt_chainlength' => 2000,
			
		############ Integrator   ############
		'sintegrator_type' => 'bidirectional',
		'sintegrator_bidir_eyedepth' => 48,
		'sintegrator_bidir_eyerrthreshold' => 0.0,
		'sintegrator_bidir_lightdepth' => 48,
		'sintegrator_bidir_lightthreshold' => 0.0,
		'sintegrator_bidir_strategy' => 'auto',
		'sintegrator_bidir_debug' => 'false',
		'sintegrator_direct_maxdepth' => 5,
		'sintegrator_direct_shadow_ray_count' => 1,
		'sintegrator_direct_strategy' => 'auto',
		'sintegrator_distributedpath_directsampleall' => true,
		'sintegrator_distributedpath_directsamples' => 1,
		'sintegrator_distributedpath_indirectsampleall' => false,
		'sintegrator_distributedpath_indirectsamples' => 1,
		'sintegrator_distributedpath_diffusereflectdepth' => 3,
		'sintegrator_distributedpath_diffusereflectsamples' => 1,
		'sintegrator_distributedpath_diffuserefractdepth' => 5,
		'sintegrator_distributedpath_diffuserefractsamples' => 1,
		'sintegrator_distributedpath_directdiffuse' => true,
		'sintegrator_distributedpath_indirectdiffuse' => true,
		'sintegrator_distributedpath_glossyreflectdepth' => 2,
		'sintegrator_distributedpath_glossyreflectsamples' => 1,
		'sintegrator_distributedpath_glossyrefractdepth' => 5,
		'sintegrator_distributedpath_glossyrefractsamples' => 1,
		'sintegrator_distributedpath_directglossy' => true,
		'sintegrator_distributedpath_indirectglossy' => true,
		'sintegrator_distributedpath_specularreflectdepth' => 2,
		'sintegrator_distributedpath_specularrefractdepth' => 5,
		'sintegrator_distributedpath_strategy' => 'auto',
		'sintegrator_distributedpath_reject' => false, #GUI
		'sintegrator_distributedpath_diffusereflectreject' => false,
		'sintegrator_distributedpath_diffusereflectreject_threshold' => 10.0,
		'sintegrator_distributedpath_diffuserefractreject' => false,
		'sintegrator_distributedpath_diffuserefractreject_threshold' => 10.0,
		'sintegrator_distributedpath_glossyreflectreject' => false,
		'sintegrator_distributedpath_glossyreflectreject_threshold' => 10.0,
		'sintegrator_distributedpath_glossyrefractreject' => false,
		'sintegrator_distributedpath_glossyrefractreject_threshold' => 10.0,
		'sintegrator_exphoton_finalgather' => true,
		'sintegrator_exphoton_finalgathersamples' => 32,
		'sintegrator_exphoton_gatherangle' => 10.0,
		'sintegrator_exphoton_maxdepth' => 5,
		'sintegrator_exphoton_maxphotondepth' => 10,
		'sintegrator_exphoton_maxphotondist' => 0.5,
		'sintegrator_exphoton_nphotonsused' => 50,
		'sintegrator_exphoton_causticphotons' => 20000,
		'sintegrator_exphoton_directphotons' => 200000,
		'sintegrator_exphoton_indirectphotons' => 1000000,
		'sintegrator_exphoton_radiancephotons' => 200000,
		'sintegrator_exphoton_renderingmode' => 'directlighting',
		'sintegrator_exphoton_rrcontinueprob' => 0.65,
		'sintegrator_exphoton_rrstrategy' => 'efficiency',
		'sintegrator_exphoton_photonmapsfile' => '',
		'sintegrator_exphoton_shadow_ray_count' => 1,
		'sintegrator_exphoton_strategy' => 'auto',
		'sintegrator_exphoton_dbg_enable_direct' => true,
		'sintegrator_exphoton_dbg_enable_indircaustic' => true,
		'sintegrator_exphoton_dbg_enable_indirdiffuse' => true,
		'sintegrator_exphoton_dbg_enable_indirspecular' => true,
		'sintegrator_exphoton_dbg_enable_radiancemap' => false,
		'sintegrator_igi_maxdepth' => 5,
		'sintegrator_igi_mindist' => 0.1,
		'sintegrator_igi_nsets' => 4,
		'sintegrator_igi_nlights' => 64,
		'sintegrator_path_include_environment' => true,
		'sintegrator_path_maxdepth' => 10,
		'sintegrator_path_rrstrategy' => 'efficiency',
		'sintegrator_path_rrcontinueprob' => 0.65,
		'sintegrator_path_shadow_ray_count' => 1,
		'sintegrator_path_strategy' => 'auto',
		
		
		############ Integrator, SPPM ######
		
		'sppm_photonsampler' => "halton",
		'sppm_lookupaccel' => "hybridhashgrid",
		'sppm_maxeyedepth' => 16,
		'sppm_maxphotondepth' => 16,
		'sppm_photonperpass' => 1000000,
		'sppm_startradius' => 2.0,
		'sppm_alpha' =>  0.7,

		############  Volume Integrator  ############
		'volume_integrator_type' => "multi",
		'volume_integrator_stepsize' => 1.0,

		############  Accelerator   ############
		'accelerator_type' => "qbvh",
		'kdtree_intersectcost' => 80,
		'kdtree_traversalcost' => 1,
		'kdtree_emptybonus' => 0.5,
		'kdtree_maxprims' => 1,
		'kdtree_maxdepth' => -1,
		'qbvh_maxprimsperleaf' => 4,
		'qbvh_fullsweepthreshold'=> 16,
		'qbvh_skip_factor' => 1,
		'grid_refineimmediately' => false,
	}
	
	@@default_settings_texture_and_volume = {
		### helper value for procedural materials ###
		'proceduralTextureNames' => [],
		'volumeNames' => [],
		'colorpicker' => "diffuse_swatch",
		'colorpicker_volume' => "vol_absorption_swatch",
	}
	
	@@default_settings_scene = {
		############    Camera   ############
		'camera_type' => 'SketchUp',
		'hither'=> 0.1,
		'yon' => 100,
		'shutteropen' => 0.0,
		'shutterclose' => 1.0,
		'shutterdistribution' => 'uniform',
		'lensradius' => 0.006250,
		'aperture' => 2.8,
		'focaldistance' => 1.0,
		'frameaspectratio' => 1.333333,
		'autofocus' => false,
		#'fov' => format("%.2f", Sketchup.active_model.active_view.camera.fov), # camera angle, not currently in use
		'distribution' => 'uniform',
		'power' => 1,
		'blades' => 6,
		'camera_scale' => 7.31, #seems to work only in Blender
		'use_clipping' => false, #GUI
		'use_dof_bokeh'=>false, #GUI
		'focus_type' => 'manual', #GUI
		'use_architectural'=>false, #GUI
		'shiftX' => 0.0, #GUI
		'shiftY' => 0.0, #GUI
		'use_ratio' => false, #GUI
		'use_motion_blur'=>false, #GUI
		#'focal_length' => format("%.5f", Sketchup.active_model.active_view.camera.focal_length), #GUI
		
		############   Environment   ############
		'environment_light_type'=> 'sunsky',
		'environment_infinite_lightgroup' => 'environment',
		'environment_infinite_L_R' => Sketchup.active_model.rendering_options["BackgroundColor"].red / 255.0, #environment color red component
		'environment_infinite_L_G' => Sketchup.active_model.rendering_options["BackgroundColor"].green / 255.0, #environment color green component
		'environment_infinite_L_B' => Sketchup.active_model.rendering_options["BackgroundColor"].blue / 255.0, #environment color green component
		'environment_infinite_gain' => 1.0,
		'environment_infinite_mapping' => 'latlong',
		'environment_infinite_mapname' => '',
		'environment_infinite_rotatex' => 0,
		'environment_infinite_rotatey' => 0,
		'environment_infinite_rotatez' => 0,
		'environment_infinite_gamma' => 1.0,
		'environment_sky_lightgroup' => 'sky',
		'environment_sky_gain' => 1.0,
		'environment_sky_turbidity' => 2.2,
		'environment_sun_lightgroup' => 'sun',
		'environment_sun_gain' => 1.0,
		'environment_sun_relsize' => 1.0,
		'environment_sun_turbidity' => 2.2,
		'environment_use_sun' => true,
		'environment_use_sky' => true,
		'use_environment_infinite_sun' => false, #GUI
		'environment_infinite_sun_lightgroup' => 'sun', #for full GUI
		'environment_infinite_sun_gain' => 1.0, #for full GUI
		'environment_infinite_sun_relsize' => 1.0, #for full GUI
		'environment_infinite_sun_turbidity' => 2.2, #for full GUI

		############  Film   ############
		'aspectratio_type' => "aspectratio_sketchup_view",
		'aspectratio_fixed_ratio' => 0.666666,
		'aspectratio_numerator' => 2.0,
		'aspectratio_denominator' => 3.0,
		'aspectratio_fixed_orientation' => "landscape",
		'aspectratio_resolution_interface' => true,
		'aspectratio_skp_res_type' => "aspectratio_skp_view",
		'film_type' => "fleximage",
		'fleximage_premultiplyalpha' => false,
		'fleximage_xresolution' => 800,
		'fleximage_yresolution' => 600,
		'fleximage_resolution_percent' => 100,
		'fleximage_filterquality' => 4,
		'fleximage_ldr_clamp_method' => "lum",
		'fleximage_write_exr' => false,
		'fleximage_write_exr_channels' => "RGB",
		'fleximage_write_exr_halftype' => true,
		'fleximage_write_exr_compressiontype' => "PIZ (lossless)",
		'fleximage_write_exr_applyimaging' => true,
		'fleximage_write_exr_gamutclamp' => true,
		'fleximage_write_exr_ZBuf' => false,
		'fleximage_write_exr_zbuf_normalizationtype' => "None",
		'fleximage_write_png' => true,
		'fleximage_write_png_channels' => "RGB",
		'fleximage_write_png_16bit' => false,
		'fleximage_write_png_gamutclamp' => true,
		'fleximage_write_png_ZBuf' => false,
		'fleximage_write_png_zbuf_normalizationtype' => "Min/Max",
		'fleximage_write_tga' => false,
		'fleximage_write_tga_channels' => "RGB",
		'fleximage_write_tga_gamutclamp' => true,
		'fleximage_write_tga_ZBuf' => false,
		'fleximage_write_tga_zbuf_normalizaziontype' => "Min/Max",
		'fleximage_write_resume_flm' => false,
		'fleximage_restart_resume_flm' => false,
		'fleximage_filename' => "SU2LUX_rendered_image",
		'fleximage_writeinterval' => 180,
		'fleximage_displayinterval' => 20,
		'fleximage_outlierrejection_k' => 0,
		'fleximage_debug' => false,
		'fleximage_render_time' => "infinite",
		'fleximage_haltspp' => 500,
		'fleximage_halttime' => 60,
		'fleximage_colorspace_red_x' => 0.63, #GUI
		'fleximage_colorspace_red_y' => 0.34, #GUI
		'fleximage_colorspace_green_x' => 0.31, #GUI
		'fleximage_colorspace_green_y' => 0.595, #GUI
		'fleximage_colorspace_blue_x' => 0.155, #GUI
		'fleximage_colorspace_blue_y' => 0.07, #GUI
		'fleximage_colorspace_white_x' => 0.314275, #GUI
		'fleximage_colorspace_white_y' => 0.329411, #GUI
		'fleximage_tonemapkernel' => 'reinhard',
		'fleximage_reinhard_prescale' => 1.0,
		'fleximage_reinhard_postscale' => 1.0,
		'fleximage_reinhard_burn' => 0.5,
		'fleximage_linear_sensitivity' => 50.0,
		'fleximage_linear_exposure' => 1.0,
		'fleximage_linear_fstop' => 2.8,
		'fleximage_linear_gamma' => 2.2,
		'fleximage_contrast_ywa' => 1.0,
		'fleximage_cameraresponse' => "",
		'fleximage_gamma' => 2.2,
		'fleximage_linear_use_preset' => false,
		'fleximage_linear_camera_type' => "photo",
		'fleximage_linear_cinema_exposure' => "180-deg",
		'fleximage_linear_cinema_fps' => "25 FPS",
		'fleximage_linear_photo_exposure' => "1/125",
		'fleximage_linear_use_half_stop' => "false",
		'fleximage_linear_hf_stopF' => 2.8,
		'fleximage_linear_hf_stopT' => 3.3,
		'fleximage_linear_iso' => "100",
		'fleximage_use_colorspace_preset' => true,
		'fleximage_use_colorspace_whitepoint' => true,
		'fleximage_use_colorspace_gamma' => true,
		'fleximage_use_colorspace_whitepoint_preset' => true,
		'fleximage_colorspace_wp_preset' => "D65 - daylight, 6504",
		'fleximage_colorspace_gamma' => 2.2,
		'fleximage_colorspace_preset_white_x' => 0.314275,
		'fleximage_colorspace_preset_white_y' => 0.329411,
		'fleximage_colorspace_preset' => 'sRGB - HDTV (ITU-R BT.709-5)',
		
		############   System   ############
		'runluxrender' => "ask",
		'texexport' => "skp",
		'exp_distorted' => true, # export distorted textures
		'export_file_path' => "",
		'export_luxrender_path' => "",
		'geomexport' => 'ply',
		'priority' => 'low',
		'copy_textures' => true,
		'preview_size' => 140,
		'preview_time' => 2,
	}
	@@allDefaultSettings = @@default_settings_render.merge(@@default_settings_texture_and_volume).merge(@@default_settings_global).merge(@@default_settings_scene)	
		
	##
	#
	##
	def initialize(modelID)
	    puts "initializing LuxRender settings"
        @model_id = modelID
		singleton_class = (class << self; self; end)
		@model = Sketchup.active_model
        @attributedictionary = LuxrenderAttributeDictionary.new(@model)
		@view = @model.active_view
		
		# clone settings to this object's settings
		@settings_render = @@default_settings_render.clone
		@settings_scene = @@default_settings_scene.clone
		@settings_texture_and_volume = @@default_settings_texture_and_volume.clone
		@settings_global = @@default_settings_global.clone
		
		@settings_interface = @settings_render.merge(@settings_scene).merge(@settings_texture_and_volume)
		@settings = @settings_interface.merge(@@default_settings_global.clone)
		
		singleton_class.module_eval do			
			define_method("[]") do |key| 
				defaultValue = @@allDefaultSettings[key]
				return @attributedictionary.get_attribute("luxrender_settings", key, defaultValue)
			end
				
			#puts "creating methods to access and modify LuxRender settings"
			   			
			@@allDefaultSettings.each do |key, defaultValue|
				# create getter methods to access any parameter; calling @lrs.someattribute will actually call @attributedictionary.get_attribute("luxrender_settings", someattribute, someattributesdefaultvalue)
				define_method(key) {@attributedictionary.get_attribute("luxrender_settings", key, defaultValue) }
				# create setter methods for all parameters
				case key
					when(LuxrenderSettings::ui_refreshable?(key))# create setter methods for path fields
						# puts "OBJECT IS REFRESHABLE!"
						define_method("#{key}=") do |new_value|
							@attributedictionary.set_attribute("luxrender_settings", key, new_value)
							# todo: check if the following two lines do something useful (update interface?)
							scene_settings_editor = SU2LUX.get_editor(@model_id, "scenesettings")
							scene_settings_editor.updateSettingValue(key) if scene_settings_editor
						end
					else # create setter methods for other fields
						define_method("#{key}=") { |new_value| @attributedictionary.set_attribute("luxrender_settings", key, new_value) }
				end #end case key
			end #end settings.each
		end # end module_eval
		
		#puts "intitialized settings, volumes:"
		#puts self.volumeNames
        #puts "done initializing LuxRender settings"
	end #end initialize

	def reset
            puts "resetting LuxRender Settings"
			@settings.each do |key, value|
				@attributedictionary.set_attribute("luxrender_settings", key, value)
			end
			#@attributedictionary.set_attribute("luxrender_settings", 'fov', format("%.2f", @model.active_view.camera.fov))
			#@attributedictionary.set_attribute("luxrender_settings", 'focal_length', format("%.2f", @model.active_view.camera.focal_length))
			@attributedictionary.set_attribute("luxrender_settings", 'fleximage_xresolution', @model.active_view.vpwidth)
			@attributedictionary.set_attribute("luxrender_settings", 'fleximage_yresolution', @model.active_view.vpheight)
	end #END reset
	
	def reset_volumes_and_textures
		@settings_texture_and_volume = @@default_settings_texture_and_volume
		
		# set values in attribute dictionary
		@attributedictionary.set_attribute("luxrender_settings", 'proceduralTextureNames', [])
        @attributedictionary.set_attribute("luxrender_settings", 'volumeNames', [])
		@attributedictionary.set_attribute("luxrender_settings", 'colorpicker', "diffuse_swatch")
        @attributedictionary.set_attribute("luxrender_settings", 'colorpicker_volume', "vol_absorption_swatch")
		
	end
	
	

    ##
    #   return render setting keys
    ##

    def rendersettingkeys()
        return @settings_render.keys
    end

	##
	#
	##
	def LuxrenderSettings::ui_refreshable?(id)
		ui_refreshable_settings = [
            'export_file_path',
            'export_luxrender_path',
			'environment_infinite_mapname'
		]
		return (ui_refreshable_settings.include?(id)) ? true : false
	end # END LuxrenderSettings::ui_refreshable?
    
    def reset_viewparams
        #@attributedictionary.set_attribute("luxrender_settings", 'fov', format("%.2f", @model.active_view.camera.fov))
        #@attributedictionary.set_attribute("luxrender_settings", 'focal_length', format("%.2f", @model.active_view.camera.focal_length))
        @attributedictionary.set_attribute("luxrender_settings", 'fleximage_xresolution', @model.active_view.vpwidth)
        @attributedictionary.set_attribute("luxrender_settings", 'fleximage_yresolution', @model.active_view.vpheight)
    end
	
	def load_from_model
		return @attributedictionary.load_from_model("luxrender_settings")
	end #END load_from_model
	
	#def save_to_model # note: all changes are saved to model instantly
    #   puts "LuxrenderSettings.rb calling attribute dictionary to save settings to SketchUp file"
	#	@model.start_operation "SU2LUX settings saved" # start undo operation block
	#	puts "SAVE TO MODEL CALLED FROM LUXRENDERSETTINGS"
    #   if(@dict)
    #        @attributedictionary.save_to_model(@dict)
    #    end
	#	@model.commit_operation # end undo operation block
	#end #END save_to_model
	
	def get_names
		settings = []
		@settings.each { |key, value|
			settings.push(key)
		}
		return settings
	end #END get_names
    
	def get_names_render
		rendersettings = []
		@settings_render.each { |key, value|
			rendersettings.push(key)
		}
		return rendersettings
	end
        
	def get_names_scene
		scenesettings = []
		@settings_scene.each { |key, value|
			scenesettings.push(key)
		}
		return scenesettings
	end
    
	def get_attributedictionary
		return @attributedictionary
	end
    
	
end # END class LuxrenderSettings