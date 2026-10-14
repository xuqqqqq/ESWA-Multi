function result = runBaselineOnce(algorithmName, caseName, carNumValue, seedValue, iterMaxValue, popsizeValue, varargin)
% Unified runner for comparison baselines using the same data and objective.
p = inputParser;
addParameter(p, 'NumPeriods', 3);
addParameter(p, 'Qp', []);
addParameter(p, 'Tshift', []);
addParameter(p, 'PenaltyWeight', 10000);
addParameter(p, 'Pc', 0.5);
addParameter(p, 'Verbose', false);
addParameter(p, 'MaxEvaluations', inf);
addParameter(p, 'MaxSeconds', inf);
parse(p, varargin{:});

global route road lengthR numR arrivalTime fitness damage popsize carNum roadNum
global depot nodeNum v demand s D maxLoad omega
global initialDeteriorationNode deteriorationRateNode recoveryRateNode
global initialDeteriorationD deteriorationRateD recoveryRateD
global deteriorationRateDMax recoveryRateDmin distance
global numPeriods Qp Tshift penaltyWeight totalCarNum
global objectiveEvalCount
global objectiveMode

algorithmKey = lower(string(algorithmName));
if algorithmKey ~= "vns" && algorithmKey ~= "ima"
    error('runBaselineOnce:UnknownAlgorithm', 'Unknown baseline algorithm: %s', algorithmName);
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

popsize = popsizeValue;
iterMax = iterMaxValue;
carNum = carNumValue;
roadNum = 3;
totalCarNum = numPeriods * carNum;
maxEvaluations = p.Results.MaxEvaluations;
maxSeconds = p.Results.MaxSeconds;
objectiveEvalCount = 0;
objectiveMode = 'dynamic_damage';
solveTimer = tic;

route = zeros(totalCarNum,nodeNum,popsize);
road = zeros(popsize,nodeNum);
numR = zeros(1,popsize);
lengthR = zeros(popsize,totalCarNum);
arrivalTime = zeros(popsize,nodeNum);
damage = zeros(popsize,nodeNum);
fitness = zeros(1,popsize);
distance = zeros(1,popsize);

if algorithmKey == "vns"
    initialPopulationRandom();
else
    initialPopulationIMAStyle();
end
initialObjective();

swapScore = [1 1 1];
insertScore = [1 1 1];
exchangeScore = [1 1 1];
relocationScore = [1 1 1];

[globalBest,index] = min(fitness);
globalBestIndex = index;
globalBestRoute = route(:,:,index);
globalBestDamage = damage(index,:);
globalBestTime = arrivalTime(index,:);
globalBestRoad = road(index,:);
globalBestLengthR = lengthR(index,:);
globalBestNumR = numR(index);

Pc = p.Results.Pc;
trace = zeros(iterMax,1);
traceEvaluations = zeros(iterMax,1);
traceSeconds = zeros(iterMax,1);
completedGenerations = 0;
for t = 1:iterMax
    if objectiveEvalCount >= maxEvaluations || toc(solveTimer) >= maxSeconds
        break;
    end
    if algorithmKey == "vns"
        for k = 1:popsize
            alpha = 1;
            while alpha <= 5
                switch alpha
                    case 1
                        [flag,swapScore] = Swap(k,swapScore);
                    case 2
                        flag = Opt(k);
                    case 3
                        flag = OrOpt(k);
                    case 4
                        [flag,exchangeScore] = Exchange(k,exchangeScore);
                    case 5
                        [flag,relocationScore] = Relocate(k,relocationScore);
                end
                if flag == 1
                    alpha = 1;
                else
                    alpha = alpha + 1;
                end
            end
            runRoadSelection(k);
        end
    else
        localSearchCount = max(1, floor(popsize / 2));
        for k = 1:localSearchCount
            if popsize > 1 && rand < Pc
                candidateParents = setdiff(1:popsize, k);
                parentPool = candidateParents(randperm(numel(candidateParents), min(3, numel(candidateParents))));
                [~,bestParentIndex] = min(fitness(parentPool));
                crossover(k,parentPool(bestParentIndex));
            end

            alpha = 1;
            while alpha <= 4
                switch alpha
                    case 1
                        [flag,swapScore] = Swap(k,swapScore);
                    case 2
                        [flag,insertScore] = Insert(k,insertScore);
                    case 3
                        [flag,exchangeScore] = Exchange(k,exchangeScore);
                    case 4
                        [flag,relocationScore] = Relocate(k,relocationScore);
                end
                if flag == 1
                    alpha = 1;
                else
                    alpha = alpha + 1;
                end
            end
            runRoadSelection(k);
        end
    end

    [currentBest,index] = min(fitness);
    if currentBest < globalBest
        globalBest = currentBest;
        globalBestIndex = index;
        globalBestRoute = route(:,:,index);
        globalBestDamage = damage(index,:);
        globalBestTime = arrivalTime(index,:);
        globalBestRoad = road(index,:);
        globalBestLengthR = lengthR(index,:);
        globalBestNumR = numR(index);
        if p.Results.Verbose
            disp(['algorithm=', char(algorithmKey), ', iter=', num2str(t), ', best=', num2str(globalBest)]);
        end
    end
    trace(t) = globalBest;
    traceEvaluations(t) = objectiveEvalCount;
    traceSeconds(t) = toc(solveTimer);
    completedGenerations = t;
