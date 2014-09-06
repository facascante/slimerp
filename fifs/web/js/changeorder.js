  //<!-- Original:  Roelof Bos (roelof667\@hotmail.com) -->
  //<!-- Web Site:  http:\/\/www.refuse.nl -->
	//<!-- Modified Warren Rodie warren@sportingpulse.com -->

  //<!-- Begin
  function move(list, index,to) {
    var total = list.options.length-1;
    if (index == -1) {
			alert("You must select a section");
			return false;
		}
    if (to == +1 && index == total) return false;
    if (to == -1 && index == 0) return false;
    var items = new Array;
    var values = new Array;
    for (i = total; i >= 0; i--) {
      items[i] = list.options[i].text;
      values[i] = list.options[i].value;
    }
    for (i = total; i >= 0; i--) {
      if (index == i) {
        list.options[i + to] = new Option(items[i],values[i ], 0, 1);
        list.options[i] = new Option(items[i + to], values[i + to]);
        i--;
      }
      else {
        list.options[i] = new Option(items[i], values[i]);
      }
    }
    list.scrollTop = (index + to - 1) * 10;
    list.focus(); 
  }

  function updateorder(list, updatefield) {
    var neworder= '';
    for (i = 0; i <= list.options.length-1; i++) {
      neworder+= list.options[i].value;
      if (i != list.options.length-1) neworder+= "|";
    }
		updatefield.value=neworder;
  }

//End
