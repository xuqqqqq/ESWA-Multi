function outputFile = runMultiPeriodImportance(mode, caseFilter, repeatFilter)
% Supplemental experiments for showing why multi-period resource timing matters.
% 1) single_period_aggregate: all vehicles and inventory are available at time zero.
% 2) inventory_release_profile: same total inventory, different period-release profiles.
if nargin < 1 || isempty(mode)
    mode = 'quick';
end
if nargin < 2
    caseFilter = {};
end
if nargin < 3
    repeatFilter = [];
end

allCases = {'C101-25','r101-25','rc101-25'};

switch lower(mode)
    case 'smoke'
        cases = {'C101-25'};
        repeats = 1;
        iterMax = 20;
        popsize = 6;
        runAggregate = true;
        runProfiles = true;
    case 'paper'
        cases = allCases;
        repeats = 5;
        iterMax = 600;
        popsize = 10;
        runAggregate = true;
        runProfiles = false;
    case 'release_paper'
        cases = allCases;
        repeats = 5;
        iterMax = 600;
        popsize = 10;
        runAggregate = false;
        runProfiles = true;
    otherwise
        cases = allCases;
        repeats = 2;
        iterMax = 120;
        popsize = 8;
        runAggregate = true;
        runProfiles = true;
end

if ischar(caseFilter)
    caseFilter = {caseFilter};
end
if ~isempty(caseFilter)
    [isSelected, caseOrder] = ismember(caseFilter, allCases);
    if any(~isSelected)
        error('runMultiPeriodImportance:UnknownCase', 'Unknown case name in caseFilter.');
    end
    cases = allCases(caseOrder);
else
    [~, caseOrder] = ismember(cases, allCases);
end

repeatIndices = 1:repeats;
if ~isempty(repeatFilter)
    repeatIndices = repeatFilter;
end

totalFleet = 60;
baseSeed = 24600;
rows = {};
rowIndex = 0;

if ~exist('results','dir')
    mkdir('results');
end

headers = {'mode','experiment','releaseProfile','caseName','seed','iterMax','popsize', ...
    'numPeriods','carNumPerPeriod','totalVehicles','QpProfile','qPeriod1','qPeriod2', ...
    'qPeriod3','qPeriod4','qPeriod5','totalSupply','totalDemand','bestFitness', ...
    'nodeDamage','roadDamage','nonEmptyRoutes','avgArrivalTime','maxArrivalTime', ...
    'periodLoad1','periodLoad2','periodLoad3','periodLoad4','periodLoad5','elapsedSeconds'};
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
outputFile = fullfile('results', ['multiperiod_importance_' lower(mode) '_' timestamp '.csv']);

for c = 1:numel(cases)
    caseOrdinal = caseOrder(c);
    data = load([cases{c} '-para.txt']);
    totalDemand = sum(data(1:100,4));

    if runAggregate
        periodCount = 1;
        carNumPerPeriod = totalFleet;
        qVector = totalDemand;
        for rep = repeatIndices
            seed = baseSeed + caseOrdinal * 1000 + 100 + rep;
            fprintf('[single-period-aggregate] case=%s vehicles=%d Q=%d repeat=%d\n', ...
                cases{c}, carNumPerPeriod, qVector, rep);
            result = runIHGAOnce(cases{c}, carNumPerPeriod, seed, iterMax, popsize, ...
                'NumPeriods', periodCount, 'Qp', qVector);
            rowIndex = rowIndex + 1;
            rows(rowIndex,:) = resultToRow(result, lower(mode), 'single_period_aggregate', ...
                'all_at_start', totalDemand); %#ok<AGROW>
            writeRows(rows, headers, outputFile);
        end
    end

    if runProfiles
        periodCount = 3;
        carNumPerPeriod = totalFleet / periodCount;
        profiles = {
            'front_loaded', [0.50 0.30 0.20];
            'uniform',      [1/3  1/3  1/3 ];
            'back_loaded',  [0.20 0.30 0.50]
        };

        for profileIdx = 1:size(profiles,1)
            profileName = profiles{profileIdx,1};
            qVector = allocateInventory(totalDemand, profiles{profileIdx,2});
            for rep = repeatIndices
                seed = baseSeed + caseOrdinal * 1000 + 500 + profileIdx * 100 + rep;
                fprintf('[inventory-release] case=%s profile=%s Q=[%s] repeat=%d\n', ...
                    cases{c}, profileName, num2str(qVector), rep);
                result = runIHGAOnce(cases{c}, carNumPerPeriod, seed, iterMax, popsize, ...
                    'NumPeriods', periodCount, 'Qp', qVector);
                rowIndex = rowIndex + 1;
                rows(rowIndex,:) = resultToRow(result, lower(mode), 'inventory_release_profile', ...
                    profileName, totalDemand); %#ok<AGROW>
                writeRows(rows, headers, outputFile);
            end
        end
    end
end

writeRows(rows, headers, outputFile);
fprintf('Saved %s\n', outputFile);
end

function qVector = allocateInventory(totalDemand, weights)
weights = weights(:)' ./ sum(weights);
qVector = floor(totalDemand * weights);
remainder = totalDemand - sum(qVector);
[~,order] = sort(weights, 'descend');
for idx = 1:remainder
    qVector(order(mod(idx - 1, numel(order)) + 1)) = qVector(order(mod(idx - 1, numel(order)) + 1)) + 1;
end
end

function row = resultToRow(result, mode, experiment, releaseProfile, totalDemand)
qVector = result.Qp;
qPeriods = zeros(1,5);
qPeriods(1:numel(qVector)) = qVector;
totalVehicles = result.carNum * result.numPeriods;
row = {mode, experiment, releaseProfile, result.caseName, result.seed, result.iterMax, result.popsize, ...
    result.numPeriods, result.carNum, totalVehicles, qProfile(qVector), qPeriods(1), qPeriods(2), ...
    qPeriods(3), qPeriods(4), qPeriods(5), sum(qVector), totalDemand, result.bestFitness, ...
    result.nodeDamage, result.roadDamage, result.nonEmptyRoutes, result.avgArrivalTime, ...
    result.maxArrivalTime, result.periodLoad1, result.periodLoad2, result.periodLoad3, ...
    result.periodLoad4, result.periodLoad5, result.elapsedSeconds};
end

function label = qProfile(qVector)
label = strjoin(arrayfun(@num2str, qVector, 'UniformOutput', false), '|');
end

function writeRows(rows, headers, outputFile)
T = cell2table(rows, 'VariableNames', headers);
writetable(T, outputFile);
end
