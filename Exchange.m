function [flag,exchangeScoreNew] = Exchange(k,exchangeScore)
global route                                                               % 所有个体的路径 carNum * n * popsize   n为受灾点数量
global road                                                                % 所有个体的选择的行驶路线 popsize * n（通过道路z到i点）
global lengthR                                                             % 所有个体的每条道路的长度 popsize * n
global numR                                                                % 所有个体的路径数量 1 * popsize
global arrivalTime                                                         % 所有个体的每个受灾点的到达时间 popsize * n
global fitness                                                             % 所有个体的适应度值 1 * popsize
global damage                                                              % 每个受灾点的损失 popsize * n
global initialDeteriorationNode                                            % 每个点的初始毁坏程度 n * 1
global deteriorationRateNode                                               % 每个点的毁坏率 n * 1

flag = 0;
fitK = fitness(k);
routeK = route(:,:,k);
numRK = numR(k);
lengthRK = lengthR(k,:);
roadK = road(k,:);
damageK = damage(k,:);
arrivalTimeK = arrivalTime(k,:);
exchangeScoreNew = exchangeScore;

r1 = randperm(numRK,1);                                                    % 随机选择两条路
% === 添加以下检查：确保 r1 不是空路径 ===
while lengthRK(r1) < 1
    r1 = randperm(numRK,1);
end
r2 = randperm(numRK,1);
% === 添加以下检查：确保 r2 不是空路径且不等于 r1 ===
while r1 == r2 || lengthRK(r2) < 1
    r2 = randperm(numRK,1);
end


p1 = randperm(lengthRK(r1),1);
p2 = randperm(lengthRK(r2),1);

if arrivalTimeK(routeK(r1,p1)) < arrivalTimeK(routeK(r2,p2))
    s1 = p1;
    rs1 = r1;
    s2 = p2;
    rs2 = r2;
else
    s1 = p2;
    rs1 = r2;
    s2 = p1;
    rs2 = r1;
end

sumexchangeScore = sum(exchangeScore);
pexchangeScore = exchangeScore ./ sumexchangeScore;
mexchangeScore = cumsum(pexchangeScore);

rd = rand;
for i = 1:length(exchangeScore)
    if rd > mexchangeScore(i)
        continue;
    else
        beta = i;
        break;
    end
end

switch beta
    case 1
        if initialDeteriorationNode(routeK(rs1,s1)) < initialDeteriorationNode(routeK(rs2,s2))
            temp = routeK(rs1,s1);
            routeK(rs1,s1) = routeK(rs2,s2);
            routeK(rs2,s2) = temp;
            r = [rs1,rs2];
            [fitK,damageKnew,roadKnew,arrivalTimeKnew] = objectiveK(routeK,lengthRK,roadK,arrivalTimeK,damageK,r);
        end
    case 2
        if deteriorationRateNode(routeK(rs1,s1)) < deteriorationRateNode(routeK(rs2,s2))
            temp = routeK(rs1,s1);
            routeK(rs1,s1) = routeK(rs2,s2);
            routeK(rs2,s2) = temp;
            r = [rs1,rs2];
            [fitK,damageKnew,roadKnew,arrivalTimeKnew] = objectiveK(routeK,lengthRK,roadK,arrivalTimeK,damageK,r);
        end
    case 3
        temp = routeK(rs1,s1);
        routeK(rs1,s1) = routeK(rs2,s2);
        routeK(rs2,s2) = temp;
        r = [rs1,rs2];
        [fitK,damageKnew,roadKnew,arrivalTimeKnew] = objectiveK(routeK,lengthRK,roadK,arrivalTimeK,damageK,r);
end

if fitK < fitness(k)
    exchangeScore(beta) = exchangeScore(beta) + abs(fitness(k) - fitK) ./ fitness(k);
    exchangeScoreNew = exchangeScore;
    fitness(k) = fitK;
    damage(k,:) = damageKnew;
    road(k,:) = roadKnew;
    arrivalTime(k,:) = arrivalTimeKnew;
    route(:,:,k) = routeK;
    flag = 1;
end
end