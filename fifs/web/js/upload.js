
$(function() {
    $('.progress').hide();

    // need to update the ContentType field when file choosed
    $('#fileupload').change( function(e) {
        $('#ContentType').val(getMIMEType(this.value));
    });

    $('#upload-form').fileupload({
        url: $(this).attr('action'),
        type: 'POST',
        autoUpload: true,
        dataType: 'xml', 
        add: function (event, data) {
            data.submit();
        },
        send: function(e, data) {
            $('.progress').fadeIn();
        },
        progress: function(e, data){
            var percent = Math.round((data.loaded / data.total) * 100)
            $('.progress-bar').css('width', percent + '%')
        },
        fail: function(e, data) {
            $('.progress').fadeOut(300, function() {
                $('.progress-bar').css('width', 0)
            })
            console.log(data);
        },
        success: function(data) {
            var url = $(data).find('Location').text();
            $('#uploaded_file_url').html(url);
            try {
                var funcNum = getUrlParam( 'CKEditorFuncNum' );
                window.opener.CKEDITOR.tools.callFunction(funcNum, url);
                window.close();
            } catch(err) {
                // do nothing
            }
            console.log(data);
        },
        done: function (event, data) {
            $('.progress').fadeOut(300, function() {
                $('.progress-bar').css('width', 0)
            })
        },
    });
});


function getUrlParam( paramName ) {
    var reParam = new RegExp( '(?:[\?&]|&)' + paramName + '=([^&]+)', 'i' ) ;
    var match = window.location.search.match(reParam) ;

    return ( match && match.length > 1 ) ? match[ 1 ] : null ;
}

