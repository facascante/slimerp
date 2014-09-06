jQuery(document).ready(function(){
    // Smart Wizard     
        jQuery('#wizard').smartWizard({transitionEffect:'slideleft',onShowStep:ShowAStep,onLeaveStep:leaveAStepCallback,onFinish:onFinishCallback,enableFinishButton:true});
        var realmID     =   0;
        var fromClub    =   0;
        var fromAssoc   =   0;
        var toAssoc     =   0;
        var toClub      =   0;
        var FromseasonID    =   0;
        var ToseasonID    =   0;
        function leaveAStepCallback(obj){
            var step_num= obj.attr('rel');
            return validateSteps(step_num);
        }

        function onFinishCallback(){
            if(validateAllSteps()){
                //jQuery('form').submit();
                //Finish
                 jQuery.post( "copyMemberSteps.cgi", 
                     {
                        action :"Finish",
                        realmID: realmID,
                        fromAssoc: fromAssoc,
                        toAssoc:toAssoc,
                        fromClub:fromClub,
                        toClub:toClub,
                        FromseasonID:FromseasonID,
                        ToseasonID:ToseasonID,
                        RealmName: jQuery("#realmID option:selected").text(),
                        fromAssocName: jQuery("#fromAssoc option:selected").text(),
                        toAssocName:jQuery("#toAssoc option:selected").text(),
                        fromClubName:jQuery("#fromClub option:selected").text(),
                        toClubName:jQuery("#toClub option:selected").text(),
                        FromseasonName:jQuery("#FromseasonID option:selected").text(),
                        ToseasonName:jQuery("#ToseasonID option:selected").text(),
                        clearOut : jQuery("#clearOut").is(':checked'),
                        activeOldAssoc: jQuery("#activeOldAssoc").is(':checked'),
                        activeNewAssoc: jQuery("#activeNewAssoc").is(':checked'),
                       
                     },
                        function( data ) {
                            jQuery("#finalTitle").html("Member Transfer Report");   
                            jQuery("#review").html(data) ;
                       }
                    );
            }
        }
        function ShowAStep(obj){
            var step_num= obj.attr('rel');
            if (step_num == 2) {
                jQuery.post( "copyMemberSteps.cgi", 
                    {
                       action :"Load",
                       option:"getFromSeason",
                       realmID: realmID,
                       Assoc: fromAssoc
                      
                    },
                       function( data ) {
                        jQuery("#FromseasonID").html(data) ;
                    }
                
                );
                jQuery.post( "copyMemberSteps.cgi", 
                    {
                       action :"Load",
                       option:"getToSeason",
                       realmID: realmID,
                      toAssoc: toAssoc
                      
                    },
                       function( data ) {
                        jQuery("#ToseasonID").html(data) ;
                    }
                
                );
                
            }else if (step_num ==3) {
                //Review
                
                jQuery.post( "copyMemberSteps.cgi", 
                     {
                        action :"Load",
                        option:"review",
                        realmID: realmID,
                        fromAssoc: fromAssoc,
                        toAssoc:toAssoc,
                        fromClub:fromClub,
                        toClub:toClub,
                        FromseasonID:FromseasonID,
                        ToseasonID:ToseasonID,
                        RealmName: jQuery("#realmID option:selected").text(),
                        fromAssocName: jQuery("#fromAssoc option:selected").text(),
                        toAssocName:jQuery("#toAssoc option:selected").text(),
                        fromClubName:jQuery("#fromClub option:selected").text(),
                        toClubName:jQuery("#toClub option:selected").text(),
                        FromseasonName:jQuery("#FromseasonID option:selected").text(),
                        ToseasonName:jQuery("#ToseasonID option:selected").text(),
                        clearOut : jQuery("#clearOut").is(':checked'),
                        activeOldAssoc: jQuery("#activeOldAssoc").is(':checked'),
                        activeNewAssoc: jQuery("#activeNewAssoc").is(':checked'),
                       
                     },
                        function( data ) {
                         jQuery("#review").html(data) ;
                       }
                    );
            }
            
        }
        jQuery.post( "copyMemberSteps.cgi", 
                     {
                        action :"Load",
                        option:"getRealm",
                       
                     },
                        function( data ) {
                         jQuery("#realmID").html(data) ;
                       }
                    );
       
        jQuery("#realmID").change(function(){
            realmID = jQuery(this).val();
            jQuery.post( "copyMemberSteps.cgi", 
                     {
                        action :"Load",
                        option:"getAssoc",
                        realmID:realmID
                       
                     },
                        function( data ) {
                        jQuery("#fromAssoc").html(data) ;
                        jQuery("#fromClub").html();
                        jQuery("#toAssoc").html();
                        jQuery("#toClub").html();
                        
                       }
                    );
        });
        jQuery("#fromAssoc").change(function(){
            fromAssoc = jQuery(this).val();
            jQuery.post( "copyMemberSteps.cgi", 
                     {
                        action :"Load",
                        option:"getClub",
                        Assoc:fromAssoc
                     },
                        function( data ) {
                        jQuery("#fromClub").html(data) ;
                        jQuery("#toAssoc").html();
                        jQuery("#toClub").html();
                       }
                    );
        });
        jQuery("#fromClub").change(function(){
            fromClub = jQuery(this).val();
            realmID = jQuery("#realmID").val();
            jQuery.post( "copyMemberSteps.cgi", 
                     {
                        action :"Load",
                        option:"getAssoc",
                        realmID:realmID
                     },
                        function( data ) {
                        jQuery("#toAssoc").html(data) ;
                        jQuery("#toClub").html();    
                    
                       }
                    );
        });
        jQuery("#toAssoc").change(function(){
            toAssoc = jQuery(this).val();
            jQuery.post( "copyMemberSteps.cgi", 
                     {
                        action :"Load",
                        option:"getClub",
                        Assoc:toAssoc
                     },
                        function( data ) {
                        jQuery("#toClub").html(data) ;
                        
                       }
                    );
        });
        jQuery("#toClub").change(function(){
            toClub = jQuery(this).val();
        });
        jQuery("#FromseasonID").change(function(){
            FromseasonID = jQuery(this).val();
        });
        jQuery("#ToseasonID").change(function(){
            ToseasonID = jQuery(this).val();
        });
});
       
            
function validateAllSteps(){
    var isStepValid = true;

    if(validateStep1() == false){
        isStepValid = false;
        jQuery('#wizard').smartWizard('setError',{stepnum:1,iserror:true});         
    }else{
        jQuery('#wizard').smartWizard('setError',{stepnum:1,iserror:false});
    }

    if(validateStep2() == false){
        isStepValid = false;
        jQuery('#wizard').smartWizard('setError',{stepnum:2,iserror:true});         
    }else{
        jQuery('#wizard').smartWizard('setError',{stepnum:2,iserror:false});
    }        

    if(!isStepValid){
        jQuery('#wizard').smartWizard('showMessage','Please correct the errors in the steps and continue');
    }
  
    return isStepValid;
}   
        
        
function validateSteps(step){
    var isStepValid = true;
    // validate step 1
    if(step == 1){
        if(validateStep1() == false ){
            isStepValid = false; 
            jQuery('#wizard').smartWizard('showMessage','Please correct the errors in step'+step+ ' and click next.');
            jQuery('#wizard').smartWizard('setError',{stepnum:step,iserror:true});         
        }else{
            jQuery('#wizard').smartWizard('setError',{stepnum:step,iserror:false});
        }   
    }
    // validate step2
    if(step == 2){
        if(validateStep2() == false ){
            isStepValid = false; 
            jQuery('#wizard').smartWizard('showMessage','Please correct the errors in step'+step+ ' and click next.');
            jQuery('#wizard').smartWizard('setError',{stepnum:step,iserror:true});         
        }else{
            jQuery('#wizard').smartWizard('setError',{stepnum:step,iserror:false});
        }   
    }

    return isStepValid;
 }
        
