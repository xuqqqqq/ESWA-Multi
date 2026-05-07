function outputFile = runAdditionalSensitivity(mode)
% Sensitivity of planning periods and period inventory supply.
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
        qFactors = [1.0 1.2];
    case 'paper'
        cases = {'C101-25','r101-25','rc101-25'};
        repeats = 5;
        iterMax = 600;
        popsize = 10;
        periods = [2 3 4 5];
        qFactors = [0.8 1.0 1.2 1.5];
    case 'full'
        cases = {'C101-25','r101-25','rc101-25'};
        repeats = 15;
        iterMax = 3000;
        popsize = 20;
        periods = [2 3 4 5];
        qFactors = [0.8 1.0 1.2 1.5];
    otherwise
        cases = {'C101-25','r101-25','rc101-25'};
        repeats = 2;
        iterMax = 120;
        popsize = 8;
        periods = [2 3 4 5];
        qFactors = [0.8 1.0 1.2];
end

carNum = 18;
baseSeed = 7300;
rows = {};
rowIndex = 0;

if ~exist('results','dir')
    mkdir('results');
end

for c = 1:numel(cases)
    data = load([cases{c} '-para.txt']);
    totalDemand = sum(data(1:100,4));

    for pIdx = 1:numel(periods)
        for rep = 1:repeats
            seed = baseSeed + c * 1000 + pIdx * 100 + rep;
            fprintf('[period] case=%s periods=%d repeat=%d\n', cases{c}, periods(pIdx), rep);
            result = runIHGAOnce(cases{c}, carNum, seed, iterMax, popsize, 'NumPeriods', periods(pIdx));
            rowIndex = rowIndex + 1;
            rows(rowIndex,:) = resultToSensitivityRow(result, lower(mode), 'period_count', periods(pIdx), 1.0); %#ok<AGROW>
        end
    end

    baseQp = ceil(totalDemand / 3);
    for fIdx = 1:numel(qFactors)
        qValue = ceil(baseQp * qFactors(fIdx));
        for rep = 1:repeats
            seed = baseSeed + c * 1000 + 500 + fIdx * 100 + rep;
            fprintf('[inventory] case=%s Qp=%d factor=%.2f repeat=%d\n', cases{c}, qValue, qFactors(fIdx), rep);
            result = runIHGAOnce(cases{c}, carNum, seed, iterMax, popsize, 'NumPeriods', 3, 'Qp', qValue);
            rowIndex = rowIndex + 1;
            rows(rowIndex,:) = resultToSensitivityRow(result, lower(mode), 'inventory_supply', qValue, qFactors(fIdx)); %#ok<AGROW>
        end
    end
end

headers = {'mode','experiment','caseName','carNum','seed','iterMax','popsize','numPeriods','Qp','level','factor', ...
    'bestFitness','nodeDamage','roadDamage','nonEmptyRoutes','avgArrivalTime','maxArrivalTime', ...
    'periodLoad1','periodLoad2','periodLoad3','periodLoad4','periodLoad5','elapsedSeconds'};
T = cell2table(rows, 'VariableNames', headers);
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
outputFile = fullfile('results', ['sensitivity_period_inventory_' lower(mode) '_' timestamp '.csv']);
writetable(T, outputFile);
fprintf('Saved %s\n', outputFile);
end

function row = resultToSensitivityRow(result, mode, experiment, level, factor)
row = {mode, experiment, result.caseName, result.carNum, result.seed, result.iterMax, result.popsize, ...
    result.numPeriods, result.Qp, level, factor, result.bestFitness, result.nodeDamage, result.roadDamage, ...
    result.nonEmptyRoutes, result.avgArrivalTime, result.maxArrivalTime, result.periodLoad1, result.periodLoad2, ...
    result.periodLoad3, result.periodLoad4, result.periodLoad5, result.elapsedSeconds};
end
