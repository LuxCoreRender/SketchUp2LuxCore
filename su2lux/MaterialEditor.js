function expand_section(sender_id, section_id, closed_sign, opened_sign) {  // user interface: closes/opens panels
	text = sender_id.text();
	$(sender_id).html(text);
	//$(sender_id).next(section_id).slideToggle(100);
	$(sender_id).next(section_id).toggle();
}

function checkbox_expander(id){      // user interface, shows and hides interface fields for current material
    if ($("#" + id).attr("checked"))
	{
		$("#" + id).nextAll(".collapse_check").show();
	}
	else if ($("#" + id).attr("checked") == false)
	{
		$("#" + id).nextAll(".collapse_check").hide();
	}
}

function startactivemattype(){ // loaded on opening SketchUp on OS X, on showing material dialog on Windows // triggered by window.location = 'skp:show_continued@'
	if ($("#material_name").val() == "bogus"){
		//alert ("not initialized");
		window.location = 'skp:start_refresh_and_update@' + this.id;
	}
}

function addToProcTextList(newName, channelType){
	$("option[value='noProcText']").remove();
		// note: values are only added if they are not already present
	if(channelType == 'color'){		
		if ($(".proctex_dropdown_color option[value=" + newName + "]").length<1){
			$('.proctex_dropdown_color').append( $('<option></option>').val(newName).html(newName));
		}
	}else if(channelType == 'float'){
		if ($(".proctex_dropdown_float option[value=" + newName + "]").length<1){
			$('.proctex_dropdown_float').append( $('<option></option>').val(newName).html(newName));
		}
	}else if(channelType == 'fresnel'){
		if ($(".proctex_dropdown_fresnel option[value=" + newName + "]").length<1){
			$('.proctex_dropdown_fresnel').append( $('<option></option>').val(newName).html(newName));
		}
	}
}

function setProcTextList(dropdown, texname){
	//alert(dropdown);
	//alert(texname);
	$(dropdown).val(texname);
}

function removeFromProcTextList(texName){
	$("option[value='" + texName + "']").remove();
}
	
function startmaterialchanged() {
    window.location = 'skp:material_changed@' + this.value;
}

function setpreviewheight(previewsize,previewtime){
	//alert ("setpreviewheight")
    // image and element size
    $("#preview").height(previewsize+28)
    $("#preview_image").height(previewsize)
    
    // dropdown values
    $("#previewtime").val(previewtime)
    $("#previewsize").val(previewsize)
    
    // preview button location
    verticalposition = previewsize - 18
    $("#update_material_preview").css('top',verticalposition+'px')
    
}
    
function update_RGB(fieldR,fieldG,fieldB,colorr,colorg,colorb){
    $(fieldR).val(colorr);
    $(fieldG).val(colorg);
    $(fieldB).val(colorb);
}

function show_load_buttons(textype,filename){
    //alert (textype)
    //alert ("show_load_buttons")
    idname = textype + '_texturetype';
    if ($('#'+idname).val()=="imagemap"){
        $('#'+idname).nextAll(".imagemap").show(); // shows  <span class="imagemap">
        $('#'+textype+'_imgmapname').text(filename)
    }
    // autoalpha
    if (textype=="aa"){
        $('#aa_imgmapname').text(filename)
    }
    
    // show color/texture area for custom metal2 material
    if ($("#metal2_preset").val()=="custom"){
        $(".metal2_custom").show();
    } else{
        $(".metal2_custom").hide();
    }
}

function show_fields(material_type){
	$("#type").nextAll().hide();
	$("#type").nextAll("." + material_type).show();
}

