function addToVolumeList(newName){
	$("option[value='bogus']").remove();
	$('#volumes_in_model').append( $('<option></option>').val(newName).html(newName));
	$('#volumes_in_model').val(newName);
}

function showParameterSections(volumeType){
	// first hide all parameter sections
	$('.parameter_area').hide();
	// then show appropriate parameter sections
	$('.' + volumeType).show();
}
	
$(document).ready(
		
    function() {
        //alert ("document ready");
		
		$("#type").nextAll().hide(); // hides irrelevant material properties

		window.location = 'skp:update_GUI@'

        $("#create_volume").click(
            function()
            {
                window.location = 'skp:create_volume';
            }
        )
		
		$("#volumes_in_model").change(
			function(){
				// set parameter in volume object, get right parameters from object and show them in interface
				window.location = 'skp:display_volume@' + this.value;
			}
		)		
		
		$("#volume_type").change(
			function(){
				// show right parameter sections
				showParameterSections(this.value);
				// set parameter in volume object, get right parameters from object and show them in interface
				window.location = 'skp:update_volume_type@' + this.value + '|' + $('#volumes_in_model').val();
			}
		)
		
        $("td.swatch").click(
            function()
            {
                //alert (this.id)
                window.location = 'skp:open_color_picker@' + this.id;
            }
        )

		// parameter field change
		$(".parameter_field").change(
			function()
			{
				var volName = $("#volumes_in_model").val();
				// call ruby function that deals with change
				window.location = 'skp:set_param@' + volName + "|" + this.id + "|" + this.value; // passes volumeName|parameterName|parameterValue
			}
		)
		
		

	}		
)





