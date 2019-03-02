var elmArr = document.getElementsByClassName("content");

var styleEl = document.createElement('style'), styleSheet;
document.head.appendChild(styleEl);
styleSheet = styleEl.sheet;

styleSheet.insertRule('#statsFrame { visibility: visible}');
var ruleR1 = styleSheet.cssRules[0];

styleSheet.insertRule('#headerbox { marginLeft: 0;}');
var ruleR2 = styleSheet.cssRules[0];

styleSheet.insertRule('.apprise-overlay { opacity: 0 !important; pointer-events: none}');
var ruleR3 = styleSheet.cssRules[0];

styleSheet.insertRule('.span3 .content { filter: brightness(1);}');
var ruleR4 = styleSheet.cssRules[0];

styleSheet.insertRule('#headertab {}');
var ruleR5 = styleSheet.cssRules[0];

function genHeaderBox() {
	$("body").append("<div id='headerbox'></div>");
	  var num=1;
	  $('#cardrow>.span3>.smallcard>.header').each(function() {
		  $(this).attr('id', "headerid"+num);
	  	$(this).detach().appendTo('#headerbox');
		num++;
	  });
	  num = 1;
	  $('#cardrow>.span3>.smallcard>.content').each(function() {
		  $(this).attr('id', "cardid"+num);
		  num++;
	  });
	  num = 1;
	  $("#headerbox").show('slow');
	  document.querySelector('#headertab').addEventListener('click', function (e) {
  	  if (e.pageX != 0 && e.pageY !=0){
  		if (e.pageX  < 60 && window.innerWidth <= (50 * parseFloat(getComputedStyle(document.documentElement).fontSize))) {
  			openNav();
  		}
  	  }
      });
	  document.querySelector('#headerbox').addEventListener('click', function (e) {
  	  if (e.target.childNodes.length == 2 && e.target.childNodes[0].nodeName == "DIV" && e.target.childNodes[1].nodeName == "DIV")
  		e.target.childNodes[0].click();
  		
  	    closeNav();
      });
}

function waitHeaderLoad() {
	if ($('#TmpCardRow>#cardrow>.span3>.smallcard>.header').length > 0) {
		genHeaderBox();
		$("#TmpCardRow").detach();
	} else {
		setTimeout(function() {
				waitHeaderLoad();
			}, 1000);
	}
}

function themescript() {
	if (document.querySelector('#headerbox') == null){
		if ( $("#infocardrow").length ) {
			$('<div id="TmpCardRow" class="hide"></div>').insertAfter("#infocardrow").load( "/cards.lp?contentonly=true #cardrow" );
			setTimeout(function() {
				waitHeaderLoad();
			}, 1000);
		} else if ( $("#cardrow").length ) {
			genHeaderBox();
		}
	}
	  
	if (document.querySelector('#headerbox') != null){
      //window.onresize = updateHeight;
      //updateHeight();
	  if ( $("#cardrow").length ) {
		$('#cardrow>.span3>.smallcard>.header').each(function() {
			$(this).detach();
		});
		
		num = 1;
		$('#cardrow>.span3>.smallcard>.content').each(function() {
			$(this).attr('id', "cardid"+num);
			num++;
		});
	  
		$(".content.card_bg").on("click", function() {
			var id = $(this).attr('id').replace(/cardid/, '');
			$("#headerid"+id)[0].click();
		});
	  }
    }
}

$(document).ready(
    function() {
	
    document.querySelector('.apprise-overlay').style.opacity = "";
    $(document).off("touchend", '[data-toggle\x3d"modal"]');
    $(document).off("touchend", ".smallcard");

	themescript();
	closeNav();
      
      document.querySelector('.apprise-overlay').addEventListener('click', function (e) {
        closeNav();
      });
  
	//
	$("#swtichbuttom").on("switchcard", function() {
		setTimeout(themescript, 3000);
	});
});

var blockHeight = false;
var modalOpen = false;

function openNav() {
	ruleR2.style.marginLeft = "0";
	ruleR2.style.overflow = "auto";
	ruleR3.style.zIndex = "1";
	ruleR5.style.zIndex = "0";
	ruleR3.style.opacity = "0.6";
	ruleR4.style.filter = "brightness(0.4)";
	ruleR3.style.pointerEvents  = "all";
	ruleR4.style.display = "none";
	blockHeight = true;
}

function closeNav() {
	ruleR2.style.marginLeft  = "-15.5rem";
	ruleR2.style.overflow = "visible";
	ruleR3.style.zIndex = "2";
	ruleR5.style.zIndex = "6";
	ruleR3.style.opacity = "0";
	ruleR4.style.filter = "brightness(1)";
	ruleR3.style.pointerEvents  = "none";
	if (!modalOpen){
		ruleR4.style.display = "block";
		blockHeight = false;
	}
}
if (typeof $ !== 'undefined') {
	$(window).on('shown.bs.modal', function(e) { 
		if (e.target.nodeName == "DIV" && e.target.className.includes("modal")){
			ruleR1.style.visibility = "hidden";
			ruleR4.style.display = "none";
			blockHeight = true;
			modalOpen = true;
		}
	});

	$(window).on('hidden.bs.modal', function(e) { 
		if (e.target.nodeName == "DIV" && e.target.className.includes("modal")){
			ruleR1.style.visibility = "visible";
			ruleR4.style.display = "block";
			blockHeight = false;
			modalOpen = false;
		}
	});
}