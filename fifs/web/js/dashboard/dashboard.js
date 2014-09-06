$('#password').hidePassword(true);

$.ajax({
  url: 'http://api.randomuser.me/0.3.2/?seed=greenBear',
  dataType: 'json',
  success: function(data){
    $("img.profile-pic").attr("src",data.results[0].user.picture);
    $("img.user-one-pic").attr("src",data.results[0].user.picture);
    $(".user-one-firstname").append(data.results[0].user.name.first);
    $(".user-one-lastname").append(data.results[0].user.name.last);
    $(".user-one-email").append(data.results[0].user.email);
    }
});

$.ajax({  
  url: 'http://api.randomuser.me/0.3.2/?seed=silverLeopard',
  dataType: 'json',
  success: function(data){
    $("img.user-two-pic").attr("src",data.results[0].user.picture);
    $(".user-two-firstname").append(data.results[0].user.name.first);
    $(".user-two-lastname").append(data.results[0].user.name.last);
    $(".user-two-email").append(data.results[0].user.email);
  }
});
