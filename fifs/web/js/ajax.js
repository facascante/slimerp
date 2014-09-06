
function update_options_for(id, json) {
    $(id).empty();
    $(id).append("<option SELECTED value=''></option>");
    $.each(json, function(i, n){
        $(id).append('<option value="'+ n.k + '">' + n.v + "</option>");
    });
}

function ajax_request(data, on_success) {
    $.ajax({
            type: "GET",
            url: "ajax/aj_data_request.cgi",
            contentType: "application/json; charset=utf-8",
            dataType: "json",
            data: data,
            success: on_success
        });
}

