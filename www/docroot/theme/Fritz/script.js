var elmArr = document.getElementsByClassName("content");


var styleEl = document.createElement('style'), styleSheet;
document.head.appendChild(styleEl);
styleSheet = styleEl.sheet;

styleSheet.insertRule('.content { transform: translateY( 0px);}');
var ruleR1 = styleSheet.cssRules[0];
styleSheet.insertRule('.row[style="z-index : 2;  position: relative;"] { width: 15.5rem;}');
var ruleR2 = styleSheet.cssRules[0];
styleSheet.insertRule('.apprise-overlay { opacity: 0 !important}');
var ruleR3 = styleSheet.cssRules[0];

window.addEventListener('scroll', function(){
	ruleR1.style.transform = 'translateY( -' + window.scrollY + 'px)';
});

var updateHeight = (function(){
	var maxheight = 0;
	var j;
	for (j = 0; j < elmArr.length; j++) { 
		height = elmArr[j].getBoundingClientRect().bottom;
		if (height > maxheight) {
			maxheight = height;
		} 
	}
	document.body.style.height = (maxheight+30) + "px";
});

window.onresize = updateHeight;
window.onload = function(){
  updateHeight;
  closeNav();
  document.querySelector('.header.span12').addEventListener('click', function (e) {
    if (e.pageX  < 60) {
        openNav();
    }
  });
  
  document.querySelector('.apprise-overlay').style.opacity = "";
  document.querySelector('.apprise-overlay').addEventListener('click', function (e) {
    closeNav();
  });
  document.querySelector('.row[style="z-index : 2;  position: relative;"]').addEventListener('click', function (e) {
    closeNav();
  });
}

function openNav() {
	ruleR2.style.width  = "15.5rem";
	ruleR3.style.opacity = "0.4";
	ruleR3.style.pointerEvents  = "all";
}

function closeNav() {
	ruleR2.style.width  = "0";
	ruleR3.style.opacity = "0";
	ruleR3.style.pointerEvents  = "none";
}
