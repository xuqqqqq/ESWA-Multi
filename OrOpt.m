function flag = OrOpt(k)
global route road lengthR numR arrivalTime fitness damage

flag = 0;
routeK = route(:,:,k);
numRK = numR(k);
lengthRK = lengthR(k,:);
roadK = road(k,:);
damageK = damage(k,:);
arrivalTimeK = arrivalTime(k,:);

candidateRoutes = find(lengthRK(1:numRK) > 3);
if isempty(candidateRoutes)
    return;
end

r = candidateRoutes(randperm(numel(candidateRoutes),1));
p1 = randperm(lengthRK(r),1);
p2 = randperm(lengthRK(r),1);
s1 = min(p1,p2);
s2 = max(p1,p2);
guard = 0;
while (s1 == s2 || s2 == lengthRK(r)) && guard < 20
    p1 = randperm(lengthRK(r),1);
    p2 = randperm(lengthRK(r),1);
    s1 = min(p1,p2);
    s2 = max(p1,p2);
    guard = guard + 1;
end
if s1 == s2 || s2 == lengthRK(r)
    return;
end

routeK(r,:) = [routeK(r,1:s1-1) routeK(r,s2:s2+1) routeK(r,s1:s2-1) routeK(r,s2+2:end)];
[fitK,damageKnew,roadKnew,arrivalTimeKnew] = objectiveK(routeK,lengthRK,roadK,arrivalTimeK,damageK,r);

if fitK < fitness(k)
    fitness(k) = fitK;
    damage(k,:) = damageKnew;
    road(k,:) = roadKnew;
    arrivalTime(k,:) = arrivalTimeKnew;
    route(:,:,k) = routeK;
    flag = 1;
end
end
