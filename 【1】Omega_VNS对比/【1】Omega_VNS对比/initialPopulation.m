function initialPopulation()
global route                                                               % 所有个体的路径 carNum * n * popsize   n为受灾点数量
global road                                                                % 所有个体的选择的行驶路线 popsize * n （通过道路z到i点）
global lengthR                                                             % 所有个体的每条道路的长度 popsize * n
global numR                                                                % 所有个体的路径数量 1 * popsize
% global arrivalTime                                                         % 所有个体的每个受灾点的到达时间 popsize * n
% global fitness                                                             % 所有个体的适应度值 1 * popsize
% global damage                                                              % 每个受灾点的损失 1 * n
global popsize                                                             % 种群规模
global carNum                                                              % 最大车辆使用数量
global roadNum                                                             % 可选择的道路数量
% global depot                                                               % 仓库编号
global nodeNum                                                             % 受灾点数量
% global v                                                                   % 车辆行驶初始速度
global demand                                                              % 各个点的需求量
% global s                                                                   % 各个点的服务时间
% global D                                                                   % 距离矩阵(n+1) * (n+1) * 3，第1个是短的路径长度，第2个是正常路径长度，第3个是长的路径长度
global maxLoad                                                             % 车辆的最大装载量
% global initialDeteriorationNode                                            % 每个点的初始毁坏程度 n * 1
% global deteriorationRateNode                                               % 每个点的毁坏率 n * 1
% global recoveryRateNode                                                    % 每个点的恢复率 n * 1
% global initialDeteriorationD                                               % 每条路的初始毁坏程度 (n+1) * (n+1) * 3
% global deteriorationRateD                                                  % 每条路的毁坏率 (n+1) * (n+1) * 3
% global recoveryRateD                                                       % 每条路的恢复率 (n+1) * (n+1)
global numPeriods Qp totalCarNum

for k = 1:popsize
    sequence = randperm(nodeNum);
%     numR(k) = carNum;
%     load = zeros(1,carNum);
    numR(k) = totalCarNum; % 使用总车辆数（所有周期）
    loadV = zeros(1, totalCarNum); % 每辆车的负载
    loadP = zeros(1, numPeriods); % 每个周期的总负载

    for j = 1:nodeNum
        node = sequence(j);
        assigned = false;

        for p = 1:numPeriods
            % --- 滚动库存核心：计算截至到周期 p 的累计已分配物资和总上限 ---
            cumLoad = sum(loadP(1:p));
            cumSupply = p * Qp;
            
            % 如果 累计已用物资 + 新点的需求 <= 累计可用补货上限
            if cumLoad + demand(sequence(1)) <= cumSupply


        for i = 1:carNum
                    vIdx = (p - 1) * carNum + i; % 转换到全局车辆索引
                    if loadV(vIdx) + demand(node) <= maxLoad
                        lengthR(k, vIdx) = lengthR(k, vIdx) + 1;
                        route(vIdx, lengthR(k, vIdx), k) = node;
                        road(k, node) = randperm(roadNum, 1);
                        loadV(vIdx) = loadV(vIdx) + demand(node);
                        loadP(p) = loadP(p) + demand(node);
                        assigned = true;
                        break;
                    end
                end
            end
            if assigned, break; end
        end
        % 如果所有周期都塞不下了（理论上不应发生，除非总需求 > 总供应）
        if ~assigned
             % 强制塞入最后一个周期的第一辆车（或报错提示）
             vIdx = totalCarNum - carNum + 1;
             lengthR(k, vIdx) = lengthR(k, vIdx) + 1;
             route(vIdx, lengthR(k, vIdx), k) = node;
             road(k, node) = randperm(roadNum, 1);
        end
    end
end
end

            