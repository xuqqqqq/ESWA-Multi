function [childarrivalTime,childRoad] = calArrivalTime(k,childRoute,childlengthR,childnumR)
% Evaluate child arrival time without mutating global road.
global road
global roadNum
global depot
global nodeNum
global s
global D
global initialDeteriorationD
global Tshift carNum

childarrivalTime = zeros(1,nodeNum);
childRoad = road(k,:);

for i = 1:childnumR
    p = ceil(i / carNum);
    timeOffset = (p - 1) * Tshift;

    tempRoute = [depot childRoute(i,1:childlengthR(i))];
    for j = 1:length(tempRoute) - 1
        if tempRoute(j) == depot
            vkz = speedv(initialDeteriorationD(depot,tempRoute(j+1),childRoad(tempRoute(j+1))));
            while vkz <= 0
                childRoad(tempRoute(j+1)) = randperm(roadNum,1);
                vkz = speedv(initialDeteriorationD(depot,tempRoute(j+1),childRoad(tempRoute(j+1))));
            end
            childarrivalTime(tempRoute(j+1)) = timeOffset + D(depot,tempRoute(j+1),childRoad(tempRoute(j+1))) / vkz;
        else
            Rzt = Rt(childRoad(tempRoute(j+1)),(childarrivalTime(tempRoute(j)) + s(tempRoute(j))),tempRoute(j),tempRoute(j+1));
            vkz = speedv(Rzt);
            while vkz <= 0
                childRoad(tempRoute(j+1)) = randperm(roadNum,1);
                Rzt = Rt(childRoad(tempRoute(j+1)),(childarrivalTime(tempRoute(j)) + s(tempRoute(j))),tempRoute(j),tempRoute(j+1));
                vkz = speedv(Rzt);
            end
            childarrivalTime(tempRoute(j+1)) = childarrivalTime(tempRoute(j)) + D(tempRoute(j),tempRoute(j+1),childRoad(tempRoute(j+1))) / vkz + s(tempRoute(j));
        end
    end
end
end
