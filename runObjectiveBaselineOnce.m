function result = runObjectiveBaselineOnce(modelName, caseName, carNumValue, seedValue, varargin)
% Greedy constructive baselines for model-comparison evidence.
p = inputParser;
addParameter(p, 'NumPeriods', 3);
addParameter(p, 'Qp', []);
addParameter(p, 'Tshift', []);
addParameter(p, 'PenaltyWeight', 10000);
parse(p, varargin{:});

global route road lengthR numR arrivalTime fitness damage popsize carNum roadNum
global depot nodeNum v demand s D maxLoad omega
global initialDeteriorationNode deteriorationRateNode recoveryRateNode
global initialDeteriorationD deteriorationRateD recoveryRateD
global deteriorationRateDMax recoveryRateDmin distance
global numPeriods Qp Tshift penaltyWeight totalCarNum

modelKey = lower(string(modelName));
validModels = ["cvrp", "ccvrp", "priority_initial", "priority_deterioration"];
if ~any(modelKey == validModels)
    error('runObjectiveBaselineOnce:UnknownModel', 'Unknown model baseline: %s', modelName);
end

rng(seedValue, 'twister');

nodeNum = 100;
depot = 101;
data = load([caseName '-para.txt']);
demand = data(:,4);
s = data(:,5);
D = zeros(nodeNum + 1, nodeNum + 1, 3);
D(:,:,1) = load([caseName '-Dshort.txt']);
D(:,:,2) = load([caseName '-D.txt']);
D(:,:,3) = load([caseName '-Dlong.txt']);

nodeData = load('nodeRate.txt');
initialDeteriorationNode = nodeData(:,1);
deteriorationRateNode = nodeData(:,2);
recoveryRateNode = nodeData(:,3);

initialDeteriorationD = zeros(nodeNum + 1, nodeNum + 1, 3);
deteriorationRateD = zeros(nodeNum + 1, nodeNum + 1, 3);
initialDeteriorationD(:,:,1) = load('initialDshort.txt');
initialDeteriorationD(:,:,2) = load('initialD.txt');
initialDeteriorationD(:,:,3) = load('initialDlong.txt');
deteriorationRateD(:,:,1) = load('deteriorationRateDshort.txt');
deteriorationRateD(:,:,2) = load('deteriorationRateD.txt');
deteriorationRateD(:,:,3) = load('deteriorationRateDlong.txt');
recoveryRateD = load('recoveryRateD.txt');

deteriorationRateDMax = 1;
recoveryRateDmin = 0.01;
omega = ones(1,nodeNum);
maxLoad = 200;
v = 1;

numPeriods = p.Results.NumPeriods;
if isempty(p.Results.Qp)
    Qp = ceil(sum(demand(1:nodeNum)) / numPeriods);
else
    Qp = p.Results.Qp;
end
if isempty(p.Results.Tshift)
    Tshift = 1440 / numPeriods;
else
    Tshift = p.Results.Tshift;
end
penaltyWeight = p.Results.PenaltyWeight;

popsize = 1;
carNum = carNumValue;
roadNum = 3;
totalCarNum = numPeriods * carNum;

route = zeros(totalCarNum,nodeNum,popsize);
road = ones(popsize,nodeNum);
numR = totalCarNum;
lengthR = zeros(popsize,totalCarNum);
arrivalTime = zeros(popsize,nodeNum);
damage = zeros(popsize,nodeNum);
fitness = zeros(1,popsize);
distance = zeros(1,popsize);

if modelKey == "cvrp"
    buildNearestDistanceRoutes();
elseif modelKey == "ccvrp"
    buildEarliestArrivalRoutes();
elseif modelKey == "priority_initial"
    buildPriorityRoutes(initialDeteriorationNode);
else
    buildPriorityRoutes(deteriorationRateNode);
end
initialObjective();

tic;
elapsedSeconds = toc;
globalBestRoute = route(:,:,1);
globalBestLengthR = lengthR(1,:);
globalBestRoad = road(1,:);
globalBestTime = arrivalTime(1,:);
globalBestDamage = damage(1,:);
globalBestNumR = numR(1);
routeIndexes = 1:globalBestNumR;
totalRoadDamage = roadDamage(globalBestRoute,globalBestLengthR,globalBestRoad,globalBestTime,routeIndexes);

periodLoad = zeros(1,numPeriods);
for routeIdx = 1:globalBestNumR
    periodIdx = ceil(routeIdx / carNum);
    if globalBestLengthR(routeIdx) > 0
        periodLoad(periodIdx) = periodLoad(periodIdx) + sum(demand(globalBestRoute(routeIdx,1:globalBestLengthR(routeIdx))));
    end
end

result = struct();
if modelKey == "priority_initial"
    result.modelName = 'PRIORITY-INITIAL';
