% 对第r条路更新，r可以是一个常数也可是一个向量
function totalroadDamage = roadDamage(routeK,lengthRK,roadK,arrivalTimeK,r)
% global roadNum                                                             % 可选择的道路数量
global depot                                                               % 仓库编号
global s                                                                   % 各个点的服务时间
% global D                                                                   % 距离矩阵(n+1) * (n+1) * 3，第1个是短的路径长度，第2个是正常路径长度，第3个是长的路径长度
% global omega                                                               % 每个点的单位损失成本 1 * n
global initialDeteriorationD                                               % 每条路的初始毁坏程度 (n+1) * (n+1) * 3
totalroadDamage = 0;
for i = 1:length(r)
    tempRoute = [];
    tempRoute = [depot routeK(r(i),1:lengthRK(r(i)))];
    for j = 1:length(tempRoute) - 1
        if tempRoute(j) == depot
            totalroadDamage = totalroadDamage + initialDeteriorationD(depot,tempRoute(j+1),roadK(tempRoute(j+1)));
        else
            Rzt = Rt(roadK(tempRoute(j+1)),(arrivalTimeK(tempRoute(j)) + s(tempRoute(j))),tempRoute(j),tempRoute(j+1));
            totalroadDamage = totalroadDamage + Rzt;
        end 
    end
end
end
    
    
