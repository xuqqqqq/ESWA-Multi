function [flag,relocationScoreNew] = Relocate(k,relocationScore)
global route road lengthR numR arrivalTime fitness damage
global initialDeteriorationNode deteriorationRateNode demand maxLoad

flag = 0;
fitK = fitness(k);
routeK = route(:,:,k);
numRK = numR(k);
lengthRK = lengthR(k,:);
roadK = road(k,:);
damageK = damage(k,:);
arrivalTimeK = arrivalTime(k,:);
relocationScoreNew = relocationScore;

nonEmpty = find(lengthRK(1:numRK) > 0);
if numel(nonEmpty) < 2
    return;
end

r1 = nonEmpty(randperm(numel(nonEmpty),1));
r2 = nonEmpty(randperm(numel(nonEmpty),1));
while r1 == r2
    r2 = nonEmpty(randperm(numel(nonEmpty),1));
end

p1 = randperm(lengthRK(r1),1);
p2 = randperm(lengthRK(r2),1);

if arrivalTimeK(routeK(r1,p1)) < arrivalTimeK(routeK(r2,p2))
    s1 = p1; rs1 = r1;
    s2 = p2; rs2 = r2;
else
    s1 = p2; rs1 = r2;
    s2 = p1; rs2 = r1;
end

sumScore = sum(relocationScore);
scoreCum = cumsum(relocationScore ./ sumScore);
rd = rand;
beta = find(rd <= scoreCum, 1, 'first');
if isempty(beta)
    beta = numel(relocationScore);
end

success = 0;
switch beta
    case 1
        success = initialDeteriorationNode(routeK(rs1,s1)) < initialDeteriorationNode(routeK(rs2,s2));
    case 2
        success = deteriorationRateNode(routeK(rs1,s1)) < deteriorationRateNode(routeK(rs2,s2));
    otherwise
        if rand < 0.5
            temp = rs1; rs1 = rs2; rs2 = temp;
            temp = s1; s1 = s2; s2 = temp;
        end
        success = 1;
end

if ~success
    return;
end

nodeToMove = routeK(rs2,s2);
routeLoad = 0;
if lengthRK(rs1) > 0
    routeLoad = sum(demand(routeK(rs1,1:lengthRK(rs1))));
end
if routeLoad + demand(nodeToMove) > maxLoad
    return;
end

sourceNew = [routeK(rs2,1:s2-1), routeK(rs2,s2+1:lengthRK(rs2))];
targetNew = [routeK(rs1,1:s1-1), nodeToMove, routeK(rs1,s1:lengthRK(rs1))];

routeK(rs2,:) = 0;
routeK(rs2,1:numel(sourceNew)) = sourceNew;
lengthRK(rs2) = numel(sourceNew);

routeK(rs1,:) = 0;
routeK(rs1,1:numel(targetNew)) = targetNew;
lengthRK(rs1) = numel(targetNew);

rUpdate = unique([rs1,rs2]);
[fitKNew, damageKnew, roadKnew, arrivalTimeKnew] = objectiveK(routeK, lengthRK, roadK, arrivalTimeK, damageK, rUpdate);

if fitKNew < fitK
    relocationScoreNew(beta) = relocationScore(beta) + abs(fitK - fitKNew) / fitK;
    fitness(k) = fitKNew;
    damage(k,:) = damageKnew;
    road(k,:) = roadKnew;
    arrivalTime(k,:) = arrivalTimeKnew;
    route(:,:,k) = routeK;
    lengthR(k,:) = lengthRK;
    flag = 1;
end
end