elseif modelKey == "priority_deterioration"
    result.modelName = 'PRIORITY-DETERIORATION';
else
    result.modelName = upper(char(modelKey));
end
result.caseName = caseName;
result.carNum = carNum;
result.seed = seedValue;
result.iterMax = 0;
result.popsize = popsize;
result.numPeriods = numPeriods;
result.Qp = Qp;
result.bestFitness = fitness(1);
result.nodeDamage = sum(globalBestDamage .* omega);
result.roadDamage = totalRoadDamage;
result.totalDistance = routeDistance(globalBestRoute, globalBestLengthR, globalBestRoad);
result.totalCompletionTime = sum(globalBestTime);
result.nonEmptyRoutes = sum(globalBestLengthR(1:globalBestNumR) > 0);
result.avgArrivalTime = mean(globalBestTime(globalBestTime > 0));
result.maxArrivalTime = max(globalBestTime);
for periodIdx = 1:5
    if periodIdx <= numPeriods
        result.(['periodLoad' num2str(periodIdx)]) = periodLoad(periodIdx);
    else
        result.(['periodLoad' num2str(periodIdx)]) = 0;
    end
end
result.elapsedSeconds = elapsedSeconds;
end

function buildPriorityRoutes(priorityValues)
global route lengthR road nodeNum depot demand D maxLoad carNum numPeriods Qp Tshift s
[~, nodeOrder] = sort(priorityValues(1:nodeNum), 'descend');
routeLoad = zeros(1, carNum * numPeriods);
routeLast = depot * ones(1, carNum * numPeriods);
routeTime = zeros(1, carNum * numPeriods);
periodLoad = zeros(1, numPeriods);
for r = 1:numel(routeTime)
    routeTime(r) = (ceil(r / carNum) - 1) * Tshift;
end

for idx = 1:numel(nodeOrder)
    node = nodeOrder(idx);
    [bestRoute, foundFeasible] = bestPriorityRoute(node, routeLoad, routeLast, routeTime, periodLoad, true);
    if ~foundFeasible
        [bestRoute, foundFeasible] = bestPriorityRoute(node, routeLoad, routeLast, routeTime, periodLoad, false);
    end
    if ~foundFeasible
        [~, bestRoute] = min(routeLoad);
    end

    lengthR(1,bestRoute) = lengthR(1,bestRoute) + 1;
    route(bestRoute,lengthR(1,bestRoute),1) = node;
    road(1,node) = 1;
    routeLoad(bestRoute) = routeLoad(bestRoute) + demand(node);
    periodIdx = ceil(bestRoute / carNum);
    periodLoad(periodIdx) = periodLoad(periodIdx) + demand(node);
    routeTime(bestRoute) = routeTime(bestRoute) + D(routeLast(bestRoute), node, 1) + s(node);
    routeLast(bestRoute) = node;
end
end

function [bestRoute, foundFeasible] = bestPriorityRoute(node, routeLoad, routeLast, routeTime, periodLoad, requireInventory)
global demand D maxLoad carNum numPeriods Qp
bestScore = inf;
bestRoute = 1;
foundFeasible = false;
for r = 1:(carNum * numPeriods)
    periodIdx = ceil(r / carNum);
    if routeLoad(r) + demand(node) > maxLoad
        continue;
    end
    if requireInventory && ~isInventoryFeasible(periodLoad, periodIdx, demand(node), Qp)
        continue;
    end
    score = routeTime(r) + D(routeLast(r), node, 1);
    if score < bestScore
        bestScore = score;
        bestRoute = r;
        foundFeasible = true;
    end
end
end

function buildNearestDistanceRoutes()
global route lengthR road nodeNum depot demand D maxLoad carNum numPeriods Qp
unassigned = 1:nodeNum;
periodLoad = zeros(1,numPeriods);
for r = 1:(carNum * numPeriods)
    periodIdx = ceil(r / carNum);
    load = 0;
    current = depot;
    while ~isempty(unassigned)
        demandCandidates = demand(unassigned)';
        routeFeasible = demandCandidates + load <= maxLoad;
        inventoryFeasible = false(size(unassigned));
        for idx = 1:numel(unassigned)
            inventoryFeasible(idx) = isInventoryFeasible(periodLoad, periodIdx, demand(unassigned(idx)), Qp);
        end
        feasible = unassigned(routeFeasible & inventoryFeasible);
        if isempty(feasible)
            break;
        end
        [~, pos] = min(D(current, feasible, 1));
        node = feasible(pos);
        lengthR(1,r) = lengthR(1,r) + 1;
        route(r,lengthR(1,r),1) = node;
        road(1,node) = 1;
        load = load + demand(node);
        periodLoad(periodIdx) = periodLoad(periodIdx) + demand(node);
        current = node;
        unassigned(unassigned == node) = [];
    end
