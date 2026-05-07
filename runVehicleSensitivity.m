function outputFile = runVehicleSensitivity(mode)
% Batch runner. Use mode='smoke', 'quick', 'paper', or 'full'.
if nargin < 1
    mode = 'quick';
end
algorithmVersion = 'critical_damage_v2_warmstart';

switch lower(mode)
    case 'smoke'
        cases = {'C101-25'};
        carNums = [8 10];
        repeats = 1;
        iterMax = 30;
        popsize = 6;
    case 'paper'
        cases = {'r101-25','C101-25','rc101-25'};
        carNums = [6 10 14 18 30 50];
        repeats = 5;
        iterMax = 600;
        popsize = 10;
    case 'full'
        cases = {'r101-25','C101-25','rc101-25'};
        carNums = [6 8 10 12 14 16 18 20 30 40 50];
        repeats = 10;
        iterMax = 3000;
        popsize = 20;
    otherwise
        cases = {'r101-25','C101-25','rc101-25'};
        carNums = [6 18 30 50];
        repeats = 1;
        iterMax = 50;
        popsize = 8;
end

resultsDir = fullfile(pwd, 'results');
if ~exist(resultsDir, 'dir')
    mkdir(resultsDir);
end

stamp = datestr(now, 'yyyymmdd_HHMMSS');
outputFile = fullfile(resultsDir, ['vehicle_sensitivity_' lower(mode) '_' stamp '.csv']);

caseCol = {};
modeCol = {};
algorithmVersionCol = {};
carNumCol = [];
seedCol = [];
iterMaxCol = [];
popsizeCol = [];
qPCol = [];
bestFitnessCol = [];
nodeDamageCol = [];
roadDamageCol = [];
bestNumRoutesCol = [];
nonEmptyRoutesCol = [];
maxRouteLengthCol = [];
avgRouteLengthCol = [];
avgArrivalTimeCol = [];
maxArrivalTimeCol = [];
periodLoad1Col = [];
periodLoad2Col = [];
periodLoad3Col = [];
elapsedSecondsCol = [];

baseSeed = 20260428 + mod(round(now * 86400), 1000000);
for c = 1:numel(cases)
    for r = 1:repeats
        warmStart = [];
        for i = 1:numel(carNums)
            seed = baseSeed + c * 10000 + i * 100 + r;
            if isempty(warmStart)
                result = runIHGAOnce(cases{c}, carNums(i), seed, iterMax, popsize);
            else
                result = runIHGAOnce(cases{c}, carNums(i), seed, iterMax, popsize, 'WarmStart', warmStart);
            end

            caseCol{end+1,1} = result.caseName;
            modeCol{end+1,1} = lower(mode);
            algorithmVersionCol{end+1,1} = algorithmVersion;
            carNumCol(end+1,1) = result.carNum;
            seedCol(end+1,1) = result.seed;
            iterMaxCol(end+1,1) = result.iterMax;
            popsizeCol(end+1,1) = result.popsize;
            qPCol(end+1,1) = result.Qp;
            bestFitnessCol(end+1,1) = result.bestFitness;
            nodeDamageCol(end+1,1) = result.nodeDamage;
            roadDamageCol(end+1,1) = result.roadDamage;
            bestNumRoutesCol(end+1,1) = result.bestNumRoutes;
            nonEmptyRoutesCol(end+1,1) = result.nonEmptyRoutes;
            maxRouteLengthCol(end+1,1) = result.maxRouteLength;
            avgRouteLengthCol(end+1,1) = result.avgRouteLength;
            avgArrivalTimeCol(end+1,1) = result.avgArrivalTime;
            maxArrivalTimeCol(end+1,1) = result.maxArrivalTime;
            periodLoad1Col(end+1,1) = result.periodLoad1;
            periodLoad2Col(end+1,1) = result.periodLoad2;
            periodLoad3Col(end+1,1) = result.periodLoad3;
            elapsedSecondsCol(end+1,1) = result.elapsedSeconds;

            fprintf('case=%s carNum=%d repeat=%d best=%.6f Qp=%g elapsed=%.1fs\n', ...
                result.caseName, result.carNum, r, result.bestFitness, result.Qp, result.elapsedSeconds);
            warmStart = result;
        end
    end
end

T = table(caseCol, modeCol, algorithmVersionCol, carNumCol, seedCol, iterMaxCol, popsizeCol, qPCol, ...
    bestFitnessCol, nodeDamageCol, roadDamageCol, bestNumRoutesCol, nonEmptyRoutesCol, ...
    maxRouteLengthCol, avgRouteLengthCol, avgArrivalTimeCol, maxArrivalTimeCol, ...
    periodLoad1Col, periodLoad2Col, periodLoad3Col, elapsedSecondsCol, ...
    'VariableNames', {'caseName','mode','algorithmVersion','carNum','seed','iterMax','popsize','Qp', ...
    'bestFitness','nodeDamage','roadDamage','bestNumRoutes','nonEmptyRoutes', ...
    'maxRouteLength','avgRouteLength','avgArrivalTime','maxArrivalTime', ...
    'periodLoad1','periodLoad2','periodLoad3','elapsedSeconds'});
writetable(T, outputFile);
fprintf('Wrote %s\n', outputFile);
end
