function [fitK,damageK,roadK,arrivalTimeK] = objectiveK(routeK,lengthRK,roadK,arrivalTimeK,damageK,r)
global roadNum
global depot
global s
global D
global omega
global initialDeteriorationD
global demand
global numPeriods Qp Tshift penaltyWeight carNum maxLoad

for i = 1:length(r)
    p = ceil(r(i) / carNum);
    timeOffset = (p - 1) * Tshift;

    tempRoute = [depot routeK(r(i),1:lengthRK(r(i)))];
    for j = 1:length(tempRoute) - 1
        if tempRoute(j) == depot
            vkz = speedv(initialDeteriorationD(depot,tempRoute(j+1),roadK(tempRoute(j+1))));
            while vkz <= 0
                roadK(tempRoute(j+1)) = randperm(roadNum,1);
                vkz = speedv(initialDeteriorationD(depot,tempRoute(j+1),roadK(tempRoute(j+1))));
            end
            arrivalTimeK(tempRoute(j+1)) = timeOffset + D(depot,tempRoute(j+1),roadK(tempRoute(j+1))) / vkz;
        else
            Rzt = Rt(roadK(tempRoute(j+1)),(arrivalTimeK(tempRoute(j)) + s(tempRoute(j))),tempRoute(j),tempRoute(j+1));
            vkz = speedv(Rzt);
            while vkz <= 0
                roadK(tempRoute(j+1)) = randperm(roadNum,1);
                Rzt = Rt(roadK(tempRoute(j+1)),(arrivalTimeK(tempRoute(j)) + s(tempRoute(j))),tempRoute(j),tempRoute(j+1));
                vkz = speedv(Rzt);
            end
            arrivalTimeK(tempRoute(j+1)) = arrivalTimeK(tempRoute(j)) + D(tempRoute(j),tempRoute(j+1),roadK(tempRoute(j+1))) / vkz + s(tempRoute(j));
        end

        damageK(tempRoute(j+1)) = Dt(tempRoute(j+1),arrivalTimeK(tempRoute(j+1)));
    end
end

penalty = 0;
periodLoad = zeros(1, numPeriods);
vehicleOverload = 0;
for i = 1:length(lengthRK)
    p = ceil(i / carNum);
    if lengthRK(i) > 0
        routeLoad = sum(demand(routeK(i, 1:lengthRK(i))));
        periodLoad(p) = periodLoad(p) + routeLoad;
        vehicleOverload = vehicleOverload + max(0, routeLoad - maxLoad);
    end
end

cumulativeLoad = 0;
cumulativeSupply = 0;
for p = 1:numPeriods
    cumulativeLoad = cumulativeLoad + periodLoad(p);
    cumulativeSupply = cumulativeSupply + periodInventory(p);

    if cumulativeLoad > cumulativeSupply
        penalty = penalty + (cumulativeLoad - cumulativeSupply) * penaltyWeight;
    end
end

penalty = penalty + vehicleOverload * penaltyWeight;
fitK = sum(damageK .* omega) + penalty;
end

function supply = periodInventory(periodIdx)
global Qp
if numel(Qp) == 1
    supply = Qp;
else
    supply = Qp(periodIdx);
end
end
