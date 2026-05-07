function outputFile = runRevisedSensitivityResume(mode)
% Resume revised period/inventory sensitivity by appending missing rows.
if nargin < 1 || isempty(mode)
    mode = 'quick';
end

cfg = revisedSensitivityConfig(mode);
headers = {'mode','experiment','caseName','seed','iterMax','popsize', ...
    'numPeriods','carNumPerPeriod','totalVehicles','QpPerPeriod','totalSupply', ...
    'totalDemand','inventoryFactor','bestFitness','nodeDamage','roadDamage', ...
    'nonEmptyRoutes','avgArrivalTime','maxArrivalTime','periodLoad1','periodLoad2', ...
    'periodLoad3','periodLoad4','periodLoad5','elapsedSeconds'};

if ~exist('results','dir')
    mkdir('results');
end

outputFile = latestRevisedFile(mode);
if isempty(outputFile)
    timestamp = datestr(now, 'yyyymmdd_HHMMSS');
    outputFile = fullfile('results', ['sensitivity_revised_' lower(mode) '_' timestamp '.csv']);
    appendCsvLine(outputFile, headers);
end

completedKeys = loadCompletedKeys(outputFile);
fprintf('Resume file: %s\n', outputFile);
fprintf('Existing completed rows: %d\n', numel(completedKeys));

for c = 1:numel(cfg.cases)
    data = load([cfg.cases{c} '-para.txt']);
    totalDemand = sum(data(1:100,4));

    for pIdx = 1:numel(cfg.periods)
        periodCount = cfg.periods(pIdx);
        carNumPerPeriod = cfg.totalFleet / periodCount;
        if abs(carNumPerPeriod - round(carNumPerPeriod)) > eps
            error('runRevisedSensitivityResume:InvalidFleet', ...
                'totalFleet=%d cannot be evenly divided by periodCount=%d.', cfg.totalFleet, periodCount);
        end
        carNumPerPeriod = round(carNumPerPeriod);
        qPerPeriod = ceil(totalDemand / periodCount);

        for rep = 1:cfg.repeats
            seed = cfg.baseSeed + c * 1000 + pIdx * 100 + rep;
            key = makeKey('period_fixed_fleet', cfg.cases{c}, seed, periodCount, carNumPerPeriod, qPerPeriod);
            if any(completedKeys == key)
                continue;
            end
            fprintf('[period-fixed-fleet] case=%s periods=%d carPerPeriod=%d Qp=%d repeat=%d\n', ...
                cfg.cases{c}, periodCount, carNumPerPeriod, qPerPeriod, rep);
            result = runIHGAOnce(cfg.cases{c}, carNumPerPeriod, seed, cfg.iterMax, cfg.popsize, ...
                'NumPeriods', periodCount, 'Qp', qPerPeriod);
            row = resultToRow(result, lower(mode), 'period_fixed_fleet', ...
                totalDemand, qPerPeriod / ceil(totalDemand / periodCount));
            appendCsvLine(outputFile, row);
            completedKeys(end+1,1) = key; %#ok<AGROW>
        end
    end

    baseQp = ceil(totalDemand / cfg.fixedInventoryPeriods);
    carNumPerPeriod = cfg.totalFleet / cfg.fixedInventoryPeriods;
    if abs(carNumPerPeriod - round(carNumPerPeriod)) > eps
        error('runRevisedSensitivityResume:InvalidInventoryFleet', ...
            'totalFleet=%d cannot be evenly divided by fixedInventoryPeriods=%d.', ...
            cfg.totalFleet, cfg.fixedInventoryPeriods);
    end
    carNumPerPeriod = round(carNumPerPeriod);

    for fIdx = 1:numel(cfg.inventoryFactors)
        qPerPeriod = ceil(baseQp * cfg.inventoryFactors(fIdx));
        for rep = 1:cfg.repeats
            seed = cfg.baseSeed + c * 1000 + 500 + fIdx * 100 + rep;
            key = makeKey('inventory_qp', cfg.cases{c}, seed, cfg.fixedInventoryPeriods, carNumPerPeriod, qPerPeriod);
            if any(completedKeys == key)
                continue;
            end
            fprintf('[inventory-Qp] case=%s periods=%d carPerPeriod=%d Qp=%d factor=%.2f repeat=%d\n', ...
                cfg.cases{c}, cfg.fixedInventoryPeriods, carNumPerPeriod, qPerPeriod, cfg.inventoryFactors(fIdx), rep);
            result = runIHGAOnce(cfg.cases{c}, carNumPerPeriod, seed, cfg.iterMax, cfg.popsize, ...
                'NumPeriods', cfg.fixedInventoryPeriods, 'Qp', qPerPeriod);
            row = resultToRow(result, lower(mode), 'inventory_qp', totalDemand, qPerPeriod / baseQp);
            appendCsvLine(outputFile, row);
            completedKeys(end+1,1) = key; %#ok<AGROW>
        end
    end
