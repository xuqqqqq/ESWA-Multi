function flag = GreedySelection(k)
global route                                                               % 所有个体的路径 carNum * n * popsize   n为受灾点数量
global road                                                                % 所有个体的选择的行驶路线 popsize * n（通过道路z到i点）
global lengthR                                                             % 所有个体的每条道路的长度 popsize * n
global arrivalTime                                                         % 所有个体的每个受灾点的到达时间 popsize * n
global fitness                                                             % 所有个体的适应度值 1 * popsize
global damage                                                              % 每个受灾点的损失 popsize * n
global roadNum                                                             % 可选择的道路数量
global depot                                                               % 仓库编号
global nodeNum                                                             % 受灾点数量
global initialDeteriorationD                                               % 每条路的初始毁坏程度 (n+1) * (n+1) * 3
global s                                                                   % 各个点的服务时间

flag = 0;
% fitK = fitness(k);
routeK = route(:,:,k);
lengthRK = lengthR(k,:);
roadK = road(k,:);
damageK = damage(k,:);
arrivalTimeK = arrivalTime(k,:);

p = randperm(nodeNum,1);                                                   % 选择一个要变换道路的点
rd = 1;                                                                    % 选择通行速度最快的路
[row,col] = find(routeK == p);                                             % 找到p点所在的行和列
tempRoute = [depot routeK(row,1:lengthRK(row))];
if col == 1
    vkz = speedv(initialDeteriorationD(tempRoute(col),tempRoute(col + 1),rd));
else
    Rzt = Rt(rd,(arrivalTimeK(tempRoute(col)) + s(tempRoute(col))),tempRoute(col),tempRoute(col+1));
    vkz = speedv(Rzt);
end

for i = 2:roadNum
    if col == 1
        vkzNew = speedv(initialDeteriorationD(tempRoute(col),tempRoute(col + 1),i));
    else
        Rzt = Rt(i,(arrivalTimeK(tempRoute(col)) + s(tempRoute(col))),tempRoute(col),tempRoute(col+1));
        vkzNew = speedv(Rzt);
    end
    
    if vkzNew > vkz
        rd = i;
        vkz = vkzNew;
    end
end

roadK(p) = rd;
[fitK,damageKnew,roadKnew,arrivalTimeKnew] = objectiveK(routeK,lengthRK,roadK,arrivalTimeK,damageK,row);
if fitK < fitness(k)
    fitness(k) = fitK;
    damage(k,:) = damageKnew;
    road(k,:) = roadKnew;
    arrivalTime(k,:) = arrivalTimeKnew;
    route(:,:,k) = routeK;
    flag = 1;
end
end