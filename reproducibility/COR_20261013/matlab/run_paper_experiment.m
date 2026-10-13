function outputDir = run_paper_experiment(phase, repeatFilter, caseFilter, inputDir)
% Run the frozen solver in a new directory, leaving archived evidence untouched.
if nargin < 1, phase = 'smoke'; end
if nargin < 2, repeatFilter = []; end
if nargin < 3, caseFilter = {}; end
solverDir = fileparts(mfilename('fullpath'));
packageDir = fileparts(solverDir);
if nargin < 4 || isempty(inputDir), inputDir = fullfile(solverDir, 'data'); end
if isempty(caseFilter), cases = {'C101-25','r101-25','rc101-25'};
elseif ischar(caseFilter) || isstring(caseFilter), cases = cellstr(string(caseFilter));
else, cases = caseFilter; end
if strcmpi(phase,'external') && isempty(caseFilter)
    cases = {'HC1-100','HR1-100','HRC1-100'};
end
allowedCases = {'C101-25','r101-25','rc101-25','HC1-100','HR1-100','HRC1-100'};
assert(all(ismember(cases,allowedCases)), 'COR:UnknownCase', 'Use a documented case identifier');
allowedPhases = {'smoke','comparison','ablation','convergence','dispatch', ...
    'external','objectives','resources','nodes','archived_seed'};
assert(ismember(lower(phase),allowedPhases), 'COR:UnknownPhase', 'Unknown experiment phase');
if strcmpi(phase,'archived_seed'), cases = {'C101-25'}; end
required = {'nodeRate.txt','initialDshort.txt','initialD.txt','initialDlong.txt', ...
    'deteriorationRateDshort.txt','deteriorationRateD.txt','deteriorationRateDlong.txt','recoveryRateD.txt'};
for i = 1:numel(cases)
    for suffix = {'-para.txt','-Dshort.txt','-D.txt','-Dlong.txt'}
        required{end+1} = [cases{i} suffix{1}]; %#ok<AGROW>
    end
end
for i = 1:numel(required)
    assert(isfile(fullfile(inputDir,required{i})), 'COR:MissingInputs', ...
        'Excluded benchmark/model inputs are required. See INPUTS.md; missing %s', required{i});
end
previousDir = pwd;
previousPath = path;
cleanup = onCleanup(@() restoreEnvironment(previousDir, previousPath)); %#ok<NASGU>
addpath(solverDir, '-begin');
runRoot = fullfile(packageDir, 'new_runs');
if ~exist(runRoot, 'dir'), mkdir(runRoot); end
outputDir = tempname(runRoot);
mkdir(outputDir);
mkdir(fullfile(outputDir, 'results'));
mkdir(fullfile(outputDir, 'latex'));
for i = 1:numel(required)
    copyfile(fullfile(inputDir,required{i}), fullfile(outputDir,required{i}));
