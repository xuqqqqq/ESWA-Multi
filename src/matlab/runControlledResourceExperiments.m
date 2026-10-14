function outputFile = runControlledResourceExperiments(outputFile, caseFilter, repeatFilter, experimentFilter)
% Controlled old-v2 resource experiments with exact fixed totals and paired seeds.
if nargin < 1 || isempty(outputFile)
    outputFile = fullfile('results', ['controlled_resources_' datestr(now,'yyyymmdd_HHMMSS') '.csv']);
end
if nargin < 2 || isempty(caseFilter)
    cases = {'C101-25','r101-25','rc101-25'};
else
    cases = normalizeTextFilter(caseFilter);
end
if nargin < 3 || isempty(repeatFilter)
    repeats = 1:5;
else
    repeats = repeatFilter;
end
if nargin < 4 || isempty(experimentFilter)
    experiments = {'period_count','release_profile'};
else
    experiments = normalizeTextFilter(experimentFilter);
end

iterMax = 300;
popsize = 8;
totalDispatchSlots = 60;
finalHorizon = 1440;
headers = {'experiment','setting','caseName','seed','iterMax','popsize', ...
    'numPeriods','carNumPerPeriod','totalDispatchSlots','Tshift','QpProfile', ...
    'qPeriod1','qPeriod2','qPeriod3','qPeriod4','qPeriod5','totalSupply', ...
    'totalDemand','bestFitness','nodeDamage','roadDamage','nonEmptyRoutes', ...
    'avgArrivalTime','maxArrivalTime','periodLoad1','periodLoad2','periodLoad3', ...
    'periodLoad4','periodLoad5','elapsedSeconds','algorithmVersion'};
rows = {};
if exist(outputFile,'file')
    existing = readtable(outputFile);
    if ~isequal(existing.Properties.VariableNames,headers)
        error('runControlledResourceExperiments:ResumeSchemaMismatch', ...
            'Existing output has a different schema.');
    end
    rows = table2cell(existing);
end

for caseIdx = 1:numel(cases)
    caseName = cases{caseIdx};
    data = load([caseName '-para.txt']);
    totalDemand = sum(data(1:100,4));

    if any(strcmp(experiments,'period_count'))
        for periodCount = 1:5
            carNum = totalDispatchSlots / periodCount;
            if abs(carNum-round(carNum)) > eps
                error('Total dispatch slots must divide evenly by period count.');
            end
            carNum = round(carNum);
            qVector = allocateExact(totalDemand,ones(1,periodCount));
            for rep = repeats
                seed = 41000 + stableCaseIndex(caseName)*1000 + rep;
                setting = sprintf('P%d',periodCount);
                if hasRun(rows,'period_count',setting,caseName,seed)
                    continue;
                end
                fprintf('[period] case=%s P=%d seed=%d Q=[%s]\n', ...
                    caseName,periodCount,seed,num2str(qVector));
                result = runIHGAOnce(caseName,carNum,seed,iterMax,popsize, ...
                    'NumPeriods',periodCount,'Qp',qVector,'Tshift',finalHorizon/periodCount);
                rows(end+1,:) = resultRow(result,'period_count',setting,totalDemand, ...
                    totalDispatchSlots,finalHorizon/periodCount); %#ok<AGROW>
                writeRows(rows,headers,outputFile);
            end
        end
    end

    if any(strcmp(experiments,'release_profile'))
        profiles = {
            'front_loaded', [0.50 0.30 0.20];
            'uniform', [1/3 1/3 1/3];
            'back_loaded', [0.20 0.30 0.50]
        };
        periodCount = 3;
        carNum = totalDispatchSlots / periodCount;
        for profileIdx = 1:size(profiles,1)
            setting = profiles{profileIdx,1};
            qVector = allocateExact(totalDemand,profiles{profileIdx,2});
            for rep = repeats
                % The same seed is deliberately shared across release profiles.
                seed = 51000 + stableCaseIndex(caseName)*1000 + rep;
                if hasRun(rows,'release_profile',setting,caseName,seed)
                    continue;
                end
                fprintf('[release] case=%s profile=%s seed=%d Q=[%s]\n', ...
                    caseName,setting,seed,num2str(qVector));
                result = runIHGAOnce(caseName,carNum,seed,iterMax,popsize, ...
                    'NumPeriods',periodCount,'Qp',qVector,'Tshift',finalHorizon/periodCount);
                rows(end+1,:) = resultRow(result,'release_profile',setting,totalDemand, ...
                    totalDispatchSlots,finalHorizon/periodCount); %#ok<AGROW>
                writeRows(rows,headers,outputFile);
            end
        end
    end
end
writeRows(rows,headers,outputFile);
fprintf('Saved %s\n',outputFile);
end

function row = resultRow(result,experiment,setting,totalDemand,totalSlots,tshift)
q = result.Qp(:)';
q5 = zeros(1,5);
q5(1:numel(q)) = q;
row = {experiment,setting,result.caseName,result.seed,result.iterMax,result.popsize, ...
    result.numPeriods,result.carNum,totalSlots,tshift,strjoin(string(q),'|'), ...
    q5(1),q5(2),q5(3),q5(4),q5(5),sum(q),totalDemand,result.bestFitness, ...
    result.nodeDamage,result.roadDamage,result.nonEmptyRoutes,result.avgArrivalTime, ...
    result.maxArrivalTime,result.periodLoad1,result.periodLoad2,result.periodLoad3, ...
    result.periodLoad4,result.periodLoad5,result.elapsedSeconds,'critical_damage_v2'};
end

function q = allocateExact(total,weights)
weights = weights(:)'/sum(weights);
raw = total*weights;
q = floor(raw);
remainder = total-sum(q);
[~,order] = sort(raw-q,'descend');
q(order(1:remainder)) = q(order(1:remainder))+1;
end

function found = hasRun(rows,experiment,setting,caseName,seed)
found = false;
for idx = 1:size(rows,1)
    if strcmp(char(rows{idx,1}),experiment) && strcmp(char(rows{idx,2}),setting) && ...
            strcmpi(char(rows{idx,3}),caseName) && double(rows{idx,4})==seed
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

function values = normalizeTextFilter(value)
if ischar(value) || isstring(value)
    values = cellstr(string(value));
else
    values = value;
end
end

function writeRows(rows,headers,outputFile)
T = cell2table(rows,'VariableNames',headers);
writetable(T,outputFile);
end
