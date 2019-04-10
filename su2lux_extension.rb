     # Create an entry in the Extension list that loads su2lux.rb.
     require 'sketchup.rb'
     require 'extensions.rb'

     su2lux_extension = SketchupExtension.new('SU2LUX', 'su2lux/su2lux.rb')
     su2lux_extension.version = '0.45b'
     su2lux_extension.description = 'Exporter to LuxRender'
	 su2lux_extension.copyright = 'GPL2, free software'
	 su2lux_extension.creator = 'the LuxRender team'
     Sketchup.register_extension(su2lux_extension, true)