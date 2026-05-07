function crossover(k,p)
global route                                                               % 所有个体的路径 carNum * n * popsize   n为受灾点数量
global road                                                                % 所有个体的选择的行驶路线 popsize * n（通过道路z到i点）
global lengthR                                                             % 所有个体的每条道路的长度 popsize * n
global numR                                                                % 所有个体的路径数量 1 * popsize
global arrivalTime                                                         % 所有个体的每个受灾点的到达时间 popsize * n
global fitness                                                             % 所有个体的适应度值 1 * popsize
global damage                                                              % 每个受灾点的损失 popsize * n
% global popsize                                                             % 种群规模
% global carNum                                                              % 最大车辆使用数量
% global roadNum                                                             % 可选择的道路数量
% global depot                                                               % 仓库编号
global nodeNum                                                             % 受灾点数量
% global v                                                                   % 车辆行驶初始速度
global demand                                                              % 各个点的需求量
% global s                                                                   % 各个点的服务时间
% global D                                                                   % 距离矩阵(n+1) * (n+1) * 3，第1个是短的路径长度，第2个是正常路径长度，第3个是长的路径长度
global maxLoad                                                             % 车辆的最大装载量
global omega                                                               % 每个点的单位损失成本 1 * n
% global initialDeteriorationNode                                            % 每个点的初始毁坏程度 n * 1
% global deteriorationRateNode                                               % 每个点的毁坏率 n * 1
% global recoveryRateNode                                                    % 每个点的恢复率 n * 1
% global initialDeteriorationD                                               % 每条路的初始毁坏程度 (n+1) * (n+1) * 3
% global deteriorationRateD                                                  % 每条路的毁坏率 (n+1) * (n+1) * 3
% global recoveryRateD                                                       % 每条路的恢复率 (n+1) * (n+1)
% global deteriorationRateDMax                                               % 最大损坏率
% global recoveryRateDmin                                                    % 最小恢复率

childRoute = route(:,:,k);
childlengthR = lengthR(k,:);
childnumR = numR(k);
% childarrivalTime = arrivalTime(k,:);

similarMatrix = zeros(numR(k),numR(p));                                   % 个体k和个体p2的相似度矩阵
for i = 1:numR(k)
    for j = 1:numR(p)
        flag = [];
        flag = ismember(route(i,1:lengthR(k,i),k),route(j,1:lengthR(p,j),p));
        similarMatrix(i,j) = sum(flag);
    end
end
[row,col] = find(similarMatrix == max(max(similarMatrix)));
Rk = row(1);                                                               % 选择父代k的路
Rp = col(1);                                                               % 选择父代p的路
flag = [];                                                                 % 先找到Rk中与Rp中的点是否相同，0为不同，1为相同，再把不相同的点拿出来，等待插入
flag = ismember(route(Rk,1:lengthR(k,Rk),k),route(Rp,1:lengthR(p,Rp),p));
insertRoute = [];                                                          % 待插入的点的矩阵
originalRoute = [];                                                        % 不需要重新插入的点
for i = 1:length(flag)
    if flag(i) == 0
        insertRoute = [insertRoute route(Rk,i,k)];
    else
        originalRoute = [originalRoute route(Rk,i,k)];
    end
end
childRoute(Rk,:) = 0;
childRoute(Rk,1:length(originalRoute)) = originalRoute;
childlengthR(Rk) = length(originalRoute);
if ~isempty(insertRoute)
    for i = 1:length(insertRoute)
        r = randperm(childnumR,1);
        load = sum(demand(childRoute(r,1:childlengthR(r))));
        while (load + demand(insertRoute(i))) > maxLoad
            r = randperm(childnumR,1);
            load = sum(demand(childRoute(r,1:childlengthR(r))));
        end
        
% --- 核心修复：处理空路径插入的情况 ---
        if childlengthR(r) == 0
            % 如果路径是空的，直接放在第一个位置，不需要 randperm
            point = 1; 
        else
            % 如果路径不为空，再随机选择位置
            point = randperm(childlengthR(r), 1); 
        end

%         point = randperm(childlengthR(r),1);                           % 随机选择一个插入点
        childlengthR(r) = childlengthR(r) + 1;
        temp = [childRoute(r,1:point-1) insertRoute(i) childRoute(r,point:end - 1)];
        childRoute(r,:) = temp;
    end
end

childarrivalTime = calArrivalTime(k,childRoute,childlengthR,childnumR);
childDamage = zeros(1,nodeNum);
for i = 1:nodeNum
    childDamage(i) = Dt(i,childarrivalTime(i));
end
childfitness = sum(childDamage .* omega);
if childfitness < fitness(k)
    fitness(k) = childfitness;
    route(:,:,k) = childRoute;
    numR(k) = childnumR;
    lengthR(k,:) = childlengthR;
    arrivalTime(k,:) = childarrivalTime;
    damage(k,:) = childDamage;
end
end


