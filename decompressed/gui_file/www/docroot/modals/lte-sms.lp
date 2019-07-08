--pretranslated: do not change this file
 
local ngx = ngx

-- Enable localization
gettext.textdomain('webui-mobiled')

local utils = require("web.lte-utils")
local ui_helper = require("web.ui_helper")

local params = utils.get_params()
  ngx.print('\
\
<style>\
	.message-text {\
		word-wrap: break-word;\
	}\
	.uneven {\
		background-color: #eee;\
	}\
	.message{\
		border-bottom: 1px solid #aaa;\
		min-height: 50px;\
	}\
	.message-title {\
		font-weight: bold;\
		border-bottom: 2px solid #888;\
	}\
	.unread {\
		font-weight: bold;\
	}\
	.read-icon, .unread-icon {\
		background-size: 30px 30px;\
		background-repeat: no-repeat;\
		cursor: pointer;\
		cursor: hand;\
		margin-top: 5px;\
		margin-left: 5px;\
		height: 30px;\
		width: 30px;\
	}\
	.read-icon {\
		background-image: url(\'img/message-read.png\');\
	}\
	.unread-icon {\
		background-image: url(\'img/message-unread.png\');\
		background-size: 30px 25px;\
	}\
	.bar {\
		border-radius: 0;\
		border: 0;\
	}\
	.nomessages {\
		color: #999;\
		text-align: center;\
	}\
	#storageused .progress {\
		width: 280px;\
		margin-top: 10px;\
	}\
</style>\
<script language="javascript" type="text/javascript" src="js/bootstrap-progressbar-min.js"></script>\
\
');  ngx.print( ui_helper.createHeader(params.modal_title, true, true, nil)); ngx.print('\
<div class="modal-body update" id="lte-sms-body">\
	<form class="form-horizontal" method="post" action="modals/lte-sms.lp">\
		');  
			local lp = require("web.lp")
			lp.setpath("/www/snippets/")
			lp.include("tabs-mobiled.lp")
		  ngx.print('\
\
		<div data-bind="visible: messages().length > 0">\
			<div class="row-fluid message-title hidden-phone">\
				<div class="span1">');  ngx.print( T"Status"); ngx.print('</div>\
				<div class="span2">');  ngx.print( T"From"); ngx.print('</div>\
				<div class="span6">');  ngx.print( T"Message"); ngx.print('</div>\
				<div class="span2">');  ngx.print( T"Received"); ngx.print('</div>\
				<div class="span1"></div>\
			</div>\
			<div data-bind="foreach: messages">\
				<div class="row-fluid message" data-bind="css: { \'unread\': ($data.status == \'unread\'), \'uneven\': ($index() % 2 != 0) }">\
					<div class="span1" data-bind="click: $parent.setMessageStatus"><div data-bind="css: { \'unread-icon\': ($data.status == \'unread\'), \'read-icon\': ($data.status == \'read\') }"></div></div>\
					<div class="span2" data-bind="text: number"></div>\
					<div class="span6 message-text" data-bind="text: text"></div>\
					<div class="span2" data-bind="text: date"></div>\
					<div class="span1"><a href="#" data-bind="click: $parent.removeMessage">');  ngx.print( T"Remove"); ngx.print('</a></div>\
				</div>\
			</div>\
		</div>\
		<div data-bind="visible: messages().length == 0">\
			<div class="row-fluid">\
				<div class="span12">\
					<h3 class="nomessages">');  ngx.print( T"You currently don't have any messages" ); ngx.print('</h3>\
				</div>\
			</div>\
		</div>\
		<div data-bind="visible: messages().length > 0" class="row-fluid messagestatus">\
			<div class="span5">\
				<h5 style="float: left; margin-right: 10px;">');  ngx.print( T"Storage used" ); ngx.print('</h5><span id="storageused" class="progress progress-striped"></span>\
			</div>\
			<div class="span2"><h5 data-bind="text: readMessagesText"></h5></div>\
			<div class="span2"><h5 data-bind="text: unreadMessagesText"></h5></div>\
			<div class="span3"></div>\
		</div>\
	</form>\
</div>\
');  ngx.print(ui_helper.createFooter())   ngx.print('\
<script>\
	var id = window.setTimeout(function() {}, 0);\
	while (id--) {\
		window.clearTimeout(id);\
	}\
\
	function sortResults(obj, prop, asc) {\
		obj = obj.sort(function(a, b) {\
			if (asc) { return (a[prop] > b[prop]) ? 1 : ((a[prop] < b[prop]) ? -1 : 0); }\
			else { return (b[prop] > a[prop]) ? 1 : ((b[prop] < a[prop]) ? -1 : 0); }\
		});\
		return obj;\
	}\
\
	var SmsView = function () {\
		var self = this;\
		this.messages = ko.observableArray([]);\
		this.readMessages = ko.observable(0);\
		this.unreadMessages = ko.observable(0);\
		this.readMessagesText = ko.computed(function() {\
			var text="');  ngx.print( T"Read messages" ); ngx.print('";\
			return text+\': \'+this.readMessages();\
		}, this);\
		this.unreadMessagesText = ko.computed(function() {\
			var text="');  ngx.print( T"Unread messages" ); ngx.print('";\
			return text+\': \'+this.unreadMessages();\
		}, this);\
		this.setMessageStatus = function() {\
			var action = \'read\';\
			if(this.status == \'read\') {\
				action=\'unread\';\
			}\
			var params = [ { name: \'id\', value: this.id },\
						   { name: \'action\', value: action },\
						   tch.elementCSRFtoken() ];\
			self.update(params);\
		};\
		this.removeMessage = function() {\
			var params = [ { name: \'id\', value: this.id },\
						   { name: \'action\', value: \'delete\' },\
						   tch.elementCSRFtoken() ];\
			self.update(params);\
		};\
		this.update = function(params) {\
			$.post("/ajax/sms.lua", params, function(data) {\
				// First sort by ID in order to keep a consistent data set.\
				if(data.messages != undefined) {\
					data.messages = sortResults(data.messages, \'id\', false);\
					data.messages = sortResults(data.messages, \'date\', false);\
					self.messages(data.messages);\
				}\
				if(data.info != undefined) {\
					var percent = 0;\
					data.total_messages = parseInt(data.info.total_messages);\
					data.max_message = parseInt(data.info.max_message);\
					self.unreadMessages(parseInt(data.info.unread_messages));\
					self.readMessages(parseInt(data.info.read_messages));\
					if(!isNaN(data.info.total_messages) && !isNaN(data.info.max_messages)) {\
						percent = Math.round(((data.info.total_messages/data.info.max_messages)*100));\
					}\
					$(\'#storageused\').progressbar(\'setPosition\', percent);\
					$(\'#storageused\').prop(\'title\', percent+\'%\');\
				}\
			}, "json");\
		};\
		this.createStorageInfo = function() {\
			$(\'#storageused\').progressbar({\
				warningMarker: 60,\
				dangerMarker: 80,\
				maximum: 100\
			});\
		};\
		this.refresh = function() {\
			self.update([tch.elementCSRFtoken()]);\
		};\
		self.createStorageInfo();\
		setInterval(self.refresh, (60*1000));\
		self.refresh();\
	};\
\
	var smsView = new SmsView();\
	ko.applyBindings(smsView, document.getElementById(\'lte-sms-body\'));\
</script>\
'); 