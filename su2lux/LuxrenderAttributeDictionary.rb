class LuxrenderAttributeDictionary

	attr_reader :dictionaries

    #private_class_method :new

	#list of all possible dictionaries in use
	
	@@allDictionaryCollections = [] # class variable
	
	#@@dictionary = {}   # the current working dictionary (class variable)

	##
	#
	##
	def initialize(model)
		@@allDictionaryCollections << self
        @dictionaries = {} # hash containing name strings and dictionary objects
        @dictionary = {} # hash containing parameters and values
        @model = model
	end #END initialize
	
	def self.returnDictionary(name)
		@@allDictionaryCollections.each{ |dictCollection|
			if dictCollection.dictionaries.key?(name)
				#puts "self.returnDictionary found dictionary " + dictCollection.dictionaries[name].__id__.to_s + " containing key " + name
				return dictCollection.dictionaries[name]
			end
		}
		#puts "self.returnDictionary: no dictionary found with name " + name + ", returning nil"
		return nil
	end
	
	def returnDictionary(name)
		if @dictionaries.key?(name)
			#puts "returnDictionary found dictionary " + @dictionaries[name].__id__.to_s + " containing key " + name
			return @dictionaries[name]
		end
		#puts "returnDictionary found no dictionary with name " + name + ", returning nil"
		return nil	
	end
		
	def self.returnDictionaryCollection(name)
		@@allDictionaryCollections.each{ |dictCollection|
			if dictCollection.dictionaries.key?(name)
				#puts "self.returnDictionaryCollection: found dictionary collection containing key " + name
				return dictCollection
			end
		}
		return nil
	end
	
	##
	#
	##
	def get_attribute(name, key, default = nil)
		dictionary = self.choose(name)
		if (dictionary.key? key)
			#puts "returning value from dictionary:"
			#puts dictionary[key]
			return dictionary[key]
		else
			#puts "returning default"
			return default
		end
	end # END get_attribute
	
	##
	#
	##
	def set_attribute(name, key, value)
        #puts "setting attribute, storing in SketchUp file"
        #puts "values:"
        #puts name
        #puts key
        #puts value
        #puts ""
		@model.start_operation("SU2LUX settings update", true, false, true) # start undoable operation
		
		dictionary = self.choose(name)
		dictionary[key] = value
		@dictionaries[name] = dictionary
		#puts "storing value in model: " + value.to_s
        valueCheck =  @model.set_attribute(name, key, value) # store to model's attribute dictionary
		#puts valueCheck
		
		@model.commit_operation() # end undoable operation
	end #END set_attribute
	
	##
	#
	##
	def choose(name)
		if (name.nil? or name.strip.empty?)
			#puts "returning @dictionary"
			return @dictionary
		end
		if ( !@dictionaries.key? name)
			#puts "adding new dictionary with name " + name + " to @dictionaries"
			@dictionaries[name] = {}
		end
		@dictionary = @dictionaries[name]
		return @dictionary
	end #END choose
    
	#def save_to_model(name)
    #    puts "attributeDictionary running save_to_model for: " + name.to_s
	#	@dictionary = self.choose(name)
	#	if (self.modified?(name))
    #       puts "modified"
	#		@dictionary.each { |key, value|
    #            # puts key.to_s + " " + value.to_s
	#			@model.set_attribute(name, key, value)
	#		}
    #   else
    #       puts "not modified"
	#	end
	#end #END save_to_model
    
	def load_from_model(name)
        #puts "loading dictionary for " + name.to_s
		@dictionary = self.choose(name) # self is #<LuxrenderAttributeDictionary:.....>
		model_dictionary = @model.attribute_dictionary(name)
		#puts "load from model opening dictionary " + model_dictionary.__id__.to_s
		if (model_dictionary)
            #puts "number of attribute dictionary items:" + model_dictionary.length.to_s
			@model.start_operation("SU2LUX load model data", true, false, true)
			model_dictionary.each { |key, value|
				# puts "load_from_model updating attributes"
				#puts "dictionary value: " + key.to_s + ": " + value.to_s
				self.set_attribute(name, key, value) # set, because we're taking values from the model's attribute dictionary
                                                     # and setting them in the (temporary) LuxRender attribute dictionary
													 # TODO 2014: prevent running this function on loading model; parameters that are not loaded in the attribute dictionary should be retrieved from the SketchUp file directly
			}
			@model.commit_operation()
			
			return true
		else
            #puts "dictionary does not exist"
			return false
		end
	end #END load_from_model
	
#	def load_from_model_procedural(name)
#	puts "running load_from model for " + name.to_s + ", using attribute dictionary:"
#		puts self
#		@dictionary = self.choose(name) # self is #<LuxrenderAttributeDictionary:.....>
#		puts @dictionary
#		model_dictionary = @model.attribute_dictionary(name)
#		if (model_dictionary)
#			puts "number of attribute dictionary items:"
#			puts model_dictionary.length
#			@model.start_operation("SU2LUX load model data", true, false, true)
#			model_dictionary.each { |key, value|
#				puts "setting value for procedural texture key"
#				@dictionary[key] = value 
#			}
#			@model.commit_operation()
#			puts @dictionary
#			
#			return true
#		else
#			puts "dictionary does not exist"
#			return false
#		end
#	end #END load_from_model_procedural
	
	def modified?(name)
		@dictionary = self.choose(name)
		@dictionary.each { |key, value|
			if (@model.get_attribute(name, key) != value)
                #puts key.to_s + " has changed"
				return true;
			end
		}
		return false
	end #END modified?
	
	def list_dictionaries()
		puts @dictionaries.length
		keys = @dictionaries.keys
		keys.each{|k|
		puts "\n\n#{k}\n\n"
			puts @dictionaries[k].each{|kk,vv| puts "#{kk}=>#{vv}"}
		}
	end
	
	def list_properties()
		puts @dictionary.length
		theproperties = @dictionary.keys
		theproperties.each{|kk,vv|
			puts "#{kk} #{vv}"
		}
	end
	
end #END class Luxrender_Attribute_dictionary