end

fprintf('Saved %s\n', outputFile);
end

function cfg = revisedSensitivityConfig(mode)
switch lower(mode)
    case 'smoke'
        cfg.cases = {'C101-25'};
        cfg.repeats = 1;
        cfg.iterMax = 20;
        cfg.popsize = 6;
        cfg.periods = [2 3];
        cfg.inventoryFactors = [1.0 1.2];
        cfg.totalFleet = 60;
    case 'paper'
        cfg.cases = {'C101-25','r101-25','rc101-25'};
        cfg.repeats = 5;
        cfg.iterMax = 600;
        cfg.popsize = 10;
        cfg.periods = [2 3 4 5];
        cfg.inventoryFactors = [0.8 1.0 1.2 1.5];
        cfg.totalFleet = 60;
    case 'full'
        cfg.cases = {'C101-25','r101-25','rc101-25'};
        cfg.repeats = 15;
        cfg.iterMax = 3000;
        cfg.popsize = 20;
        cfg.periods = [2 3 4 5];
        cfg.inventoryFactors = [0.8 1.0 1.2 1.5];
        cfg.totalFleet = 60;
    otherwise
        cfg.cases = {'C101-25','r101-25','rc101-25'};
        cfg.repeats = 2;
        cfg.iterMax = 120;
        cfg.popsize = 8;
        cfg.periods = [2 3 4 5];
        cfg.inventoryFactors = [0.8 1.0 1.2];
        cfg.totalFleet = 60;
end
cfg.fixedInventoryPeriods = 3;
cfg.baseSeed = 13600;
end

function outputFile = latestRevisedFile(mode)
files = dir(fullfile('results', ['sensitivity_revised_' lower(mode) '_*.csv']));
if isempty(files)
    outputFile = '';
    return;
end
names = {files.name};
keep = cellfun(@(name) isempty(strfind(name, '_summary')), names); %#ok<STREMP>
files = files(keep);
if isempty(files)
    outputFile = '';
    return;
end
[~,idx] = max([files.datenum]);
outputFile = fullfile(files(idx).folder, files(idx).name);
end

function completedKeys = loadCompletedKeys(outputFile)
completedKeys = strings(0,1);
if ~exist(outputFile, 'file')
    return;
end
T = readtable(outputFile);
if isempty(T) || height(T) == 0
    return;
end
for i = 1:height(T)
    completedKeys(end+1,1) = makeKey(T.experiment(i), T.caseName(i), T.seed(i), ...
        T.numPeriods(i), T.carNumPerPeriod(i), T.QpPerPeriod(i)); %#ok<AGROW>
end
end

function key = makeKey(experiment, caseName, seed, numPeriods, carNumPerPeriod, qPerPeriod)
key = string(sprintf('%s|%s|%d|%d|%d|%d', char(string(experiment)), char(string(caseName)), ...
    round(seed), round(numPeriods), round(carNumPerPeriod), round(qPerPeriod)));
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

function appendCsvLine(outputFile, row)
fid = fopen(outputFile, 'a');
if fid < 0
    error('runRevisedSensitivityResume:OpenFailed', 'Cannot open %s for append.', outputFile);
end
cleanupObj = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', rowToCsv(row));
clear cleanupObj;
end

function line = rowToCsv(row)
parts = cell(1,numel(row));
for i = 1:numel(row)
    value = row{i};
    if isnumeric(value)
        parts{i} = num2str(value, '%.15g');
    else
        parts{i} = char(string(value));
    end
end
line = strjoin(parts, ',');
end
