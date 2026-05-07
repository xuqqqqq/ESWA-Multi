% z 为受道路编号
% ai 为需要用道路z的时间
% i,j 从i到j的道路
function Rzt = Rt(z,ai,i,j)
global initialDeteriorationD                                               % 每条路的初始毁坏程度 (n+1) * (n+1) * 3
global deteriorationRateD                                                  % 每条路的毁坏率 (n+1) * (n+1) * 3
global recoveryRateD                                                       % 每条路的恢复率 (n+1) * (n+1)
Rzt = initialDeteriorationD(i,j,z) .* exp(-recoveryRateD(i,j) .* ai) + deteriorationRateD(i,j,z) ./ recoveryRateD(i,j) .* (1 - exp(-recoveryRateD(i,j) .* ai));
end