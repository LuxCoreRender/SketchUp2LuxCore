# Copyright 2012, Trimble Navigation Limited

# This software is provided as an example of using the Ruby interface
# to SketchUp.

# Permission to use, copy, modify, and distribute this software for 
# any purpose and without fee is hereby granted, provided that the above
# copyright notice appear in all copies.

# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
#-----------------------------------------------------------------------------

class FocusTool

def initialize(sceneID, lrs)
	@sceneID = sceneID
	@lrs = lrs
    @focusPoint = nil
	@gotPoint = false
end

# The activate method is called by SketchUp when the tool is first selected.
def activate
    @focusPoint = Sketchup::InputPoint.new
    # This sets the label for the VCB (value control box)
    Sketchup::set_status_text "select LuxRender camera focus point", SB_VCB_LABEL

end


# The onLButtonDOwn method is called when the user presses the left mouse button.
def onLButtonDown(flags, x, y, view)
    if (!@gotPoint)
		@focusPoint.pick view, x, y
		if( @focusPoint.valid? )
			@xdown = x
			@ydown = y
			puts @focusPoint.position
			
			# calculate distance to camera
			cam = Sketchup.active_model.active_view.camera
			
			# use camera direction and position: cam.direction cam.eye
			cameraPlane =  [cam.eye, cam.direction]
			focusDistance = (0.0254 * @focusPoint.position.distance_to_plane(cameraPlane)).round(3)
			puts "focusDistance is " + focusDistance.to_s
			
			# update focus distance in interface
			sceneSettingsEditor = SU2LUX.get_editor(@sceneID,"scenesettings")
			# call jquery call on scene settings editor
			sceneSettingsEditor.scene_settings_dialog.execute_script('$("#focaldistance").val("' + focusDistance.to_s + '")')
			
			# set this value as camera distance
			@lrs.send('focaldistance=', focusDistance)
	
			# prevent further input
			Sketchup::set_status_text("focus distance set to " + focusDistance.to_s, SB_VCB_LABEL)
			@gotPoint = true
		end
	end
    
end

#def onCancel(flag, view)
#    self.reset(view)
#end

end # class FocusTool

