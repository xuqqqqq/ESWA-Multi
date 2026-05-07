function outputFile = runPriorityAnalysis(mode)
% Quantify whether high-priority nodes are served earlier and suffer less damage.
if nargin < 1 || isempty(mode)
    mode = 'quick';
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
    case 'full'
        cases = {'C101-25','r101-25','rc101-25'};
        repeats = 20;
        iterMax = 3000;
        popsize = 20;
    otherwise
        cases = {'C101-25','r101-25','rc101-25'};
        repeats = 3;
        iterMax = 120;
        popsize = 8;
end

metrics = {'initial','deterioration','urgency'};
groupLabels = {'low','medium','high'};
carNum = 18;
baseSeed = 8400;
nodeData = load('nodeRate.txt');
metricValues = struct();
metricValues.initial = nodeData(:,1);
metricValues.deterioration = nodeData(:,2);
metricValues.urgency = nodeData(:,1) + nodeData(:,2) ./ max(nodeData(:,3), eps);

rows = {};
rowIndex = 0;
if ~exist('results','dir')
    mkdir('results');
end

for c = 1:numel(cases)
    for rep = 1:repeats
        seed = baseSeed + c * 1000 + rep;
        fprintf('[priority] case=%s repeat=%d\n', cases{c}, rep);
        result = runIHGAOnce(cases{c}, carNum, seed, iterMax, popsize);
        arrival = result.bestArrivalTime(:);
        nodeDamage = result.bestDamage(:);
        [~, order] = sort(arrival, 'ascend');
        serviceRank = zeros(numel(arrival),1);
        serviceRank(order) = (1:numel(arrival))';

        for m = 1:numel(metrics)
            values = metricValues.(metrics{m});
            groups = tertileGroups(values);
            for g = 1:3
                idx = groups == g;
                rowIndex = rowIndex + 1;
                rows(rowIndex,:) = {lower(mode), cases{c}, rep, seed, metrics{m}, groupLabels{g}, ...
                    mean(values(idx)), mean(arrival(idx)), mean(nodeDamage(idx)), mean(serviceRank(idx)), sum(idx), ...
                    result.bestFitness, result.elapsedSeconds}; %#ok<AGROW>
            end
        end
    end
end

headers = {'mode','caseName','repeat','seed','priorityMetric','priorityGroup','avgPriorityValue', ...
    'avgArrivalTime','avgNodeDamage','avgServiceRank','nodeCount','bestFitness','elapsedSeconds'};
T = cell2table(rows, 'VariableNames', headers);
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
outputFile = fullfile('results', ['priority_analysis_' lower(mode) '_' timestamp '.csv']);
writetable(T, outputFile);
fprintf('Saved %s\n', outputFile);
end

function groups = tertileGroups(values)
[~, order] = sort(values, 'ascend');
groups = zeros(numel(values),1);
n = numel(values);
groups(order(1:floor(n/3))) = 1;
groups(order(floor(n/3)+1:floor(2*n/3))) = 2;
groups(order(floor(2*n/3)+1:end)) = 3;
end
