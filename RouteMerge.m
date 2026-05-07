function flag = RouteMerge(k)
global route road lengthR numR arrivalTime fitness damage carNum demand maxLoad D depot

flag = 0;
routeK = route(:,:,k);
lengthRK = lengthR(k,:);
roadK = road(k,:);
arrivalTimeK = arrivalTime(k,:);
damageK = damage(k,:);
numRK = numR(k);

bestFitness = fitness(k);
bestRoute = routeK;
bestLengthR = lengthRK;
bestRoad = roadK;
bestArrivalTime = arrivalTimeK;
bestDamage = damageK;

numPeriods = ceil(numRK / carNum);
for period = 1:numPeriods
    firstRoute = (period - 1) * carNum + 1;
    lastRoute = min(period * carNum, numRK);
    routesInPeriod = firstRoute:lastRoute;
    nonEmpty = routesInPeriod(lengthRK(routesInPeriod) > 0);
    if numel(nonEmpty) < 2
        continue;
    end

    [~,order] = sort(lengthRK(nonEmpty), 'ascend');
    sourceCandidates = nonEmpty(order(1:min(3,numel(order))));

    for sourceRoute = sourceCandidates
        sourceNodes = routeK(sourceRoute,1:lengthRK(sourceRoute));
        sourceLoad = sum(demand(sourceNodes));
        sourceHead = sourceNodes(1);

        targetCandidates = setdiff(nonEmpty, sourceRoute);
        targetScores = zeros(1,numel(targetCandidates));
        for i = 1:numel(targetCandidates)
            targetRoute = targetCandidates(i);
            targetTail = routeK(targetRoute,lengthRK(targetRoute));
            targetScores(i) = D(targetTail,sourceHead,2);
        end
        [~,targetOrder] = sort(targetScores, 'ascend');
        targetCandidates = targetCandidates(targetOrder(1:min(4,numel(targetOrder))));

        for targetRoute = targetCandidates
            targetNodes = routeK(targetRoute,1:lengthRK(targetRoute));
            targetLoad = sum(demand(targetNodes));
            if targetLoad + sourceLoad > maxLoad
                continue;
            end

            mergedOptions = {
                [targetNodes sourceNodes], ...
                [sourceNodes targetNodes]
            };

            for optionIdx = 1:numel(mergedOptions)
                mergedNodes = mergedOptions{optionIdx};
                candidateRoute = routeK;
                candidateLengthR = lengthRK;
                candidateRoad = roadK;
                candidateArrivalTime = arrivalTimeK;
                candidateDamage = damageK;

                candidateRoute(sourceRoute,:) = 0;
                candidateLengthR(sourceRoute) = 0;
                candidateRoute(targetRoute,:) = 0;
                candidateRoute(targetRoute,1:numel(mergedNodes)) = mergedNodes;
                candidateLengthR(targetRoute) = numel(mergedNodes);

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