end
trace = trace(1:completedGenerations);
traceEvaluations = traceEvaluations(1:completedGenerations);
traceSeconds = traceSeconds(1:completedGenerations);
elapsedSeconds = toc(solveTimer);

routeIndexes = 1:globalBestNumR;
totalRoadDamage = roadDamage(globalBestRoute,globalBestLengthR,globalBestRoad,globalBestTime,routeIndexes);
totalDistance = 0;
for routeIdx = 1:globalBestNumR
    if globalBestLengthR(routeIdx) > 0
        tempRoute = [depot globalBestRoute(routeIdx,1:globalBestLengthR(routeIdx))];
        for edgeIdx = 1:(numel(tempRoute) - 1)
            totalDistance = totalDistance + D(tempRoute(edgeIdx),tempRoute(edgeIdx + 1),globalBestRoad(tempRoute(edgeIdx + 1)));
        end
    end
end
nonEmptyRoutes = sum(globalBestLengthR(1:globalBestNumR) > 0);
maxRouteLength = max(globalBestLengthR(1:globalBestNumR));
avgRouteLength = mean(globalBestLengthR(globalBestLengthR(1:globalBestNumR) > 0));
if isnan(avgRouteLength)
    avgRouteLength = 0;
end
avgArrivalTime = mean(globalBestTime(globalBestTime > 0));
maxArrivalTime = max(globalBestTime);
periodLoad = zeros(1,numPeriods);
capacityViolation = 0;
for routeIdx = 1:globalBestNumR
    periodIdx = ceil(routeIdx / carNum);
    if globalBestLengthR(routeIdx) > 0
        routeLoad = sum(demand(globalBestRoute(routeIdx,1:globalBestLengthR(routeIdx))));
        periodLoad(periodIdx) = periodLoad(periodIdx) + routeLoad;
        capacityViolation = capacityViolation + max(0, routeLoad - maxLoad);
    end
end
inventoryViolation = cumulativeInventoryViolation(periodLoad, Qp);

result = struct();
result.algorithm = upper(char(algorithmKey));
result.algorithmVersion = ['unified_' char(algorithmKey) '_v1'];
result.caseName = caseName;
result.carNum = carNum;
result.seed = seedValue;
result.iterMax = iterMax;
result.popsize = popsize;
result.maxEvaluations = maxEvaluations;
result.maxSeconds = maxSeconds;
result.evaluationCount = objectiveEvalCount;
result.generationsCompleted = completedGenerations;
result.numPeriods = numPeriods;
result.Qp = Qp;
result.bestFitness = globalBest;
result.nodeDamage = sum(globalBestDamage .* omega);
result.roadDamage = totalRoadDamage;
result.totalDistance = totalDistance;
result.bestNumRoutes = globalBestNumR;
result.nonEmptyRoutes = nonEmptyRoutes;
result.maxRouteLength = maxRouteLength;
result.avgRouteLength = avgRouteLength;
result.avgArrivalTime = avgArrivalTime;
result.maxArrivalTime = maxArrivalTime;
result.capacityViolation = capacityViolation;
result.inventoryViolation = inventoryViolation;
result.isFeasible = capacityViolation <= 1e-9 && inventoryViolation <= 1e-9;
for periodIdx = 1:5
    if periodIdx <= numPeriods
        result.(['periodLoad' num2str(periodIdx)]) = periodLoad(periodIdx);
    else
        result.(['periodLoad' num2str(periodIdx)]) = 0;
    end
end
result.elapsedSeconds = elapsedSeconds;
result.trace = trace;
result.traceEvaluations = traceEvaluations;
result.traceSeconds = traceSeconds;
result.bestRoute = globalBestRoute;
result.bestLengthR = globalBestLengthR;
result.bestRoad = globalBestRoad;
result.bestArrivalTime = globalBestTime;
result.bestDamage = globalBestDamage;
result.globalBestIndex = globalBestIndex;
end

function violation = cumulativeInventoryViolation(periodLoad, inventory)
violation = 0;
cumulativeLoad = 0;
cumulativeSupply = 0;
for periodIdx = 1:numel(periodLoad)
    cumulativeLoad = cumulativeLoad + periodLoad(periodIdx);
    if numel(inventory) == 1
        cumulativeSupply = cumulativeSupply + inventory;
    else
        cumulativeSupply = cumulativeSupply + inventory(periodIdx);
    end
    violation = violation + max(0, cumulativeLoad - cumulativeSupply);
end
end

function runRoadSelection(k)
beta = 1;
while beta
    if rand < 0.5
        flag = RandomlySelection(k);
    else
        flag = GreedySelection(k);
    end
    if ~flag
        beta = 0;
    end
end
end
