function flag = ParallelRelocate(k)
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
[~,sourceOrder] = sort(lengthRK(1:numRK), 'descend');
sourceOrder = sourceOrder(lengthRK(sourceOrder) > 1);
if isempty(sourceOrder)
    return;
end
sourceOrder = sourceOrder(1:min(2,numel(sourceOrder)));

bestFitness = fitness(k);
bestRoute = routeK;
bestLengthR = lengthRK;
bestRoad = roadK;
bestArrivalTime = arrivalTimeK;
bestDamage = damageK;

for sourceRoute = sourceOrder
    period = ceil(sourceRoute / carNum);
    firstRoute = (period - 1) * carNum + 1;
    lastRoute = min(period * carNum, numRK);

    nodes = routeK(sourceRoute,1:lengthRK(sourceRoute));
    [~,nodeOrder] = sort(urgency(nodes), 'descend');
    nodeOrder = nodeOrder(1:min(2,numel(nodeOrder)));

    for sourcePos = nodeOrder
        nodeToMove = routeK(sourceRoute,sourcePos);
        sourceNew = [routeK(sourceRoute,1:sourcePos-1), routeK(sourceRoute,sourcePos+1:lengthRK(sourceRoute))];

        for targetRoute = firstRoute:lastRoute
            if targetRoute == sourceRoute
                continue;
            end

            targetLoad = 0;
            if lengthRK(targetRoute) > 0
                targetLoad = sum(demand(routeK(targetRoute,1:lengthRK(targetRoute))));
            end
            if targetLoad + demand(nodeToMove) > maxLoad
                continue;
            end

            insertPositions = unique([1, lengthRK(targetRoute) + 1]);
            for insertPos = insertPositions
                candidateRoute = routeK;
                candidateLengthR = lengthRK;
                candidateRoad = roadK;
                candidateArrivalTime = arrivalTimeK;
                candidateDamage = damageK;

                targetBase = routeK(targetRoute,1:lengthRK(targetRoute));
                targetNew = [targetBase(1:insertPos-1), nodeToMove, targetBase(insertPos:end)];

                candidateRoute(sourceRoute,:) = 0;
                candidateRoute(sourceRoute,1:numel(sourceNew)) = sourceNew;
                candidateLengthR(sourceRoute) = numel(sourceNew);

                candidateRoute(targetRoute,:) = 0;
                candidateRoute(targetRoute,1:numel(targetNew)) = targetNew;
                candidateLengthR(targetRoute) = numel(targetNew);

                affectedRoutes = unique([sourceRoute,targetRoute]);
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
