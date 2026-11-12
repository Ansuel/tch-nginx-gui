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
    $("#agentEnable, #wificonductorEnable").val(enabled ? "1" : "0");
    if (typeof easyMeshAgentOnly === "undefined" || !easyMeshAgentOnly) {
      $("#controllerEnable").val(enabled ? "1" : "0");
    }
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

  var acceptedValue = $("#easyMeshEnable").val();
  showState(acceptedValue === "1");
  $(document).off("click.easyMeshConfirm");
  // The shared switch widget updates its hidden value before firing change.
  $("#easyMeshEnable").on("change", function () {
    var enabled = $("#easyMeshEnable").val() === "1";
    if (confirmPopup === "true") {
      confirmationDialogue(enabled ? easyMeshEnableMessage : easyMeshDisableMessage,
        enabled ? enableTitle : disableTitle);
      $(document).off("click.easyMeshConfirm").one("click.easyMeshConfirm", "#ok", function () {
        setState(enabled);
        acceptedValue = enabled ? "1" : "0";
        $(document).off("click.easyMeshConfirm");
        tch.removeProgress();
      }).one("click.easyMeshConfirm", "#cancel", function () {
        var input = $("#easyMeshEnable").val(acceptedValue);
        input.closest(".switch").toggleClass("switchOn", acceptedValue === "1")
          .children(".switcher").toggleClass("switcherOn", acceptedValue === "1");
        $(document).off("click.easyMeshConfirm");
        tch.removeProgress();
      });
    } else {
      setState(enabled);
      acceptedValue = enabled ? "1" : "0";
    }
  });
}());
