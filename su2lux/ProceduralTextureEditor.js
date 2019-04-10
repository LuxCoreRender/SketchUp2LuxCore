function expand_section(sender_id, section_id) {  // user interface: closes/opens panels
	text = sender_id.text();
	$(sender_id).html(text);
	$(sender_id).next(section_id).toggle();
}

function addToTextureList(newName){
	// remove default option, add item for new material, set to new material
	$("option[value='bogus']").remove();
	$('#textures_in_model').append( $('<option></option>').val(newName).html(newName));
	$('#textures_in_model').val(newName);
}

function displayTextureInterface(texType){
	$('#textypedropdownarea').show();
	$("#texture_types").val(texType)
	$('#texturechanneldropdownarea').show();
	$("." + texType).show();
}

function setTextureNameDropdown(texName){
	$("#textures_in_model").val(texName)
}



$(document).ready(	
    function() {
		// hide texture and channel type dropdowns if no material has been created
		if ($('#textures_in_model').val() == 'bogus'){
			$('#textypedropdownarea').hide();
			$('#texturechanneldropdownarea').hide();
		}
		
		$('.parameter_container').hide(); // hides irrelevant material properties
		
		window.location = 'skp:show_texData@'
             
		$('input[id="create_procedural_texture"]').click(
            function()
            {
				//$('#textypedropdownarea').show(); // this should only happen if a valid name is provided, we do not yet know if this is the case
				//$('#texturechanneldropdownarea').show();
				//alert('setting marble');
				var defaultType = "marble";
				//$("#texture_types").val(defaultType); // sets type in dropdown
				//$('.parameter_container').hide(); // hide all texture fields
				//$("."+defaultType).show(); // show right texture field
                window.location = 'skp:create_procedural_texture@' + defaultType; // creates new procedural texture
            }
        )
		
		$("#textures_in_model").change( // procTex_1, procTex_2, ...
			function()
			{
				// pass new active texture name to ruby function, which will then update texture type dropdown, channel type dropdown and relevant parameters
				window.location = 'skp:show_procedural_texture@' + this.value;
			}
		)
		
		$("#texture_types").change( // add, band, bilerp, ...
			function()
			{
				$('.parameter_container').hide(); // hide all texture fields
				$("."+this.value).show(); // show selected field
				paramString = $('#textures_in_model').val() + '|' + $('#texture_types').val(); // + '|' + $('#procTexChannel').val();
				//alert(paramString);
				window.location = 'skp:update_texType@' + paramString;
			}
		) 
		
		$("#procTexChannel").change( // triggered on changing texture channel dropdown menu
			function()
			{
				// call ruby function that deals with change
				var texType = $("#textures_in_model").val();
				var passedParameters = "procTexChannel|" + this.value;
				window.location = 'skp:set_param@' + passedParameters;
			}
		)
        
		// parameter field change
		$(".parameter_field").change(
			function()
			{
				// get parameter name and value
				//var texType = $("#textures_in_model").val();
				var parameterName = this.id; // for example marble_octaves
				var parameterValue = this.value; // for example 3
				// call ruby function that deals with change
				var passedParameters = parameterName + "|" + parameterValue;
				window.location = 'skp:set_param@' + passedParameters;
			}
		)		
				
		$(".vectorparam").change(
			function()
			{
				window.location = 'skp:set_param@' + this.id + "|" + this.value;
			}
		)		
				
		
	}		
)





