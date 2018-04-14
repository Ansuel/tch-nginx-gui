var elmArr = document.getElementsByClassName("content");

window.addEventListener('scroll', function(){
	var i;
	for (i = 0; i < elmArr.length; i++) { 
		elmArr[i].style.transform = "translateY( -" + window.scrollY + "px)";
	}
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
	document.getElementsByTagName("body")[0].style.height = (maxheight+30) + "px";
});

window.onresize = updateHeight;
window.onload = updateHeight;