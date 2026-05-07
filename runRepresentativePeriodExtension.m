function outputFile = runRepresentativePeriodExtension(mode, caseFilter, repeatFilter)
% Representative multi-period extension on additional C/R/RC instances.
if nargin < 1 || isempty(mode)
    mode = 'quick';
end
if nargin < 2
    caseFilter = {};
end
if nargin < 3
    repeatFilter = [];
end

allCases = {'C102-25','C201-25','r102-25','r201-25','rc102-25','rc201-25'};

switch lower(mode)
    case 'smoke'
        cases = {'C102-25'};
        repeats = 1;
        iterMax = 20;
        popsize = 6;
        periods = [1 3];
    case {'paper_lite','paper-lite'}
        cases = allCases;
        repeats = 3;
        iterMax = 300;
        popsize = 8;
        periods = [1 3 5];
    case 'paper'
        cases = allCases;
        repeats = 5;
        iterMax = 600;
        popsize = 10;
        periods = [1 3 5];
    otherwise
        cases = allCases;
        repeats = 2;
        iterMax = 120;
        popsize = 8;
        periods = [1 3 5];
end

if ischar(caseFilter)
    caseFilter = {caseFilter};
end
if ~isempty(caseFilter)
    [isSelected, caseOrder] = ismember(caseFilter, allCases);
    if any(~isSelected)
        error('runRepresentativePeriodExtension:UnknownCase', 'Unknown case name in caseFilter.');
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
baseSeed = 43800;
rows = {};
rowIndex = 0;

if ~exist('results','dir')
    mkdir('results');
end

headers = {'mode','caseName','caseGroup','caseFamily','seed','iterMax','popsize', ...
    'numPeriods','scenario','carNumPerPeriod','totalVehicles','QpPerPeriod','totalSupply', ...
    'totalDemand','bestFitness','nodeDamage','roadDamage','totalDistance', ...
    'nonEmptyRoutes','avgArrivalTime','maxArrivalTime','periodLoad1','periodLoad2', ...
    'periodLoad3','periodLoad4','periodLoad5','elapsedSeconds'};
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
outputFile = fullfile('results', ['period_extension_' normalizeMode(mode) '_' timestamp '.csv']);

for c = 1:numel(cases)
    caseName = cases{c};
    caseOrdinal = caseOrder(c);
    data = load([caseName '-para.txt']);
    totalDemand = sum(data(1:100,4));

    for pIdx = 1:numel(periods)
        periodCount = periods(pIdx);
        carNumPerPeriod = totalFleet / periodCount;
        if abs(carNumPerPeriod - round(carNumPerPeriod)) > eps
            error('runRepresentativePeriodExtension:InvalidFleet', ...
                'totalFleet=%d cannot be evenly divided by periodCount=%d.', totalFleet, periodCount);
        end
        carNumPerPeriod = round(carNumPerPeriod);
        qPerPeriod = ceil(totalDemand / periodCount);

        for rep = repeatIndices
            seed = baseSeed + caseOrdinal * 1000 + pIdx * 100 + rep;
            fprintf('[period-extension] case=%s periods=%d carPerPeriod=%d Qp=%d repeat=%d\n', ...
                caseName, periodCount, carNumPerPeriod, qPerPeriod, rep);
            result = runIHGAOnce(caseName, carNumPerPeriod, seed, iterMax, popsize, ...
                'NumPeriods', periodCount, 'Qp', qPerPeriod);
            rowIndex = rowIndex + 1;
            rows(rowIndex,:) = resultToRow(result, lower(mode), totalDemand); %#ok<AGROW>
            writeRows(rows, headers, outputFile);
        end
    end
end

writeRows(rows, headers, outputFile);
fprintf('Saved %s\n', outputFile);
end

function row = resultToRow(result, mode, totalDemand)
caseGroup = extractCaseGroup(result.caseName);
caseFamily = extractCaseFamily(result.caseName);
totalVehicles = result.carNum * result.numPeriods;
scenario = 'Staged';
if result.numPeriods == 1
    scenario = 'Aggregate';
end
if numel(result.Qp) == 1
    totalSupply = result.Qp * result.numPeriods;
else
    totalSupply = sum(result.Qp);
end
row = {mode, result.caseName, caseGroup, caseFamily, result.seed, result.iterMax, result.popsize, ...
    result.numPeriods, scenario, result.carNum, totalVehicles, result.Qp, totalSupply, totalDemand, ...
    result.bestFitness, result.nodeDamage, result.roadDamage, result.totalDistance, ...
    result.nonEmptyRoutes, result.avgArrivalTime, result.maxArrivalTime, result.periodLoad1, ...
    result.periodLoad2, result.periodLoad3, result.periodLoad4, result.periodLoad5, result.elapsedSeconds};
end

function group = extractCaseGroup(caseName)
if startsWith(lower(caseName), 'rc')
    group = 'RC';
elseif startsWith(lower(caseName), 'r')
    group = 'R';
else
    group = 'C';
end
end

function family = extractCaseFamily(caseName)
parts = split(caseName, '-');
family = upper(parts{1});
end

function modeName = normalizeMode(mode)
modeName = lower(strrep(mode, '-', '_'));
end

function writeRows(rows, headers, outputFile)
T = cell2table(rows, 'VariableNames', headers);
writetable(T, outputFile);
end
