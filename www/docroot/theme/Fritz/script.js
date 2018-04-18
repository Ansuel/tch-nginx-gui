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

window.addEventListener('scroll', function(){
	ruleR1.style.transform = 'translateY( -' + window.scrollY + 'px)';
});

window.onload = function(){
  
  document.querySelector('.apprise-overlay').style.opacity = "";
  
  if (document.querySelector('.row[style="z-index : 2;  position: relative;"]') != null){
    window.onresize = updateHeight;
    updateHeight();
    closeNav();
    document.querySelector('.header.span12').addEventListener('click', function (e) {
      if (e.pageX  < 60) {
        openNav();
      }
    });
    document.querySelector('.apprise-overlay').addEventListener('click', function (e) {
      closeNav();
    });
    document.querySelector('.row[style="z-index : 2;  position: relative;"]').addEventListener('click', function (e) {
	  if (e.target.childNodes.length == 2)
        e.target.childNodes[0].click();
	  closeNav();
    });
  }
}

function updateHeight(){
	var maxheight = 0;
	var j;
	for (j = 0; j < elmArr.length; j++) { 
		height = elmArr[j].getBoundingClientRect().bottom;
		if (height > maxheight) {
			maxheight = height;
		} 
	}
	document.body.style.height = (maxheight+30) + "px";
}

function openNav() {
	ruleR2.style.marginLeft  = "0";
	ruleR3.style.opacity = "0.6";
	ruleR3.style.pointerEvents  = "all";
}

function closeNav() {
	ruleR2.style.marginLeft  = "-15.5rem";
	ruleR3.style.opacity = "0";
	ruleR3.style.pointerEvents  = "none";
}
