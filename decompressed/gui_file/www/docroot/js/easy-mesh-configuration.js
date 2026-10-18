// Keep the hidden controller, agent and Wi-Fi settings in sync with the EasyMesh switch.
(function () {
  var labels = $("[id='controllermac'], [id='agentmac']");
  var tabs = $("[id='" + extenderInfo + "'], [id='" + agentList + "'], [id='" + devicesList + "']");
  var credentials = $("[id^='state@cred'], [id^='fronthaul@cred'], [id^='backhaul@cred']");

  if (multiapAgent === "1" && multiapContr === "1") {
    credentials.closest(".controls").css({ "pointer-events": "none", opacity: "0.5" });
  }

  function showState(enabled) {
    labels.closest(".control-group").toggle(enabled);
    tabs.toggle(enabled);
  }

  function setState(enabled) {
    $("#agentEnable, #controllerEnable, #wificonductorEnable").val(enabled ? "1" : "0");
    if (enabled) {
      $("#wifibandsteerEnable, #wifiGuestbandsteerEnable").val("0");
    } else if (bandsteerDisabled) {
      if (ap0_state === "1" && ap1_state === "1") {
        $("#wifibandsteerEnable").val("1");
      }
      if (isGuest && guestAP.length && guestAP.every(function (ap) { return content[ap] === "1"; })) {
        $("#wifiGuestbandsteerEnable").val("1");
      }
    }
    showState(enabled);
  }

  showState($("#easyMeshEnable").val() === "1");
  $("#easyMeshEnable").closest(".switch").on("click", function () {
    var enabled = $("#easyMeshEnable").val() === "1";
    if (confirmPopup === "true") {
      confirmationDialogue(enabled ? easyMeshEnableMessage : easyMeshDisableMessage,
        enabled ? enableTitle : disableTitle, enabled ? "enable" : "disable");
      $(document).one("click", enabled ? ".enable" : ".disable", function () { setState(enabled); });
    } else {
      setState(enabled);
    }
  });
  $(document).on("click", "#ok, #cancel", function () { tch.removeProgress(); });
}());
