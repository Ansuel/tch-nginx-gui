# Various Functions List

Here you see some Functions that will make your life easier

>**Note:** Non complete Function list

### /usr/lib/lua/tch/inet.lua

```lua
function M.isValidIPv4(ip)
--- Check if the given address is a valid IPv4 address.
-- @tparam string ip The IP address string to test.
-- @treturn boolean True if it is a valid IPv4 address.
-- @error Error message.

function M.isValidIPv6(ip)
--- Check if the given address is a valid IPv6 address.
-- @tparam string ip The IP address string to test.
-- @treturn boolean True if it is a valid IPv6 address.
-- @error Error message.

function M.isValidIP(ip)
--- Check if the given address is a valid IP address.
-- @tparam string ip The IP address to test.
-- @treturn string "IPv4" if `ip` is a valid IPv4 address or "IPv6" if
--   `ip` is a valid IPv6 address.
-- @error Error message.

function M.hexIPv4ToString(hexip)
--- Convert the given hexadecimal IPv4 address string to
-- dotted decimal notation. The string may have leading or
-- trailing whitespace.
-- @tparam string hexip The hexadecimal IPv4 address to be converted.
-- @treturn string The IPv4 address in dotted decimal notation.
-- @error Error message.

function M.isValidGlobalUnicastv6Address(ipv6addr)
--- Check whether the given IPv6 address is a valid global unicast address.
-- Global unicast address has the prefix 2000::/3 (see
-- [IANA](https://www.iana.org/assignments/ipv6-unicast-address-assignments/ipv6-unicast-address-assignments.xhtml))
-- @string ipv6addr The IPv6 address to be checked.
-- @treturn boolean True if `ipv6addr` is valid global unicast address.
-- @error Error Message.

function M.netmaskToNumber(num)
--- Convert a number of bits to a number representing the netmask
-- In particular it will check that the input netmask falls in the range of 1 to 32
-- @tnumber num the subnet value as number
-- @treturn number representing the netmask or nil
```

### /usr/lib/lua/transformer/shared/cmdhelper.lua

```lua
function M.parseCmd(cmdlookup, keys, xdslInfo)
--- Function executes the specified command and parses its output based on lookup and keys
-- @param cmdlookup   A table of the form {command="command to execute",lookup={parsing rules}}
--                    command  A string specifying the command to execute.
--                    lookup   A table specifying the rules to parse the output of command.
--                             This table contains entries of the form
--                             ["keyname"]={pat="regex"[,act=postprocessingfunction(string)][,subkeys={"subkey1","subkey2"}]}
--                             Each entry represents a parsing rule for a particular key "keyname". These rules are records
--                             containing the following members:
--
--                             pat                Contains a pattern that will extract the corresponding value from the command output.
--                             act (optional)     Is a pointer to a function which applies post-processing on the value extracted by the pat
--                             subkeys (optional) Is needed if there are multiple values extracted from the same line of output.
--                                                These values are then stored in values["keyname"][subkeys[i]]
--
-- @param keys    An array of keynames to be retrieved from the output
-- @param xdslInfo A table to return the extracted values for each keyname in keys
-- examples in xdslctl.lua
```

### /usr/lib/lua/transformer/shared/reboot_helper.lua

```lua
function M.getRebootOptions(option, default)
  return getUciValue(option, default)
end

function M.setRebootOptions(option, value)
  if not sectionExists() then
    createScheduledRebootSec()
  end
  if option == "time" and not validateTime(value) then
    return nil, "Invalid value or format"
  end
  setUciValue(option, value)
  return true
end

function M.uci_system_commit()
  if configChanged then
    uciHelper.commit(sysBinding)
    configChanged = false
  end
end

function M.uci_system_revert()
  if configChanged then
    uciHelper.revert(sysBinding)
    configChanged = false
  end
end
```

### /www/lua/wizard.lua

