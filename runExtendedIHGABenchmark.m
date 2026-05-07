function outputFile = runExtendedIHGABenchmark(mode, caseFilter, repeatFilter)
% Extended IHGA robustness benchmark over the available 25-node instances.
if nargin < 1 || isempty(mode)
    mode = 'quick';
end
if nargin < 2
    caseFilter = {};
end
if nargin < 3
    repeatFilter = [];
end

allCases = {'C101-25','C102-25','C103-25','C201-25','C202-25','C203-25', ...
    'r101-25','r102-25','r103-25','r201-25','r202-25','r203-25', ...
    'rc101-25','rc102-25','rc103-25','rc201-25','rc202-25','rc203-25'};

switch lower(mode)
    case 'smoke'
        cases = {'C102-25'};
        repeats = 1;
        iterMax = 20;
        popsize = 6;
    case {'paper_lite','paper-lite'}
        cases = allCases;
        repeats = 3;
        iterMax = 300;
        popsize = 8;
    case 'paper'
        cases = allCases;
        repeats = 5;
        iterMax = 600;
        popsize = 10;
    otherwise
        cases = allCases;
        repeats = 2;
        iterMax = 120;
        popsize = 8;
end

if ischar(caseFilter)
    caseFilter = {caseFilter};
end
if ~isempty(caseFilter)
    [isSelected, caseOrder] = ismember(caseFilter, allCases);
    if any(~isSelected)
        error('runExtendedIHGABenchmark:UnknownCase', 'Unknown case name in caseFilter.');
    end
    cases = allCases(caseOrder);
else
    [~, caseOrder] = ismember(cases, allCases);
end

repeatIndices = 1:repeats;
if ~isempty(repeatFilter)
    repeatIndices = repeatFilter;
end

carNum = 18;
baseSeed = 38200;
rows = {};
rowIndex = 0;

if ~exist('results','dir')
    mkdir('results');
end

headers = {'mode','caseName','caseGroup','caseFamily','seed','iterMax','popsize', ...
    'numPeriods','carNumPerPeriod','totalVehicles','QpPerPeriod','totalSupply', ...
    'totalDemand','bestFitness','nodeDamage','roadDamage','totalDistance', ...
    'nonEmptyRoutes','avgArrivalTime','maxArrivalTime','periodLoad1','periodLoad2', ...
    'periodLoad3','periodLoad4','periodLoad5','elapsedSeconds'};
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
outputFile = fullfile('results', ['extended_ihga_' normalizeMode(mode) '_' timestamp '.csv']);

for c = 1:numel(cases)
    caseName = cases{c};
    caseOrdinal = caseOrder(c);
    data = load([caseName '-para.txt']);
    totalDemand = sum(data(1:100,4));

    for rep = repeatIndices
        seed = baseSeed + caseOrdinal * 1000 + rep;
        fprintf('[extended-IHGA] case=%s repeat=%d seed=%d\n', caseName, rep, seed);
        result = runIHGAOnce(caseName, carNum, seed, iterMax, popsize);
        rowIndex = rowIndex + 1;
        rows(rowIndex,:) = resultToRow(result, lower(mode), totalDemand); %#ok<AGROW>
        writeRows(rows, headers, outputFile);
    end
end

writeRows(rows, headers, outputFile);
fprintf('Saved %s\n', outputFile);
end

function row = resultToRow(result, mode, totalDemand)
caseGroup = extractCaseGroup(result.caseName);
caseFamily = extractCaseFamily(result.caseName);
totalVehicles = result.carNum * result.numPeriods;
if numel(result.Qp) == 1
    qPerPeriod = result.Qp;
    totalSupply = result.Qp * result.numPeriods;
else
    qPerPeriod = result.Qp(1);
    totalSupply = sum(result.Qp);
end
row = {mode, result.caseName, caseGroup, caseFamily, result.seed, result.iterMax, result.popsize, ...
    result.numPeriods, result.carNum, totalVehicles, qPerPeriod, totalSupply, totalDemand, ...
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
