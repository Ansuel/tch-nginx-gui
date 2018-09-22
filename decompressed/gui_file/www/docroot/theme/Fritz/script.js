var elmArr = document.getElementsByClassName("content");


var styleEl = document.createElement('style'), styleSheet;
document.head.appendChild(styleEl);
styleSheet = styleEl.sheet;

styleSheet.insertRule('#cardrow > .span3 > .smallcard > .content { transform: translateY( 0px);}');
var ruleR1 = styleSheet.cssRules[0];

styleSheet.insertRule('#headerbox { marginLeft: 0;}');
var ruleR2 = styleSheet.cssRules[0];

styleSheet.insertRule('.apprise-overlay { opacity: 0 !important; pointer-events: none}');
var ruleR3 = styleSheet.cssRules[0];

styleSheet.insertRule('.row[style="z-index : 3;  position: relative;"] { transform: translateY( 0px);}');
var ruleR4 = styleSheet.cssRules[0];

styleSheet.insertRule('.span3 .content { filter: brightness(1);}');
var ruleR5 = styleSheet.cssRules[0];

styleSheet.insertRule('body{ height: 100%;}');
var ruleR6 = styleSheet.cssRules[0];

styleSheet.insertRule('#headertab {}');
var ruleR7 = styleSheet.cssRules[0];

function themescript() {
	if ( $("#cardrow").length ) {
	  $("#dynamic-content").append("<div id='headerbox'></div>");
	  var num=1;
	  $('.smallcard>.header').each(function() {
		  $(this).attr('id', "headerid"+num);
	  	$(this).detach().appendTo('#headerbox');
		num++;
	  });
	  num = 1;
	  $('.smallcard>.content').each(function() {
		  $(this).attr('id', "cardid"+num);
		  num++;
	  });
	  num = 1;
	  if (document.querySelector('#headerbox') != null){
      //window.onresize = updateHeight;
      //updateHeight();
      closeNav();
      document.querySelector('#headertab').addEventListener('click', function (e) {
  	  if (e.pageX != 0 && e.pageY !=0){
  		if (e.pageX  < 60 && window.innerWidth <= (50 * parseFloat(getComputedStyle(document.documentElement).fontSize))) {
  			openNav();
  		}
  	  }
      });
      document.querySelector('.apprise-overlay').addEventListener('click', function (e) {
        closeNav();
      });
  
      document.querySelector('#headerbox').addEventListener('click', function (e) {
  	  if (e.target.childNodes.length == 2 && e.target.childNodes[0].nodeName == "DIV" && e.target.childNodes[1].nodeName == "DIV")
  		e.target.childNodes[0].click();
  		
  	    closeNav();
      });
	  
      }
	  $(".content.card_bg").on("click", function() {
	  	var id = $(this).attr('id').replace(/cardid/, '');
	  	$("#headerid"+id)[0].click();
	  });
	}
}

$(document).ready(
    function() {
	 
    document.querySelector('.apprise-overlay').style.opacity = "";
    $(document).off("touchend", '[data-toggle\x3d"modal"]');
    $(document).off("touchend", ".smallcard");
	
	themescript();
	
	$("#swtichbuttom").on("switchcard", function() {
		setTimeout(themescript, 3000);
	});
});

var blockHeight = false;
var modalOpen = false;


function updateHeight(){
	if (!blockHeight){
		ruleR1.style.transform = 'translateY( 0px)';
		var maxheight = 0;
		var j;
		for (j = 0; j < elmArr.length; j++) { 
			height = elmArr[j].getBoundingClientRect().bottom;
			if (height > maxheight) {
				maxheight = height;
			} 
		}
		ruleR6.style.height = (maxheight+30) + "px";
		ruleR1.style.transform = 'translateY( -' + window.scrollY + 'px)';
	}
}

function openNav() {
	ruleR2.style.marginLeft = "0";
	ruleR2.style.overflow = "auto";
	ruleR3.style.zIndex = "1";
	ruleR7.style.zIndex = "0";
	ruleR3.style.opacity = "0.6";
	ruleR5.style.filter = "brightness(0.4)";
	ruleR3.style.pointerEvents  = "all";
	ruleR4.style.display = "none";
	ruleR5.style.display = "none";
	blockHeight = true;
	ruleR6.style = "100%";
}

function closeNav() {
	ruleR2.style.marginLeft  = "-15.5rem";
	ruleR2.style.overflow = "visible";
	ruleR3.style.zIndex = "2";
	ruleR7.style.zIndex = "6";
	ruleR3.style.opacity = "0";
	ruleR5.style.filter = "brightness(1)";
	ruleR3.style.pointerEvents  = "none";
	ruleR4.style.display = "block";
	if (!modalOpen){
		ruleR5.style.display = "block";
		blockHeight = false;
		updateHeight();
	}
}
if (typeof $ !== 'undefined') {
	$(window).on('shown.bs.modal', function(e) { 
		if (e.target.nodeName == "DIV"){
			ruleR5.style.display = "none";
			blockHeight = true;
			ruleR6.style = "100%";
			ruleR4.style.boxShadow = "none";
			modalOpen = true;
		}
	});

	$(window).on('hidden.bs.modal', function(e) { 
		if (e.target.nodeName == "DIV"){
			ruleR5.style.display = "block";
			blockHeight = false;
			updateHeight();
			modalOpen = false;
			ruleR4.style.boxShadow = "0 0.1875rem 0.375rem rgba(0,0,0,0.25)";
		}
	});
}