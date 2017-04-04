S,C,TC=string,component,"copper"
function CG(n)return C.proxy(C.list(n)())end
TH,TX=CG("eeprom").getLabel(),CG("modem")TX.open(4957)TB=TX.broadcast
function TN(m)if#m<2then return end
local n,t=m:byte(1)+2t=m:sub(n+1)if#t>=n then return m:sub(2,n),m:sub(n+1)end
end
function TR(m)local h,s,m,d=m:byte(),TN(m:sub(2))if s then
d,m=TN(m)if d then
return s,d,m
end
end
end
function TS(d,m)TB(4957,TC,S.char(0,#TH-1)..TH..S.char(#d-1)..d..m)end
R1,R2,R3,R4=0x40,60,12,2.5
RT,RA,RN,RU,R,X={},{},{},computer.uptime,math.random,255
RP,RK,RF=function(f,x)if#RT<R1 then
local t={f,RU()+x}table.insert(RT,t)return t
end
end,function(t)for i=1,#RT do
if t==RT[i]then
table.remove(RT,i)end
end
end,function()local i,t=1,RU()while#RT>i do
if t>RT[i][2]then
table.remove(RT,i)[1]()else
i=i+1
end
end
end
function RC(r,f,t,d)if d and#d>=7then
local p,b,g,k=d:byte(2)+(d:byte(1)*X),d:byte(7),d:sub(1,5)if b==0x01or b==0x00then
k=t..g
if not RA[k] then
r(f,t,p,d:sub(8))else
RK(RA[k])end
RA[k]=RP(function()RA[k]=nil end,R2)if not(b~=0x01or t~=TH)then
TS(f,d:sub(1,6).."\x02")end
end
k=f..g
if b==0x02 and RN[k]then
RK(RN[k])RN[k]=nil
end
end
end
function RS(t,p,d)local g,a,j,x=S.char(p>>8,p%X,R(X)-1,R(X)-1,R(X)-1),-1
j=function()a=a+1
x=nil
if a~=R3 then
TS(t,g..S.char(a,1)..d)x=RP(j,R4)end
RN[t..g]=x
end j()end