```lua
function handleQuery(mapParams, mapValidation)
--- Method to store the POST parameters sent by the UI in UCI (SAVE action)
-- @function [parent=#post_helper] handleQuery
-- @param #table mapParams key/string dictionary containing for each form control's name, the associated path
--                      this should be an exact path since we're going to write
--                      if you need to READ partial paths, please do so after this function has run
-- @param #table mapValidation key/function dictionary containing for each form control's name, the associated
--                      validation function. The validation function should return (err, msg). If err
--                      is nil, then msg should contain an error message, otherwise err should be true
-- @return #table,#table it returns a dictionary containing for each input name, the retrieved value from UCI
--          and another dictionary containing for each failed validation the help message
```

### /usr/lib/lua/transformer/shared/fon_helper.lua

```lua
function M.validateStringIsDomainName(value)
--- To Validate whether the received 'value' has the syntax of a domain name [RFC 1123]
-- @function validateStringIsDomainName
-- @param #string value consists of domain names
-- @return #boolean true/nil true when all the validations are correct with respect to domain name check and nil when domain name check is violated

function M.getAp(intf)
--- function to get the corresponding accesspoint value for the given interface
-- @param #string intf contains the interface name
-- @return #string accpoint contains the accesspoint value for the corresponding interface passed

local function getHotspotWiFiInterfaces()
--- function to get all the Gre Hotspot Wifi Interfaces
-- @return #table interfaces contains all the Gre Hotspot Wifi Interfaces

local function getSSIDName(ifname, device)
--- function to get the corresponding SSID name for the given interface
-- @param #string ifname contains the interface name
-- @param #string device contains the device information i.e 2G or 5G
-- @return #string ssidName contains the corresponding SSID name for the given interface

function M.getIfnames()
--- function to get all the Gre Hotspot Wifi Interfaces
-- @return #table ifnames contains all the Gre Hotspot Wifi Interfaces mapped to ssid Names

function M.getAllAp()
--- function to get all the accesspoints that corresponds to Gre Hotspot Wifi Interfaces
-- @return #table accpoints contains all the accesspoints that corresponds to Gre Hotspot Wifi Interfaces

function M.getPrivateAp()
--- function to get all the accesspoints and Interface names that correspond to Private WiFi Interfaces
-- @return #table privateAPs contains all the accesspoints that corresponds to Private Wifi Interfaces
-- @return #table privateIface contains all the interface names that corresponds to Private Wifi Interfaces
```

### /www/lua/logdownload_helper.lua

```lua
function M.export_log(export_way_assign)
```

### /www/lua/parental_helper.lua

```lua
function M.mac_to_hostname(mac)

function M.compareTodRule(oldTODRules, newTODRule)
-- function that can be used to compare and find whether the rule is duplicate or overlap
-- @param #oldTODRules have the rules list of existing tod
-- @param #newTODRule have the new rule which is going to be add in tod
-- @return #boolean or nil+error message if the rule is duplicate or overlap

function M.getWifiTodRuleLists()
-- function to retrieve existing wifitod rules list
-- @return wifitod rules list

function M.getAccessControlTodRuleLists(mac_id)
-- function to retrieve existing access control tod rules list
-- @param #mac_id have the mac name of new tod rule request
-- @return access control tod rules list

function M.validateTodRule(value, object, key, todRequest)
-- function that can be used to validate tod rule
-- @param #value have the value of corresponding key
-- @param #object have the POST data
-- @param #key validation key name
-- @param #todRequest have the string value of request tod rule
-- @return #boolean or nil+error message
```

### /www/lua/usbmap.lua

```lua
function M.get_usb_label(port)
-- This function returns the USB port number based on a given directory name
-- created in /sys/bus/usb/devices/ when a USB storage device is inserted.
-- Expected input: Directory Name
-- Return value: USB Port Labell
```

### /www/lua/wizard.lua

```lua
function handleQuery(mapParams, mapValidation)
--- Method to store the POST parameters sent by the UI in UCI (SAVE action)
-- @function [parent=#post_helper] handleQuery
-- @param #table mapParams key/string dictionary containing for each form control's name, the associated path
--                      this should be an exact path since we're going to write
--                      if you need to READ partial paths, please do so after this function has run
-- @param #table mapValidation key/function dictionary containing for each form control's name, the associated
--                      validation function. The validation function should return (err, msg). If err
--                      is nil, then msg should contain an error message, otherwise err should be true
-- @return #table,#table it returns a dictionary containing for each input name, the retrieved value from UCI
--          and another dictionary containing for each failed validation the help message
```

