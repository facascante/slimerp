function comparer(a,b) {
	var col = sortcol;
	if(sortcol + '_RAW' in a) {
		col = sortcol + '_RAW';
	}
	var x = a[col];
	if(a[col]){x = a[col].toUpperCase(); }
	var y = b[col];
	if(b[col]) {y = b[col].toUpperCase(); }
	var col_sorttype = sorttype;
	if(col_sorttype == 'number')  {
		return (x -y );
	}
	return (x == y ? 0 : (x > y ? 1 : -1));
}

function gridFilter(item, args) {
	if(args && args.SearchParams) {
		for(var i = 0; i < args.SearchParams.length; i++){
			if(args.SearchParams[i][1] != '') {
				if(args.SearchParams[i][2] == 'regex') {
					var re = new RegExp(args.SearchParams[i][1],"i");
					var t = re.test(item[args.SearchParams[i][0]]);
					if(!re.test(item[args.SearchParams[i][0]]))  {
						return false;
					}
				}
				else  {
					var allvalue = args.SearchParams[i][3];
					if(allvalue == '' || args.SearchParams[i][1] != allvalue ) {
						if(args.SearchParams[i][1] != item[args.SearchParams[i][0]])  {
							return false;
						}
					}
				}
			}
		}
	}
	return true;
}

function SlickHTMLFormatter(row, cell, value, columnDef, dataContext) {
	return '<span class = "grid_htmlcell">' + value + '</span>';
} 
function SlickTickFormatter(row, cell, value, columnDef, dataContext) {
	if(!value || value == 0)  {
		return '';
	}
	if(value && value != 1) {
		return value; 
	}
	if(columnDef.editor)	{
		return value ? "<img src='images/gridcell_tick.png'>" : "";
	}
	return value ? "<img src='images/gridcell_tick_disabled.png'>" : "";
}
function SlickSelectorFormatter(row, cell, value, columnDef, dataContext) {
	return value ? '<a href = "' + value + '"><img src="images/gridcell_select.png"></a>' : '';
}

function SlickDateTimeFormatter(row, cell, value, columnDef, dataContext) {
	if(!value) {return value;}
	var dtfields = value.split(' ');
	var d = dtfields[0].split('-');
	var tmfields = dtfields[1].split(':');
    var ampm = dtfields[2];
	var out  = d[2] + '/' + d[1] + '/' + d[0] + ' ' + tmfields[0] + ':' + tmfields[1];

    if( ampm != '' ) {
        out += ' ' + ampm;
    }
 	
	return out;
}

function SlickSelectListFormatter(row, cell, value, columnDef, dataContext) {
	if(columnDef.options){
		opt_values = columnDef.options.split('|');
	}
	for( var i=0;i<opt_values.length;i++){
		var opts = opt_values[i].split(',');
		if(parseInt(opts[0]) == parseInt(value))	{
			return opts[1];
		}
	}
	return value;
}

