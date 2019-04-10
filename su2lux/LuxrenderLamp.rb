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
# This file is part of SU2LUX.
#
# Author:      Abel Groenewolt (aka pistepilvi)

class LuxRenderLamp

	attr_reader :name
	
	@@lampParamDicts =
	{
		# texture types, data format: [texture parameter name, parameter type, default value]
		# note: only stores default values; actual values are stored in the SketchUp component definition attribute dictionary
		'point' => {"light_group"=>["string",""],"importance"=>["float",1.0],"gain"=>["float",1.0],"color_r"=>["float",1.0],"color_g"=>["float",1.0],"color_b"=>["float",1.0],"iesname"=>["string",""]}, 
		'spot' => {"light_group"=>["string",""],"importance"=>["float",1.0],"gain"=>["float",1.0],"color_r"=>["float",1.0],"color_g"=>["float",1.0],"color_b"=>["float",1.0],"L"=>["color",[1.0,1.0,1.0]],"coneangle"=>["float",53.1],"conedeltaangle"=>["float",5.0]},
		'projection' => {"light_group"=>["string",""],"importance"=>["float",1.0],"gain"=>["float",1.0],"color_r"=>["float",1.0],"color_g"=>["float",1.0],"color_b"=>["float",1.0],"fov"=>["float",45],"mapname"=>["string",""]},	
	}			# "L"=>["color",[1.0,1.0,1.0]]
		
	def initialize(createNew, lampEditor, lrs, passedName, lampComponentInstance) # passedParameter is lamp type: point, spot, projection
		# store name, get SketchUp component instance, add observer
		@name = passedName
		@model = Sketchup.active_model
		@component = lampComponentInstance
		
		# get lamp editor, add this lamp
		@lampEditor = lampEditor
		@lampEditor.addLamp(lampComponentInstance.definition, self)
		@color_picker = UI::WebDialog.new("Color Picker - lamp", false, "ColorPicker", 410, 200, 200, 350, true)
		
		# create geometry
		if(createNew)
			createGeometry(lampType())
			setValue("name", @name)
			# set this lamp as active lamp
			@lampEditor.set_active_lamp(self)
		end
		
		# add observer
		@component.add_observer(SU2LUX_LightObserver.new)
		
	end
	
	##
	#	instance methods
	##
	
	def lampType()
		return getValue("lamp_type")
	end
	
	def setValue(property, value)	
		packed_value = value.to_s.gsub('/', '//')
		packed_value = [packed_value].pack("m")
		puts "setting property #{property} to value #{packed_value} (#{value})"
		
		if(property != "coneangle") # cone angle should always be calculated from the component instance scale
			@component.definition.set_attribute "LuxRender", property, packed_value
		end
		
		# in case the spot angle changed, scale component instance to match
		if(property == "coneangle" || property == "fov")
			scaleToMatchAngle(value)
			createGeometry(lampType())
		end
		
		# change component definition geometry when lamp type changes, or when fading angle changes
		if(property == "lamp_type" || property == "conedeltaangle")
			puts "updating geometry; lamp type or cone delta angle changed"
			createGeometry(lampType())
		end
	end
	
	def getValue(property)
		# check the attribute dictionary of the lamp instance's component definition attribute dictionary; if no value is found, get a value from @@lampParamDicts instead
		attDict = @component.definition.attribute_dictionaries["LuxRender"]
		foundVal = attDict[property]
		#puts attDict
		#puts foundVal
		if(property == "coneangle" || property == "fov")
			return angle_from_scale
		elsif(foundVal != nil)
			return foundVal.unpack("m")[0]
		else
			#puts "no key found for #{property}"
			return @@lampParamDicts[lampType()][property][1]
		end
	end
	
	def getValueHash()
		# note: this returns hash with default values, not actual values
		# note: this only returns values for which default parameters are provided in @@lampParamDicts, so if a pair is removed there, it will not be shown
		return @@lampParamDicts[lampType()]
	end
		
	def angle_from_scale()		
		# get scale factors
		scale_xy = [@component.transformation.xscale, @component.transformation.yscale].max
		scale_z = @component.transformation.zscale
		
		# calculate angle value
		angle_radians = 2 * Math.atan(0.5 * scale_xy / scale_z)
		angle_degrees = 180 * angle_radians / Math::PI
		
		return angle_degrees.round(2)
	end
	
	def scaleToMatchAngle(angle)
		# calculate scale that results in correct angle
		angle = [[angle.to_f, 0.001].max, 179].min		
		z_scale_factor = 0.5 / Math.tan(0.5 * angle.to_f * Math::PI/180) 
				
		# create transformation from origin to current location and orientation
		t = @component::transformation
		t_place =  Geom::Transformation.axes t.origin, t.xaxis, t.yaxis, t.zaxis
		
		# create scaling transformation
		t_scale =  Geom::Transformation.scaling @component::transformation.zscale/z_scale_factor, @component::transformation.zscale/z_scale_factor, @component::transformation.zscale
		
		# assign scaling transformation, apply place transformation
		@component.transformation = t_scale
		@component.transform! t_place		
		
		puts "scale: " + @component.transformation.xscale.to_s + ", " + @component.transformation.yscale.to_s + ", " + @component.transformation.zscale.to_s 
	end
	
	def createGeometry(lampType)
		# start undo operation
		@model.start_operation("Lamp Geometry")
		
		# remove current geometry
		@component.definition.entities.clear!
	
		# create new geometry
		if(lampType == "spot")
			createSpotGeometry
		elsif(lampType == "point")
			createPointGeometry
		elsif(lampType = "projection")
			createProjectionGeometry
		end		
		
		# end undo operation
		@model.commit_operation()
	end
	
	def createSpotGeometry()
		origin = [0, 0, 0.001] # by moving the "origin" point slightly up, we prevent the actual light position from being placed exacly on a surface
		radius = 5
		height = 10
		nr_points = 7
		
		# radial points
		radial_points = Array.new
		for index in 0..nr_points 
			angle = 2 * Math::PI * index / nr_points
			
			# get x and y values
			x_pos = radius * Math.cos(angle)
			y_pos = radius * Math.sin(angle)
			
			# create and add point
			radial_points[index] = [x_pos, y_pos, -height]
		end
		
		# radial lines
		for index in 0..nr_points
			@component.definition.entities.add_line(origin, radial_points[index]) # radial lines
		end
		
		# circle
		@component.definition.entities.add_circle [0,0,-height], [0,0,1], radius
		
		# fading circle
		halfSpotAngle = 0.5 * getValue("coneangle").to_f * Math::PI / 180 # radians
		fadeAngle = halfSpotAngle - getValue("conedeltaangle").to_f * Math::PI / 180
		fadeRadius = Math.tan(fadeAngle) * radius / Math.tan(halfSpotAngle)
		if(fadeRadius > 0 && getValue("conedeltaangle").to_f > 0)
			@component.definition.entities.add_circle [0,0,-height], [0,0,1], fadeRadius
		end
	end
	
	def createPointGeometry()	
		lamp_points = Array.new
		core_size = 5
		star_size = 8
		# six times two points (in all axis directions)
		p_x_pos = [core_size, 0, 0]
		pp_x_pos = [star_size, 0, 0]
		p_x_neg = [-core_size, 0, 0]
		pp_x_neg = [-star_size, 0, 0]
		p_y_pos = [0, core_size, 0]
		pp_y_pos = [0, star_size, 0]
		p_y_neg = [0, -core_size, 0]
		pp_y_neg = [0, -star_size, 0]
		p_z_pos = [0, 0, core_size]
		pp_z_pos = [0, 0, star_size]
		p_z_neg = [0, 0, -core_size]
		pp_z_neg = [0, 0, -star_size]
		
		# lines between points in three planes
		# xy plane
		@component.definition.entities.add_line(p_x_pos, p_y_pos)
		@component.definition.entities.add_line(p_y_pos, p_x_neg)
		@component.definition.entities.add_line(p_x_neg, p_y_neg)
		@component.definition.entities.add_line(p_y_neg, p_x_pos)		
		
		# yz plane
		@component.definition.entities.add_line(p_y_pos, p_z_pos)
		@component.definition.entities.add_line(p_z_pos, p_y_neg)
		@component.definition.entities.add_line(p_y_neg, p_z_neg)
		@component.definition.entities.add_line(p_z_neg, p_y_pos)
		
		# xz plane
		@component.definition.entities.add_line(p_x_pos, p_z_pos)
		@component.definition.entities.add_line(p_z_pos, p_x_neg)
		@component.definition.entities.add_line(p_x_neg, p_z_neg)
		@component.definition.entities.add_line(p_z_neg, p_x_pos)
		
		# extension lines in all six axis directions
		@component.definition.entities.add_line(p_x_pos, pp_x_pos)
		@component.definition.entities.add_line(p_x_neg, pp_x_neg)
		@component.definition.entities.add_line(p_y_pos, pp_y_pos)
		@component.definition.entities.add_line(p_y_neg, pp_y_neg)
		@component.definition.entities.add_line(p_z_pos, pp_z_pos)
		@component.definition.entities.add_line(p_z_neg, pp_z_neg)
	end
	
	def createProjectionGeometry()
		lamp_points = Array.new
		height = 20
		half_width = 10
		lamp_points[0] = [0, 0, 0.001] # by moving the "origin" point slightly up, we prevent the actual light position from being placed exacly on a surface
		lamp_points[1] = [half_width, half_width , -height]
		lamp_points[2] = [half_width, -half_width, -height]
		lamp_points[3] = [-half_width , -half_width, -height]
		lamp_points[4] = [-half_width , half_width, -height]
		
		projected_origin = [0, 0, -height]
		projected_x = [0.5 * half_width, 0, -height]
		projected_y = [0, 0.5 * half_width, -height]
		
		# radial points
		@component.definition.entities.add_line(lamp_points[0], lamp_points[1])
		@component.definition.entities.add_line(lamp_points[0], lamp_points[2])
		@component.definition.entities.add_line(lamp_points[0], lamp_points[3])
		@component.definition.entities.add_line(lamp_points[0], lamp_points[4])
		
		# frame points
		@component.definition.entities.add_line(lamp_points[1], lamp_points[2])
		@component.definition.entities.add_line(lamp_points[2], lamp_points[3])
		@component.definition.entities.add_line(lamp_points[3], lamp_points[4])
		@component.definition.entities.add_line(lamp_points[4], lamp_points[1])
		
		# coordinate lines
		@component.definition.entities.add_line(projected_origin, projected_x)
		@component.definition.entities.add_line(projected_origin, projected_y)
	end
	
	
	def get_description(inst) # inst is a passed component instance
		description_lines = []
		pos = inst.transformation::origin.to_a
		#color = getValue("L").to_a

		light_group_string = getValue("light_group")
		if(light_group_string != "")
			description_lines << 'LightGroup "' + light_group_string + '"'
		end
		
		if(lampType == "spot")
			# get data
			look_at = (inst.transformation::origin - inst.transformation::zaxis).to_a
			
			# create definition
			description_lines << 'LightSource "spot"'
			description_lines << '  "point from" [' + pos.x.to_s + " " + pos.y.to_s + " " + pos.z.to_s +  ']'
			description_lines << '  "point to" [' + look_at.x.to_s + " " + look_at.y.to_s + " " + look_at.z.to_s +  ']'
			description_lines << '  "float coneangle" [' + getValue("coneangle").to_s  + ']' 
			description_lines << '  "float conedeltaangle" [' + getValue("conedeltaangle").to_s  + ']' 
			description_lines << '  "float gain" [' + getValue("gain").to_s  + ']' 
			description_lines << '  "color L" [' + getValue("color_r").to_s + " " + getValue("color_g").to_s + " "  + getValue("color_b").to_s + ']' 
			
		elsif(lampType == "projection")
			mapname = getValue("mapname")
			if(mapname != "")
				# get data
				look_at = (inst.transformation::origin - inst.transformation::zaxis).to_a
				
				# create transformation definition				
				pos_metric = [pos[0] * 0.0254, pos[1] * 0.0254, pos[2] * 0.0254]
				look_at_metric = [look_at[0] * 0.0254, look_at[1] * 0.0254, look_at[2] * 0.0254]
				
				transformation_string = look_at_transform(pos_metric, look_at_metric, inst.transformation::yaxis.to_a)
								
				description_lines << "TransformBegin"
				description_lines << "Transform [#{transformation_string}]"
				
				# create projection light definition
				description_lines << '  LightSource "projection"'
				#description_lines << '    "point from" [' + pos.x.to_s + " " + pos.y.to_s + " " + pos.z.to_s +  ']'
				#description_lines << '    "point to" [' + look_at.x.to_s + " " + look_at.y.to_s + " " + look_at.z.to_s +  ']'
				description_lines << '    "float fov" [' + getValue("fov").to_s  + ']'
				description_lines << '    "float gain" [' + getValue("gain").to_s  + ']' 
				description_lines << '    "string mapname" ["' + mapname  + '"]' 
				description_lines << '  "color L" [' + getValue("color_r").to_s + " " + getValue("color_g").to_s + " "  + getValue("color_b").to_s + ']' 
				
				# end transform
				description_lines << 'TransformEnd'
			end
		
		elsif(lampType == "point")
		 	# get data
			iespath = getValue("iesname")
			
			# create definition
			description_lines << 'LightSource "point"'
			description_lines << '  "point from" [' + (pos.x * 0.0254).to_s + " " + (pos.y * 0.0254).to_s + " " + (pos.z * 0.0254).to_s +  ']' # point light does not get affected by global transform
			description_lines << '  "float gain" [' + getValue("gain").to_s  + ']' 
			description_lines << '  "float power" [0]' 
			description_lines << '  "float efficacy" [0]' 
			description_lines << '  "color L" [' + getValue("color_r").to_s + " " + getValue("color_g").to_s + " "  + getValue("color_b").to_s + ']'
			if(iespath != "")
				description_lines << '  "string iesname" ["' + iespath  + '"]' 
			end
		end
		
		return description_lines
	end
	
	
	def look_at_transform(cam, target, up) # PBRT look-at transformation
		transform_string = ""
		
		# prepare vectors		
		dir = [target[0] - cam[0], target[1] - cam[1], target[2] - cam[2]];
		dir.normalize!
		up.normalize!
		right = cross_product(dir, up)
		newUp = cross_product(right, dir)

		# first row
		transform_string += right[0].to_s + " "
		transform_string += right[1].to_s + " "
		transform_string += right[2].to_s + " "
		transform_string += "0 ";
		
		# second row
		transform_string += newUp[0].to_s + " "
		transform_string += newUp[1].to_s + " "
		transform_string += newUp[2].to_s + " "
		transform_string += "0 ";

		# third row
		transform_string += dir[0].to_s + " "
		transform_string += dir[1].to_s + " "
		transform_string += dir[2].to_s + " "
		transform_string += "0 ";

		# fourth row
		transform_string += cam[0].to_s + " "
		transform_string += cam[1].to_s + " "
		transform_string += cam[2].to_s + " "
		transform_string += "1";
		return transform_string
	end
	
	def cross_product(va, vb)
		x = va[1] * vb[2] - va[2] * vb[1]
		y = va[2] * vb[0] - va[0] * vb[2]
		z = va[0] * vb[1] - va[1] * vb[0]	
		return [x,y,z]
	end
end




     

