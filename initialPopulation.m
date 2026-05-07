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
global deteriorationRateNode                                               % 每个点的毁坏率 n * 1
global recoveryRateNode                                                    % 每个点的恢复率 n * 1
% global initialDeteriorationD                                               % 每条路的初始毁坏程度 (n+1) * (n+1) * 3
% global deteriorationRateD                                                  % 每条路的毁坏率 (n+1) * (n+1) * 3
% global recoveryRateD                                                       % 每条路的恢复率 (n+1) * (n+1)
global numPeriods Qp totalCarNum



for k = 1:popsize/2
    sequence = randperm(nodeNum);
    numR(k) = totalCarNum; % 展开后的车辆总数
    loadV = zeros(1,totalCarNum);  % 每辆车的载重
    loadP = zeros(1,numPeriods);   % 每个周期的总派发物资
    
    for j = 1:nodeNum
        assigned = false;
        for p = 1:numPeriods
            % --- 滚动库存核心：计算截至到周期 p 的累计已分配物资和总上限 ---
            cumLoad = sum(loadP(1:p));
            cumSupply = p * Qp;
            
            % 如果 累计已用物资 + 新点的需求 <= 累计可用补货上限
            if cumLoad + demand(sequence(1)) <= cumSupply
                % 遍历当前周期的车辆
%         for p = 1:numPeriods
%             % 如果当前周期还能装得下这个点
%             if loadP(p) + demand(sequence(1)) <= Qp
%                 % 遍历当前周期的车辆
                for i = 1:carNum
                    vIdx = (p - 1) * carNum + i; % 映射到全局车次索引
                    if loadV(vIdx) + demand(sequence(1)) <= maxLoad
                        route(vIdx, lengthR(k,vIdx)+1, k) = sequence(1);
                        lengthR(k,vIdx) = lengthR(k,vIdx) + 1;
                        road(k,sequence(1)) = randperm(roadNum,1);
                        loadV(vIdx) = loadV(vIdx) + demand(sequence(1));
                        loadP(p) = loadP(p) + demand(sequence(1));
                        assigned = true;
                        break;
                    end
                end
            end
            if assigned, break; end
        end
        % 如果所有周期都装不下(极其严苛的Qp限制)，强制塞入随机周期，交由惩罚函数处理
        if ~assigned
            vIdx = randperm(totalCarNum,1);
            p = ceil(vIdx / carNum);
            route(vIdx, lengthR(k,vIdx)+1, k) = sequence(1);
            lengthR(k,vIdx) = lengthR(k,vIdx) + 1;
            road(k,sequence(1)) = randperm(roadNum,1);
            loadV(vIdx) = loadV(vIdx) + demand(sequence(1));
            loadP(p) = loadP(p) + demand(sequence(1));
        end
        sequence(1) = [];
    end
end

% 启发式部分 (按紧急度分配)
X = [deteriorationRateNode(1:nodeNum) recoveryRateNode(1:nodeNum)];
[idx, C] = kmeans(X, 3);
Vurgent = []; urgent = []; Surgent = [];                                                             
betaGamma = C(:,1) ./ C(:,2);                                              
[f, indexf] = sort(betaGamma);

for i = 1:nodeNum
    switch indexf(idx(i))
        case 1, Vurgent = [Vurgent i];
        case 2, urgent = [urgent i];
        case 3, Surgent = [Surgent i];
    end
end

for k = (popsize/2+1):popsize
    Sequence = [Vurgent(randperm(length(Vurgent))) urgent(randperm(length(urgent))) Surgent(randperm(length(Surgent)))];
    numR(k) = totalCarNum;
    loadV = zeros(1,totalCarNum);
    loadP = zeros(1,numPeriods);
    
    for j = 1:nodeNum
        assigned = false;
        for p = 1:numPeriods
            % --- 滚动库存核心：计算截至到周期 p 的累计已分配物资和总上限 ---
            cumLoad = sum(loadP(1:p));
            cumSupply = p * Qp;
            
            % 如果 累计已用物资 + 新点的需求 <= 累计可用补货上限
            if cumLoad + demand(Sequence(1)) <= cumSupply
                % 遍历当前周期的车辆
%         for p = 1:numPeriods
%             if loadP(p) + demand(Sequence(1)) <= Qp
                for i = 1:carNum
                    vIdx = (p - 1) * carNum + i;
                    if loadV(vIdx) + demand(Sequence(1)) <= maxLoad
                        route(vIdx, lengthR(k,vIdx)+1, k) = Sequence(1);
                        lengthR(k,vIdx) = lengthR(k,vIdx) + 1;
                        road(k,Sequence(1)) = randperm(roadNum,1);
                        loadV(vIdx) = loadV(vIdx) + demand(Sequence(1));
                        loadP(p) = loadP(p) + demand(Sequence(1));
                        assigned = true;
                        break;
                    end
                end
            end
            if assigned, break; end
        end
        if ~assigned
            vIdx = randperm(totalCarNum,1);
            p = ceil(vIdx / carNum);
            route(vIdx, lengthR(k,vIdx)+1, k) = Sequence(1);
            lengthR(k,vIdx) = lengthR(k,vIdx) + 1;
            road(k,Sequence(1)) = randperm(roadNum,1);
        end
        Sequence(1) = [];
    end   
end
end
            