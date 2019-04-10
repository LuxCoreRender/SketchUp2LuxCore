<!--TODO add spinner plugin for number input field -->
function checkbox_expander(id)
{
	if ($("#" + id).attr("checked"))
	{
		$("#" + id).nextAll(".collapse").show();
		$("#" + id).nextAll(".collapse").children("#focus_type").change();
	}
	else if ($("#" + id).attr("checked") == false)
	{
		$("#" + id).nextAll(".collapse").hide();
	}
}

function update_subfield(field_class)
{
    //alert(field_class)
    $("#"+field_class).nextAll("."+field_class).hide();
    id_option_string = "#" + field_class + " option:selected"
    idname = $(id_option_string).val()
    $("#"+idname).show();
    $("."+idname).show();
}

function update_boxfield(field_class)
{
    //alert($("#"+field_class).is(':checked'))
    $("#"+field_class).nextAll("."+field_class).hide();
    if ($("#"+field_class).is(':checked') == true){
        $("."+field_class).show();
    }
}

update_boxfield

$(document).ready(
	function()
	{
        // alert ("settings DOM ready")
        //hide categories that are less likely to be used or take too much space
        //$("#tone_mapping").next(".collapse").hide()
                  
        //hide subfields for settings that are not active
        $(".use_custom_whitepoint").hide();
        $(".fleximage_render_time").hide();

        window.location = 'skp:scene_setting_loaded@'
                  
		$("#scene_settings_panel select, :text").change( // catches changes in dropdowns and text input fields
			function()
			{
                //alert ("change in settings panel text field");
				if(this.id=="export_luxrender_path"){
					window.location = 'skp:param_generate@' + this.id+'='+ escape(this.value); //this.value;
				}else{
					window.location = 'skp:param_generate@' + this.id+'='+this.value;
				}
			}
		);
		
		$("#scene_settings_panel #camera_type").change(
			function()
			{
				$(this).nextAll().hide();
				$(this).nextAll("." + this.value).show();
				//window.location = 'skp:camera_change@' + this.value
			}
		);
		
		$("#scene_settings_panel #focus_type").change(
			function()
			{
				$(this).nextAll("div").hide();
                $(this).nextAll("span").hide();
                $(this).nextAll("." + this.value).show();
			}
		);
		
		$("#scene_settings_panel #environment_light_type").change(
			function()
			{
				$(this).nextAll().hide();
				//$(".environment_common").show();
				$(this).nextAll("." + this.value).show();
			}
		);

        $("#fleximage_colorspace_wp_preset").change(
            function()
            {
                if(this.value=="use_custom_whitepoint"){
                    $(".use_custom_whitepoint").show();
                }else{
                    $(".use_custom_whitepoint").hide();
                }
            }
        );

                  
 		$("#scene_settings_panel #aspectratio_type").change(
			function()
			{
                if (this.value=="aspectratio_sketchup_view"){
                    $("#aspectratio_sketchup_view").show();
                    $("#aspectratio_free").hide();
                    $("#aspectratio_custom").hide();
                    $("#aspectratio_fixed").hide();
                    if ($("#aspectratio_skp_res_type").val()=="aspectratio_skp_view"){
                      $("#aspectratio_resolution_interface").hide();
                      window.location = 'skp:remove_frame@' + this.value
                    }else{
                      // start function that updates y resolution based on x resolution (1)
                      window.location = 'skp:resolution_update_skp@' + this.value
                    }
                }else if (this.value=="aspectratio_free"){
                    $("#aspectratio_sketchup_view").hide();
                    $("#aspectratio_free").show();
                    $("#aspectratio_custom").hide();
                    $("#aspectratio_fixed").hide();
                    $("#aspectratio_resolution_interface").show();
                    window.location = 'skp:resolution_update_free@' + this.value;
                }else if (this.value=="aspectratio_custom"){
                    $("#aspectratio_sketchup_view").hide();
                    $("#aspectratio_free").hide();
                    $("#aspectratio_custom").show();
                    $("#aspectratio_fixed").hide();
                    $("#aspectratio_resolution_interface").show();
                    // start function that updates resolutions based on custom aspect ratio
                    window.location = 'skp:resolution_update_custom@' + this.value
                }else { // fixed ratio
                    $("#aspectratio_sketchup_view").hide();
                    $("#aspectratio_free").hide();
                    $("#aspectratio_custom").hide();
                    $("#aspectratio_fixed").show();
                    $("#aspectratio_resolution_interface").show();
                    // start function that updates resolutions based on aspect ratio
                    window.location = 'skp:resolution_update_fixed@' + this.value
                }
			}
		);
                  
  		$("#scene_settings_panel #aspectratio_skp_res_type").change(
			function()
			{
                if (this.value=="aspectratio_skp_view"){
                    $("#aspectratio_resolution_interface").hide();
                }else { // custom ratio
                    $("#aspectratio_resolution_interface").show();
                    window.location = 'skp:resolution_update_skp@' + this.value
                }
			}
		);
        
        $("#scene_settings_panel #aspectratio_fixed_orientation").change(
           function(){
                //alert(this.value)
                window.location = 'skp:swap_portrait_landscape@' + this.value               
           }
        );
                  
                  
        $("#scene_settings_panel #aspectratio_flip").click(
           function(){
                //alert(this.value)
                window.location = 'skp:flip_aspect_ratio@' + this.value               
           }
        );
		
		$("#scene_settings_panel #fleximage_tonemapkernel").change(
			function()
			{
				$(this).nextAll("div").hide();
				$(this).nextAll("." + this.value).show();
			}
		);
                  
		
		$("#fleximage_render_time").change(
			function()
			{
				$(".fleximage_render_time").hide();
                if(this.value=="halt_spp"){
                    $("#halt_spp").show();
                }else if(this.value=="halt_time"){
                    $("#halt_time").show();
                }
			}
		);
		
		$("#scene_settings_panel #fleximage_linear_camera_type").change(
			function()
			{
				$(this).nextAll("div").hide();
				$(this).nextAll("span").hide();
				$(this).nextAll("." + this.value).show();
			}
		);
		

		$(":checkbox").click(
			function()
            {   // note: changing the order of the following methods will cause synchronity issues on OS X
                checkbox_expander(this.id);
                window.location = 'skp:param_generate@' + this.id + '=' + $(this).attr('checked');
			}
		);
		
		$("#scene_settings_panel p.header").click(
			function()
			{
				node = $(this).next("div.collapse").children("#accelerator_type").attr("value");
				$(this).next("div.collapse").children("#accelerator_type").siblings("#" + node).show();
				node = $(this).next("div.collapse").children("#sintegrator_type").attr("value");
				$(this).next("div.collapse").children("#sintegrator_type").siblings("#" + node).show();
				node = $(this).next("div.collapse").children("#camera_type").change();
				node = $(this).next("div.collapse").children("#environment_light_type").change();
				node = $(this).next("div.collapse").children("#sampler_type").change();
				node = $(this).next("div.collapse").children("#pixelfilter_type").change();
				node = $(this).next("div.collapse").children("#fleximage_tonemapkernel").change();
				node = $(this).next("div.collapse").find("#sintegrator_path_rrstrategy").change();
				node = $(this).next("div.collapse").find("#sintegrator_exphoton_rrstrategy").change();
				node = $(this).next("div.collapse").find("#fleximage_write_exr_compressiontype").change();
				node = $(this).next("div.collapse").find("#fleximage_write_exr_zbuf_normalizationtype").change();
				node = $(this).next("div.collapse").find("#fleximage_linear_camera_type").change();
				
				//TODO: expand all checkbox
				// checkbox_expander("fleximage_write_exr")
				// checkbox_expander("fleximage_write_png")
				// checkbox_expander("fleximage_write_tga")
				// checkbox_expander("fleximage_use_colorspace_preset")
				$("input:checkbox").each(function(index, element) { checkbox_expander(element.id) } );
				$(this).next("div.collapse").slideToggle(300);
				// node = $(this).next("div.collapse").children("#environment_light_type").attr("value");
				// $(this).next("div.collapse").children("#environment_light_type").siblings("#" + node).show();
			}
		);
				
		$("#scene_settings_panel p.header2").click(
			function()
			{
				node = $(this).next("div.collapse2").children("#accelerator_type").attr("value");
				$(this).next("div.collapse2").children("#accelerator_type").siblings("#" + node).show();
				node = $(this).next("div.collapse2").children("#sintegrator_type").attr("value");
				$(this).next("div.collapse2").children("#sintegrator_type").siblings("#" + node).show();
//				node = $(this).next("div.collapse2").children("#camera_type").change();
				$(this).next("div.collapse2").slideToggle(300);
				// node = $(this).next("div.collapse").children("#environment_light_type").attr("value");
				// $(this).next("div.collapse").children("#environment_light_type").siblings("#" + node).show();
			}
		);
				
		$("#scene_settings_panel #sintegrator_type").change(
			function()
			{
				//alert("#"+this.value);
				nodes = $(this).nextAll().hide();
				nodes = $(this).nextAll("#" + this.value).show();
			}
		);

		
		$("#scene_settings_panel #accelerator_type").change(
			function()
			{
				//alert("#"+this.value);
				nodes = $(this).nextAll().hide();
				nodes = $(this).nextAll("#" + this.value).show();
			}
		);
                  
        $("#runluxrender").change(
            function()
            {
              //alert(this.value);
              window.location = 'skp:set_runtype@' + this.value;
            }
        )
		
		$("#export_file_path_browse").click(
			function()
			{
				window.location = 'skp:open_dialog@new_export_file_path'
			}
		)
                
        $("#export_luxrender_path_browse").click(
            function()
            {
                window.location = 'skp:open_dialog@change_luxpath'

            }
        ) 
                  
		
		$("#map_file_path_browse").click(
			function()
			{
				window.location = 'skp:open_dialog@load_env_image'
			}
		)

		$("#pickfocaldistance").click(
			function()
			{
				window.location = 'skp:set_focal_distance@'
			}
		)
		
		$("#reset").click(
			function()
			{
				window.location = 'skp:reset_to_default';
			}
		);
		
	}
);
