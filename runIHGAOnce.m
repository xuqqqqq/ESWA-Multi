function result = runIHGAOnce(caseName, carNumValue, seedValue, iterMaxValue, popsizeValue, varargin)
% Parameterized IHGA runner for repeatable experiments.
p = inputParser;
addParameter(p, 'NumPeriods', 3);
addParameter(p, 'Qp', []);
addParameter(p, 'Tshift', []);
addParameter(p, 'PenaltyWeight', 10000);
addParameter(p, 'Pc', 0.5);
addParameter(p, 'Verbose', false);
addParameter(p, 'WarmStart', []);
addParameter(p, 'OperatorProfile', 'full');
addParameter(p, 'EnableDamageCritical', []);
addParameter(p, 'EnablePeriodRelocate', []);
addParameter(p, 'EnableParallelRelocate', []);
addParameter(p, 'EnableRouteMerge', []);
addParameter(p, 'EnableRouteRebuild', []);
addParameter(p, 'EnablePolish', []);
parse(p, varargin{:});

global route road lengthR numR arrivalTime fitness damage popsize carNum roadNum
global depot nodeNum v demand s D maxLoad omega
global initialDeteriorationNode deteriorationRateNode recoveryRateNode
global initialDeteriorationD deteriorationRateD recoveryRateD
global deteriorationRateDMax recoveryRateDmin distance
global numPeriods Qp Tshift penaltyWeight totalCarNum

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
if numel(Qp) > 1
    Qp = Qp(:)';
    if numel(Qp) ~= numPeriods
        error('runIHGAOnce:InvalidInventoryVector', ...
            'Qp must be scalar or a vector with NumPeriods entries.');
    end
end
if isempty(p.Results.Tshift)
    Tshift = 1440 / numPeriods;
else
    Tshift = p.Results.Tshift;
end
penaltyWeight = p.Results.PenaltyWeight;
operatorProfile = normalizeOperatorProfile(p.Results.OperatorProfile);
operatorFlags = resolveOperatorFlags(operatorProfile, p.Results);
popsize = popsizeValue;
iterMax = iterMaxValue;
carNum = carNumValue;
roadNum = 3;
totalCarNum = numPeriods * carNum;

route = zeros(totalCarNum,nodeNum,popsize);
road = zeros(popsize,nodeNum);
numR = zeros(1,popsize);
lengthR = zeros(popsize,totalCarNum);
arrivalTime = zeros(popsize,nodeNum);
damage = zeros(popsize,nodeNum);
fitness = zeros(1,popsize);
distance = zeros(1,popsize);

initialPopulationV2();
warmStart = p.Results.WarmStart;
if ~isempty(warmStart) && isstruct(warmStart) && isfield(warmStart, 'bestRoute')
    oldCarNum = warmStart.carNum;
    oldNumPeriods = warmStart.numPeriods;
    oldRoute = warmStart.bestRoute;
    oldLengthR = warmStart.bestLengthR;

    route(:,:,1) = 0;
    lengthR(1,:) = 0;
    road(1,:) = 0;
    if isfield(warmStart, 'bestRoad')
        road(1,:) = warmStart.bestRoad;
    end
    numR(1) = totalCarNum;

    copyPeriods = min(numPeriods, oldNumPeriods);
    for pIdx = 1:copyPeriods
        oldFirst = (pIdx - 1) * oldCarNum + 1;
        newFirst = (pIdx - 1) * carNum + 1;
        copyRoutes = min(oldCarNum, carNum);
        for localRoute = 1:copyRoutes
            oldRouteIdx = oldFirst + localRoute - 1;
            newRouteIdx = newFirst + localRoute - 1;
            if oldRouteIdx <= numel(oldLengthR) && newRouteIdx <= totalCarNum
                len = oldLengthR(oldRouteIdx);
                if len > 0
                    route(newRouteIdx,1:len,1) = oldRoute(oldRouteIdx,1:len);
                    lengthR(1,newRouteIdx) = len;
                end
            end
        end
    end
end
initialObjective();

