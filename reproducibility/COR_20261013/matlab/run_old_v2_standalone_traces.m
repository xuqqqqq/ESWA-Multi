function traceFile = run_old_v2_standalone_traces(caseName, repeatValues)
% Record convergence traces for the two standalone cells of the 2x2 ablation.
if nargin < 1 || isempty(caseName)
    error('run_old_v2_standalone_traces:MissingCase', 'A case name is required.');
end
if nargin < 2 || isempty(repeatValues)
    repeatValues = 1:10;
end

profiles = {'damage_critical_only','period_relocate_only'};
labels = {'Damage-critical repair','Period-aware relocation'};
carNum = 18;
iterMax = 300;
popsize = 8;
baseSeed = 9700;

if ~exist('results','dir')
    mkdir('results');
end
timestamp = datestr(now, 'yyyymmdd_HHMMSS');
caseKey = lower(strrep(caseName, '-', '_'));
traceFile = fullfile('results', sprintf('ablation_old_v2_trace_%s_%s.csv', caseKey, timestamp));
headers = {'mode','variant','operatorProfile','algorithmVersion','caseName','carNum','seed', ...
    'iterMax','popsize','numPeriods','generation','bestFitness'};
rows = {};
rowIndex = 0;

for rep = repeatValues
    seed = baseSeed + caseSeedOffset(caseName) + rep;
    for profileIndex = 1:numel(profiles)
        fprintf('[old-v2-trace] case=%s repeat=%d profile=%s seed=%d\n', ...
            caseName, rep, profiles{profileIndex}, seed);
        result = runIHGAOnce(caseName, carNum, seed, iterMax, popsize, ...
            'OperatorProfile', profiles{profileIndex});
        for generation = 1:numel(result.trace)
            rowIndex = rowIndex + 1;
            rows(rowIndex,:) = {'paper_lite', labels{profileIndex}, profiles{profileIndex}, ...
                result.algorithmVersion, result.caseName, result.carNum, result.seed, ...
                result.iterMax, result.popsize, result.numPeriods, generation, result.trace(generation)}; %#ok<AGROW>
        end
        writetable(cell2table(rows, 'VariableNames', headers), traceFile);
    end
end

fprintf('Saved %s\n', traceFile);
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
    error('run_old_v2_standalone_traces:UnknownCase', 'No paired-seed offset for %s.', caseName);
end
end
