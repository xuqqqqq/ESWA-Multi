function flag = RouteRebuild(k)
global route road lengthR numR arrivalTime fitness damage D depot
global initialDeteriorationNode deteriorationRateNode recoveryRateNode

flag = 0;
routeK = route(:,:,k);
lengthRK = lengthR(k,:);
roadK = road(k,:);
arrivalTimeK = arrivalTime(k,:);
damageK = damage(k,:);
numRK = numR(k);

candidateRoutes = find(lengthRK(1:numRK) >= 4);
if isempty(candidateRoutes)
    return;
end

[~,order] = sort(lengthRK(candidateRoutes), 'descend');
candidateRoutes = candidateRoutes(order(1:min(3,numel(order))));

urgency = initialDeteriorationNode + deteriorationRateNode ./ max(recoveryRateNode, eps);
bestFitness = fitness(k);
bestRoute = routeK;
bestRoad = roadK;
bestArrivalTime = arrivalTimeK;
bestDamage = damageK;

for r = candidateRoutes
    nodes = routeK(r,1:lengthRK(r));

    [~,urgentOrder] = sort(urgency(nodes), 'descend');
    urgentRoute = nodes(urgentOrder);
    nnRoute = nearestNeighborRoute(nodes);
    routeOptions = {urgentRoute, nnRoute, fliplr(nnRoute)};

    for optionIdx = 1:numel(routeOptions)
        candidateRoute = routeK;
        candidateRoad = roadK;
        candidateArrivalTime = arrivalTimeK;
        candidateDamage = damageK;

        candidateRoute(r,1:lengthRK(r)) = routeOptions{optionIdx};
        [candidateFitness,candidateDamage,candidateRoad,candidateArrivalTime] = ...
            objectiveK(candidateRoute,lengthRK,candidateRoad,candidateArrivalTime,candidateDamage,r);

        if candidateFitness < bestFitness
            bestFitness = candidateFitness;
            bestRoute = candidateRoute;
            bestRoad = candidateRoad;
            bestArrivalTime = candidateArrivalTime;
            bestDamage = candidateDamage;
        end
    end
end

if bestFitness < fitness(k)
    fitness(k) = bestFitness;
    route(:,:,k) = bestRoute;
    road(k,:) = bestRoad;
    arrivalTime(k,:) = bestArrivalTime;
    damage(k,:) = bestDamage;
    flag = 1;
end

    function ordered = nearestNeighborRoute(nodes)
        remaining = nodes;
        ordered = zeros(1,numel(nodes));
        current = depot;
        for idx = 1:numel(nodes)
            distances = D(current,remaining,2);
            [~,bestIdx] = min(distances);
            ordered(idx) = remaining(bestIdx);
            current = remaining(bestIdx);
            remaining(bestIdx) = [];
        end
    end
end
