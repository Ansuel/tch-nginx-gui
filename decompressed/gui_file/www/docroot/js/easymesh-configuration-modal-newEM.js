// The GUI reuses the same modal; discard polling from the previous instance.
if (typeof controller_status !== "undefined") clearInterval(controller_status);
if (typeof agent_status !== "undefined") clearInterval(agent_status);
var labelHide = $("[id='controllermac'], [id='agentmac']");
var controller = $("[id='easyMeshController']");
var agent = $("[id='easyMeshAgent']");
var target = $(".modal form").attr("action");
var stateBlock = $("[id='state@cred2']");
var isControllerState = (($("[id='EasyMesh Controller']").text() == "ON") && ($("[id='EasyMesh Agent']").text() == "ON")) ? 1 : 0;
var easymeshRole = $("[id='Easymesh Role']").text() == "Controller" ? 1 : 0;

$(document).off("click.easyMeshPopup").on("click.easyMeshPopup", "#ok, #cancel", function() {
  tch.removeProgress();
});

if (controlSelection == "true") {
  agent.closest(".control-group .controls").css({"pointer-events":"none","opacity":"0.5"})
  if (controlSelect == "telus"){
    controller.closest(".control-group .controls").css({"pointer-events":"none","opacity":"0.5"});
  }
}

if (multiapAgent == "1" || multiapContr == "1"){
  stateBlock.closest(".control-group .controls").css({"pointer-events":"none","opacity":"0.5"});
}

if ($("#control_select").val() == "telus"){
  $(".todWarning").hide();
}

function easyMeshEnable() {
  $("#agentEnable").val("1")
  $("#controllerEnable").val("1")
  $("#wificonductorEnable").val("1")
  if (controlSelection == "true") {
    $("#wifibandsteerEnable").val("0")
    if (isGuest) {
      $("#wifiGuestbandsteerEnable").val("0")
    }
  }
  labelHide.closest(".control-group").show();
}

function easyMeshDisable() {
  $("#agentEnable").val("0")
  $("#controllerEnable").val("0")
  $("#wificonductorEnable").val("0")
  if (controlSelection == "true") {
    $("#wifibandsteerEnable").val("0")
    if (isGuest) {
      $("#wifiGuestbandsteerEnable").val("0")
    }
  }
  labelHide.closest(".control-group").hide();
}

function enableParams(id) {
  $("#" + id).val("1")
  if (controlSelection == "true") {
    $("#wifibandsteerEnable").val("0")
    $("#wifiGuestbandsteerEnable").val("0")
  }
  labelHide.closest(".control-group").show();
}

function disableParams(id) {
  $("#" + id).val("0")
  if (controlSelection == "true") {
    $("#wifibandsteerEnable").val("0")
    $("#wifiGuestbandsteerEnable").val("0")
  }
  labelHide.closest(".control-group").hide();
}
if ($("#easyMeshAgent").length) {
  if ($("#easyMeshAgent").val() == "1") {
    enableParams("agentEnable")
  } else {
    disableParams("agentEnable")
  }
}

if ($("#easyMeshController").length) {
  if ($("#easyMeshController").val() == "1") {
    enableParams("controllerEnable")
  } else {
    disableParams("controllerEnable")
  }
}

