function flag = RandomlySelection(k)
global route                                                               % 所有个体的路径 carNum * n * popsize   n为受灾点数量
global road                                                                % 所有个体的选择的行驶路线 popsize * n（通过道路z到i点）
global lengthR                                                             % 所有个体的每条道路的长度 popsize * n
global arrivalTime                                                         % 所有个体的每个受灾点的到达时间 popsize * n
global fitness                                                             % 所有个体的适应度值 1 * popsize
global damage                                                              % 每个受灾点的损失 popsize * n
global roadNum                                                             % 可选择的道路数量
global nodeNum                                                             % 受灾点数量


flag = 0;
% fitK = fitness(k);
routeK = route(:,:,k);
lengthRK = lengthR(k,:);
roadK = road(k,:);
damageK = damage(k,:);
arrivalTimeK = arrivalTime(k,:);

p = randperm(nodeNum,1);                                                   % 选择一个要变换道路的点
rd = randperm(roadNum,1);                                                  % 随机变换到另一条道路
while roadK(p) == rd
    rd = randperm(roadNum,1);
end

[row,~] = find(routeK == p);                                               % 找到p点的路径位置（在第几条路，第几个位置）
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
