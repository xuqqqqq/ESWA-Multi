function initialPopulationIMAStyle()
global nodeNum initialDeteriorationNode deteriorationRateNode recoveryRateNode popsize

urgency = initialDeteriorationNode(1:nodeNum) + ...
    deteriorationRateNode(1:nodeNum) ./ max(recoveryRateNode(1:nodeNum), eps);
urgency = urgency(:)';

for k = 1:popsize
    remaining = 1:nodeNum;
    sequence = zeros(1,nodeNum);
    weights = urgency;
    for idx = 1:nodeNum
        weightsLocal = weights(remaining);
        weightsLocal = weightsLocal ./ sum(weightsLocal);
        cumulative = cumsum(weightsLocal);
        selected = find(rand <= cumulative, 1, 'first');
        if isempty(selected)
            selected = numel(remaining);
        end
        sequence(idx) = remaining(selected);
        remaining(selected) = [];
    end
    assignOne(k, sequence);
end

    function assignOne(k, sequence)
        global route road lengthR numR carNum roadNum demand maxLoad numPeriods Qp totalCarNum
        numR(k) = totalCarNum;
        loadV = zeros(1,totalCarNum);
        loadP = zeros(1,numPeriods);
        for idx = 1:numel(sequence)
            node = sequence(idx);
            assigned = false;
            for p = 1:numPeriods
                if sum(loadP(1:p)) + demand(node) > p * Qp
                    continue;
                end
                vehicles = (p - 1) * carNum + (1:carNum);
                [~,order] = sort(loadV(vehicles), 'ascend');
                vehicles = vehicles(order);
                for vIdx = vehicles
                    if loadV(vIdx) + demand(node) <= maxLoad
                        route(vIdx,lengthR(k,vIdx)+1,k) = node;
                        lengthR(k,vIdx) = lengthR(k,vIdx) + 1;
                        road(k,node) = randperm(roadNum,1);
                        loadV(vIdx) = loadV(vIdx) + demand(node);
                        loadP(p) = loadP(p) + demand(node);
                        assigned = true;
                        break;
                    end
                end
                if assigned
                    break;
                end
            end
            if ~assigned
                [~,vIdx] = min(loadV);
                p = ceil(vIdx / carNum);
                route(vIdx,lengthR(k,vIdx)+1,k) = node;
                lengthR(k,vIdx) = lengthR(k,vIdx) + 1;
                road(k,node) = randperm(roadNum,1);
                loadV(vIdx) = loadV(vIdx) + demand(node);
                loadP(p) = loadP(p) + demand(node);
            end
        end
    end
end
