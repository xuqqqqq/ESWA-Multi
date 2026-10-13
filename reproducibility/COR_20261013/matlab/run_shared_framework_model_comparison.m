function outputFile = run_shared_framework_model_comparison(caseName, repeatValues)
% Compare routing objectives inside the same frozen PDR-HGA search framework.
if nargin < 1 || isempty(caseName)
    error('run_shared_framework_model_comparison:MissingCase', 'A case name is required.');
end
if nargin < 2 || isempty(repeatValues)
    repeatValues = 1:5;
end

objectiveModes = {'distance','cumulative_arrival','dynamic_damage'};
objectiveLabels = {'CVRP objective','CCVRP objective','MP-DDVRP objective'};
carNum = 18;
iterMax = 300;
popsize = 8;
baseSeed = 16600 + caseSeedOffset(caseName);
caseTag = lower(regexprep(caseName, '[^A-Za-z0-9]+', '_'));
outputFile = fullfile('results', ['shared_framework_models_' caseTag '.csv']);
headers = {'modelName','objectiveMode','algorithmVersion','caseName','seed','iterMax', ...
    'popsize','searchObjective','totalAffectedNodeLoss','capacityViolation', ...
    'inventoryViolation','isFeasible','elapsedSeconds'};
rows = readRows(outputFile, headers);

for rep = repeatValues
    seed = baseSeed + rep;
    for modeIndex = 1:numel(objectiveModes)
        label = objectiveLabels{modeIndex};
        if hasRun(rows, label, seed)
            fprintf('[shared-model:skip] case=%s model=%s seed=%d\n', caseName, label, seed);
            continue;
        end
        fprintf('[shared-model] case=%s model=%s repeat=%d seed=%d\n', ...
            caseName, label, rep, seed);
        result = runIHGAOnce(caseName, carNum, seed, iterMax, popsize, ...
            'ObjectiveMode', objectiveModes{modeIndex});
        rows(end+1,:) = {label,objectiveModes{modeIndex},result.algorithmVersion, ...
            result.caseName,result.seed,result.iterMax,result.popsize,result.bestFitness, ...
            result.dynamicDamage,result.capacityViolation,result.inventoryViolation, ...
            result.isFeasible,result.elapsedSeconds}; %#ok<AGROW>
        writetable(cell2table(rows, 'VariableNames', headers), outputFile);
    end
end
fprintf('Saved %s\n', outputFile);
end

function rows = readRows(path, headers)
if exist(path, 'file')
    data = readtable(path, 'TextType', 'string');
    if ~isequal(data.Properties.VariableNames, headers)
        error('run_shared_framework_model_comparison:SchemaMismatch', 'Unexpected schema in %s.', path);
    end
    rows = table2cell(data);
else
    rows = cell(0, numel(headers));
end
end

function found = hasRun(rows, modelName, seed)
found = false;
for rowIndex = 1:size(rows,1)
    if strcmpi(char(rows{rowIndex,1}), modelName) && double(rows{rowIndex,5}) == seed
        found = true;
        return;
    end
end
end

function offset = caseSeedOffset(caseName)
caseKey = lower(char(caseName));
if startsWith(caseKey, 'rc')
    offset = 3000;
elseif startsWith(caseKey, 'r')
    offset = 2000;
elseif startsWith(caseKey, 'c')
    offset = 1000;
else
    error('run_shared_framework_model_comparison:UnknownCase', 'No seed offset for %s.', caseName);
end
end
