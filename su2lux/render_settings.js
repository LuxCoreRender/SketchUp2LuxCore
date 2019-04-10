<!--TODO add spinner plugin for number input field -->
function checkbox_expander(id)
{
	if ($("#" + id).attr("checked"))
	{
		$("#" + id).nextAll(".collapse").show();
	}
	else if ($("#" + id).attr("checked") == false)
	{
		$("#" + id).nextAll(".collapse").hide();
	}
}

function update_settings_dropdown(presetname){
    var preset_exists = false;
    $('#renderpreset option').each(
        function(){
            if (this.value == presetname  || this.text == presetname) {
                preset_exists = true;
            }
        }
    )
    if (preset_exists==true){
        //alert ("preset existed already")
        $("#renderpreset").val(presetname);
    }else{
        //alert ("new preset loaded")
        $("#renderpreset").append($('<option></option>').val(presetname).html(presetname));
        $("#renderpreset").val(presetname); // make current
    }
    window.location = 'skp:display_loaded_presets@'   // refresh view
}

function load_active_settings(){
    //alert ("load_active_settings")
    window.location = 'skp:load_settings@' + $("#renderpreset option:selected").text()
}

function add_to_dropdown(simplepreset){
    //alert ("add_to_dropdown running");
    $("#renderpreset").append($('<option></option>').val(simplepreset).html(simplepreset));
    //if (simplepreset == 'interior'){
        // set dropdown to recommended setting
        //$("#renderpreset").val(simplepreset);
        //alert ($("#renderpreset option:selected").text())
        //window.location = 'skp:load_settings@' + $("#renderpreset option:selected").text() // should be started automatically as jquery detects change in dropdown
        //alert (simplepreset)
    //}
}

function update_subfield(field_class)
{
    //alert(field_class)
    $("#"+field_class).nextAll("."+field_class).hide(); // was nextAll instead of each //
    id_option_string = "#" + field_class + " option:selected"
    idvalue = $(id_option_string).val();
    $("#"+field_class).nextAll("#"+idvalue).show(); // was nextAll //
}



$(document).ready(
	function()
	{
        // alert ("settings DOM ready")
        
        $(".continueprobability").hide();
                  
                  
        //window.location = 'skp:load_preset_files@'
        window.location = 'skp:render_setting_loaded@'
                  
        $("#save_settings_file").click(
            function()
            {
                window.location = 'skp:export_settings@' + this.value
            }
        )
                  
        $("#overwrite_settings_file").click(
            function()
            {
                window.location = 'skp:overwrite_settings@' + $("#renderpreset").val()
            }
        )

        $("#load_settings_file").click(
            function()
            {
                window.location = 'skp:load_settings@' + false
            }
        )
                  
        $("#delete_settings_file").click(
            function()
            {
                window.location = 'skp:delete_settings@' + $("#renderpreset option:selected").text()
            }
        )
	
		$("#render_settings_panel select, :text").change( // catches changes in dropdowns and text input fields
			function()
			{
                //alert ("change in settings panel text field");
				window.location = 'skp:param_generate@' + this.id+'='+this.value;
			}
		);


		
		$("#sampler_type").change(
			function()
			{
				$(this).nextAll().hide();
				$(this).nextAll("#" + this.value).show();
				$(".noiseaware").show();
			}
		);
                  
   //   $("#renderer").change(
     //       function()
       //     {
               // alert (this.value)
                    //if (this.value=="sppm"){
                    //    $("#sppm").show();
                    //    $("#integratorsection").hide();
                    //}else{
                    //    $("#sppm").hide();
                    //    $("#integratorsection").show();
                    //}
                //$(this).nextAll("#" + this.value).show();
         //   }
           // );
                  
		$("#sintegrator_path_rrstrategy, #sintegrator_exphoton_rrstrategy").change(
			function()
			{
                parentid = $(this).parent().attr('name');
                $("#"+parentid).children("." + this.id).hide();
                $("#"+parentid).children("#"+ this.value).show();
			}
		);

		
		$("#pixelfilter_type").change(
			function()
			{
				$(this).nextAll().hide();
				$(this).nextAll("#" + this.value).show();
			}
		);
		
		$("#fleximage_tonemapkernel").change(
			function()
			{
				$(this).nextAll("div").hide();
				$(this).nextAll("." + this.value).show();
			}
		);
		
		
		$("#renderpreset").change(
			function()
            {
                window.location = 'skp:param_generate@' + this.id + '=' + $("#renderpreset option:selected").text();
				//alert("loading settings for preset");
				//window.location = 'skp:preset@' + this.value;
                //window.location = 'skp:load_settings@' + $("#renderpreset option:selected").text()
			}
		);

		$(":checkbox").click(
			function()
            {   // note: changing the order of the following methods will cause synchronity issues on OS X
                checkbox_expander(this.id);
                window.location = 'skp:param_generate@' + this.id + '=' + $(this).attr('checked');
			}
		);
		
		$("#render_settings_panel p.header").click(
			function()
			{
				node = $(this).next("div.collapse").children("#accelerator_type").attr("value");
				$(this).next("div.collapse").children("#accelerator_type").siblings("#" + node).show();
				node = $(this).next("div.collapse").children("#sintegrator_type").attr("value");
				$(this).next("div.collapse").children("#sintegrator_type").siblings("#" + node).show();
				node = $(this).next("div.collapse").children("#sampler_type").change();
				node = $(this).next("div.collapse").children("#pixelfilter_type").change();
				node = $(this).next("div.collapse").children("#fleximage_tonemapkernel").change();
				node = $(this).next("div.collapse").find("#sintegrator_path_rrstrategy").change();
				node = $(this).next("div.collapse").find("#sintegrator_exphoton_rrstrategy").change();
				node = $(this).next("div.collapse").find("#fleximage_write_exr_compressiontype").change();
				node = $(this).next("div.collapse").find("#fleximage_write_exr_zbuf_normalizationtype").change();
				
				$("input:checkbox").each(function(index, element) { checkbox_expander(element.id) } );
				$(this).next("div.collapse").slideToggle(300);
			}
		);
				
		$("#render_settings_panel p.header2").click(
			function()
			{
				node = $(this).next("div.collapse2").children("#accelerator_type").attr("value");
				$(this).next("div.collapse2").children("#accelerator_type").siblings("#" + node).show();
				node = $(this).next("div.collapse2").children("#sintegrator_type").attr("value");
				$(this).next("div.collapse2").children("#sintegrator_type").siblings("#" + node).show();
				$(this).next("div.collapse2").slideToggle(300);
			}
		);
				
		$("#sintegrator_type").change(
			function()
			{
				//alert("#"+this.value);
				nodes = $(this).nextAll().hide();
				nodes = $(this).nextAll("." + this.value).show();
			}
		);

		
		$("#accelerator_type").change(
			function()
			{
				//alert("#"+this.value);
				nodes = $(this).nextAll().hide();
				nodes = $(this).nextAll("#" + this.value).show();
			}
		);
		
		$("#save_to_model").click(
			function()
			{
				window.location = 'skp:save_to_model';
			}
		);
		
		$("#reset").click(
			function()
			{
				window.location = 'skp:reset_to_default';
			}
		);
		
	}
);
