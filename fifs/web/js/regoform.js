function check_payment_product(e) {
    if ($('.products-table').size() == 0 ) 
        return;

    if ($('.products-table').find('.product-row').size == 0) {
        e.preventDefault();
        alert("You must make a purchase to continue. If there are no products to purchase please contact the organisation who provided this form.");
        return;
    }

    var validate = false;
    $('.products-table').find('.product-row').each( function() {
        var input_list = $(this).find('input');
        if (input_list[0].type == 'hidden') {
            if (input_list[1].value == 0) {
                e.preventDefault();
                alert("Please enter quantity for the mandatory product");
                return;
            } else if (input_list[1].value > 0) {
                //console.log("found compulsory product", this);
                validate = true;
            }
        } else if (input_list[0].type == 'checkbox' && input_list[0].checked && input_list[1].value > 0) {
            //console.log("found compulsory product", this);
            validate = true;
        }
    });
    if ( !validate) {
        e.preventDefault();
        alert("Need to select at least one product to continue registration");
    }
}
