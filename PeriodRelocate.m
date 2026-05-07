function flag = PeriodRelocate(k)
global route road lengthR numR arrivalTime fitness damage carNum
global demand maxLoad initialDeteriorationNode deteriorationRateNode recoveryRateNode

flag = 0;
routeK = route(:,:,k);
lengthRK = lengthR(k,:);
roadK = road(k,:);
arrivalTimeK = arrivalTime(k,:);
damageK = damage(k,:);
numRK = numR(k);

urgency = initialDeteriorationNode + deteriorationRateNode ./ max(recoveryRateNode, eps);
moveOptions = [];

for r = 1:numRK
    period = ceil(r / carNum);
    if period <= 1 || lengthRK(r) == 0
        continue;
    end
    for pos = 1:lengthRK(r)
        node = routeK(r,pos);
        moveOptions = [moveOptions; urgency(node), r, pos, node, period]; %#ok<AGROW>
    end
end

if isempty(moveOptions)
    return;
end

[~,order] = sort(moveOptions(:,1), 'descend');
topCount = min(8, numel(order));
selected = moveOptions(order(randperm(topCount,1)),:);
fromRoute = selected(2);
fromPos = selected(3);
nodeToMove = selected(4);
fromPeriod = selected(5);

baseSource = [routeK(fromRoute,1:fromPos-1), routeK(fromRoute,fromPos+1:lengthRK(fromRoute))];
bestFitness = fitness(k);
bestRoute = routeK;
bestLengthR = lengthRK;
bestRoad = roadK;
bestArrivalTime = arrivalTimeK;
bestDamage = damageK;

for targetPeriod = 1:(fromPeriod - 1)
    firstRoute = (targetPeriod - 1) * carNum + 1;
    lastRoute = min(targetPeriod * carNum, numRK);

    for toRoute = firstRoute:lastRoute
        if toRoute == fromRoute
            continue;
        end

        targetLoad = 0;
        if lengthRK(toRoute) > 0
            targetLoad = sum(demand(routeK(toRoute,1:lengthRK(toRoute))));
        end
        if targetLoad + demand(nodeToMove) > maxLoad
            continue;
        end

        for insertPos = 1:(lengthRK(toRoute) + 1)
            candidateRoute = routeK;
            candidateLengthR = lengthRK;
            candidateRoad = roadK;
            candidateArrivalTime = arrivalTimeK;
            candidateDamage = damageK;

            targetBase = routeK(toRoute,1:lengthRK(toRoute));
            targetNew = [targetBase(1:insertPos-1), nodeToMove, targetBase(insertPos:end)];

            candidateRoute(fromRoute,:) = 0;
            candidateRoute(fromRoute,1:numel(baseSource)) = baseSource;
            candidateLengthR(fromRoute) = numel(baseSource);

            candidateRoute(toRoute,:) = 0;
            candidateRoute(toRoute,1:numel(targetNew)) = targetNew;
            candidateLengthR(toRoute) = numel(targetNew);

            affectedRoutes = unique([fromRoute,toRoute]);
            [candidateFitness,candidateDamage,candidateRoad,candidateArrivalTime] = ...
                objectiveK(candidateRoute,candidateLengthR,candidateRoad,candidateArrivalTime,candidateDamage,affectedRoutes);

            if candidateFitness < bestFitness
                bestFitness = candidateFitness;
                bestRoute = candidateRoute;
                bestLengthR = candidateLengthR;
                bestRoad = candidateRoad;
                bestArrivalTime = candidateArrivalTime;
                bestDamage = candidateDamage;
            end
        end
    end
end

if bestFitness < fitness(k)
    fitness(k) = bestFitness;
    route(:,:,k) = bestRoute;
    lengthR(k,:) = bestLengthR;
    road(k,:) = bestRoad;
    arrivalTime(k,:) = bestArrivalTime;
    damage(k,:) = bestDamage;
    flag = 1;
end
end
