function outputFile = run_frozen_external_comparison(caseName, repeatValues)
% Resumable five-seed comparison on a Homberger-derived configuration.
if nargin < 1 || isempty(caseName)
    error('run_frozen_external_comparison:MissingCase', 'A case name is required.');
end
if nargin < 2 || isempty(repeatValues)
    repeatValues = 1:5;
end

allowedCases = {'HC1-100','HR1-100','HRC1-100'};
if ~any(strcmpi(caseName, allowedCases))
    error('run_frozen_external_comparison:UnknownCase', ...
        'Expected one of: %s.', strjoin(allowedCases, ', '));
end

algorithms = {'VNS','IMA','IHGA'};
carNum = 18;
iterMax = 300;
popsize = 8;
baseSeed = 22600 + caseSeedOffset(caseName);
caseTag = lower(regexprep(caseName, '[^A-Za-z0-9]+', '_'));
outputFile = fullfile('results', ...
    ['algorithm_comparison_paper_lite_' caseTag '_frozen.csv']);
headers = {'mode','algorithm','algorithmVersion','caseName','carNum','seed', ...
    'iterMax','popsize','numPeriods','Qp','bestFitness','nodeDamage', ...
    'capacityViolation','inventoryViolation','isFeasible','elapsedSeconds'};
rows = readRows(outputFile, headers);

for rep = repeatValues
    seed = baseSeed + rep;
    for algorithmIndex = 1:numel(algorithms)
        algorithm = algorithms{algorithmIndex};
        if hasRun(rows, algorithm, seed)
            fprintf('[external:skip] case=%s algorithm=%s seed=%d\n', ...
                caseName, algorithm, seed);
            continue;
        end
        fprintf('[external] case=%s algorithm=%s repeat=%d seed=%d\n', ...
            caseName, algorithm, rep, seed);
        if strcmpi(algorithm, 'IHGA')
            result = runIHGAOnce(caseName, carNum, seed, iterMax, popsize);
        elseif strcmpi(algorithm, 'IMA')
            result = runBaselineOnce('IMA', caseName, carNum, seed, iterMax, popsize);
        else
            result = runBaselineOnce('VNS', caseName, carNum, seed, iterMax, 1);
        end
        rows(end+1,:) = {'paper_lite',algorithm,result.algorithmVersion, ...
            result.caseName,result.carNum,result.seed,result.iterMax,result.popsize, ...
            result.numPeriods,result.Qp,result.bestFitness,result.nodeDamage, ...
            result.capacityViolation,result.inventoryViolation,result.isFeasible, ...
            result.elapsedSeconds}; %#ok<AGROW>
        writetable(cell2table(rows, 'VariableNames', headers), outputFile);
    end
end
fprintf('Saved %s\n', outputFile);
end

function rows = readRows(path, headers)
if exist(path, 'file')
    data = readtable(path, 'TextType', 'string');
    if ~isequal(data.Properties.VariableNames, headers)
        error('run_frozen_external_comparison:SchemaMismatch', ...
            'Unexpected schema in %s.', path);
    end
    rows = table2cell(data);
else
    rows = cell(0, numel(headers));
end
end

function found = hasRun(rows, algorithm, seed)
found = false;
for rowIndex = 1:size(rows,1)
    if strcmpi(char(rows{rowIndex,2}), algorithm) && double(rows{rowIndex,6}) == seed
        found = true;
        return;
    end
end
end

function offset = caseSeedOffset(caseName)
caseKey = upper(char(caseName));
if startsWith(caseKey, 'HRC')
    offset = 3000;
elseif startsWith(caseKey, 'HR')
    offset = 2000;
else
    offset = 1000;
end
end