swapScore = [1 1 1];
insertScore = [1 1 1];
exchangeScore = [1 1 1];
relocationScore = [1 1 1];
operatorMax = 12;
aosScores = ones(1,operatorMax);

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
tic;
for t = 1:iterMax
    for k = 1:popsize
        if rand < Pc
            parents = randperm(popsize,3);
            while ismember(k,parents)
                parents = randperm(popsize,3);
            end
            [~,bestParentIndex] = min(fitness(parents));
            crossover(k,parents(bestParentIndex));
        end

        alphaSequence = buildOperatorSequence(aosScores, operatorFlags, carNum);
        alphaPos = 1;
        while alphaPos <= numel(alphaSequence)
            alpha = alphaSequence(alphaPos);
            switch alpha
                case 1
                    [flag,swapScore] = Swap(k,swapScore);
                case 2
                    [flag,insertScore] = Insert(k,insertScore);
                case 3
                    flag = Opt(k);
                case 4
                    flag = OrOpt(k);
                case 5
                    [flag,exchangeScore] = Exchange(k,exchangeScore);
                case 6
                    [flag,relocationScore] = Relocate(k,relocationScore);
                case 7
                    if operatorFlags.periodRelocate
                        flag = PeriodRelocate(k);
                    else
                        flag = 0;
                    end
                case 8
                    parallelProb = 0.35;
                    if operatorFlags.parallelRelocate && carNum >= 12 && rand < parallelProb
                        flag = ParallelRelocate(k);
                    else
                        flag = 0;
                    end
                case 9
                    mergeProb = 0;
                    if carNum >= 30
                        mergeProb = 0.75;
                    elseif carNum >= 12
                        mergeProb = 0.35;
                    end
                    if operatorFlags.routeMerge && rand < mergeProb
                        flag = RouteMerge(k);
                    else
                        flag = 0;
                    end
                case 10
                    rebuildProb = 0.5;
                    if operatorFlags.routeRebuild && rand < rebuildProb
                        flag = RouteRebuild(k);
                    else
                        flag = 0;
                    end
                case 11
                    criticalProb = 0.12 + 0.18 * (t > 0.4 * iterMax) + 0.15 * (t > 0.75 * iterMax);
                    if operatorFlags.damageCritical && rand < criticalProb
                        flag = DamageCriticalRelocate(k, 5, min(totalCarNum, 18));
                    else
                        flag = 0;
                    end
                case 12
                    criticalProb = 0.10 + 0.15 * (t > 0.4 * iterMax) + 0.15 * (t > 0.75 * iterMax);
                    if operatorFlags.damageCritical && rand < criticalProb
                        flag = DamageCriticalExchange(k, 5, min(totalCarNum, 18));
                    else
                        flag = 0;
                    end
            end
            if flag == 1
                alphaPos = 1;
            else
                alphaPos = alphaPos + 1;
            end
        end

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
            disp(['iter=',num2str(t),', best=',num2str(globalBest)]);
        end
    end
    if popsize > 1 && (mod(t,5) == 0 || t == 1)
        globalBestIndex = restoreGlobalBest(globalBestRoute, globalBestLengthR, globalBestRoad, ...
            globalBestTime, globalBestDamage, globalBest, globalBestNumR);
    end
    trace(t) = globalBest;
end

polishPasses = 2;
if carNum >= 30
    polishPasses = 4;
end
globalBestIndex = restoreGlobalBest(globalBestRoute, globalBestLengthR, globalBestRoad, ...
    globalBestTime, globalBestDamage, globalBest, globalBestNumR);
for pass = 1:polishPasses
    if ~operatorFlags.polish
        break;
    end
    improved = 0;
    if operatorFlags.damageCritical
        improved = max(improved, DamageCriticalRelocate(globalBestIndex, 8, min(totalCarNum, 30)));
        improved = max(improved, DamageCriticalExchange(globalBestIndex, 8, min(totalCarNum, 30)));
    end
    if operatorFlags.periodRelocate
        improved = max(improved, PeriodRelocate(globalBestIndex));
    end
    if carNum >= 12 && operatorFlags.routeMerge
        improved = max(improved, RouteMerge(globalBestIndex));
    end
    if carNum >= 12 && operatorFlags.parallelRelocate
        improved = max(improved, ParallelRelocate(globalBestIndex));
    end
    if operatorFlags.routeRebuild
        improved = max(improved, RouteRebuild(globalBestIndex));
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
    end
    if ~improved
        break;
    end
end
elapsedSeconds = toc;

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
for routeIdx = 1:globalBestNumR
    periodIdx = ceil(routeIdx / carNum);
    if globalBestLengthR(routeIdx) > 0
        periodLoad(periodIdx) = periodLoad(periodIdx) + sum(demand(globalBestRoute(routeIdx,1:globalBestLengthR(routeIdx))));
    end
end

result = struct();
result.algorithm = 'IHGA';
result.algorithmVersion = ['critical_damage_v2_' operatorProfile];
result.operatorProfile = operatorProfile;
result.operatorFlags = operatorFlags;
result.aosScores = aosScores;
result.caseName = caseName;
result.carNum = carNum;
result.seed = seedValue;
result.iterMax = iterMax;
result.popsize = popsize;
result.numPeriods = numPeriods;
result.Qp = Qp;
if numel(Qp) == 1
    result.totalSupply = Qp * numPeriods;
else
    result.totalSupply = sum(Qp);
