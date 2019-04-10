function addToLampList(newName){
	$("option[value='bogus']").remove();
	$('#lamps_in_model').append( $('<option></option>').val(newName).html(newName));
}

function setLampList(passedName){
	$('#lamps_in_model').val(passedName);
}

function addToLampListAndSet(newName){
	$("option[value='bogus']").remove();
	$('#lamps_in_model').append( $('<option></option>').val(newName).html(newName));
	$('#lamps_in_model').val(newName);
}


function clearLampList(){
	$('#lamps_in_model').empty();
}

function showParameterSections(lampType){
	// first hide all parameter sections
	$('.parameter_area').hide();
	// then show appropriate parameter sections
	$('.' + lampType).show();
}
	
$(document).ready(
		
    function() {
        //alert ("document ready");
		
		$("#head").nextAll().hide(); // hides irrelevant material properties

		window.location = 'skp:update_GUI@'

        $("#create_lamp").click(
            function()
            {
                window.location = 'skp:create_lamp';
            }
        )
		
		$("#lamps_in_model").change(
			function(){
				//alert("change in #lamps_in_model detected");
				// set parameter in lamp object, get right parameters from object and show them in interface
				window.location = 'skp:display_lamp@' + this.value;
			}
		)		
		
		$("#lamp_type").change(
			function(){
				// show right parameter sections
				showParameterSections(this.value);
				// set parameter in lamp object, get right parameters from object and show them in interface
				window.location = 'skp:update_lamp_type@' + this.value + '|' + $('#lamps_in_model').val();
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
				var lampName = $("#lamps_in_model").val();
				// call ruby function that deals with change
				window.location = 'skp:set_param@' + lampName + "|" + this.id + "|" + this.value; // passes lampName|parameterName|parameterValue
			}
		)
		
		$(".parameter_field_wide").change(
			function()
			{
				var lampName = $("#lamps_in_model").val();
				// call ruby function that deals with change
				window.location = 'skp:set_param@' + lampName + "|" + this.id + "|" + this.value; // passes lampName|parameterName|parameterValue
			}
		)
		
		
		
		
		
		
		$("#iesname_button").click(
			function()
			{
				window.location = 'skp:select_IES@'; 
			}
		)
		
		$("#iesname_clear").click(
			function()
			{
				window.location = 'skp:clear_IES@'; 
			}
		)
		
		$("#mapname_button").click(
			function()
			{
				window.location = 'skp:select_map@'; 
			}
		)
		
		$("#mapname_clear").click(
			function()
			{
				window.location = 'skp:clear_map@'; 
			}
		)
		

	}		
)





