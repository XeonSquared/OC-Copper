TH,S,C,TC="hostname",string,component,"copper"
TX=C.proxy(C.list("modem")())TX.open(4957)TB=TX.broadcast
function TN(m)if#m<2then return end
local n=m:byte(1)+2return m:sub(2,n),m:sub(n+1)end
function TR(m)local h,s,m,d=m:byte(),TN(m:sub(2))if s then
d,m=TN(m)if d then
return s,d,m
end
end
end
function TS(d,m)TB(4957,TC,S.char(0,#TH-1)..TH..S.char(#d-1)..d..m)end
R1,R2,R3,R4=0x40,60,12,2.5
RT,RA,RN,RU={},{},{},computer.uptime
function RP(f,x)if#RT<R1 then
local t={f,RU()+x}table.insert(RT,t)return t
end
end
function RK(t)for i=1,#RT do
if t==RT[i]then
table.remove(RT,i)end
end
end
function RC(r,f,t,d)if d and#d>=7then
local p,b,g,k=d:byte(2)+(d:byte(1)*256),d:byte(7),d:sub(1,5)if b==0x01or b==0x00then
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
function RF()local i,t=1,RU()while#RT>i do
if t>RT[i][2]then
table.remove(RT,i)[1]()else
i=i+1
end
end
end
function RG()return math.random(256)-1
end
function RS(t,p,d)local g,a,j,x=S.char(math.floor(p/256),p%256,RG(),RG(),RG()),-1
j=function()a=a+1
x=nil
if a~=R3 then
TS(t,g..S.char(a,1)..d)x=RP(j,R4)end
RN[t..g]=x
end j()end
-- EXAMPLE IoT Redstone Top Controller --
UR=C.proxy(C.list("redstone")())function UT(p)US=p
if#p>0then
UR.setOutput(1,15)else
UR.setOutput(1,0)end
end
UT("")function UG(t)RS(t,4,"\xC0\x42active.\x81setName")end
N={[0]=UG,
[1]=function(f)RS(f,4,"\xC1"..US)end,
[0x41]=function(_,p)UT(p)end,
[0x82]=function(_,p)if#p>0then TH=p end end,
}
function UI(f,t,p,d)local m=t==TH
if p==1 and(t=="*"or m)then
UG(f)end
if p==4 and m then
if N[d:byte(1)]then
N[d:byte(1)](f,d:sub(2))end
end
end
while true do local x={computer.pullSignal(1)}RF()if"modem_message"==x[1]and 4957==x[4]and TC==x[6]then
RC(UI,TR(x[7]))end
end