function initialObjective()
global route lengthR numR arrivalTime fitness damage popsize road

for k = 1:popsize
    r = 1:numR(k);
    routeK = route(:,:,k);
    lengthRK = lengthR(k,:);
    roadK = road(k,:);
    arrivalTimeK = arrivalTime(k,:);
    damageK = damage(k,:);
    [fitness(k),damageK,roadK,arrivalTimeK] = objectiveK(routeK,lengthRK,roadK,arrivalTimeK,damageK,r);
    damage(k,:) = damageK;
    road(k,:) = roadK;
    arrivalTime(k,:) = arrivalTimeK;
end
end
