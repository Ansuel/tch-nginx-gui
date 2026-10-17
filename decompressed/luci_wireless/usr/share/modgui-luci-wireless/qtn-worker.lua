local q=require('modgui.luci_qtn')
if arg[1]=='job' then
  require('nixio').nanosleep(2)
  q.run_job(arg[2])
  return
end
local failed=false
repeat
  local ok=q.reconcile()
  if not ok and not failed then
    os.execute("logger -t modgui-luci-qtn 'Reconciliation failed; retrying automatically'")
  elseif ok and failed then
    os.execute("logger -t modgui-luci-qtn 'Reconciliation recovered'")
  end
  failed=not ok
  if arg[1]=='once' then break end
  require('nixio').nanosleep(15)
until false
