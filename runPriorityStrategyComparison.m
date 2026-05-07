function outputFile = runPriorityStrategyComparison(mode, caseFilter)
% Compare deterministic priority-only delivery strategies against IHGA summaries.
if nargin < 1 || isempty(mode)
    mode = 'quick';
end
if nargin < 2
    caseFilter = [];
end

switch lower(mode)
    case 'smoke'
        cases = {'C102-25'};
    case {'extended_quick','extended-quick','quick'}
        cases = extendedRepresentativeCases();
    case {'extended_full','extended-full','full'}
        cases = extendedAllCases();
    otherwise
        cases = {'C101-25','r101-25','rc101-25'};
end

if ~isempty(caseFilter)
    cases = normalizeCaseFilter(caseFilter);
end

strategies = {'priority_initial','priority_deterioration'};
carNum = 18;
baseSeed = 11800;
rows = {};
rowIndex = 0;

if ~exist('results','dir')
    mkdir('results');
end

for c = 1:numel(cases)
    seed = baseSeed + c * 1000 + 1;
    for s = 1:numel(strategies)
        fprintf('[priority-strategy] strategy=%s case=%s\n', strategies{s}, cases{c});
        result = runObjectiveBaselineOnce(strategies{s}, cases{c}, carNum, seed);
        rowIndex = rowIndex + 1;
        rows(rowIndex,:) = {lower(mode), result.modelName, cases{c}, carNum, seed, ...
            result.numPeriods, result.Qp, result.bestFitness, result.nodeDamage, result.roadDamage, ...
            result.totalDistance, result.totalCompletionTime, result.nonEmptyRoutes, ...
            result.avgArrivalTime, result.maxArrivalTime, result.periodLoad1, result.periodLoad2, ...
            result.periodLoad3, result.periodLoad4, result.periodLoad5, result.elapsedSeconds}; %#ok<AGROW>
    end
end

headers = {'mode','strategyName','caseName','carNum','seed','numPeriods','Qp', ...
    'dynamicDamageObjective','nodeDamage','roadDamage','totalDistance','totalCompletionTime', ...
    'nonEmptyRoutes','avgArrivalTime','maxArrivalTime','periodLoad1','periodLoad2','periodLoad3', ...
    'periodLoad4','periodLoad5','elapsedSeconds'};
T = cell2table(rows, 'VariableNames', headers);
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
outputFile = fullfile('results', ['priority_strategy_' lower(mode) '_' timestamp '.csv']);
writetable(T, outputFile);
fprintf('Saved %s\n', outputFile);
end

function cases = extendedRepresentativeCases()
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
    error('runPriorityStrategyComparison:InvalidCaseFilter', 'caseFilter must be a string or cell array.');
end
cases = cases(~cellfun(@isempty, cases));
end