### /www/snippets/broadband-vlan.lp

```lua
function getValidateNumberInRange(min, max, value)
```

### /www/snippets/internet-pppoe-routed.lp

```lua
function get_dhcp_state(wan_auto, wan_ppp, wan_error, ipaddr
```

### /usr/lib/lua/transformer/shared/common/network.lua

```lua
function M.getHostInfo(hostData, getInfo)
--- Retrieves the list of mac-addresses or the device names of the connected hosts.
-- @table hostData The table containing the information of the connected hosts.
-- @function getInfo It specifies the function to retrieve information of the hosts and
-- if not specified dev names will be returned.
-- @treturn table The array containing the information of the connected hosts based on the option parameter.
```

###  /usr/lib/lua/web/network 

```lua
function M.interfacesToIP(interfaces)
--- convert interface names to corresponding IP addresses
-- @param interface a list of interface names
-- @returns a list of corresponding IP addresses.
--   In case a given interface has not IP address an empty string
--   will be substituted.
--   In case an error occurs (eg due to an invalid interface name)
--   an empty list is returned.
```

### /usr/lib/lua/transformer/shared/intfdiaghelper.lua

```lua
local function transaction_set(binding, pvalue, commitapply)
--- Set a given value to the specified uci config
-- @function transaction_set
-- @param binding corresponding uci config for which the value has to be set
-- @param pvalue holds the new value to be set
-- @param commitapply boolean whether to commit or not

function M.startup(interfaces)
--- Check if interface is already present in intfdiag config, else create a new section with interface as sectionname.
-- @function startup
-- @param interface holds the interface name for which the new section has to be created
-- @return interface name

function M.intfDiagSet(binding, pvalue, commitapply)
--- Set the given value to the corresponding section and option in intfdiag config.
-- @function intfDiagSet
-- @param binding holds the uci config and option for which the value has to be set
-- @param pname Parameter name
-- pvalue new value to be set
-- commitapply boolean whether to commit or not
```

### /usr/lib/lua/transformer/shared/processinfo.lua

```lua
function M.getCPUUsage()
-- Calculates CPU usage since boot from the /proc/stat file. This value is a ratio of the non-idle time to the total usage in "USER_HZ".
-- @function M.getCPUUsage
-- @return #string, returns the CPU usage value as a percentage of the total usage.
```

### /usr/lib/lua/transformer/shared/reboot_helper.lua

```lua
local function validateTime(time)
--- Checks if given time is in this "2016-12-29T10:24:00Z" format, Also validates if the given time is greater than the current time.
-- @function validateTime
-- @param time #string holds the givenTime specified by the user
-- @return boolean true if given time is valid and a future time, else returns nil
```

### /www/docroot/modals/relay-modal.lp

```lua
local function getWanInterfacePath()
-- Description Function to get the list of wan interface Paths
-- @function getWanInterfacePath
-- @return table
```

### /usr/share/transformer/mappings/rpc/network.interface.map

```lua
local function getAddress(param, interface)
--- Retrieves the address from "ip -6 addr"
-- @function getAddress
-- @param param the parameter name
-- @param interface the interface name
-- @return addr the ipv6 address
```

### /www/lua/wizard.lua

```lua
function handleQuery(mapParams, mapValidation)
--- Method to store the POST parameters sent by the UI in UCI (SAVE action)
-- @function [parent=#post_helper] handleQuery
-- @param #table mapParams key/string dictionary containing for each form control's name, the associated path
--                      this should be an exact path since we're going to write
--                      if you need to READ partial paths, please do so after this function has run
-- @param #table mapValidation key/function dictionary containing for each form control's name, the associated
--                      validation function. The validation function should return (err, msg). If err
--                      is nil, then msg should contain an error message, otherwise err should be true
-- @return #table,#table it returns a dictionary containing for each input name, the retrieved value from UCI
--          and another dictionary containing for each failed validation the help message
```

