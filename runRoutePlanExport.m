function routeFile = runRoutePlanExport(mode, caseFilter)
% Export a machine-readable best IHGA route plan for route-map figures.
if nargin < 1 || isempty(mode)
    mode = 'smoke';
end
if nargin < 2
    caseFilter = [];
end

switch lower(mode)
    case 'smoke'
        cases = {'C101-25'};
        iterMax = 40;
        popsize = 6;
    case {'quick','paper_lite','paper-lite'}
        cases = {'C101-25','r101-25','rc101-25'};
        iterMax = 300;
        popsize = 8;
    case 'paper'
        cases = {'C101-25','r101-25','rc101-25'};
        iterMax = 600;
        popsize = 10;
    otherwise
        cases = {'C101-25'};
        iterMax = 40;
        popsize = 6;
end

if ~isempty(caseFilter)
    cases = normalizeCaseFilter(caseFilter);
end

if ~exist('results','dir')
    mkdir('results');
end

carNum = 18;
baseSeed = 16600;
routeRows = {};
summaryRows = {};
routeRowIndex = 0;
summaryRowIndex = 0;

for c = 1:numel(cases)
    seed = baseSeed + c * 1000 + 1;
    fprintf('[route-export] case=%s seed=%d\n', cases{c}, seed);
    result = runIHGAOnce(cases{c}, carNum, seed, iterMax, popsize);
    [routeRows, routeRowIndex, summaryRows, summaryRowIndex] = appendRouteRows( ...
        routeRows, routeRowIndex, summaryRows, summaryRowIndex, lower(mode), result);
end

timestamp = datestr(now, 'yyyymmdd_HHMMSS');
routeFile = fullfile('results', ['route_plan_' lower(mode) '_' timestamp '.csv']);
summaryFile = fullfile('results', ['route_plan_' lower(mode) '_' timestamp '_summary.csv']);

routeHeaders = {'mode','caseName','seed','routeIdx','periodIdx','position','node','demand', ...
    'arrivalTime','nodeDamage','roadType'};
summaryHeaders = {'mode','caseName','seed','routeIdx','periodIdx','routeLength','routeLoad', ...
    'routeLastArrival','routeNodeDamage'};
routeTable = cell2table(routeRows, 'VariableNames', routeHeaders);
summaryTable = cell2table(summaryRows, 'VariableNames', summaryHeaders);
writetable(routeTable, routeFile);
writetable(summaryTable, summaryFile);
fprintf('Saved %s\n', routeFile);
fprintf('Saved %s\n', summaryFile);
end

function [routeRows, routeRowIndex, summaryRows, summaryRowIndex] = appendRouteRows( ...
    routeRows, routeRowIndex, summaryRows, summaryRowIndex, mode, result)
global demand

route = result.bestRoute;
lengthR = result.bestLengthR;
arrivalTime = result.bestArrivalTime;
damage = result.bestDamage;
road = result.bestRoad;
carNum = result.carNum;

for routeIdx = 1:result.bestNumRoutes
    routeLength = lengthR(routeIdx);
    if routeLength <= 0
        continue;
    end
    periodIdx = ceil(routeIdx / carNum);
    nodes = route(routeIdx,1:routeLength);
    routeLoad = sum(demand(nodes));
    routeLastArrival = max(arrivalTime(nodes));
    routeNodeDamage = sum(damage(nodes));

    summaryRowIndex = summaryRowIndex + 1;
    summaryRows(summaryRowIndex,:) = {mode, result.caseName, result.seed, routeIdx, periodIdx, ...
        routeLength, routeLoad, routeLastArrival, routeNodeDamage}; %#ok<AGROW>

    for pos = 1:routeLength
        node = nodes(pos);
        routeRowIndex = routeRowIndex + 1;
        routeRows(routeRowIndex,:) = {mode, result.caseName, result.seed, routeIdx, periodIdx, ...
            pos, node, demand(node), arrivalTime(node), damage(node), road(node)}; %#ok<AGROW>
    end
end
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
    error('runRoutePlanExport:InvalidCaseFilter', 'caseFilter must be a string or cell array.');
end
cases = cases(~cellfun(@isempty, cases));
end
