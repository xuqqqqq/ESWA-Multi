function flag = OrOpt(k)
global route                                                               % 所有个体的路径 carNum * n * popsize   n为受灾点数量
global road                                                                % 所有个体的选择的行驶路线 popsize * n（通过道路z到i点）
global lengthR                                                             % 所有个体的每条道路的长度 popsize * n
global numR                                                                % 所有个体的路径数量 1 * popsize
global arrivalTime                                                         % 所有个体的每个受灾点的到达时间 popsize * n
global fitness                                                             % 所有个体的适应度值 1 * popsize
global damage                                                              % 每个受灾点的损失 popsize * n
% global initialDeteriorationNode                                            % 每个点的初始毁坏程度 n * 1
% global deteriorationRateNode                                               % 每个点的毁坏率 n * 1

flag = 0;
routeK = route(:,:,k);
numRK = numR(k);
lengthRK = lengthR(k,:);
roadK = road(k,:);
damageK = damage(k,:);
arrivalTimeK = arrivalTime(k,:);
fitK = fitness(k);

r = randperm(numRK,1);                                                     % 随机选择一条路
while lengthRK(r) <= 3
    r = randperm(numRK,1);
end

p1 = randperm(lengthRK(r),1);
p2 = randperm(lengthRK(r),1);
s1 = min(p1,p2);
s2 = max(p1,p2);
while s1 == s2 || s2 == lengthRK(r)
    p1 = randperm(lengthRK(r),1);
    p2 = randperm(lengthRK(r),1);
    s1 = min(p1,p2);
    s2 = max(p1,p2);
end

temp = [routeK(r,1:s1-1) routeK(r,s2:s2+1) routeK(r,s1:s2-1) routeK(r,s2+2:end)];
routeK(r,:) = temp;
[fitK,damageKnew,roadKnew,arrivalTimeKnew] = objectiveK(routeK,lengthRK,roadK,arrivalTimeK,damageK,r);


if fitK < fitness(k)
    fitness(k) = fitK;
    damage(k,:) = damageKnew;
    road(k,:) = roadKnew;
    arrivalTime(k,:) = arrivalTimeKnew;
    route(:,:,k) = routeK;
    flag = 1;
end
end