function validateStep1(){
    var isValid = true; 
    var realm = jQuery('#realmID').val();
    if(realm == 0){
        isValid = false;
        jQuery('#msg_realm').html('Please select a realm').show();
    }else{
        jQuery('#msg_realm').html('').hide();
    }    
    if(jQuery('#fromAssoc').val() == 0){
        isValid = false;
        jQuery('#msg_fromAssoc').html('Please select a Association').show();
    }else{
        jQuery('#msg_fromAssoc').html('').hide();
    }
    if(jQuery('#toAssoc').val() == 0){
        isValid = false;
        jQuery('#msg_toAssoc').html('Please select a Association').show();
    }else{
        jQuery('#msg_toAssoc').html('').hide();
    }
    if(jQuery('#toClub').val() == 0){
        isValid = false;
        jQuery('#msg_toClub').html('Please select a Club').show();
    }else{
        jQuery('#msg_toClub').html('').hide();
    }
    if(jQuery('#fromClub').val() == 0){
        isValid = false;
        jQuery('#msg_fromClub').html('Please select a Club').show();
    }else{
        jQuery('#msg_fromClub').html('').hide();
    }
    
   // console.log("Validation Step 1:::"+realm);
    return isValid;
}
    
function validateStep2(){
    var isValid = true;    
     if(jQuery('#FromseasonID').val() == 0){
        isValid = false;
        jQuery('#msg_FromseasonID').html('Please select a Season').show();
    }else{
        jQuery('#msg_FromseasonID').html('').hide();
    }
    if(jQuery('#ToseasonID').val() == 0){
        isValid = false;
        jQuery('#msg_ToseasonID').html('Please select a Season').show();
    }else{
        jQuery('#msg_ToseasonID').html('').hide();
    }
    return isValid;
}
