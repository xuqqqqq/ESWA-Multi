function report = smoke_synthetic(workingDir, reportFile)
% Synthetic fixture tests plumbing, not benchmark replication or performance.
packageDir = fileparts(fileparts(mfilename('fullpath')));
if nargin < 1, workingDir = fullfile(packageDir,'synthetic_test'); end
if nargin < 2, reportFile = fullfile(workingDir,'smoke_report.json'); end
assert(~exist(workingDir,'dir'), 'Use a new fixture directory');
previousDir = pwd;
previousPath = path;
cleanup = onCleanup(@() restoreEnvironment(previousDir,previousPath)); %#ok<NASGU>
addpath(fullfile(packageDir,'matlab'),'-begin');
try
    run_paper_experiment('smoke',[],'C101-25');
    error('COR:TestFailed','Missing-input guard did not fire');
catch err
    assert(strcmp(err.identifier,'COR:MissingInputs'),'Unexpected missing-input error');
end
mkdir(workingDir);
coordinates = [mod((0:99)',10)+1, floor((0:99)'/10)+1; 0 0];
para = [(1:101)', coordinates, [10*ones(100,1);0], [ones(100,1);0]];
writematrix(para,fullfile(workingDir,'C101-25-para.txt'),'Delimiter','space');
distances = sqrt((coordinates(:,1)-coordinates(:,1)').^2 + (coordinates(:,2)-coordinates(:,2)').^2);
names = {'-Dshort.txt','-D.txt','-Dlong.txt'};
scales = [0.8 1 1.2];
for i = 1:3
    writematrix(scales(i)*distances,fullfile(workingDir,['C101-25' names{i}]),'Delimiter','space');
end
writematrix([0.5*ones(100,1),0.3*ones(100,1),0.1*ones(100,1)], ...
    fullfile(workingDir,'nodeRate.txt'),'Delimiter','space');
shared = {'initialDshort.txt','initialD.txt','initialDlong.txt', ...
    'deteriorationRateDshort.txt','deteriorationRateD.txt','deteriorationRateDlong.txt','recoveryRateD.txt'};
for i = 1:numel(shared)
    matrix = 0.1*(ones(101)-eye(101));
    writematrix(matrix,fullfile(workingDir,shared{i}),'Delimiter','space');
end
cd(workingDir);
clear global;
algorithms = {'PDR-HGA','IMA','VNS'};
checks = cell(1,numel(algorithms));
for i = 1:numel(algorithms)
    if i == 1
        result = runIHGAOnce('C101-25',18,7301,2,4,'EnablePolish',false);
        repeated = runIHGAOnce('C101-25',18,7301,2,4,'EnablePolish',false);
    else
        population = 4;
        if i == 3, population = 1; end
        result = runBaselineOnce(algorithms{i},'C101-25',18,7301,2,population);
        repeated = runBaselineOnce(algorithms{i},'C101-25',18,7301,2,population);
    end
    assert(abs(result.bestFitness-repeated.bestFitness)<1e-9,'Nondeterministic seeded solve');
    served = [];
    for k = 1:numel(result.bestLengthR)
        served = [served result.bestRoute(k,1:result.bestLengthR(k))]; %#ok<AGROW>
    end
    assert(isequal(sort(served),1:100),'Each customer must be served exactly once');
    assert(result.isFeasible && isfinite(result.bestFitness),'Synthetic solution is infeasible');
    checks{i} = struct('algorithm',algorithms{i},'loss',result.bestFitness, ...
        'deterministic',true,'all_nodes_once',true,'capacity_inventory_feasible',true);
end
cd(previousDir);
run_paper_experiment('smoke',[],'C101-25',workingDir);
files = dir(fullfile(packageDir,'matlab','*.m'));
warningCount = 0;
syntaxErrors = {};
for i = 1:numel(files)
    issues = checkcode(fullfile(files(i).folder,files(i).name),'-struct');
    warningCount = warningCount + numel(issues);
    for j = 1:numel(issues)
        if contains(lower(issues(j).message),'parse error') || contains(lower(issues(j).message),'syntax error')
            syntaxErrors{end+1} = files(i).name; %#ok<AGROW>
        end
    end
end
assert(isempty(syntaxErrors),'MATLAB syntax errors found');
report = struct('passed',true,'fixture','synthetic grid, not a benchmark', ...
    'release',version('-release'),'generations',2,'checks',{checks}, ...
    'missing_input_guard_passed',true,'adapted_wrapper_smoke_passed',true, ...
    'files_checkcode_checked',numel(files),'checkcode_advisories',warningCount, ...
    'syntax_errors',{syntaxErrors},'fresh_benchmark_replication',false);
fid = fopen(reportFile,'w');
fileCleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(report));
fprintf('Synthetic solver and input-boundary checks passed.\n');
end

function restoreEnvironment(previousDir,previousPath)
cd(previousDir);
path(previousPath);
end
