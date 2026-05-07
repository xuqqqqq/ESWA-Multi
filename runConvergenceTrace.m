function outputFile = runConvergenceTrace(mode, caseFilter, repeatFilter, algorithmFilter)
% Export real best-fitness traces for convergence-curve figures.
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
        repeats = 1;
        iterMax = 40;
        popsize = 6;
    case {'quick','convergence_quick','convergence-quick'}
        cases = {'C101-25','r101-25','rc101-25'};
        repeats = 1;
        iterMax = 120;
        popsize = 8;
    case {'paper_lite','paper-lite','convergence_paper_lite','convergence-paper-lite'}
        cases = {'C101-25','r101-25','rc101-25'};
        repeats = 3;
        iterMax = 300;
        popsize = 8;
    case {'paper','convergence_paper','convergence-paper'}
        cases = {'C101-25','r101-25','rc101-25'};
        repeats = 5;
        iterMax = 600;
        popsize = 10;
    otherwise
        cases = {'C101-25','r101-25','rc101-25'};
        repeats = 1;
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

algorithms = {'VNS','IMA','IHGA'};
if ~isempty(algorithmFilter)
    algorithms = normalizeTextFilter(algorithmFilter);
end

carNum = 18;
baseSeed = 14200;
rows = {};
summaryRows = {};
rowIndex = 0;
summaryIndex = 0;

if ~exist('results','dir')
    mkdir('results');
end

timestamp = datestr(now, 'yyyymmdd_HHMMSS');
outputFile = fullfile('results', ['convergence_trace_' lower(mode) '_' timestamp '.csv']);
summaryFile = fullfile('results', ['convergence_trace_' lower(mode) '_' timestamp '_summary.csv']);

for c = 1:numel(cases)
    for rep = repeatValues
        seed = baseSeed + c * 1000 + rep;
        for a = 1:numel(algorithms)
            algorithm = algorithms{a};
            fprintf('[convergence] algorithm=%s case=%s repeat=%d seed=%d\n', algorithm, cases{c}, rep, seed);
            if strcmpi(algorithm, 'IHGA')
                result = runIHGAOnce(cases{c}, carNum, seed, iterMax, popsize);
            elseif strcmpi(algorithm, 'VNS')
                result = runBaselineOnce('VNS', cases{c}, carNum, seed, iterMax, 1);
            else
                result = runBaselineOnce('IMA', cases{c}, carNum, seed, iterMax, popsize);
            end

            trace = result.trace(:);
            firstValue = trace(1);
            finalValue = trace(end);
            for generation = 1:numel(trace)
                rowIndex = rowIndex + 1;
                rows(rowIndex,:) = {lower(mode), cases{c}, upper(algorithm), rep, seed, ...
                    carNum, iterMax, popsize, generation, trace(generation), firstValue, finalValue, ...
                    result.elapsedSeconds}; %#ok<AGROW>
            end

            summaryIndex = summaryIndex + 1;
            summaryRows(summaryIndex,:) = {lower(mode), cases{c}, upper(algorithm), rep, seed, ...
                firstValue, finalValue, 100 * (firstValue - finalValue) / max(firstValue, eps), ...
                result.elapsedSeconds}; %#ok<AGROW>
            writeTraceRows(rows, outputFile);
            writeSummaryRows(summaryRows, summaryFile);
        end
    end
end

writeTraceRows(rows, outputFile);
writeSummaryRows(summaryRows, summaryFile);
fprintf('Saved %s\n', outputFile);
fprintf('Saved %s\n', summaryFile);
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
    error('runConvergenceTrace:InvalidCaseFilter', 'caseFilter must be a string or cell array.');
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
    error('runConvergenceTrace:InvalidRepeatFilter', 'repeatFilter must be numeric or comma-separated text.');
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
    error('runConvergenceTrace:InvalidTextFilter', 'Text filters must be a string or cell array.');
end
values = values(~cellfun(@isempty, values));
end

function writeTraceRows(rows, outputFile)
headers = {'mode','caseName','algorithm','repeat','seed','carNum','iterMax','popsize', ...
    'generation','bestFitness','firstFitness','finalFitness','elapsedSeconds'};
T = cell2table(rows, 'VariableNames', headers);
writetable(T, outputFile);
end

function writeSummaryRows(rows, outputFile)
headers = {'mode','caseName','algorithm','repeat','seed','firstFitness','finalFitness', ...
    'improvementPct','elapsedSeconds'};
T = cell2table(rows, 'VariableNames', headers);
writetable(T, outputFile);
end
