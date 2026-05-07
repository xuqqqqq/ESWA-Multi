function outputFile = runAlgorithmComparison(mode, caseFilter, repeatFilter, algorithmFilter)
% Run fair algorithm-comparison experiments under the same objective.
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
    algorithmFilter = [];
end

switch lower(mode)
    case 'smoke'
        cases = {'C101-25'};
        carNums = 18;
        repeats = 1;
        iterMax = 20;
        popsizeMain = 6;
    case 'paper'
        cases = {'C101-25','r101-25','rc101-25'};
        carNums = 18;
        repeats = 5;
        iterMax = 600;
        popsizeMain = 10;
    case {'paper_lite','paper-lite'}
        cases = {'C101-25','r101-25','rc101-25'};
        carNums = 18;
        repeats = 3;
        iterMax = 300;
        popsizeMain = 8;
    case {'extended_quick','extended-quick'}
        cases = extendedRepresentativeCases();
        carNums = 18;
        repeats = 2;
        iterMax = 120;
        popsizeMain = 8;
    case {'extended_paper_lite','extended-paper-lite'}
        cases = extendedRepresentativeCases();
        carNums = 18;
        repeats = 3;
        iterMax = 300;
        popsizeMain = 8;
    case {'extended_paper','extended-paper'}
        cases = extendedRepresentativeCases();
        carNums = 18;
        repeats = 5;
        iterMax = 600;
        popsizeMain = 10;
    case {'extended_full','extended-full'}
        cases = extendedAllCases();
        carNums = 18;
        repeats = 5;
        iterMax = 600;
        popsizeMain = 10;
    case 'full'
        cases = {'C101-25','r101-25','rc101-25'};
        carNums = [12 18 30];
        repeats = 20;
        iterMax = 3000;
        popsizeMain = 20;
    otherwise
        cases = {'C101-25','r101-25','rc101-25'};
        carNums = 18;
        repeats = 3;
        iterMax = 120;
        popsizeMain = 8;
end

if ~isempty(caseFilter)
    cases = normalizeCaseFilter(caseFilter);
end
repeatValues = 1:repeats;
if ~isempty(repeatFilter)
    repeatValues = normalizeRepeatFilter(repeatFilter);
end

algorithms = {'VNS','IMA','IHGA'};
if ~isempty(algorithmFilter)
    algorithms = normalizeTextFilter(algorithmFilter);
end
rows = {};
rowIndex = 0;
baseSeed = 6200;

if ~exist('results','dir')
    mkdir('results');
end
headers = {'mode','algorithm','algorithmVersion','caseName','carNum','seed','iterMax','popsize','numPeriods','Qp', ...
    'bestFitness','nodeDamage','roadDamage','totalDistance','nonEmptyRoutes','maxRouteLength','avgRouteLength', ...
    'avgArrivalTime','maxArrivalTime','periodLoad1','periodLoad2','periodLoad3','periodLoad4','periodLoad5','elapsedSeconds'};
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
outputFile = fullfile('results', ['algorithm_comparison_' lower(mode) '_' timestamp '.csv']);

for c = 1:numel(cases)
    for cn = 1:numel(carNums)
        for rep = repeatValues
            seed = baseSeed + c * 1000 + cn * 100 + rep;
            for a = 1:numel(algorithms)
                algorithm = algorithms{a};
                fprintf('[%s] case=%s car=%d repeat=%d seed=%d\n', algorithm, cases{c}, carNums(cn), rep, seed);
                if strcmpi(algorithm,'IHGA')
                    result = runIHGAOnce(cases{c}, carNums(cn), seed, iterMax, popsizeMain);
                    result.algorithm = 'IHGA';
                elseif strcmpi(algorithm,'VNS')
                    result = runBaselineOnce('VNS', cases{c}, carNums(cn), seed, iterMax, 1);
                else
                    result = runBaselineOnce('IMA', cases{c}, carNums(cn), seed, iterMax, popsizeMain);
                end
                rowIndex = rowIndex + 1;
                rows(rowIndex,:) = resultToRow(result, lower(mode)); %#ok<AGROW>
                writeRows(rows, headers, outputFile);
            end
        end
    end
end

writeRows(rows, headers, outputFile);
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
    error('runAlgorithmComparison:InvalidCaseFilter', 'caseFilter must be a string or cell array.');
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
    error('runAlgorithmComparison:InvalidRepeatFilter', 'repeatFilter must be numeric or comma-separated text.');
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
    error('runAlgorithmComparison:InvalidTextFilter', 'Text filters must be a string or cell array.');
end
values = values(~cellfun(@isempty, values));
end

function row = resultToRow(result, mode)
row = {mode, result.algorithm, result.algorithmVersion, result.caseName, result.carNum, result.seed, ...
    result.iterMax, result.popsize, result.numPeriods, result.Qp, result.bestFitness, result.nodeDamage, ...
    result.roadDamage, result.totalDistance, result.nonEmptyRoutes, result.maxRouteLength, result.avgRouteLength, ...
    result.avgArrivalTime, result.maxArrivalTime, result.periodLoad1, result.periodLoad2, result.periodLoad3, ...
    result.periodLoad4, result.periodLoad5, result.elapsedSeconds};
end

function writeRows(rows, headers, outputFile)
T = cell2table(rows, 'VariableNames', headers);
writetable(T, outputFile);
end