if (($("#easyMeshAgent").val() == "1") || ($("#easyMeshController").val() == "1") || ($("#easyMeshEnable").val() == "1") || (isControllerState == "1") || (easymeshRole == "1")) {
  $("[id='Topology'], [id='Agent List'], [id='easyMeshDevices']").show()
  $("[id='Topologia'], [id='Agent List'], [id='easyMeshDevices']").show()
} else {
  $("[id='Topology'], [id='Agent List'], [id='easyMeshDevices']").hide()
  $("[id='Topologia'], [id='Agent List'], [id='easyMeshDevices']").hide()
}
var nodeStatus
//EasyMesh Agent and Controller Services click function
$(".switch").click(function() {
  if ($(this).find("#easyMeshEnable").length) {
  if ($("#easyMeshEnable").val() == "1") {
    if (confirmPopup) {
      confirmationDialogue(easyMeshDisableMessage, disableTitle, "disable");
      $("#ok").one("click", function() {
        easyMeshDisable()
      });
    } else {
      easyMeshDisable()
    }
  } else if($("#easyMeshEnable").val() == "0") {
    if (confirmPopup) {
      confirmationDialogue(easyMeshEnableMessage, enableTitle, "enable");
      $("#ok").one("click", function() {
        easyMeshEnable()
      });
    } else {
      easyMeshEnable()
    }
  }
  }

  if ($(this).find("#easyMeshAgent").length == "1") {
    if ($("#easyMeshAgent").val() == "1") {
      disableParams("agentEnable")
    } else {
      enableParams("agentEnable")
    }
  }
  if ($(this).find("#easyMeshController").length == "1") {
    if ($("#easyMeshController").val() == "1") {
      $("#controllerEnable").val("0")
      disableParams("controllerEnable")
    } else {
      $("#controllerEnable").val("1")
      enableParams("controllerEnable")
    }
  }
});

//On change of frequency band checkboxes,
//updating the hidden field value with checked values as comma separated
$('input[name=frequencyBands]').change(function(){
  var selectedFrequencies = '';
  $(this).parent().parent().find('input[name=frequencyBands]').each(function(i,e) {
    if ($(e).is(':checked')) {
      var appendComma = selectedFrequencies.length === 0 ? '' : ',';
      selectedFrequencies += (appendComma+e.value);
    }
  })
  $(this).parent().parent().parent().next().find('input').val(selectedFrequencies)
});

var controller_status = setInterval(getControllerStatus, 2000);
if (multiapContr == "0") {
  clearInterval(controller_status);
}
var agent_status;
if ((currentRole == "engineer" || isExtender) && multiapAgent == "1") {
  agent_status =  setInterval(getAgentStatus, 2000);
}

function noneMode() {
  if (document.getElementById("securityMode" + credParamIndex).value == "none") {
    $(".monitor-wpa-psk").addClass("hide").removeClass("show");
    $(".monitor-none").addClass("show").removeClass("hide");
  } else {
    $(".monitor-wpa-psk").removeClass("hide").addClass("show");
    $(".monitor-none").addClass("hide").removeClass("show");
  }
}
if (document.getElementById("securityMode" + credParamIndex)) {
  noneMode()
}
if (document.getElementById("securityMode" + credParamIndex)) {
  document.getElementById("securityMode" + credParamIndex).onchange = function(){
    if ($(this).val() == "none") {
      confirmationDialogue("Security for the wireless network will be <br> disabled and anyone will be able to connect <br> or listen, please confirm to continue?", "Security Mode", "", "Continue");
    }
    noneMode()
  }
}
$(document).off("click.easyMeshOk").on("click.easyMeshOk", "#ok", function() {
  tch.removeProgress();
});

$(document).off("click.easyMeshCancel").on("click.easyMeshCancel", "#cancel", function() {
  var target = $(".modal form").attr("action");
  var scrolltop = $(".modal-body").scrollTop();
  tch.loadModal(target, function () {
    $(".modal-body").scrollTop(scrolltop);
  });
  tch.removeProgress();
});

