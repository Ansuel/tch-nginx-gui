var elmArr = document.getElementsByClassName("content");


var styleEl = document.createElement('style'), styleSheet;
document.head.appendChild(styleEl);
styleSheet = styleEl.sheet;

styleSheet.insertRule('.row .smallcard .content { transform: translateY( 0px);}');
var ruleR1 = styleSheet.cssRules[0];

styleSheet.insertRule('.row[style="z-index : 2;  position: relative;"] { marginLeft: 0;}');
var ruleR2 = styleSheet.cssRules[0];

styleSheet.insertRule('.apprise-overlay { opacity: 0 !important; pointer-events: none}');
var ruleR3 = styleSheet.cssRules[0];

styleSheet.insertRule('.row[style="z-index : 3;  position: relative;"] { transform: translateY( 0px);}');
var ruleR4 = styleSheet.cssRules[0];

styleSheet.insertRule('.span3 .content { filter: brightness(1);}');
var ruleR5 = styleSheet.cssRules[0];

styleSheet.insertRule('body{ height: 100%;}');
var ruleR6 = styleSheet.cssRules[0];

window.addEventListener('scroll', function(){
	ruleR1.style.transform = 'translateY( -' + window.scrollY + 'px)';
});

$(document).ready(
  function() {
    document.querySelector('.apprise-overlay').style.opacity = "";
    $(document).off("touchend", '[data-toggle\x3d"modal"]');
    $(document).off("touchend", ".smallcard");
  	
    if (document.querySelector('.row[style="z-index : 2;  position: relative;"]') != null){
      window.onresize = updateHeight;
      updateHeight();
      closeNav();
      document.querySelector('.header.span12').addEventListener('click', function (e) {
  	  if (e.pageX != 0 && e.pageY !=0){
  		if (e.pageX  < 60 && window.innerWidth <= (50 * parseFloat(getComputedStyle(document.documentElement).fontSize))) {
  			openNav();
  		}
  	  }
      });
      document.querySelector('.apprise-overlay').addEventListener('click', function (e) {
        closeNav();
      });
  
      document.querySelector('.row[style="z-index : 2;  position: relative;"]').addEventListener('click', function (e) {
  	  if (e.target.childNodes.length == 2 && e.target.childNodes[0].nodeName == "DIV" && e.target.childNodes[1].nodeName == "DIV")
  		e.target.childNodes[0].click();
  		
  	  closeNav();
      });
    }
  }
)

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