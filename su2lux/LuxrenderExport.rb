class LuxrenderExport
	attr_reader :count_tri
	attr_reader :used_materials
    
	def initialize(export_file_path, os_separator, lrs, mat_editor, model)
        @scene_id = Sketchup.active_model.definitions.entityID
		@lrs = lrs
		@model = model
		@material_editor = mat_editor
		#puts 'exporting to ' + export_file_path.to_s
		@export_file_path = export_file_path # assume that this is sanitised already
		@model_name = File.basename(@export_file_path).split(".")[0] # remove folder structure, remove extension
        @instance_name = 0
		@os_separator=os_separator
		@has_portals = false
        @mat_step = 0 # monitors export progress
        @current_step = 0
        @total_step = 0
        @texexport = "skp"
        @texfolder = ""
		@nr_distorted_materials = 0
        @distorted_faces = [] # [face, skp_mat, dist_index]
		@group_definition_hash = {}
		@component_material_definitions = []
		@component_skp_materials = []
		@nr_component_materials = 0
	end # END initialize

	def reset
		@has_portals = false
		@fm_materials = {}
		@count_faces = 0
		@exp_default_uvs = false
        @instance_name = 0
        @lrs.fleximage_xresolution = Sketchup.active_model.active_view.vpwidth unless @lrs.fleximage_xresolution
		@lrs.fleximage_yresolution = Sketchup.active_model.active_view.vpheight unless @lrs.fleximage_yresolution
        if (@lrs.aspectratio_type == "aspectratio_sketchup_view" && @lrs.aspectratio_skp_res_type == "aspectratio_skp_view")
            xres = Sketchup.active_model.active_view.vpwidth # * @lrs.fleximage_resolution_percent.to_i / 100.0
            @lrs.fleximage_xresolution = xres # needed for fov calculation
            yres = Sketchup.active_model.active_view.vpheight # * @lrs.fleximage_resolution_percent.to_i / 100.0
            @lrs.fleximage_yresolution = yres # needed for fov calculation
        end
	end #END reset

	def export_global_settings(out)
		out.puts "# LuxRender Scene File"
		out.puts "# Exported by SU2LUX #{SU2LUX::SU2LUX_VERSION}"
		out.puts ""
	end # END export_global_settings
    
    def export_renderer(out)
        case @lrs.sintegrator_type
            when "directlighting", "path", "bidirectional"
                out.puts "Renderer \"sampler\""
            when "hybrid"
                out.puts "Renderer \"hybrid\""
                out.puts "\t\"bool opencl.gpu.use\" [\"true\"]"
            when "sppm"
                out.puts "Renderer \"sppm\""
            when "luxcore_pathcpu"
                out.puts "Renderer \"luxcore\""
                out.puts "\t\"string config\" [\"opencl.gpu.use = 1\" \"opencl.cpu.use = 1\" \"renderengine.type = PATHCPU\"  \"accelerator.type = AUTO\"]"
            when "luxcore_pathocl"
                out.puts "Renderer \"luxcore\""
                out.puts "\t\"string config\" [\"opencl.gpu.use = 1\" \"opencl.cpu.use = 1\" \"renderengine.type = PATHOCL\" \"accelerator.type = AUTO\"]"
            when "luxcore_biaspathcpu"
                out.puts "Renderer \"luxcore\""
                out.puts "\t\"string config\" [\"opencl.gpu.use = 0\" \"opencl.cpu.use = 1\" \"renderengine.type = BIASPATHCPU\" \"tile.multipass.enable = 1\" \"accelerator.type = AUTO\" \"biaspath.clamping.radiance.maxvalue = 0\"  \"biaspath.clamping.pdf.value = 0\"]"
            when "luxcore_biaspathocl"
                out.puts "Renderer \"luxcore\""
                out.puts "\t\"string config\" [\"opencl.gpu.use = 1\" \"opencl.cpu.use = 1\" \"renderengine.type = BIASPATHOCL\" \"tile.multipass.enable = 1\" \"accelerator.type = AUTO\" \"biaspath.clamping.radiance.maxvalue = 0\"  \"biaspath.clamping.pdf.value = 0\"]"
            when "luxcore_bidircpu"
                out.puts "Renderer \"luxcore\""
                out.puts "\t\"string config\" [\"opencl.gpu.use = 0\" \"opencl.cpu.use = 1\" \"renderengine.type = BIDIRCPU\" \"accelerator.type = AUTO\"]"
            when "luxcore_bidircpuvm"
                out.puts "Renderer \"luxcore\""
                out.puts "\t\"string config\" [\"opencl.gpu.use = 1\" \"opencl.cpu.use = 1\" \"opencl.gpu.workgroup.size = 64\" \"opencl.kernelcache = NONE\" \"renderengine.type = PATHCPU\" \"accelerator.type = AUTO\"]"
        end
        out.puts ""
    end

	def export_camera(view, out)
		user_camera = view.camera
		user_eye = user_camera.eye
		user_target=user_camera.target
		user_up=user_camera.up

		out_user_target = "%12.6f" %(user_target.x.to_m.to_f) + " " + "%12.6f" %(user_target.y.to_m.to_f) + " " + "%12.6f" %(user_target.z.to_m.to_f)
		out_user_up = "%12.6f" %(user_up.x) + " " + "%12.6f" %(user_up.y) + " " + "%12.6f" %(user_up.z)
		out.puts " LookAt"
		out.puts "%12.6f" %(user_eye.x.to_m.to_f) + " " + "%12.6f" %(user_eye.y.to_m.to_f) + " " + "%12.6f" %(user_eye.z.to_m.to_f)
		out.puts out_user_target
		out.puts out_user_up
		out.print "\n"

		camera_scale = 1.0
        
		tempCamType = 'perspective' # can be environment, perspective or orthographic; @lrs.camera_type can only be 'SketchUp' or 'environment' 
		if(@lrs.camera_type == 'environment')
			tempCamType = 'environment' 
		else
			tempCamType = Sketchup.active_model.active_view.camera.perspective? ? 'perspective' : 'orthographic'
		end
		
		out.puts "Camera \"#{tempCamType}\""
		case tempCamType
			when "perspective"
				fov = compute_fov(@lrs.fleximage_xresolution, @lrs.fleximage_yresolution)
				out.puts "	\"float fov\" [%.6f" %(fov) + "]"
			when "orthographic"
                # scale is taken into account in screenwindow declaration
			when "environment"
				# out.puts "Camera \"#{@lrs.camera_type}\""
		end
		
		if (@lrs.use_clipping)
			out.puts "\t\"float hither\" [" + "%.6f" %(@lrs.hither) + "]"
			out.puts "\t\"float yon\" [" + "%.6f" %(@lrs.yon) + "]"
		end
		
		if (@lrs.use_dof_bokeh)
			focal_length = format("%.2f", Sketchup.active_model.active_view.camera.focal_length)
            radiusfromaperture = 0.0005 * focal_length.to_f / @lrs.aperture.to_f
			out.puts "\t\"float lensradius\" [%.6f" %(radiusfromaperture) + "]"
			case @lrs.focus_type
				when "autofocus"
					autofocus = @lrs.autofocus ? "true" : "false"
					out.puts "\t\"bool autofocus\" [\"" + autofocus + "\"]"
				when "manual"
					out.puts "\t\"float focaldistance\" [%.6f" %(@lrs.focaldistance.to_f) + "]"
			end
			out.puts "\t\"string distribution\" [\"" + @lrs.distribution + "\"]"
			out.puts "\t\"integer power\" [#{@lrs.power.to_i}]"
			out.puts "\t\"integer blades\" [#{@lrs.blades.to_i}]"
		end
		
		if (@lrs.use_architectural)
			if (@lrs.use_ratio)
				out.puts "\t\"float frameaspectratio\" [" + "%.6f" %(@lrs.frameaspectratio) + "]"
			end
		end
		
		if (@lrs.use_motion_blur)
			out.puts "\t\"float shutteropen\" [%.6f" %(@lrs.shutteropen) + "]"
			out.puts "\t\"float shutterclose\" [%.6f" %(@lrs.shutterclose) + "]"
			out.puts "\t\"string shutterdistribution\" [\"" + @lrs.shutterdistribution + "\"]"
		end
		
		sw = compute_screen_window(tempCamType)
		out.puts	"\t\"float screenwindow\" [" + "%.6f" %(sw[0]) + " " + "%.6f" %(sw[1]) + " " + "%.6f" %(sw[2]) + " " + "%.6f" %(sw[3]) +"]\n"
		out.print "\n"
	end # END export_camera

	def compute_fov(xres, yres)
        width = xres.to_f
        height = yres.to_f
        view = Sketchup.active_model.active_view
		camera = view.camera
        centerx = view.screen_coords(camera.target)[0].to_f
        centery = view.screen_coords(camera.target)[1].to_f
        vcenterx = view.center[0].to_f
        vcentery = view.center[1].to_f
		fov_sketchup = camera.fov # vertical angle if aspect ratio is not set, horizontal angle if it is
        skp_ratio = camera.aspect_ratio # 0.0, unless aspect ratio is fixed
        lux_ratio = width/height
        view_ratio = view.vpwidth.to_f/view.vpheight.to_f
        
        if ((centerx-vcenterx).abs>1.0 || (centery-vcentery).abs>1.0) # two point perspective
            # calculate angle by adding a virtual point, then getting distance to the target point in screen space
            puts "exporting camera, two point perspective"
            eye = camera.eye
            target = camera.target
            helper_vertical_distance = 200.0; # inches
            target_distance = ((eye[0]-target[0])**2 + (eye[1]-target[1])**2)**0.5 # inches
            helper_point = Geom::Point3d.new(target[0], target[1], target[2]+helper_vertical_distance)
            helper_height = (view.screen_coords(helper_point)[1] - view.screen_coords(target)[1]).abs
            helper_fraction = helper_height / view.vpheight
            if (skp_ratio != 0.0) # sketchup aspect ratio fixed
                if (skp_ratio > 1.0) # landscape
                    puts "fixed aspect ratio, landscape"
                    fraction_tan = helper_vertical_distance/target_distance
                    if view_ratio < skp_ratio
                        # if view ratio is more vertical than render ratio, fraction_tan should be multiplied by viewratio/renderratio
                        # puts "adjusting for horizontal bars" (note: actually, vertical bars?)
                        fraction_tan = fraction_tan * view_ratio / skp_ratio
                    end
                    total_tan = (0.5/helper_fraction) * fraction_tan
                    calculated_angle = 2*Math.atan(total_tan)
                    fov = calculated_angle.radians
                else # portrait
                    puts "fixed aspect ratio, portrait"
                    fraction_tan = helper_vertical_distance/target_distance
                    total_tan = (0.5/helper_fraction) * fraction_tan
                    calculated_angle = 2*Math.atan(total_tan)
                    fov_vertical = calculated_angle.radians
                    fov = 2 * (Math.atan(Math.tan(fov_vertical.degrees/2)*lux_ratio)).radians
                end
            else # free aspect ratio
                puts "free aspect ratio"
                half_tan = (0.5*view.vpheight/helper_height) * (helper_vertical_distance/target_distance) # (pixel screen space) * (3d space)
                calculated_angle = 2*Math.atan(half_tan)
                fov = calculated_angle.radians
            end
        else # not two point perspective
            puts "exporting ordinary camera"
            if (skp_ratio != 0.0) # sketchup aspect ratio fixed
                if (skp_ratio > 1.0) # landscape
                    puts "fixed aspect ratio, landscape"
                    fov = 2 * (Math.atan(Math.tan(fov_sketchup.degrees/2)/lux_ratio)).radians
                else
                    puts "fixed aspect ratio, portrait"
                    fov = fov_sketchup
                end
            else # free aspect ratio
                if (view.vpheight > view.vpwidth) # portrait
                    puts "free aspect ratio, portrait"
                    fov = 2 * (Math.atan(lux_ratio*Math.tan(fov_sketchup.degrees/2))).radians
                else # landscape
                    puts "free aspect ratio, landscape"
                    fov = fov_sketchup
                end
            end
        end
        #puts "calculated fov:"
        #puts fov
		return fov
	end # END compute_fov

	def compute_screen_window(camType)
        cam_shiftX = 0.0
		cam_shiftY = 0.0
        if (@lrs.use_architectural)  # if lens shift is on
            cam_shiftX = @lrs.shiftX.to_f
            cam_shiftY = @lrs.shiftY.to_f
        end
		ratio = @lrs.fleximage_xresolution.to_f / @lrs.fleximage_yresolution.to_f
		inv_ratio = 1.0 / ratio
        
        # two point perspective logic
        camtarget = Sketchup.active_model.active_view.camera.target
        skp_view_height = Sketchup.active_model.active_view.vpheight.to_f
        skp_view_width = Sketchup.active_model.active_view.vpwidth.to_f
        skpratio = skp_view_width/skp_view_height
        target_x = Sketchup.active_model.active_view.screen_coords(camtarget)[0].to_f
        target_y = Sketchup.active_model.active_view.screen_coords(camtarget)[1].to_f
        target_fraction_x_skp = 0.0
        target_fraction_y_skp = 0.0
        if (ratio == skpratio)
            puts "render ratio equals sketchup ratio"
            target_fraction_x_skp = ((target_x - 0.5*skp_view_width)/skp_view_width) * ratio
            target_fraction_y_skp = target_y / skp_view_height - 0.5
        elsif (ratio > 1.0 && skpratio > ratio)
            # landscape, vertical bars
            puts "landscape, vertical bars"
            target_fraction_x_skp = ((target_x - 0.5*skp_view_width)/skp_view_width)*skpratio
            target_fraction_y_skp = target_y / skp_view_height - 0.5
        elsif (ratio < 1.0 && skpratio < ratio)
            # portrait, horizontal bars
            puts "portrait, horizontal bars"
            target_fraction_x_skp = ((target_x - 0.5*skp_view_width)/skp_view_width)
            target_fraction_y_skp = (target_y / skp_view_height - 0.5)/ratio
        elsif (ratio > 1.0 && skpratio < ratio)
            # landscape, horizontal bars
            puts "landscape, horizontal bars"
            target_fraction_x_skp = ((target_x - 0.5*skp_view_width)/skp_view_width) * ratio
            target_fraction_y_skp = ((target_y - 0.5*skp_view_height)/skp_view_height)*ratio/skpratio
        elsif (ratio < 1.0 && skpratio > ratio)
            # portrait, vertical bars
            puts "portrait, vertical bars"
            target_fraction_x_skp = ((target_x - 0.5*skp_view_width)/skp_view_width)/ratio
            target_fraction_y_skp = ((target_y / skp_view_height) - 0.5)/ratio
        end
        offsetx = -2 * target_fraction_x_skp
        offsety = 2 * target_fraction_y_skp
        # end two point perspective logic
        
        if(camType == 'orthographic')
            imageheight = Sketchup.active_model.active_view.camera.height.to_m
            imagewidth = ratio * imageheight
            screen_window = [-0.5*imagewidth, 0.5*imagewidth, -0.5*imageheight, 0.5*imageheight] # lens shift not used here
        else # perspective or environment
			if(ratio > 1.0)
				screen_window = [2 * cam_shiftX - ratio + offsetx, 2 * cam_shiftX + ratio + offsetx, 2 * cam_shiftY - 1.0 + offsety, 2 * cam_shiftY + 1.0 + offsety]
				#screen_window = [2 * cam_shiftX - ratio, 2 * cam_shiftX + ratio, 2 * cam_shiftY - 1.0, 2 * cam_shiftY + 1.0]
				else
				screen_window = [2 * cam_shiftX - 1.0 + offsetx, 2 * cam_shiftX + 1.0 + offsetx, 2 * cam_shiftY - inv_ratio + offsety, 2 * cam_shiftY + inv_ratio + offsety]
            end
        end
	end # END compute_screen_window

	def export_film(out,file_basename)
		out.puts "Film \"fleximage\""
		percent = @lrs.fleximage_resolution_percent.to_i / 100.0
        xres = (@lrs.fleximage_xresolution.to_i * percent).round
        yres = (@lrs.fleximage_yresolution.to_i * percent).round
        
		out.puts "\t\"integer xresolution\" [#{xres.to_i}]"
		out.puts "\t\"integer yresolution\" [#{yres.to_i}]"
        case @lrs.fleximage_render_time
            when "halt_time"
                out.puts "\t\"integer halttime\" [" + (60*@lrs.fleximage_halttime.to_i).to_s + "]"
            when "halt_spp"
                out.puts "\t\"integer haltspp\" [#{@lrs.fleximage_haltspp.to_i}]"
        end
		out.puts "\t\"integer filterquality\" [#{@lrs.fleximage_filterquality.to_i}]"
		pre_alpha = @lrs.fleximage_premultiplyalpha ? "true" : "false"
		out.puts "\t\"bool premultiplyalpha\" [\"#{pre_alpha}\"]\n"
		out.puts "\t\"integer displayinterval\" [#{@lrs.fleximage_displayinterval.to_i}]"
		out.puts "\t\"integer writeinterval\" [#{@lrs.fleximage_writeinterval.to_i}]"
		out.puts "\t\"string ldr_clamp_method\" [\"#{@lrs.fleximage_ldr_clamp_method}\"]"
		out.puts "\t\"string tonemapkernel\" [\"#{@lrs.fleximage_tonemapkernel}\"]"
		case @lrs.fleximage_tonemapkernel
			when "reinhard"
				out.puts "\t\"float reinhard_prescale\" [#{"%.6f" %(@lrs.fleximage_reinhard_prescale)}]\n"
				out.puts "\t\"float reinhard_postscale\" [#{"%.6f" %(@lrs.fleximage_reinhard_postscale)}]\n"
				out.puts "\t\"float reinhard_burn\" [#{"%.6f" %(@lrs.fleximage_reinhard_burn)}]\n"
			when "linear"
				if (@lrs.fleximage_linear_use_preset)
					out.puts "\t\"float linear_sensitivity\" [#{"%.6f" %(@lrs.fleximage_linear_iso)}]\n"
					if (@lrs.fleximage_linear_use_half_stop == true)
						fstop = @lrs.fleximage_linear_hf_stopT
					else
						fstop = @lrs.fleximage_linear_hf_stopF
					end
					out.puts "\t\"float linear_fstop\" [#{"%.6f" %(fstop)}]\n"

					case @lrs.fleximage_linear_camera_type
						when "photo"
							exposure_preset = @lrs.fleximage_linear_photo_exposure
						when "cinema"
							exposure_preset = @lrs.fleximage_linear_cinema_exposure
					end
					exposure = get_exposure(@lrs.fleximage_linear_camera_type, exposure_preset, @lrs.fleximage_linear_cinema_fps)
					out.puts "\t\"float linear_exposure\" [#{"%.6f" %(exposure)}]\n"
				else
					out.puts "\t\"float linear_sensitivity\" [#{"%.6f" %(@lrs.fleximage_linear_sensitivity)}]\n"
					out.puts "\t\"float linear_exposure\" [#{"%.6f" %(@lrs.fleximage_linear_exposure)}]\n"
					out.puts "\t\"float linear_fstop\" [#{"%.6f" %(@lrs.fleximage_linear_fstop)}]\n"
				end
			when "contrast"
				out.puts "\t\"float contrast_ywa\" [#{"%.6f" %(@lrs.fleximage_contrast_ywa)}]\n"
			when "maxwhite"
		end
		exr = @lrs.fleximage_write_exr ? "true" : "false"
		out.puts "\t\"bool write_exr\" [\"#{exr}\"]\n"
		if (@lrs.fleximage_write_exr)
			out.puts "\t\"string write_exr_channels\" [\"#{@lrs.fleximage_write_exr_channels}\"]"
			bits = @lrs.fleximage_write_exr_halftype ? "true" : "false"
			out.puts "\t\"bool write_exr_halftype\" [\"#{bits}\"]\n"
			out.puts "\t\"string write_exr_compressiontype\" [\"#{@lrs.fleximage_write_exr_compressiontype}\"]"
			if (@lrs.fleximage_write_exr_applyimaging)
				gamut = @lrs.fleximage_write_exr_gamutclamp ? "true" : "false"
				out.puts "\t\"bool write_exr_gamutclamp\" [\"#{gamut}\"]\n"
			end
			if (@lrs.fleximage_write_exr_ZBuf)
				out.puts "\t\"string write_exr_zbuf_normalizationtype\" [\"#{@lrs.fleximage_write_exr_zbuf_normalizationtype}\"]"
			end
		end
		png = @lrs.fleximage_write_png ? "true" : "false"
		out.puts "\t\"bool write_png\" [\"#{png}\"]\n"
		if (@lrs.fleximage_write_png)
			out.puts "\t\"string write_png_channels\" [\"#{@lrs.fleximage_write_png_channels}\"]"
			bits = @lrs.fleximage_write_png_16bit ? "true" : "false"
			out.puts "\t\"bool write_png_16bit\" [\"#{bits}\"]\n"
			gamut = @lrs.fleximage_write_png_gamutclamp ? "true" : "false"
			out.puts "\t\"bool write_png_gamutclamp\" [\"#{gamut}\"]\n"
			if (@lrs.fleximage_write_png_ZBuf)
				out.puts "\t\"string write_png_zbuf_normalizationtype\" [\"#{@lrs.fleximage_write_png_zbuf_normalizationtype}\"]"
			end
		end
		tga = @lrs.fleximage_write_tga ? "true" : "false"
		out.puts "\t\"bool write_tga\" [\"#{tga}\"]\n"
		if (@lrs.fleximage_write_tga)
			out.puts "\t\"string write_tga_channels\" [\"#{@lrs.fleximage_write_tga_channels}\"]"
			gamut = @lrs.fleximage_write_tga_gamutclamp ? "true" : "false"
			out.puts "\t\"bool write_exr_gamutclamp\" [\"#{gamut}\"]\n"
			#if (@lrs.fleximage_write_tga_ZBuf)
			#	out.puts "\t\"string write_tga_zbuf_normalizationtype\" [\"#{@lrs.fleximage_write_tga_zbuf_normalizationtype}\"]"
			#end
		end
		flm = @lrs.fleximage_write_resume_flm ? "true" : "false"
		out.puts "\t\"bool write_resume_flm\" [\"#{flm}\"]\n"
		flm = @lrs.fleximage_restart_resume_flm ? "true" : "false"
		out.puts "\t\"bool restart_resume_flm\" [\"#{flm}\"]\n"
		out.puts "\t\"string filename\" [\"#{file_basename}\"]"
        dbg = @lrs.fleximage_debug ? "true" : "false"
		out.puts "\t\"bool debug\" [\"#{dbg}\"]\n"
		if (@lrs.fleximage_use_colorspace_preset)
			#SU2LUX.dbg_p @lrs.fleximage_colorspace_preset
			case @lrs.fleximage_colorspace_preset
				when "sRGB - HDTV (ITU-R BT.709-5)"
					cspacewhiteX = 0.314275
					cspacewhiteY = 0.329411 # sRGB
					cspaceredX = 0.63
					cspaceredY = 0.34
					cspacegreenX = 0.31
					cspacegreenY = 0.595
					cspaceblueX = 0.155
					cspaceblueY = 0.07
				when "ROMM RGB"
					cspacewhiteX = 0.346
					cspacewhiteY = 0.359 # D50
					cspaceredX = 0.7347
					cspaceredY = 0.2653
					cspacegreenX = 0.1596
					cspacegreenY = 0.8404
					cspaceblueX = 0.0366
					cspaceblueY = 0.0001
				when "Adobe RGB 98"
					cspacewhiteX = 0.313
					cspacewhiteY = 0.329 # D65
					cspaceredX = 0.64
					cspaceredY = 0.34
					cspacegreenX = 0.21
					cspacegreenY = 0.71
					cspaceblueX = 0.15
					cspaceblueY = 0.06
				when "Apple RGB"
					cspacewhiteX = 0.313
					cspacewhiteY = 0.329 # D65
					cspaceredX = 0.625
					cspaceredY = 0.34
					cspacegreenX = 0.28
					cspacegreenY = 0.595
					cspaceblueX = 0.155
					cspaceblueY = 0.07
				when "NTSC (FCC 1953, ITU-R BT.470-2 System M)"
					cspacewhiteX = 0.310
					cspacewhiteY = 0.316 # C
					cspaceredX = 0.67
					cspaceredY = 0.33
					cspacegreenX = 0.21
					cspacegreenY = 0.71
					cspaceblueX = 0.14
					cspaceblueY = 0.08
				when "NTSC (FCC 1953, ITU-R BT.470-2 System M)"
					cspacewhiteX = 0.313
					cspacewhiteY = 0.329 # D65
					cspaceredX = 0.63
					cspaceredY = 0.34
					cspacegreenX = 0.31
					cspacegreenY = 0.595
					cspaceblueX = 0.155
					cspaceblueY = 0.07
				when "PAL/SECAM (EBU 3213, ITU-R BT.470-6)"
					cspacewhiteX = 0.313
					cspacewhiteY = 0.329 # D65
					cspaceredX = 0.64
					cspaceredY = 0.33
					cspacegreenX = 0.29
					cspacegreenY = 0.60
					cspaceblueX = 0.15
					cspaceblueY = 0.06
				when "CIE (1931) E"
					cspacewhiteX = 0.333
					cspacewhiteY = 0.333 # E
					cspaceredX = 0.7347
					cspaceredY = 0.2653
					cspacegreenX = 0.2738
					cspacegreenY = 0.7174
					cspaceblueX = 0.1666
					cspaceblueY = 0.0089
			end
			if (@lrs.fleximage_use_colorspace_gamma) # not exposed, but both values are 2.2 by default
				gamma = @lrs.fleximage_gamma
			else
				gamma = @lrs.fleximage_colorspace_gamma
			end
			if (@lrs.fleximage_colorspace_wp_preset != "use_colorspace_whitepoint") # in case of color space white point, variables have already been defined above
                if (@lrs.fleximage_colorspace_wp_preset == "use_custom_whitepoint")
                    cspacewhiteX = @lrs.fleximage_colorspace_preset_white_x
                    cspacewhiteY = @lrs.fleximage_colorspace_preset_white_y
				else
					if (((@lrs.fleximage_colorspace_wp_preset)).include?("E - "))
						cspacewhiteX = 0.333
						cspacewhiteY = 0.333
					elsif ((@lrs.fleximage_colorspace_wp_preset).include?("D50 - "))
						cspacewhiteX = 0.346
						cspacewhiteY = 0.359
					elsif ((@lrs.fleximage_colorspace_wp_preset).include?("D55 - "))
						cspacewhiteX = 0.332
						cspacewhiteY = 0.347
					elsif ((@lrs.fleximage_colorspace_wp_preset).include?("D65 - "))
						cspacewhiteX = 0.313
						cspacewhiteY = 0.329
					elsif ((@lrs.fleximage_colorspace_wp_preset).include?("D75 - "))
						cspacewhiteX = 0.299
						cspacewhiteY = 0.315
					elsif (((@lrs.fleximage_colorspace_wp_preset)).include?("A - "))
						cspacewhiteX = 0.448
						cspacewhiteY = 0.407
					elsif ((@lrs.fleximage_colorspace_wp_preset).include?("B - "))
						cspacewhiteX = 0.348
						cspacewhiteY = 0.352
					elsif ((@lrs.fleximage_colorspace_wp_preset).include?("C - "))
						cspacewhiteX = 0.310
						cspacewhiteY = 0.316
					elsif ((@lrs.fleximage_colorspace_wp_preset).include?("9300"))
						cspacewhiteX = 0.285
						cspacewhiteY = 0.293
					elsif ((@lrs.fleximage_colorspace_wp_preset).include?("F2 - "))
						cspacewhiteX = 0.372
						cspacewhiteY = 0.375
					elsif ((@lrs.fleximage_colorspace_wp_preset).include?("F7 - "))
						cspacewhiteX = 0.313
						cspacewhiteY = 0.329
					elsif ((@lrs.fleximage_colorspace_wp_preset).include?("F11 - "))
						cspacewhiteX = 0.381
						cspacewhiteY = 0.377
					end
				end
			end
			out.puts "\t\"float colorspace_white\" [#{"%.6f" %(cspacewhiteX)} #{"%.6f" %(cspacewhiteY)}]\n"
			out.puts "\t\"float colorspace_red\" [#{"%.6f" %(cspaceredX)} #{"%.6f" %(cspaceredY)}]\n"
			out.puts "\t\"float colorspace_green\" [#{"%.6f" %(cspacegreenX)} #{"%.6f" %(cspacegreenY)}]\n"
			out.puts "\t\"float colorspace_blue\" [#{"%.6f" %(cspaceblueX)} #{"%.6f" %(cspaceblueY)}]\n"
			out.puts "\t\"float gamma\" [#{"%.6f" %(gamma)}]\n"
        else # custom color space
			out.puts "\t\"float colorspace_white\" [#{"%.6f" %(@lrs.fleximage_colorspace_white_x)} #{"%.6f" %(@lrs.fleximage_colorspace_white_y)}]\n"
			out.puts "\t\"float colorspace_red\" [#{"%.6f" %(@lrs.fleximage_colorspace_red_x)} #{"%.6f" %(@lrs.fleximage_colorspace_red_y)}]\n"
			out.puts "\t\"float colorspace_green\" [#{"%.6f" %(@lrs.fleximage_colorspace_green_x)} #{"%.6f" %(@lrs.fleximage_colorspace_green_y)}]\n"
			out.puts "\t\"float colorspace_blue\" [#{"%.6f" %(@lrs.fleximage_colorspace_blue_x)} #{"%.6f" %(@lrs.fleximage_colorspace_blue_y)}]\n"
			out.puts "\t\"float gamma\" [#{"%.6f" %(@lrs.fleximage_gamma)}]\n"
		end
		out.puts "\t\"integer outlierrejection_k\" [#{@lrs.fleximage_outlierrejection_k.to_i}]"
	end # END export_film

	def get_exposure(type, shutterStr, fpsStr)
		if (type == 'photo')
			fps = 1
		else
			fps = fpsStr.split(" ")[0].to_f  # assuming fps are in form 'n FPS'
		end

		if (shutterStr == '1')
			exp = 1.0
		elsif (type == 'photo')
			exp = 1.0 / shutterStr[/(?!.*?\/).*/].to_f  # assuming still camera shutterspeed is in form '1/n'
		elsif (type == 'cinema')
			exp = (1.0 / fps) * (1 - shutterStr.split("-")[1].to_f/360) # assuming motion camera shutterspeed is in form 'n-degree'
		end
		return exp
	end

	def export_render_settings(out)
		out.puts export_surface_integrator
		out.puts export_filter
		out.puts export_sampler
		out.puts export_volume_integrator
		out.puts export_accelerator
		out.puts "\n"
	end # END export_render_settings

	def export_filter
		filter = "\n"
		filter << "PixelFilter \"#{@lrs.pixelfilter_type}\"\n"
		case @lrs.pixelfilter_type
			when "blackmanharris"
                filter << "\t\"float xwidth\" [#{"%.6f" %(@lrs.pixelfilter_blackmanharris_xwidth)}]\n"
                filter << "\t\"float ywidth\" [#{"%.6f" %(@lrs.pixelfilter_blackmanharris_ywidth)}]\n"
			when "box"
                filter << "\t\"float xwidth\" [#{"%.6f" %(@lrs.pixelfilter_box_xwidth)}]\n"
                filter << "\t\"float ywidth\" [#{"%.6f" %(@lrs.pixelfilter_box_ywidth)}]\n"
			when "gaussian"
                filter << "\t\"float xwidth\" [#{"%.6f" %(@lrs.pixelfilter_gaussian_xwidth)}]\n"
                filter << "\t\"float ywidth\" [#{"%.6f" %(@lrs.pixelfilter_gaussian_ywidth)}]\n"
                filter << "\t\"float alpha\" [#{"%.6f" %(@lrs.pixelfilter_gaussian_alpha)}]\n"
			when "mitchell"
                filter << "\t\"float xwidth\" [#{"%.6f" %(@lrs.pixelfilter_mitchell_xwidth)}]\n"
                filter << "\t\"float ywidth\" [#{"%.6f" %(@lrs.pixelfilter_mitchell_ywidth)}]\n"
                filter << "\t\"float B\" [#{"%.6f" %(@lrs.pixelfilter_mitchell_B)}]\n"
                filter << "\t\"float C\" [#{"%.6f" %(@lrs.pixelfilter_mitchell_C)}]\n"
                supersample = @lrs.pixelfilter_mitchell_supersample ? "true" : "false"
                filter << "\t\"bool supersample\" [\"" + supersample + "\"]\n"
			when "sinc"
                filter << "\t\"float xwidth\" [#{"%.6f" %(@lrs.pixelfilter_sinc_xwidth)}]\n"
                filter << "\t\"float ywidth\" [#{"%.6f" %(@lrs.pixelfilter_sinc_ywidth)}]\n"
                filter << "\t\"float tau\" [#{"%.6f" %(@lrs.pixelfilter_sinc_tau)}]\n"
			when "triangle"
                filter << "\t\"float xwidth\" [#{"%.6f" %(@lrs.pixelfilter_triangle_xwidth)}]\n"
                filter << "\t\"float ywidth\" [#{"%.6f" %(@lrs.pixelfilter_triangle_ywidth)}]\n"
		end
		return filter
	end #END export_filter

	def export_sampler
		sampler = "\n"
		sampler << "Sampler \"#{@lrs.sampler_type}\"\n"
        usevariance = @lrs.sampler_metropolis_usevariance ? "true" : "false"
        noiseaware = @lrs.sampler_noiseaware ? "true" : "false"
		case @lrs.sampler_type
			when "metropolis"
                sampler << "\t\"float largemutationprob\" [#{"%.6f" %(@lrs.sampler_metropolis_largemutationprob)}]\n"
                sampler << "\t\"integer maxconsecrejects\" [#{@lrs.sampler_metropolis_maxconsecrejects.to_i}]\n"
                sampler << "\t\"bool usevariance\" [\"#{usevariance}\"]\n"
                sampler << "\t\"bool noiseaware\" [\"#{noiseaware}\"]\n"
			when "lowdiscrepancy"
				sampler << "\t\"string pixelsampler\" [\"#{@lrs.sampler_lowdisc_pixelsampler}\"]\n"
				sampler << "\t\"integer pixelsamples\" [#{@lrs.sampler_lowdisc_pixelsamples.to_i}]\n"
                sampler << "\t\"bool noiseaware\" [\"#{noiseaware}\"]\n"
			when "random"
				sampler << "\t\"string pixelsampler\" [\"#{@lrs.sampler_random_pixelsampler}\"]\n"
				sampler << "\t\"integer pixelsamples\" [#{@lrs.sampler_random_pixelsamples.to_i}]\n"
                sampler << "\t\"bool noiseaware\" [\"#{noiseaware}\"]\n"
			when "erpt"
                sampler << "\t\"integer chainlength\" [#{@lrs.sampler_erpt_chainlength.to_i}]\n"
            when "sobol"
                sampler << "\n"
                sampler << "\t\"bool noiseaware\" [\"#{noiseaware}\"]\n"
		end
		return sampler
	end #END export_sampler

    def export_surface_integrator
        #puts "renderer is:"
        #puts @lrs.sintegrator_type
        integrator = "\n"
		case @lrs.sintegrator_type
			# "bidirectional"
			when "bidirectional", "luxcore_bidircpu", "luxcore_bidircpuvm"
				integrator << "SurfaceIntegrator \"bidirectional\"\n"
				integrator << "\t\"integer eyedepth\" [#{@lrs.sintegrator_bidir_eyedepth}]\n"
				integrator << "\t\"integer lightdepth\" [#{@lrs.sintegrator_bidir_lightdepth}]\n"
				integrator << "\t\"string lightstrategy\" [\"#{@lrs.sintegrator_bidir_strategy}\"]\n"
				integrator << "\t\"float eyerrthreshold\" [#{"%.6f" %(@lrs.sintegrator_bidir_eyerrthreshold)}]\n"
				integrator << "\t\"float lightrrthreshold\" [#{"%.6f" %(@lrs.sintegrator_bidir_lightthreshold)}]\n"
			# 'path'
			when "path", "luxcore_pathcpu", "luxcore_pathocl", "luxcore_biaspathcpu", "luxcore_biaspathocl"
				integrator << "SurfaceIntegrator \"path\"\n"
				integrator << "\t\"integer maxdepth\" [#{@lrs.sintegrator_path_maxdepth}]\n"
				environment = @lrs.sintegrator_path_include_environment ? "true" : "false"
				integrator << "\t\"bool includeenvironment\" [\"#{environment}\"]\n"
				integrator << "\t\"string rrstrategy\" [\"#{@lrs.sintegrator_path_rrstrategy}\"]\n"
				if (@lrs.sintegrator_path_rrstrategy == "probability")
					integrator << "\t\"float rrcontinueprob\" [#{"%.6f" %(@lrs.sintegrator_path_rrcontinueprob)}]\n"
				end
				integrator << "\t\"string lightstrategy\" [\"#{@lrs.sintegrator_path_strategy}\"]\n"
				integrator << "\t\"integer shadowraycount\" [#{@lrs.sintegrator_path_shadow_ray_count}]\n"
			# "distributedpath"
			when "distributedpath"
				integrator << "SurfaceIntegrator \"distributedpath\"\n"
				integrator << "\t\"string strategy\" [\"#{@lrs.sintegrator_distributedpath_strategy}\"]\n"
				bool_value = @lrs.sintegrator_distributedpath_directsampleall ? "true" : "false"
				integrator << "\t\"bool directsampleall\" [\"#{bool_value}\"]\n"
				integrator << "\t\"integer directsamples\" [#{@lrs.sintegrator_distributedpath_directsamples.to_i}]\n"
				bool_value = @lrs.sintegrator_distributedpath_indirectsampleall ? "true" : "false"
				integrator << "\t\"bool indirectsampleall\" [\"#{bool_value}\"]\n"
				integrator << "\t\"integer indirectsamples\" [#{@lrs.sintegrator_distributedpath_indirectsamples.to_i}]\n"
				integrator << "\t\"integer diffusereflectdepth\" [#{@lrs.sintegrator_distributedpath_diffusereflectdepth.to_i}]\n"
				integrator << "\t\"integer diffusereflectsamples\" [#{@lrs.sintegrator_distributedpath_diffusereflectsamples.to_i}]\n"
				integrator << "\t\"integer diffuserefractdepth\" [#{@lrs.sintegrator_distributedpath_diffuserefractdepth.to_i}]\n"
				integrator << "\t\"integer diffuserefractsamples\" [#{@lrs.sintegrator_distributedpath_diffuserefractsamples.to_i}]\n"
				bool_value = @lrs.sintegrator_distributedpath_directdiffuse ? "true" : "false"
				integrator << "\t\"bool directdiffuse\" [\"#{bool_value}\"]\n"
				bool_value = @lrs.sintegrator_distributedpath_indirectdiffuse ? "true" : "false"
				integrator << "\t\"bool indirectdiffuse\" [\"#{bool_value}\"]\n"
				integrator << "\t\"integer glossyreflectdepth\" [#{@lrs.sintegrator_distributedpath_glossyreflectdepth.to_i}]\n"
				integrator << "\t\"integer glossyreflectsamples\" [#{@lrs.sintegrator_distributedpath_glossyreflectsamples.to_i}]\n"
				integrator << "\t\"integer glossyrefractdepth\" [#{@lrs.sintegrator_distributedpath_glossyrefractdepth.to_i}]\n"
				integrator << "\t\"integer glossyrefractsamples\" [#{@lrs.sintegrator_distributedpath_glossyrefractsamples.to_i}]\n"
				bool_value = @lrs.sintegrator_distributedpath_directglossy ? "true" : "false"
				integrator << "\t\"bool directglossy\" [\"#{bool_value}\"]\n"
				bool_value = @lrs.sintegrator_distributedpath_indirectglossy ? "true" : "false"
				integrator << "\t\"bool indirectglossy\" [\"#{bool_value}\"]\n"
				integrator << "\t\"integer specularreflectdepth\" [#{@lrs.sintegrator_distributedpath_specularreflectdepth.to_i}]\n"
				integrator << "\t\"integer specularrefractdepth\" [#{@lrs.sintegrator_distributedpath_specularrefractdepth.to_i}]\n"
				if (@lrs.sintegrator_distributedpath_reject)
					bool_value = @lrs.sintegrator_distributedpath_diffusereflectreject ? "true" : "false"
					integrator << "\t\"bool diffusereflectreject\" [\"#{bool_value}\"]\n"
					integrator << "\t\"float diffusereflectreject_threshold\" [#{"%.6f" %(@lrs.sintegrator_distributedpath_diffusereflectreject_threshold)}]\n"
					bool_value = @lrs.sintegrator_distributedpath_diffuserefractreject ? "true" : "false"
					integrator << "\t\"bool diffuserefractreject\" [\"#{bool_value}\"]\n"
					integrator << "\t\"float diffuserefractreject_threshold\" [#{"%.6f" %(@lrs.sintegrator_distributedpath_diffuserefractreject_threshold)}]\n"
					bool_value = @lrs.sintegrator_distributedpath_glossyreflectreject ? "true" : "false"
					integrator << "\t\"bool glossyreflectreject\" [\"#{bool_value}\"]\n"
					integrator << "\t\"float glossyreflectreject_threshold\" [#{"%.6f" %(@lrs.sintegrator_distributedpath_glossyreflectreject_threshold)}]\n"
					bool_value = @lrs.sintegrator_distributedpath_glossyrefractreject ? "true" : "false"
					integrator << "\t\"bool glossyrefractreject\" [\"#{bool_value}\"]\n"
					integrator << "\t\"float glossyrefractreject_threshold\" [#{"%.6f" %(@lrs.sintegrator_distributedpath_glossyrefractreject_threshold)}]\n"
				end
			# "directlighting"
			when "directlighting"
				integrator << "SurfaceIntegrator \"directlighting\"\n"
				integrator << "\t\"integer maxdepth\" [#{@lrs.sintegrator_direct_maxdepth}]\n"
				integrator << "\t\"integer shadowraycount\" [#{@lrs.sintegrator_direct_shadow_ray_count}]\n"
				integrator << "\t\"string lightstrategy\" [\"#{@lrs.sintegrator_direct_strategy}\"]\n"
			# "exphotonmap"
			when "exphotonmap"
				integrator << "SurfaceIntegrator \"exphotonmap\"\n"
				integrator << "\t\"integer directphotons\" [#{@lrs.sintegrator_exphoton_directphotons}]\n"
				integrator << "\t\"integer indirectphotons\" [#{@lrs.sintegrator_exphoton_indirectphotons}]\n"
				integrator << "\t\"integer causticphotons\" [#{@lrs.sintegrator_exphoton_causticphotons}]\n"
				finalgather = @lrs.sintegrator_exphoton_finalgather ? "true" : "false"
				integrator << "\t\"bool finalgather\" [\"#{finalgather}\"]\n"
				if (@lrs.sintegrator_exphoton_finalgather)
					integrator << "\t\"integer finalgathersamples\" [#{@lrs.sintegrator_exphoton_finalgathersamples}]\n"
					integrator << "\t\"string rrstrategy\" [\"#{@lrs.sintegrator_exphoton_rrstrategy}\"]\n"
					if (@lrs.sintegrator_exphoton_rrstrategy.match("probability"))
						integrator << "\t\"float rrcontinueprob\" [#{"%.6f" %(@lrs.sintegrator_exphoton_rrcontinueprob)}]\n"
					end
					integrator << "\t\"float gatherangle\" [#{"%.6f" %(@lrs.sintegrator_exphoton_gatherangle)}]\n"
				end
				integrator << "\t\"integer maxdepth\" [#{@lrs.sintegrator_exphoton_maxdepth}]\n"
				integrator << "\t\"integer maxphotondepth\" [#{@lrs.sintegrator_exphoton_maxphotondepth}]\n"
				integrator << "\t\"float maxphotondist\" [#{"%.6f" %(@lrs.sintegrator_exphoton_maxphotondist)}]\n"
				integrator << "\t\"integer nphotonsused\" [#{@lrs.sintegrator_exphoton_nphotonsused}]\n"
				integrator << "\t\"integer shadowraycount\" [#{@lrs.sintegrator_exphoton_shadow_ray_count}]\n"
				integrator << "\t\"string lightstrategy\" [\"#{@lrs.sintegrator_exphoton_strategy}\"]\n"
				integrator << "\t\"string renderingmode\" [\"#{@lrs.sintegrator_exphoton_renderingmode}\"]\n"
				#if (@lrs.sintegrator_exphoton_show_advanced) # not exposed
					#dbg = @lrs.sintegrator_exphoton_dbg_enable_direct ? "true" : "false"
					#integrator << "\t\"bool dbg_enabledirect\" [\"#{dbg}\"]\n"
					#dbg = @lrs.sintegrator_exphoton_dbg_enable_indircaustic ? "true" : "false"
					#integrator << "\t\"bool dbg_enableindircaustic\" [\"#{dbg}\"]\n"
					#dbg = @lrs.sintegrator_exphoton_dbg_enable_indirdiffuse ? "true" : "false"
					#integrator << "\t\"bool dbg_enableindirdiffuse\" [\"#{dbg}\"]\n"
					#dbg = @lrs.sintegrator_exphoton_dbg_enable_indirspecular ? "true" : "false"
					#integrator << "\t\"bool dbg_enableindirspecular\" [\"#{dbg}\"]\n"
					#dbg = @lrs.sintegrator_exphoton_dbg_enable_radiancemap ? "true" : "false"
					#integrator << "\t\"bool dbg_enableradiancemap\" [\"#{dbg}\"]\n"
				#end
			# "igi"
			when "igi"
				integrator << "SurfaceIntegrator \"igi\"\n"
				integrator << "\t\"integer maxdepth\" [#{@lrs.sintegrator_igi_maxdepth}]\n"
				integrator << "\t\"integer nsets\" [#{@lrs.sintegrator_igi_nsets}]\n"
				integrator << "\t\"integer nlights\" [#{@lrs.sintegrator_igi_nlights}]\n"
				integrator << "\t\"float mindist\" [#{"%.6f" %(@lrs.sintegrator_igi_mindist)}]\n"
			# SPPM 
			when "sppm"
				integrator << "SurfaceIntegrator \"sppm\"\n"
				integrator << "\t\"string photonsampler\" [\"#{@lrs.sppm_photonsampler}\"]\n"
				integrator << "\t\"string lookupaccel\" [\"#{@lrs.sppm_lookupaccel}\"]\n"
				integrator << "\t\"integer maxeyedepth\" [#{@lrs.sppm_maxeyedepth}]\n"
				integrator << "\t\"integer maxphotondepth\" [#{@lrs.sppm_maxphotondepth}]\n"
				integrator << "\t\"integer photonperpass\" [#{@lrs.sppm_photonperpass}]\n"
				integrator << "\t\"float startradius\" [#{"%.6f" %(@lrs.sppm_startradius)}]\n"
				integrator << "\t\"float alpha\" [#{"%.6f" %(@lrs.sppm_alpha)}]\n"
				integrator << "\t\"bool includeenvironment\" [\"true\"]\n"
				integrator << "\t\"bool directlightsampling\" [\"true\"]\n"
            end # case
		return integrator
		
	end #END export_surface_integrator

	def export_accelerator
		accel = "\n"
		accel << "Accelerator \"#{@lrs.accelerator_type}\"\n"
		case @lrs.accelerator_type
			when "kdtree", "tabreckdtree"
				accel << "\t\"integer intersectcost\" [#{@lrs.kdtree_intersectcost.to_i}]\n"
				accel << "\t\"integer traversalcost\" [#{@lrs.kdtree_traversalcost.to_i}]\n"
				accel << "\t\"float emptybonus\" [#{"%.6f" %(@lrs.kdtree_emptybonus)}]\n"
				accel << "\t\"integer maxprims\" [#{@lrs.kdtree_maxprims.to_i}]\n"
				accel << "\t\"integer maxdepth\" [#{@lrs.kdtree_maxdepth.to_i}]\n"
			when "grid"
				refine = @lrs.grid_refineimmediately ? "true": "false"
				accel << "\t\"bool refineimmediately\" [\"#{refine}\"]\n"
			when "bvh"
			when "qbvh"
                accel << "\t\"integer maxprimsperleaf\" [#{@lrs.qbvh_maxprimsperleaf.to_i}]\n"
                accel << "\t\"integer fullsweepthreshold\" [#{@lrs.qbvh_fullsweepthreshold.to_i}]\n"
				accel << "\t\"integer skipfactor\" [#{@lrs.qbvh_skip_factor.to_i}]\n"
		end
		return accel
	end

	def export_volume_integrator
		volume = "\n"
		volume << "VolumeIntegrator \"#{@lrs.volume_integrator_type}\"\n"
		volume << "\t\"float stepsize\" [#{"%.6f" %(@lrs.volume_integrator_stepsize)}]\n"
		return volume
	end

	def export_light(out)
		sun_direction = Sketchup.active_model.shadow_info['SunDirection']
		out.puts "TransformBegin"
		case @lrs.environment_light_type
            when 'sunsky'
                out.puts "\tLightGroup \"#{@lrs.environment_sky_lightgroup}\""
			when 'environmentimage'
				if ( ! @lrs.environment_infinite_mapname.strip.empty?)
					out.puts "\tRotate #{@lrs.environment_infinite_rotatex} 1 0 0" 
					out.puts "\tRotate #{@lrs.environment_infinite_rotatey} 0 1 0"
					out.puts "\tRotate #{@lrs.environment_infinite_rotatez} 0 0 1"
				end
				out.puts "\tLightGroup \"#{@lrs.environment_infinite_lightgroup}\""
            when 'environmentcolor'
				out.puts "\tLightGroup \"#{@lrs.environment_infinite_lightgroup}\""
		end
		out.puts "AttributeBegin"
		case @lrs.environment_light_type
			when 'sunsky'
                if (@lrs.environment_use_sky)
                    out.puts "\tLightSource \"sky2\""
                    out.puts "\t\"float gain\" [#{"%.6f" %(@lrs.environment_sky_gain)}]"
                    out.puts "\t\"float turbidity\" [#{"%.6f" %(@lrs.environment_sky_turbidity)}]"
                    out.puts "\t\"vector sundir\" [#{"%.6f" %(sun_direction.x)} #{"%.6f" %(sun_direction.y)} #{"%.6f" %(sun_direction.z)}]"
                    out.puts "\tPortalInstance \"Portal_Shape\"" if @has_portals == true
                    out.puts "AttributeEnd" + "\n"
                    
                    out.puts "AttributeBegin"
                end
                # sun is written below
			when 'environmentimage'
				out.puts "\tLightSource \"infinitesample\""
				out.puts "\t\"float gain\" [#{"%.6f" %(@lrs.environment_infinite_gain)}]"
				if (! @lrs.environment_infinite_mapname.strip.empty?)
					out.puts "\t\"float gamma\" [#{"%.6f" %(@lrs.environment_infinite_gamma)}]"
					out.puts "\t\"string mapping\" [\"" + @lrs.environment_infinite_mapping + "\"]"
					out.puts "\t\"string mapname\" [\"" + @lrs.environment_infinite_mapname + "\"]"
                else
					out.puts "\t\"color L\" [#{"%.6f" %(@lrs.environment_infinite_L_R)} #{"%.6f" %(@lrs.environment_infinite_L_G)} #{"%.6f" %(@lrs.environment_infinite_L_B)}]"
				end
			when 'environmentcolor'
				out.puts "\tLightSource \"infinitesample\""
				out.puts "\t\"float gain\" [#{"%.6f" %(@lrs.environment_infinite_gain)}]"
                out.puts "\t\"color L\" [#{"%.6f" %(@lrs.environment_infinite_L_R)} #{"%.6f" %(@lrs.environment_infinite_L_G)} #{"%.6f" %(@lrs.environment_infinite_L_B)}]"

		end
		out.puts "AttributeEnd"
		out.puts "TransformEnd"
        
        out.puts "AttributeBegin"
        if ((@lrs.environment_light_type == 'sunsky' && @lrs.environment_use_sun) || @lrs.use_environment_infinite_sun)
            out.puts "\tLightGroup \"#{@lrs.environment_sun_lightgroup}\""
            out.puts "\tLightSource \"sun\""
            out.puts "\t\"float gain\" [#{"%.6f" %(@lrs.environment_sun_gain)}]"
            out.puts "\t\"float relsize\" [#{"%.6f" %(@lrs.environment_sun_relsize)}]"
            out.puts "\t\"float turbidity\" [#{"%.6f" %(@lrs.environment_sun_turbidity)}]"
            out.puts "\t\"vector sundir\" [#{"%.6f" %(sun_direction.x)} #{"%.6f" %(sun_direction.y)} #{"%.6f" %(sun_direction.z)}]"
            out.puts "\tPortalInstance \"Portal_Shape\"" if @has_portals == true
        end
        out.puts "AttributeEnd"
        
	end # END export_light

	def export_mesh(geometry_file, model) # note: "geometry_file" is a file object (.lxo file), to which all relevant data will be added through this method
		# note: ply_folder should be relative path, so that projects can be moved more easily
		exportpath = File.join(File.dirname(@lrs.export_file_path), SU2LUX.sanitize_path(File.basename(@lrs.export_file_path)))
		file_basename = File.basename(exportpath, SU2LUX::SCENE_EXTENSION)
		relative_ply_folder = File.join(file_basename + SU2LUX::SUFFIX_DATAFOLDER, SU2LUX::GEOMETRYFOLDER)
		ply_folder = File.join(File.dirname(@export_file_path), File.basename(@export_file_path, SU2LUX::SCENE_EXTENSION) + SU2LUX::SUFFIX_DATAFOLDER, SU2LUX::GEOMETRYFOLDER)
	
		#
		# process_components
		#
		
		Sketchup.set_status_text('SU2LUX export: processing component definitions')
		@group_definition_hash = get_component_instances() # component_instance => component_definition
		
		processed_components = process_components()
		puts 'processing ' + processed_components[0].size.to_s + (processed_components[0].size == 1 ? ' component' : ' components')
		components = processed_components[0] # sketchup component definitions
		component_mat_geometry = processed_components[1] # series of [skpmat, skpfaces] for each component
		component_children = processed_components[2] # child components for each component: [e.entityID, e.material, e.local_transformation.to_a]
		
		#
		# sort out distorted faces, write geometry
		#
		Sketchup.set_status_text('SU2LUX export: writing component geometry to file')
		sorted_component_mat_geometry = {}
		components.each{|comp_def|
			puts comp_def.name
			# proces geometry collections, separating distorted faces (result: list with [skpmat, skpfaces, 0 or exported material index]
			if(@lrs.exp_distorted == true)
				sorted_component_mat_geometry[comp_def] = sort_distorted_faces(component_mat_geometry[comp_def]);
			else
				sorted_component_mat_geometry[comp_def] = component_mat_geometry[comp_def];
			end
			# write component geometry to ply
			sorted_component_mat_geometry[comp_def].each{|skp_mat, faces, dist_index| # note: undistorted geometry has dist_index 0
				if(dist_index != 0)
					@distorted_faces << [faces, skp_mat, dist_index] # @distorted_faces is used later for texture export
				end
				# prepare ply file path
				skp_mat_name = (skp_mat == "SU2LUX_no_material") ? "nomat" : SU2LUX.sanitize_path(skp_mat.name)
				componentnr = comp_def.entityID.to_s
				ply_name = SU2LUX.sanitize_path(componentnr + '_' + skp_mat_name + ((dist_index == 0 || dist_index == nil) ? "" : SU2LUX::SUFFIX_DIST + dist_index.to_s) + '.ply')
				ply_path = File.join(ply_folder, ply_name)
				# write ply file
				if(faces.length > 0)
					output_ply_file(ply_path, faces, false) # false: write ASCII file, not binary
				end
			}
		}
		
		# write component object definition
		puts 'writing component definitions'
		geometry_file.puts "# created by SU2LUX " + SU2LUX::SU2LUX_VERSION + " " + Time.new.to_s
		geometry_file.puts ''
		components.each{|comp|
			# only write component if it is not a lamp definition
			if(comp.attribute_dictionary("LuxRender") == nil)
				write_component_definition(geometry_file, relative_ply_folder, comp, sorted_component_mat_geometry[comp], component_children[comp])
			end
		}		
		geometry_file.puts ''
		
		# iterate objects in scene, process ordinary geometry and component instances
		puts 'exporting real and instanced geometry'
		geometry_file.puts "# geometry definition - first change global transformation from inches to meters"
		geometry_file.puts "ConcatTransform [0.0254 0.0 0.0 0.0 0.0 0.0254 0.0 0.0 0.0 0.0 0.0254 0.0 0.0 0.0 0.0 1.0]" # convert from scene units (inches) to meters
		geometry_file.puts ''
		
		# create containers for ordinary geometry
		material_geometry = {}
		@material_editor.materials_skp_lux.keys.each{|skpmat|
			material_geometry[skpmat] = [] # note: distorted materials still need to be added one by one
		}
		material_geometry["SU2LUX_no_material"] = []
		
		# writing component instances
		Sketchup.set_status_text('SU2LUX export: writing component instances')
		lamp_editor = SU2LUX.get_editor(@scene_id, "lamp")
		model.entities.each{|ent|
			# check if it is an instance, if so, check if it is visible, if so, write
			if ent.class == Sketchup::ComponentInstance
				# check if it is a lamp 
				if (ent.definition.attribute_dictionaries != nil && ent.definition.attribute_dictionaries["LuxRender"] != nil) # lamp
					# write lamp		
					puts "lamp editor valid?" + (lamp_editor == nil ? "no" : "yes")
					lamp_object = lamp_editor.getLampObject(ent.definition)
						if(lamp_object != nil)
						lamp_definition = lamp_object.get_description(ent)
						lamp_definition.each do|text_line|
							geometry_file.puts text_line
						end
					end

				else # ordinary component instance			
					# get transformation, get id, write instance
					geometry_file.puts 'AttributeBegin' + ' # component name: ' + ent.definition.name + ', instance name: ' + ent.name
					geometry_file.puts "\t ConcatTransform " + '[' + ent.transformation.to_a.join(" ") + ']'
					geometry_file.puts "\t ObjectInstance \"" + ent.definition.entityID.to_s + '"'
					if(ent.material != nil)
						geometry_file.puts "\t NamedMaterial \"" + SU2LUX.sanitize_path(@material_editor.materials_skp_lux[ent.material].name) + '_component_material"'
						@component_skp_materials << ent.material
					end
					geometry_file.puts "\t ObjectInstance \"" + ent.definition.entityID.to_s + '_nomat"'
					geometry_file.puts 'AttributeEnd'
				end
				
				
			elsif ent.class == Sketchup::Group
				# get transformation, get id, write instance
				geometry_file.puts 'AttributeBegin' + ' # group name: ' + ent.name
				geometry_file.puts "\t ConcatTransform " + '[' + ent.transformation.to_a.join(" ") + ']'
				geometry_file.puts "\t ObjectInstance \"" + @group_definition_hash[ent].entityID.to_s + '"'
				if(ent.material != nil)
					geometry_file.puts "\t NamedMaterial \"" + SU2LUX.sanitize_path(@material_editor.materials_skp_lux[ent.material].name) + '_component_material"'
					@component_skp_materials << ent.material
				end
				geometry_file.puts "\t ObjectInstance \"" + @group_definition_hash[ent].entityID.to_s + '_nomat"'
				geometry_file.puts 'AttributeEnd'
			elsif ent.class == Sketchup::Face
				# sort: add face to material_geometry[skpmat] list
				if(ent.layer.visible? and ent.visible?)
					# sort faces in lists with [luxrender material, [triangles]] 
					facemat = ent.material
					backmat = ent.back_material
					if(facemat == nil && backmat == nil)
						material_geometry["SU2LUX_no_material"] << ent
					elsif facemat == nil	
						material_geometry[backmat] << ent
					else
						material_geometry[facemat] << ent
					end
				end
			end
		}
		geometry_file.puts ''
		
		##
		# start ordinary geometry export
		##
		Sketchup.set_status_text('SU2LUX export: exporting geometry')
		
		# sort out distorted faces for ordinary geometry		
		if(@lrs.exp_distorted == true)
			material_geometry = sort_distorted_faces(material_geometry) # separates faces with distorted textures
		else
			material_geometry = mark_undistorted(material_geometry) # restructures content, from material=>faces to [material, faces, 0]
		end
		
		# write ordinary geometry to ply files
		material_geometry.each{|skp_mat, faces, dist_index| # note: undistorted geometry has dist_index 0  #
			if(dist_index != 0)
				@distorted_faces << [faces, skp_mat, dist_index = 0]
			end
			# create name, for example: material_dist1.ply
			skp_mat_name = "nomat"
			if(skp_mat != "SU2LUX_no_material")
				skp_mat_name = SU2LUX.sanitize_path(skp_mat.name)
			end
			ply_name = skp_mat_name + (dist_index == 0 ? "" : SU2LUX::SUFFIX_DIST + dist_index.to_s) + '.ply'
			ply_path = File.join(ply_folder, ply_name)
			# write geometry file
			output_ply_file(ply_path, faces, false) # false: write ASCII file, not binary
		}		
		
		# write ordinary geometry references
		write_ordinary_geometry(material_geometry, geometry_file, relative_ply_folder)
		

	end # END export_mesh
	
	def write_ordinary_geometry(material_geometry, geometry_file, relative_ply_folder)
		material_geometry.each{|skp_mat, facelist, dist_index|
			if facelist.size > 0
				skp_mat_name = "nomat"
				if(skp_mat != "SU2LUX_no_material")
					skp_mat_name = SU2LUX.sanitize_path(skp_mat.name)
				end
				geometry_file.puts 'AttributeBegin'
				matname = skp_mat_name + ((dist_index == 0 || dist_index == nil) ? "" : SU2LUX::SUFFIX_DIST + dist_index.to_s) # @material_editor.materials_skp_lux[skp_mat].name
				ply_path = File.join(relative_ply_folder, matname + '.ply')
				lux_mat = nil
				if(skp_mat != "SU2LUX_no_material")
					lux_mat = @material_editor.materials_skp_lux[skp_mat]
					if(lux_mat.type != 'portal')
						geometry_file.puts '  NamedMaterial "' + SU2LUX.sanitize_path(matname) + '"' 			# NamedMaterial "materialname"
					end
					if(lux_mat.type == 'light')
						geometry_file.puts '  LightGroup "' + matname + '"'
						light_def_lines = output_light_definition(lux_mat, matname)
						light_def_lines.each{|lightdef_line|
							geometry_file.puts "  " + lightdef_line
						}					
					end
				end
				
				if(lux_mat != nil && lux_mat.type == 'portal')
					geometry_file.puts '  PortalShape "plymesh"' 					#   PortalShape "plymesh"
				else
					geometry_file.puts '  Shape "plymesh"' 							#   Shape "plymesh"
				end
				
				geometry_file.puts '  "string filename" ["' +  ply_path + '"]'	#	"string filename" ["Untitled_luxdata/geometry/1_boxes.ply"]
				
				# write displacement
				if(lux_mat != nil)
					self.export_displacement_textures(geometry_file, lux_mat, matname)
				end
				
				geometry_file.puts 'AttributeEnd'
				geometry_file.puts ''
			end
		}
	end
	
	
	def sort_distorted_faces(skpmat_faces_hash) # contains: {skpmat=>skpfaces, skpmat=>skpfaces}
		sorted_faces_per_material = [] # sketchup material, face list for this material, distorted_face_index (not distorted: 0)
		# for each material
		skpmat_faces_hash.each{|skpmat, facelist|
			# prepare containers for current SketchUp material
			undistorted_faces = []
			distorted_faces = []
			
			# check all faces for distortion, add face to appropriate list
			facelist.each{|face|
				if(face.material != nil)
					is_distorted(face, true) ? distorted_faces << face : undistorted_faces << face
				else
					is_distorted(face, false) ? distorted_faces << face : undistorted_faces << face
				end
			}
			
			# add data to output container, increment number of distorted materials
			sorted_faces_per_material << [skpmat, undistorted_faces, 0]
			distorted_faces.each{|distorted_face|
				@nr_distorted_materials += 1
				sorted_faces_per_material << [skpmat, [distorted_face], @nr_distorted_materials]
			}
		}		
		return sorted_faces_per_material # contains: {[skpmat, skpfaces, distorted_mat_index]}
	end
	
	def mark_undistorted(skpmat_faces_hash)
		sorted_faces_per_material = [] # sketchup material, face list for this material, distorted_face_index (not distorted: 0)
		# for each material
		skpmat_faces_hash.each{|skpmat, facelist|
			sorted_faces_per_material << [skpmat, facelist, 0]
		}		
		return sorted_faces_per_material # contains: {[skpmat, skpfaces, distorted_mat_index]}
	end
	
	def is_distorted(face, mat_dir)
		if face.valid?
			for v in face.vertices # get UV coordinates for all vertices:
				p = v.position 
				tw = Sketchup.create_texture_writer
				uvHelp = face.get_UVHelper(mat_dir, !mat_dir, tw)
				uvq = mat_dir ? uvHelp.get_front_UVQ(p) : uvHelp.get_back_UVQ(p)
				if (uvq and (uvq.z.to_f - 1).abs > 1e-5)
                    return true # texture is distorted
				end
			end
		end
		return false # texture is not distorted
	end

	def write_component_definition(geometry_file, relative_ply_folder, this_component_definition, this_component_mat_geometry, this_component_children)
		compdef_lines = []
		compdef_nomat_lines = []
		componentname = this_component_definition.entityID.to_s # note: for components, but also for groups, this is the ID of the definition, not the instance
		
		# store component definition and no-material component definition in separate arrays of strings, then output them to the geometry_file afterwards
		compdef_lines << 'ObjectBegin "' + componentname + '" # ' + this_component_definition.name
		compdef_nomat_lines << 'ObjectBegin "' + componentname + '_nomat' + '" # ' + this_component_definition.name

		## write reference to material and geometry for every used material, and export geometry files
		this_component_mat_geometry.each{|skpmat, facelist, dist_index|
			if(facelist != nil and facelist.size > 0)	
				if skpmat == "SU2LUX_no_material"
					# note: this is written to a separate component, as otherwise material inheritance will not work
					component_ply_name = componentname + '_nomat' + ((dist_index == 0 || dist_index == nil) ? "" : SU2LUX::SUFFIX_DIST + dist_index.to_s) + '.ply'
					ply_path = File.join(relative_ply_folder, component_ply_name)
					# write definition for component without material
					compdef_nomat_lines << '  AttributeBegin'
					compdef_nomat_lines << '    Shape "plymesh"'
					compdef_nomat_lines << '    "string filename" ["' +  ply_path + '"]'
					compdef_nomat_lines << '  AttributeEnd'
				else
					luxmat = @material_editor.materials_skp_lux[skpmat]
					component_ply_name = componentname + '_' + SU2LUX.sanitize_path(luxmat.name) + ((dist_index == 0 || dist_index == nil) ? "" : SU2LUX::SUFFIX_DIST + dist_index.to_s) + '.ply'
					ply_path = File.join(relative_ply_folder, component_ply_name)
					
					compdef_lines << '  AttributeBegin'	
					if luxmat.type == 'light'
						# write light properties
						light_def_lines = output_light_definition(luxmat, skpmat.name)
						light_def_lines.each{|lightdef_line|
							compdef_lines << "  " + lightdef_line
						}
					end
					this_mat_name = SU2LUX.sanitize_path(luxmat.name) + ((dist_index == 0 || dist_index == nil) ? "" : SU2LUX::SUFFIX_DIST + dist_index.to_s)
					
					if(luxmat.type == 'portal')
						compdef_lines << '    PortalShape "plymesh"'						#   PortalShape "plymesh"
					else
						compdef_lines << '    NamedMaterial "' + this_mat_name + '"'
						compdef_lines << '    Shape "plymesh"'						#   Shape "plymesh"
					end
					
					compdef_lines << '    "string filename" ["' +  ply_path + '"]' #	"string filename" ["Untitled_luxdata/geometry/1_boxes.ply"]
									# write displacement
					if(luxmat != nil)
						self.export_displacement_definition(compdef_lines, luxmat, this_mat_name)
					end
					compdef_lines << '  AttributeEnd'
				end
			elsif(skpmat == "SU2LUX_no_material")
				# write empty definition?
			end
		}
		## write references to child components
		#puts "processing child components"
		this_component_children.each{|child_component| # child component contains [child object, entityID, material, local_transformation.to_a]
			# we have two child components, one with the ordinary materials, one with undefined materials. The latter has "_nomat" appended to its name.

			# first write the ordinary component
			compdef_lines << 'AttributeBegin'
			compdef_lines << "\t ConcatTransform [" + child_component[3].join(" ") + ']' # child_component[2].to_a.to_s.delete(',') 
			
			# get the group/component definition entityID
			if child_component[0].class == Sketchup::Group
				definition_entityID = @group_definition_hash[child_component[0]].entityID.to_s
			else
				definition_entityID = child_component[0].definition.entityID.to_s
			end
			
			compdef_lines << "\t ObjectInstance \"" + definition_entityID + '"'
			compdef_lines << 'AttributeEnd'
			
			# write the _nomat component to either the ordinary material definition, or the one without material (depending on whether this component instance has a material)
			if (child_component[2] != nil && child_component[2] != [] && child_component != "") # component has a material, so write it to the normal component definition
				compdef_lines << 'AttributeBegin'
				compdef_lines << "\t ConcatTransform [" + child_component[3].join(" ") + ']' # + child_component[2].to_a.to_s.delete(',') 
				
				# add this material to list of materials that need to be exported with scaling factor
				@component_skp_materials << child_component[2]
				
				# write reference to child material
				compdef_lines << "\t NamedMaterial \"" + SU2LUX.sanitize_path(@material_editor.materials_skp_lux[child_component[2]].name) + '"'
				compdef_lines << "\t ObjectInstance \"" + definition_entityID + '_nomat"'
				compdef_lines << 'AttributeEnd'
			else
				compdef_nomat_lines << 'AttributeBegin'
				compdef_nomat_lines << "\t ConcatTransform [" + child_component[3].join(" ") + ']' # child_component[2].to_a.to_s.delete(',') 
				compdef_nomat_lines << "\t ObjectInstance \"" + definition_entityID + '_nomat"'
				compdef_nomat_lines << 'AttributeEnd'
			end
		}
		compdef_lines << 'ObjectEnd'
		compdef_lines << ''
		compdef_nomat_lines << 'ObjectEnd'
		compdef_nomat_lines <<''
				
		# write component definitions to file
		compdef_lines.each{|singlestring|
			geometry_file.puts singlestring
		}
		compdef_nomat_lines.each{|singlestring|
			geometry_file.puts singlestring
		}
	end
	
	def export_textures(texture_folder)
		# get image textures from all LuxRender materials, and store SketchUp materials from which the texture needs to be written
		skpmat_with_used_texture = []
		luxmat_file_paths = []
		puts "gathering textures"
		@material_editor.materials_skp_lux.each{|skp_mat, lux_mat|	
			luxmat_file_paths += lux_mat.get_used_image_paths
			if (lux_mat.uses_skp_texture && skp_mat.texture != nil)
				#puts "texture found"	
				skpmat_with_used_texture << skp_mat
			end
		}
		#puts 'luxmat_file_paths:'
		#puts luxmat_file_paths
		
		# if export textures is set, export all image textures from the list
		if @lrs.texexport == 'all'
			luxmat_file_paths.uniq.each{|file_path|
				destination_path = File.join(texture_folder, SU2LUX.sanitize_path(File.basename(file_path)))
				#puts 'trying to write file from ' + file_path.to_s + ' to ' + destination_path.to_s
				FileUtils.cp(file_path, destination_path) unless File.exists?(destination_path)
			}
		else
			# export only images that have file paths that LuxRender cannot read
			# iterate image paths, save the ones that have a path cannot be processed by LuxRender; those need to be copied as otherwise LuxRender will not find them
			@material_editor.materials_skp_lux.values.each {|luxmat|
				for channel in luxmat.texturechannels
					# first check if this channels uses image texture, if so, check if the path is a valid LuxRender path; if not, copy
					if(luxmat.send(channel + "_texturetype") == 'imagemap')
						texturepath = luxmat.send(channel + "_imagemap_filename")
						if (texturepath != "" && texturepath != SU2LUX.sanitize_path(texturepath))
							# get output path, copy file
							destination_path = File.join(texture_folder, SU2LUX.sanitize_path(File.basename(texturepath)))
							FileUtils.cp(texturepath, destination_path) unless File.exists?(destination_path)
						end
					end
				end
			}
		end
		
		Sketchup.active_model.start_operation("SU2LUX: material export", true, true, false)
		
		# for all sketchup materials in the list, export the bitmap images
		luxmat_group = Sketchup.active_model.entities.add_group
		luxmat_face = luxmat_group.entities.add_face([-3,-3,-3], [-3, -3, -4], [-3, -4, -3])
		skpmat_with_used_texture.each{|skp_mat|
			puts "exporting bitmap image for sketchup material: " + skp_mat.name 
			# apply texture to temporary geometry, then load it from there
			luxmat_face.material = skp_mat
			tw = Sketchup.create_texture_writer
			tw.load luxmat_face, true
			destination_path = File.join(texture_folder, SU2LUX.sanitize_path(File.basename(get_texture_file_name(skp_mat))))
			puts destination_path
			tw.write luxmat_face, true, destination_path
		}
		Sketchup.active_model.entities.erase_entities luxmat_group
		Sketchup.active_model.commit_operation()
		
		# process distorted faces
		if(@lrs.exp_distorted)
			@distorted_faces.each{|face, skp_mat, dist_index| # note: 'face' is a list of faces, but in practice should have only one item
				# if the material has a sketchup texture, export the distorted sketchup texture
				if(skpmat_with_used_texture.include? skp_mat)
					tw = Sketchup.create_texture_writer
					texname = SU2LUX.sanitize_path(get_texture_file_name(skp_mat)) # texturename.jpg
					destination_path = File.join(texture_folder, texname.split('.')[0] + SU2LUX::SUFFIX_DIST + dist_index.to_s + File.extname(texname))
					if(face[0].material == nil)
						tw.load face[0], false
						tw.write face[0], false, destination_path
					else
						tw.load face[0], true
						tw.write face[0], true, destination_path
					end
				end			
				# for all the material's image textures, copy the image with a modified name (todo for later: assign to face, read with texture reader, export distorted image)
				image_file_paths = @material_editor.materials_skp_lux[skp_mat].get_used_image_paths
				image_file_paths.each{|source_path|
					# todo: create material, assign to temporary triangle, read and write with texturewriter, delete material
					texname_parts = File.basename(source_path).split('.')
					target_path = File.join(texture_folder, texname_parts[0] + dist_index.to_s + texname_parts[1])
					#puts target_path
					FileUtils.cp(source_path, target_path) unless File.exists?(target_path)
				}
			} # end distorted_faces.each
		end # end if @lrs.exp_distorted
	end

	def export_preview_material(preview_path, generated_lxm_file, currentmaterialname, currentmaterial, texture_path, luxmat)
		puts "\n"
        puts "running preview export function"
		
		# prepare texture paths
        outputfolder = "LuxRender_luxdata/textures"
		@texfolder = File.join(preview_path, outputfolder)
        
		# check for textures folder in temporary location, create if missing
		luxdata_folder = File.join(preview_path, "LuxRender_luxdata")
		Dir.mkdir(luxdata_folder) unless File.exists?(luxdata_folder)
		texture_folder = File.join(luxdata_folder, "textures")
		Dir.mkdir(texture_folder) unless File.exists?(texture_folder)
		
		# copy image textures if paths contain non-supported characters; otherwise, we use absolute paths
		collectedtextures = []
		for channel in luxmat.texturechannels
			texturepath = luxmat.send(channel+"_imagemap_filename")
			if (texturepath != "" && texturepath != SU2LUX.sanitize_path(texturepath))
				collectedtextures << texturepath
			end
		end
		# write collected images to luxdata folder
		if (collectedtextures.length > 0)
			puts  "copying " + collectedtextures.length.to_s + " image textures" 
			for texturepath in collectedtextures.uniq
				destinationfolder = File.join(texture_folder, SU2LUX.sanitize_path(File.basename(texturepath)))
				FileUtils.cp(texturepath, destinationfolder)
			end
        end
		
		Sketchup.active_model.start_operation("SU2LUX: material export", true, true, false)
		
		# create temporary group and face, apply current material
		luxmat_group = Sketchup.active_model.entities.add_group
		pt1 = [-3,-3,-3]
		pt2 = [-3, -3, -4]
		pt3 = [-3, -4, -3]
		luxmat_face = luxmat_group.entities.add_face(pt1, pt2, pt3)
		puts "assigning material #{currentmaterial.name} to temporary face"
		luxmat_face.material = currentmaterial
		
		# get SketchUp material texture
		if (currentmaterial.texture)
			texturefilename = currentmaterial.texture.filename
			trimmedfilename = texturefilename.gsub("\\", "")
			trimmedfilename = trimmedfilename.gsub("/", "")
			outputpath = File.join(texture_folder, SU2LUX.sanitize_path(File.basename(texturefilename)))
			if (File.exist?(texturefilename)) # get texture from full file path
				FileUtils.copy_file(texturefilename, outputpath)
			else # get texture through texturewriter
				tw = Sketchup.create_texture_writer
				tw.load luxmat_face, true
				tw.write luxmat_face, true, outputpath
			end
		end
		
		# write data to file
		mat_definition = get_material_definition(luxmat, luxmat.name, texdistorted = false)
		mat_definition.each{|line|
			generated_lxm_file << line
		}
		
		# delete temporary group
		Sketchup.active_model.entities.erase_entities luxmat_group
		puts "end of preview export function"
		
		Sketchup.active_model.commit_operation()
		
	end # end export_preview_material

	def export_fm_faces(out, is_instance)
        puts "processing face me components"
		@fm_materials.each{|matname,value|
			if (value!=nil and value!=[])
                #puts "fm_materials values:"
                #puts value[0][0]
                #puts value[0][1]
                #puts value[0][2]
                #puts value[0][3]
                #puts value[0][4]
                #puts value[0][5]
                #puts value[0][6]
				export_face(out,value[0][4],true,is_instance,matname,value[0][5])
				@fm_materials[matname]=nil
			end}
		@fm_materials={}
	end # END export_fm_faces

	def point_to_vector(p)
		return Geom::Vector3d.new(p.x, p.y, p.z)
	end # END point_to_vector
	
	def output_ply_file(ply_path, facelist, binary = false)
		#puts "exporting ply file to path:"
		#puts ply_path
		# create folder if it doesn't exist yet
		geometry_folder = File.dirname(ply_path)
		Dir.mkdir(geometry_folder) unless File.exists?(geometry_folder)
	
	    # create file, write header lines
		if (binary)       
			ply_file = File.new(ply_path, "wb")
			ply_file.puts "ply"
            ply_file.puts "format binary_little_endian 1.0"
        else
			ply_file = File.new(ply_path, "w")
			ply_file.puts "ply"
            ply_file.puts "format ascii 1.0"
        end
        ply_file.puts "comment created by SU2LUX " + SU2LUX::SU2LUX_VERSION + " " + Time.new.to_s
	
		#
		#	process faces: create meshes from all faces; add their triangles to a single list
		#
		meshpointcounter = 0
		meshfacelist = []
		vertexlist = []
		vertexnormallist = []
		vertexuvlist = []
		facelist.each{|skp_face|
			polygonmesh = skp_face.mesh(5) # 5: include PolygonMeshUVQFront and PolygonMeshNormals
			
			# get points (defined as Point3d)
			polygonmesh.points.each{|p3d|
				vertexlist << p3d
			}
			
			# get normals and uvs for each point
			tw = Sketchup.create_texture_writer # create texture writer for this face 
			tw.load(skp_face, true)
			uvHelp = skp_face.get_UVHelper(true, true, tw) # deals with distorted textures
			for i in 1..polygonmesh.points.length
				vertexnormallist << polygonmesh.normal_at(i) 
				if(skp_face.material != nil || skp_face.back_material == nil)
					vertexuvlist << uvHelp.get_front_UVQ(polygonmesh.points[i-1])
				else
					vertexuvlist << uvHelp.get_back_UVQ(polygonmesh.points[i-1])
				end
			end
				
			# get faces (defined as point indices)
			polygonmesh.polygons.each{|face_vertex_indices|
				globalfaceindices = []
				face_vertex_indices.each{|face_vertex_index|
					globalfaceindices << meshpointcounter + face_vertex_index.abs - 1
				}
				meshfacelist << globalfaceindices
			}	
			meshpointcounter += polygonmesh.points.length		
		}
		
		# write element, vertex count, vertex parameters, face count, face parameters, end of header
        ply_file.puts "element vertex #{vertexlist.length.to_s}\n"
        ply_file.puts "property float x"
        ply_file.puts "property float y"
        ply_file.puts "property float z"
        ply_file.puts "property float nx"
        ply_file.puts "property float ny"
        ply_file.puts "property float nz"
        ply_file.puts "property float s"
        ply_file.puts "property float t"
        ply_file.puts "element face #{meshfacelist.length.to_s}"
        ply_file.puts "property list uchar uint vertex_indices"
        ply_file.puts "end_header"

		# write vertices
		for i in 0..vertexlist.length-1
			if (binary)
				#ply_file << [vertexlist[i].x.to_f, vertexlist[i].y.to_f, vertexlist[i].z.to_f, vertexnormallist[i].x, vertexnormallist[i].y, vertexnormallist[i].z, vertexuvlist[i].x, 1-vertexuvlist[i].y].pack('e*.')
			else
				position_string = vertexlist[i].x.to_f.to_s + " " + vertexlist[i].y.to_f.to_s + " " + vertexlist[i].z.to_f.to_s
				normal_string = ("%5.6f" % vertexnormallist[i].x).to_s + " " + ("%5.6f" % vertexnormallist[i].y).to_s + " " + ("%5.6f" % vertexnormallist[i].z).to_s
				uv_string = ("%5.6f" % (vertexuvlist[i].x.to_f)).to_s + " " + ("%5.6f" % (1.0 - vertexuvlist[i].y)).to_s
				ply_file.puts position_string + " " + normal_string + " " + uv_string
			end	
		end
		
		# write faces
		for f in 0..meshfacelist.length-1
			faceindices = meshfacelist[f]
			facedef = faceindices.size.to_s + ' '
			faceindices.each{|fi|
				facedef = facedef + fi.to_s + ' '
			}
			if (binary)
				ply_file << facedef.pack('CVVV')
			else
				ply_file.puts facedef
			end 
		end
		ply_file.close
	end
        
		
    def output_light_definition (luxrender_mat, matname) # writes light definition (for geometry file)
        #puts "running output_material"
		light_definition = []
		light_definition << 'LightGroup "' + SU2LUX.sanitize_path(matname) + '"'
		light_definition << "AreaLightSource \"area\""
		spectrum_lines = export_spectrum_lines(luxrender_mat, matname)
		spectrum_lines.each{|spectrum_line|
			light_definition << spectrum_line
		}
		light_definition << "\"float power\" [#{"%.6f" %(luxrender_mat.light_power)}]"
		light_definition << "\"float efficacy\" [#{"%.6f" %(luxrender_mat.light_efficacy)}]"
		light_definition << "\"float gain\" [#{"%.6f" %(luxrender_mat.light_gain)}]"
		# write IES file
		if (luxrender_mat.ies_path != "")
			light_definition << "\"string iesname\" [\"" + luxrender_mat.ies_path + "\"]"  
		end	
		return light_definition
    end
		
		
    def output_material (out, luxrender_mat, matname) # writes link to material and volumes, not material itself # only used for material preview
        #puts "running output_material"
        case luxrender_mat.type
        when "light"
			# note/todo: remove from here? there is another method writing this information
            out.puts "AreaLightSource \"area\""
            export_spectrum(out, luxrender_mat, matname)
            out.puts "\"float power\" [#{"%.6f" %(luxrender_mat.light_power)}]"
            out.puts "\"float efficacy\" [#{"%.6f" %(luxrender_mat.light_efficacy)}]"
            out.puts "\"float gain\" [#{"%.6f" %(luxrender_mat.light_gain)}]"
			# write IES file
			if (luxrender_mat.ies_path != "")
				out.puts "\"string iesname\" [\"" + luxrender_mat.ies_path + "\"]"  
			end	
        when "portal"
            out.puts "ObjectBegin \"Portal_Shape\""
            @has_portals = true
        else
            out.puts "NamedMaterial \"" + SU2LUX.sanitize_path(matname) + "\""
			#
			volume_interior = luxrender_mat.volume_interior
			volume_exterior = luxrender_mat.volume_exterior
			if(volume_interior != 'default')
				# add volume information here
				out.puts 'Interior  "' + volume_interior + '"'
			end
			if(volume_exterior != 'default')
				# add volume information here
				out.puts 'Exterior  "' + volume_exterior + '"'
			end
        end # end case
    end
   
	def export_procedural_textures(out)
		puts "exporting procedural textures"
		out.puts '# procedural textures'
		
		# get list of procedural textures from procedural texture editor
		proctexeditor = SU2LUX.get_editor(@scene_id, "proceduraltexture")
		textureHash = proctexeditor.getTextureCollection()
		
		# write textures
		textureHash.each do |texName, texObject|
			puts "exporting procedural texture " + texName
			texType = texObject.getTexType()
			out.puts "Texture \"" + texName + "\" \"" + texObject.getChannelType() + "\" \"" + texType + "\""
			# get and write texture properties
			texObject.getFormattedValues().each {|propList|
				out.puts "\t" + "\"" + propList[0] + "\" [" + propList[1].to_s + "]"
			}
			# get and write texture transformation
			texObject.getTransformations().each{|transformItem|
				out.puts "\t" + transformItem
			}
			out.puts ""
		end
	end
     
	 def export_spectrum_lines(luxrender_mat, tex_name, dist_nr = 0)
		spectrum_lines = []
        case luxrender_mat.light_L
			when "blackbody"
				spectrum_lines << "\"texture L\" [\"#{luxrender_mat.name}:light:L\"]" # texture is defined in .lxm file
			when "emit_color"
				if luxrender_mat.has_texture?("em")
					dummy, texturenameline = self.export_texture(luxrender_mat, "em", "color", "", "", tex_name, dist_nr)
					spectrum_lines << texturenameline
				else
					spectrum_lines << "\t" + "\"color L\" [" + luxrender_mat.em_R.to_s + " " + luxrender_mat.em_G.to_s + " " + luxrender_mat.em_B.to_s + "]"
				end
			when "emit_preset"
				spectrum_lines << "\"texture L\" [\"#{luxrender_mat.name}:light:L\"]" # texture is defined in .lxm file
        end
		return spectrum_lines
    end
   
   
   
    def export_spectrum(out, luxrender_mat, tex_name, dist_nr = 0)
        case luxrender_mat.light_L
        when "blackbody"
            out.puts "\"texture L\" [\"#{luxrender_mat.name}:light:L\"]" # texture is defined in .lxm file
        when "emit_color"
            if luxrender_mat.has_texture?("em")
                dummy, texturenameline = self.export_texture(luxrender_mat, "em", "color", "", "", tex_name, dist_nr)
                out.puts texturenameline
            else
                out.puts "\t" + "\"color L\" [" + luxrender_mat.em_R.to_s + " " + luxrender_mat.em_G.to_s + " " + luxrender_mat.em_B.to_s + "]"
            end
        when "emit_preset"
            out.puts "\"texture L\" [\"#{luxrender_mat.name}:light:L\"]" # texture is defined in .lxm file
        end
    end
        
    def export_displacement_textures(out, luxrender_mat, texname) # writes to a file that is passed as an argument
        if luxrender_mat.use_displacement
			# puts "exporting displacement"
			# puts luxrender_mat.dm_texturetype
            out.puts "\"string subdivscheme\" [\"" + luxrender_mat.dm_scheme + "\"]"
            case luxrender_mat.dm_scheme
                when "loop"
                    out.puts "\"bool dmnormalsmooth\" [\"#{luxrender_mat.dm_normalsmooth}\"]"
                    out.puts "\"bool dmnormalsplit\" [\"#{luxrender_mat.dm_normalsplit}\"]"
                    out.puts "\"bool dmsharpboundary\" [\"#{luxrender_mat.dm_sharpboundary}\"]"
                    out.puts "\"integer nsubdivlevels\" [#{luxrender_mat.dm_subdivl}]"
                when "microdisplacement"
                    out.puts "\"integer nsubdivlevels\" [#{luxrender_mat.dm_microlevels}]"
            end
			
			if (luxrender_mat.dm_texturetype == 'imagemap' || luxrender_mat.dm_texturetype == 'sketchup')
				out.puts "\"texture displacementmap\" [\""+ texname +"::displacementmap\"]"
			else # procedural
				out.puts "\"texture displacementmap\" [\"#{luxrender_mat.dm_imagemap_proctex}\"]"
            end
			
			out.puts "\"float dmscale\" [#{"%.6f" %(luxrender_mat.dm_scale)}]"
            out.puts "\"float dmoffset\" [#{"%.6f" %(luxrender_mat.dm_offset)}]"
        end
    end
	
	def export_displacement_definition(definition_array, luxrender_mat, texname) # writes to an array that is passed as an argument
        if luxrender_mat.use_displacement
			# puts "exporting displacement"
			# puts luxrender_mat.dm_texturetype
            definition_array << "\"string subdivscheme\" [\"" + luxrender_mat.dm_scheme + "\"]"
            case luxrender_mat.dm_scheme
                when "loop"
                    definition_array << "\"bool dmnormalsmooth\" [\"#{luxrender_mat.dm_normalsmooth}\"]"
                    definition_array << "\"bool dmnormalsplit\" [\"#{luxrender_mat.dm_normalsplit}\"]"
                    definition_array << "\"bool dmsharpboundary\" [\"#{luxrender_mat.dm_sharpboundary}\"]"
                    definition_array << "\"integer nsubdivlevels\" [#{luxrender_mat.dm_subdivl}]"
                when "microdisplacement"
                    definition_array << "\"integer nsubdivlevels\" [#{luxrender_mat.dm_microlevels}]"
            end
			
			if (luxrender_mat.dm_texturetype == 'imagemap' || luxrender_mat.dm_texturetype == 'sketchup')
				definition_array << "\"texture displacementmap\" [\""+ texname +"::displacementmap\"]"
			else # procedural
				definition_array << "\"texture displacementmap\" [\"#{luxrender_mat.dm_imagemap_proctex}\"]"
            end
			
			definition_array << "\"float dmscale\" [#{"%.6f" %(luxrender_mat.dm_scale)}]"
            definition_array << "\"float dmoffset\" [#{"%.6f" %(luxrender_mat.dm_offset)}]"
        end
    end
	
	def export_volumes(out)
		volumeEditor = SU2LUX.get_editor(@scene_id, "volume")
		volumeHash = volumeEditor.getVolumeCollection()
		volumeHash.each do |volumeName, volumeObject|
			export_single_volume(out, volumeName, volumeObject)
		end
	end
	
	def export_single_volume(out, volumeName, volumeObject)
		volumeType = volumeObject.getValue("volume_type")
		volumeParameterHash = volumeObject.getValueHash()
		puts volumeParameterHash
		
		absorption = volumeParameterHash["vol_absorption_swatch"][1]
		aScale = volumeParameterHash["absorption_scale"][1].to_f
		absorption = (absorption[0]*aScale).to_s + " " + (absorption[1]*aScale).to_s + " " + (absorption[2]*aScale).to_s
		
		out.puts "MakeNamedVolume \""  + volumeName + "\" \""+ volumeType + "\""
		out.puts "\t \"float fresnel\" [" + volumeParameterHash["fresnel"][1].to_s + "]"
		case volumeType
			when "clear"
				out.puts "\t \"color absorption\" [" + absorption.to_s + "]"
			when "homogeneous"
				scattering = volumeParameterHash["vol_scattering_swatch"][1]
				sScale = volumeParameterHash["scattering_scale"][1].to_f
				scattering = (scattering[0]*sScale).to_s + " " + (scattering[1]*sScale).to_s + " " + (scattering[2]*sScale).to_s
				out.puts "\t \"color sigma_a\" [" + absorption.to_s + "]"
				out.puts "\t \"color sigma_s\" [" + scattering.to_s + "]"
				if (volumeParameterHash["g"][1].class == String)
					out.puts "\t \"float g\" [" + volumeParameterHash["g"][1].split(",").map{|s| s.to_f}.join(" ") + "]"
				else
					out.puts "\t \"float g\" [" + volumeParameterHash["g"][1].join(" ") + "]"
				end
			when "heterogeneous"
				scattering = volumeParameterHash["vol_scattering_swatch"][1]
				sScale = volumeParameterHash["scattering_scale"][1].to_f
				scattering = (scattering[0]*sScale).to_s + " " + (scattering[1]*sScale).to_s + " " + (scattering[2]*sScale).to_s
				out.puts "\t \"color sigma_a\" [" + absorption.to_s + "]"
				out.puts "\t \"color sigma_s\" [" + scattering.to_s + "]"
				if (volumeParameterHash["g"][1].class == String)
					out.puts "\t \"float g\" [" + volumeParameterHash["g"][1].split(",").map{|s| s.to_f}.join(" ") + "]"
				else
					out.puts "\t \"float g\" [" + volumeParameterHash["g"][1].join(" ") + "]"
				end
				out.puts "\t \"float stepsize\" [" + volumeParameterHash["stepsize"][1].to_s + "]"
		end
		out.puts ""
	end
	
	def export_used_materials(materials, lxm_data, texexport, datafolder)
        mateditor = SU2LUX.get_editor(@scene_id, "material")
        #puts "@texexport: " + texexport
        @texexport = texexport
        @texfolder = File.join(datafolder, SU2LUX::TEXTUREFOLDER)
		
		# create three sets of material definitions, so that mix materials and emitting materials are not defined before their constituent materials
		normal_material_definitions = []
		light_material_definitions = []
		mix_material_definitions = []
		
		materials.each{|skp_mat|
			lux_mat = mateditor.materials_skp_lux[skp_mat]
			mattype = lux_mat.type
			case mattype
				when 'light'
					light_material_definitions << get_material_definition(lux_mat)
				when 'mix'
					mix_material_definitions << get_material_definition(lux_mat)
				when 'portal'
					# do nothing
				else
					normal_material_definitions << get_material_definition(lux_mat)
			end
		}
		
		lxm_data << '' + "\n"
		lxm_data << '# SU2LUX: the following materials are exported by export_used_materials' + "\n"
		lxm_data << '# SU2LUX: the following materials are exported by export_used_materials, normal materials' + "\n"
		lxm_data << '' + "\n"
		
		# add material definitions to material file
		normal_material_definitions.each{|matdef|
			matdef.each{|line|
				lxm_data << line
			}
		}
		
		lxm_data << ''	 + "\n"
		lxm_data << '# SU2LUX: the following materials are exported by export_used_materials, light materials' + "\n"
		lxm_data << '' + "\n"
		light_material_definitions.each{|lightmatdef|
			lightmatdef.each{|line|
				lxm_data << line
			}
		}
		
		lxm_data << ''	 + "\n"
		lxm_data << '# SU2LUX: the following materials are exported by export_used_materials, mix materials' + "\n"
		lxm_data << '' + "\n"
		mix_material_definitions.each{|mixmatdef|
			mixmatdef.each{|line|
				lxm_data << line
			}
		}

        @texexport = "skp" # prevent material preview function from copying textures
	end
    
	def export_distorted_materials(lxm_file, datafolder)
		lxm_file << ''
		lxm_file << '# SU2LUX: the following materials are exported by export_distorted_materials'
		lxm_file << ''
		@distorted_faces.each{|face, skp_mat, dist_index|
			lux_mat = @material_editor.materials_skp_lux[skp_mat]
			distorted_name = lux_mat.name + SU2LUX::SUFFIX_DIST + dist_index.to_s
			material_definition_lines = get_material_definition(lux_mat, distorted_name, true, dist_index)
			material_definition_lines.each{|mat_definition_line|
				lxm_file << mat_definition_line
			}
		}
	end
	
	def export_component_materials(lxm_file)
		#
		# create materials that are applied to geometry with no material in groups or components
		#
		# note: these materials are gathered from component definitions, we still need to gather the materials from component instances
		@component_skp_materials.uniq!
		#puts "number of component materials found:"
		#puts @component_skp_materials.size
		@component_skp_materials.each{|skp_mat|
			# get scale factors
			scale_x = 1.0
			scale_y = 1.0
			if(skp_mat.texture != nil)
				scale_x = 1.0 / skp_mat.texture.width
				scale_y = 1.0 / skp_mat.texture.height
			end
			
			# get luxrender material
			lux_mat = @material_editor.materials_skp_lux[skp_mat]
		
			# get material definition for this material, with scale factor and appropriate name; add to @component_material_definitions
			mat_def = get_material_definition(lux_mat, lux_mat.name, false, 0, true, scale_x, scale_y)
			@component_material_definitions.concat mat_def
			
			#puts "@component_material_definitions size is now:"
			#puts @component_material_definitions.size
		}
	
		#puts "writing component materials, number of lines:"
		#puts @component_material_definitions.size
		#puts "texture export path:"
		#puts @texfolder
		
		lxm_file << "\n\n"
		lxm_file << '# scaled component materials'
		lxm_file << "\n\n"
	
		@component_material_definitions.each{|comp_mat_line|
			lxm_file << comp_mat_line
		}
	end

	def export_texture(lux_mat, tex_channel, type, before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
        #puts "running export_texture, material:" 
		#puts lux_mat.name
		type_str = self.texture_parameters_from_type(tex_channel)
		texture_type = lux_mat.send(tex_channel + "_texturetype")
		
		preceding = ""
		following = ""
		
		if(texture_type != "procedural") # procedural textures are written separately
			if (tex_channel == "normal")
				preceding << "Texture \"#{tex_name}::#{type_str}\" \"#{type}\" \"normalmap\"" + "\n"
			elsif (tex_channel == "bump")
				preceding << "Texture \"#{tex_name}::#{type_str}" + "_unscaled" +  "\" \"#{type}\" \"imagemap\"" + "\n"
			else
				preceding << "Texture \"#{tex_name}::#{type_str}\" \"#{type}\" \"imagemap\"" + "\n"
			end
		end
		
        # preceding << "\t" + "\"string wrap\" [\"#{lux_mat.send(tex_channel + "_imagemap_wrap")}\"]" + "\n"
        if (tex_channel=='dm')
			preceding << "\t" + "\"string channel\" [\"#{lux_mat.send(tex_channel + "_imagemap_channel")}\"]" + "\n"
        end
		case texture_type
			when "sketchup"
				skp_mat = @material_editor.materials_skp_lux.index(lux_mat) # hash.key does not work in Ruby 1.8
                if (skp_mat.texture != nil)
					original_tex_name = get_texture_file_name(skp_mat)
					if(dist_nr != 0) # texture is distorted, insert number
						original_file_name_parts = File.basename(SU2LUX.sanitize_path(original_tex_name)).split('.')
						distorted_file_name = original_file_name_parts[0] + SU2LUX::SUFFIX_DIST + dist_nr.to_s + '.' + original_file_name_parts[1]
						filename = File.join(@texfolder, distorted_file_name)
					else (@texexport == "all")
						filename = File.join(@texfolder, SU2LUX.sanitize_path(File.basename(original_tex_name)))
					end
					#puts "checking filename: "
					#puts filename.to_s
				else
                    puts "export_texture: no texture file path found"
					if(tex_channel == "kd")
						following << "\t" + "\"color Kd\" [#{"%.6f" %(lux_mat.kd_R)} #{"%.6f" %(lux_mat.kd_G)} #{"%.6f" %(lux_mat.kd_B)}]" + "\n"
						return [before, after + following] # sketchup texture set in LuxRender material, but no texture found in SketchUp material
					else
						return [preceding, following]
					end
                end
				#puts 'writing: '
                preceding << "\t" + "\"string filename\" [\"#{filename}\"]" + "\n"	
			when "imagemap"
				if(dist_nr != 0) # texture is distorted, insert number
					original_file_name_parts = File.basename(SU2LUX.sanitize_path(lux_mat.send(tex_channel + "_imagemap_filename"))).split('.')
					distorted_file_name = original_file_name_parts[0] + SU2LUX::SUFFIX_DIST + dist_nr.to_s + '.' + original_file_name_parts[1]
                    imagemap_filename = File.join(@texfolder, File.basename(distorted_file_name))
                elsif (@texexport == "all")
                    imagemap_filename = File.join(@texfolder, File.basename(SU2LUX.sanitize_path(lux_mat.send(tex_channel + "_imagemap_filename"))))
                else
                    imagemap_filename = lux_mat.send(tex_channel + "_imagemap_filename")
					# if the sanitized is not the same as the original path, LuxRender may not be able to read the file, so we use the texture that we copied to the texture folder
					if(imagemap_filename != SU2LUX.sanitize_path(imagemap_filename))
						# otherwise, check the texture folder as we should have copied the texture there
						imagemap_filename = File.join(@texfolder, File.basename(SU2LUX.sanitize_path(imagemap_filename)))
					end
                end
                preceding << "\t" + "\"string filename\" [\"#{imagemap_filename}\"]" + "\n"
			when "procedural"
				# all procedural textures are written in advance, so we only need to write a reference.
				# this is done by write_texture_reference, which is called later
				## following << "\t" + "\"texture Kd\" [\"#{material.kd_imagemap_proctex }\"]" + "\n"
        end
		if(texture_type != "procedural")
			preceding << "\t" + "\"float gamma\" [#{lux_mat.send(tex_channel + "_imagemap_gamma")}]" + "\n"
			preceding << "\t" + "\"float gain\" [#{lux_mat.send(tex_channel + "_imagemap_gain")}]" + "\n"
			preceding << "\t" + "\"string filtertype\" [\"#{lux_mat.send(tex_channel + "_imagemap_filtertype")}\"]" + "\n"
			preceding << "\t" + "\"string mapping\" [\"#{lux_mat.send(tex_channel + "_imagemap_mapping")}\"]" + "\n"
			tex_scale_x = lux_mat.send(tex_channel + "_imagemap_uscale").to_f * scale_x
			tex_scale_y = lux_mat.send(tex_channel + "_imagemap_vscale").to_f * scale_y
			preceding << "\t" + "\"float uscale\" [#{"%.6f" %(tex_scale_x)}]" + "\n"
			preceding << "\t" + "\"float vscale\" [#{"%.6f" %(tex_scale_y)}]" + "\n"
			preceding << "\t" + "\"float udelta\" [#{"%.6f" %(lux_mat.send(tex_channel + "_imagemap_udelta"))}]" + "\n"
			vdelta_value = lux_mat.send(tex_channel + "_imagemap_vdelta").to_f - scale_y
			preceding << "\t" + "\"float vdelta\" [#{"%.6f" %(vdelta_value)}]" + "\n"
		end
		preceding, following = write_texture_reference(lux_mat, tex_channel, type, preceding, following, tex_name)
   
        return [preceding, following]
	end
	
	def write_texture_reference(material, tex_channel, type, prec, foll, tex_name)
		#puts "WRITING TEXTURE REFERENCE LINE"
		type_str = self.texture_parameters_from_type(tex_channel) # bump, Ks, displacementmap etc. 
		
        if (material.send(tex_channel + "_texturetype") == "procedural")
			procTexString = material.send(tex_channel + "_imagemap_proctex")
			puts procTexString
			if(tex_channel == "bump") # separate entry in order to scale 
				foll << "\t" + "\"texture #{type_str}\" [\"" + procTexString + "_scale\"]" + "\n"
			else
				foll << "\t" + "\"texture #{type_str}\" [\"" + procTexString + "\"]" + "\n"
			end
		elsif (material.send(tex_channel + "_imagemap_colorize") == true) 
			prec << "Texture \"#{tex_name}::#{type_str}.scale\" \"#{type}\" \"scale\" \"texture tex1\" [\"#{tex_name}::#{type_str}\"] \"#{type} tex2\" [#{material.channelcolor_tos(tex_channel)}]" + "\n"
			foll << "\t" + "\"texture #{type_str}\" [\"#{tex_name}::#{type_str}.scale\"]" + "\n"
		else # ordinary textures
			foll << "\t" + "\"texture #{type_str}\" [\"#{tex_name}::#{type_str}\"]" + "\n"
		end
		return [prec, foll]
	end


    def export_material_parameters(luxmat, pre, post, texture_name, tex_distorted, distortion_index, is_component_mat = false, scale_x = 0.0, scale_y = 0.0)
		#puts 'running export_material_parameters'
		case luxmat.type
			when "null"
                pre, post = self.export_null(luxmat, pre, post)
			when "mix"
                pre, post = self.export_mix(luxmat, pre, post, texture_name, distortion_index, is_component_mat, scale_x, scale_y)
			when "matte"
                pre, post = self.export_diffuse_component(luxmat, pre, post, texture_name, distortion_index, is_component_mat, scale_x, scale_y)
                pre, post = self.export_sigma(luxmat, pre, post, texture_name, distortion_index, is_component_mat, scale_x, scale_y)
			when "carpaint"
                pre, post = self.export_carpaint_name(luxmat, pre, post)
                if (!luxmat.carpaint_name)
                    pre, post = self.export_diffuse_component(luxmat, pre, post, texture_name, distortion_index, is_component_mat, scale_x, scale_y)
                end
			when "velvet"
                pre, post = self.export_diffuse_component(luxmat, pre, post, texture_name, distortion_index, is_component_mat, scale_x, scale_y)
                pre, post = self.export_sigma(luxmat, pre, post, texture_name, distortion_index, is_component_mat, scale_x, scale_y)
            when "cloth"
                pre, post = self.export_cloth_base(luxmat, pre, post)
                pre, post = self.export_cloth_channel1(luxmat, pre, post, texture_name, distortion_index, is_component_mat, scale_x, scale_y)
                pre, post = self.export_cloth_channel2(luxmat, pre, post, texture_name, distortion_index, is_component_mat, scale_x, scale_y)
                pre, post = self.export_cloth_channel3(luxmat, pre, post, texture_name, distortion_index, is_component_mat, scale_x, scale_y)
                pre, post = self.export_cloth_channel4(luxmat, pre, post, texture_name, distortion_index, is_component_mat, scale_x, scale_y)
			when "glossy"
                pre, post = self.export_diffuse_component(luxmat, pre, post, texture_name, distortion_index, is_component_mat, scale_x, scale_y)
                pre, post = self.export_specular_component(luxmat, pre, post, texture_name, distortion_index, is_component_mat, scale_x, scale_y)
                pre, post = self.export_exponent(luxmat, pre, post, texture_name, distortion_index, is_component_mat, scale_x, scale_y)
                #pre, post = self.export_IOR(luxmat, pre, post, texture_name)
                #pre, post = self.export_spec_IOR(luxmat, pre, post)

                if (luxmat.use_absorption)
                    pre, post = self.export_absorption_component(luxmat, pre, post, texture_name, distortion_index, is_component_mat, scale_x, scale_y)
                end
                multibounce = luxmat.multibounce ? "true": "false"
                post << "\t" + "\"bool multibounce\" [\"#{multibounce}\"]" + "\n"
			when "glass"
                pre, post = self.export_reflection_component(luxmat, pre, post, texture_name, distortion_index, is_component_mat, scale_x, scale_y)
                pre, post = self.export_transmission_component(luxmat, pre, post, texture_name, distortion_index, is_component_mat, scale_x, scale_y)
                pre, post = self.export_IOR(luxmat, pre, post, texture_name, distortion_index, is_component_mat, scale_x, scale_y)
                architectural = luxmat.use_architectural ? "true" : "false"
                post << "\t" + "\"bool architectural\" [\"#{architectural}\"]" + "\n"
                if ( ! luxmat.use_architectural)
                    if (luxmat.use_dispersive_refraction)
                        pre, post = self.export_dispersive_refraction(luxmat, pre, post, texture_name, distortion_index, is_component_mat, scale_x, scale_y)
                    end
                end
			#when "glass2" - no parameters
			when "roughglass"
                pre, post = self.export_reflection_component(luxmat, pre, post, texture_name, distortion_index, is_component_mat, scale_x, scale_y)
                pre, post = self.export_transmission_component(luxmat, pre, post, texture_name, distortion_index, is_component_mat, scale_x, scale_y)
                pre, post = self.export_exponent(luxmat, pre, post, texture_name, distortion_index, is_component_mat, scale_x, scale_y)
                pre, post = self.export_IOR(luxmat, pre, post, texture_name, distortion_index, is_component_mat, scale_x, scale_y)
                pre, post = self.export_dispersive_refraction(luxmat, pre, post, texture_name, distortion_index, is_component_mat, scale_x, scale_y)
			when "metal"
                pre, post = self.export_nk(luxmat, pre, post)
                pre, post = self.export_exponent(luxmat, pre, post, texture_name, distortion_index, is_component_mat, scale_x, scale_y)
            when "metal2"
                pre, post = self.export_metal2(luxmat, pre, post, texture_name, distortion_index, is_component_mat, scale_x, scale_y)
                pre, post = self.export_exponent(luxmat, pre, post, texture_name, distortion_index, is_component_mat, scale_x, scale_y)
			when "shinymetal"
                pre, post = self.export_reflection_component(luxmat, pre, post, texture_name, distortion_index, is_component_mat, scale_x, scale_y)
                pre, post = self.export_specular_component(luxmat, pre, post, texture_name, distortion_index, is_component_mat, scale_x, scale_y)
                pre, post = self.export_exponent(luxmat, pre, post, texture_name, distortion_index, is_component_mat, scale_x, scale_y)
			when "mirror"
                pre, post = self.export_reflection_component(luxmat, pre, post, texture_name, distortion_index, is_component_mat, scale_x, scale_y)
            when "mattetranslucent"
                pre, post = self.export_reflection_component(luxmat, pre, post, texture_name, distortion_index, is_component_mat, scale_x, scale_y)
                pre, post = self.export_transmission_component(luxmat, pre, post, texture_name, distortion_index, is_component_mat, scale_x, scale_y)
                energyconserving = luxmat.energyconserving ? "true": "false"
                post << "\t" + "\"bool energyconserving\" [\"#{energyconserving}\"]" + "\n"
                pre, post = self.export_sigma(luxmat, pre, post, texture_name, distortion_index, is_component_mat, scale_x, scale_y)
			when "glossytranslucent"
                pre, post = self.export_diffuse_component(luxmat, pre, post, texture_name, distortion_index, is_component_mat, scale_x, scale_y)
                pre, post = self.export_transmission_component(luxmat, pre, post, texture_name, distortion_index, is_component_mat, scale_x, scale_y)
                pre, post = self.export_specular_component(luxmat, pre, post, texture_name, distortion_index, is_component_mat, scale_x, scale_y)
                pre, post = self.export_exponent(luxmat, pre, post, texture_name, distortion_index, is_component_mat, scale_x, scale_y)
                pre, post = self.export_IOR(luxmat, pre, post, texture_name, distortion_index, is_component_mat, scale_x, scale_y)
                pre, post = self.export_absorption_component(luxmat, pre, post, texture_name, distortion_index, is_component_mat, scale_x, scale_y)
                multibounce = luxmat.multibounce ? "true": "false"
                post << "\t" + "\"bool multibounce\" [\"#{multibounce}\"]" + "\n"
			when "light"
                pre, post = self.export_mesh_light(luxmat, pre, post, texture_name, distortion_index, is_component_mat, scale_x, scale_y)
		end
        return pre, post
    end # end export_material_parameters

	def process_components()
		component_data = [] # will contain: entityID, transformation, component luxrender material, hash of materials and ply paths, list of (list with child components, child luxrender materials, child transformations)
		
		relevant_components = []
		#puts "processing components"
		Sketchup.active_model.definitions.each{ |this_definition|
			# check if the components are geometric components and are used (this_component.count_instances > 0)
			if(this_definition.is_a?(Sketchup::ComponentDefinition) or this_definition.is_a?(Sketchup::Group)) # this check should not be necessary as the list only contains component definitions
				if this_definition.count_instances > 0
					relevant_components << this_definition
				end
			end
		}
		
		# sort components in such a way that a component never depends on any subsequent components
		relevant_components = sort_components(relevant_components)
		relevant_component_children = {}
		component_material_geometry = {}
		
		relevant_components.each{|comp|
			relevant_component_children[comp] = []
			component_material_geometry[comp] = []
			
			# process faces and child components 
			material_geometry = {} # will contain hashes of skpmat, sketchup face entities 
			@material_editor.materials_skp_lux.keys.each{|skpmat|
				material_geometry[skpmat] = [] # note: distorted materials still need to created separately
			}
			material_geometry["SU2LUX_no_material"] = []
			comp_children = []
			
			comp.entities.each{|e|
				if(e.class == Sketchup::Face and e.layer.visible? and e.visible?)
					facemat = e.material
					if(facemat == nil)
						# if the face has a material on its back side, use that material
						backmat = e.back_material
						if backmat != nil
							material_geometry[backmat] << e
						else
							# if not, add face to collection of faces without material 
							material_geometry["SU2LUX_no_material"] << e
						end
					else
						if material_geometry[facemat] != nil # skip geometry with ghost material
							material_geometry[facemat] << e 
						end
					end
				elsif(e.class == Sketchup::ComponentInstance and e.layer.visible? and e.visible?)
					# for each child component, store "[component entityID, component sketchup material, component transformation]}
					comp_children << [e, e.entityID.to_s, e.material, e.transformation.to_a]
				elsif(e.class == Sketchup::Group and e.layer.visible? and e.visible?)
					# for each child component, store "[component entityID, component sketchup material, component transformation]}
					comp_children << [e, @group_definition_hash[e].entityID.to_s, e.material, e.transformation.to_a]
				end
			}

			component_material_geometry[comp] = material_geometry
			relevant_component_children[comp] = comp_children
		}
		return [relevant_components, component_material_geometry, relevant_component_children]	
	end
	
	def get_component_instances()
		group_definition_hash = {}
		# for this model, iterate all component definitions
		# get definition instances; if the instance is a group, add it to the hash
		# note: for recent versions of SketchUp, we could skip this step and get the definitions through group.definition
		@model.definitions.each{|comp_def|
			comp_def.instances.each{|inst|
				if inst.class == Sketchup::Group
					group_definition_hash[inst] = comp_def
				end
			}
		}
		#@group_definition_hash = group_definition_hash
		return group_definition_hash
	end	
	
	
	
	def sort_components(passed_component_definitions)
		relevant_component_definitions = passed_component_definitions
		
		#store components as {component => [childcomponentdefinition0, childcomponentdefinition5, childcomponentdefinition6(, group?])}
		component_hashes = {}

		# process relevant components; get child component definitions
		relevant_component_definitions.each{|this_definition|
			collected_child_components = []
			this_definition.entities.each{|e|
				if e.is_a?(Sketchup::ComponentInstance) 
					# adding child (component)
					collected_child_components << e.definition
				elsif e.is_a?(Sketchup::Group)
					# adding child (group)
					collected_child_components << @group_definition_hash[e]
				end
			}
			component_hashes[this_definition] = collected_child_components
		}

		sorted_components = []
		maxtries = 30 # maximum recursion depth - used as a safety net to prevent infinite loops

		while(relevant_component_definitions.size > 0 and maxtries > 0)
			maxtries = maxtries - 1
			postponed_components = []
			#check if definition has children; if not, add to list and remove from original; also remove from all child component lists
			relevant_component_definitions.each{|comp|
				#puts "processing..."
				#puts comp
				if(component_hashes[comp] == [])
					#puts 'adding component to sorted_component list'
					sorted_components << comp
					# remove from child component lists
					relevant_component_definitions.each{|d|
						component_hashes[d].delete(comp)
					}
					postponed_components.each{|d|
						component_hashes[d].delete(comp)
					}
				else
					postponed_components << comp
				end
			}
			relevant_component_definitions = postponed_components
		end
		#puts "number of components to return:"
		#puts sorted_components.size
		return sorted_components
	end
	
	
	def get_material_definition(lux_mat, distortedname = nil, texdistorted = false, distorted_index = 0, is_component_mat = false, scale_x = 1.0, scale_y = 1.0) # returns material definition as a list of strings (otherwise similar to export_mat)
		#puts 'running get_material_definition for ' + lux_mat.name
		currentmatname = distortedname ? distortedname : lux_mat.name # materialname_dist42 # also used as texture name for SketchUp texture
		if(is_component_mat)
			currentmatname = currentmatname + '_component_material'
		end
        
        # export main material properties
		pre = ""
		matdefinition = []
		post = ""
        pre, post = export_material_parameters(lux_mat, pre, post, currentmatname, texdistorted, distorted_index, is_component_mat, scale_x, scale_y)
        
		# export additional material properties
        if (lux_mat.use_thin_film_coating)
			puts 'adding thin film coating'
            pre, post = self.export_thin_film(lux_mat, pre, post, currentmatname, distorted_index, is_component_mat, scale_x, scale_y)
        end
		if (lux_mat.has_bump?)
			puts 'adding bump map'
            pre, post = self.export_bump(lux_mat, pre, post, currentmatname, distorted_index, is_component_mat, scale_x, scale_y)
		end
        if (lux_mat.has_normal?)
			puts 'adding normal map'
            pre, post = self.export_normal(lux_mat, pre, post, currentmatname, distorted_index, is_component_mat, scale_x, scale_y)
		end
        if (lux_mat.has_displacement?)
			puts "adding displacement map"
			pre, post = self.export_displacement(lux_mat, pre, post, currentmatname, distorted_index, is_component_mat, scale_x, scale_y)
		end
        
        matnamecomment = "# Material '" + currentmatname + "'\n"
		matdeclaration_statement1 = "MakeNamedMaterial \"#{SU2LUX.sanitize_path(currentmatname)}\"\n"
		matdeclaration_statement2 = "\t\"string type\" [\"#{lux_mat.type}\"]\n"
        
		if (lux_mat.type == "light")
            if lux_mat.lightbase == 'default'
				matdefinition <<  pre
				matdefinition << matnamecomment
				matdefinition <<  "\n"
			elsif lux_mat.lightbase == 'invisible'
				matdefinition <<  pre
				matdefinition <<  matnamecomment
				matdefinition <<  matdeclaration_statement1
				matdefinition <<  '"string type" ["null"]'
				matdefinition <<  "\n"
			else
				# write reference to base material, use mix material as a workaround
				matdefinition <<  pre
				matdefinition <<  matnamecomment
				matdefinition <<  matdeclaration_statement1
				matdefinition <<  "\t" + '"string type" ["mix"]' + "\n"
				matdefinition <<  "\t" + '"string namedmaterial1" ["' + lux_mat.lightbase + '"]' + "\n"
				matdefinition <<  "\t" + '"string namedmaterial2" ["' + lux_mat.lightbase + '"]' + "\n"
			end	
        else
            if (lux_mat.use_auto_alpha == true)
                puts "exporting alpha transparency"
                # export material as mix material
                matdefinition <<  "# auto-alpha material for Material '" + currentmatname + "'\n"
                # define null material
                matdefinition <<  "# Material 'Mix_Null'\n"
                matdefinition <<  "MakeNamedMaterial \"Mix_Null\"\n"
                matdefinition <<  "\t\"string type\" [\"null\"]\n\n"
                # define main material (with altered name) and texture
                matdefinition << "# Original material texture and material definition \n"
                matdefinition <<  pre
                matdefinition <<  "# Material 'Mix_Original'\n"
                matdefinition <<  "MakeNamedMaterial \"Mix_Original\"\n"
                matdefinition <<  matdeclaration_statement2
                matdefinition <<  post
                matdefinition <<  "\n\n"
                # write mix texture
                matdefinition <<  "# Generated mix texture \n"
                matdefinition <<  'Texture "' + lux_mat.name + '_automix::amount" "float" "imagemap"' + "\n"
                imagemap_filename = ""
                if (lux_mat.aa_texturetype == "sketchupalpha") ## sketchup texture
					skp_mat = @material_editor.materials_skp_lux.index(lux_mat) # hash.key does not work in Ruby 1.8
                    if (skp_mat.texture != nil)
                        tex_filename = get_texture_file_name(skp_mat)
                        imagemap_filename = File.join(File.basename(@export_file_path, SU2LUX::SCENE_EXTENSION) + SU2LUX::SUFFIX_DATAFOLDER, SU2LUX::TEXTUREFOLDER, tex_filename)
                    end
               else ## image texture
                    if (@texexport == "all")
                        imagemap_filename = File.join(@texfolder, File.basename(SU2LUX.sanitize_path(lux_mat.send("aa_imagemap_filename"))))
                    else
                        imagemap_filename = SU2LUX.sanitize_path(lux_mat.send("aa_imagemap_filename"))
                    end
                end
                matdefinition <<  "\t\"string filename\" [\"#{imagemap_filename}\"]\n"
                matdefinition <<  "\t\"float gamma\" [#{lux_mat.send("aa_imagemap_gamma")}]\n"
                matdefinition <<  "\t\"float gain\" [#{lux_mat.send("aa_imagemap_gain")}]\n"
                matdefinition <<  "\t\"string wrap\" [\"repeat\"] \n"
                if (lux_mat.aa_texturetype=="imagealpha" || lux_mat.aa_texturetype=="sketchupalpha")
                    matdefinition <<  "\t\"string channel\" [\"alpha\"]\n"
                else
                    matdefinition <<  "\t\"string channel\" [\"mean\"]\n"
                end
                matdefinition <<  "\t\"string filtertype\" [\"" + lux_mat.aa_imagemap_filtertype + "\"]\n"
                matdefinition <<  "\t\"string mapping\" [\"uv\"]\n"
                matdefinition <<  "\t\"float uscale\" [" + lux_mat.aa_imagemap_uscale.to_s + "]\n"
                matdefinition <<  "\t\"float vscale\" [" + lux_mat.aa_imagemap_vscale.to_s + "]\n"
                matdefinition <<  "\t\"float udelta\" [" + lux_mat.aa_imagemap_udelta.to_s + "]\n"
                matdefinition <<  "\t\"float vdelta\" [" + lux_mat.aa_imagemap_vdelta.to_s + "]\n\n"
                # define mix material with matdeclaration_statement
                matdefinition <<  matnamecomment
                matdefinition <<  matdeclaration_statement1
                matdefinition <<  "\t\"string type\" [\"mix\"]" + "\n"
                matdefinition <<  "\t\"texture amount\" [\"" + lux_mat.name +  "_automix::amount\"]\n"
                matdefinition <<  "\t\"string namedmaterial1\" [\"Mix_Null\"]\n"
                matdefinition <<  "\t\"string namedmaterial2\" [\"Mix_Original\"]\n"
            else # export ordinary material
                matdefinition <<  matnamecomment
                matdefinition <<  pre # if (pre != "")
                matdefinition <<  matdeclaration_statement1
                matdefinition <<  matdeclaration_statement2
                matdefinition <<  post
            end
		end
		matdefinition << "\n"
		return matdefinition
	end # END get_material_definition
	
	##
	# get the file name of a SketchUp material's texture
	##
	def get_texture_file_name(skpmat) # note: removes folder structure
		original_tex_name = skpmat.texture.filename # may include full path
		tex_basename = File.basename(original_tex_name.split("\\").last) # removes the folder structure
		tex_extension = File.extname(tex_basename)
		tex_corename = File.basename(tex_basename, tex_extension)
		tex_extension = ".jpg" if tex_extension == ""
		tex_extension = ".png" if (tex_extension.upcase ==".BMP" or tex_extension.upcase ==".GIF" or tex_extension.upcase ==".PNG") #Texture writer converts BMP and GIF to PNG
		tex_extension = ".tif" if (tex_extension.upcase=="TIFF" or tex_extension.upcase==".TIF")
		tex_extension = ".jpg" if tex_extension.upcase==".JPG"
		return tex_corename + tex_extension
	end 

	def export_diffuse_component(lux_mat, before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
		#puts "exporting diffuse component for material " + lux_mat.name
		preceding = ""
		following = ""
		if lux_mat.kd_texturetype == "none"
			following << "\t" + "\"color Kd\" [#{"%.6f" %(lux_mat.kd_R)} #{"%.6f" %(lux_mat.kd_G)} #{"%.6f" %(lux_mat.kd_B)}]" + "\n"
		else
			if (lux_mat.send("kd_imagemap_colorize") == true)
                preceding << "Texture \"#{tex_name}::Kd.scale\" \"color\" \"scale\"" + "\n\t" + "\"texture tex1\" [\"#{tex_name}::Kd\"]" + "\n\t" + "\"color tex2\" [#{lux_mat.channelcolor_tos('kd')}]" + "\n"
				following << "\t" + "\"texture Kd\" [\"#{tex_name}::Kd.scale\"]" + "\n"
			end
			# call export_texture
			preceding, following = self.export_texture(lux_mat, "kd", "color", before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
		end
		return [before + preceding, after + following]
	end
	
	def get_distorted_name(tex_name, dist_index) # note: returns a single file name, not a full path
		if(dist_index == 0)
			return tex_name
		else
			# remove extension, add _dist##, add extension 
			return File.basename(tex_name, '.*') + SU2LUX::SUFFIX_DIST + dist_index.to_s + '.' + File.extname(tex_name)
		end
	end

	def export_sigma(material, before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
		preceding = ""
		following = ""
		if ( ! material.has_texture?("matte_sigma"))
			following << "\t" + "\"float sigma\" [#{material.matte_sigma}]" + "\n"
		else
			preceding, following = self.export_texture(material, "matte_sigma", "float", before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
		end
		return [before + preceding, after + following]
	end

	def export_specular_component(material, before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
		preceding = ""
		following = ""
        if (material.specular_scheme == "specular_scheme_preset")
            following << "\t" + "\"float index\" [#{material.specular_preset}]\n"
        elsif (material.specular_scheme == "specular_scheme_IOR")
            if (material.has_texture?("spec_IOR"))
                preceding, following = self.export_texture(material, "spec_IOR", "float", before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
            else
                following << "\t" + "\"float index\" [#{material.spec_IOR}]\n"
            end
        else
            if (material.has_texture?("ks"))	
                preceding, following = self.export_texture(material, "ks", "color", before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
            else
                following << "\t" + "\"color Ks\" [#{"%.6f" %(material.ks_R)} #{"%.6f" %(material.ks_G)} #{"%.6f" %(material.ks_B)}]" + "\n"
            end
        end
		return [before + preceding, after + following]
	end
    
    def export_cloth_base(material, before,after)
		preceding = ""
		following = ""
        # add cloth type, u scale, v scale
        following << "\t" + "\"string presetname\" [\"#{material.cl_type}\"]" + "\n"
        following << "\t" + "\"float repeat_u\" [#{material.cl_repeatu}]" + "\n"
        following << "\t" + "\"float repeat_v\" [#{material.cl_repeatv}]" + "\n"
        
        return [before + preceding, after + following]
	end
    
    def export_cloth_channel1(material, before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
        preceding = ""
        following = ""
        if (!material.has_texture?("cl1kd"))
            following << "\t" + "\"color warp_Kd\" [#{material.channelcolor_tos('cl1kd')}]" + "\n"
        else
            preceding, following = self.export_texture(material, "cl1kd", "color", before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
        end
        return [before + preceding, after + following]
    end
    
    def export_cloth_channel2(material, before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
        preceding = ""
        following = ""
        if(!material.has_texture?("cl1ks"))
            following << "\t" + "\"color warp_Ks\" [#{material.channelcolor_tos('cl1ks')}]" + "\n"
        else
            preceding, following = self.export_texture(material, "cl1ks", "color", before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
        end
        return [before + preceding, after + following]
    end

    def export_cloth_channel3(material, before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
        preceding = ""
        following = ""
        if(!material.has_texture?("cl2kd"))
            following << "\t" + "\"color weft_Kd\" [#{material.channelcolor_tos('cl2kd')}]" + "\n"
        else
            preceding, following = self.export_texture(material, "cl2kd", "color", before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
        end
        return [before + preceding, after + following]
    end

    def export_cloth_channel4(material, before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
        preceding = ""
        following = ""
        if (!material.has_texture?("cl2ks"))
            following << "\t" + "\"color weft_Ks\" [#{material.channelcolor_tos('cl2ks')}]" + "\n"
        else
            preceding, following = self.export_texture(material, "cl2ks", "color", before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
        end
        return [before + preceding, after + following]
    end

	def export_null(material, before, after)
		preceding = ""
		following = ""
		#following << "\t" + "\"string type\" [\"null\"]"+ "\n\n"

		return [before + preceding, after + following]
	end
    
	def export_mix(material, before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
		puts "MATERIAL.MX_TEXTURETYPE: " + material.mx_texturetype
		preceding = ""
		following = ""
        mixmat1 = material.material_list1 #.delete("[<>]")
        mixmat2 = material.material_list2 #.delete("[<>]")
        case material.mx_texturetype
            when "none"
                following << "\t" + "\"string namedmaterial1\" [\"#{mixmat1}\"]" + "\n"
                following << "\t" + "\"string namedmaterial2\" [\"#{mixmat2}\"]" + "\n"
                mixamount = 1 - material.mix_uniform.to_f / 100
                mixamountstring = mixamount.to_s
                following << "\t" + "\"float amount\" [" + mixamountstring +"]" + "\n"
            when "sketchup"
                preceding, following = self.export_texture(material, 'mx', 'float', before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
                following << "\t" + "\"string namedmaterial1\" [\"#{mixmat1}\"]" + "\n"
                following << "\t" + "\"string namedmaterial2\" [\"#{mixmat2}\"]" + "\n"
            when "imagemap"
                preceding, following = self.export_texture(material, 'mx', 'float', before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
                following << "\t" + "\"string namedmaterial1\" [\"#{mixmat1}\"]" + "\n"
                following << "\t" + "\"string namedmaterial2\" [\"#{mixmat2}\"]" + "\n"
			when "procedural"
				preceding, following = self.write_texture_reference(material, 'mx', 'float', "", "", tex_name)
                following << "\t" + "\"string namedmaterial1\" [\"#{mixmat1}\"]" + "\n"
                following << "\t" + "\"string namedmaterial2\" [\"#{mixmat2}\"]" + "\n"

		end
		return [before + preceding, after + following]
	end

	def export_carpaint_name(material, before, after)
		preceding = ""
		following = ""
		if (material.carpaint_name)
			following << "\t" + "\"string name\" [\"#{material.carpaint_name}\"]" + "\n"
		end
		return [before + preceding, after + following]
	end

	def export_exponent(material, before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
		preceding = ""
		following = ""
		material.uroughness = Math.sqrt(2.0 / (material.u_exponent.to_f + 2))
		material.vroughness = Math.sqrt(2.0 / (material.v_exponent.to_f + 2))
		if ( ! material.has_texture?('u_exponent'))
			following << "\t" + "\"float uroughness\" [#{"%.6f" %(material.uroughness)}]" + "\n"
			following << "\t" + "\"float vroughness\" [#{"%.6f" %(material.vroughness)}]" + "\n"
		else
			preceding_t, following_t = self.export_texture(material, "u_exponent", "float", before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
			preceding, following = self.export_texture(material, "v_exponent", "float", before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
			preceding = preceding_t+ preceding
			following = following_t + following
		end
		return [before + preceding, after + following]
	end

	def export_IOR(material, before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
		preceding = ""
		following = ""
		if ( ! material.has_texture?('IOR_index'))
			following << "\t" + "\"float index\" [#{material.IOR_index}]\n"
		else
			preceding, following = self.export_texture(material, 'IOR_index', 'float', before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
		end
		return [before + preceding, after + following]
	end

	def export_absorption_component(material, before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
		preceding = ""
		following = ""
		if (!material.has_texture?('ka'))
			#following << "\t" + "\"color Ka\" [#{"%.6f" %(material.absorption[0])} #{"%.6f" %(material.absorption[1])} #{"%.6f" %(material.absorption[2])}]" + "\n"
			following << "\t" + "\"color Ka\" [#{"%.6f" %(material.ka_R)} #{"%.6f" %(material.ka_G)} #{"%.6f" %(material.ka_B)}]" + "\n"
		else
			preceding, following = self.export_texture(material, "ka", "color", before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
		end
		if (!material.has_texture?('ka_d'))
			following << "\t" + "\"float d\" [#{"%.6f" %(material.ka_d)}]" + "\n"
		else
			preceding, following = self.export_texture(material, "d", "float", before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
		end
		return [before + preceding, after + following]
	end

	def export_nk(material, before, after)
		preceding = ""
		following = ""
		following << "\t" + "\"string name\" [\"#{material.nk_preset}\"]" + "\n"
		return [before + preceding, after + following]
	end
    
    def export_metal2(material, before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
        preceding = ""
        following = ""
        if (material.metal2_preset == "custom")
            if (material.has_texture?('km2'))
                preceding, preceding2 = self.export_texture(material, "km2", "color", before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
                preceding << "\n" + "Texture \"#{tex_name}::Km2_fresnel\" \"fresnel\" \"fresnelcolor\"" + "\n"
                preceding << preceding2
            else
                preceding << "Texture \"#{tex_name}::Km2_fresnel\" \"fresnel\" \"fresnelcolor\"" + "\n"
                preceding << "\t" + "\"color Kr\" [#{material.km2_R} #{material.km2_G} #{material.km2_B}]" + "\n" + "\n"
            end
        else # preset
            preceding << "Texture \"#{tex_name}::Km2_fresnel\" \"fresnel\" \"preset\"" + "\n"
            preceding << "\"string name\" [\"" + material.metal2_preset + "\"]" + "\n" + "\n"
        end
        following << "\t" + "\"texture fresnel\" [\"#{tex_name}::Km2_fresnel\"]" + "\n"
        return [before + preceding, after + following]
    end

	def export_reflection_component(material, before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
		preceding = ""
		following = ""
		if ( ! material.has_texture?('kr'))
			following << "\t" + "\"color Kr\" [#{"%.6f" %(material.kr_R)} #{"%.6f" %(material.kr_G)} #{"%.6f" %(material.kr_B)}]" + "\n"
		else
			preceding, following = self.export_texture(material, 'kr', 'color', before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
		end
		return [before + preceding, after + following]
	end

	def export_transmission_component(material, before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
		preceding = ""
		following = ""
		if ( ! material.has_texture?('kt'))
			following << "\t" + "\"color Kt\" [#{"%.6f" %(material.kt_R)} #{"%.6f" %(material.kt_G)} #{"%.6f" %(material.kt_B)}]" + "\n"
		else
			preceding, following = self.export_texture(material, 'kt', 'color', before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
		end
		return [before + preceding, after + following]
	end

	def export_thin_film(material, before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
        puts "exporting thin film"
		preceding = ""
		following = ""
		if ( ! material.has_texture?('film'))
			following << "\t" + "\"float film\" [#{"%.6f" %(material.film)}]" + "\n"
		else
			preceding, following = self.export_texture(material, 'film', 'float', before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
		end
		if ( ! material.has_texture?('filmindex'))
			following << "\t" + "\"float filmindex\" [#{"%.6f" %(material.filmindex)}]" + "\n"
		else
			preceding, following = self.export_texture(material, 'filmindex', 'float', before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
		end
		return [before + preceding, after + following]
	end

	def export_dispersive_refraction(material, before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
		preceding = ""
		following = ""
		if ( ! material.has_texture?('cauchyb'))
			following << "\t" + "\"float cauchyb\" [#{"%.6f" %(material.cauchyb)}]" + "\n"
		else
			preceding, following = self.export_texture(material, 'cauchyb', 'float', before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
		end
		return [before + preceding, after + following]
	end
    
	def export_bump(material, before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
		preceding = ""
		following = ""
		# if image texture:
		if (material.bump_texturetype == 'imagemap' || material.bump_texturetype == 'sketchup')
			preceding, following = self.export_texture(material, "bump", "float", before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
			preceding << "Texture \"#{tex_name}::bumpmap\" \"float\" \"scale\"" + "\n"
			preceding << "\t" + "\"float tex1\" [#{material.bumpmap}]" + "\n"
			preceding << "\t" + "\"texture tex2\" [\"#{tex_name}::bumpmap_unscaled\"]" + "\n"
		else # procedural (needed to scale texture)
			preceding, following = write_texture_reference(material, "bump", material.type, preceding, following, tex_name)
			preceding << "Texture \"#{material.bump_imagemap_proctex}_scale\" \"float\" \"scale\"" + "\n"
			preceding << "\t" + "\"float tex1\" [#{material.bumpmap}]" + "\n"
			preceding << "\t" + "\"texture tex2\" [\"#{material.bump_imagemap_proctex}\"]" + "\n"
		end
		# todo: make original bump always refer to this scale texture -> add "_scale" to texture name
		return [before + preceding, after + following]
	end
	
	def export_normal(material, before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
		preceding = ""
		following = ""
        preceding, following = self.export_texture(material, "normal", "float", before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
		return [before + preceding, after + following]
	end

	def export_displacement(material, before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
		preceding = ""
		following = ""
		if (material.has_texture?('dm') && material.dm_texturetype != "procedural")
            puts ("material.has_texture? dm is true")
			preceding, following = self.export_texture(material, "dm", "float", before, after, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
		end
		
		return [before + preceding, after] # following parts would be added to geometry, not to material definition
	end

	def export_mesh_light (material, pre, post, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
        puts "exporting blackbody texture"
        preceding = pre # empty
        following = post # empty
        if material.light_L == "blackbody"
            preceding << "Texture \"" + material.name + ":light:L\"" + "\n"
            preceding << "\t" + "\"color\" \"blackbody\"" + "\n"
            preceding << "\t" + "\"float temperature\" [#{material.light_temperature}]" + "\n"
			
        elsif material.light_L == "emit_preset"
            preceding << "Texture \"" + material.name + ":light:L\"" + "\n"
            preceding << "\t" + "\"color\" \"lampspectrum\""  + "\n"
            preceding << "\t" + "\"string name\" [\"" + material.light_spectrum+ "\"]" + "\n"
        else
            if (material.has_texture?('em'))
                preceding, following = self.export_texture(material, "em", "color", preceding, following, tex_name, dist_nr, is_component_mat, scale_x, scale_y)
            else
                following = "\t" + "\"color L\" [" + material.em_R.to_s + " " + material.em_G.to_s + " " + material.em_B.to_s + "]"
            end
        end
        return [preceding, following]
	end

	def texture_parameters_from_type(mat_type)
		case mat_type
			when 'kd'
				type_str = "Kd"
			when 'bump'
				type_str = "bumpmap"
			when 'dm'
				type_str = "displacementmap"
			when 'matte_sigma'
				type_str = "sigma"
			when 'ks'
				type_str = "Ks"
			when 'ka'
				type_str = "Ka"
            when 'km2'
                type_str = "Kr"
			when 'ka_d'
				type_str = "d"
			when 'kr'
				type_str = "Kr"
			when 'kt'
				type_str = "Kt"
            when 'em'
                type_str = "L"
            when 'normal'
				type_str = "bumpmap"
            when 'IOR_index'
				type_str = 'index'
            when 'spec_IOR'
				type_str = 'index'
			when 'u_exponent'
				type_str = 'uroughness'
			when 'v_exponent'
				type_str = 'vroughness'
			when 'mx'
				type_str = 'amount'
			when 'carpaint_name'
				type_str = 'carpaint_name'
            when 'cl1kd'
                type_str = 'warp_Kd'
            when 'cl1ks'
                type_str = 'warp_Ks'
            when 'cl2kd'
                type_str = 'weft_Kd'
            when 'cl2ks'
                type_str = 'weft_Ks'
			else
				type_str = mat_type
		end
		return type_str
	end
	
end # END class LuxrenderExport
