function outputFile = runModelComparison(mode, caseFilter, repeatFilter, modelFilter)
% Compare distance, cumulative-time, and dynamic-damage routing logic.
if nargin < 1 || isempty(mode)
    mode = 'quick';
end
if nargin < 2
    caseFilter = [];
end
if nargin < 3
    repeatFilter = [];
end
if nargin < 4
    modelFilter = [];
end

switch lower(mode)
    case 'smoke'
        cases = {'C101-25'};
        repeats = 1;
        iterMax = 20;
        popsize = 6;
    case 'paper'
        cases = {'C101-25','r101-25','rc101-25'};
        repeats = 5;
        iterMax = 600;
        popsize = 10;
    case {'paper_lite','paper-lite'}
        cases = {'C101-25','r101-25','rc101-25'};
        repeats = 3;
        iterMax = 300;
        popsize = 8;
    case {'extended_quick','extended-quick'}
        cases = extendedRepresentativeCases();
        repeats = 2;
        iterMax = 120;
        popsize = 8;
    case {'extended_paper_lite','extended-paper-lite'}
        cases = extendedRepresentativeCases();
        repeats = 3;
        iterMax = 300;
        popsize = 8;
    case {'extended_paper','extended-paper'}
        cases = extendedRepresentativeCases();
        repeats = 5;
        iterMax = 600;
        popsize = 10;
    case {'extended_full','extended-full'}
        cases = extendedAllCases();
        repeats = 5;
        iterMax = 600;
        popsize = 10;
    case 'full'
        cases = {'C101-25','r101-25','rc101-25'};
        repeats = 15;
        iterMax = 3000;
        popsize = 20;
    otherwise
        cases = {'C101-25','r101-25','rc101-25'};
        repeats = 2;
        iterMax = 120;
        popsize = 8;
end

if ~isempty(caseFilter)
    cases = normalizeCaseFilter(caseFilter);
end
repeatValues = 1:repeats;
if ~isempty(repeatFilter)
    repeatValues = normalizeRepeatFilter(repeatFilter);
end

models = {'CVRP','CCVRP','DDVRP-IHGA'};
if ~isempty(modelFilter)
    models = normalizeTextFilter(modelFilter);
end
carNum = 18;
baseSeed = 9500;
rows = {};
rowIndex = 0;

if ~exist('results','dir')
    mkdir('results');
end

for c = 1:numel(cases)
    for rep = repeatValues
        seed = baseSeed + c * 1000 + rep;
        for m = 1:numel(models)
            fprintf('[model] model=%s case=%s repeat=%d\n', models{m}, cases{c}, rep);
            if strcmp(models{m}, 'DDVRP-IHGA')
                result = runIHGAOnce(cases{c}, carNum, seed, iterMax, popsize);
                result.modelName = 'DDVRP-IHGA';
                result.totalCompletionTime = sum(result.bestArrivalTime);
            else
                result = runObjectiveBaselineOnce(models{m}, cases{c}, carNum, seed);
            end
            rowIndex = rowIndex + 1;
            rows(rowIndex,:) = {lower(mode), result.modelName, cases{c}, carNum, seed, result.iterMax, result.popsize, ...
                result.numPeriods, result.Qp, result.bestFitness, result.nodeDamage, result.roadDamage, ...
                result.totalDistance, result.totalCompletionTime, result.nonEmptyRoutes, result.avgArrivalTime, ...
                result.maxArrivalTime, result.periodLoad1, result.periodLoad2, result.periodLoad3, ...
                result.periodLoad4, result.periodLoad5, result.elapsedSeconds}; %#ok<AGROW>
        end
    end
end

headers = {'mode','modelName','caseName','carNum','seed','iterMax','popsize','numPeriods','Qp', ...
    'dynamicDamageObjective','nodeDamage','roadDamage','totalDistance','totalCompletionTime','nonEmptyRoutes', ...
    'avgArrivalTime','maxArrivalTime','periodLoad1','periodLoad2','periodLoad3','periodLoad4','periodLoad5','elapsedSeconds'};
T = cell2table(rows, 'VariableNames', headers);
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
outputFile = fullfile('results', ['model_comparison_' lower(mode) '_' timestamp '.csv']);
writetable(T, outputFile);
fprintf('Saved %s\n', outputFile);
end

function cases = extendedRepresentativeCases()
% Mirrors the paper's broad benchmark table, using available 25-node variants.
cases = {'C101-25','C102-25','C103-25', ...
    'r101-25','r102-25','r103-25', ...
    'rc101-25','rc102-25','rc103-25'};
end

function cases = extendedAllCases()
cases = {'C101-25','C102-25','C103-25','C201-25','C202-25','C203-25', ...
    'r101-25','r102-25','r103-25','r201-25','r202-25','r203-25', ...
    'rc101-25','rc102-25','rc103-25','rc201-25','rc202-25','rc203-25'};
end

function cases = normalizeCaseFilter(caseFilter)
if ischar(caseFilter) || isstring(caseFilter)
    caseText = char(caseFilter);
    if contains(caseText, ',')
        cases = strtrim(strsplit(caseText, ','));
    else
        cases = cellstr(string(caseFilter));
    end
elseif iscell(caseFilter)
    cases = caseFilter;
else
    error('runModelComparison:InvalidCaseFilter', 'caseFilter must be a string or cell array.');
end
cases = cases(~cellfun(@isempty, cases));
end

function repeatValues = normalizeRepeatFilter(repeatFilter)
if isnumeric(repeatFilter)
    repeatValues = repeatFilter;
elseif ischar(repeatFilter) || isstring(repeatFilter)
    parts = strtrim(strsplit(char(repeatFilter), ','));
    repeatValues = cellfun(@str2double, parts);
else
    error('runModelComparison:InvalidRepeatFilter', 'repeatFilter must be numeric or comma-separated text.');
end
repeatValues = repeatValues(~isnan(repeatValues));
end

function values = normalizeTextFilter(filterValue)
if ischar(filterValue) || isstring(filterValue)
    filterText = char(filterValue);
    if contains(filterText, ',')
        values = strtrim(strsplit(filterText, ','));
    else
        values = cellstr(string(filterValue));
    end
elseif iscell(filterValue)
    values = filterValue;
else
    error('runModelComparison:InvalidTextFilter', 'Text filters must be a string or cell array.');
end
values = values(~cellfun(@isempty, values));
end
