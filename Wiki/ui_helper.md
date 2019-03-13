# Api List of /usr/lib/lua/web/ui_helper.lua

Here you can see all the element that you can put into the GUI

```lua
--- createAlertBlock
-- @function [parent=#ui_helper] createAlertBlock
-- @param #string value
-- @param #table attributes
-- @return #string for ngx.print
function M.createAlertBlock(value, attributes)

--- createHelpText
-- @function [parent=#ui_helper] createHelpText
-- @param #string value
-- @param #table attributes
-- @return #string for display by ngx.print
function M.createHelpText(value, attributes)

--- createSimpleInputHidden
-- Template
--		<input name="{Name}" class="" type="hidden" value="{Value}">
-- @function [parent=#ui_helper] createSimpleInputHidden
-- @param #string name
-- @param #string value
-- @param #table attributes
-- @param #string helpmsg
-- @return #table array for ngx.print
function  M.createSimpleInputHidden(name, value, attributes, helpmsg)

--- createSimpleInputText
-- Template
--		<input name="{Name}" class="span3 edit-input" type="text" value="{Value}">
--	 	<span class="help-inline"><strong>Alert Title ! </strong> Alert details and explanations</span>
-- @function [parent=#ui_helper] createSimpleInputText
-- @param #string name
-- @param #string value
-- @param #table attributes
-- @param #string helpmsg
-- @return #table array for ngx.print
function  M.createSimpleInputText(name, value, attributes, helpmsg)

--- createInputText
-- Template
-- <div class="control-group">
--	<label class="control-label">{Description}</label>
--	<div class="controls">
--		<input name="{Name}" class="span3 edit-input" type="text" value="{Value}">
--	    <span class="help-inline"><strong>Alert Title ! </strong> Alert details and explainations</span>
--	</div>
-- </div>
-- @function [parent=#ui_helper] createInputText
-- @param #string desc
-- @param #string name
-- @param #string value
-- @param #table attributes
-- @param #string helpmsg
-- @return #table array for ngx.print
function M.createInputText(desc, name, value, attributes, helpmsg)

--- createSimpleInputPassword
-- Template
--      <input name="{Name}" class="span3 edit-input" type="text" value="{Value}">
--      <span class="help-inline"><strong>Alert Title ! </strong> Alert details and explanations</span>
-- @function [parent=#ui_helper] createSimpleInputPassword
-- @param #string name
-- @param #string value
-- @param #table attributes
-- @param #string helpmsg
-- @return #table array for ngx.print
function  M.createSimpleInputPassword(name, value, attributes, helpmsg)

--- createInputPassword
-- Template
-- <div class="control-group">
--  <label class="control-label">{Description}</label>
--  <div class="controls">
--      <input name="{Name}" class="span3 edit-input" type="password" value="">
--      <span class="help-inline"><strong>Alert Title ! </strong> Alert details and explainations</span>
--  </div>
-- </div>
-- @function [parent=#ui_helper] createInputPassword
-- @param #string desc
-- @param #string name
-- @param #string value
-- @param #table attributes
-- @param #string helpmsg
-- @return #table array for ngx.print
function M.createInputPassword(desc, name, value, attributes, helpmsg)

--- createSimpleInputCheckbox
-- Template
--              if suffixname == true
--              <input name="{Name}" class="" type="checkbox" value="{Value}">  "{Name}"</input><br\>
--              else
--              <input name="{Name}" class="" type="checkbox" value="{Value}">
-- @function [parent=#ui_helper] createSimpleInputCheckbox
-- @param #string name
-- @param #string value
-- @param #table attributes
-- @param #boolean suffixname
-- @return #string string for ngx.print
function  M.createSimpleInputCheckbox(name, value, attributes, suffixname)

--- createInputCheckbox
-- Template
-- <div class="control-group">
--      <label class="control-label">{Description}</label>
--      <div class="controls">
--              <input name="{Name}" class="" type="checkbox" value="{Value}">
--      </div>
-- </div>
-- @function [parent=#ui_helper] createInputCheckbox
-- @param #string desc
-- @param #string name
-- @param #string value
-- @param #table attributes
-- @return #table array for ngx.print
function M.createInputCheckbox(desc, name, value, attributes)

--- createSimpleCheckboxSwitch
-- Template
--              <input name="{Name}" class="" type="checkbox" value="{Value}">  "{Name}"</input><br\>
--              else
--              <input name="{Name}" class="" type="checkbox" value="{Value}">
-- @function [parent=#ui_helper] createSimpleCheckboxSwitch
-- @param #string name
-- @param #string value
-- @param #table attributes
-- @return #string string for ngx.print
function  M.createSimpleCheckboxSwitch(name, value, attributes)

--- createCheckboxSwitch
-- Template
-- <div class="control-group">
--      <label class="control-label">{Description}</label>
--      <div class="controls">
--              <input name="{Name}" class="" type="checkbox" value="{Value}">
--      </div>
-- </div>
-- @function [parent=#ui_helper] createCheckboxSwitch
-- @param #string desc
-- @param #string name
-- @param #string value
-- @param #table attributes
-- @return #table array for ngx.print
function M.createCheckboxSwitch(desc, name, value, attributes)

--- createSimpleChecboxGroup
-- Template
--           <label class="checkbox">
--           <input name="{Name}" type="checkbox" value="{Value}" checked>  {Name}
--           </label>
--           ...
-- @function [parent=#ui_helper] createSimpleCheckboxGroup
function M.createSimpleCheckboxGroup(name, values, checked, attributes)

--- createCheckboxGroup
-- Template
-- <div class="control-group">
--      <label class="control-label">{Description}</label>
--      <div class="controls">
--           <label class="checkbox">
--           <input name="{Name}" type="checkbox" value="{Value}" checked>  {Name}
--           </label>
--           ...
--           <span class="help-inline"><strong>Alert Title ! </strong> Alert details and explainations</span>
--      </div>
-- </div>
-- @function [parent=#ui_helper] createCheckboxGroup
-- @param #string desc
-- @param #table namevaluemap
-- @param #table attributes
-- @return #table array for ngx.print
function M.createCheckboxGroup(desc, name, values, checked, attributes, helpmsg)

---createLabel
--	Template
-- 			  <div class="control-group">
--			   	 <label class="control-label">{Description}</label>
--			   	 <div class="controls">
--				   	<span class="span2 simple-desc">{Value}</span>
--	 		  		<span class="help-inline"><strong>Alert Title ! </strong> Alert details and explainations</span>
--			   	 </div>
--			  </div>
-- @function [parent=#ui_helper] createLabel
-- @param #string desc: text used for the label description
-- @param #string value: text used for the label values
-- @param #table attributes: maps additional attributes to apply
-- @param #string helpmsg
-- @return #string
function M.createLabel(desc, value, attributes, helpmsg)

---createSimpleSwitch
-- Template
--			 			<div class="switch {switchOn} pull-left">
--			 				<div class="switcher {switcherOn}"></div>
--				 			<input type="hidden" name="{name}" value="{value}">
--		 				</div>
--	 		  		    <span class="help-inline"><strong>Alert Title ! </strong> Alert details and explainations</span>
-- @function [parent=#ui_helper] createSimpleSwitch
-- @param #string name
-- @param #string value
-- @param #table attributes
-- @param #string helpmsg
-- @return #table array for ngx.print
function M.createSimpleSwitch(name, value, attributes, helpmsg)

---createSwitch
-- Template
--				<div class="control-group">
--		 			<label class="control-label">Enabled</label>
--		 			<div class="controls">
--			 			<div id="personal-wireless-switch" class="switch {switchOn} pull-left">
--			 				<div class="switcher {switcherOn}"></div>
--				 			<input type="hidden" name="{name}" value="{value}">
--		 				</div>
--	 		  			<span class="help-inline"><strong>Alert Title ! </strong> Alert details and explainations</span>
--					</div>
--				</div>
-- @function [parent=#ui_helper] createSwitch
-- @param #string desc
-- @param #string name
-- @param #string value
-- @param #table attributes
-- @param #string helpmsg
-- @return #table
function M.createSwitch(desc, name, value, attributes, helpmsg)

---createSimpleInputSelect
-- Template
--	 		  		<select name="{Name}" class="span3">
--						<option value="{value[i]" {selected} >{text[i]}</option>
--	 		  		</select>
--	 		  		<span class="help-inline"><strong>Alert Title ! </strong> Alert details and explainations</span>
--
-- @function [parent=#ui_helper] createSimpleInputSelect
-- @param #string name
-- @param #table values
-- @param #string current
-- @param #table attributes
-- @param #string helpmsg
-- @return #table array for ngx.print
function M.createSimpleInputSelect(name, values, current, attributes, helpmsg)

---createInputSelect
-- Template
--	 		  <div class="control-group">
--	 		   	<label class="control-label">{Description}</label>
--	 		   	<div class="controls">
--	 		  		<select name="{Name}" class="span3">
--						<option value="{value[i]" {selected} >{text[i]}</option>
--	 		  		</select>
--	 		  		<span class="help-inline"><strong>Alert Title ! </strong> Alert details and explainations</span>
--	 		   	</div>
--	 		  </div>
-- @function [parent=#ui_helper] createInputSelect
-- @param #string desc
-- @param #string name
-- @param #table values
-- @param #string current
-- @param #table attributes
-- @param #string helpmsg
-- @return #table
function M.createInputSelect(desc, name, values, current, attributes, helpmsg)

---createSimpleInputRadio
-- Template
--              <label class="radio">
--                  <input type="radio" name="{Name} value="{value[i]}" {selected} >{text[i]}
--              </label>
--
-- @function [parent=#ui_helper] createSimpleInputRadio
-- @param #string name
-- @param #table values
-- @param #string current
-- @param #table attributes
-- @return #table array for ngx.print
function M.createSimpleInputRadio(name, value, current, attributes)

---createInputRadio
-- Template
--            <div class="control-group">
--              <label class="control-label">{Description}</label>
--              <div class="controls">
--              <label class="radio">
--                  <input type="radio" name="{Name} value="{value[i]}" {selected} >{text[i]}
--              </label>
--              (...)
--              <span class="help-inline"><strong>Alert Title ! </strong> Alert details and explainations</span>
--            </div>
--            </div>
-- @function [parent=#ui_helper] createInputRadio
-- @param #string desc
-- @param #string name
-- @param #table values
-- @param #string current
-- @param #table attributes
-- @param #string helpmsg
-- @return #table
function M.createInputRadio(desc, name, values, current, attributes, helpmsg)

--- Create a button control without label
--  Template:
--      <div class="btn"><i class="{icon}"></i>  {label}</div>
-- @function [parent=#ui_helper] createSimpleButton
--    @param #string buttontext
--    @param #string icon
--    @param #table attributes
--    @return #string
function M.createSimpleButton(buttontext, icon, attributes)

--- Create a button control
--  Template:
--  <div class="control-group">
--    <label class="control-label">{Description}</label>
--    <div class="controls">
--      <div class="btn"><i class="{icon}"></i>  {label}</div>
--    </div>
--  </div>
-- @function [parent=#ui_helper] createButton
--  @param #string desc
--  @param #string buttontext
--  @param #string icon
--  @param #table attributes
--  @return #table
function M.createButton(desc, buttontext, icon, attributes)

--- Create a text input + button control
--  Template:
--  <div class="control-group">
--    <label class="control-label">{Description}</label>
--    <div class="controls">
--      <div class="btn"><i class="{icon}"></i>  {label}</div>
--    </div>
--  </div>
-- @function [parent=#ui_helper] createInputTextWithButton
--  @param #string desc
--  @param #string name
--  @param #boolean value
--  @param #string buttontext
--  @param #string icon
--  @param #table attributes
--  @param #table helpmsg
--  @return #table
function M.createInputTextWithButton(desc, name, value, buttontext, icon, attributes, helpmsg)

--- Create a table
-- Template
-- <table class="table table-striped">
--              <thead>
--                <tr>
--                  <th>{header[1]}</th>
--                  <th>{header[2]}</th>
--                  <th>{header[3]}</th>
--                  <th>{header[4]}</th>
--                  (...)
--                </tr>
--              </thead>
--              <tbody>
--                <tr>
--                  <td>{data[1][uciname[1])}</td>
--                  <td>{data[1][uciname[2])}</td>
--                  <td>{data[1][uciname[3])}</td>
--                  <td>{data[1][uciname[4])}</td>
--                  (...)
--                </tr>
--                (...)
--              </tbody>
--            </table>
-- @function [parent=#ui_helper] createTable
-- @param #table columns
-- @param #table data array
-- @param #table options
-- @param #table attributes
-- @param #table helpmsg
-- @return #table
function M.createTable(columns, data, options, attributes, helpmsg)

--- createSimpleLight
--- Template
--			 <span class="simple-desc">
--			  <div class="light green"></div>This is a status
--			 </span>
-- @function [parent=#ui_helper] createSimpleLight
-- @param #boolean value
-- @param #string desc
-- @param #table attributes
-- @return #string for ngx.print
function M.createSimpleLight(value, text, attributes, icon_type)

---createLight
--- Template
-- <div class="control-group">
--		   <label class="control-label">Broadband status</label>
--		   <div class="controls">
--			 <span class="simple-desc">
--			  <div class="light green"></div>This is a status
--			 </span>
--		   </div>
--		 </div>
-- @function [parent=#ui_helper] createLight
-- @param #string label
-- @param #boolean value
-- @param #string desc
-- @param #table attributes
function M.createLight(desc, value, text, attributes)

---createSimpleSliderSelect
--- Template
--    <div class="noUiSlider span2 no-margin horizontal"></div>
--    <div class="noUiSlider-text simple-desc">25 %</div>
--    <span class="help-inline"><strong>Alert Title ! </strong> Alert details and explainations</span>
-- @function [parent=#ui_helper] createSimpleSliderSelect
-- @param #string name
-- @param #table values
-- @param #string current
-- @param #table attributes
-- @param #string helpmsg
-- @return #table array for ngx.print
function M.createSimpleSliderSelect(name, values, current, attributes, helpmsg)

---createSliderSelect
--- Template
-- <div class="control-group">
--   <label class="control-label trigger-slider">Test Switch</label>
--   <div class="controls">
--    <div class="noUiSlider span2 no-margin horizontal"></div>
--    <div class="noUiSlider-text simple-desc">25 %</div>
--    <span class="help-inline"><strong>Alert Title ! </strong> Alert details and explainations</span>
--    </div>
--  </div>
-- @function [parent=#ui_helper] createSliderSelect
-- @param #string desc
-- @param #string name
-- @param #tabel values
-- @param #string current
-- @param #table attributes
-- @param #string helpmsg
-- @return #table for ngx.print
function M.createSliderSelect(desc, name, values, current, attributes, helpmsg)

---createModalTabs
---Template
--<div class="modal-tab" id="modal-loadlp" load-target="modals/mmpbx-service-modal.lp">Service</div>
-- or
-- <div class="modal-tab">Service</div>
--
-- <ul class="nav nav-tabs">
--  <li><div data-remote="url" ...></div></li>
--  <li><div data-remote="url" ...></div></li>
--  <li><div data-remote="url" ...></div></li>
-- </ul>
-- @function [parent=#ui_helper]   createModalTabs
-- @param #table tabs[.][desc]     name for tab
-- 		 tabs[.][id]       optional. if tabs[.][id] == "modal-loadlp", this tab could used be to load a modal page
-- 		 tabs[.][target]   optional. path for the modal page want to be loaded
-- @return #table for ngx.print
function M.createModalTabs (tabs)

---createHeader
--- Template
-- <div class="modal-header">
--  <div class="row-fluid">
--    <div class="span11"><h2 class="span4">title</h2>
--    <span class="modal-action">
--      <span class="modal-action-advanced hide"><i class="icon-minus-sign"></i> hide advanced</span>
--      <span class="modal-action"><i class="icon-plus-sign"></i> show advanced</span>
--    </span>
--    </div>
--    <div class="span1"><a href="#" class="button btn-primary btn-close" data-dismiss="modal"><i class="icon-remove"></i></a></div>
--  </div>
--</div>
-- @function [parent=#ui_helper] createHeader
-- @param #string  name        the name to be displayed
-- @param #boolean hasAdvanced if the header should contain the show advanced/hide advanced text
-- @param #boolean hasRefresh  if the header should contain the refresh text (will trigger a GET on the modal)
-- @param #number autorefresh  if defined, indicates the time in second between refreshes (will trigger
--          a POST on the modal with a action=REFRESH as the parameter)
-- @param #table helpLink      if defined, the header contains the help text which links to the help page indicated by link
--          typical use: { data-toggle="modal", data-remote = "/help/index.lp"} or { href="/help/index.lp" }
  -- @return #table for ngx.print
function M.createHeader(name, hasAdvanced, hasRefresh, autorefresh, helpLink)

---createFooter
--- Template
-- <div class="modal-footer">
--  <div id="modal-no-change">
--    <div class="btn btn-primary btn-large" data-dismiss="modal">Close</div>
--  </div>
--  <div id="modal-changes" class="hide">
--    <div class="btn btn-large" data-dismiss="modal">Cancel</div>
--    <div id="save-config" class="btn btn-primary btn-large" data-dismiss="modal">Save and Close</div>
--  </div>
--</div>
-- @function [parent=#ui_helper] createFooter
-- @return #string for ngx.print
function M.createFooter()

---createCardHeader
--- Template
--   <div class="header">
--      <div class="header-title pull-left" data-toggle="modal" data-remote="modals/device-modal.lp" data-id="device-modal"><p>Devices</p></div>
--      <div class="switch"><div class="switcher"></div><input value="0" type="hidden" name="uci_wan_auto"></div>
--      <div class="settings" data-toggle="modal" data-remote="modals/device-modal.lp" data-id="device-modal"><i class="icon-cogs"></i></div>
--    </div>
-- @function [parent=#ui_helper] createCardHeader
-- @param #string title
-- @param #string modalPath URL to the modal, if nil, then no modal will open and no configure icon displayed
-- @param #string switchName if nil, then no switch will be added
-- @param #string switchValue
-- @return #string for ngx.print
function M.createCardHeader(title, modalPath, switchName, switchValue, attributes, mobile)

---createCardHeaderNoIcon
--- Template
--   <div class="header">
--      <div class="header-title pull-left" data-toggle="modal" data-remote="modals/device-modal.lp" data-id="device-modal"><p>Devices</p></div>
--    </div>
-- @function [parent=#ui_helper] createCardHeaderNoIcon
-- @param #string title
-- @param #string modalPath URL to the modal, if nil, then no modal will open and no configure icon displayed
-- @return #string for ngx.print
function M.createCardHeaderNoIcon(title, modalPath, switchName, switchValue, attributes)

---createSwitchPort
--- Template
--    <div class="socket socket-form">
--      <ul><li></li><li></li><li></li><li></li><li></li><li></li><li></li><li></li></ul>
--      <p>1</p>
--      <div class="socket-light off align-right" style="opacity:.5;"></div>
--      <% if  eth0State == "up" then
--      <div class="socket-light green align-right"></div>
--      <div class="socket-light green align-left"></div>
--      <% end %>
--      <div class="socket-light off align-left" style="opacity:.5;"></div>
--    </div>
-- @function [parent=#ui_helper] createSwitchPort
-- @param #string num port number
-- @param #string state
-- @param #string speed
-- @return #table for ngx.print
function M.createSwitchPort(num, state, speed, attributes)

---createLanguageSelect
-- @function [parent=#ui_helper] createLanguageSelect
-- @param #string textdomain the page's textdomain
-- @param #string current the current language
-- @return #table for ngx.print
function M.createLanguageSelect(textdomain, current, attributes)

---createBitLoadHistogram
-- @function [parent=#ui_helper] createBitLoadHistogram
-- @param #string data comma separated data feed
-- @return #table
function M.createBitLoadHistogram(datastring)

---createMessages
-- @function [parent=#ui_helper] createMessages
-- @param messages array of messages with for each message, level and content
-- @return #table for ngx.print
function M.createMessages(messages)

--- Create a input select + button control
--  Template:
--	 		  <div class="control-group">
--	 		   	<label class="control-label">{Description}</label>
--	 		   	<div class="controls">
--	 		  		<select name="{Name}" class="span3">
--						<option value="{value[i]" {selected} >{text[i]}</option>
--	 		  		</select>
--	 		  		<span class="help-inline"><strong>Alert Title ! </strong> Alert details and explainations</span>
--    			</div>
--   			 <div class="controls">
--   				   <div class="btn"><i class="{icon}"></i>  {label}</div>
--	 		   	</div>
--	 		  </div>
-- @function [parent=#ui_helper] createInputSelectWithButton
-- @param #string desc
-- @param #string name
-- @param #table values
-- @param #string current
-- @param #string buttontext
-- @param #string icon
-- @param #table attributes
-- @param #string helpmsg
-- @return #table
function M.createInputSelectWithButton(desc, name, values, current, buttontext, icon, attributes, helpmsg)

---createLabelWithButton
--	Template
-- 			  <div class="control-group">
--			   	 <label class="control-label">{Description}</label>
--			   	 <div class="controls">
--				   	<span class="span2 simple-desc">{Value}</span>
--   			 <div class="controls">
--   				   <div class="btn"><i class="{icon}"></i>  {label}</div>
--	 		   	</div>
--	 		  		<span class="help-inline"><strong>Alert Title ! </strong> Alert details and explainations</span>
--			   	 </div>
--			  </div>
-- @function [parent=#ui_helper] createLabelWithButton
-- @param #string desc: text used for the label description
-- @param #string value: text used for the label values
-- @param #string buttontext
-- @param #string icon
-- @param #table attributes: maps additional attributes to apply
-- @param #string helpmsg
-- @return #string
function M.createLabelWithButton(desc, value, buttontext, icon, attributes, helpmsg)
```