### /usr/lib/lua/transformer/shared/sfp.lua

```lua
function handleQuery(mapParams, mapValidation)
--- Method to store the POST parameters sent by the UI in UCI (SAVE action)
-- @function [parent=#post_helper] handleQuery
-- @param #table mapParams key/string dictionary containing for each form control's name, the associated path
--                      this should be an exact path since we're going to write
--                      if you need to READ partial paths, please do so after this function has run
-- @param #table mapValidation key/function dictionary containing for each form control's name, the associated
--                      validation function. The validation function should return (err, msg). If err
--                      is nil, then msg should contain an error message, otherwise err should be true
-- @return #table,#table it returns a dictionary containing for each input name, the retrieved value from UCI
--          and another dictionary containing for each failed validation the help message
```

###  /usr/lib/lua/transformer/shared/common/network.lua  

```lua
function M.getWanInterfaces()
--- Retrieves the list of wan interfaces.
-- @treturn table The array containing wan interfaces.

function M.getLanInterfaces()
--- Retrieves the list of lan interfaces.
-- @treturn table The array containing lan interfaces.

function M.triggerACSRescan(radio)
--- Triggers the ACS rescan on the particular radio if radio is specified else on all the radios.
-- @string radio Specifies the radio name on which the acs rescan should be triggered
-- and if radio is nil, then rescan is triggered on all the radios.

function M.listContains(list, value)
--- Check whether the particular value is present in the given table.
-- @table list A table with different values
-- @string value The value to be checked in the given list of values.
-- @treturn boolean True the given value is present in the table.

function M.setDHCPMinAddress(interface, address, commitapply)
--- Set the minaddress for the given interface.
-- @string interface The interface for which the start address to be modified.
-- @string address The IP Address to be set as start address.
-- @treturn boolean True if the given address is successfully set for the interface else nil + error message.
-- @string commitapply is to apply all changes it will execute all queued actions asynchronously in the background.

function M.setDHCPMaxAddress(interface, address, commitapply)
--- Set the maxaddress for the given interface.
-- @string interface The interface for which the end address to be modified.
-- @string address The IP Address to be set as end address.
-- @treturn boolean True if the given address is successfully set for the interface else nil + error message.
-- @string commitapply is to apply all changes it will execute all queued actions asynchronously in the background.

function M.wlanRemotePort()
--- Retrieves the wlan port.
-- @treturn string Wlan port if it is present else nil is returned.

function M.getDHCPLanInterfaces()
--- Retrieves the list of DHCP Lan interfaces.
-- @treturn table The array containing the list of lan dhcp interfaces.

function M.getHostDataByName(devname)
--- Retrieves the host information based on the given device name.
-- @string devname The device name for which the information to be retrieved.
-- @treturn table The array containing the host information like mac-address, ip address, etc.

function M.convertEpochToISO(time)
--- Converts the given epoch time to ISO 8601 format for combined date
-- and UTC time representation ("2016-12-29T10:24:00Z").
-- @number time The epoch timestamp value.
-- @treturn string The ISO 8601 format for combined date and UTC time representation
-- else 9999-12-31T23:59:59Z if the given time is nil.

function M.getAccessPointInfo(apName)
--- Retrieves the accesspoint information.
-- @string devname The accesspoint name name for which the information to be retrieved.
-- @treturn table The array containing the accesspoint information like state, ssid, etc.

function M.stringToHex(strValue)
--- Converts the given string to hex value.
-- @string strValue the string to be converted to hex.
-- @return string The equivalent hex value for the given string.
```

###  /usr/lib/lua/web/content_helper.lua 

