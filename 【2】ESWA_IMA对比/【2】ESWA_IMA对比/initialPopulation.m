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
global initialDeteriorationNode                                            % 每个点的初始毁坏程度 n * 1
global deteriorationRateNode                                               % 每个点的毁坏率 n * 1
global recoveryRateNode                                                    % 每个点的恢复率 n * 1
% global initialDeteriorationD                                               % 每条路的初始毁坏程度 (n+1) * (n+1) * 3
% global deteriorationRateD                                                  % 每条路的毁坏率 (n+1) * (n+1) * 3
% global recoveryRateD                                                       % 每条路的恢复率 (n+1) * (n+1)
global numPeriods Qp totalCarNum


% for k = 1:popsize
%     %     tempSequence = [];
%     pInitialDeteriorationNode = initialDeteriorationNode(1:nodeNum) ./ sum(initialDeteriorationNode(1:nodeNum));
%     mInitialDeteriorationNode = cumsum(pInitialDeteriorationNode);
%     pDNode = (deteriorationRateNode(1:nodeNum) ./ recoveryRateNode(1:nodeNum)) ./ sum((deteriorationRateNode(1:nodeNum) ./ recoveryRateNode(1:nodeNum)));
%     mDNode = cumsum(pDNode);
%     mP = (mInitialDeteriorationNode + mDNode) ./ 2;
%     se = 1:nodeNum;
%     for z = 1:nodeNum
%         
%         rd = rand;
%         for x = 1:length(mP)
%             if rd > mP(x)
%                 continue;
%             else
%                 tempSequence(1,z) = se(x);
%                 se(x) = [];
%                 mP(x) = [];
%                 tempmP = mP ./ sum(mP);
%                 mP = cumsum(tempmP);
%                 break;
%             end
%         end
%     end
%     sequence = tempSequence;
%     numR(k) = carNum;
%     load = zeros(1,carNum);
%     for j = 1:nodeNum
%         for i = 1:carNum
%             if j == 1
%                 route(i,j,k) = sequence(1);
%                 lengthR(k,i) = 1;
%                 road(k,sequence(1)) = randperm(roadNum,1);
%                 load(i) = demand(route(i,j,k));
%                 sequence(1) = [];
%             else
%                 if (~isempty(sequence))
%                     if (load(i) + demand(sequence(1)) <= maxLoad)
%                         load(i) = load(i) + demand(sequence(1));
%                         route(i,j,k) = sequence(1);
%                         lengthR(k,i) = lengthR(k,i) + 1;
%                         road(k,sequence(1)) = randperm(roadNum,1);
%                         sequence(1) = [];
%                     end
%                 end
%             end
%         end
%     end
% end
% 
% 
% 
% end


for k = 1:popsize
    % =====================================================================
    % 1. 序列生成阶段：【完全保留】你对比算法原有的轮盘赌逻辑
    % =====================================================================
    tempSequence = [];
    pInitialDeteriorationNode = initialDeteriorationNode(1:nodeNum) ./ sum(initialDeteriorationNode(1:nodeNum));
    mInitialDeteriorationNode = cumsum(pInitialDeteriorationNode);
    pDNode = (deteriorationRateNode(1:nodeNum) ./ recoveryRateNode(1:nodeNum)) ./ sum((deteriorationRateNode(1:nodeNum) ./ recoveryRateNode(1:nodeNum)));
    mDNode = cumsum(pDNode);
    mP = (mInitialDeteriorationNode + mDNode) ./ 2;
    se = 1:nodeNum;
    for z = 1:nodeNum
        rd = rand;
        for x = 1:length(mP)
            if rd > mP(x)
                continue;
            else
                tempSequence(1,z) = se(x);
                se(x) = [];
                mP(x) = [];
                tempmP = mP ./ sum(mP);
                mP = cumsum(tempmP);
                break;
            end
        end
    end
    sequence = tempSequence;
    
    % =====================================================================
    % 2. 节点分配阶段：【修改为支持多周期与滚动库存】
    % （废弃了原来只循环 carNum 的分配逻辑，改为跨周期分配）
    % =====================================================================
    numR(k) = totalCarNum;         % 使用展开后的总车辆数
    loadV = zeros(1, totalCarNum); % 记录每辆车的载重
    loadP = zeros(1, numPeriods);  % 记录每个周期的总消耗物资
    
    while ~isempty(sequence)
        node = sequence(1);
        assigned = false;
        
        % 尝试将点分配给合适的周期和车辆
        for p = 1:numPeriods
            % --- 滚动库存核心：计算截至到周期 p 的累计已分配物资和总上限 ---
            cumLoadAlready = sum(loadP(1:p));
            cumSupply = p * Qp;
            
            % 只要 (已有累计负荷 + 当前点需求) <= 累计总供给，就允许分配到当前周期
            if cumLoadAlready + demand(node) <= cumSupply
                % 遍历当前周期的所有车辆，找一辆还没满载的车
                for i = 1:carNum
                    vIdx = (p - 1) * carNum + i; % 计算在 totalCarNum 中的绝对索引
                    if loadV(vIdx) + demand(node) <= maxLoad
                        % 分配成功，更新路径和载重
                        route(vIdx, lengthR(k, vIdx) + 1, k) = node;
                        lengthR(k, vIdx) = lengthR(k, vIdx) + 1;
                        road(k, node) = randperm(roadNum, 1);
                        
                        loadV(vIdx) = loadV(vIdx) + demand(node);
                        loadP(p) = loadP(p) + demand(node); % 更新当前周期的消耗
                        assigned = true;
                        break; % 跳出车辆循环
                    end
                end
            end
            if assigned 
                break; % 跳出周期循环
            end
        end
        
        % 防御性编程：如果因为极度严苛的约束导致哪都没塞进去，强制塞入随机车辆
        % (后续会在 target function 里由 penaltyWeight 惩罚掉)
        if ~assigned
            vIdx = randperm(totalCarNum, 1);
            p = ceil(vIdx / carNum);
            route(vIdx, lengthR(k, vIdx) + 1, k) = node;
            lengthR(k, vIdx) = lengthR(k, vIdx) + 1;
            road(k, node) = randperm(roadNum, 1);
            loadV(vIdx) = loadV(vIdx) + demand(node);
            loadP(p) = loadP(p) + demand(node);
        end
        
        sequence(1) = []; % 成功分配后，将该点从待分配序列中移除
    end
end
end
            