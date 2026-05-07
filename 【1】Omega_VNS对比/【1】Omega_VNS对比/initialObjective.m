function initialObjective()
global route                                                               % 所有个体的路径 carNum * n * popsize   n为受灾点数量
global road                                                                % 所有个体的选择的行驶路线 popsize * n（通过道路z到i点）
global lengthR                                                             % 所有个体的每条道路的长度 popsize * n
global numR                                                                % 所有个体的路径数量 1 * popsize
global arrivalTime                                                         % 所有个体的每个受灾点的到达时间 popsize * n
global fitness                                                             % 所有个体的适应度值 1 * popsize
global damage                                                              % 每个受灾点的损失 1 * n
global popsize                                                             % 种群规模
% global carNum                                                              % 最大车辆使用数量
global roadNum                                                             % 可选择的道路数量
global depot                                                               % 仓库编号
global nodeNum                                                             % 受灾点数量
% global v                                                                   % 车辆行驶初始速度
global demand                                                              % 各个点的需求量
global s                                                                   % 各个点的服务时间
global D                                                                   % 距离矩阵(n+1) * (n+1) * 3，第1个是短的路径长度，第2个是正常路径长度，第3个是长的路径长度
% global maxLoad                                                             % 车辆的最大装载量
global omega                                                               % 每个点的单位损失成本 1 * n
% global initialDeteriorationNode                                            % 每个点的初始毁坏程度 n * 1
% global deteriorationRateNode                                               % 每个点的毁坏率 n * 1
% global recoveryRateNode                                                    % 每个点的恢复率 n * 1
global initialDeteriorationD                                               % 每条路的初始毁坏程度 (n+1) * (n+1) * 3
% global deteriorationRateD                                                  % 每条路的毁坏率 (n+1) * (n+1) * 3
% global recoveryRateD                                                       % 每条路的恢复率 (n+1) * (n+1)
global numPeriods Qp Tshift penaltyWeight carNum

for k = 1:popsize
    for i = 1:numR(k)

        % ====== 核心：时间轴偏移计算 ======
        p = ceil(i / carNum);           % 计算该车属于第几个周期
        timeOffset = (p - 1) * Tshift;  % 该周期的基础起算时间

        tempRoute = [];
        tempRoute = [depot route(i,1:lengthR(k,i),k)];
        for j = 1:length(tempRoute) - 1
            if tempRoute(j) == depot
                vkz = speedv(initialDeteriorationD(depot,tempRoute(j+1),road(k,tempRoute(j+1))));
                while vkz <= 0
                    road(k,tempRoute(j+1)) = randperm(roadNum,1);
                    vkz = speedv(initialDeteriorationD(depot,tempRoute(j+1),road(k,tempRoute(j+1))));
                end
                arrivalTime(k,tempRoute(j+1)) = timeOffset + D(depot,tempRoute(j+1),road(k,tempRoute(j+1))) / vkz;
            else
                Rzt = Rt(road(k,tempRoute(j+1)),(arrivalTime(k,tempRoute(j)) + s(tempRoute(j))),tempRoute(j),tempRoute(j+1));
                vkz = speedv(Rzt);
                while vkz <= 0
                    road(k,tempRoute(j+1)) = randperm(roadNum,1);
                    Rzt = Rt(road(k,tempRoute(j+1)),(arrivalTime(k,tempRoute(j)) + s(tempRoute(j))),tempRoute(j),tempRoute(j+1));
                    vkz = speedv(Rzt);
                end
                arrivalTime(k,tempRoute(j+1)) = arrivalTime(k,tempRoute(j)) + D(tempRoute(j),tempRoute(j+1),road(k,tempRoute(j+1))) / vkz + s(tempRoute(j));
            end
        end
    end
    
    for i = 1:nodeNum
        damage(k,i) = Dt(i,arrivalTime(k,i));
    end
    
    % ====== 计算多周期物资限制的惩罚函数 ======
    penalty = 0;
    periodLoad = zeros(1, numPeriods);
    for i = 1:numR(k)
        p = ceil(i / carNum);
        if lengthR(k,i) > 0
            periodLoad(p) = periodLoad(p) + sum(demand(route(i, 1:lengthR(k,i), k)));
        end
    end
    % --- 修改核心：累加法计算滚动库存 ---
    cumulativeLoad = 0;
    cumulativeSupply = 0;
    for p = 1:numPeriods
        cumulativeLoad = cumulativeLoad + periodLoad(p);
        cumulativeSupply = cumulativeSupply + Qp; % 假设每个周期固定补货 Qp
        
        % 如果截至到当前周期的总消耗 > 总补货，说明透支了，给予惩罚
        if cumulativeLoad > cumulativeSupply
            penalty = penalty + (cumulativeLoad - cumulativeSupply) * penaltyWeight;
        end
    end
    
    fitness(k) = sum(damage(k,:) .* omega) + penalty;
end
end
    
        
        
        
        
        