end
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
for periodIdx = 1:5
    if periodIdx <= numPeriods
        result.(['periodLoad' num2str(periodIdx)]) = periodLoad(periodIdx);
    else
        result.(['periodLoad' num2str(periodIdx)]) = 0;
    end
end
result.elapsedSeconds = elapsedSeconds;
result.trace = trace;
result.bestRoute = globalBestRoute;
result.bestLengthR = globalBestLengthR;
result.bestRoad = globalBestRoad;
result.bestArrivalTime = globalBestTime;
result.bestDamage = globalBestDamage;
end

function eliteIndex = restoreGlobalBest(bestRoute, bestLengthR, bestRoad, bestArrivalTime, bestDamage, bestFitness, bestNumR)
global route road lengthR numR arrivalTime fitness damage

[~,eliteIndex] = max(fitness);
route(:,:,eliteIndex) = bestRoute;
lengthR(eliteIndex,:) = bestLengthR;
road(eliteIndex,:) = bestRoad;
arrivalTime(eliteIndex,:) = bestArrivalTime;
damage(eliteIndex,:) = bestDamage;
fitness(eliteIndex) = bestFitness;
numR(eliteIndex) = bestNumR;
end

function profile = normalizeOperatorProfile(profileValue)
profile = lower(strtrim(char(profileValue)));
profile = strrep(profile, '-', '_');
profile = strrep(profile, ' ', '_');
end

function flags = resolveOperatorFlags(profile, args)
flags = struct();
flags.damageCritical = true;
flags.periodRelocate = true;
flags.parallelRelocate = true;
flags.routeMerge = true;
flags.routeRebuild = true;
flags.polish = true;

switch profile
    case {'full','ihga','mp_ihga','proposed'}
        % Keep all proposed repair operators enabled.
    case {'base_hga','generic_hga','no_proposed','without_proposed'}
        flags.damageCritical = false;
        flags.periodRelocate = false;
        flags.parallelRelocate = false;
        flags.routeMerge = false;
        flags.routeRebuild = false;
        flags.polish = false;
    case {'no_damage_critical','without_damage_critical','wo_damage_critical'}
        flags.damageCritical = false;
    case {'no_period_relocate','no_period_relocation','without_period_relocate','wo_period_relocate'}
        flags.periodRelocate = false;
    case {'no_route_structure','no_route_repair','without_route_structure','wo_route_structure'}
        flags.parallelRelocate = false;
        flags.routeMerge = false;
        flags.routeRebuild = false;
    case {'no_parallel_relocate','without_parallel_relocate','wo_parallel_relocate'}
        flags.parallelRelocate = false;
    case {'no_route_merge','without_route_merge','wo_route_merge'}
        flags.routeMerge = false;
    case {'no_route_rebuild','without_route_rebuild','wo_route_rebuild'}
        flags.routeRebuild = false;
    case {'no_polish','without_polish','wo_polish'}
        flags.polish = false;
    otherwise
        error('runIHGAOnce:UnknownOperatorProfile', 'Unknown OperatorProfile: %s', profile);
end

flags.damageCritical = overrideFlag(flags.damageCritical, args.EnableDamageCritical);
flags.periodRelocate = overrideFlag(flags.periodRelocate, args.EnablePeriodRelocate);
flags.parallelRelocate = overrideFlag(flags.parallelRelocate, args.EnableParallelRelocate);
flags.routeMerge = overrideFlag(flags.routeMerge, args.EnableRouteMerge);
flags.routeRebuild = overrideFlag(flags.routeRebuild, args.EnableRouteRebuild);
flags.polish = overrideFlag(flags.polish, args.EnablePolish);
end

function seq = buildOperatorSequence(scores, flags, carNumValue)
eligible = 1:numel(scores);
keep = false(size(eligible));
for i = 1:numel(eligible)
    keep(i) = isOperatorEnabled(eligible(i), flags, carNumValue);
end
eligible = eligible(keep);
if isempty(eligible)
    seq = [];
    return;
end

seq = eligible;
end

function enabled = isOperatorEnabled(operatorId, flags, carNumValue)
global numPeriods
switch operatorId
    case {1,2,3,4,5,6}
        enabled = true;
    case 7
        enabled = flags.periodRelocate;
    case 8
        enabled = flags.parallelRelocate && carNumValue >= 12;
    case 9
        enabled = flags.routeMerge && carNumValue >= 12;
    case 10
        enabled = flags.routeRebuild;
    case {11,12}
        enabled = flags.damageCritical;
    otherwise
        enabled = false;
end
end

function value = overrideFlag(defaultValue, overrideValue)
if isempty(overrideValue)
    value = defaultValue;
else
    value = logical(overrideValue);
end
end