end
assignLeftovers(unassigned);
end

function buildEarliestArrivalRoutes()
global route lengthR road nodeNum depot demand D maxLoad carNum numPeriods Qp Tshift s
unassigned = 1:nodeNum;
routeLoad = zeros(1,carNum * numPeriods);
routeLast = depot * ones(1,carNum * numPeriods);
routeTime = zeros(1,carNum * numPeriods);
periodLoad = zeros(1,numPeriods);
for r = 1:numel(routeTime)
    routeTime(r) = (ceil(r / carNum) - 1) * Tshift;
end
while ~isempty(unassigned)
    bestScore = inf;
    bestNode = unassigned(1);
    bestRoute = 1;
    for idx = 1:numel(unassigned)
        node = unassigned(idx);
        for r = 1:(carNum * numPeriods)
            periodIdx = ceil(r / carNum);
            if routeLoad(r) + demand(node) > maxLoad || ~isInventoryFeasible(periodLoad, periodIdx, demand(node), Qp)
                continue;
            end
            previous = routeLast(r);
            travelTime = D(previous,node,1);
            score = routeTime(r) + travelTime;
            if score < bestScore
                bestScore = score;
                bestNode = node;
                bestRoute = r;
            end
        end
    end
    lengthR(1,bestRoute) = lengthR(1,bestRoute) + 1;
    route(bestRoute,lengthR(1,bestRoute),1) = bestNode;
    road(1,bestNode) = 1;
    routeLoad(bestRoute) = routeLoad(bestRoute) + demand(bestNode);
    periodIdx = ceil(bestRoute / carNum);
    periodLoad(periodIdx) = periodLoad(periodIdx) + demand(bestNode);
    routeTime(bestRoute) = bestScore + s(bestNode);
    routeLast(bestRoute) = bestNode;
    unassigned(unassigned == bestNode) = [];
end
end

function assignLeftovers(unassigned)
global route lengthR road demand maxLoad carNum numPeriods Qp
if isempty(unassigned)
    return;
end
periodLoad = zeros(1,numPeriods);
for r = 1:(carNum * numPeriods)
    periodIdx = ceil(r / carNum);
    if lengthR(1,r) > 0
        periodLoad(periodIdx) = periodLoad(periodIdx) + sum(demand(route(r,1:lengthR(1,r),1)));
    end
end
for idx = 1:numel(unassigned)
    node = unassigned(idx);
    bestRoute = 1;
    bestLoad = inf;
    foundFeasible = false;
    for r = 1:(carNum * numPeriods)
        periodIdx = ceil(r / carNum);
        currentLoad = 0;
        if lengthR(1,r) > 0
            currentLoad = sum(demand(route(r,1:lengthR(1,r),1)));
        end
        if currentLoad + demand(node) <= maxLoad && isInventoryFeasible(periodLoad, periodIdx, demand(node), Qp) && currentLoad < bestLoad
            bestRoute = r;
            bestLoad = currentLoad;
            foundFeasible = true;
        end
    end
    if ~foundFeasible
        bestLoad = inf;
        for r = 1:(carNum * numPeriods)
            currentLoad = 0;
            if lengthR(1,r) > 0
                currentLoad = sum(demand(route(r,1:lengthR(1,r),1)));
            end
            if currentLoad + demand(node) <= maxLoad && currentLoad < bestLoad
                bestRoute = r;
                bestLoad = currentLoad;
            end
        end
    end
    lengthR(1,bestRoute) = lengthR(1,bestRoute) + 1;
    route(bestRoute,lengthR(1,bestRoute),1) = node;
    road(1,node) = 1;
    periodIdx = ceil(bestRoute / carNum);
    periodLoad(periodIdx) = periodLoad(periodIdx) + demand(node);
end
end

function ok = isInventoryFeasible(periodLoad, periodIdx, loadToAdd, Qp)
candidate = periodLoad;
candidate(periodIdx) = candidate(periodIdx) + loadToAdd;
ok = true;
cumulativeLoad = 0;
for p = 1:numel(candidate)
    cumulativeLoad = cumulativeLoad + candidate(p);
    if isscalar(Qp)
        availableInventory = p * Qp;
    else
        availableInventory = sum(Qp(1:min(p, numel(Qp))));
    end
    if cumulativeLoad > availableInventory
        ok = false;
        return;
    end
end
end

function totalDistance = routeDistance(routeK, lengthRK, roadK)
global depot D
totalDistance = 0;
for r = 1:numel(lengthRK)
    if lengthRK(r) <= 0
        continue;
    end
    tempRoute = [depot routeK(r,1:lengthRK(r))];
    for j = 1:(numel(tempRoute)-1)
        totalDistance = totalDistance + D(tempRoute(j), tempRoute(j+1), roadK(tempRoute(j+1)));
    end
end
end
