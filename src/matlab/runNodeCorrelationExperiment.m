function outputFile = runNodeCorrelationExperiment(outputFile, caseFilter, repeatFilter)
% Export node-level old-v2 outcomes for paired parameter-correlation analysis.
if nargin < 1 || isempty(outputFile)
    outputFile = fullfile('results',['node_correlation_' datestr(now,'yyyymmdd_HHMMSS') '.csv']);
end
if nargin < 2 || isempty(caseFilter)
    cases = {'C101-25','r101-25','rc101-25'};
elseif ischar(caseFilter) || isstring(caseFilter)
    cases = cellstr(string(caseFilter));
else
    cases = caseFilter;
end
if nargin < 3 || isempty(repeatFilter)
    repeats = 1:10;
else
    repeats = repeatFilter;
end

iterMax = 300;
popsize = 8;
carNum = 18;
nodeData = load('nodeRate.txt');
initialDamage = nodeData(:,1);
deteriorationRate = nodeData(:,2);
recoveryRate = nodeData(:,3);
sustainedPressure = deteriorationRate ./ max(recoveryRate,eps);
urgency = initialDamage + sustainedPressure;
headers = {'caseName','seed','node','initialDamage','deteriorationRate', ...
    'recoveryRate','sustainedPressure','urgency','arrivalTime','serviceRank', ...
    'nodeDamage','bestFitness','iterMax','popsize','algorithmVersion'};
rows = {};
if exist(outputFile,'file')
    existing = readtable(outputFile);
    if ~isequal(existing.Properties.VariableNames,headers)
        error('runNodeCorrelationExperiment:ResumeSchemaMismatch', ...
            'Existing output has a different schema.');
    end
    rows = table2cell(existing);
end

for caseIdx = 1:numel(cases)
    caseName = cases{caseIdx};
    for rep = repeats
        seed = 61000 + stableCaseIndex(caseName)*1000 + rep;
        if hasRun(rows,caseName,seed)
            continue;
        end
        fprintf('[node-correlation] case=%s seed=%d\n',caseName,seed);
        result = runIHGAOnce(caseName,carNum,seed,iterMax,popsize);
        arrival = result.bestArrivalTime(:);
        nodeLoss = result.bestDamage(:);
        [~,order] = sort(arrival,'ascend');
        serviceRank = zeros(numel(arrival),1);
        serviceRank(order) = (1:numel(arrival))';
        for node = 1:numel(arrival)
            rows(end+1,:) = {caseName,seed,node,initialDamage(node), ...
                deteriorationRate(node),recoveryRate(node),sustainedPressure(node), ...
                urgency(node),arrival(node),serviceRank(node),nodeLoss(node), ...
                result.bestFitness,iterMax,popsize,'critical_damage_v2'}; %#ok<AGROW>
        end
        writeRows(rows,headers,outputFile);
    end
end
writeRows(rows,headers,outputFile);
fprintf('Saved %s\n',outputFile);
end

function found = hasRun(rows,caseName,seed)
found = false;
for idx = 1:size(rows,1)
    if strcmpi(char(rows{idx,1}),caseName) && double(rows{idx,2})==seed
        found = true;
        return;
    end
end
end

function index = stableCaseIndex(caseName)
catalog = {'C101-25','r101-25','rc101-25'};
index = find(strcmpi(caseName,catalog),1);
if isempty(index)
    error('Unknown case %s.',caseName);
end
end

function writeRows(rows,headers,outputFile)
T = cell2table(rows,'VariableNames',headers);
writetable(T,outputFile);
end