$("#controller1,#controller2, #controller3, #controller4, #controller5, #controller6, #controller7").addClass("grey-bar");
function getControllerStatus() {
  $.get(target+"?action=controllerStatus", function(response) {
    if (response.getParams.controllerStatus == "[1/7] initializing") {
      $("#controller1").removeClass("grey-bar").addClass("green-bar");
      $("#controller2, #controller3, #controller4, #controller5, #controller6, #controller7").addClass("grey-bar");
      $("#status-text-box").html(T["initializingController"]);
    }else if(response.getParams.controllerStatus == "[2/7] synchronizing") {
      $("#controller1, #controller2").removeClass("grey-bar").addClass("green-bar");
      $("#status-text-box").html(T["syncController"]);
    }else if(response.getParams.controllerStatus == "[3/7] starting") {
      $("#controller1, #controller2, #controller3").removeClass("grey-bar").addClass("green-bar");
      $("#status-text-box").html(T["startController"]);
    }else if(response.getParams.controllerStatus == "[4/7] up") {
      $("#controller1, #controller2, #controller3, #controller4").removeClass("grey-bar").addClass("green-bar");
      $("#status-text-box").html(T["upController"]);
    }else if(response.getParams.controllerStatus == "[5/7] local agent onboarding in progress") {
      $("#controller1, #controller2, #controller3, #controller4, #controller5").removeClass("grey-bar").addClass("green-bar");
      $("#status-text-box").html(T["onboardProgressController"]);
    }else if(response.getParams.controllerStatus == "[6/7] checking messages from local agent") {
      $("#controller1, #controller2, #controller3, #controller4, #controller5, #controller6").removeClass("grey-bar").addClass("green-bar");
      $("#status-text-box").html(T["messageController"]);
    }else if(response.getParams.controllerStatus == "[7/7] local agent onboarding success") {
      $("#controller1, #controller2, #controller3, #controller4, #controller5, #controller6, #controller7").removeClass("grey-bar").addClass("green-bar");
      $("#status-text-box").html(T["onboardSuccessController"]);
      clearInterval(controller_status);
    }
  });
}

$("#agent1, #agent2, #agent3, #agent4, #agent5, #agent6").addClass("grey-bar");
function getAgentStatus() {
  $.get(target+"?action=agentStatus", function(response) {
    if (response.getParams.agentStatus == "[1/6] initializing") {
      $("#agent1").removeClass("grey-bar").addClass("green-bar");
      $("#agent2, #agent3, #agent4, #agent5, #agent6").addClass("grey-bar")
      $("#status-text-box-agent").html(T["initializingAgent"]);
    }else if(response.getParams.agentStatus == "[2/6] synchronizing") {
      $("#agent1, #agent2").removeClass("grey-bar").addClass("green-bar");
      $("#status-text-box-agent").html(T["syncAgent"]);
    }else if(response.getParams.agentStatus == "[3/6] starting") {
      $("#agent1, #agent2, #agent3").removeClass("grey-bar").addClass("green-bar");
      $("#status-text-box-agent").html(T["startAgent"]);
    }else if(response.getParams.agentStatus == "[4/6] up") {
      $("#agent1, #agent2, #agent3, #agent4").removeClass("grey-bar").addClass("green-bar");
      $("#status-text-box-agent").html(T["upAgent"]);
    }else if(response.getParams.agentStatus == "[5/6] onboarding in progress") {
      $("#agent1, #agent2, #agent3, #agent4, #agent5").removeClass("grey-bar").addClass("green-bar");
      $("#status-text-box-agent").html(T["onboardProgressAgent"]);
    }else if(response.getParams.agentStatus == "[6/6] onboarding success") {
      $("#agent1, #agent2, #agent3, #agent4, #agent5, #agent6").removeClass("grey-bar").addClass("green-bar");
      $("#status-text-box-agent").html(T["onboardSuccessAgent"]);
      clearInterval(agent_status);
    }
  });
}

var showPassword = 1;
if (multiapAgent != "1" && multiapContr != "1" && currentRole == "engineer" && showPass && document.getElementById("showpass" + credParamIndex)){
  if (showPass ) {
    document.getElementById("password" + credParamIndex).type = "password";
  }
  document.getElementById("showpass" + credParamIndex).onchange = function(){
    if (showPassword == 1) {
      document.getElementById("password" + credParamIndex).type = "text";
      showPassword = 0;
    }
    else {
      document.getElementById("password" + credParamIndex).type = "password";
      showPassword = 1;
    }
  }
}

$(".modal").off("hidden.easyMeshStatus").one("hidden.easyMeshStatus", function () {
  clearInterval(controller_status);
  clearInterval(agent_status);
});
