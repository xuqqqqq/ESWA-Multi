% 对第r条路更新，r可以是一个常数也可是一个向量
function [fitK,damageK,roadK,arrivalTimeK] = objectiveK(routeK,lengthRK,roadK,arrivalTimeK,damageK,r)
global roadNum                                                             % 可选择的道路数量
global depot                                                               % 仓库编号
global s                                                                   % 各个点的服务时间
global D                                                                   % 距离矩阵(n+1) * (n+1) * 3，第1个是短的路径长度，第2个是正常路径长度，第3个是长的路径长度
global omega                                                               % 每个点的单位损失成本 1 * n
global initialDeteriorationD                                               % 每条路的初始毁坏程度 (n+1) * (n+1) * 3
global demand
global numPeriods Qp Tshift penaltyWeight carNum

for i = 1:length(r)
    % ====== 加入时间轴偏移 ======
    p = ceil(r(i) / carNum);
    timeOffset = (p - 1) * Tshift;
    
    tempRoute = [depot routeK(r(i),1:lengthRK(r(i)))];
    for j = 1:length(tempRoute) - 1
        if tempRoute(j) == depot
            vkz = speedv(initialDeteriorationD(depot,tempRoute(j+1),roadK(tempRoute(j+1))));
            while vkz <= 0
                roadK(tempRoute(j+1)) = randperm(roadNum,1);
                vkz = speedv(initialDeteriorationD(depot,tempRoute(j+1),roadK(tempRoute(j+1))));
            end
            arrivalTimeK(tempRoute(j+1)) = timeOffset + D(depot,tempRoute(j+1),roadK(tempRoute(j+1))) / vkz;
        else
            Rzt = Rt(roadK(tempRoute(j+1)),(arrivalTimeK(tempRoute(j)) + s(tempRoute(j))),tempRoute(j),tempRoute(j+1));
            vkz = speedv(Rzt);
            while vkz <= 0
                roadK(tempRoute(j+1)) = randperm(roadNum,1);
                Rzt = Rt(roadK(tempRoute(j+1)),(arrivalTimeK(tempRoute(j)) + s(tempRoute(j))),tempRoute(j),tempRoute(j+1));
                vkz = speedv(Rzt);
            end
            arrivalTimeK(tempRoute(j+1)) = arrivalTimeK(tempRoute(j)) + D(tempRoute(j),tempRoute(j+1),roadK(tempRoute(j+1))) / vkz + s(tempRoute(j));
        end
        
        damageK(tempRoute(j+1)) = Dt(tempRoute(j+1),arrivalTimeK(tempRoute(j+1)));
    end
end

% ====== 计算滚动库存惩罚 ======
penalty = 0;
periodLoad = zeros(1, numPeriods);
for i = 1:length(lengthRK) 
    p = ceil(i / carNum);
    if lengthRK(i) > 0
        periodLoad(p) = periodLoad(p) + sum(demand(routeK(i, 1:lengthRK(i))));
    end
end

currentCumulativeLoad = 0;
for p = 1:numPeriods
    currentCumulativeLoad = currentCumulativeLoad + periodLoad(p);
    cumulativeSupplyLimit = p * Qp;
    if currentCumulativeLoad > cumulativeSupplyLimit
        penalty = penalty + (currentCumulativeLoad - cumulativeSupplyLimit) * penaltyWeight;
    end
end

fitK = sum(damageK .* omega) + penalty;
end
    
    
