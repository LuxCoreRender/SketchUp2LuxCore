def create_toolbar
	main_menu = UI.menu("Plugins").add_submenu("LuxRender")
	main_menu.add_item("Render") { (SU2LUX.export_dialog)}
	main_menu.add_item("Material Editor") {(SU2LUX.show_material_editor(Sketchup.active_model.definitions.entityID))}
	main_menu.add_item("Lamp Editor") {(SU2LUX.show_lamp_editor(Sketchup.active_model.definitions.entityID))}
	main_menu.add_item("Volume Editor") {(SU2LUX.show_volume_editor(Sketchup.active_model.definitions.entityID))}
	main_menu.add_item("Scene Settings Editor") { (SU2LUX.show_scene_settings_editor(Sketchup.active_model.definitions.entityID))}
	main_menu.add_item("Procedural Texture Editor") { (SU2LUX.show_procedural_textures_editor(Sketchup.active_model.definitions.entityID))}
	main_menu.add_item("Render Engine Settings Editor") { (SU2LUX.show_render_settings_editor(Sketchup.active_model.definitions.entityID))}
	main_menu.add_item("About SU2LUX") {(SU2LUX.about)}
	
	toolbar = UI::Toolbar.new("SU2LUX")

	cmd_render = UI::Command.new("Render"){(SU2LUX.export_dialog)}
	cmd_render.small_icon = "icons\\su2lux_render.png"
	cmd_render.large_icon = "icons\\su2lux_render.png"
	cmd_render.tooltip = "Export and Render with LuxRender"
	cmd_render.menu_text = "Render"
	cmd_render.status_bar_text = "Export and Render with LuxRender"
	@renderbutton = toolbar.add_item(cmd_render)

	cmd_material = UI::Command.new("Material"){(SU2LUX.show_material_editor(Sketchup.active_model.definitions.entityID))}
	cmd_material.small_icon = "icons\\su2lux_material.png"
	cmd_material.large_icon = "icons\\su2lux_material.png"
	cmd_material.tooltip = "Open SU2LUX Material Editor"
	cmd_material.menu_text = "Material Editor"
	cmd_material.status_bar_text = "Open SU2LUX Material Editor"
    cmd_material.set_validation_proc{MF_UNCHECKED}
	@materialbutton = toolbar.add_item(cmd_material)
	
	cmd_lamp = UI::Command.new("Lamp"){(SU2LUX.show_lamp_editor(Sketchup.active_model.definitions.entityID))}
	cmd_lamp.small_icon = "icons\\su2lux_lamp.png"
	cmd_lamp.large_icon = "icons\\su2lux_lamp.png"
	cmd_lamp.tooltip = "Open SU2LUX Lamp Editor"
	cmd_lamp.menu_text = "Volume Lamp"
	cmd_lamp.status_bar_text = "Open SU2LUX lamp Editor"
    cmd_lamp.set_validation_proc{MF_UNCHECKED}
	@materialbutton = toolbar.add_item(cmd_lamp)
	
	cmd_volume = UI::Command.new("Volume"){(SU2LUX.show_volume_editor(Sketchup.active_model.definitions.entityID))}
	cmd_volume.small_icon = "icons\\su2lux_volume.png"
	cmd_volume.large_icon = "icons\\su2lux_volume.png"
	cmd_volume.tooltip = "Open SU2LUX Volume Editor"
	cmd_volume.menu_text = "Volume Editor"
	cmd_volume.status_bar_text = "Open SU2LUX Volume Editor"
    cmd_volume.set_validation_proc{MF_UNCHECKED}
	@materialbutton = toolbar.add_item(cmd_volume)
	
	cmd_proceduraltexture = UI::Command.new("Procedural_Textures"){(SU2LUX.show_procedural_textures_editor(Sketchup.active_model.definitions.entityID))}
	cmd_proceduraltexture.small_icon = "icons\\su2lux_procedural_texture.png"
	cmd_proceduraltexture.large_icon = "icons\\su2lux_procedural_texture.png"
	cmd_proceduraltexture.tooltip = "Open SU2LUX Procedural Texture Editor"
	cmd_proceduraltexture.menu_text = "Procedural Texture Editor"
	cmd_proceduraltexture.status_bar_text = "Open SU2LUX Procedural Texture Editor"
    cmd_proceduraltexture.set_validation_proc{MF_UNCHECKED}
	@proceduraltexturebutton = toolbar.add_item(cmd_proceduraltexture)
	    
	cmd_scene_settings = UI::Command.new("Scene_settings"){(SU2LUX.show_scene_settings_editor(Sketchup.active_model.definitions.entityID))}
	cmd_scene_settings.small_icon = "icons\\su2lux_scene_settings.png"
	cmd_scene_settings.large_icon = "icons\\su2lux_scene_settings.png"
	cmd_scene_settings.tooltip = "Open SU2LUX Scene Settings Window"
	cmd_scene_settings.menu_text = "Scene Settings"
	cmd_scene_settings.status_bar_text = "Open SU2LUX Scene Settings Window"
    cmd_scene_settings.set_validation_proc{MF_UNCHECKED}
	@scenesettingsbutton = toolbar.add_item(cmd_scene_settings)
    
	cmd_engine_settings = UI::Command.new("Settings"){(SU2LUX.show_render_settings_editor(Sketchup.active_model.definitions.entityID))}
	cmd_engine_settings.small_icon = "icons\\su2lux_engine_settings.png"
	cmd_engine_settings.large_icon = "icons\\su2lux_engine_settings.png"
	cmd_engine_settings.tooltip = "Open SU2LUX Render Engine Settings Window"
	cmd_engine_settings.menu_text = "Render Settings"
	cmd_engine_settings.status_bar_text = "Open SU2LUX Render Engine Settings Window"
    cmd_engine_settings.set_validation_proc{MF_UNCHECKED}
	@rendersettingsbutton = toolbar.add_item(cmd_engine_settings)

	toolbar.show
    return toolbar
end

#def create_context_menu
#	UI.add_context_menu_handler do |menu|
#		if( SU2LUX.selected_face_has_texture? )
#			menu.add_separator
#			uvs = SU2LUX_UV.new
#			lux_menu = menu.add_submenu("SU2LUX Add-ons")
#			su2lux_menu = lux_menu.add_submenu("UV Manager")
#			su2lux_menu.add_item("Save UV coordinates") { uvs.get_selection_uvs(1) }
#		end
#	end
#end