```lua
function M.getPaths(path)
--- Return the path to use with add or as base for index based access given a basepath
-- @function (parent=#content_helper] getPaths
-- @param #string path
-- @return #string, #string, #string addpath, indexpath, instanceprefix

function M.getExactContent(content)
--- Method to get content from exact paths from UCI via transformer.
--  It only accepts UNTAINTED strings
-- @function [parent=#content_helper] getExactContent
-- @param content A table containing key, path pairs. Every path will be retrieved
--                via transformer and the retrieved value will replace the path in the
--                table.
-- @return #bool, #string returns true if successful otherwise returns nil + errmsg

function M.getMatchedContent (path, filter, num)
--- Method to filter section content from uci path.
-- @function [parent=#content_helper] getMatchedContent
-- @param path   A string. Such as "uci.mmpbx.inmap."
-- @param filter A table containing param, value pairs. Only the sections match with the
--               filter will be returned.
--                filter = {
--		      profile = "profile1",
--		      voicePort = {"FXS0", "FXS1"}
--                }
-- @param num    A number. if num matched sections are found, return.
-- 			   Or ergodic all sections to find all matched sections
-- @return A table. Including param and value pairs. The path for this section also returned.
--               content = {
--		     {
--		       profile = "profile1",
--		       ...
--		       path = "uci.mmpbx.inmap.1.", -- if path is not a param, then path will contain the actual path
--		       path = "/usr/lib/mmpbx.sh", -- if path is a param, then path will contain the value of that param
--		       __path = "uci.mmpbx.inmap.1.", -- __path will always contain the actual path and it is preferred over path
--		       voicePort = {
--		           {
--		             value = "FXS0",
--		             path = "uci.mmpbx.inmap.1.voicePort.@1."
--		           },
--		           {...}
--		       }
--		     },
--		     {...},
--               }

function M.addListContent(content, incompletes)
--- Method to add content from list paths from UCI via transformer.
-- @function [parent=#content_helper] addListContent
-- @param content A table to which the lists need to be added.
-- @param incompletes A table containing key, path pairs. Every path will be retrieved
--                    via transformer and the retrieved values will be inserted into
--                    an array which is added to the content table with the corresponding
--                    key.
-- @param Nothing is returned, but the content table contains the lists corresponding
--        to the given incomplete paths after this method is called.

function M.readfile(filename,form,conversion)
--- Method to retrieve information from a file.
-- @function [parent=#content_helper] readfile
-- @param #string filename The file from which information needs to be retrieved.
-- @param #string form The format to be used when reading from the file. Possible formats:
--             number: retrieve a number
--             line: retrieve a line
--             file: retrieve the entire file
-- @param conversion An optional function to convert the retrieved data from the file
--                   before returning the value.
-- @return

function M.setObject(object, map, basepath, defaultObject)
--- Method to set parameters using a mapping table
-- @function [parent=#content_helper] setObject
-- @param #table object - the object to write
-- @param #table map - the object property -> transformer mapping
-- @param #string basepath - basepath to append to every path
-- @param #table defaultObject table or nil (transformer param name => value)
-- 			     1) table that is merged with the data gathered from the form before being written
-- 			     2) nil just use the data gathered from the form without change

function M.addNewObject(basepath, object, map, defaultObject, objectName)
--- Method to create a new element and populate its fields using a mapping table
-- @function [parent=#content_helper] addNewObject
-- @param #string basepath - transformer path
-- @param #table object - object to use to populate the fields
-- @param #table map - property name to transformer name conversion table
-- @param #table defaultObject table or nil (transformer param name => value)
-- 			     1) table that is merged with the data gathered from the form before being written
-- 			     2) nil just use the data gathered from the form without change
-- @param #string objectName - name for the new added object
-- @return #strings, #table index,msg

function M.validateObject(object, mapValidation)
-- Method that takes an object and applies the validation methods provided in mapValidation on it
-- @function [parent=#content_helper] validateObject
-- @param #table object
-- @param #table mapValidation
-- @return #boolean, #table success, helpmsg

function M.getMergedList(list1, list2)
-- Method that takes two lists of comma separated values and merges into a single list.
-- Also removes the duplicate entries if any.
-- @function [parent=#content_helper] getMergedList
-- @param #string list1
-- @param #string list2
-- @return #string mergedList
```
