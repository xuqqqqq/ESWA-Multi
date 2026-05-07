function flag = DamageCriticalExchange(k, maxCandidates, maxTargetRoutes)
% Swap high-loss late customers with lower-loss earlier customers.
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
        nodeInfo = [nodeInfo; score, r, pos, node, ceil(r / carNum), arrivalTimeK(node)]; %#ok<AGROW>
    end
end

if size(nodeInfo,1) < 2
    return;
end

[~,order] = sort(nodeInfo(:,1), 'descend');
highNodes = nodeInfo(order(1:min(maxCandidates, numel(order))),:);

bestFitness = fitness(k);
bestRoute = routeK;
bestLengthR = lengthRK;
bestRoad = roadK;
bestArrivalTime = arrivalTimeK;
bestDamage = damageK;

for h = 1:size(highNodes,1)
    sourceScore = highNodes(h,1);
    sourceRoute = highNodes(h,2);
    sourcePos = highNodes(h,3);
    highNode = highNodes(h,4);
    sourcePeriod = highNodes(h,5);
    highArrival = highNodes(h,6);

    targetRoutes = rankedTargetRoutes(sourceRoute, sourcePeriod);
    for targetRoute = targetRoutes
        if targetRoute > numRK || lengthRK(targetRoute) <= 0
            continue;
        end
        for targetPos = 1:lengthRK(targetRoute)
            if targetRoute == sourceRoute && targetPos == sourcePos
                continue;
            end
            lowNode = routeK(targetRoute,targetPos);
            lowScore = damageK(lowNode) + 0.005 * arrivalTimeK(lowNode) + 0.25 * urgency(lowNode);
            if lowScore >= sourceScore || arrivalTimeK(lowNode) >= highArrival
                continue;
            end
            if ~capacityFeasible(sourceRoute, targetRoute, highNode, lowNode)
                continue;
            end

            candidateRoute = routeK;
            candidateLengthR = lengthRK;
            candidateRoad = roadK;
            candidateArrivalTime = arrivalTimeK;
            candidateDamage = damageK;

            candidateRoute(sourceRoute,sourcePos) = lowNode;
            candidateRoute(targetRoute,targetPos) = highNode;
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

if bestFitness < fitness(k)
    fitness(k) = bestFitness;
    route(:,:,k) = bestRoute;
    lengthR(k,:) = bestLengthR;
    road(k,:) = bestRoad;
    arrivalTime(k,:) = bestArrivalTime;
    damage(k,:) = bestDamage;
    flag = 1;
end

    function targetRoutes = rankedTargetRoutes(sourceRouteLocal, sourcePeriodLocal)
        lastRoute = min(sourcePeriodLocal * carNum, numRK);
        candidates = 1:lastRoute;
        scores = zeros(1,numel(candidates));
        for idx = 1:numel(candidates)
            rLocal = candidates(idx);
            pLocal = ceil(rLocal / carNum);
            scores(idx) = pLocal * 1000 + 5 * lengthRK(rLocal);
        end
        [~,targetOrder] = sort(scores, 'ascend');
        keep = candidates(targetOrder(1:min(maxTargetRoutes, numel(targetOrder))));
        targetRoutes = unique([sourceRouteLocal, keep], 'stable');
    end

    function ok = capacityFeasible(sourceRouteLocal, targetRouteLocal, highNodeLocal, lowNodeLocal)
        ok = true;
        if sourceRouteLocal == targetRouteLocal
            return;
        end
        sourceLoad = routeLoad(sourceRouteLocal) - demand(highNodeLocal) + demand(lowNodeLocal);
        targetLoad = routeLoad(targetRouteLocal) - demand(lowNodeLocal) + demand(highNodeLocal);
        ok = sourceLoad <= maxLoad && targetLoad <= maxLoad;
    end

    function loadValue = routeLoad(routeIdx)
        if lengthRK(routeIdx) <= 0
            loadValue = 0;
        else
            loadValue = sum(demand(routeK(routeIdx,1:lengthRK(routeIdx))));
        end
    end
end
