function initialPopulationV2()
global route road lengthR numR popsize carNum roadNum nodeNum demand D maxLoad
global initialDeteriorationNode deteriorationRateNode recoveryRateNode
global numPeriods Qp totalCarNum depot

urgency = initialDeteriorationNode(1:nodeNum) + ...
    deteriorationRateNode(1:nodeNum) ./ max(recoveryRateNode(1:nodeNum), eps);
urgency = urgency(:)';

randomCut = ceil(popsize / 3);
weightedCut = ceil(2 * popsize / 3);
for k = 1:popsize
    if k <= randomCut
        sequence = randperm(nodeNum);
    elseif k <= weightedCut
        sequence = weightedUrgencySequence();
    else
        jitter = 1e-6 * rand(1,nodeNum);
        [~,sequence] = sort(urgency + jitter, 'descend');
        sequence = bandShuffle(sequence, 5);
    end
    assignSequence(k, sequence);
end

    function sequenceOut = weightedUrgencySequence()
        remaining = 1:nodeNum;
        sequenceOut = zeros(1,nodeNum);
        weights = max(urgency, eps);
        for seqIdx = 1:nodeNum
            localWeights = weights(remaining);
            localWeights = localWeights ./ sum(localWeights);
            cumulative = cumsum(localWeights);
            selected = find(rand <= cumulative, 1, 'first');
            if isempty(selected)
                selected = numel(remaining);
            end
            sequenceOut(seqIdx) = remaining(selected);
            remaining(selected) = [];
        end
    end

    function sequenceOut = nearestNeighborSequence()
        remaining = 1:nodeNum;
        sequenceOut = zeros(1,nodeNum);
        currentNode = depot;
        urgencyScale = max(urgency);
        if urgencyScale <= 0
            urgencyScale = 1;
        end
        for seqIdx = 1:nodeNum
            distanceScore = D(currentNode,remaining,2);
            distanceScale = max(distanceScore);
            if distanceScale <= 0
                distanceScale = 1;
            end
            urgencyBonus = urgency(remaining) ./ urgencyScale;
            score = distanceScore ./ distanceScale - 0.15 * urgencyBonus + 0.02 * rand(1,numel(remaining));
            [~,selected] = min(score);
            sequenceOut(seqIdx) = remaining(selected);
            currentNode = sequenceOut(seqIdx);
            remaining(selected) = [];
        end
    end

    function sequenceOut = bandShuffle(sequenceIn, bandCount)
        sequenceOut = [];
        bandSize = ceil(numel(sequenceIn) / bandCount);
        for b = 1:bandCount
            fromIdx = (b - 1) * bandSize + 1;
            toIdx = min(b * bandSize, numel(sequenceIn));
            if fromIdx <= toIdx
                band = sequenceIn(fromIdx:toIdx);
                sequenceOut = [sequenceOut band(randperm(numel(band)))];
            end
        end
    end

    function assignSequence(k, sequence)
        numR(k) = totalCarNum;
        loadV = zeros(1,totalCarNum);
        loadP = zeros(1,numPeriods);

        for idx = 1:numel(sequence)
            node = sequence(idx);
            assigned = false;
            periodOrder = 1:numPeriods;

            for p = periodOrder
                if sum(loadP(1:p)) + demand(node) > cumulativeInventory(p)
                    continue;
                end

                firstRoute = (p - 1) * carNum + 1;
                lastRoute = p * carNum;
                bestVehicle = 0;
                bestCost = inf;
                vehicles = firstRoute:lastRoute;

                for vIdx = vehicles(randperm(numel(vehicles)))
                    if loadV(vIdx) + demand(node) > maxLoad
                        continue;
                    end

                    if lengthR(k,vIdx) == 0
                        prevNode = depot;
                    else
                        prevNode = route(vIdx,lengthR(k,vIdx),k);
                    end
                    cost = D(prevNode,node,2) + 0.25 * loadV(vIdx) + 3.0 * lengthR(k,vIdx);
                    if cost < bestCost
                        bestCost = cost;
                        bestVehicle = vIdx;
                    end
                end

                if bestVehicle > 0
                    putNode(k, bestVehicle, p, node, loadV, loadP);
                    loadV(bestVehicle) = loadV(bestVehicle) + demand(node);
                    loadP(p) = loadP(p) + demand(node);
                    assigned = true;
                    break;
                end
            end

            if ~assigned
                [~,p] = min(loadP);
                firstRoute = (p - 1) * carNum + 1;
                lastRoute = p * carNum;
                candidates = firstRoute:lastRoute;
                [~,localIdx] = min(loadV(candidates));
                vIdx = candidates(localIdx);
                putNode(k, vIdx, p, node, loadV, loadP);
                loadV(vIdx) = loadV(vIdx) + demand(node);
                loadP(p) = loadP(p) + demand(node);
            end
        end
    end

    function putNode(k, vIdx, ~, node, ~, ~)
        route(vIdx,lengthR(k,vIdx)+1,k) = node;
        lengthR(k,vIdx) = lengthR(k,vIdx) + 1;
        road(k,node) = randperm(roadNum,1);
    end

    function supply = cumulativeInventory(periodIdx)
        if numel(Qp) == 1
            supply = periodIdx * Qp;
        else
            supply = sum(Qp(1:periodIdx));
        end
    end
end
