function outputFile = runRevisedSensitivity(mode)
% Revised period/inventory sensitivity with cleaner experimental controls.
% Period sensitivity keeps total supply and total fleet fixed while periods vary.
% Inventory sensitivity uses per-period supply Qp as the primary x-axis.
if nargin < 1 || isempty(mode)
    mode = 'quick';
end

switch lower(mode)
    case 'smoke'
        cases = {'C101-25'};
        repeats = 1;
        iterMax = 20;
        popsize = 6;
        periods = [2 3];
        inventoryFactors = [1.0 1.2];
        totalFleet = 60;
    case 'paper'
        cases = {'C101-25','r101-25','rc101-25'};
        repeats = 5;
        iterMax = 600;
        popsize = 10;
        periods = [2 3 4 5];
        inventoryFactors = [0.8 1.0 1.2 1.5];
        totalFleet = 60;
    case 'full'
        cases = {'C101-25','r101-25','rc101-25'};
        repeats = 15;
        iterMax = 3000;
        popsize = 20;
        periods = [2 3 4 5];
        inventoryFactors = [0.8 1.0 1.2 1.5];
        totalFleet = 60;
    otherwise
        cases = {'C101-25','r101-25','rc101-25'};
        repeats = 2;
        iterMax = 120;
        popsize = 8;
        periods = [2 3 4 5];
        inventoryFactors = [0.8 1.0 1.2];
        totalFleet = 60;
end

fixedInventoryPeriods = 3;
baseSeed = 13600;
rows = {};
rowIndex = 0;

if ~exist('results','dir')
    mkdir('results');
end

headers = {'mode','experiment','caseName','seed','iterMax','popsize', ...
    'numPeriods','carNumPerPeriod','totalVehicles','QpPerPeriod','totalSupply', ...
    'totalDemand','inventoryFactor','bestFitness','nodeDamage','roadDamage', ...
    'nonEmptyRoutes','avgArrivalTime','maxArrivalTime','periodLoad1','periodLoad2', ...
    'periodLoad3','periodLoad4','periodLoad5','elapsedSeconds'};
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
outputFile = fullfile('results', ['sensitivity_revised_' lower(mode) '_' timestamp '.csv']);

for c = 1:numel(cases)
    data = load([cases{c} '-para.txt']);
    totalDemand = sum(data(1:100,4));

    for pIdx = 1:numel(periods)
        periodCount = periods(pIdx);
        carNumPerPeriod = totalFleet / periodCount;
        if abs(carNumPerPeriod - round(carNumPerPeriod)) > eps
            error('runRevisedSensitivity:InvalidFleet', ...
                'totalFleet=%d cannot be evenly divided by periodCount=%d.', totalFleet, periodCount);
        end
        carNumPerPeriod = round(carNumPerPeriod);
        qPerPeriod = ceil(totalDemand / periodCount);

        for rep = 1:repeats
            seed = baseSeed + c * 1000 + pIdx * 100 + rep;
            fprintf('[period-fixed-fleet] case=%s periods=%d carPerPeriod=%d Qp=%d repeat=%d\n', ...
                cases{c}, periodCount, carNumPerPeriod, qPerPeriod, rep);
            result = runIHGAOnce(cases{c}, carNumPerPeriod, seed, iterMax, popsize, ...
                'NumPeriods', periodCount, 'Qp', qPerPeriod);
            rowIndex = rowIndex + 1;
            rows(rowIndex,:) = resultToRow(result, lower(mode), 'period_fixed_fleet', ...
                totalDemand, qPerPeriod / ceil(totalDemand / periodCount)); %#ok<AGROW>
            writeRows(rows, headers, outputFile);
        end
    end

    baseQp = ceil(totalDemand / fixedInventoryPeriods);
    carNumPerPeriod = totalFleet / fixedInventoryPeriods;
    if abs(carNumPerPeriod - round(carNumPerPeriod)) > eps
        error('runRevisedSensitivity:InvalidInventoryFleet', ...
            'totalFleet=%d cannot be evenly divided by fixedInventoryPeriods=%d.', totalFleet, fixedInventoryPeriods);
    end
    carNumPerPeriod = round(carNumPerPeriod);

    for fIdx = 1:numel(inventoryFactors)
        qPerPeriod = ceil(baseQp * inventoryFactors(fIdx));
        for rep = 1:repeats
            seed = baseSeed + c * 1000 + 500 + fIdx * 100 + rep;
            fprintf('[inventory-Qp] case=%s periods=%d carPerPeriod=%d Qp=%d factor=%.2f repeat=%d\n', ...
                cases{c}, fixedInventoryPeriods, carNumPerPeriod, qPerPeriod, inventoryFactors(fIdx), rep);
            result = runIHGAOnce(cases{c}, carNumPerPeriod, seed, iterMax, popsize, ...
                'NumPeriods', fixedInventoryPeriods, 'Qp', qPerPeriod);
            rowIndex = rowIndex + 1;
            rows(rowIndex,:) = resultToRow(result, lower(mode), 'inventory_qp', ...
                totalDemand, qPerPeriod / baseQp); %#ok<AGROW>
            writeRows(rows, headers, outputFile);
        end
    end
end

writeRows(rows, headers, outputFile);
fprintf('Saved %s\n', outputFile);
end

function row = resultToRow(result, mode, experiment, totalDemand, inventoryFactor)
totalVehicles = result.carNum * result.numPeriods;
totalSupply = result.Qp * result.numPeriods;
row = {mode, experiment, result.caseName, result.seed, result.iterMax, result.popsize, ...
    result.numPeriods, result.carNum, totalVehicles, result.Qp, totalSupply, totalDemand, ...
    inventoryFactor, result.bestFitness, result.nodeDamage, result.roadDamage, ...
    result.nonEmptyRoutes, result.avgArrivalTime, result.maxArrivalTime, result.periodLoad1, ...
    result.periodLoad2, result.periodLoad3, result.periodLoad4, result.periodLoad5, result.elapsedSeconds};
end

function writeRows(rows, headers, outputFile)
T = cell2table(rows, 'VariableNames', headers);
writetable(T, outputFile);
end