end
cd(outputDir);
assert(strcmpi(strrep(fileparts(which('runIHGAOnce')),'\','/'), ...
    strrep(solverDir,'\','/')), 'Wrong solver on MATLAB path');
clear global;

switch lower(phase)
    case 'smoke'
        report = struct('matlabVersion', version, 'release', version('-release'), 'cases', {{}});
        for i = 1:numel(cases)
            result = runIHGAOnce(cases{i}, 18, 7301, 2, 4, 'EnablePolish', false);
            repeated = runIHGAOnce(cases{i}, 18, 7301, 2, 4, 'EnablePolish', false);
            assert(abs(result.bestFitness - repeated.bestFitness) < 1e-9, 'Seed not deterministic');
            nodes = [];
            for k = 1:numel(result.bestLengthR)
                nodes = [nodes, result.bestRoute(k,1:result.bestLengthR(k))]; %#ok<AGROW>
            end
            assert(isequal(sort(nodes), 1:100), 'Nodes not served exactly once');
            assert(result.isFeasible && isfinite(result.bestFitness), 'Infeasible smoke solution');
            report.cases{end+1} = struct('caseName',cases{i},'loss',result.bestFitness,'passed',true);
            fprintf('Smoke passed: %s %.12f\n', cases{i}, result.bestFitness);
        end
        writeJSON(fullfile(outputDir,'smoke_report.json'), report);
    case 'comparison'
        if isempty(repeatFilter), repeatFilter = 1:20; end
        for i = 1:numel(cases)
            runAlgorithmComparison('paper_lite', cases{i}, repeatFilter, {'VNS','IMA','IHGA'});
        end
    case 'ablation'
        if isempty(repeatFilter), repeatFilter = 1:10; end
        runAblationStudy('paper_lite', cases, repeatFilter, ...
            {'base_hga','damage_critical_only','period_relocate_only','damage_period_coupled'});
    case 'convergence'
        if isempty(repeatFilter), repeatFilter = 1:20; end
        sourceFile = fullfile(packageDir,'evidence','convergence_old_v2_20run_authoritative.csv');
        cohorts = readtable(sourceFile,'TextType','string');
        cohorts = cohorts(cohorts.generation==1 & ismember(cohorts.caseName,string(cases)) ...
            & ismember(cohorts.repeat,repeatFilter),:);
        traceRows = {};
        for i = 1:height(cohorts)
            caseName = char(cohorts.caseName(i));
            algorithm = char(cohorts.algorithm(i));
            seed = cohorts.seed(i);
            if strcmp(algorithm,'PDR-HGA')
                result = runIHGAOnce(caseName,18,seed,300,8);
            elseif strcmp(algorithm,'IMA')
                result = runBaselineOnce('IMA',caseName,18,seed,300,8);
            else
                result = runBaselineOnce('VNS',caseName,18,seed,300,1);
            end
            for generation = 1:numel(result.trace)
                traceRows(end+1,:) = {caseName,algorithm,cohorts.repeat(i),seed, ...
                    generation,result.trace(generation)}; %#ok<AGROW>
            end
            writetable(cell2table(traceRows,'VariableNames', ...
                {'caseName','algorithm','repeat','seed','generation','bestFitness'}), ...
                fullfile('results','convergence.csv'));
        end
    case 'dispatch'
        runRoutePlanExport('paper_lite',cases);
    case 'external'
        if isempty(repeatFilter), repeatFilter = 1:5; end
        if isempty(caseFilter), cases = {'HC1-100','HR1-100','HRC1-100'}; end
        for i = 1:numel(cases), run_frozen_external_comparison(cases{i}, repeatFilter); end
    case 'objectives'
        if isempty(repeatFilter), repeatFilter = 1:20; end
        for i = 1:numel(cases), run_shared_framework_model_comparison(cases{i}, repeatFilter); end
    case 'resources'
        if isempty(repeatFilter), repeatFilter = 1:5; end
        runControlledResourceExperiments(fullfile('results','resources.csv'), cases, repeatFilter);
    case 'nodes'
        if isempty(repeatFilter), repeatFilter = 1:10; end
        runNodeCorrelationExperiment(fullfile('results','nodes.csv'), cases, repeatFilter);
    case 'archived_seed'
        result = runIHGAOnce('C101-25',18,7301,300,8);
        expected = 371.5469882096;
        report = struct('caseName','C101-25','seed',7301,'loss',result.bestFitness, ...
            'archivedLoss',expected,'difference',result.bestFitness-expected, ...
            'matched',abs(result.bestFitness-expected)<1e-7,'matlabVersion',version);
        writeJSON(fullfile(outputDir,'archived_seed_report.json'),report);
        fprintf('Archived seed: expected %.12f actual %.12f\n',expected,result.bestFitness);
        assert(report.matched,'Archived seed differs; inspect report before claiming an exact rerun');
    otherwise
        error('Unknown phase: %s',phase);
end
fprintf('New outputs: %s\n',outputDir);
end

function restoreEnvironment(previousDir, previousPath)
cd(previousDir);
path(previousPath);
end

function writeJSON(fileName, value)
fid = fopen(fileName,'w');
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s',jsonencode(value));
end
