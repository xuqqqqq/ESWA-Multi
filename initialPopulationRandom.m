function initialPopulationRandom()
global route road lengthR numR popsize carNum roadNum nodeNum demand D maxLoad
global numPeriods Qp totalCarNum depot

for k = 1:popsize
    sequence = randperm(nodeNum);
    assignSequence(k, sequence);
end

    function assignSequence(k, sequence)
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
                firstRoute = (p - 1) * carNum + 1;
                lastRoute = p * carNum;
                vehicleOrder = firstRoute:lastRoute;
                vehicleOrder = vehicleOrder(randperm(numel(vehicleOrder)));
                for vIdx = vehicleOrder
                    if loadV(vIdx) + demand(node) > maxLoad
                        continue;
                    end
                    putNode(k, vIdx, node);
                    loadV(vIdx) = loadV(vIdx) + demand(node);
                    loadP(p) = loadP(p) + demand(node);
                    assigned = true;
                    break;
                end
                if assigned
                    break;
                end
            end

            if ~assigned
                feasibleVehicles = find(loadV + demand(node) <= maxLoad);
                if isempty(feasibleVehicles)
                    [~,vIdx] = min(loadV);
                else
                    [~,localIdx] = min(loadV(feasibleVehicles));
                    vIdx = feasibleVehicles(localIdx);
                end
                p = ceil(vIdx / carNum);
                putNode(k, vIdx, node);
                loadV(vIdx) = loadV(vIdx) + demand(node);
                loadP(p) = loadP(p) + demand(node);
            end
        end
    end

    function putNode(k, vIdx, node)
        route(vIdx,lengthR(k,vIdx)+1,k) = node;
        lengthR(k,vIdx) = lengthR(k,vIdx) + 1;
        road(k,node) = randperm(roadNum,1);
    end
end