// Other Editors
(function (jQuery) {
  // register namespace
  jQuery.extend(true, window, {
    "Slick": {
      "Editors": {
        "SelectBox": SelectCellEditor,
        "DateTime": DateTimeEditor
      }
    }
  });


	function SelectCellEditor (args) {
		var select;
		var defaultValue;
		var scope = this;


		this.init = function() {
					var opt_values = '';			
					var direction = '';
				if(args.column.direction == 'right') {
					direction = 'dir="rtl"';
				}
				if(args.column.options){
					opt_values = args.column.options.split('|');
				}
				else {
					opt_values ="yes,no".split(',');
				}
				option_str = "";
				for(var i=0;i<opt_values.length;i++){
					var opts = opt_values[i].split(',');
					option_str += '<OPTION value="' + opts[0] + '">' + opts[1] + '</OPTION>';
				}
				select = jQuery('<select '+direction+' tabIndex="0" class="editor-select" style = "text-align:left;width:100%">'+ option_str +'</SELECT>');
				select.appendTo(args.container);
				select.focus();
		};

		this.destroy = function() {
				select.remove();
		};

		this.focus = function() {
				select.focus();
		};

		this.loadValue = function(item) {
				defaultValue = item[args.column.field];
				select.val(defaultValue);
		};

		this.serializeValue = function() {
				if(args.column.options){
					return select.val();
				}else{
					return (select.val() == "yes");
				}
		};

		this.applyValue = function(item,state) {
				item[args.column.field] = state;
		};

		this.isValueChanged = function() {
				return (select.val() != defaultValue);
		};

		this.validate = function() {
            if (args.column.validator) {
                if (typeof window[args.column.validator] == 'function') {
                    var vr = window[args.column.validator];
                    var validationResults = vr(select.val(), args.item);
                    if (!validationResults.valid) {
                        return validationResults;
                    }
                }
            }
		    return { valid: true, msg: null };
		};

		this.init();
	}

  function DateTimeEditor(args) {
    var $date;
    var $hour;
    var $min;
    var $ampm;
    var defaultValue;
    var scope = this;
    var calendarOpen = false;

    this.init = function () {
      $date = jQuery('<INPUT type=text class="editor-text" size = "10"/>');
      $date.appendTo(args.container);
      //$date.focus().select();
      $date.datepicker({
		
				dateFormat: 'dd/mm/yy', 
				autoSize: true, 
				changeMonth: true, 
				changeYear: true, 
				yearRange: '1900:2020',
				showOn: 'focus',
				constrainInput: true,
        beforeShow: function () {
          calendarOpen = true
        },
        onClose: function () {
          calendarOpen = false
        }
      });
      $(args.container).append("&nbsp;");

			var h = '';
			for(var i = 1; i <= 12; i++){
				var v = i;
				if(v < 10)	{
					v = '0' + v;
				}
				h = h + '<option value = "' + v + '">' + v + '</option>';
			}
      $hour = jQuery('<select size = "1">' + h + '</select>')
          .appendTo(args.container)
          .bind("keydown", scope.handleKeyDown);

			var m = '';
			for(var i = 0; i <= 59; i++){
				var v = i;
				if(v < 10)	{
					v = '0' + v;
				}
				m = m + '<option value = "' + v + '">' + v + '</option>';
			}
      $min = jQuery('<select size = "1">' + m + '</select>')
          .appendTo(args.container)
          .bind("keydown", scope.handleKeyDown);

      var ap = '<option value = "AM">AM</option>' + '<option value = "PM">PM</option>';
      $ampm = jQuery('<select size = "1">' + ap + '</select>')
          .appendTo(args.container)
          .bind("keydown", scope.handleKeyDown);

      //$input.width($input.width() - 18);
    };

    this.destroy = function () {
      $.datepicker.dpDiv.stop(true, true);
      $date.datepicker("hide");
      $date.datepicker("destroy");
      $date.remove();
    };

    this.show = function () {
      if (calendarOpen) {
        $.datepicker.dpDiv.stop(true, true).show();
      }
    };

    this.hide = function () {
      if (calendarOpen) {
        $.datepicker.dpDiv.stop(true, true).hide();
      }
    };

    this.position = function (position) {
      if (!calendarOpen) {
        return;
      }
      $.datepicker.dpDiv
          .css("top", position.top + 30)
          .css("left", position.left);
    };

    this.focus = function () {
      $date.focus();
    };

    this.loadValue = function (item) {
      defaultValue = item[args.column.field];
			var dtfields = defaultValue.split(' ');
			var d = dtfields[0].split('-');
      $date.val(d[2] + '/' + d[1] + '/' + d[0]);
			var tmfields = dtfields[1].split(':');
      $hour.val(tmfields[0]);
      $min.val(tmfields[1]);
      $ampm.val(dtfields[2]);
      $date.select();
    };

    this.serializeValue = function () {
      var dtvals = $date.val().split('/');
			var newdate = dtvals[2] + '-' + dtvals[1] + '-' + dtvals[0];
			var d = newdate + ' ' + $hour.val() + ':' + $min.val() + ':00' + ' ' + $ampm.val();
			
      return d;
    };

    this.applyValue = function (item, state) {
      item[args.column.field] = state;
    };

    this.isValueChanged = function () {
      return (!($date.val() == "" && defaultValue == null)) && ($date.val() != defaultValue);
    };

    this.validate = function () {
      return {
        valid: true,
        msg: null
      };
    };

    this.init();
  }


})(jQuery);

