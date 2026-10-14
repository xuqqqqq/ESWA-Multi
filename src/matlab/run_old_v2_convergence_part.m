function [summaryFile, traceFile] = run_old_v2_convergence_part(caseName, caseTag, repeatValues)
% Resume-safe 300-generation traces for the frozen old-v2 comparison.
if nargin < 1 || isempty(caseName)
    error('run_old_v2_convergence_part:MissingCase', 'caseName is required.');
end
if nargin < 2 || isempty(caseTag)
    caseTag = lower(regexprep(caseName, '[^A-Za-z0-9]+', '_'));
end
if nargin < 3 || isempty(repeatValues)
    repeatValues = 6:20;
end

algorithms = {'VNS','IMA','PDR-HGA'};
carNum = 18;
iterMax = 300;
popsize = 8;
baseSeed = 15200;

if ~exist('results', 'dir')
    mkdir('results');
end
summaryFile = fullfile('results', sprintf('convergence_20run_%s_summary.csv', caseTag));
traceFile = fullfile('results', sprintf('convergence_20run_%s_trace.csv', caseTag));
summaryHeaders = {'caseName','algorithm','algorithmVersion','repeat','seed', ...
    'carNum','iterMax','popsize','firstFitness','finalFitness','elapsedSeconds'};
traceHeaders = {'caseName','algorithm','algorithmVersion','repeat','seed', ...
    'generation','bestFitness'};

summaryRows = readRows(summaryFile, summaryHeaders);
traceRows = readRows(traceFile, traceHeaders);
for rep = repeatValues
    seed = baseSeed + rep;
    for algorithmIndex = 1:numel(algorithms)
        algorithm = algorithms{algorithmIndex};
        if hasRun(summaryRows, algorithm, seed)
            fprintf('[convergence-20:skip] case=%s algorithm=%s repeat=%d seed=%d\n', ...
                caseName, algorithm, rep, seed);
            continue;
        end

        fprintf('[convergence-20] case=%s algorithm=%s repeat=%d seed=%d\n', ...
            caseName, algorithm, rep, seed);
        if strcmp(algorithm, 'PDR-HGA')
            result = runIHGAOnce(caseName, carNum, seed, iterMax, popsize);
        elseif strcmp(algorithm, 'IMA')
            result = runBaselineOnce('IMA', caseName, carNum, seed, iterMax, popsize);
        else
            result = runBaselineOnce('VNS', caseName, carNum, seed, iterMax, 1);
        end

        trace = result.trace(:);
        if numel(trace) ~= iterMax
            error('run_old_v2_convergence_part:IncompleteTrace', ...
                '%s/%s/seed=%d produced %d generations; expected %d.', ...
                caseName, algorithm, seed, numel(trace), iterMax);
        end
        summaryRows(end+1,:) = {caseName,algorithm,result.algorithmVersion,rep,seed, ...
            carNum,iterMax,result.popsize,trace(1),trace(end),result.elapsedSeconds}; %#ok<AGROW>
        for generation = 1:iterMax
            traceRows(end+1,:) = {caseName,algorithm,result.algorithmVersion,rep,seed, ...
                generation,trace(generation)}; %#ok<AGROW>
        end
        writeRows(summaryRows, summaryHeaders, summaryFile);
        writeRows(traceRows, traceHeaders, traceFile);
    end
end
end

function rows = readRows(path, headers)
if exist(path, 'file')
    data = readtable(path, 'TextType', 'string');
    if ~isequal(data.Properties.VariableNames, headers)
        error('run_old_v2_convergence_part:SchemaMismatch', 'Unexpected schema in %s.', path);
    end
    rows = table2cell(data);
else
    rows = cell(0, numel(headers));
end
end

function found = hasRun(rows, algorithm, seed)
found = false;
for rowIndex = 1:size(rows,1)
    if strcmpi(char(rows{rowIndex,2}), algorithm) && double(rows{rowIndex,5}) == seed
        found = true;
        return;
    end
end
end

function writeRows(rows, headers, path)
writetable(cell2table(rows, 'VariableNames', headers), path);
end
