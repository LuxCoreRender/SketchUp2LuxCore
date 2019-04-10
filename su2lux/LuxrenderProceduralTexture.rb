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

class LuxrenderProceduralTexture

	attr_reader :name
	
	@@textureTypes = 
	{
		"add" => ["color","float"],
		"band" => ["color","float","fresnel"],
		"bilerp" => ["color","float","fresnel"],
		"blackbody" => ["color"],
		"brick" => ["color","float"],
		"cauchy" => ["fresnel"],
		"checkerboard" => ["float"],
		"cloud" => ["float"],
		"colordepth" => ["color"],
		"constant" => ["float","color","fresnel"],
		"dots" => ["float"],
		"equalenergy" => ["color"],
		"fbm" => ["float"],
		"fresnelcolor" => ["fresnel"],
		"fresnelname" => ["fresnel"],
		"gaussian" => ["color"],
		"harlequin" => ["color"],
		"lampspectrum" => ["color"],
		"marble" => ["color"],
		"mix" => ["float","color","fresnel"],
		"multimix" => ["float","color","fresnel"],
		"normalmap" => ["float"],
		"scale" => ["float","color","fresnel"],
		"sellmeier" => ["fresnel"],
		"subtract" => ["float","color"],
		"tabulateddata" => ["color"],
		"uv" => ["color"],
		"uvmask" => ["float"],
		"windy" => ["float"],
		"wrinkled" => ["float"],
		"blender_blend" => ["float"],
		"blender_clouds" => ["float"],
		"blender_distortednoise" => ["float"],
		"blender_noise" => ["float"],
		"blender_magic" => ["float"],
		"blender_marble" => ["float"],
		"blender_musgrave" => ["float"],
		"blender_stucci" => ["float"],
		"blender_wood" => ["float"],
		"blender_voronoi" => ["float"]
	}  
	
	@@textureParameters =
	{
		# texture types, data format: [parameter SU2LUX name, parameter LuxRender name, parameter type, default value]
		'add' => [["tex1","color",[1.0,1.0,1.0]],["tex2","color",[1.0,1.0,1.0]]],
		'band' => [["tex1","color",[1.0,1.0,1.0]],["tex2","color",[0.0,0.0,0.0]],["tex3","color",[1.0,1.0,1.0]],["tex4","color",[0.0,0.0,0.0]],["tex5","color",[1.0,1.0,1.0]],["tex6","color",[0.0,0.0,0.0]],["tex7","color",[1.0,1.0,1.0]],["tex8","color",[0.0,0.0,0.0]],["offsets","arrayf",""],["amount","texf",""]],
		'bilerp' => [["v00","color",[0.8,0.8,0.8]],["v01","color",[0.0,0.0,0.0]],["v10","color",[0.8,0.8,0.8]],["v11","color",[0.0,0.0,0.0]]],
		'blackbody' => [["temperature","float",6500.0]],
		'brick' => [["brickwidth","float",0.3],
		["brickheight","float",0.1],["brickdepth","float",0.15],["mortarsize","float",0.01],["brickbevel","float",0.0],["brickrun","float",0.75],["brickbond","string","stacked"],["bricktex","color",[0.4,0.2,0.2]],["mortartex","color",[0.2,0.2,0.2]],["brickmodtex","float",1.0]],
		'checkerboard' => [["dimension","integer",2],["aamode","string","none"],["tex1","float",1.0],["tex2","float",0.0]],
		'cloud' => [["radius","float",0.5],["noisescale","float",0.5],["turbulence","float",0.01],["sharpness","float",6.0],["noiseoffset","float",0.0],["omega","float",0.75],["variability","float",0.9],["baseflatness","float",0.8],["spheresize","float",0.15],["spheres","integer",0],["octaves","integer",1]],
		'colordepth' => [["depth","float",1.0],["Kt","color",[0.0,0.0,0.0]]],
		'densitygrid' => [["density","floats",""],["nx","integer",1],["ny","integer",1],["nz","integer",1],["wrap","string","repeat"]],
		'dots' => [["inside","color",[1.0,1.0,1.0]],["outside","color",[0.0,0.0,0.0]]],
		'exponential' => [["origin","point",[0.0,0.0,0.0]],["updir","vector",[0.0,0.0,1.0]],["decay","float",1.0]],
		'fbm' => [["roughness","float",0.8],["octaves","integer",8]],
		'fresnelname' => [["filename","string",""],["name","string","aluminium"]],
		'fresnelcolor' => [["Kr","color",[0.5,0.5,0.5]]],
		'gaussian' => [["energy","float",1.0],["wavelength","float",550.0],["width","float",50.0]],
		'harlequin' => [],
		'imagemap' => [["filename","string",""],["wrap","string",""],["filtertype","string","bilinear"],["maxanisotropy","float",8.0],["trilinear","boolean",false],["channel","string","mean"],["gamma","float",2.2],["gain","float",1.0]],
		'marble' => [["octaves","integer",12],["roughness","float",0.6],["scale","float",1.0],["variation","float",0.7]],
		'mix' => [["tex1","color",[0.0,0.0,0.0]],["tex2","color",[1.0,1.0,1.0]],["scale","float",1.0],["variation","float",0.2]],
		'normalmap' => [["filename","string",""],["wrap","string",""],["filtertype","string","bilinear"],["maxanisotropy","float",8.0],["trilinear","boolean",false],["channel","string","mean"],["gamma","float",1.0],["gain","float",1.0]],
		'scale' => [["value","color",[1.0,1.0,1.0]],["tex1","color",[1.0,1.0,1.0]],["tex2","color",[1.0,1.0,1.0]]],
		'subtract' => [["tex1","color",[1.0,1.0,1.0]],["tex2","color",[1.0,1.0,1.0]]],
		'tabulateddata' => [["filename","string",""]],
		'windy' => [],
		'wrinkled' => [["octaves","integer",8],["roughness","float",0.5]],
		'blender_clouds' => [["noisetype","string","soft_noise"],["noisebasis","string","blender_original"],["noisesize","float",0.25],["noisedepth","integer",2],["bright","float",1.0],["contrast","float",1.0]],
		'blender_distortednoise' => [["type","string","blender_original"],["noisebasis","string","blender_original"],["noisesize","float",0.25],["distamount","float",1.0],["noisedepth","integer",2],["bright","float",1.0],["contrast","float",1.0]],
		'blender_noise' => [["coordinates","string","global"]],
		'blender_magic' => [["coordinates","string","global"]],
		'blender_marble' => [["noisesize","float",0.25],["noisedepth","integer",2],["turbulence","float",5.0],["type","string","soft"],["noisetype","string","hard_noise"],["noisebasis","string","sin"],["noisebasis2","string","blender_original"],["bright","float",1.0],["contrast","float",1.0]],
		'blender_musgrave' => [["h","float",1.0],["lacu","float",2.0],["octs","float",2.0],["gain","float",1.0],["offset","float",1.0],["noisesize","float",0.25],["outscale","float",1.0],["type","string","multifractal"],["noisebasis","string","blender_original"],["bright","float",1.0],["contrast","float",1.0]],
		'blender_stucci' => [["type","string","plastic"],["noisetype","string","soft_noise"],["noisebasis","string","blender_original"],["turbulence","float",5.0],["bright","float",1.0],["contrast","float",1.0]],
		'blender_wood' => [["type","string","bands"],["noisetype","string","soft_noise"],["noisebasis","string","blender_original"],["noisebasis2","string","sin"],["noisesize","float",0.25],["turbulence","float",5.0],["bright","float",1.0],["contrast","float",1.0]],
		'blender_voronoi' => [["distmetric","string","actual_distance"],["minkowsky_exp","float",2.5],["noisesize","float",0.25],["nabla","float",0.025],["w1","float",1.0],["w2","float",0.0],["w3","float",0.0],["w4","float",0.0],["bright","float",1.0],["contrast","float",1.0]]
	}
	
	@@transformationParameters = # parameter => default value
	{
		'vectortranslateX' => 0.0,
		'vectortranslateY' => 0.0,
		'vectortranslateZ' => 0.0,
		'vectorrotateX' => 0.0,
		'vectorrotateY' => 0.0,
		'vectorrotateZ' => 0.0,
		'vectorscaleX' => 1.0,
		'vectorscaleY' => 1.0,
		'vectorscaleZ' => 1.0,
	}
	
	@@hasTransformation = ["brick", "checkerboard", "cloud", "dots", "fbm", "marble", "windy", "wrinkled", "blender_clouds", "blender_distorted_noise", "blender_noise", "blender_magic", "blender_marble", "blender_musgrave", "blender_stucci", "blender_wood", "blender_voronoi"]
	
	##
	#
	##
	def initialize(createNew, procEditor, lrs, passedParam, texName) # passedParam is texture type (marble, checkerboard) or object number
		@lrs = lrs
		@procTexEditor = procEditor
		@name = texName
		
		# get attribute dictionary from texture editor (this dictionary contains subdictionaries for each texture)
		@textureDictionary = @procTexEditor.getTextureDictionary()
		
		if createNew == true # create new object from scratch
			textureType = passedParam
			
			# add texture name to @lrs
			namesArray = @lrs.proceduralTextureNames
			namesArray << name
			@lrs.proceduralTextureNames = namesArray

			# write texture name, texture type and channel type to attribute dictionary
			@textureDictionary.set_attribute(@name, "name", @name) # any name, for example ProcTex_1
			@textureDictionary.set_attribute(@name, "textureType", textureType) # marble, noise, fbm etc.			
			@textureDictionary.set_attribute(@name, "procTexChannel", @@textureTypes[textureType][0]) # color, float or fresnel
			
		else # create object based on existing data in attribute dictionary
			#@textureDictionary.set_attribute(@name, "name", @name) # commented out: name should be loaded from attribute dictionary
			@textureDictionary.load_from_model(@name) # loads values stored in SketchUp file into AttributeDictionary dictionary
		end
		
		@procTexEditor.addTexture(@name, self) # add texture to collection in current texture editor
		@procTexEditor.setActiveTexture(self) # mark this texture as the active texture
	end

	def setValue(property, value)
		@textureDictionary.set_attribute(@name, property, value)
	end
	
	def printValues()
		@@textureParameters[getTexType()].each do |propertySet|
			puts propertySet
		end	
	end	
	
	def getValues()
		passedVariableLists = []
		texType = getTexType()
		@@textureParameters[texType].each do |propertySet|
			#puts propertySet
			# get value from dictionary, or use default value if no value has been stored
			varValue = @textureDictionary.get_attribute(name, propertySet[0].to_s, propertySet[2])
			passedVariableLists << [propertySet[0],propertySet[1],varValue]
		end
		return passedVariableLists
	end
	
	def getTranformationValues()
		passedVariableLists = []
		texType = getTexType()
		@@transformationParameters.each do |key, value|
			varValue = @textureDictionary.get_attribute(name, key, value)
			passedVariableLists << [key, varValue]
		end
		return passedVariableLists
	end
	
	
	def getFormattedValues()
		unformattedValues = getValues()
		formattedValues = []
		unformattedValues.each do |paramSet|
			# puts paramSet
			# deal with vector parameters
			texParamName = paramSet[0]
			if (texParamName[0..5] == "vector")
				texParamName.slice! "vector"
			end
			typeString = paramSet[1].to_s + " " + texParamName
			# deal with square brackets: if first character is '[', remove first and last character and replace ', ' with ' '
			if paramSet[2].to_s[0] == '['
				paramSet[2] = paramSet[2].to_s
				paramSet[2] = paramSet[2][1, paramSet[2].length - 2]
				paramSet[2] = paramSet[2].gsub!(', ' , ' ')
			end			

			# add formatted strings to array
			if (paramSet[1] == "string" || paramSet[1] == "bool")
				formattedValues << [typeString, "\"" + paramSet[2] + "\""]
			else
				formattedValues << [typeString, paramSet[2]]
			end
		end
		#puts "returning values:"
		#puts formattedValues
		return formattedValues
	end
	
	def getTransformations()
		# create empty list	
		transformList = []
		# check if item has transformation
		if @@hasTransformation.include? getTexType()
			# if so, combine properties into nice strings
			co = @textureDictionary.get_attribute(name, "coordinates", "global")
			transformList << '"string coordinates" ["' + co + '"]'     
			tX = @textureDictionary.get_attribute(name, "vectortranslateX", 0.0).to_s
			tY = @textureDictionary.get_attribute(name, "vectortranslateY", 0.0).to_s
			tZ = @textureDictionary.get_attribute(name, "vectortranslateZ", 0.0).to_s
			transformList << '"vector translate" [' + tX + ' ' + tY + ' ' + tX + ']'
			rX = @textureDictionary.get_attribute(name, "vectorrotateX", 0.0).to_s
			rY = @textureDictionary.get_attribute(name, "vectorrotateY", 0.0).to_s
			rZ = @textureDictionary.get_attribute(name, "vectorrotateZ", 0.0).to_s
			transformList << '"vector rotate" [' + rX + ' ' + rY + ' ' + rZ + ']'
			sX = @textureDictionary.get_attribute(name, "vectorscaleX", 1.0).to_s
			sY = @textureDictionary.get_attribute(name, "vectorscaleY", 1.0).to_s
			sZ = @textureDictionary.get_attribute(name, "vectorscaleZ", 1.0).to_s
			transformList << '"vector scale" [' + sX + ' ' + sY + ' ' + sZ + ']'
		end
		return transformList
	end
	
	def self.getChannelType(texName)
		thisDict = LuxrenderAttributeDictionary.returnDictionary(texName)
		thisTexType = thisDict["procTexChannel"]
		#puts "self.getChannelType found texture type " + thisTexType + " for material with name " + texName
		return thisTexType
	end
	
	def self.getTexChannels(texType)
		return @@textureTypes[texType]
	end
	

	
	def setTexChannel()
		thisTexName = @textureDictionary.get_attribute(name, "textureType")
		self.setValue("procTexChannel", @@textureTypes[thisTexName][0])
		return @@textureTypes[thisTexName][0]
	end
	

	def getTexType()
		thisDict = LuxrenderAttributeDictionary.returnDictionary(name)
		thisTexName = thisDict["textureType"]
		return thisTexName
	end
	
	def getChannelType()
		thisDict = LuxrenderAttributeDictionary.returnDictionary(name)
		thisTexType = thisDict["procTexChannel"]
		puts "getChannelType found texture type " + thisTexType + " for texture " + self.name
		return thisTexType
	end
	
	
	def self.getTexType(texName)
		thisDict = LuxrenderAttributeDictionary.returnDictionary(texName)
		thisTexName = thisDict["textureType"]
		return thisTexName
	end
	
end