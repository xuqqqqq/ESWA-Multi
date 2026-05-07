function childarrivalTime = calArrivalTime(k,childRoute,childlengthR,childnumR)
% global route                                                               % 所有个体的路径 carNum * n * popsize   n为受灾点数量
global road                                                                % 所有个体的选择的行驶路线 popsize * n（通过道路z到i点）
% global lengthR                                                             % 所有个体的每条道路的长度 popsize * n
% global numR                                                                % 所有个体的路径数量 1 * popsize
% global arrivalTime                                                         % 所有个体的每个受灾点的到达时间 popsize * n
% global fitness                                                             % 所有个体的适应度值 1 * popsize
% global damage                                                              % 每个受灾点的损失 popsize * n
% global popsize                                                             % 种群规模
% global carNum                                                              % 最大车辆使用数量
global roadNum                                                             % 可选择的道路数量
global depot                                                               % 仓库编号
global nodeNum                                                             % 受灾点数量
% global v                                                                   % 车辆行驶初始速度
% global demand                                                              % 各个点的需求量
global s                                                                   % 各个点的服务时间
global D                                                                   % 距离矩阵(n+1) * (n+1) * 3，第1个是短的路径长度，第2个是正常路径长度，第3个是长的路径长度
% global maxLoad                                                             % 车辆的最大装载量
% global omega                                                               % 每个点的单位损失成本 1 * n
% global initialDeteriorationNode                                            % 每个点的初始毁坏程度 n * 1
% global deteriorationRateNode                                               % 每个点的毁坏率 n * 1
% global recoveryRateNode                                                    % 每个点的恢复率 n * 1
global initialDeteriorationD                                               % 每条路的初始毁坏程度 (n+1) * (n+1) * 3
% global deteriorationRateD                                                  % 每条路的毁坏率 (n+1) * (n+1) * 3
% global recoveryRateD                                                       % 每条路的恢复率 (n+1) * (n+1)
% global deteriorationRateDMax                                               % 最大损坏率
% global recoveryRateDmin                                                    % 最小恢复率
global numPeriods Tshift carNum

childarrivalTime = zeros(1,nodeNum);
for i = 1:childnumR
    % ====== 加入时间轴偏移 ======
    p = ceil(i / carNum);
    timeOffset = (p - 1) * Tshift;

    tempRoute = [depot childRoute(i,1:childlengthR(i))];
    for j = 1:length(tempRoute) - 1
        if tempRoute(j) == depot
            vkz = speedv(initialDeteriorationD(depot,tempRoute(j+1),road(k,tempRoute(j+1))));
            while vkz <= 0
                road(k,tempRoute(j+1)) = randperm(roadNum,1);
                vkz = speedv(initialDeteriorationD(depot,tempRoute(j+1),road(k,tempRoute(j+1))));
            end
            childarrivalTime(tempRoute(j+1)) = timeOffset + D(depot,tempRoute(j+1),road(k,tempRoute(j+1))) / vkz;
        else
            Rzt = Rt(road(k,tempRoute(j+1)),(childarrivalTime(tempRoute(j)) + s(tempRoute(j))),tempRoute(j),tempRoute(j+1));
            vkz = speedv(Rzt);
            while vkz <= 0
                road(k,tempRoute(j+1)) = randperm(roadNum,1);
                Rzt = Rt(road(k,tempRoute(j+1)),(childarrivalTime(tempRoute(j)) + s(tempRoute(j))),tempRoute(j),tempRoute(j+1));
                vkz = speedv(Rzt);
            end
            childarrivalTime(tempRoute(j+1)) = childarrivalTime(tempRoute(j)) + D(tempRoute(j),tempRoute(j+1),road(k,tempRoute(j+1))) / vkz + s(tempRoute(j));
        end
    end
end
end