$(document).ready(
		
    function() {
        //alert ("document ready");
		
		$("#type").nextAll().hide(); // hides irrelevant material properties
		
		window.location = 'skp:show_continued@'
        
		
		$("#settings_panel select, :text").change( // triggered on changing dropdown menus or text fields
			function()
			{
                //alert ("detected!")
				
				if(this.id == "material_name"){     
					//alert("different material selected: " + this.value);
					window.location = 'skp:material_changed@' + this.value;
				}else{
					//alert("dropdown parameter changed");
					window.location = 'skp:param_generate@' + this.id+'='+this.value
				}
			}
		)
		
		$(":checkbox").click(
			function()
			{
                if(this.id=="use_architectural"){
                    //alert ("architectural")
                    window.location = 'skp:param_generate@' + this.id + '=' + $(this).attr('checked');
                     if($(this).attr('checked')){
                        $("#IOR_interface").hide()
                     }else{
                        $("#IOR_interface").show()
                     }
                }
                else if(this.id){
                    window.location = 'skp:param_generate@' + this.id + '=' + $(this).attr('checked');
                    checkbox_expander(this.id)
                }else{ // synchronize colorize checkboxes for "sketchup" and "imagemap" types
                    $("." + this.name).attr('checked', $(this).attr('checked'));
                    window.location = 'skp:param_generate@' + this.name + '=' + $(this).attr('checked');
                }
			}
		)

		$("#type").change(
			function() {
                //alert ("type change")
                $(this).nextAll().hide();
                $(this).nextAll("." + this.value).show();
                window.location = 'skp:type_changed@' + this.value;
			}
		)
                  
        $("#metal2_preset").change(
			function() {
                if ($("#metal2_preset").val()=="custom"){
                    $(".metal2_custom").show();
                } else{
                    $(".metal2_custom").hide();
                }
			}
		)
        
		$("#light_L").change(
			function() {
                //alert ("javascript: light spectrum type change")
                $(".light_L").hide();
                $("#" + this.value).show();
			}
		)
                  
        $("#carpaint_name").change(
            function() {
                if ($("#carpaint_name").val()==""){
                    $("#diffuse").show();
                } else{
                    $("#diffuse").hide();
                }
			}
		)
        

		
		$("#settings_panel p.header").click(
			function()
			{
				expand_section($(this), "div.collapse", "+", "-");
				$(this).next("div.collapse").find("select").change();
				// checkbox_expander("use_diffuse_texture");
				$("input:checkbox").each(function(index, element) { checkbox_expander(element.id) } );
			}
		)

        $(".header2").click(
            function()
            {
                //alert (this)
                expand_section($(this), "div.collapse", "+", "-");
            }
        )
        
		$("#ies_path_button").click(
			function()
			{
				window.location = 'skp:select_IES@'; 
			}
		)
		        
		$("#ies_path_clear").click(
			function()
			{
				window.location = 'skp:clear_IES@'; 
			}
		)
                  
        $("td.swatch").click(
            function()
            {
                // alert (this.id)
                window.location = 'skp:open_color_picker@' + this.id;
            }
        )
		
		//$("[id$=_texturetype]").change(
		//	function(){
		//		if(this.value == "procedural"){
		//			// first, report dropdown name
		//			//alert(this.id);
		//			// if that works, call a method that in turn will set the relevant texture
		//			window.location = 'skp:set_procedural_texture@' + this.id;
		//		}
		//	}
		//)
		
		$('select[id$="_imagemap_filtertype"]').change(
			function()
			{
				$(this).nextAll().hide();
				$(this).nextAll("." + this.value).show();
			}
		)
		
		$('select[id$="_texturetype"]').change(
			function()
            {
                $(this).nextAll().hide();
                $(this).nextAll("." + this.value).show(); // shows image map interface elements
                // show auto alpha field
                if (this.value == "imagealpha" || this.value == "imagecolor"){
                    $("#autoalpha_image_field").show();
                }else if (this.value == "sketchupalpha"){
                    $("#autoalpha_image_field").hide();
                }
                // note: do not add window.location methods as they will interfere with .change functions on OS X
			}
		)

        $("#mx_texturetype").change(
            function()
            {
                $(this).nextAll("div").hide();
                $(this).nextAll("span").hide();
                $(this).nextAll("." + this.value).show();
            }
        )
                  
        $("#imagemap_filename").change(
            function()
               {
                    //alert(this.value)
                    $("#texture_preview").attr("src", this.value);
                    // store path for proper channel
                }
        )
 
        $("#dm_scheme").change(
            function()
            {
                if (this.value=="microdisplacement"){
                    $("#loop").hide();
                    $("#microdisplacement").show();
                }else{
                    $("#loop").show();
                    $("#microdisplacement").hide();
                }
            }
        )
 
        $("#specular_scheme").change(
            function()
            {
                if (this.value=="specular_scheme_IOR"){
                    $("#specular_scheme_color").hide();
                    $("#specular_scheme_preset").hide();
                    $("#specular_scheme_IOR").show();
                }else if (this.value=="specular_scheme_color"){
                    $("#specular_scheme_color").show();
                    $("#specular_scheme_preset").hide();
                    $("#specular_scheme_IOR").hide();
                }else{
                    $("#specular_scheme_color").hide();
                    $("#specular_scheme_preset").show();
                    $("#specular_scheme_IOR").hide();
                }
            }
        );
                  
        $("#specular_preset").change(
            function()
            {
                 $('#spec_IOR_preset_value').text(parseFloat(this.value).toFixed(3));
            }
        )
        
        $('#previewsize').change(
            function()
            {
                //alert(this.value);
                window.location = 'skp:previewsize@' + this.value;
            }
        )
                  
        $('#previewtime').change(
            function()
            {
                //alert(this.value);
                window.location = 'skp:previewtime@' + this.value;
            }
        )
                  
		
		$('input[id$="_browse"]').click(
			function()
			{
				id = this.id;
				index = id.lastIndexOf("_browse");
				text = id.substring(0, index);
				window.location = 'skp:open_dialog@' + text;
			}
		)
		
		$('input[id$="_browse_map"]').click(
			function()
			{
				id = this.id;
				index = id.lastIndexOf("_browse_map");
				text = id.substring(0, index);
				window.location = 'skp:texture_editor@' + text;
			}
		)
		
		$("#get_diffuse_color").click(
			function()
			{
				window.location = 'skp:get_diffuse_color'
			}
		)
		
		$("#reset").click(
			function()
			{
				window.location = 'skp:reset_to_default';
			}
		)
		
		$('input[id="update_changes"]').click(
			function()
			{
				window.location = 'skp:update_changes';
			}
		)
		
		$('input[id="cancel_changes"]').click(
			function()
			{
				window.location = 'skp:cancel_changes';
			}
		)
        
        $('input[id="update_material_preview"]').click(
            function()
            {
                window.location = 'skp:update_material_preview';
            }
        )	
	}		
)





