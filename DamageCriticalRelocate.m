function flag = DamageCriticalRelocate(k, maxCandidates, maxTargetRoutes)
% Move high-loss customers to earlier feasible positions.
if nargin < 2 || isempty(maxCandidates)
    maxCandidates = 6;
end
if nargin < 3 || isempty(maxTargetRoutes)
    maxTargetRoutes = 18;
end

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
nodeInfo = [];
for r = 1:numRK
    if lengthRK(r) <= 0
        continue;
    end
    for pos = 1:lengthRK(r)
        node = routeK(r,pos);
        score = damageK(node) + 0.005 * arrivalTimeK(node) + 0.25 * urgency(node);
        nodeInfo = [nodeInfo; score, r, pos, node, ceil(r / carNum)]; %#ok<AGROW>
    end
end

if isempty(nodeInfo)
    return;
end

[~,order] = sort(nodeInfo(:,1), 'descend');
nodeInfo = nodeInfo(order(1:min(maxCandidates, numel(order))),:);

bestFitness = fitness(k);
bestRoute = routeK;
bestLengthR = lengthRK;
bestRoad = roadK;
bestArrivalTime = arrivalTimeK;
bestDamage = damageK;

for c = 1:size(nodeInfo,1)
    sourceRoute = nodeInfo(c,2);
    sourcePos = nodeInfo(c,3);
    nodeToMove = nodeInfo(c,4);
    sourcePeriod = nodeInfo(c,5);

    if sourceRoute > numRK || sourcePos > lengthRK(sourceRoute) || routeK(sourceRoute,sourcePos) ~= nodeToMove
        continue;
    end

    targetRoutes = rankedTargetRoutes(sourceRoute, sourcePeriod, nodeToMove);
    sourceBase = [routeK(sourceRoute,1:sourcePos-1), routeK(sourceRoute,sourcePos+1:lengthRK(sourceRoute))];

    for targetRoute = targetRoutes
        if targetRoute > numRK
            continue;
        end

        if targetRoute ~= sourceRoute
            targetLoad = routeLoad(targetRoute);
            if targetLoad + demand(nodeToMove) > maxLoad
                continue;
            end
            targetBase = routeK(targetRoute,1:lengthRK(targetRoute));
            insertPositions = 1:(lengthRK(targetRoute) + 1);
        else
            targetBase = sourceBase;
            insertPositions = 1:(numel(sourceBase) + 1);
        end

        for insertPos = insertPositions
            if targetRoute == sourceRoute
                targetNew = [targetBase(1:insertPos-1), nodeToMove, targetBase(insertPos:end)];
                if isequal(targetNew, routeK(sourceRoute,1:lengthRK(sourceRoute)))
                    continue;
                end
            else
                targetNew = [targetBase(1:insertPos-1), nodeToMove, targetBase(insertPos:end)];
            end

            candidateRoute = routeK;
            candidateLengthR = lengthRK;
            candidateRoad = roadK;
            candidateArrivalTime = arrivalTimeK;
            candidateDamage = damageK;

            candidateRoute(sourceRoute,:) = 0;
            if targetRoute == sourceRoute
                candidateRoute(sourceRoute,1:numel(targetNew)) = targetNew;
                candidateLengthR(sourceRoute) = numel(targetNew);
                affectedRoutes = sourceRoute;
            else
                candidateRoute(sourceRoute,1:numel(sourceBase)) = sourceBase;
                candidateLengthR(sourceRoute) = numel(sourceBase);

                candidateRoute(targetRoute,:) = 0;
                candidateRoute(targetRoute,1:numel(targetNew)) = targetNew;
                candidateLengthR(targetRoute) = numel(targetNew);
                affectedRoutes = unique([sourceRoute,targetRoute]);
            end

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

    function loadValue = routeLoad(routeIdx)
        if lengthRK(routeIdx) <= 0
            loadValue = 0;
        else
            loadValue = sum(demand(routeK(routeIdx,1:lengthRK(routeIdx))));
        end
    end

    function targetRoutes = rankedTargetRoutes(sourceRouteLocal, sourcePeriodLocal, nodeLocal)
        lastRoute = min(sourcePeriodLocal * carNum, numRK);
        candidates = 1:lastRoute;
        scores = zeros(1,numel(candidates));
        for idx = 1:numel(candidates)
            rLocal = candidates(idx);
            pLocal = ceil(rLocal / carNum);
            loadLocal = routeLoad(rLocal);
            capacityPenalty = 0;
            if rLocal ~= sourceRouteLocal && loadLocal + demand(nodeLocal) > maxLoad
                capacityPenalty = 1e6;
            end
            scores(idx) = pLocal * 1000 + loadLocal + 5 * lengthRK(rLocal) + capacityPenalty;
        end
        [~,targetOrder] = sort(scores, 'ascend');
        keep = candidates(targetOrder(1:min(maxTargetRoutes, numel(targetOrder))));
        targetRoutes = unique([sourceRouteLocal, keep], 'stable');
    end
end
