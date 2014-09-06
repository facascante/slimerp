
var callAjaxRequest = function(method,endpoint,data,cb){
	var request = {};
	if(method){
		request.type = method;
	}
	if(endpoint){
		request.url = endpoint;
	}
	if(data){
		request.data = data
	}
	$.ajax(request)
	.done(function( msg ) {
		cb(null,msg)
    })
    .fail(function( jqXHR, textStatus ) {
        cb(textStatus);
    });
};