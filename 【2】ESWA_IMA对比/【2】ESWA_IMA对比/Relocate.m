function flag = Relocate(k)
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
fitK = fitness(k);
routeK = route(:,:,k);
numRK = numR(k);
lengthRK = lengthR(k,:);
roadK = road(k,:);
damageK = damage(k,:);
arrivalTimeK = arrivalTime(k,:);

% --- 防空载越界保护 ---
r1 = randperm(numRK,1);                                                    
while lengthRK(r1) < 1
    r1 = randperm(numRK,1);
end
r2 = randperm(numRK,1);
while r1 == r2 || lengthRK(r2) < 1 % 因为下面用到了p2，所以r2也不能为空
    r2 = randperm(numRK,1);
end

p1 = randperm(lengthRK(r1),1);
p2 = randperm(lengthRK(r2),1);

temp2 = [routeK(r2,1:p2-1) routeK(r2,p2+1:end) 0];
temp2_lengthRK = lengthRK(r2) - 1;
temp1 = [routeK(r1,1:p1-1) routeK(r2,p2) routeK(r1,p1:end-1)];
temp1_lengthRK = lengthRK(r1) + 1;
if temp2_lengthRK == 0
    routeK(r1,:) = temp1;
    lengthRK(r1) = temp1_lengthRK;
    routeK(r2,:) = routeK(numRK,:);
    lengthRK(r2) = lengthRK(numRK);
    routeK(numRK,:) = 0;
    lengthRK(numRK) = 0;
    numRK = numRK - 1;
    r = 1:numRK;
else
    routeK(r1,:) = temp1;
    lengthRK(r1) = temp1_lengthRK;
    routeK(r2,:) = temp2;
    lengthRK(r2) = temp2_lengthRK;
    r = [r1,r2];
end
[fitKNew,damageKnew,roadKnew,arrivalTimeKnew] = objectiveK(routeK,lengthRK,roadK,arrivalTimeK,damageK,r);

if fitKNew < fitness(k)
    fitness(k) = fitKNew;
    damage(k,:) = damageKnew;
    road(k,:) = roadKnew;
    arrivalTime(k,:) = arrivalTimeKnew;
    route(:,:,k) = routeK;
    numR(k) = numRK;
    lengthR(k,:) = lengthRK;
    flag = 1;
end
end