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

class LuxrenderMaterial

    attr_reader :dict, :mat, :swatch_channels
    attr_accessor :name_string
	alias_method :dictionary_name, :dict
    
	@@methods_created = false
	
	@@settings=
	{
		'type' => "glossy",
		'kd_imagemap_Sketchup_filename' => '',
        'texturechannels' => ["kd", "ks", "ka", "km2", "em", "mx", "u_exponent", "v_exponent", "uroughness", "vroughness", "aa", "cl1kd", "cl1ks", "cl2kd", "cl2ks", "ka_d", "spec_IOR", "IOR_index", "kr", "kt", "cauchyb", "film", "filmindex", "bump", "normal", "dm"],
        		
		'kd_R' => 0.64,
		'kd_G' => 0.64,
		'kd_B' => 0.64,

		'ks_R' => 0.1,
		'ks_G' => 0.1,
		'ks_B' => 0.1,

		'ka_R' => 0.0,
		'ka_G' => 0.0,
		'ka_B' => 0.0,

		'kr_R' => 1.0,
		'kr_G' => 1.0,
		'kr_B' => 1.0,
        
		'kt_R' => 1.0,
		'kt_G' => 1.0,
		'kt_B' => 1.0,
        
		'km2_R' => 1.0,
		'km2_G' => 1.0,
		'km2_B' => 1.0,
        
		'em_R' => 0.9,
		'em_G' => 1.0,
		'em_B' => 0.8,
        
        'cl1kd_R' => 0.8,
        'cl1kd_G' => 0.0,
        'cl1kd_B' => 0.0,
        
        'cl1ks_R' => 0.1,
        'cl1ks_G' => 0.1,
        'cl1ks_B' => 0.1,
        
        'cl2kd_R' => 0.8,
        'cl2kd_G' => 0.8,
        'cl2kd_B' => 0.0,
        
        'cl2ks_R' => 0.1,
        'cl2ks_G' => 0.1,
        'cl2ks_B' => 0.1,

		'u_exponent' => 50,
		'v_exponent' => 50,
		'uroughness' => 0.1,
		'vroughness' => 0.1,

		'mix_uniform' => 50.0,
		'material_list1' => '',
		'material_list2' => '',
        
        'cl_repeatu' => 80.0,
        'cl_repeatv' => 80.0,
        'cl_type' => "cotton_twill",
        
		'matte_sigma' => 0.0,
		'ka_d' => 0.0,
		'IOR_index' => 1.5,
		'multibounce' => false,
		'cauchyb' => 0.004,
		'film' => 200,
		'filmindex' => 1.5,
		'nk_preset' => 'aluminium',
        'metal2_preset' => 'aluminium',
		'carpaint_name' => '',
		'energyconserving' => true,
		'bumpmap' => 0.005,
		'volume_interior' => 'default',
		'volume_exterior' => 'default',

		'dm_scheme' => 'loop',
		'dm_normalsmooth' => true,
        'dm_normalsplit' => false,
        'dm_sharpboundary' => false,
		'dm_subdivl' => '2',
        'dm_microlevels' => '10',
		'dm_scale' => 0.1,
		'dm_offset' => 0.000,
		'displacement' => 1.000000,
        
        'specular_scheme' => 'specular_scheme_IOR',
        'spec_IOR' => 1.33,
        'specular_preset' => 1.360001,

		'light_L' => 'blackbody',
        'light_spectrum' => 'Incandescent1',
		'light_temperature' => 6500.0,
		'light_power' => 100.0,
		'light_efficacy' => 17.0,
		'light_gain' => 1000.0,
        'lightbase' => 'invisible',
		'ies_path' => '',

		'use_architectural' => false,
        'use_auto_alpha' => false,
		'use_absorption' => false,
		'use_dispersive_refraction' => false,
		'use_thin_film_coating' => false,
		'use_bump' => false,
        'use_normal' => false,
		'use_displacement' => false,
        # 'aa_texturetype' => 'sketchup',
	}
    
	##
	#
	##
	def lux_image_texture(material, name, texture, type)
		material_prefix = material
		material_prefix << "_" if (!material.empty?)
		key_prefix = material_prefix + "#{name}"
		key = "#{key_prefix}_#{texture}_"
        if (name=="aa")
            @@settings[key_prefix + "_texturetype"] = "sketchupalpha" # autoalpha does not have "none" setting
        else
            @@settings[key_prefix + "_texturetype"] = "none" # for example kd_texturetype
        end
        @@settings[key + "colorize"] = false             # for example kd_imagemap_colorize
		@@settings[key + "wrap"] = "repeat"
		@@settings[key + "channel"] = "mean" if (type == "float")
		@@settings[key + "filename"] = ""
		@@settings[key + "gamma"] = 2.2
        if(name=="normal")
            @@settings[key + "gamma"] = 1.0
        end
		@@settings[key + "gain"] = 1.0
		@@settings[key + "filtertype"] = "bilinear"
		@@settings[key + "mapping"] = "uv"
		@@settings[key + "uscale"] = 1.0
		@@settings[key + "vscale"] = 1.0
		@@settings[key + "udelta"] = 0.0
		@@settings[key + "vdelta"] = 0.0
		@@settings[key + "proctex"] = ""
		@@settings[key + "maxanisotropy"] = 8.0
		@@settings[key + "discardmipmaps"] = 0
		# @@settings[key + "uvset"] = 0
	end
	
	##
	#
	##
	def LuxrenderMaterial::ui_refreshable?(id)
		ui_refreshable_settings = [
			"kd_imagemap_filename",
			"matte_sigma_imagemap_filename",
			"ks_imagemap_filename",
			"km2_imagemap_filename",
            "em_imagemap_filename",
			"uroughness_imagemap_filename",
			"vroughness_imagemap_filename",
            "aa_imagemap_filename",
            
			"cl1kd_imagemap_filename",
			"cl1ks_imagemap_filename",
			"cl2kd_imagemap_filename",
			"cl2ks_imagemap_filename",
            
            "spec_IOR_imagemap_filename",
            "IOR_index_imagemap_filename",
            
			"ka_imagemap_filename",
			"ka_d_imagemap_filename",
			"kr_imagemap_filename",
			"kt_imagemap_filename",
			"mx_imagemap_filename",
		]
		if ui_refreshable_settings.include?(id)
			return id
		else
			return "not_ui_refreshable"
		end
	end # END LuxrenderMaterial::ui_refreshable?

	##
	#
	##
	def initialize(su_material, matEditor) # creates LuxrenderMaterial object
		@model = Sketchup.active_model
		@material_editor = matEditor
        if su_material.class == String
            if @model.materials[su_material].class == Sketchup::Material
                @mat = @model.materials[su_material]
            else
                puts "could not find material #{su_material}, using material 0 instead"
                @mat = @model.materials[0]
            end
        else
            @mat = su_material
        end
		@uvs = {}
		
		lux_image_texture("", "kd", "imagemap", "color")
		lux_image_texture("matte", "sigma", "imagemap", "float")
		lux_image_texture("", "ks", "imagemap", "color")
		lux_image_texture("", "ka", "imagemap", "color")
		lux_image_texture("", "km2", "imagemap", "color")
		lux_image_texture("", "em", "imagemap", "color")
		lux_image_texture("", "mx", "imagemap", "float") # mix
		lux_image_texture("", "u_exponent", "imagemap", "float")
		lux_image_texture("", "v_exponent", "imagemap", "float")
		lux_image_texture("", "uroughness", "imagemap", "float")
		lux_image_texture("", "vroughness", "imagemap", "float")
		lux_image_texture("", "aa", "imagemap", "float")
		lux_image_texture("", "cl1kd", "imagemap", "color")
		lux_image_texture("", "cl1ks", "imagemap", "color")
		lux_image_texture("", "cl2kd", "imagemap", "color")
		lux_image_texture("", "cl2ks", "imagemap", "color")
        lux_image_texture("", "ka_d", "imagemap", "float")
        lux_image_texture("", "IOR_index", "imagemap", "float")
        lux_image_texture("", "spec_IOR", "imagemap", "float")
		lux_image_texture("", "kr", "imagemap", "color")
		lux_image_texture("", "kt", "imagemap", "color")
		# lux_image_texture("", "IOR", "imagemap", "float")
		lux_image_texture("", "cauchyb", "imagemap", "float")
		lux_image_texture("", "film", "imagemap", "float")
		lux_image_texture("", "filmindex", "imagemap", "float")
		lux_image_texture("", "bump", "imagemap", "float")
		lux_image_texture("", "normal", "imagemap", "float")
		lux_image_texture("", "dm", "imagemap", "float")
		
        # puts "LuxrenderMaterial.rb self object: ", self # returns #<LuxrenderMaterial:........>
        @name_string = su_material.name.to_s
		singleton_class = (class << self; self; end)
		@view = @model.active_view
		@skp_mat_name = mat.name
        @attributeDictionary = LuxrenderAttributeDictionary.new(@model)
        
        # puts "singleton_class inspect ",singleton_class.inspect
		
		if !@@methods_created
			#singleton_class.module_eval do
			LuxrenderMaterial.module_eval do
				define_method("[]") do |key|  # method [] for <LuxrenderMaterial:........> # allows getting LuxMat[property]
					value = @@settings[key]
					return @attributeDictionary.get_attribute(@skp_mat_name, key, value)
				end
				
				@@settings.each do |key, value|
					######## -- get any attribute -- #######
					define_method(key){ # allows calling LuxMat(property)
						@attributeDictionary.get_attribute(@skp_mat_name, key, value)
					}

					case key
						when LuxrenderMaterial::ui_refreshable?(key)# update UI after changing value (todo 2015: does this UI update work?)
							define_method("#{key}=") do |new_value| # allows setting properties, LuxMat.parameter = some_new_value
								@attributeDictionary.set_attribute(@skp_mat_name, key, new_value)
								@material_editor.updateSettingValue(key) if @material_editor
							end
						else # not ui_refreshable
							define_method("#{key}=") { |new_value| # allows setting properties, LuxMat.parameter = some_new_value
								@attributeDictionary.set_attribute(@skp_mat_name, key, new_value)
							}
					end #end case
				end #end settings.each
			end #end module_eval
		end #end @@methods_created
		
		@@methods_created = true
	end #end initialize
	
	def get_texture_channels()
		return @@settings['texturechannels']
	end
	
	def self.get_texture_channels()
		return @@settings['texturechannels']
	end
	
	def get_used_image_paths
		used_image_paths = []
		# go through all of this material's texturechannels
		@@settings['texturechannels'].each{|textype|
			# check if this channel uses an image texture
			textype_string = textype + '_texturetype'
			texture_type = self.send(textype_string)
			# store image 
			if(texture_type == 'imagemap')
				image_path = self.send(textype + '_imagemap_filename')
				if(image_path != '' && image_path != nil)
					used_image_paths << image_path
				end
			end
		}
		return used_image_paths
	end
	
	def uses_skp_texture
		skp_texture_used = false
		# check if any texture channel uses a sketchup texture
		@@settings['texturechannels'].each{|textype|
			textype_string = textype + '_texturetype'
			if(self.send(textype_string) == 'sketchup')
				#puts textype_string
				#puts self.send(textype_string)
				skp_texture_used = true
			end
		}
		return skp_texture_used
	end

	##
	#
	##
	def reset
            #puts "resetting material"
			@@settings.each do |key, value|
				@attributeDictionary.set_attribute(@skp_mat_name, key, value)
			end
	end #END reset
	
	##
	#
	##
	def load_from_model
		return @attributeDictionary.load_from_model(@skp_mat_name)
	end #END load_from_model
	
	##
	#
	##
	#def save_to_model
	#	@model.start_operation "SU2LUX Material settings saved"
	#	puts "SAVE TO MODEL CALLED FROM LUXRENDERMATERIAL"
	#	@attributeDictionary.save_to_model(@skp_mat_name)
	#	@model.commit_operation
	#end #END save_to_model
	
	##
	#
	##
	def get_names
		settings = []
        #puts "collecting keys:"
		@@settings.each { |key, value|
            #puts key
			settings.push(key)
		}
        #puts "done collecting keys"
		return settings
	end #END get_names
	
	##
	#
	##

	def name
		return mat.name
	end
  
	def html_name
		mat_string = mat.name
		# escape < and >
		mat_string.gsub!('<', '&lt;')
		mat_string.gsub!('>', '&gt;')
		# replace space with \;nbsp ?
		# mat_string.gsub(' ', '&nbsp;')
		# remove leading and trailing spaces
		mat_string.strip!
		return mat_string
	end
  
	##
	#
	##
	def original_name
		return mat.name
	end
	
	##
	#
	##
	def color
		color = {}
		color['red'] = self.kd_R
		color['green'] = self.kd_G
		color['blue'] = self.kd_B
        return color
	end
    
    def channelcolor_tos(mattype)
        redstring = mattype + '_R'
        greenstring = mattype + '_G'
        bluestring = mattype + '_B'
        returncolor = "#{"%.6f" %(self.send(redstring))} #{"%.6f" %(self.send(greenstring))} #{"%.6f" %(self.send(bluestring))}"
    end
    
	##
	#
	##
	def color=(su_mat_color)
		scale = 1/255.0
		self.kd_R = format("%.6f", su_mat_color.red.to_f * scale)
		self.kd_G = format("%.6f", su_mat_color.green.to_f * scale)
		self.kd_B = format("%.6f", su_mat_color.blue.to_f * scale)
	end
	
	##
	#
	##
	def RGB_color
		scale = 255
		rgb = []
        # puts "self: ", self
        # puts "self.color: ", self.color
        # puts "self.color[\'red\']: ", self.color['red']
		for c in self.color
			puts "c: ", c
            rgb.push((c.to_f * scale).to_i)
		end
		#self.color.each do |key, value|
        #    puts "iterating"
        #    puts key
        #    puts value
        #end
        return rgb
	end

	##
	#
	##
	def specular=(color)
		self.ks_R = format("%.6f", color['red'])
		self.ks_G = format("%.6f", color['green'])
		self.ks_B = format("%.6f", color['blue'])
	end

	##
	#
	##
	def save_uv(channel_number, uv_set)
		# uvs = {}
		# (uvs[channel_number] ||= []) << uv_set
		@uvs[channel_number] = uv_set
		@attributeDictionary.set_attribute(@skp_mat_name, 'uv_set', @uvs)
	end

	##
	#
	##
	def get_uv(channel_number)
		uvs = @attributeDictionary.get_attribute(@skp_mat_name, 'uv_set', {})
		p "get"
		p uvs
		uv = uvs[channel_number]
	end
	
	##
	#
	##
	def has_uvs?(channel_number=1)
		uvs = @attributeDictionary.get_attribute(@skp_mat_name, 'uv_set', {})
		p "hasuvs"
		p uvs
		return uvs ? true : false
	end
	
	##
	#
	##
	def has_bump?
		has_bump = false
		if (self.bump_texturetype != 'none' && self.use_bump == true)
			if (self.bump_texturetype == 'sketchup')
                # do not export if the material does not have a texture
				has_bump = true if @material_editor.materials_skp_lux.index(self).texture
            elsif (self.bump_texturetype == 'imagemap')
				has_bump = true if (not self.bump_imagemap_filename.empty?)
			elsif (self.bump_texturetype == 'procedural')
				has_bump = true if (not self.bump_imagemap_filename == 'noProcText')
			end
		end
		return has_bump
	end
	
    ##
	#
	##
	def has_normal?
		has_normal = false
		if (self.normal_texturetype != 'none' && self.use_normal == true)
			if (self.normal_texturetype == 'sketchup')
				has_normal = true if @material_editor.materials_skp_lux.index(self).texture
            elsif (self.normal_texturetype == 'imagemap')
				has_normal = true if (not self.normal_imagemap_filename.empty?)
			elsif (self.normal_texturetype == 'procedural')
				has_normal = true if (not self.normal_imagemap_filename	 == 'noProcText')
			end
		end
		return has_normal
	end
	
	##
	#
	##
	def has_displacement?
		has_displacement = false
		if (self.dm_texturetype != 'none')
			if (self.dm_texturetype == 'sketchup')
				has_displacement = true if @material_editor.materials_skp_lux.index(self).texture
			elsif (self.dm_texturetype == 'imagemap')
				has_displacement = true if (not self.dm_imagemap_filename.empty?)
			elsif (self.dm_texturetype == 'procedural')
				has_displacement = true if (not self.dm_imagemap_filename == 'noProcText')
			end
		end	
		return has_displacement
	end
	
	##
	#
	##
	def has_texture?(type)
		has_texture = false
		if (self.send(type + "_texturetype") != 'none')
			if (self.send(type + "_texturetype") == 'sketchup')
				has_texture = true if (@mat.materialType > 0)
			elsif (self.send(type + "_texturetype") == 'imagemap')
				has_texture = true if (not self.send(type + "_imagemap_filename").empty?)
			elsif (self.send(type + "_texturetype") == 'procedural')
				has_texture = true if (not self.send(type + "_texturetype") == 'noProcText')
			end
		end	
		return has_texture
	end
	
	private :lux_image_texture
	
end # END class LuxrenderMaterial