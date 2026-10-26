-- WPA2 PBKDF2-HMAC-SHA1. Uses the firmware's Lua BitOp; no shell credentials.
local bit=require('bit')
local band,bxor,bnot,rol,rshift,tobit=bit.band,bit.bxor,bit.bnot,bit.rol,bit.rshift,bit.tobit
local M={}
local initial={0x67452301,0xefcdab89,0x98badcfe,0x10325476,0xc3d2e1f0}
local function word(n) return string.char(band(rshift(n,24),255),band(rshift(n,16),255),band(rshift(n,8),255),band(n,255)) end
local function compress(h,s)
  local w={}
  for i=0,15 do local a,b,c,d=s:byte(i*4+1,i*4+4); w[i]=tobit(((a*256+b)*256+c)*256+d) end
  for i=16,79 do w[i]=rol(bxor(w[i-3],w[i-8],w[i-14],w[i-16]),1) end
  local a,b,c,d,e=h[1],h[2],h[3],h[4],h[5]
  for i=0,79 do
    local f,k
    if i<20 then f=bxor(band(b,c),band(bnot(b),d)); k=0x5a827999
    elseif i<40 then f=bxor(b,c,d); k=0x6ed9eba1
    elseif i<60 then f=bxor(band(b,c),band(b,d),band(c,d)); k=0x8f1bbcdc
    else f=bxor(b,c,d); k=0xca62c1d6 end
    local t=tobit(rol(a,5)+f+e+k+w[i]); e=d; d=c; c=rol(b,30); b=a; a=t
  end
  h[1]=tobit(h[1]+a); h[2]=tobit(h[2]+b); h[3]=tobit(h[3]+c); h[4]=tobit(h[4]+d); h[5]=tobit(h[5]+e)
  return h
end
local function digest(s,prefix,done)
  local h={}; for i,v in ipairs(prefix or initial) do h[i]=v end
  local size=#s+(done or 0)
  s=s..'\128'..string.rep('\0',(55-#s)%64)..word(0)..word(size*8)
  for i=1,#s,64 do compress(h,s:sub(i,i+63)) end
  return word(h[1])..word(h[2])..word(h[3])..word(h[4])..word(h[5])
end
local function hex(s) return (s:gsub('.',function(c) return string.format('%02x',c:byte()) end)) end
function M.fingerprint(ssid,password) return hex(digest(ssid..'\0'..password)) end
function M.derive(ssid,password)
  if #password==64 and password:match('^%x+$') then return password:lower() end
  assert(#password>=8 and #password<=63 and #ssid<=32)
  local pad=password..string.rep('\0',64-#password)
  local inner,outer={},{}
  for i=1,64 do inner[i]=string.char(bxor(pad:byte(i),0x36)); outer[i]=string.char(bxor(pad:byte(i),0x5c)) end
  local ih=compress({unpack(initial)},table.concat(inner)); local oh=compress({unpack(initial)},table.concat(outer))
  local function hmac(s) return digest(digest(s,ih,64),oh,64) end
  local blocks={}
  for block=1,2 do
    local u=hmac(ssid..word(block)); local t={u:byte(1,20)}
    for _=2,4096 do
      u=hmac(u)
      for i=1,20 do t[i]=bxor(t[i],u:byte(i)) end
    end
    for i=1,20 do t[i]=string.char(t[i]) end
    blocks[block]=table.concat(t)
  end
  return hex(table.concat(blocks):sub(1,32))
end
return M
